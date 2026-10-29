import crypto from 'node:crypto';

import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { pool, query } from '../db.js';
import { orgIdForMember } from '../lib/orgScope.js';
import { draftAgencyReport } from '../lib/ai/agencyReport.js';
import { evidenceOf } from '../lib/ai/draft.js';
import { draftFarmReport, kstDate } from '../lib/ai/farmReport.js';
import { analyzeMemos } from '../lib/ai/memoAnalysis.js';
import { AiError, MODEL_CATALOG, modelStatus } from '../lib/ai/model.js';
import { AGENCY_SECTIONS, FARM_SECTIONS } from '../lib/ai/prompts.js';
import { modelsWithUsage, recordUsage } from '../lib/ai/usage.js';

export const aiReportsRouter = Router();
aiReportsRouter.use(requireAuth);

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_PERIOD_DAYS = 92;
// 메모가 많으면 묶음별 중간 정리를 거쳐 만든다(staged.js).
const MAX_MEMOS = 600;
const MAX_AGENCY_MEMOS = 3000;
const OPINION_MAX = 3000;
const SHARE_LINK_MS = 30 * 86400_000;

const KIND_TAGS = ['폐사', '접종', '방문', '배달', '문의', '할일'];
const kindOf = (tags) => KIND_TAGS.find((t) => (tags ?? []).includes(t)) ?? '메모';

/** "## 제목" 섹션별 본문 */
function sectionsOf(body) {
  const out = new Map();
  let title = '';
  for (const line of String(body ?? '').split(/\r?\n/)) {
    if (line.startsWith('## ')) {
      title = line.slice(3).trim();
      out.set(title, []);
    } else if (line.trim()) {
      out.set(title, [...(out.get(title) ?? []), line.trim()]);
    }
  }
  return out;
}

/** AI 원문과 비교해 전문가가 고친 섹션 */
function editedSections(row, body = row.body) {
  const a = sectionsOf(row.ai_body);
  const b = sectionsOf(body);
  const base = row.type === 'agency' ? AGENCY_SECTIONS : FARM_SECTIONS;
  const titles = [...new Set([...base, ...a.keys(), ...b.keys()])].filter(Boolean);
  return titles.filter((t) => (a.get(t) ?? []).join('\n') !== (b.get(t) ?? []).join('\n'));
}

function toAiReportJson(row, { full = true } = {}) {
  const snap = row.input_snapshot ?? {};
  return {
    id: row.id,
    type: row.type ?? 'farm',
    farmId: row.farm_id,
    periodStart: kstDateOnly(row.period_start),
    periodEnd: kstDateOnly(row.period_end),
    status: row.status,
    version: row.version ?? 0,
    model: row.model,
    memoCount: row.memo_count,
    commentCount: row.comment_count,
    checkCount: Array.isArray(row.checks) ? row.checks.length : 0,
    edited: row.body !== row.ai_body,
    createdByName: row.created_by_name,
    createdAt: row.created_at,
    editedByName: row.edited_by_name,
    editedAt: row.edited_at,
    confirmedByName: row.confirmed_by_name,
    confirmedAt: row.confirmed_at,
    sentByName: row.sent_by_name,
    sentAt: row.sent_at,
    ...(full
      ? {
          body: row.body,
          aiBody: row.ai_body,
          checks: row.checks ?? [],
          memos: [
            ...(snap.memos ?? []).map((m) => ({ ...memoJson(m), period: 'current' })),
            ...(snap.prevMemos ?? []).map((m) => ({ ...memoJson(m), period: 'previous' })),
          ],
          comments: (snap.comments ?? []).map((c) => ({ key: c.key, memoN: c.memoN, date: c.date, author: c.author ?? '', body: c.body ?? '', late: !!c.late })),
          // 근거 확인: AI 초안 항목이 본문에 찍힌 줄과 그 근거 메모 번호
          evidence: row.type === 'agency' ? [] : evidenceOf(row.draft, { memos: snap.memos ?? [], prev: snap.prevMemos ?? [], comments: snap.comments ?? [] }),
          // 리포트 양식(타일·차트)용 값. 이 기능 이전에 만든 리포트에는 없다(null).
          meta: snap.meta ?? null,
          examples: snap.examples ?? [],
          staged: snap.staged ?? null,
          finalOpinion: row.final_opinion ?? '',
          editedSections: editedSections(row),
        }
      : {}),
  };
}

