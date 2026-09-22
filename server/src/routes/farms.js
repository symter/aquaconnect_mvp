import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { query } from '../db.js';
import { orgIdForMember } from '../lib/orgScope.js';

export const farmsRouter = Router();
farmsRouter.use(requireAuth);

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
    waterTemp: Number(row.water_temp),
    lastVisitDays: row.last_visit_days,
    assignedMemberName: row.assigned_member_name,
    ownerContact: row.owner_contact,
  };
}

farmsRouter.get('/', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { rows } = await query(
    `select f.*, m.name as assigned_member_name
     from farms f left join members m on m.id = f.assigned_member_id
     where f.org_id = $1 order by f.name`,
    [orgId],
  );
  res.json(rows.map(toFarmJson));
});

farmsRouter.get('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { rows } = await query(
    `select f.*, m.name as assigned_member_name
     from farms f left join members m on m.id = f.assigned_member_id
     where f.org_id = $1 and f.id = $2`,
    [orgId, req.params.id],
  );
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
  const { rows } = await query(
    `insert into farms (org_id, name, region, address, nearest_station_code, nearest_station_name, owner_contact)
     values ($1, $2, $3, $4, $5, $6, $7)
     returning *`,
    [orgId, name.trim(), region, address.trim(), nearestStationCode, nearestStationName, ownerContact.trim()],
  );
  res.status(201).json(toFarmJson({ ...rows[0], assigned_member_name: null }));
});

farmsRouter.put('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const error = validateFarmBody(req.body);
  if (error) return res.status(400).json({ error });

  const { name, address, ownerContact, region = '', nearestStationCode = '', nearestStationName = '' } = req.body;
  const { rows } = await query(
    `update farms
     set name = $3, address = $4, owner_contact = $5, region = $6, nearest_station_code = $7, nearest_station_name = $8
     where org_id = $1 and id = $2
     returning *`,
    [orgId, req.params.id, name.trim(), address.trim(), ownerContact.trim(), region, nearestStationCode, nearestStationName],
  );
  if (!rows[0]) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });

  const { rows: memberRows } = await query('select name from members where id = $1', [rows[0].assigned_member_id]);
  res.json(toFarmJson({ ...rows[0], assigned_member_name: memberRows[0]?.name ?? null }));
});

farmsRouter.delete('/:id', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { rows } = await query('delete from farms where org_id = $1 and id = $2 returning id', [orgId, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });
  res.status(204).end();
});
