// JS port of lib/data/logic/report_generator.dart — keep the two in sync.
// The UI labels this "AI 정리 소견" per the approved design copy, but it's
// rule-based: memos + ocean readings combined with fixed thresholds, not an
// LLM call. This is the authoritative version once the backend is live —
// the Dart copy stays only for mock-mode (no-backend) local runs.

const MORTALITY_TAG_PATTERN = /폐사\s*(\d+)\s*마리/;

export function generateReport({ farm, farmMemos, ocean, now = new Date() }) {
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const recentMemos = farmMemos.filter((m) => new Date(m.createdAt) > sevenDaysAgo);

  const dayLabels = ocean?.sevenDayLabels?.length === 7 ? ocean.sevenDayLabels : lastSevenDayLabels(now);
  // No reading at all (NIFS down / station without data, and no earlier
  // reading stored on the farm) leaves the trend empty rather than
  // inventing a temperature.
  const currentTemp = ocean?.waterTemp ?? farm.waterTemp ?? null;
  const tempTrend =
    ocean?.sevenDayTemps?.length === 7 ? ocean.sevenDayTemps : currentTemp == null ? [] : Array(7).fill(currentTemp);
  const mortalityTrend = mortalityByDay(recentMemos, now);

  const weeklyMortality = mortalityTrend.reduce((sum, v) => sum + Math.round(v), 0);
  const avgTemp = tempTrend.length ? tempTrend.reduce((a, b) => a + b, 0) / tempTrend.length : null;
  const tempDelta = tempTrend.length >= 2 ? tempTrend[tempTrend.length - 1] - tempTrend[0] : 0;

  const hasAbnormalSwimming = recentMemos.some((m) => (m.tags ?? []).includes('유영 이상'));
  const hasFeedingDrop = recentMemos.some((m) => m.content.includes('섭이') && m.content.includes('감소'));

  const riskLevel = classify({ weeklyMortality, avgTemp, tempDelta });

  const findings = [];
  if (Math.abs(tempDelta) >= 0.4) {
    findings.push(
      `${farm.nearestStationName} 관측소 수온 최근 7일간 ${tempDelta >= 0 ? '+' : ''}${tempDelta.toFixed(1)}℃ 변화`,
    );
  }
  if (weeklyMortality > 0) findings.push(`최근 7일간 누적 폐사 ${weeklyMortality}마리 (기록된 메모 기준)`);
  if (hasAbnormalSwimming) findings.push('유영 이상 증상이 현장 메모에 보고됨');
  if (hasFeedingDrop) findings.push('섭이량 감소가 현장 메모에 보고됨');
  if (findings.length === 0) findings.push('최근 7일간 특이 신호 없음');

  const followUps = followUpsFor(riskLevel);

  const headline = {
    danger: '고수온·폐사 급증 — 긴급 확인 필요',
    warning: '고수온 지속 + 폐사 소폭 증가',
    good: '특이사항 없음 — 정상 범위',
  }[riskLevel];

  const summary =
    riskLevel === 'danger'
      ? '지난 7일 대비 폐사와 수온이 함께 상승했습니다. 즉시 방문 및 시료 채취를 권장합니다.'
      : riskLevel === 'warning'
        ? avgTemp == null
          ? `지난 7일 대비 폐사 ${weeklyMortality}마리 — 방문 및 수질 확인을 권장합니다.`
          : `지난 7일 대비 폐사 ${weeklyMortality}마리, 평균 수온 ${avgTemp.toFixed(1)}℃ — 방문 및 수질 확인을 권장합니다.`
        : '최근 7일간 폐사·수온 모두 안정적인 범위입니다. 정기 모니터링을 유지하세요.';

  return {
    farmId: farm.id,
    periodLabel: '이번 주',
    riskLevel,
    headline,
    summary,
    weeklyMortality,
    avgTemp,
    lastVisitDays: lastVisitDays(farmMemos, now) ?? farm.lastVisitDays ?? null,
    findings,
    followUps,
    mortalityTrend,
    tempTrend,
    dayLabels,
    generatedAt: now.toISOString(),
  };
}

function classify({ weeklyMortality, avgTemp, tempDelta }) {
  const temp = avgTemp ?? -Infinity;
  if (weeklyMortality >= 15 || temp >= 29.5) return 'danger';
  if (weeklyMortality >= 5 || temp >= 28.0 || tempDelta >= 0.6) return 'warning';
  return 'good';
}

function followUpsFor(level) {
  if (level === 'danger') {
    return ['즉시 방문 및 폐사체 시료 채취를 진행하세요', '용존산소·수온 변화를 시간 단위로 모니터링하세요', '질병 검사 의뢰 여부를 검토하세요'];
  }
  if (level === 'warning') {
    return ['수질(용존산소·수온) 확인을 권장합니다', '3일 이내 재방문을 권장합니다', '폐사한 개체와 수조 상태를 사진으로 기록해두세요'];
  }
  return ['정기 모니터링 일정을 유지하세요', '다음 정기 방문 일정대로 진행하세요'];
}

function mortalityByDay(memos, now) {
  const buckets = Array(7).fill(0);
  for (const memo of memos) {
    const haystack = [...(memo.tags ?? []), memo.content].join(' ');
    const match = haystack.match(MORTALITY_TAG_PATTERN);
    if (!match) continue;
    const count = Number(match[1]) || 0;
    const daysAgo = Math.floor((now.getTime() - new Date(memo.createdAt).getTime()) / (24 * 60 * 60 * 1000));
    const dayIndex = 6 - daysAgo;
    if (dayIndex >= 0 && dayIndex < 7) buckets[dayIndex] += count;
  }
  return buckets;
}

// Short status line for the farm card on Home / 전체 리포트.
export function farmHeadline(report) {
  if (report.weeklyMortality > 0) return `최근 7일 폐사 ${report.weeklyMortality}마리`;
  if (report.riskLevel === 'danger') return '고수온 위험';
  if (report.riskLevel === 'warning') return '고수온 주의';
  return '특이사항 없음';
}

// Days since the latest institute memo (a field visit), or null if none.
export function lastVisitDays(memos, now) {
  let latest = null;
  for (const m of memos) {
    if (m.authorType && m.authorType !== 'institute') continue;
    const t = new Date(m.createdAt).getTime();
    if (latest == null || t > latest) latest = t;
  }
  return latest == null ? null : Math.floor((now.getTime() - latest) / (24 * 60 * 60 * 1000));
}

function lastSevenDayLabels(now) {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now.getTime() - (6 - i) * 24 * 60 * 60 * 1000);
    return `${d.getMonth() + 1}/${d.getDate()}`;
  });
}
