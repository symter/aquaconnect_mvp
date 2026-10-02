import { Router } from 'express';

import { hashPassword, requireAuth, signToken, verifyPassword } from '../auth.js';
import { pool, query } from '../db.js';
import {
  digitsOnly,
  formatPhone,
  normalizeEmail,
  validateBizRegNo,
  validateEmail,
  validatePassword,
  validatePhone,
} from '../lib/validators.js';

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
    // `isOwner` is derived from `role`, not the separate `is_owner` column
    // — the two are independently writable with no DB-level sync, and the
    // client already ignores the wire `isOwner` in favor of deriving it
    // from `role` too (see Member.isOwner in member.dart), so `role` is the
    // single source of truth here.
    member: { id: row.id, orgId: row.org_id, name: row.name, role: row.role, isOwner: row.role === 'owner', phone: row.phone },
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

// ── Signup (ported from aquaconnect_web, minus the business-certificate
// upload and admin approval: a new institute and its owner account are
// usable immediately) ──────────────────────────────────────────────────

export const TERMS_VERSION = '2026-10-01';

authRouter.get('/terms', (req, res) => {
  res.json({ termsVersion: TERMS_VERSION });
});

async function emailTaken(email) {
  const { rows } = await query('select 1 from members where lower(email) = $1', [normalizeEmail(email)]);
  return rows.length > 0;
}

authRouter.get('/check-email', async (req, res) => {
  const error = validateEmail(req.query.email);
  if (error) return res.status(400).json({ error });
  res.json({ available: !(await emailTaken(req.query.email)) });
});

// Unauthenticated and bcrypt-heavy: cap signups per client IP.
const SIGNUPS_PER_IP_PER_HOUR = 10;
const signupHits = new Map();

function tooManySignups(req) {
  const ip = String(req.headers['x-forwarded-for'] ?? req.socket.remoteAddress ?? '').split(',')[0].trim();
  const now = Date.now();
  const recent = (signupHits.get(ip) ?? []).filter((t) => now - t < 3600_000);
  if (recent.length >= SIGNUPS_PER_IP_PER_HOUR) return true;
  recent.push(now);
  signupHits.set(ip, recent);
  return false;
}

function validateSignup(body) {
  const { account = {}, organization = {}, terms = {} } = body ?? {};
  if (terms.termsAgreed !== true || terms.privacyAgreed !== true) return '필수 약관에 동의해야 가입할 수 있습니다.';
  if (!String(account.name ?? '').trim()) return '대표자명을 입력해 주세요.';
  const checks = [validateEmail(account.email), validatePassword(account.password), validatePhone(account.phone)];
  if (!String(organization.name ?? '').trim()) return '수산질병관리원명을 입력해 주세요.';
  if (!String(organization.address ?? '').trim()) return '관리원 주소를 입력해 주세요.';
  // 사업자등록번호 is optional; when given it must be a possible number.
  if (digitsOnly(organization.businessRegNo)) checks.push(validateBizRegNo(organization.businessRegNo));
  return checks.find((c) => c) ?? null;
}

authRouter.post('/signup', async (req, res) => {
  const error = validateSignup(req.body);
  if (error) return res.status(400).json({ error });
  if (tooManySignups(req)) return res.status(429).json({ error: '가입 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.' });

  const { account, organization, terms } = req.body;
  const email = normalizeEmail(account.email);
  const bizRegNo = digitsOnly(organization.businessRegNo) || null;

  if (await emailTaken(email)) return res.status(409).json({ error: '이미 가입된 이메일입니다.' });
  if (bizRegNo) {
    const { rows } = await query('select 1 from organizations where business_reg_no = $1', [bizRegNo]);
    if (rows[0]) return res.status(409).json({ error: '이미 등록된 사업자등록번호입니다.' });
  }

  const passwordHash = await hashPassword(account.password);
  const client = await pool.connect();
  let memberId;
  try {
    await client.query('begin');
    const { rows: orgRows } = await client.query(
      'insert into organizations (name, business_reg_no, address, phone) values ($1, $2, $3, $4) returning id',
      [organization.name.trim(), bizRegNo, organization.address.trim(), formatPhone(account.phone)],
    );
    const { rows: memberRows } = await client.query(
      `insert into members
         (org_id, name, email, password_hash, is_owner, role, phone,
          terms_version, terms_agreed_at, privacy_agreed_at, marketing_agreed)
       values ($1, $2, $3, $4, true, 'owner', $5, $6, now(), now(), $7)
       returning id`,
      [
        orgRows[0].id,
        account.name.trim(),
        email,
        passwordHash,
        formatPhone(account.phone),
        String(terms.termsVersion || TERMS_VERSION),
        terms.marketingAgreed === true,
      ],
    );
    memberId = memberRows[0].id;
    await client.query('commit');
  } catch (err) {
    await client.query('rollback');
    // Two signups racing for the same email / 사업자등록번호.
    if (err.code === '23505') return res.status(409).json({ error: '이미 가입된 이메일 또는 사업자등록번호입니다.' });
    throw err;
  } finally {
    client.release();
  }

  const row = await memberWithOrg(memberId);
  res.status(201).json({ token: signToken(memberId), ...toSessionJson(row) });
});
