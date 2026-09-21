// Mirrors lib/data/mock/mock_seed.dart so a freshly-provisioned database
// looks identical to mock mode. Safe to re-run: it wipes and re-inserts
// (this is demo/seed data only, never run against a database with real
// institute data in it).

import 'dotenv/config';
import { hashPassword } from '../src/auth.js';
import { pool, query } from '../src/db.js';

const DEMO_PASSWORD = process.env.SEED_DEMO_PASSWORD || 'demo1234';

async function main() {
  await query('truncate share_links, reports, memos, disease_info, farms, members, organizations cascade');

  const { rows: orgRows } = await query('insert into organizations (name) values ($1) returning id', ['해강수산질병관리원']);
  const orgId = orgRows[0].id;

  const passwordHash = await hashPassword(DEMO_PASSWORD);
  const { rows: memberRows } = await query(
    `insert into members (org_id, name, email, password_hash, is_owner, phone)
     values ($1, '이동길', 'leedonggil@haegang.kr', $2, true, '010-0000-0000') returning id`,
    [orgId, passwordHash],
  );
  const memberId = memberRows[0].id;

  const farms = [
    {
      name: '신일수산 1양식장',
      region: '완도',
      address: '완도군 노화읍',
      // Real NIFS risaList station code for 완도 노화도 (nearest real
      // observation point to 노화읍) — see D:\202609\index.mjs / server/src/lib/nifs.js.
      stationCode: 'wn087',
      stationName: '완도',
      riskLevel: 'danger',
      headline: '오늘 폐사 12마리',
      waterTemp: 29.4,
      lastVisitDays: 9,
      ownerContact: '01011112222',
    },
    {
      name: '미래수산',
      region: '완도',
      address: '완도군 금일읍',
      // Real NIFS risaList station code for 완도 금일 (nearest real
      // observation point to 금일읍).
      stationCode: 'wk094',
      stationName: '완도',
      riskLevel: 'danger',
      headline: '폐사 신고 있음',
      waterTemp: 29.1,
      lastVisitDays: 12,
      ownerContact: '01022223333',
    },
    {
      name: '청해양식장',
      region: '해남',
      address: '해남군 화산면',
      // Real NIFS risaList station code for 해남 임하 (only 해남 station
      // in the feed).
      stationCode: 'fjh5a',
      stationName: '해남',
      riskLevel: 'warning',
      headline: '섭이 감소 보고',
      waterTemp: 28.6,
      lastVisitDays: 5,
      ownerContact: '01033334444',
    },
  ];

  const farmIds = {};
  for (const f of farms) {
    const { rows } = await query(
      `insert into farms
         (org_id, name, region, address, nearest_station_code, nearest_station_name, risk_level, headline,
          water_temp, last_visit_days, assigned_member_id, owner_contact)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning id`,
      [orgId, f.name, f.region, f.address, f.stationCode, f.stationName, f.riskLevel, f.headline, f.waterTemp, f.lastVisitDays, memberId, f.ownerContact],
    );
    farmIds[f.name] = rows[0].id;
  }

  const at = (daysAgo, hour, minute) => {
    const d = new Date();
    d.setHours(hour, minute, 0, 0);
    d.setDate(d.getDate() - daysAgo);
    return d.toISOString();
  };

  const memos = [
    {
      farmId: farmIds['신일수산 1양식장'],
      authorType: 'institute',
      authorName: '수산질병관리원 · 이동길',
      content: '3수조 유영 둔화 확인. 아가미 색 약간 창백. 내일 재방문해서 확인 필요.',
      tags: ['3수조', '유영 이상'],
      createdAt: at(0, 14, 32),
    },
    {
      farmId: farmIds['신일수산 1양식장'],
      authorType: 'farm',
      authorName: '어가 · 신일수산 1양식장',
      content: '오늘 아침 폐사 12마리 나왔습니다. 사진 첨부합니다.',
      tags: ['폐사 12마리'],
      createdAt: at(0, 8, 5),
      photoCount: 1,
      readByFarm: true,
    },
    {
      farmId: null,
      authorType: 'institute',
      authorName: '수산질병관리원 · 이동길',
      content: 'GLOBEFISH 뉴스 확인 — 동남아 AHPND 확산, 국내 영향 여부 계속 모니터링.',
      tags: [],
      createdAt: at(1, 19, 40),
    },
    {
      farmId: farmIds['미래수산'],
      authorType: 'farm',
      authorName: '어가 · 미래수산',
      content: '2수조 폐사 신고, 수면 근처 유영 개체 다수 관찰됨.',
      tags: ['폐사 6마리'],
      createdAt: at(1, 7, 40),
      photoCount: 1,
      readByFarm: true,
    },
    {
      farmId: farmIds['청해양식장'],
      authorType: 'institute',
      authorName: '수산질병관리원 · 이동길',
      content: '섭이 감소 확인, 수온 상승 지속 시 재방문 필요.',
      tags: [],
      createdAt: at(2, 16, 12),
      readByFarm: true,
    },
  ];

  for (const m of memos) {
    await query(
      `insert into memos (org_id, farm_id, author_type, author_name, content, tags, photo_count, read_by_farm, created_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [orgId, m.farmId, m.authorType, m.authorName, m.content, m.tags, m.photoCount ?? 0, m.readByFarm ?? false, m.createdAt],
    );
  }

  const diseaseInfo = [
    { scope: 'domestic', species: '넙치', title: '전남 해역 넙치 에드워드시엘라증 산발 신고', source: '국립수산과학원', daysAgo: 1 },
    { scope: 'overseas', species: '새우', title: '동남아 새우 AHPND 확산 — 국내 어종 무관', source: 'GLOBEFISH', daysAgo: 2 },
    { scope: 'overseas', species: '연어', title: '노르웨이 연어 ISA 바이러스 발생 보고', source: 'FAO FishStat', daysAgo: 5 },
  ];
  for (const d of diseaseInfo) {
    const publishedAt = new Date(Date.now() - d.daysAgo * 86400_000).toISOString();
    await query('insert into disease_info (scope, species, title, source, published_at) values ($1,$2,$3,$4,$5)', [
      d.scope,
      d.species,
      d.title,
      d.source,
      publishedAt,
    ]);
  }

  // Fixed, never-expiring demo token so `/r/demo` always resolves, mirroring
  // the mock-mode convenience seed in mock_share_link_repository.dart.
  await query('insert into share_links (farm_id, token, created_by) values ($1, $2, $3)', [
    farmIds['신일수산 1양식장'],
    'demo',
    memberId,
  ]);

  console.log('Seed complete.');
  console.log(`Login: leedonggil@haegang.kr / ${DEMO_PASSWORD}`);
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
