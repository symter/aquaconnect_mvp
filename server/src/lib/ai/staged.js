// 긴 입력 단계 처리 — symterAI src/lib/report-jobs.ts 의 '중간 정리 → 통합' 이식.
// 메모 줄이 한 번에 보낼 길이(budget)를 넘으면 날짜순 묶음으로 나눠 묶음마다 '중간 정리'(근거 번호가 붙은 항목)를
// 만들고, 최종 리포트는 그 항목들로 쓴다. 메모를 잘라내지 않는다: 한 건이 한 번에 안 들어가면 오류로 알리고,
// 정리에서 빠진 메모는 원문 그대로 항목으로 옮긴다. 정리 결과는 입력과 대조해 근거·수치가 맞지 않는 항목을 버린다.

import { AiError, chat } from './model.js';
import { SUMMARIZE_PROMPT } from './prompts.js';

const NL = '\n';

/** 한 번에 보낼 사용자 입력의 최대 글자 수. Gemini 는 컨텍스트가 넉넉해 기본값을 크게 둔다. */
export const inputBudget = () => Number(process.env.MODEL_INPUT_CHARS) || 120_000;

/** 단계가 늘어나는 것을 막는 상한(중간 정리를 다시 정리하는 횟수) */
const MAX_LEVELS = 3;

const QTY = /(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)\s*(만|천|백)?\s*(마리|미(?![가-힣])|개체)/g;
const MULT = { 만: 10000, 천: 1000, 백: 100 };
const qtyOf = (n, mult) => Number(n.replace(/,/g, '')) * (mult ? MULT[mult] : 1);
const numbersIn = (s) => new Set((s.match(/\d+(?:\.\d+)?/g) ?? []).map(Number));
const quantitiesIn = (s) => new Set([...s.matchAll(QTY)].map((m) => qtyOf(m[1], m[2])));

/** 단위(메모 한 줄 또는 앞 단계 항목 한 줄)를 순서대로 묶어 한 묶음이 budget 을 넘지 않게 한다. */
export function packUnits(units, budget) {
  const out = [];
  let cur = [];
  let len = 0;
  for (const u of units) {
    if (u.text.length > budget) {
      throw new AiError(
        `메모 [#${u.ids.join(', #')}]이(가) 한 번에 처리할 수 있는 길이(${budget.toLocaleString()}자)보다 깁니다(${u.text.length.toLocaleString()}자). 내용을 자르지 않고 중단했습니다. 해당 메모를 선택에서 빼거나 댓글 포함을 꺼 주세요.`,
        400,
      );
    }
    if (cur.length && len + u.text.length + 1 > budget) {
      out.push(cur);
      cur = [];
      len = 0;
    }
    cur.push(u);
    len += u.text.length + 1;
  }
  if (cur.length) out.push(cur);
  return out;
}

/** 중간 정리 결과를 입력과 대조한다. 근거·수치가 맞지 않는 항목은 버리고(기록에 남김), 반영되지 않은 메모는 원문 그대로 옮긴다. */
export function checkEntries(parsed, units) {
  const ids = new Set(units.flatMap((u) => u.ids));
  const refs = new Set(units.flatMap((u) => u.refs));
  const source = units.map((u) => u.text).join(NL);
  const nums = numbersIn(source);
  const qty = quantitiesIn(source);
  const entries = [];
  const rejected = [];
  for (const e of parsed.entries ?? []) {
    if (!e || typeof e.text !== 'string' || !e.text.trim()) continue;
    const evidence = [...new Set((Array.isArray(e.evidence) ? e.evidence : []).map((n) => Number(String(n).replace('#', ''))).filter((id) => ids.has(id)))];
    const eRefs = [...new Set((Array.isArray(e.comment_refs) ? e.comment_refs : []).map(String).filter((k) => refs.has(k)))];
    if (!evidence.length) {
      rejected.push({ text: e.text, reason: '입력에 있는 근거 메모 번호가 없음' });
      continue;
    }
    const extra = [...numbersIn(e.text)].filter((n) => !nums.has(n));
    if (extra.length) {
      rejected.push({ text: e.text, reason: `입력에 없는 수치(${extra.join(', ')})` });
      continue;
    }
    const badQty = [...e.text.matchAll(QTY)].filter((m) => !qty.has(qtyOf(m[1], m[2]))).map((m) => m[0].trim());
    if (badQty.length) {
      rejected.push({ text: e.text, reason: `원문에 마릿수로 적히지 않은 수량(${badQty.join(', ')})` });
      continue;
    }
    const date = typeof e.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(e.date) && source.includes(e.date) ? e.date : null;
    entries.push({ text: e.text.trim(), evidence, refs: eRefs, date });
  }
  const covered = new Set(entries.flatMap((e) => e.evidence));
  const fallbacks = [];
  for (const u of units) {
    for (const id of u.ids) {
      if (covered.has(id)) continue;
      fallbacks.push(id);
      covered.add(id);
      entries.push({ text: `${u.text.split(NL)[0]} (정리에서 빠져 원문 그대로 옮김)`, evidence: [id], refs: [], date: u.text.match(/\d{4}-\d{2}-\d{2}/)?.[0] ?? null, verbatim: true });
    }
  }
  return { entries, rejected, fallbacks };
}