const memoJson = (m) => ({ id: m.id, n: m.n ?? null, date: m.date, kind: m.kind, author: m.author ?? '', body: m.body, farmName: m.farmName ?? null });

// pg returns `date` columns as local-midnight Date objects; format them back
// to the plain YYYY-MM-DD that was stored.
function kstDateOnly(value) {
  if (typeof value === 'string') return value.slice(0, 10);
  const d = new Date(value);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const kstStart = (date) => new Date(`${date}T00:00:00+09:00`);

/** 기간 검증. 맞으면 { start, endExclusive, days }, 아니면 오류 문구 */
function periodOf(from, to) {
  if (!DATE_RE.test(from ?? '') || !DATE_RE.test(to ?? '') || from > to) {
    return { error: '기간(from, to)을 YYYY-MM-DD 형식으로 올바르게 지정해 주세요.' };
  }
  const start = kstStart(from);
  const endExclusive = new Date(kstStart(to).getTime() + 86400_000);
  const days = Math.round((endExclusive - start) / 86400_000);
  if (days > MAX_PERIOD_DAYS) return { error: `기간은 최대 ${MAX_PERIOD_DAYS}일까지 고를 수 있습니다.` };
  return { start, endExclusive, days };
}

async function loadFarm(orgId, farmId) {
  if (!UUID_RE.test(String(farmId ?? ''))) return null;
  const { rows } = await query('select * from farms where org_id = $1 and id = $2', [orgId, farmId]);
  return rows[0] ?? null;
}

async function loadReport(orgId, id) {
  if (!UUID_RE.test(String(id ?? ''))) return null;
  const { rows } = await query('select * from ai_reports where org_id = $1 and id = $2', [orgId, id]);
  return rows[0] ?? null;
}

async function memberName(memberId) {
  const { rows } = await query('select name from members where id = $1', [memberId]);
  return rows[0]?.name ?? '';
}

async function orgName(orgId) {
  const { rows } = await query('select name from organizations where id = $1', [orgId]);
  return rows[0]?.name ?? '';
}

/** 상태가 맞을 때만 바꾼다(동시에 누른 두 요청 중 하나만 성공). 바뀐 행 또는 null */
async function transition(client, id, from, set, params = []) {
  const { rows } = await client.query(`update ai_reports set ${set} where id = $1 and status = $2 returning *`, [id, from, ...params]);
  return rows[0] ?? null;
}

// 연결 상태 + 고를 수 있는 모델과 모델별 오늘 사용량(이 서버가 보낸 요청 기준).
aiReportsRouter.get('/status', async (req, res) => {
  const { configured, model, note } = modelStatus();
  const usage = await modelsWithUsage();
  res.json({ configured, model, note, ...usage });
});

aiReportsRouter.get('/farm/:farmId', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const farm = await loadFarm(orgId, req.params.farmId);
  if (!farm) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });
  const { rows } = await query("select * from ai_reports where farm_id = $1 and type = 'farm' order by created_at desc limit 50", [farm.id]);
  res.json(rows.map((r) => toAiReportJson(r, { full: false })));
});

// 관리원 종합 리포트 목록
aiReportsRouter.get('/agency', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { rows } = await query("select * from ai_reports where org_id = $1 and type = 'agency' order by created_at desc limit 50", [orgId]);
  res.json(rows.map((r) => toAiReportJson(r, { full: false })));
});

