// 메모 일괄 업로드 — symterAI src/lib/memo-parser.ts 이식.
// 엑셀에서 CSV 로 저장한 표(.csv)나 메모장 글(.txt)을 날짜별 메모로 읽는다. 원문에 없는 값은 만들지 않고,
// 읽지 못한 줄은 조용히 버리지 않고 이유와 함께 알린다.

/** 메모 종류(= 태그). 우리 앱의 기록 종류 태그와 같다. */
export const IMPORT_KINDS = ['배달', '폐사', '접종', '방문', '할일'];

const MAX_BODY = 1000;

/** UTF-8 이 아니면(옛 메모장·엑셀의 ANSI) CP949(euc-kr)로 읽는다. */
export function decodeText(bytes) {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes).replace(/^\uFEFF/, '');
  } catch {
    return new TextDecoder('euc-kr').decode(bytes);
  }
}

export function isValidDate(s) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

/** 오늘(한국 시간) YYYY-MM-DD */
export const kstToday = () => new Date(Date.now() + 9 * 3600_000).toISOString().slice(0, 10);

function inferKind(body) {
  if (/접종|백신/.test(body)) return '접종';
  if (/(폐사|사망|죽)(?!\s*(없|무|0))/.test(body)) return '폐사'; // '폐사 없음'은 폐사로 보지 않는다
  if (/배달|납품|택배|출하/.test(body)) return '배달';
  if (/방문|점검|순회|현장/.test(body)) return '방문';
  return null;
}

/** 따옴표·줄바꿈이 든 칸을 지원하는 CSV 파서. 구분자는 첫 줄에서 쉼표·탭·세미콜론 중 가장 많은 것을 쓴다. */
export function parseCsv(text) {
  const head = text.split(/\r?\n/, 1)[0] ?? '';
  const delim = [',', '\t', ';'].map((d) => [d, head.split(d).length]).sort((a, b) => b[1] - a[1])[0][0];
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === delim) {
      row.push(cell);
      cell = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(cell);
      cell = '';
      rows.push(row);
      row = [];
    } else cell += ch;
  }
  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows.filter((r) => r.some((c) => c.trim()));
}

const HEADER = {
  date: /^(날짜|일자|일시|작성일|작성일시|date)$/i,
  kind: /^(종류|구분|분류|태그|유형|kind|type|tags?)$/i,
  body: /^(내용|본문|메모|메모내용|비고|body|memo|content|text)$/i,
};
// 엑셀이 만드는 날짜: 2026-09-03 / 2026/9/3 / 2026.9.3 / 2026-09-03 14:20 / 2026년 9월 3일
const CSV_DATE = /^\s*(\d{4})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})/;

function accept(memos, warnings, label, date, body, kind, today) {
  if (!body) warnings.push(`${label}: 본문이 비어 있어 건너뛰었습니다.`);
  else if (body.length > MAX_BODY) warnings.push(`${label}: 본문이 ${MAX_BODY.toLocaleString()}자를 넘어 건너뛰었습니다.`);
  else if (date > today) warnings.push(`${label}: 미래 날짜라서 건너뛰었습니다.`);
  else memos.push({ date, kind, body });
}

/**
 * 엑셀 CSV 표 → 메모.
 * - 첫 줄이 머리글이면(날짜·종류·내용 등) 그 이름으로 열을 찾고, 아니면 [날짜, 종류, 내용] 순서로 본다(열이 둘이면 [날짜, 내용]).
 * - 종류 칸에 모르는 값이 있거나 비어 있으면 내용으로 추정하고, 추정도 안 되면 종류 없이 둔다.
 */
export function parseMemoCsv(text, today = kstToday()) {
  const rows = parseCsv(text);
  const memos = [];
  const warnings = [];
  if (!rows.length) return { memos, warnings };
  const names = rows[0].map((c) => c.trim());
  const find = (re) => names.findIndex((x) => re.test(x));
  let [di, ki, bi] = [find(HEADER.date), find(HEADER.kind), find(HEADER.body)];
  const hasHeader = di >= 0 && bi >= 0;
  if (!hasHeader) [di, ki, bi] = rows[0].length >= 3 ? [0, 1, 2] : [0, -1, 1];
  const data = hasHeader ? rows.slice(1) : rows;
  data.forEach((r, i) => {
    const line = i + (hasHeader ? 2 : 1);
    const m = CSV_DATE.exec(r[di] ?? '');
    const date = m ? `${m[1]}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}` : '';
    if (!date || !isValidDate(date)) {
      warnings.push(`${line}행: 날짜를 읽지 못해 건너뛰었습니다.`);
      return;
    }
    const body = (r[bi] ?? '').trim();
    const given = ki >= 0 ? (r[ki] ?? '').split(/[\s,#]+/).find((x) => IMPORT_KINDS.includes(x)) : undefined;
    accept(memos, warnings, `${line}행(${date})`, date, body, given ?? inferKind(body), today);
  });
  return { memos, warnings };
}

// 줄 맨 앞의 날짜: 2026-09-03 / 2026.9.3 / 2026년 9월 3일 (메모장은 연도까지 적은 날짜만 새 메모로 본다)
const DATE_LINE = /^\s*(\d{4})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})(?:\s*일)?(?=$|[\s:\-–\[(【])\s*[:\-–]?\s*(.*)$/;
const KIND_TAG = /^[\[(【]\s*(배달|폐사|접종|방문|할일)\s*[\])】]\s*[:\-–]?\s*/;
const KIND_WORD = /^(배달|폐사|접종|방문|할일)(?:\s*[:：]\s*|\s+(?!없|무))/; // '폐사 없음'은 종류 표시가 아니라 내용

/** 메모장 글 → 메모. 날짜로 시작하는 줄이 새 메모, 그 아래 날짜 없는 줄은 앞 메모에 이어 붙는다. */
export function parseMemoText(text, today = kstToday()) {
  const memos = [];
  const warnings = [];
  let cur = null;
  const flush = () => {
    if (!cur) return;
    const body = cur.lines.join('\n').trim();
    accept(memos, warnings, cur.date, cur.date, body, cur.kind ?? inferKind(body), today);
    cur = null;
  };
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trimEnd();
    const m = DATE_LINE.exec(line);
    if (m) {
      const date = `${m[1]}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}`;
      if (isValidDate(date)) {
        flush();
        let body = m[4].trim();
        let kind = null;
        const k = KIND_TAG.exec(body) ?? KIND_WORD.exec(body);
        if (k) {
          kind = k[1];
          body = body.slice(k[0].length);
        }
        cur = { date, lines: body ? [body] : [], kind };
        continue;
      }
    }
    if (cur) {
      if (line.trim()) cur.lines.push(line.trim());
    } else if (line.trim()) {
      warnings.push(`날짜가 없는 줄을 건너뛰었습니다: "${line.trim().slice(0, 30)}"`);
    }
  }
  flush();
  return { memos, warnings };
}

/** 파일 이름·내용으로 형식을 골라 읽는다. */
export function parseMemoFile(bytes, fileName) {
  const text = decodeText(bytes);
  const csv = /\.csv$/i.test(fileName) || (!/\.txt$/i.test(fileName) && /^[^\n]*[,\t;][^\n]*\n/.test(text) && CSV_DATE.test(parseCsv(text)[1]?.[0] ?? parseCsv(text)[0]?.[0] ?? ''));
  return { format: csv ? 'csv' : 'text', ...(csv ? parseMemoCsv(text) : parseMemoText(text)) };
}
