// 관측소 수온 이력. NIFS 실시간 해양관측은 '지금 값'만 주므로, 서버가 1시간마다 전국 관측소 값을
// 받아 ocean_temp_readings 에 쌓아 두고 AI 리포트가 기간 일 평균 수온을 계산할 때 쓴다.
// 2개월이 지난 자료는 같은 주기에 지운다. OCEAN_TEMP_COLLECT=off 면 수집하지 않는다(로컬 시험용).

import { query } from '../db.js';
import { fetchRealtimeObservations } from './nifs.js';

const RETENTION = '2 months';
const RETENTION_DAYS = 59; // 수집 시 거르는 기준(2개월보다 조금 짧게)
const HOUR_MS = 3600_000;
// NIFS 는 정시 관측값을 몇십 분 뒤에 올린다 — 매시 20분에 받는다.
const COLLECT_MINUTE = 20;

// 양식 어류는 중·저층에 살아 저층 > 중층 > 표층 순으로 쓴다(nifs.js pickPreferredObservation 과 같은 규칙).
const LAYER_PRIORITY = ['저층', '중층', '표층'];

export const tempThresholds = () => ({
  high: Number(process.env.HIGH_TEMP_C) || 25,
  low: Number(process.env.LOW_TEMP_C) || 10,
});

const round1 = (v) => Math.round(v * 10) / 10;

/** 지금 피드에 있는 전국 관측소 값을 저장한다. 저장한 행 수를 돌려준다. */
export async function collectOceanTemps() {
  const observations = await fetchRealtimeObservations();
  const rows = observations.filter(
    (o) => o.waterTempC != null && Number.isFinite(o.waterTempC) && /^\d{4}-\d{2}-\d{2}$/.test(o.observedDate) && /^\d{2}:\d{2}/.test(o.observedTime),
  );
  if (!rows.length) return 0;
  const oldest = Date.now() - RETENTION_DAYS * 86400_000;
  const values = [];
  const params = [];
  for (const o of rows) {
    const at = new Date(`${o.observedDate}T${o.observedTime.slice(0, 5)}:00+09:00`);
    // 고장 난 관측소는 몇 달 전 값을 계속 내보낸다 — 보관 기간보다 오래된 값은 받지 않는다.
    if (Number.isNaN(at.getTime()) || at.getTime() < oldest) continue;
    const i = params.length;
    values.push(`($${i + 1}, $${i + 2}, $${i + 3}, $${i + 4}, $${i + 5}, $${i + 6})`);
    params.push(o.stationCode, o.stationName, o.layer, at, o.waterTempC, o.status ?? '');
  }
  if (!values.length) return 0;
  const { rowCount } = await query(
    `insert into ocean_temp_readings (station_code, station_name, layer, observed_at, water_temp_c, status)
     values ${values.join(', ')} on conflict do nothing`,
    params,
  );
  return rowCount;
}

export async function purgeOldOceanTemps() {
  const { rowCount } = await query(`delete from ocean_temp_readings where observed_at < now() - interval '${RETENTION}'`);
  return rowCount;
}

async function runOnce() {
  try {
    const added = await collectOceanTemps();
    const purged = await purgeOldOceanTemps();
    console.log(`ocean temps: +${added} readings${purged ? `, purged ${purged} older than ${RETENTION}` : ''}`);
  } catch (err) {
    console.error('ocean temp collection failed', err.message ?? err);
  }
}

// 켜질 때 한 번, 그 뒤 매시 20분마다.
export function scheduleOceanTempCollection() {
  if (process.env.OCEAN_TEMP_COLLECT === 'off') return;
  runOnce();
  const now = Date.now();
  const next = Math.floor(now / HOUR_MS) * HOUR_MS + COLLECT_MINUTE * 60_000;
  const wait = next > now ? next - now : next + HOUR_MS - now;
  setTimeout(() => {
    runOnce();
    setInterval(runOnce, HOUR_MS).unref();
  }, wait).unref();
}

