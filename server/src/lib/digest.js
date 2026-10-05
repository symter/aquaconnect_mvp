import { query } from '../db.js';
import { notifyMembers } from './notify.js';

// 하루 요약 / 주간 요약 notifications. Times are Korean time (KST, UTC+9) —
// the server itself runs in UTC.
const CHECK_EVERY_MS = 60 * 1000;
const WEEKLY_TIME = '08:00'; // 매주 월요일 아침
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

export const DIGEST_DEFAULTS = { dailyEnabled: true, dailyTime: '16:00', weeklyEnabled: true };
export const DAILY_TIME_RE = /^([01][0-9]|2[0-3]):[0-5][0-9]$/;

/** Current KST date ("2026-10-06"), time ("16:00") and weekday (0 = Sunday). */
export function kstNow(now = new Date()) {
  const k = new Date(now.getTime() + KST_OFFSET_MS);
  return { date: k.toISOString().slice(0, 10), time: k.toISOString().slice(11, 16), weekday: k.getUTCDay() };
}

const label = (date) => `${Number(date.slice(5, 7))}/${Number(date.slice(8, 10))}`;

async function orgSummary(orgId, sinceKstDate, days) {
  const { rows: riskRows } = await query(
    'select risk_level, count(*)::int as c from farms where org_id = $1 group by risk_level',
    [orgId],
  );
  const risk = Object.fromEntries(riskRows.map((r) => [r.risk_level, r.c]));
  const farmCount = riskRows.reduce((sum, r) => sum + r.c, 0);
  const { rows: memoRows } = await query(
    `select count(*) filter (where author_type = 'institute')::int as memos,
            count(*) filter (where author_type = 'farm')::int as inquiries
     from memos
     where org_id = $1 and created_at >= (($2::date - ($3::int - 1)) + time '00:00') at time zone 'Asia/Seoul'`,
    [orgId, sinceKstDate, days],
  );
  return { farmCount, danger: risk.danger ?? 0, warning: risk.warning ?? 0, ...memoRows[0] };
}

function summaryBody(s, period) {
  const parts = [];
  parts.push(s.farmCount ? `위험 ${s.danger}곳 · 주의 ${s.warning}곳` : '등록된 양식장 없음');
  parts.push(`${period} 메모 ${s.memos}건`);
  if (s.inquiries) parts.push(`어가 문의 ${s.inquiries}건`);
  return parts.join(' · ');
}

// Claims (marks as sent) and returns the members due now. The conditional
// update is the claim, so two server instances can't both send one summary.
async function claimDaily(now) {
  const { rows } = await query(
    `update digest_settings d set last_daily_on = $1::date
     from members m
     where m.id = d.member_id and m.status = 'active'
       and d.daily_enabled and d.daily_time <= $2
       and (d.last_daily_on is null or d.last_daily_on < $1::date)
     returning d.member_id, m.org_id`,
    [now.date, now.time],
  );
  return rows;
}

async function claimWeekly(now) {
  if (now.weekday !== 1 || now.time < WEEKLY_TIME) return [];
  const { rows } = await query(
    `update digest_settings d set last_weekly_on = $1::date
     from members m
     where m.id = d.member_id and m.status = 'active'
       and d.weekly_enabled
       and (d.last_weekly_on is null or d.last_weekly_on < $1::date)
     returning d.member_id, m.org_id`,
    [now.date],
  );
  return rows;
}

async function send(claimed, { days, title, period }, now) {
  const summaries = new Map();
  for (const { member_id: memberId, org_id: orgId } of claimed) {
    if (!summaries.has(orgId)) summaries.set(orgId, await orgSummary(orgId, now.date, days));
    await notifyMembers({
      orgId,
      memberIds: [memberId],
      type: 'digest',
      title,
      body: summaryBody(summaries.get(orgId), period),
      link: '/',
    });
  }
}

let running = false;

export async function runDigests(at = new Date()) {
  if (running) return;
  running = true;
  try {
    const now = kstNow(at);
    // Members without a row get the defaults; the row is where last-sent is kept.
    await query('insert into digest_settings (member_id) select id from members on conflict do nothing');
    await send(await claimDaily(now), { days: 1, title: `오늘의 요약 (${label(now.date)})`, period: '오늘' }, now);
    await send(await claimWeekly(now), { days: 7, title: `주간 요약 (${label(now.date)})`, period: '지난 7일' }, now);
  } catch (err) {
    console.error('digest run failed', err);
  } finally {
    running = false;
  }
}

export function scheduleDigests() {
  setInterval(runDigests, CHECK_EVERY_MS).unref();
}