// 분류 점검 목록(symterAI memo-review 이식): 자동 분류가 확신하지 못한 메모 — 폐사 수량 미기재·수치 여러 개·누적치만·분류 불가.
// 규칙을 보강할 때 본다. ?from&to (필수) &farmId (없으면 관리원 전체)
aiReportsRouter.get('/memo-review', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const p = periodOf(req.query.from, req.query.to);
  if (p.error) return res.status(400).json({ error: p.error });
  const farmId = req.query.farmId ? String(req.query.farmId) : null;
  if (farmId && !(await loadFarm(orgId, farmId))) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });
  const { rows } = await query(
    `select mm.id, mm.content, mm.tags, mm.created_at, f.name as farm_name from memos mm join farms f on f.id = mm.farm_id
      where mm.org_id = $1 and ($2::uuid is null or mm.farm_id = $2::uuid) and mm.created_at >= $3 and mm.created_at < $4
      order by mm.created_at`,
    [orgId, farmId, p.start, p.endExclusive],
  );
  const memos = rows.map((r, i) => ({ id: i + 1, n: i + 1, uuid: r.id, farm: r.farm_name, date: kstDate(r.created_at), kind: kindOf(r.tags), body: r.content }));
  const analyzed = analyzeMemos(memos);
  const uncertain = analyzed
    .filter((m) => m.a.uncertain.length)
    .map((m) => ({ id: m.uuid, farmName: m.farm, date: m.date, kind: m.kind, body: m.body, topic: m.a.primary, reasons: m.a.uncertain }));
  res.json({
    total: analyzed.length,
    uncertainCount: uncertain.length,
    unclassified: analyzed.filter((m) => m.a.primary === '기타').length,
    deathsWithoutCount: analyzed.filter((m) => m.a.deaths && m.a.deaths.min === null && m.a.deaths.cumulative === null).length,
    uncertain,
  });
});

aiReportsRouter.get('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  res.json(toAiReportJson(row));
});

// 승인된 판 목록(최신 판부터)
aiReportsRouter.get('/:id/versions', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  const { rows } = await query('select * from ai_report_versions where report_id = $1 order by version desc', [row.id]);
  const { rows: sends } = await query('select version, sent_at, sent_by_name from ai_report_sends where report_id = $1 order by sent_at', [row.id]);
  res.json(
    rows.map((v) => ({
      version: v.version,
      body: v.body,
      finalOpinion: v.final_opinion,
      approvedByName: v.approved_by_name,
      approvedAt: v.approved_at,
      editedSections: v.edited_sections ?? [],
      sends: sends.filter((s) => s.version === v.version).map((s) => ({ sentAt: s.sent_at, sentByName: s.sent_by_name })),
    })),
  );
});

