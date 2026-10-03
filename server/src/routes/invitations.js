import crypto from 'node:crypto';

import { Router } from 'express';

import { hashPassword, requireAuth, signToken } from '../auth.js';
import { pool, query } from '../db.js';
import { recordAudit } from '../lib/audit.js';
import { formatPhone, normalizeEmail, validateEmail, validatePassword, validatePhone } from '../lib/validators.js';
import { TERMS_VERSION, memberWithOrg, toSessionJson, tooManySignups } from './auth.js';

const ROLE_LABEL = { director: '원장', staff: '수산질병관리사', employee: '직원' };
const EXPIRE_DAYS = [7, 30];
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Unambiguous characters (no 0/O, 1/I/L) so a code read aloud still works.
const CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
function newCode() {
  const bytes = crypto.randomBytes(10);
  return [...bytes].map((b) => CODE_CHARS[b % CODE_CHARS.length]).join('');
}

function inviteStatus(row) {
  if (row.accepted_at) return 'accepted';
  if (row.revoked_at) return 'cancelled';
  if (new Date(row.expires_at) <= new Date()) return 'expired';
  return 'pending';
}

function toInvitationJson(row) {
  return {
    id: row.id,
    code: row.code,
    role: row.role,
    note: row.note,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    status: inviteStatus(row),
  };
}

// ── Institute side (signed in) ──────────────────────────────────────────

export const invitationsRouter = Router();
invitationsRouter.use(requireAuth);

async function manager(req, res) {
  const { rows } = await query('select id, org_id, role from members where id = $1', [req.memberId]);
  const me = rows[0];
  if (!['owner', 'director'].includes(me?.role)) {
    res.status(403).json({ error: '소유자·원장만 구성원을 초대할 수 있습니다.' });
    return null;
  }
  return me;
}

async function ownInvitation(req, res, me) {
  if (!UUID_RE.test(req.params.id)) {
    res.status(404).json({ error: '초대를 찾을 수 없습니다.' });
    return null;
  }
  const { rows } = await query('select * from invitations where id = $1 and org_id = $2', [req.params.id, me.org_id]);
  if (!rows[0]) res.status(404).json({ error: '초대를 찾을 수 없습니다.' });
  return rows[0] ?? null;
}

// Invitations still waiting to be used (expired ones too, so they can be
// extended); used and cancelled ones drop off the list.
invitationsRouter.get('/', async (req, res) => {
  const { rows } = await query(
    `select * from invitations
     where org_id = (select org_id from members where id = $1) and accepted_at is null and revoked_at is null
     order by created_at desc`,
    [req.memberId],
  );
  res.json(rows.map(toInvitationJson));
});

invitationsRouter.post('/', async (req, res) => {
  const me = await manager(req, res);
  if (!me) return;
  const role = req.body?.role;
  const expireDays = Number(req.body?.expireDays ?? 7);
  const note = String(req.body?.note ?? '').trim().slice(0, 60);
  if (!ROLE_LABEL[role]) return res.status(400).json({ error: '초대할 수 없는 역할입니다.' });
  if (!EXPIRE_DAYS.includes(expireDays)) return res.status(400).json({ error: '만료 기한은 7일 또는 30일입니다.' });

  const { rows } = await query(
    `insert into invitations (org_id, code, role, note, created_by, expires_at)
     values ($1, $2, $3, $4, $5, now() + make_interval(days => $6))
     returning *`,
    [me.org_id, newCode(), role, note, me.id, expireDays],
  );
  await recordAudit({
    orgId: me.org_id,
    actorId: me.id,
    entityType: 'member',
    entityName: note || '초대 링크',
    action: 'invite',
    changes: [{ field: 'role', label: '초대 역할', from: '', to: ROLE_LABEL[role] }],
  });
  res.status(201).json(toInvitationJson(rows[0]));
});

// 기한 연장: always grants 7 more days from now, whatever the invite's original duration was.
invitationsRouter.post('/:id/extend', async (req, res) => {
  const me = await manager(req, res);
  if (!me) return;
  const inv = await ownInvitation(req, res, me);
  if (!inv) return;
  if (inv.accepted_at || inv.revoked_at) return res.status(400).json({ error: '이미 사용되었거나 취소된 초대입니다.' });
  const { rows } = await query(
    'update invitations set expires_at = now() + make_interval(days => 7), created_at = now() where id = $1 returning *',
    [inv.id],
  );
  res.json(toInvitationJson(rows[0]));
});

invitationsRouter.post('/:id/cancel', async (req, res) => {
  const me = await manager(req, res);
  if (!me) return;
  const inv = await ownInvitation(req, res, me);
  if (!inv) return;
  if (inv.accepted_at) return res.status(400).json({ error: '이미 수락된 초대입니다.' });
  const { rows } = await query('update invitations set revoked_at = coalesce(revoked_at, now()) where id = $1 returning *', [inv.id]);
  await recordAudit({
    orgId: me.org_id,
    actorId: me.id,
    entityType: 'member',
    entityName: inv.note || '초대 링크',
    action: 'invite_cancel',
  });
  res.json(toInvitationJson(rows[0]));
});

