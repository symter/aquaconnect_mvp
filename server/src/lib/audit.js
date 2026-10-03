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
export async function recordAudit({ orgId, actorId, entityType, entityId = null, entityName = '', action, changes = [] }) {
  try {
    const { rows } = actorId ? await query('select name from members where id = $1', [actorId]) : { rows: [] };
    await query(
      `insert into audit_logs (org_id, actor_member_id, actor_name, entity_type, entity_id, entity_name, action, changes)
       values ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [orgId, actorId ?? null, rows[0]?.name ?? '', entityType, entityId, entityName, action, JSON.stringify(changes)],
    );
  } catch (err) {
    console.error('recordAudit failed', err);
  }
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
