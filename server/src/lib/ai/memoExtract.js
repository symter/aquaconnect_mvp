// 메모 원문에서 수조 번호·현장 실측값·이상 징후를 뽑는다 — symterAI src/lib/memo-extract.ts 이식(리포트 양식에 쓰는 부분만).
// 원칙: 원문에 없는 값은 만들지 않는다. 수조가 적히지 않은 문장은 '양식장 전체' 기록으로 둔다(tanks = []).
// 한 문장 안에서는 앞에 나온 수조가 뒤 구절로 이어진다("2번 수조 섭이 저하, 체표 출혈"). 문장이 바뀌면 이어지지 않는다
// (다음 문장이 같은 수조 이야기인지 확신할 수 없기 때문).

const LIST = String.raw`\d{1,3}(?:\s*(?:[,·、~\-]|및|와|과)\s*\d{1,3})*`;
/** "2번 수조", "2·3번 수조", "수조 4번", "5번조" ("조치·조사" 같은 낱말은 제외) */
const TANK = new RegExp(String.raw`(${LIST})\s*번?\s*수조|(${LIST})\s*번\s*조(?![치사절정류성합])|수조\s*(${LIST})\s*번?`, 'g');

function tankList(s) {
  const out = [];
  for (const m of s.matchAll(/(\d{1,3})(?:\s*[~\-]\s*(\d{1,3}))?/g)) {
    const a = Number(m[1]);
    const b = m[2] ? Number(m[2]) : a;
    if (b >= a && b - a <= 20) for (let i = a; i <= b; i++) out.push(String(i));
    else out.push(String(a));
  }
  return out;
}

export function tanksIn(s) {
  const found = new Set();
  for (const m of s.matchAll(TANK)) for (const t of tankList(m[1] ?? m[2] ?? m[3])) found.add(t);
  return [...found].sort((a, b) => Number(a) - Number(b));
}

const MEASURES = [
  { name: '수온', re: /수온\s*(?:은|는|이|:)?\s*(-?\d+(?:\.\d+)?)\s*(℃|°C|도(?![가-힣]))?/g, unit: '℃', needUnit: true },
  { name: '용존산소', re: /(?:용존산소|\bDO\b)\s*(?:는|은|:)?\s*(\d+(?:\.\d+)?)\s*(mg\/L|mg\/l|ppm)?/g, unit: 'mg/L' },
  { name: 'pH', re: /\b[pP][hH]\b\s*(?:는|은|:)?\s*(\d+(?:\.\d+)?)/g, unit: '' },
  { name: '염분', re: /염분\s*(?:은|는|:)?\s*(\d+(?:\.\d+)?)\s*(psu|PSU|‰)?/g, unit: 'psu' },
];

function measurementsIn(s) {
  const out = [];
  for (const { name, re, unit, needUnit } of MEASURES) {
    for (const m of s.matchAll(re)) {
      const after = s.slice(m.index + m[0].length);
      // 단위 없이 숫자 뒤에 한글이 붙으면("수온 2회 측정") 측정값이 아니다
      if (needUnit && !m[2] && /^\s*[가-힣]/.test(after)) continue;
      out.push({ name, value: Number(m[1]), unit: m[2] === 'ppm' ? 'ppm' : unit });
    }
  }
  return out;
}

const SYMPTOM =
  /섭(?:이|식)량?\s*(?:저하|감소|부진|불량|이상|없음)|식욕\s*(?:저하|감소|부진|없음)|활력\s*(?:저하|감소|부족)|유영\s*(?:이상|불량|저하)|이상\s*유영|무기력|쏠림|가라앉|수면\s*부유|체색\s*(?:흑화|변화|이상)|흑화|출혈|궤양|병변|백점|복수|부종|안구\s*(?:돌출|백탁|출혈)|아가미\s*(?:부식|괴사|변색|이상|출혈)|지느러미\s*(?:부식|괴사|출혈)|비늘\s*(?:탈락|이상)|기생충|빈혈|폐사/g;
/** "출혈 없음", "출혈은 확인되지 않음" 처럼 부정된 징후는 뺀다 */
const NEGATED = /^\s*(?:은|는|이|가|도)?\s*(?:없|무(?![가-힣])|안\s*보|확인되지\s*않|아님|X\b)/;

function symptomsIn(s) {
  const out = new Set();
  for (const m of s.matchAll(SYMPTOM)) {
    if (NEGATED.test(s.slice(m.index + m[0].length))) continue;
    out.add(m[0].replace(/\s+/g, ' '));
  }
  return [...out];
}

const sentencesOf = (body) => body.split(/(?<=[.。!?])\s+|\n|;/).map((s) => s.trim()).filter(Boolean);
const clausesOf = (sentence) => sentence.split(/,\s*(?!\d)|，/).map((s) => s.trim()).filter(Boolean);
const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);

export function extractMemo(body) {
  const observations = [];
  for (const sentence of sentencesOf(body)) {
    let carry = [];
    let prev = null;
    for (const clause of clausesOf(sentence)) {
      const found = tanksIn(clause);
      if (found.length) carry = found;
      const tanks = found.length ? found : carry;
      // 같은 수조를 이어서 말하는 구절은 한 관찰로 합친다
      if (prev && same(prev.tanks, tanks)) {
        prev.text += `, ${clause}`;
      } else {
        prev = { tanks, text: clause, symptoms: [], measurements: [] };
        observations.push(prev);
      }
      prev.symptoms = [...new Set([...prev.symptoms, ...symptomsIn(clause)])];
      prev.measurements.push(...measurementsIn(clause));
    }
  }
  return observations;
}

/**
 * memos: [{ n, date, kind, body }] → 수조별 관찰 건수, 메모에 적힌 실측값, 기록이 있는 날짜.
 */
export function summarizeField(memos) {
  const sorted = [...memos].sort((a, b) => a.date.localeCompare(b.date) || a.n - b.n);
  const tankMap = new Map();
  const measurements = [];
  for (const m of sorted) {
    for (const o of extractMemo(m.body)) {
      for (const t of o.tanks) {
        const row = tankMap.get(t) ?? { tank: t, count: 0, symptomCount: 0 };
        row.count++;
        if (o.symptoms.length) row.symptomCount++;
        tankMap.set(t, row);
      }
      for (const x of o.measurements) measurements.push({ ...x, date: m.date, tanks: o.tanks });
    }
  }
  return {
    tanks: [...tankMap.values()].sort((a, b) => Number(a.tank) - Number(b.tank)),
    measurements,
    recordDates: [...new Set(sorted.map((m) => m.date))],
  };
}
