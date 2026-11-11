import { query } from '../db.js';

// 변경 이력 is kept for 3 months, then deleted.
export const AUDIT_RETENTION = '3 months';
const PURGE_EVERY_MS = 6 * 60 * 60 * 1000;

// Field-by-field diff for an update: [{ field, label, from, to }] for the
// fields whose value actually changed. `fields` is [[key, label], ...].
export function diffFields(before, after, fields) {
  const norm = (v) => (v == null ? '' : String(v));
  return fields
    .filter(([key]) => norm(before[key]) !== norm(after[key]))
    .map(([key, label]) => ({ field: key, label, from: norm(before[key]), to: norm(after[key]) }));
}

// Records one 변경 이력 entry. Never throws — a failed log must not fail
// the change it describes.
// [actorName] stands in for a non-member actor (the admin dashboard).
export async function recordAudit({ orgId, actorId, actorName, entityType, entityId = null, entityName = '', action, changes = [] }) {
  try {
    const { rows } = actorId ? await query('select name from members where id = $1', [actorId]) : { rows: [] };
    await query(
      `insert into audit_logs (org_id, actor_member_id, actor_name, entity_type, entity_id, entity_name, action, changes)
       values ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [orgId, actorId ?? null, rows[0]?.name ?? actorName ?? '', entityType, entityId, entityName, action, JSON.stringify(changes)],
    );
  } catch (err) {
    console.error('recordAudit failed', err);
  }
}

// 메모 기록 for 변경 이력. [memo] needs org_id, id and farm_name (the entry's
// title — a memo has no name of its own). Never throws.
export function recordMemoAudit({ memo, actorId, actorName, action, changes = [] }) {
  return recordAudit({
    orgId: memo.org_id,
    actorId,
    actorName,
    entityType: 'memo',
    entityId: memo.id,
    entityName: memo.farm_name || '양식장 미지정',
    action,
    changes,
  });
}

// One snapshot line ("내용: …") for a memo entry — [from] for something
// removed, [to] for something added.
export const memoLine = (label, { from = '', to = '' } = {}) => ({ field: label, label, from: String(from ?? ''), to: String(to ?? '') });

const KST_STAMP = new Intl.DateTimeFormat('ko-KR', {
  timeZone: 'Asia/Seoul',
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
});
export const kstStamp = (at) => (at ? KST_STAMP.format(new Date(at)) : '');

// Everything 원장 needs to know about a memo after it's deleted (the row,
// its comments and edits go with it). Call before deleting.
export async function memoDeleteSnapshot(memoId) {
  const { rows } = await query(
    `select mm.id, mm.org_id, mm.content, mm.author_name, mm.created_at, mm.done_at, mm.done_by_name,
            mm.photo_count, f.name as farm_name,
            (select count(*)::int from memo_comments c where c.memo_id = mm.id) as comment_count,
            (select count(*)::int from memo_edits e where e.memo_id = mm.id) as edit_count
     from memos mm left join farms f on f.id = mm.farm_id where mm.id = $1`,
    [memoId],
  );
  const m = rows[0];
  if (!m) return null;
  const author = m.author_name.replace(/^수산질병관리원 · /, '');
  const extras = [
    m.photo_count ? `사진 ${m.photo_count}장` : '',
    m.comment_count ? `댓글 ${m.comment_count}개` : '',
    m.edit_count ? `수정 ${m.edit_count}번` : '',
  ].filter(Boolean);
  return {
    memo: m,
    changes: [
      memoLine('내용', { from: m.content }),
      memoLine('작성', { from: `${author} · ${kstStamp(m.created_at)}` }),
      ...(m.done_at ? [memoLine('완료', { from: `${m.done_by_name ?? ''} · ${kstStamp(m.done_at)}` })] : []),
      ...(extras.length ? [memoLine('함께 삭제', { from: extras.join(', ') })] : []),
    ],
  };
}

// 변경 이력 lines for a deleted 댓글 (author_name, content, created_at,
// attachment_count).
export function deletedCommentLines(comment) {
  return [
    ...(comment.content ? [memoLine('댓글', { from: comment.content })] : []),
    memoLine('작성', { from: `${comment.author_name} · ${kstStamp(comment.created_at)}` }),
    ...(comment.attachment_count ? [memoLine('함께 삭제', { from: `첨부 ${comment.attachment_count}개` })] : []),
  ];
}

export async function purgeOldAuditLogs() {
  try {
    const { rowCount } = await query(`delete from audit_logs where created_at < now() - interval '${AUDIT_RETENTION}'`);
    if (rowCount) console.log(`audit: purged ${rowCount} entries older than ${AUDIT_RETENTION}`);
  } catch (err) {
    console.error('audit purge failed', err);
  }
}

// Purge on boot and every 6 hours while the server runs.
export function scheduleAuditPurge() {
  purgeOldAuditLogs();
  setInterval(purgeOldAuditLogs, PURGE_EVERY_MS).unref();
}
