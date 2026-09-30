import { Router } from 'express';

import { query } from '../db.js';
import { loadFarmRows, toFarmJson } from './farms.js';
import { buildAndPersistReport, latestReportRow, toReportJson } from './reports.js';

// No requireAuth here on purpose: this is what a farm owner opens from a
// share link on their own phone, with no AquaConnect account.
export const publicRouter = Router();

publicRouter.get('/reports/:token', async (req, res) => {
  const { rows } = await query('select * from share_links where token = $1', [req.params.token]);
  const link = rows[0];

  const isActive = link && !link.revoked_at && (!link.expires_at || new Date(link.expires_at) > new Date());
  if (!isActive) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });

  const [farm] = await loadFarmRows('f.id = $1', [link.farm_id]);
  if (!farm) return res.status(404).json({ error: '링크가 만료되었거나 존재하지 않습니다.' });

  let reportRow = await latestReportRow(farm.id);
  const report = reportRow ? toReportJson(reportRow) : await buildAndPersistReport(farm);

  const { rows: extraRows } = await query(
    `select o.name as organization_name, m.phone as assigned_member_phone
     from organizations o left join members m on m.id = $2
     where o.id = $1`,
    [farm.org_id, farm.assigned_member_id],
  );

  res.json({
    organizationName: extraRows[0]?.organization_name ?? null,
    assignedMemberPhone: extraRows[0]?.assigned_member_phone ?? null,
    farm: toFarmJson(farm),
    report,
    link: { id: link.id, farmId: link.farm_id, token: link.token, createdAt: link.created_at, expiresAt: link.expires_at, revokedAt: link.revoked_at },
  });
});
