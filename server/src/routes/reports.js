import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { query } from '../db.js';
import { orgIdForMember } from '../lib/orgScope.js';
import { generateReport } from '../lib/reportGenerator.js';
import { fetchRealtimeObservations, pickPreferredObservation } from '../lib/nifs.js';

export const reportsRouter = Router();
reportsRouter.use(requireAuth);

export function toReportJson(row) {
  return {
    id: row.id,
    farmId: row.farm_id,
    periodLabel: row.period_label,
    riskLevel: row.risk_level,
    headline: row.headline,
    summary: row.summary,
    weeklyMortality: row.weekly_mortality,
    avgTemp: Number(row.avg_temp),
    lastVisitDays: row.last_visit_days,
    findings: row.findings ?? [],
    followUps: row.follow_ups ?? [],
    mortalityTrend: (row.mortality_trend ?? []).map(Number),
    tempTrend: (row.temp_trend ?? []).map(Number),
    dayLabels: row.day_labels ?? [],
    generatedAt: row.generated_at,
  };
}

async function loadFarm(orgId, farmId) {
  const { rows } = await query('select * from farms where org_id = $1 and id = $2', [orgId, farmId]);
  return rows[0] ?? null;
}

async function oceanSnapshotForFarm(farm) {
  try {
    const observations = await fetchRealtimeObservations({ station: farm.nearest_station_code });
    const picked = pickPreferredObservation(observations);
    if (!picked) return null;
    return { waterTemp: picked.waterTempC, layer: picked.layer, sevenDayTemps: [picked.waterTempC], sevenDayLabels: ['오늘'] };
  } catch {
    return null; // NIFS being unavailable shouldn't block report generation
  }
}

export async function latestReportRow(farmId) {
  const { rows } = await query(
    'select * from reports where farm_id = $1 order by generated_at desc limit 1',
    [farmId],
  );
  return rows[0] ?? null;
}

reportsRouter.get('/', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const requestedIds = new Set((req.query.farmIds ?? '').split(',').filter(Boolean));
  if (requestedIds.size === 0) return res.json([]);

  // A single institute manages at most a few dozen farms, so scoping by
  // fetching the org's farm ids and intersecting in JS is simpler (and
  // avoids array-typed SQL parameters) than pushing the filter into SQL.
  const { rows: farmRows } = await query('select id from farms where org_id = $1', [orgId]);
  const validIds = farmRows.map((r) => r.id).filter((id) => requestedIds.has(id));

  const reports = [];
  for (const farmId of validIds) {
    const row = await latestReportRow(farmId);
    if (row) reports.push(toReportJson(row));
  }
  res.json(reports);
});

reportsRouter.get('/:farmId', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const farm = await loadFarm(orgId, req.params.farmId);
  if (!farm) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });

  const row = await latestReportRow(farm.id);
  if (row) return res.json(toReportJson(row));

  // No snapshot yet — generate one on first view, same as mock mode does.
  const generated = await buildAndPersistReport(farm);
  res.json(generated);
});

reportsRouter.post('/:farmId/generate', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const farm = await loadFarm(orgId, req.params.farmId);
  if (!farm) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });

  const generated = await buildAndPersistReport(farm);
  res.status(201).json(generated);
});

export async function buildAndPersistReport(farm) {
  const { rows: memoRows } = await query(
    'select content, tags, created_at from memos where farm_id = $1 order by created_at desc',
    [farm.id],
  );
  const memos = memoRows.map((r) => ({ content: r.content, tags: r.tags ?? [], createdAt: r.created_at }));
  const ocean = await oceanSnapshotForFarm(farm);

  const report = generateReport({
    farm: {
      id: farm.id,
      waterTemp: Number(farm.water_temp),
      lastVisitDays: farm.last_visit_days,
      nearestStationName: farm.nearest_station_name,
    },
    farmMemos: memos,
    ocean,
    now: new Date(),
  });

  const { rows } = await query(
    `insert into reports
       (farm_id, period_label, risk_level, headline, summary, weekly_mortality, avg_temp, last_visit_days,
        findings, follow_ups, mortality_trend, temp_trend, day_labels, generated_at)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
     returning *`,
    [
      farm.id,
      report.periodLabel,
      report.riskLevel,
      report.headline,
      report.summary,
      report.weeklyMortality,
      report.avgTemp,
      report.lastVisitDays,
      report.findings,
      report.followUps,
      report.mortalityTrend,
      report.tempTrend,
      report.dayLabels,
      report.generatedAt,
    ],
  );
  return toReportJson(rows[0]);
}
