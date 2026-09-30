// Creates the institute (organization) and its owner login — nothing else.
// Farms, memos, disease info and share links are only ever what users
// enter through the app. Safe to re-run: it never deletes anything, and
// skips creation if the owner email already exists.

import 'dotenv/config';
import { hashPassword } from '../src/auth.js';
import { pool, query } from '../src/db.js';

const ORG_NAME = process.env.SEED_ORG_NAME || '해강수산질병관리원';
const OWNER_NAME = process.env.SEED_OWNER_NAME || '이동길';
const OWNER_EMAIL = process.env.SEED_OWNER_EMAIL || 'leedonggil@haegang.kr';
const OWNER_PHONE = process.env.SEED_OWNER_PHONE || null;
const OWNER_PASSWORD = process.env.SEED_DEMO_PASSWORD || 'demo1234';

async function main() {
  const { rows: existing } = await query('select id from members where lower(email) = lower($1)', [OWNER_EMAIL]);
  if (existing[0]) {
    console.log(`Owner ${OWNER_EMAIL} already exists — nothing to do.`);
    await pool.end();
    return;
  }

  const { rows: orgRows } = await query('insert into organizations (name) values ($1) returning id', [ORG_NAME]);
  const passwordHash = await hashPassword(OWNER_PASSWORD);
  await query(
    `insert into members (org_id, name, email, password_hash, is_owner, role, phone)
     values ($1, $2, $3, $4, true, 'owner', $5)`,
    [orgRows[0].id, OWNER_NAME, OWNER_EMAIL, passwordHash, OWNER_PHONE],
  );

  console.log('Seed complete.');
  console.log(`Login: ${OWNER_EMAIL} / (SEED_DEMO_PASSWORD)`);
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
