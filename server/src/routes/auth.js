import { Router } from 'express';

import { requireAuth, signToken, verifyPassword } from '../auth.js';
import { query } from '../db.js';

export const authRouter = Router();

async function memberWithOrg(memberId) {
  const { rows } = await query(
    `select m.id, m.org_id, m.name, m.role, m.is_owner, m.phone, o.name as org_name
     from members m join organizations o on o.id = m.org_id
     where m.id = $1`,
    [memberId],
  );
  return rows[0] ?? null;
}

function toSessionJson(row) {
  return {
    member: { id: row.id, orgId: row.org_id, name: row.name, role: row.role, isOwner: row.is_owner, phone: row.phone },
    organization: { id: row.org_id, name: row.org_name },
  };
}

authRouter.post('/login', async (req, res) => {
  const { email, password } = req.body ?? {};
  if (!email || !password) {
    return res.status(400).json({ error: '이메일과 비밀번호를 입력해주세요.' });
  }

  const { rows } = await query(
    `select m.id, m.password_hash, m.org_id, m.name, m.role, m.is_owner, m.phone, o.name as org_name
     from members m join organizations o on o.id = m.org_id
     where lower(m.email) = lower($1)`,
    [email],
  );
  const row = rows[0];
  if (!row || !(await verifyPassword(password, row.password_hash))) {
    return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
  }

  const token = signToken(row.id);
  res.json({ token, ...toSessionJson(row) });
});

authRouter.get('/me', requireAuth, async (req, res) => {
  const row = await memberWithOrg(req.memberId);
  if (!row) return res.status(404).json({ error: '계정을 찾을 수 없습니다.' });
  res.json(toSessionJson(row));
});