/** 'YYYY-MM-DD'(KST) 부터 'YYYY-MM-DD' 까지의 날짜 수(양끝 포함). */
const dayCount = (from, to) => Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400_000) + 1;

/**
 * 관측소의 기간 일별 수온(KST 날짜, 점검 중 값 제외). 층은 그 기간에 자료가 있는 층 중 저층 > 중층 > 표층.
 * 자료가 없으면 null.
 */
export async function dailyTemps(stationCode, from, to) {
  if (!stationCode) return null;
  const { rows } = await query(
    `select layer, to_char(observed_at at time zone 'Asia/Seoul', 'YYYY-MM-DD') as day,
            avg(water_temp_c)::float8 as avg, min(water_temp_c)::float8 as min, max(water_temp_c)::float8 as max, count(*)::int as n
       from ocean_temp_readings
      where station_code = $1 and observed_at >= $2 and observed_at < $3 and status <> '점검'
      group by layer, day order by day`,
    [stationCode, new Date(`${from}T00:00:00+09:00`), new Date(new Date(`${to}T00:00:00+09:00`).getTime() + 86400_000)],
  );
  const layer = LAYER_PRIORITY.find((l) => rows.some((r) => r.layer === l)) ?? rows[0]?.layer;
  if (!layer) return null;
  const daily = rows
    .filter((r) => r.layer === layer)
    .map((r) => ({ date: r.day, avg: round1(r.avg), min: round1(r.min), max: round1(r.max), readings: r.n }));
  return { layer, daily };
}

/**
 * 기간 요약(symterAI temp.ts summarize 이식). 고수온·저수온 일수는 '일 평균 수온'이 기준 이상/이하인 날의 수.
 * weekChange 는 마지막 7일 평균 − 첫 7일 평균(자료 14일 미만이면 null).
 */
export function summarizeTemps(daily, from, to, th = tempThresholds()) {
  if (!daily?.length) return null;
  const sorted = [...daily].sort((a, b) => a.date.localeCompare(b.date));
  const mean = (xs) => xs.reduce((s, r) => s + r.avg, 0) / xs.length;
  return {
    days: sorted.length,
    periodDays: dayCount(from, to),
    firstDate: sorted[0].date,
    lastDate: sorted[sorted.length - 1].date,
    avg: round1(mean(sorted)),
    min: Math.min(...sorted.map((r) => r.min)),
    max: Math.max(...sorted.map((r) => r.max)),
    highDays: sorted.filter((r) => r.avg >= th.high).length,
    lowDays: sorted.filter((r) => r.avg <= th.low).length,
    weekChange: sorted.length >= 14 ? round1(mean(sorted.slice(-7)) - mean(sorted.slice(0, 7))) : null,
    highThreshold: th.high,
    lowThreshold: th.low,
  };
}

/** 관측소·기간의 { layer, daily, summary } (자료 없으면 null). */
export async function periodTemps(stationCode, from, to) {
  const d = await dailyTemps(stationCode, from, to);
  if (!d || !d.daily.length) return null;
  return { ...d, summary: summarizeTemps(d.daily, from, to) };
}

/** AI 입력 한 줄: 기간 수온 요약. */
export function tempSummaryLine(name, t) {
  const s = t.summary;
  const coverage = s.days < s.periodDays ? `, 기간 ${s.periodDays}일 중 ${s.days}일만 자료 있음(${s.firstDate}~${s.lastDate})` : '';
  return (
    `${name} 관측소 ${t.layer} 일 평균 수온 ${s.days}일분${coverage}: 기간 평균 ${s.avg}℃(최저 ${s.min}℃, 최고 ${s.max}℃), ` +
    `고수온(일 평균 ${s.highThreshold}℃ 이상) ${s.highDays}일, 저수온(일 평균 ${s.lowThreshold}℃ 이하) ${s.lowDays}일` +
    (s.weekChange === null ? '' : `, 첫 7일 대비 마지막 7일 평균 변화 ${s.weekChange > 0 ? '+' : ''}${s.weekChange}℃`)
  );
}