const entryUnit = (e) => ({
  ids: e.evidence,
  refs: e.refs,
  text: `[#${e.evidence.join(', #')}]${e.date ? ` ${e.date}` : ''} ${e.text}${e.refs.length ? ` 〔댓글 ${e.refs.join(', ')}〕` : ''}`,
});

async function summarize(units, { model, onResult }) {
  const { text } = await chat(SUMMARIZE_PROMPT, units.map((u) => u.text).join(NL), { model, maxTokens: 8000, json: true, onResult });
  const body = text.replace(/^```\w*\n|\n```$/g, '');
  let parsed;
  try {
    parsed = JSON.parse(body.slice(body.indexOf('{'), body.lastIndexOf('}') + 1));
  } catch {
    throw new AiError('AI가 중간 정리를 정해진 형식(JSON)으로 작성하지 못했습니다. 다시 만들어 주세요.');
  }
  return checkEntries(parsed, units);
}

/**
 * units: [{ ids:[메모번호], refs:[댓글키], text }] — 메모 한 건(과 그 댓글)이 한 단위.
 * fixedChars: 메모와 상관없이 최종 입력에 들어가는 글자 수(집계·공공데이터 등).
 * → null(나눌 필요 없음) 또는 { block, stages:[{ label, entries, rejected, fallbacks }] }
 */
export async function condense(units, fixedChars, { model, onResult }) {
  const budget = inputBudget();
  const fits = (us) => fixedChars + us.reduce((n, u) => n + u.text.length + 1, 0) <= budget;
  if (fits(units)) return null;
  if (fixedChars + 200 >= budget) {
    throw new AiError(`메모와 상관없이 들어가는 고정 입력(${fixedChars.toLocaleString()}자)만으로 한 번에 처리할 수 있는 길이(${budget.toLocaleString()}자)에 가깝습니다. 기간을 줄여 주세요.`, 400);
  }
  const stages = [];
  let current = units;
  for (let level = 0; level < MAX_LEVELS; level++) {
    const chunks = packUnits(current, budget - fixedChars);
    if (level > 0 && chunks.every((c) => c.length === 1) && chunks.length >= current.length) {
      throw new AiError('중간 정리 항목을 더 줄일 수 없습니다. 선택한 메모 수를 줄여 다시 시도해 주세요.', 400);
    }
    const next = [];
    for (const [i, chunk] of chunks.entries()) {
      const r = await summarize(chunk, { model, onResult });
      stages.push({ label: `${level === 0 ? '중간 정리' : `중간 정리 ${level + 1}차`} ${i + 1}/${chunks.length}`, entries: r.entries.length, rejected: r.rejected, fallbacks: r.fallbacks });
      next.push(...r.entries.map(entryUnit));
    }
    current = next;
    if (fits(current)) return { block: current.map((u) => `- ${u.text}`).join(NL), stages };
  }
  throw new AiError(`중간 정리를 ${MAX_LEVELS}번 거쳐도 입력이 한 번에 처리할 수 있는 길이보다 깁니다. 기간을 나눠 만들어 주세요.`, 400);
}
