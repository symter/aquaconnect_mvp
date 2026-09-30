// One-off cleanup for a database that was seeded by the old `npm run seed`
// (demo farms 신일수산 1양식장 / 미래수산 / 청해양식장, their memos and
// reports, 3 demo disease-info rows, and the `/r/demo` share link).
// Matches only those exact demo rows, so anything users entered stays.
// The org and the owner login are kept.
//
//   npm run clear-demo            # dry run: prints what would be deleted
//   npm run clear-demo -- --yes   # actually deletes

import 'dotenv/config';
import { pool } from '../src/db.js';

const DEMO_FARMS = [
  ['신일수산 1양식장', '완도군 노화읍'],
  ['미래수산', '완도군 금일읍'],
  ['청해양식장', '해남군 화산면'],
];
const DEMO_UNASSIGNED_MEMO = 'GLOBEFISH 뉴스 확인 — 동남아 AHPND 확산, 국내 영향 여부 계속 모니터링.';
const DEMO_DISEASE_TITLES = [
  '전남 해역 넙치 에드워드시엘라증 산발 신고',
  '동남아 새우 AHPND 확산 — 국내 어종 무관',
  '노르웨이 연어 ISA 바이러스 발생 보고',
];

const apply = process.argv.includes('--yes');

async function main() {
  const client = await pool.connect();
  try {
    await client.query('begin');

    const farmIds = [];
    for (const [name, address] of DEMO_FARMS) {
      const { rows } = await client.query('select id from farms where name = $1 and address = $2', [name, address]);
      farmIds.push(...rows.map((r) => r.id));
    }

    const counts = {};
    const run = async (label, sql, params) => {
      const { rowCount } = await client.query(sql, params);
      counts[label] = (counts[label] ?? 0) + rowCount;
    };

    await run('share_links (/r/demo)', "delete from share_links where token = 'demo'");
    for (const id of farmIds) {
      // memos.farm_id is ON DELETE SET NULL, so remove them explicitly;
      // reports / share_links / memo_photos cascade.
      await run('memos', 'delete from memos where farm_id = $1', [id]);
      await run('farms', 'delete from farms where id = $1', [id]);
    }
    await run('memos', 'delete from memos where farm_id is null and content = $1', [DEMO_UNASSIGNED_MEMO]);
    for (const title of DEMO_DISEASE_TITLES) {
      await run('disease_info', 'delete from disease_info where title = $1', [title]);
    }

    console.table(counts);
    if (apply) {
      await client.query('commit');
      console.log('Demo data deleted.');
    } else {
      await client.query('rollback');
      console.log('Dry run — nothing deleted. Re-run with --yes to apply.');
    }
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