// Body: { from: 'YYYY-MM-DD', to: 'YYYY-MM-DD', memoIds?: string[], includeComments?: boolean, model? }
// memoIds omitted → every memo of the farm in the period.
aiReportsRouter.post('/farm/:farmId', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const farm = await loadFarm(orgId, req.params.farmId);
  if (!farm) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });

  const { from, to, memoIds, includeComments = true, model } = req.body ?? {};
  if (model != null && !MODEL_CATALOG.some((m) => m.id === model)) return res.status(400).json({ error: '고를 수 없는 AI 모델입니다.' });
  const p = periodOf(from, to);
  if (p.error) return res.status(400).json({ error: p.error });
  if (!modelStatus().configured) return res.status(503).json({ error: 'AI가 연결되지 않았습니다. 서버에 MODEL_API_KEY 를 설정해 주세요.' });

  const { rows: periodMemos } = await query(
    `select id, content, tags, author_type, author_name, created_at from memos
      where farm_id = $1 and created_at >= $2 and created_at < $3 order by created_at`,
    [farm.id, p.start, p.endExclusive],
  );
  let selected = periodMemos;
  if (Array.isArray(memoIds)) {
    const wanted = new Set(memoIds.map(String));
    selected = periodMemos.filter((m) => wanted.has(m.id));
  }
  if (selected.length === 0) return res.status(400).json({ error: '선택한 기간에 리포트에 넣을 메모가 없습니다.' });
  if (selected.length > MAX_MEMOS) return res.status(400).json({ error: `메모는 한 번에 ${MAX_MEMOS}건까지 넣을 수 있습니다. 기간을 줄여 주세요.` });

  let comments = [];
  if (includeComments) {
    const ids = new Set(selected.map((m) => m.id));
    const { rows } = await query(
      `select c.memo_id, c.author_name, c.content, c.created_at from memo_comments c
         join memos mm on mm.id = c.memo_id
        where mm.farm_id = $1 and mm.created_at >= $2 and mm.created_at < $3 order by c.created_at`,
      [farm.id, p.start, p.endExclusive],
    );
    comments = rows.filter((c) => ids.has(c.memo_id));
  }

  const prevStart = new Date(p.start.getTime() - p.days * 86400_000);
  const { rows: prevMemos } = await query(
    `select id, content, tags, author_type, author_name, created_at from memos
      where farm_id = $1 and created_at >= $2 and created_at < $3 order by created_at limit $4`,
    [farm.id, prevStart, p.start, MAX_MEMOS],
  );

  let result;
  try {
    result = await draftFarmReport({
      farm,
      from,
      to,
      memos: selected,
      comments,
      prevMemos,
      candidates: periodMemos.length,
      model: model ?? undefined,
      onResult: (r) => recordUsage({ orgId, memberId: req.memberId, ...r }),
    });
  } catch (err) {
    if (err instanceof AiError) return res.status(err.status).json({ error: err.message });
    throw err;
  }

  const name = await memberName(req.memberId);
  const { rows } = await query(
    `insert into ai_reports
       (org_id, farm_id, type, period_start, period_end, model, prompt_version, memo_count, comment_count,
        input_snapshot, raw_draft, draft, checks, ai_body, body, created_by, created_by_name)
     values ($1,$2,'farm',$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$13,$14,$15)
     returning *`,
    [
      orgId,
      farm.id,
      from,
      to,
      result.model,
      result.promptVersion,
      selected.length,
      result.snapshot.comments.length,
      JSON.stringify(result.snapshot),
      JSON.stringify(result.raw),
      JSON.stringify(result.draft),
      JSON.stringify(result.checks),
      result.body,
      req.memberId,
      name,
    ],
  );
  res.status(201).json(toAiReportJson(rows[0]));
});

// 관리원 종합 리포트 만들기. Body: { from, to, model? }
aiReportsRouter.post('/agency', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { from, to, model } = req.body ?? {};
  if (model != null && !MODEL_CATALOG.some((m) => m.id === model)) return res.status(400).json({ error: '고를 수 없는 AI 모델입니다.' });
  const p = periodOf(from, to);
  if (p.error) return res.status(400).json({ error: p.error });
  if (!modelStatus().configured) return res.status(503).json({ error: 'AI가 연결되지 않았습니다. 서버에 MODEL_API_KEY 를 설정해 주세요.' });

  const { rows: farms } = await query('select * from farms where org_id = $1 order by name', [orgId]);
  if (!farms.length) return res.status(400).json({ error: '등록된 양식장이 없습니다.' });
  const { rows: memos } = await query(
    `select id, farm_id, content, tags, author_type, author_name, created_at from memos
      where org_id = $1 and farm_id is not null and created_at >= $2 and created_at < $3 order by created_at`,
    [orgId, p.start, p.endExclusive],
  );
  if (!memos.length) return res.status(400).json({ error: '선택한 기간에 양식장 메모가 없습니다.' });
  if (memos.length > MAX_AGENCY_MEMOS) return res.status(400).json({ error: `메모가 너무 많습니다(${memos.length}건). 기간을 줄여 주세요.` });

  let result;
  try {
    result = await draftAgencyReport({
      orgName: await orgName(orgId),
      from,
      to,
      farms,
      memos,
      model: model ?? undefined,
      onResult: (r) => recordUsage({ orgId, memberId: req.memberId, ...r }),
    });
  } catch (err) {
    if (err instanceof AiError) return res.status(err.status).json({ error: err.message });
    throw err;
  }

  const name = await memberName(req.memberId);
  const { rows } = await query(
    `insert into ai_reports
       (org_id, farm_id, type, period_start, period_end, model, prompt_version, memo_count, comment_count,
        input_snapshot, raw_draft, draft, checks, ai_body, body, created_by, created_by_name)
     values ($1,null,'agency',$2,$3,$4,$5,$6,0,$7,'{}','{}',$8,$9,$9,$10,$11)
     returning *`,
    [orgId, from, to, result.model, result.promptVersion, result.memoCount, JSON.stringify(result.snapshot), JSON.stringify(result.checks), result.body, req.memberId, name],
  );
  res.status(201).json(toAiReportJson(rows[0]));
});

