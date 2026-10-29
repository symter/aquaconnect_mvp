import { Router } from 'express';

import { query } from '../db.js';
import { notifyMembers } from '../lib/notify.js';
import { loadFarmRows, toFarmJson } from './farms.js';
import { buildAndPersistReport, latestReportRow, toReportJson } from './reports.js';

// No requireAuth here on purpose: this is what a farm owner opens from a
// share link on their own phone, with no AquaConnect account.
export const publicRouter = Router();

publicRouter.get('/reports/:token', async (req, res) => {
  const { rows } = await query('select * from share_links where token = $1', [req.params.token]);
  const link = rows[0];

  const isActive = link && !link.revoked_at && (!link.expires_at || new Date(link.expires_at) > new Date());
  if (!isActive) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });

  const [farm] = await loadFarmRows('f.id = $1', [link.farm_id]);
  if (!farm) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });

  let reportRow = await latestReportRow(farm.id);
  const report = reportRow ? toReportJson(reportRow) : await buildAndPersistReport(farm);

  const { rows: extraRows } = await query(
    `select o.name as organization_name, m.phone as assigned_member_phone
     from organizations o left join members m on m.id = $2
     where o.id = $1`,
    [farm.org_id, farm.assigned_member_id],
  );

  res.json({
    organizationName: extraRows[0]?.organization_name ?? null,
    assignedMemberPhone: extraRows[0]?.assigned_member_phone ?? null,
    farm: toFarmJson(farm),
    report,
    link: { id: link.id, farmId: link.farm_id, token: link.token, createdAt: link.created_at, expiresAt: link.expires_at, revokedAt: link.revoked_at },
  });
});

async function activeLink(token) {
  const { rows } = await query('select * from share_links where token = $1', [token]);
  const link = rows[0];
  const isActive = link && !link.revoked_at && (!link.expires_at || new Date(link.expires_at) > new Date());
  return isActive ? link : null;
}

const ymd = (value) => {
  if (typeof value === 'string') return value.slice(0, 10);
  const d = new Date(value);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

/** 양식장이 받은 AI 관리 리포트(발송 스냅샷) — 메모 원문·검증 메모 같은 내부 자료는 싣지 않는다. */
function toSentAiReportJson(s) {
  return {
    id: s.report_id,
    type: 'farm',
    farmId: s.farm_id,
    farmName: s.farm_name,
    orgName: s.org_name,
    periodStart: ymd(s.period_start),
    periodEnd: ymd(s.period_end),
    status: 'sent',
    version: s.version,
    model: '',
    memoCount: s.memo_count,
    commentCount: s.comment_count,
    checkCount: 0,
    edited: (s.edited_sections ?? []).length > 0,
    createdByName: '',
    createdAt: s.sent_at,
    confirmedByName: s.approved_by_name,
    confirmedAt: s.approved_at,
    sentByName: s.sent_by_name,
    sentAt: s.sent_at,
    body: s.body,
    finalOpinion: s.final_opinion,
    editedSections: s.edited_sections ?? [],
    meta: s.meta,
  };
}

// 받은 AI 관리 리포트 목록: 리포트마다 가장 최근 발송본 하나(새 판을 만들어도 다시 발송될 때까지 이전 발송본).
publicRouter.get('/reports/:token/ai-reports', async (req, res) => {
  const link = await activeLink(req.params.token);
  if (!link) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });
  const { rows } = await query(
    `select * from (
       select distinct on (report_id) * from ai_report_sends where farm_id = $1 order by report_id, sent_at desc
     ) latest order by sent_at desc`,
    [link.farm_id],
  );
  res.json(rows.map((s) => ({ ...toSentAiReportJson(s), body: undefined, meta: undefined })));
});

publicRouter.get('/reports/:token/ai-reports/:reportId', async (req, res) => {
  const link = await activeLink(req.params.token);
  if (!link) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });
  if (!/^[0-9a-f-]{36}$/i.test(req.params.reportId)) return res.status(404).json({ error: '리포트를 찾을 수 없습니다.' });
  const { rows } = await query(
    'select * from ai_report_sends where farm_id = $1 and report_id = $2 order by sent_at desc limit 1',
    [link.farm_id, req.params.reportId],
  );
  if (!rows[0]) return res.status(404).json({ error: '리포트를 찾을 수 없습니다.' });
  res.json(toSentAiReportJson(rows[0]));
});

const INQUIRY_MAX_LENGTH = 500;
// No login on this route, so cap how fast one link can post.
const INQUIRIES_PER_LINK_PER_HOUR = 10;

// 문의 from the farm's shared report page. Stored, mirrored into the memo
// feed (author_type 'farm', tag 문의) and pushed to the institute.
publicRouter.post('/reports/:token/inquiries', async (req, res) => {
  const { rows } = await query('select * from share_links where token = $1', [req.params.token]);
  const link = rows[0];
  const isActive = link && !link.revoked_at && (!link.expires_at || new Date(link.expires_at) > new Date());
  if (!isActive) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });

  const message = typeof req.body?.message === 'string' ? req.body.message.trim() : '';
  if (!message) return res.status(400).json({ error: '문의 내용을 입력해주세요.' });
  if (message.length > INQUIRY_MAX_LENGTH) {
    return res.status(400).json({ error: `문의 내용은 ${INQUIRY_MAX_LENGTH}자 이내로 입력해주세요.` });
  }

  const { rows: recent } = await query(
    "select count(*)::int as c from inquiries where share_link_id = $1 and created_at > now() - interval '1 hour'",
    [link.id],
  );
  if (recent[0].c >= INQUIRIES_PER_LINK_PER_HOUR) {
    return res.status(429).json({ error: '문의가 너무 많습니다. 잠시 후 다시 시도해주세요.' });
  }

  const { rows: farmRows } = await query('select id, org_id, name from farms where id = $1', [link.farm_id]);
  const farm = farmRows[0];
  if (!farm) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });

  await query('insert into inquiries (share_link_id, farm_id, message) values ($1, $2, $3)', [link.id, farm.id, message]);
  const { rows: memoRows } = await query(
    `insert into memos (org_id, farm_id, author_type, author_name, content, tags)
     values ($1, $2, 'farm', $3, $4, $5) returning id`,
    [farm.org_id, farm.id, `어가 · ${farm.name}`, message, ['문의']],
  );

  const preview = message.replace(/\s+/g, ' ');
  await notifyMembers({
    orgId: farm.org_id,
    type: 'inquiry',
    title: `어가 문의 · ${farm.name}`,
    body: preview.length > 80 ? `${preview.slice(0, 80)}…` : preview,
    link: `/memo?memo=${memoRows[0].id}`,
  });

  res.status(201).json({ ok: true });
});
