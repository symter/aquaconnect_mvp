// 월간 자동 리포트. 매달 지난달 메모가 있는 모든 양식장에 리포트 초안을 만들어 둔다.
// 초안은 관리원이 앱에서 검토·수정해 어가에 보낼 때까지 대기한다(자동 발송하지 않음).
// 한 시간마다 확인해, 아직 없는 양식장만 만든다 — AI 한도가 떨어지면 멈췄다가 다음 확인 때 이어서 만든다.
// AUTO_MONTHLY_REPORTS=off 면 만들지 않는다.

import { query } from '../db.js';
import { createFarmReport } from './ai/createFarmReport.js';
import { AiError, DEFAULT_PROVIDER, isProvider, modelStatus } from './ai/model.js';
import { notifyMembers } from './notify.js';

const HOUR_MS = 3600_000;
const AUTO_AUTHOR = '자동 생성';
// 같은 양식장이 계속 실패하면(메모 형식 문제 등) 서버가 다시 켜질 때까지 건너뛴다.
const MAX_FAILURES = 3;
const failures = new Map();
let running = false;

/** 지금(KST) 기준 지난달 { from, to, month } */
export function previousMonth(now = new Date()) {
  const kst = new Date(now.getTime() + 9 * HOUR_MS);
  const y = kst.getUTCFullYear();
  const m = kst.getUTCMonth(); // 이번 달(0-based) → 지난달은 m-1
  const first = new Date(Date.UTC(y, m - 1, 1));
  const last = new Date(Date.UTC(y, m, 0));
  const ymd = (d) => d.toISOString().slice(0, 10);
  return { from: ymd(first), to: ymd(last), month: first.getUTCMonth() + 1 };
}

/**
 * 자동 생성에 쓸 AI. AI_PROVIDER 가 있으면 그것, 없으면 앱이 마지막으로 쓴 AI(최근 사용 기록의 모델),
 * 그것도 없으면 Gemini. 앱의 lib/main.dart 에서 AI 를 바꾸면 다음 자동 생성부터 따라간다.
 */
async function autoProvider() {
  const wanted = process.env.AI_PROVIDER?.trim();
  if (wanted && isProvider(wanted)) return wanted;
  const { rows } = await query("select model from ai_usage where outcome = 'ok' order by created_at desc limit 1");
  return rows[0]?.model?.startsWith('claude') ? 'claude' : DEFAULT_PROVIDER;
}

/** 아직 자동 초안이 없는 양식장에 지난달 초안을 만든다. 만든 건수를 돌려준다. */
export async function runMonthlyReports(now = new Date()) {
  if (running) return 0;
  running = true;
  try {
    const provider = await autoProvider();
    if (!modelStatus(provider).configured) return 0;
    const { from, to, month } = previousMonth(now);
    const start = new Date(`${from}T00:00:00+09:00`);
    const endExclusive = new Date(new Date(`${to}T00:00:00+09:00`).getTime() + 86400_000);
    // 그 달 메모가 있고, 같은 기간 리포트(자동이든 관리원이 직접 만든 것이든)가 아직 없는 양식장
    const { rows: farms } = await query(
      `select f.* from farms f
        where exists (select 1 from memos m where m.farm_id = f.id and m.created_at >= $1 and m.created_at < $2)
          and not exists (select 1 from ai_reports r where r.farm_id = f.id and r.type = 'farm' and r.period_start = $3 and r.period_end = $4)
        order by f.org_id, f.name`,
      [start, endExclusive, from, to],
    );
    const made = new Map(); // org_id → 만든 건수
    for (const farm of farms) {
      const key = `${farm.id}:${from}`;
      if ((failures.get(key) ?? 0) >= MAX_FAILURES) continue;
      try {
        await createFarmReport({ orgId: farm.org_id, farm, from, to, provider, createdByName: AUTO_AUTHOR, source: 'auto' });
        made.set(farm.org_id, (made.get(farm.org_id) ?? 0) + 1);
      } catch (err) {
        if (err?.code === '23505') continue; // 다른 인스턴스가 먼저 만듦
        // 모든 모델 한도 소진·AI 서버 장애: 이번 확인은 여기서 멈추고 다음 확인 때 이어서 만든다.
        if (err instanceof AiError && [429, 502, 503].includes(err.status)) {
          console.warn(`monthly reports: paused (${err.message})`);
          break;
        }
        failures.set(key, (failures.get(key) ?? 0) + 1);
        console.error(`monthly report failed for farm ${farm.id}`, err.message ?? err);
      }
    }
    for (const [orgId, n] of made) {
      await notifyMembers({
        orgId,
        type: 'report',
        title: `${month}월 AI 리포트 초안 ${n}건이 도착했어요`,
        body: '검토하고 고칠 내용을 고친 뒤 어가에 보내 주세요. 보내기 전에는 어가에 보이지 않아요.',
        link: '/reports',
      });
    }
    const total = [...made.values()].reduce((a, b) => a + b, 0);
    if (total) console.log(`monthly reports: ${total} drafts for ${from} ~ ${to}`);
    return total;
  } catch (err) {
    console.error('monthly reports failed', err);
    return 0;
  } finally {
    running = false;
  }
}

// 켜지고 2분 뒤 한 번, 그 뒤 한 시간마다. 이미 만든 양식장은 건너뛰므로 여러 번 돌아도 안전하다.
export function scheduleMonthlyReports() {
  if (process.env.AUTO_MONTHLY_REPORTS === 'off') return;
  setTimeout(() => {
    runMonthlyReports();
    setInterval(runMonthlyReports, HOUR_MS).unref();
  }, 2 * 60_000).unref();
}
