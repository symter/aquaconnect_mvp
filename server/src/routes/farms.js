import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { query } from '../db.js';
import { orgIdForMember } from '../lib/orgScope.js';
import { refreshReportQuietly } from './reports.js';

export const farmsRouter = Router();
farmsRouter.use(requireAuth);

// 최근 방문 = days since the latest institute memo on the farm.
const FARM_SELECT = `select f.*, m.name as assigned_member_name, m.phone as assigned_member_phone,
    (select max(mm.created_at) from memos mm where mm.farm_id = f.id and mm.author_type = 'institute') as last_visit_at
  from farms f left join members m on m.id = f.assigned_member_id`;

function daysSince(ts) {
  if (!ts) return null;
  return Math.floor((Date.now() - new Date(ts).getTime()) / 86400_000);
}

export async function loadFarmRows(where, params) {
  const { rows } = await query(`${FARM_SELECT} where ${where}`, params);
  return rows;
}

export function toFarmJson(row) {
  return {
    id: row.id,
    orgId: row.org_id,
    name: row.name,
    region: row.region,
    address: row.address,
    nearestStationCode: row.nearest_station_code,
    nearestStationName: row.nearest_station_name,
    riskLevel: row.risk_level,
    headline: row.headline,
    waterTemp: row.water_temp == null ? null : Number(row.water_temp),
    lastVisitDays: daysSince(row.last_visit_at),
    assignedMemberName: row.assigned_member_name,
    assignedMemberPhone: row.assigned_member_phone ?? null,
    ownerContact: row.owner_contact,
  };
}

farmsRouter.get('/', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const rows = await loadFarmRows('f.org_id = $1 order by f.name', [orgId]);
  res.json(rows.map(toFarmJson));
});

farmsRouter.get('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const rows = await loadFarmRows('f.org_id = $1 and f.id = $2', [orgId, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });
  res.json(toFarmJson(rows[0]));
});

function validateFarmBody(body) {
  const { name, address, ownerContact } = body ?? {};
  if (!name || !name.trim()) return '양식장명을 입력해주세요.';
  if (!address || !address.trim()) return '위치(주소)를 입력해주세요.';
  if (!ownerContact || !ownerContact.trim()) return '전화번호를 입력해주세요.';
  return null;
}

farmsRouter.post('/', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const error = validateFarmBody(req.body);
  if (error) return res.status(400).json({ error });

  const { name, address, ownerContact, region = '', nearestStationCode = '', nearestStationName = '' } = req.body;
  // The creator becomes the assigned member — the "담당 관리사" a shared
  // report's contact button calls.
  const { rows } = await query(
    `insert into farms (org_id, name, region, address, nearest_station_code, nearest_station_name, owner_contact, assigned_member_id)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     returning id`,
    [orgId, name.trim(), region, address.trim(), nearestStationCode, nearestStationName, ownerContact.trim(), req.memberId],
  );
  await refreshReportQuietly(rows[0].id);
  const [farm] = await loadFarmRows('f.id = $1', [rows[0].id]);
  res.status(201).json(toFarmJson(farm));
});

farmsRouter.put('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const error = validateFarmBody(req.body);
  if (error) return res.status(400).json({ error });

  const { name, address, ownerContact, region = '', nearestStationCode = '', nearestStationName = '' } = req.body;
  const { rows: before } = await query('select nearest_station_code from farms where org_id = $1 and id = $2', [
    orgId,
    req.params.id,
  ]);
  if (!before[0]) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });

  await query(
    `update farms
     set name = $3, address = $4, owner_contact = $5, region = $6, nearest_station_code = $7, nearest_station_name = $8
     where org_id = $1 and id = $2`,
    [orgId, req.params.id, name.trim(), address.trim(), ownerContact.trim(), region, nearestStationCode, nearestStationName],
  );
  // A different station means the stored 수온 belongs to the old one.
  if (before[0].nearest_station_code !== nearestStationCode) {
    await query('update farms set water_temp = null where id = $1', [req.params.id]);
    await refreshReportQuietly(req.params.id);
  }
  const [farm] = await loadFarmRows('f.id = $1', [req.params.id]);
  res.json(toFarmJson(farm));
});

farmsRouter.delete('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { rows } = await query('delete from farms where org_id = $1 and id = $2 returning id', [orgId, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });
  res.status(204).end();
});