// 전문가 수정(초안에서만). body 와 finalOpinion(전문가 최종 의견) 중 보낸 것만 바꾼다.
aiReportsRouter.put('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  if (row.status !== 'draft') {
    return res.status(409).json({ error: row.status === 'sent' ? '발송된 리포트입니다. 새 판을 만든 뒤 수정해 주세요.' : '확정된 리포트입니다. 확정을 취소한 뒤 수정해 주세요.' });
  }
  const hasBody = req.body?.body !== undefined;
  const body = String(req.body?.body ?? '').trim();
  if (hasBody && !body) return res.status(400).json({ error: '리포트 내용이 비어 있습니다.' });
  const opinion = req.body?.finalOpinion === undefined ? null : String(req.body.finalOpinion).trim();
  if (opinion !== null && opinion.length > OPINION_MAX) return res.status(400).json({ error: `최종 의견은 ${OPINION_MAX.toLocaleString()}자까지 쓸 수 있습니다.` });
  if (!hasBody && opinion === null) return res.status(400).json({ error: '바꿀 내용이 없습니다.' });
  const { rows } = await query(
    `update ai_reports set body = coalesce($2, body), final_opinion = coalesce($3, final_opinion),
        edited_by_name = case when $2::text is null then edited_by_name else $4 end,
        edited_at = case when $2::text is null then edited_at else now() end
      where id = $1 and status = 'draft' returning *`,
    [row.id, hasBody ? body : null, opinion, await memberName(req.memberId)],
  );
  if (!rows[0]) return res.status(409).json({ error: '다른 곳에서 상태가 바뀌었습니다. 새로고침해 주세요.' });
  res.json(toAiReportJson(rows[0]));
});

// 확정 = 승인. 판 번호를 올리고 그 시점 본문·최종 의견을 ai_report_versions 에 남긴다(이전 판은 지우지 않는다).
aiReportsRouter.post('/:id/confirm', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  const name = await memberName(req.memberId);
  const client = await pool.connect();
  let updated;
  try {
    await client.query('begin');
    updated = await transition(client, row.id, 'draft', "status = 'confirmed', confirmed_by_name = $3, confirmed_at = now(), version = version + 1", [name]);
    if (updated) {
      await client.query(
        `insert into ai_report_versions (report_id, version, body, final_opinion, approved_by_name, approved_at, edited_sections)
         values ($1, $2, $3, $4, $5, $6, $7)`,
        [updated.id, updated.version, updated.body, updated.final_opinion ?? '', name, updated.confirmed_at, JSON.stringify(editedSections(updated))],
      );
    }
    await client.query('commit');
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
  }
  if (!updated) return res.status(409).json({ error: '초안 상태의 리포트만 확정할 수 있습니다.' });
  res.json(toAiReportJson(updated));
});

// 확정 취소(발송 전만). 저장된 판은 그대로 남는다.
aiReportsRouter.post('/:id/unconfirm', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  if (row.status === 'sent') return res.status(409).json({ error: '이미 발송된 리포트는 확정을 취소할 수 없습니다. 새 판을 만들어 주세요.' });
  const updated = await transition(pool, row.id, 'confirmed', "status = 'draft', confirmed_by_name = null, confirmed_at = null");
  if (!updated) return res.status(409).json({ error: '확정된 리포트만 확정을 취소할 수 있습니다.' });
  res.json(toAiReportJson(updated));
});

