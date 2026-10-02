import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

import { query } from './db.js';

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET is not set.');
}

const TOKEN_TTL = '30d';

export const hashPassword = (plain) => bcrypt.hash(plain, 10);
export const verifyPassword = (plain, hash) => bcrypt.compare(plain, hash);

export const signToken = (memberId) => jwt.sign({ sub: memberId }, JWT_SECRET, { expiresIn: TOKEN_TTL });

export async function requireAuth(req, res, next) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: '로그인이 필요합니다.' });
  }
  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch {
    return res.status(401).json({ error: '세션이 만료되었습니다. 다시 로그인해주세요.' });
  }
  // A deactivated member loses access right away, not when the token expires.
  const { rows } = await query('select status from members where id = $1', [payload.sub]);
  if (rows[0]?.status !== 'active') {
    return res.status(401).json({ error: '비활성화된 계정입니다. 관리원에 문의해주세요.' });
  }
  req.memberId = payload.sub;
  next();
}
