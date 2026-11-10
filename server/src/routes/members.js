import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { query } from '../db.js';
import { recordAudit } from '../lib/audit.js';
import { IN_APP_ROLES, ROLE_LABEL, ROLE_ORDER_SQL, isDirector } from '../lib/roles.js';

export const membersRouter = Router();
membersRouter.use(requireAuth);

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

// Shared guard for role / status changes on another member: only 원장
// manages staff, and 원장 accounts themselves are changed only from the
// admin dashboard.
function guard(actor, target) {
  if (!target) return [404, '구성원을 찾을 수 없습니다.'];
  if (!isDirector(actor)) return [403, '원장만 직원을 관리할 수 있습니다.'];
  if (target.id === actor.id) return [400, '본인은 변경할 수 없습니다.'];
  if (isDirector(target)) return [400, '원장 계정은 관리자에게 요청해 변경할 수 있습니다.'];
  return null;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
membersRouter.param('id', (req, res, next, id) => (UUID_RE.test(id) ? next() : res.status(404).json({ error: '구성원을 찾을 수 없습니다.' })));

membersRouter.get('/', async (req, res) => {
  const { rows } = await query(
    `select * from members where org_id = (select org_id from members where id = $1)
     order by ${ROLE_ORDER_SQL('role')}, created_at`,
    [req.memberId],
  );
  res.json(rows.map((r) => toMemberJson(r, req.memberId)));
});

membersRouter.patch('/:id/role', async (req, res) => {
  const role = req.body?.role;
  if (!IN_APP_ROLES.includes(role)) return res.status(400).json({ error: '지정할 수 없는 역할입니다. 원장 권한은 관리자에게 요청해 주세요.' });
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