/** 양식장의 쓸 수 있는 공유 링크(없으면 30일짜리를 새로 만든다) */
async function activeShareLink(client, farmId, memberId) {
  const { rows } = await client.query(
    `select * from share_links where farm_id = $1 and revoked_at is null and (expires_at is null or expires_at > now())
      order by created_at desc limit 1`,
    [farmId],
  );
  if (rows[0]) return rows[0];
  const { rows: created } = await client.query(
    'insert into share_links (farm_id, token, created_by, expires_at) values ($1, $2, $3, $4) returning *',
    [farmId, crypto.randomBytes(5).toString('hex').slice(0, 6), memberId, new Date(Date.now() + SHARE_LINK_MS).toISOString()],
  );
  return created[0];
}

// 발송: 상태 변경 + 발송 스냅샷 저장을 한 번에 처리한다. 양식장은 공유 링크(/r/:token)에서 받은 리포트를 본다.
aiReportsRouter.post('/:id/send', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  if (row.type !== 'farm') return res.status(400).json({ error: '종합 리포트는 양식장에 발송하지 않습니다. 확정·인쇄/PDF만 사용할 수 있습니다.' });
  if (row.status !== 'confirmed') return res.status(409).json({ error: row.status === 'sent' ? '이미 발송된 리포트입니다.' : '확정된 리포트만 발송할 수 있습니다.' });
  const name = await memberName(req.memberId);
  const { rows: farmRows } = await query('select name from farms where id = $1', [row.farm_id]);
  const org = await orgName(orgId);
  const client = await pool.connect();
  let updated;
  let link;
  try {
    await client.query('begin');
    updated = await transition(client, row.id, 'confirmed', "status = 'sent', sent_at = now(), sent_by_name = $3", [name]);
    if (updated) {
      await client.query(
        `insert into ai_report_sends
           (report_id, farm_id, version, body, final_opinion, edited_sections, meta, farm_name, org_name, period_start, period_end,
            memo_count, comment_count, approved_by_name, approved_at, sent_by_name, sent_at)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
        [
          updated.id,
          updated.farm_id,
          updated.version,
          updated.body,
          updated.final_opinion ?? '',
          JSON.stringify(editedSections(updated)),
          JSON.stringify(updated.input_snapshot?.meta ?? null),
          farmRows[0]?.name ?? '',
          org,
          kstDateOnly(updated.period_start),
          kstDateOnly(updated.period_end),
          updated.memo_count,
          updated.comment_count,
          updated.confirmed_by_name ?? '',
          updated.confirmed_at,
          name,
          updated.sent_at,
        ],
      );
      link = await activeShareLink(client, updated.farm_id, req.memberId);
    }
    await client.query('commit');
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
  }
  if (!updated) return res.status(409).json({ error: '확정된 리포트만 발송할 수 있습니다.' });
  res.json({
    report: toAiReportJson(updated),
    shareLink: { id: link.id, farmId: link.farm_id, token: link.token, createdAt: link.created_at, expiresAt: link.expires_at, revokedAt: link.revoked_at },
  });
});

// 발송된 리포트를 고치려면 새 판을 만든다: 초안으로 되돌리되, 양식장은 다시 발송될 때까지 이전 발송본을 본다.
aiReportsRouter.post('/:id/revise', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  const updated = await transition(pool, row.id, 'sent', "status = 'draft', confirmed_by_name = null, confirmed_at = null");
  if (!updated) return res.status(409).json({ error: '발송된 리포트만 새 판을 만들 수 있습니다. 확정 전이면 확정 취소를 사용해 주세요.' });
  res.json(toAiReportJson(updated));
});

// 삭제. 발송된 리포트면 양식장이 받은 발송본도 함께 사라진다(화면에서 한 번 더 묻는다).
aiReportsRouter.delete('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const row = await loadReport(orgId, req.params.id);
  if (!row) return res.status(404).json({ error: 'AI 리포트를 찾을 수 없습니다.' });
  await query('delete from ai_reports where id = $1', [row.id]);
  res.status(204).end();
});
