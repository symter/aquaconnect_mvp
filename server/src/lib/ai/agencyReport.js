// 관리원 종합 리포트 — symterAI 원장님 종합 리포트(generator.ts agencyInput · report-data.ts agencyMeta) 이식.
// 기간 안의 모든 양식장 메모를 양식장별로 집계해 AI 에게 주고(숫자는 코드가 계산), AI 는 마크다운 섹션으로 정리한다.
// 근거 번호가 없는 형식이라 검증은 ① 섹션이 다 있는지 ② 입력에 없는 수치·진단 표현이 있는지만 본다.

import { fetchRealtimeObservations, pickPreferredObservation } from '../nifs.js';
import { kstDate } from './farmReport.js';
import { analyzeMemos, formatCount, summarizeFarm, TOPICS } from './memoAnalysis.js';
import { AiError, chat } from './model.js';
import { AGENCY_PROMPT_VERSION, AGENCY_REPORT_PROMPT, AGENCY_SECTIONS } from './prompts.js';

const NL = '\n';
const KIND_TAGS = ['폐사', '접종', '방문', '배달', '문의', '할일'];
const kindOf = (tags) => KIND_TAGS.find((t) => tags.includes(t)) ?? '메모';
const clip = (s, n) => {
  const one = s.replace(/\s+/g, ' ').trim();
  return one.length > n ? `${one.slice(0, n)}…` : one;
};
const numbersIn = (s) => new Set((s.match(/\d+(?:\.\d+)?/g) ?? []).map(Number));
const DIAGNOSIS = /확진|진단(?:됨|되었|했|하였)|(?:으)?로\s*판명|감염(?:됨|되었|된\s*것)|투약하|투여하|처방하|치료(?:하세요|하십시오|가\s*필요합니다)/g;

/** 메모 중요도 순위(작을수록 먼저): 폐사 기록 → 접종 기록 → 그 밖의 메모 → 메모 없음 */
const memoRank = (memos) => (memos.some((m) => m.kind === '폐사') ? 0 : memos.some((m) => m.kind === '접종') ? 1 : memos.length ? 2 : 3);

function tagsOf(m) {
  const out = [];
  const d = m.a.deaths;
  if (d) out.push(`폐사 ${d.min !== null && d.max !== null ? formatCount(d.min, d.max, d.approx) : '수량 미기재'}`);
  if (m.a.status) out.push(m.a.status);
  return out.map((t) => `[${t}]`).join(' ');
}

function tallyLines(an) {
  const d = an.deaths;
  const lines = [`- 기록 ${an.total}건`];
  if (an.topics.length) lines.push(`- 주제별: ${an.topics.map((t) => `${t.topic} ${t.count}건`).join(', ')}`);
  lines.push(
    d.events
      ? `- 폐사: 확정 마리수 합계 ${d.max > 0 ? formatCount(d.min, d.max) : '없음'} / 폐사 기록 ${d.events}건${d.unknown ? ` / 수량 미기재 ${d.unknown}건(합계에 포함하지 않음)` : ''}`
      : '- 폐사: 폐사가 적힌 기록 없음',
  );
  lines.push(`- 후속 확인 필요: ${an.open.length}건`);
  return lines;
}

/** 관측소마다 한 번만 실시간 수온을 조회한다(작성 시점 값). */
async function stationTemps(farms) {
  const codes = [...new Set(farms.map((f) => f.nearest_station_code).filter(Boolean))];
  const out = new Map();
  await Promise.all(
    codes.map(async (code) => {
      try {
        const t = pickPreferredObservation(await fetchRealtimeObservations({ station: code }));
        out.set(code, t ? { layer: t.layer, waterTempC: t.waterTempC, observedDate: t.observedDate, observedTime: t.observedTime } : null);
      } catch {
        out.set(code, null);
      }
    }),
  );
  return out;
}

/**
 * farms: 관리원의 양식장 행, memos: 기간 메모(모든 양식장) [{ id, farm_id, content, tags, author_type, author_name, created_at }]
 */
