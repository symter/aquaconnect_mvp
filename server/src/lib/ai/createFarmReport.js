// 양식장 AI 리포트 한 건을 만들어 저장한다. 앱의 '새 AI 리포트'(routes/aiReports.js)와
// 월간 자동 생성(lib/monthlyReports.js)이 함께 쓴다.

import { query } from '../../db.js';
import { draftFarmReport } from './farmReport.js';
import { AiError } from './model.js';
import { modelPlan, recordUsage } from './usage.js';

// 메모가 많으면 묶음별 중간 정리를 거쳐 만든다(staged.js).
export const MAX_MEMOS = 600;

const kstStart = (date) => new Date(`${date}T00:00:00+09:00`);

/**
 * from/to: 'YYYY-MM-DD'(KST, 양끝 포함, 이미 검증된 값). memoIds 없으면 기간 메모 전부.
 * memberId/createdByName: 만든 사람(자동 생성이면 null / '자동 생성').
 * 저장된 ai_reports 행을 돌려준다. 메모가 없거나 AI 오류면 AiError.
 */
export async function createFarmReport({ orgId, farm, from, to, memoIds = null, includeComments = true, provider, memberId = null, createdByName, source = 'manual' }) {
  const start = kstStart(from);
  const endExclusive = new Date(kstStart(to).getTime() + 86400_000);
  const days = Math.round((endExclusive - start) / 86400_000);

  const { rows: periodMemos } = await query(
    `select id, content, tags, author_type, author_name, created_at from memos
      where farm_id = $1 and created_at >= $2 and created_at < $3 order by created_at`,
    [farm.id, start, endExclusive],
  );
  let selected = periodMemos;
  if (Array.isArray(memoIds)) {
    const wanted = new Set(memoIds.map(String));
    selected = periodMemos.filter((m) => wanted.has(m.id));
  }
  if (selected.length === 0) throw new AiError('선택한 기간에 리포트에 넣을 메모가 없습니다.', 400);
  if (selected.length > MAX_MEMOS) throw new AiError(`메모는 한 번에 ${MAX_MEMOS}건까지 넣을 수 있습니다. 기간을 줄여 주세요.`, 400);

  let comments = [];
  if (includeComments) {
    const ids = new Set(selected.map((m) => m.id));
    const { rows } = await query(
      `select c.memo_id, c.author_name, c.content, c.created_at from memo_comments c
         join memos mm on mm.id = c.memo_id
        where mm.farm_id = $1 and mm.created_at >= $2 and mm.created_at < $3 order by c.created_at`,
      [farm.id, start, endExclusive],
    );
    comments = rows.filter((c) => ids.has(c.memo_id));
  }

  const prevStart = new Date(start.getTime() - days * 86400_000);
  const { rows: prevMemos } = await query(
    `select id, content, tags, author_type, author_name, created_at from memos
      where farm_id = $1 and created_at >= $2 and created_at < $3 order by created_at limit $4`,
    [farm.id, prevStart, start, MAX_MEMOS],
  );

  const result = await draftFarmReport({
    farm,
    from,
    to,
    memos: selected,
    comments,
    prevMemos,
    candidates: periodMemos.length,
    plan: await modelPlan(provider),
    onResult: (r) => recordUsage({ orgId, memberId, ...r }),
  });

  const { rows } = await query(
    `insert into ai_reports
       (org_id, farm_id, type, period_start, period_end, model, prompt_version, memo_count, comment_count,
        input_snapshot, raw_draft, draft, checks, ai_body, body, created_by, created_by_name, source)
     values ($1,$2,'farm',$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$13,$14,$15,$16)
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
      memberId,
      createdByName,
      source,
    ],
  );
  return rows[0];
}