// ── Public side (the invite link) ───────────────────────────────────────

export const publicInvitationsRouter = Router();

const UNUSABLE = {
  accepted: '이미 사용된 초대 링크입니다.',
  cancelled: '취소된 초대 링크입니다.',
  expired: '만료된 초대 링크입니다. 초대한 분께 새 링크를 요청해 주세요.',
};

async function invitationByCode(code) {
  const { rows } = await query(
    `select i.*, o.name as org_name, m.name as inviter_name
     from invitations i join organizations o on o.id = i.org_id left join members m on m.id = i.created_by
     where i.code = $1`,
    [String(code ?? '').toUpperCase()],
  );
  return rows[0] ?? null;
}

publicInvitationsRouter.get('/:code', async (req, res) => {
  const inv = await invitationByCode(req.params.code);
  if (!inv) return res.status(404).json({ error: '존재하지 않는 초대 링크입니다.' });
  const status = inviteStatus(inv);
  if (status !== 'pending') return res.status(410).json({ error: UNUSABLE[status], status });
  res.json({
    orgName: inv.org_name,
    role: inv.role,
    inviterName: inv.inviter_name ?? '',
    expiresAt: inv.expires_at,
    termsVersion: TERMS_VERSION,
  });
});

// Signs up into the inviting institute with the invited role and signs in.
publicInvitationsRouter.post('/:code/accept', async (req, res) => {
  const { account = {}, terms = {} } = req.body ?? {};
  if (terms.termsAgreed !== true || terms.privacyAgreed !== true) {
    return res.status(400).json({ error: '필수 약관에 동의해야 가입할 수 있습니다.' });
  }
  if (!String(account.name ?? '').trim()) return res.status(400).json({ error: '이름을 입력해 주세요.' });
  const invalid = validateEmail(account.email) ?? validatePassword(account.password) ?? validatePhone(account.phone);
  if (invalid) return res.status(400).json({ error: invalid });
  if (tooManySignups(req)) return res.status(429).json({ error: '가입 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.' });

  const email = normalizeEmail(account.email);
  const { rows: taken } = await query('select 1 from members where lower(email) = $1', [email]);
  if (taken[0]) return res.status(409).json({ error: '이미 가입된 이메일입니다. 다른 이메일을 사용해 주세요.' });

  const passwordHash = await hashPassword(account.password);
  const client = await pool.connect();
  let memberId;
  let inv;
  try {
    await client.query('begin');
    // Claim the invitation in the same transaction, so a link can only
    // ever be used once even if two people submit at the same time.
    const { rows } = await client.query(
      `update invitations set accepted_at = now()
       where code = $1 and accepted_at is null and revoked_at is null and expires_at > now()
       returning *`,
      [String(req.params.code ?? '').toUpperCase()],
    );
    inv = rows[0];
    if (!inv) {
      await client.query('rollback');
      const current = await invitationByCode(req.params.code);
      if (!current) return res.status(404).json({ error: '존재하지 않는 초대 링크입니다.' });
      return res.status(410).json({ error: UNUSABLE[inviteStatus(current)] ?? '사용할 수 없는 초대 링크입니다.' });
    }
    const { rows: memberRows } = await client.query(
      `insert into members
         (org_id, name, email, password_hash, role, phone, terms_version, terms_agreed_at, privacy_agreed_at, marketing_agreed)
       values ($1, $2, $3, $4, $5, $6, $7, now(), now(), $8)
       returning id`,
      [inv.org_id, account.name.trim(), email, passwordHash, inv.role, formatPhone(account.phone), String(terms.termsVersion || TERMS_VERSION), terms.marketingAgreed === true],
    );
    memberId = memberRows[0].id;
    await client.query('update invitations set accepted_member_id = $2 where id = $1', [inv.id, memberId]);
    await client.query('commit');
  } catch (err) {
    await client.query('rollback');
    if (err.code === '23505') return res.status(409).json({ error: '이미 가입된 이메일입니다. 다른 이메일을 사용해 주세요.' });
    throw err;
  } finally {
    client.release();
  }

  await recordAudit({
    orgId: inv.org_id,
    actorId: memberId,
    entityType: 'member',
    entityId: memberId,
    entityName: account.name.trim(),
    action: 'join',
    changes: [{ field: 'role', label: '역할', from: '', to: ROLE_LABEL[inv.role] }],
  });
  const row = await memberWithOrg(memberId);
  res.status(201).json({ token: signToken(memberId), ...toSessionJson(row) });
});