export async function draftAgencyReport({ orgName, from, to, farms, memos, model, onResult }) {
  const temps = await stationTemps(farms);
  let n = 0;
  const perFarm = farms.map((f) => {
    const list = memos
      .filter((m) => m.farm_id === f.id)
      .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
      .map((m) => ({ id: ++n, n, uuid: m.id, date: kstDate(m.created_at), kind: kindOf(m.tags ?? []), body: m.content, author: m.author_name }));
    const an = summarizeFarm(analyzeMemos(list));
    return { farm: f, memos: list, an, temp: f.nearest_station_code ? temps.get(f.nearest_station_code) ?? null : null };
  });
  const active = perFarm.filter((x) => x.memos.length);
  if (!active.length) throw new AiError('선택한 기간에 메모가 있는 양식장이 없습니다.', 400);

  const many = active.length > 10;
  const cap = many ? 4 : 8;
  const width = many ? 120 : 220;
  const priority = (k) => (k === '폐사' ? 0 : k === '접종' ? 1 : 2);
  const ordered = [...perFarm].sort(
    (a, b) => memoRank(a.memos) - memoRank(b.memos) || b.an.deaths.max - a.an.deaths.max || a.farm.name.localeCompare(b.farm.name),
  );
  const blocks = ordered
    .filter((x) => x.memos.length)
    .map((x) => {
      const picked = [...x.an.sorted].sort((a, b) => priority(a.kind) - priority(b.kind) || a.date.localeCompare(b.date)).slice(0, cap);
      const omitted = x.an.sorted.length > picked.length ? `${NL}    (그 외 ${x.an.sorted.length - picked.length}건 생략 — 집계에는 포함됨)` : '';
      const t = x.temp;
      return [
        `■ ${x.farm.name} / ${x.farm.region || '지역 미입력'}`,
        '  [집계]',
        tallyLines(x.an).map((l) => `  ${l}`).join(NL),
        '  [관리원 메모 — 중심 자료]',
        `${picked.map((m) => `    - ${m.date} [${m.a.primary}] (${m.kind}) ${clip(m.body, width)} ${tagsOf(m)}`.trimEnd()).join(NL)}${omitted}`,
        `  [수온 참고 자료] 관측소 ${x.farm.nearest_station_name || '없음'}: ${t ? `${t.layer} ${t.waterTempC}℃ (관측 ${t.observedDate} ${t.observedTime}, 작성 시점 실시간 값)` : '수온 자료 없음'}`,
      ].join(NL);
    });

  const sum = (f) => active.reduce((s, x) => s + f(x), 0);
  const topicTotals = TOPICS.map((topic) => ({ topic, count: sum((x) => x.an.topics.find((t) => t.topic === topic)?.count ?? 0) })).filter((t) => t.count > 0);
  const deathTotals = { min: sum((x) => x.an.deaths.min), max: sum((x) => x.an.deaths.max), unknown: sum((x) => x.an.deaths.unknown), events: sum((x) => x.an.deaths.events) };
  const openTotal = sum((x) => x.an.open.length);
  const overall = [
    `- 관리원 기록 ${sum((x) => x.an.total)}건 (메모가 있는 양식장 ${active.length}곳 / 전체 ${farms.length}곳)`,
    `- 대표 주제별 건수(전체): ${topicTotals.map((t) => `${t.topic} ${t.count}건`).join(', ') || '없음'}`,
    `- 폐사: 수량이 확정된 마리수 합계 ${deathTotals.max > 0 ? formatCount(deathTotals.min, deathTotals.max) : '없음'}${deathTotals.unknown ? ` / 수량 미기재 ${deathTotals.unknown}건(합계에 포함하지 않음)` : ''}`,
    `- 후속 확인이 필요한 기록: ${openTotal}건`,
  ];
  const input = [
    `기간: ${from} ~ ${to} (한국 시간)${NL}관리원: ${orgName}${NL}관리 양식장 ${farms.length}곳 (메모가 중요한 양식장 순)`,
    `[전체 집계 — 코드가 계산한 값. 그대로 쓰고 직접 계산하지 않는다]${NL}${overall.join(NL)}`,
    blocks.join(NL + NL),
  ].join(NL + NL);

  const { text, model: usedModel } = await chat(AGENCY_REPORT_PROMPT, input, { model, maxTokens: 12000, onResult });
  const body = normalizeBody(text);
  const titles = [...body.matchAll(/^## (.+)$/gm)].map((m) => m[1].trim());
  if (!AGENCY_SECTIONS.every((t) => titles.includes(t))) {
    throw new AiError('AI가 정해진 섹션으로 작성하지 못했습니다. 다시 만들어 주세요.');
  }
  const checks = checkBody(body, input);

  const meta = {
    generatedAt: new Date().toISOString(),
    farmCount: farms.length,
    activeFarmCount: active.length,
    rows: ordered.map((x) => ({
      farmId: x.farm.id,
      name: x.farm.name,
      region: x.farm.region || '',
      station: x.farm.nearest_station_name || null,
      memos: x.memos.length,
      deaths: x.an.deaths.events,
      deathsMin: x.an.deaths.min,
      deathsMax: x.an.deaths.max,
      deathsUnknown: x.an.deaths.unknown,
      topicCounts: Object.fromEntries(x.an.topics.map((t) => [t.topic, t.count])),
      open: x.an.open.length,
      vaccinations: x.memos.filter((m) => m.kind === '접종').length,
      visits: x.memos.filter((m) => m.kind === '방문').length,
      waterTempC: x.temp?.waterTempC ?? null,
    })),
    topicOrder: TOPICS.filter((t) => topicTotals.some((x) => x.topic === t)),
    topicTotals,
    deathTotals,
    open: active.flatMap((x) => x.an.open.map((m) => ({ farm: x.farm.name, date: m.date, topic: m.a.primary, status: m.a.status, text: clip(m.body, 90) }))),
    stations: [...new Map(farms.filter((f) => f.nearest_station_code).map((f) => [f.nearest_station_code, f.nearest_station_name])).entries()].map(
      ([code, name]) => ({ code, name, farms: farms.filter((f) => f.nearest_station_code === code).length, observation: temps.get(code) ?? null }),
    ),
  };

  return {
    model: usedModel,
    promptVersion: AGENCY_PROMPT_VERSION,
    body,
    checks,
    memoCount: memos.length,
    snapshot: {
      input,
      memos: active.flatMap((x) => x.memos.map((m) => ({ n: m.n, id: m.uuid, date: m.date, kind: m.kind, author: m.author, body: m.body, farmName: x.farm.name }))),
      prevMemos: [],
      comments: [],
      meta,
    },
  };
}

/** "## 제목" 과 "- 항목" 줄만 남긴다(모델이 붙인 머리말·코드블록 제거). */
function normalizeBody(text) {
  const lines = text.replace(/^```\w*\n|\n```$/g, '').split(/\r?\n/);
  const out = [];
  let started = false;
  for (const raw of lines) {
    const line = raw.trim();
    if (/^##\s+/.test(line)) {
      started = true;
      if (out.length) out.push('');
      out.push(`## ${line.replace(/^##\s+/, '').trim()}`);
    } else if (started && line) {
      out.push(line.startsWith('- ') ? line : line.replace(/^[*•]\s+/, '- ').replace(/^(?!- )/, '- '));
    }
  }
  return out.join('\n');
}

function checkBody(body, input) {
  const allowed = numbersIn(input);
  const checks = [];
  let section = '';
  for (const line of body.split('\n')) {
    if (line.startsWith('## ')) {
      section = line.slice(3);
      continue;
    }
    if (!line.trim()) continue;
    const problems = [];
    const extra = [...numbersIn(line)].filter((x) => !allowed.has(x));
    if (extra.length) problems.push(`입력 자료에 없는 수치(${extra.join(', ')})`);
    const terms = [...new Set(line.match(DIAGNOSIS) ?? [])].filter((t) => !input.includes(t));
    if (terms.length) problems.push(`메모에 없는 진단·처치 표현(${terms.join(', ')})`);
    if (problems.length) checks.push({ section, text: line.replace(/^- /, ''), problem: problems.join(' / ') });
  }
  return checks;
}
