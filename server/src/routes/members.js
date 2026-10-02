import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { pool, query } from '../db.js';
import { recordAudit } from '../lib/audit.js';

export const membersRouter = Router();
membersRouter.use(requireAuth);

const ROLE_LABEL = { owner: '소유자', director: '원장', staff: '수산질병관리사', employee: '직원' };
const ASSIGNABLE_ROLES = ['director', 'staff', 'employee'];

function toMemberJson(row, meId) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone,
    role: row.role,
    status: row.status,
    joinedAt: row.created_at,
    isMe: row.id === meId,
  };
}

async function actorAndTarget(req) {
  const { rows } = await query('select * from members where id = any($1::uuid[])', [[req.memberId, req.params.id]]);
  const actor = rows.find((r) => r.id === req.memberId);
  const target = rows.find((r) => r.id === req.params.id && r.org_id === actor?.org_id);
  return { actor, target };
}

// Shared guard for role / status changes on another member.
function guard(actor, target) {
  if (!target) return [404, '구성원을 찾을 수 없습니다.'];
  if (!['owner', 'director'].includes(actor.role)) return [403, '소유자·원장만 구성원을 관리할 수 있습니다.'];
  if (target.id === actor.id) return [400, '본인은 변경할 수 없습니다.'];
  if (target.role === 'owner') return [400, '소유자는 변경할 수 없습니다. 소유자 양도를 이용해 주세요.'];
  return null;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
membersRouter.param('id', (req, res, next, id) => (UUID_RE.test(id) ? next() : res.status(404).json({ error: '구성원을 찾을 수 없습니다.' })));

membersRouter.get('/', async (req, res) => {
  const { rows } = await query(
    `select * from members where org_id = (select org_id from members where id = $1)
     order by case role when 'owner' then 0 when 'director' then 1 when 'staff' then 2 else 3 end, created_at`,
    [req.memberId],
  );
  res.json(rows.map((r) => toMemberJson(r, req.memberId)));
});

membersRouter.patch('/:id/role', async (req, res) => {
  const role = req.body?.role;
  if (!ASSIGNABLE_ROLES.includes(role)) return res.status(400).json({ error: '지정할 수 없는 역할입니다.' });
  const { actor, target } = await actorAndTarget(req);
  const denied = guard(actor, target);
  if (denied) return res.status(denied[0]).json({ error: denied[1] });
  if (target.role === role) return res.json(toMemberJson(target, req.memberId));

  const { rows } = await query('update members set role = $2 where id = $1 returning *', [target.id, role]);
  await recordAudit({
    orgId: actor.org_id,
    actorId: actor.id,
    entityType: 'member',
    entityId: target.id,
    entityName: target.name,
    action: 'role_change',
    changes: [{ field: 'role', label: '역할', from: ROLE_LABEL[target.role], to: ROLE_LABEL[role] }],
  });
  res.json(toMemberJson(rows[0], req.memberId));
});

async function setStatus(req, res, status) {
  const { actor, target } = await actorAndTarget(req);
  const denied = guard(actor, target);
  if (denied) return res.status(denied[0]).json({ error: denied[1] });
  if (target.status === status) return res.json(toMemberJson(target, req.memberId));

  const { rows } = await query('update members set status = $2 where id = $1 returning *', [target.id, status]);
  await recordAudit({
    orgId: actor.org_id,
    actorId: actor.id,
    entityType: 'member',
    entityId: target.id,
    entityName: target.name,
    action: status === 'inactive' ? 'deactivate' : 'reactivate',
    changes: [{ field: 'status', label: '상태', from: target.status === 'active' ? '활성' : '비활성', to: status === 'active' ? '활성' : '비활성' }],
  });
  res.json(toMemberJson(rows[0], req.memberId));
}

membersRouter.post('/:id/deactivate', (req, res) => setStatus(req, res, 'inactive'));
membersRouter.post('/:id/reactivate', (req, res) => setStatus(req, res, 'active'));

// Owner hands ownership to another active member and becomes 원장.
membersRouter.post('/:id/transfer-ownership', async (req, res) => {
  const { actor, target } = await actorAndTarget(req);
  if (!target) return res.status(404).json({ error: '구성원을 찾을 수 없습니다.' });
  if (actor.role !== 'owner') return res.status(403).json({ error: '소유자만 소유자를 양도할 수 있습니다.' });
  if (target.id === actor.id) return res.status(400).json({ error: '이미 소유자입니다.' });
  if (target.status !== 'active') return res.status(400).json({ error: '비활성 구성원에게는 양도할 수 없습니다.' });

  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query("update members set role = 'director', is_owner = false where id = $1", [actor.id]);
    await client.query("update members set role = 'owner', is_owner = true where id = $1", [target.id]);
    await client.query('commit');
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
  }
  await recordAudit({
    orgId: actor.org_id,
    actorId: actor.id,
    entityType: 'member',
    entityId: target.id,
    entityName: target.name,
    action: 'owner_transfer',
    changes: [
      { field: 'role', label: `${target.name} 역할`, from: ROLE_LABEL[target.role], to: '소유자' },
      { field: 'role', label: `${actor.name} 역할`, from: '소유자', to: '원장' },
    ],
  });
  res.json({ ok: true });
});
