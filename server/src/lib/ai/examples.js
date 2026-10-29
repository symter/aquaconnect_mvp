// 전문가가 승인한 이전 리포트를 지시문에 '참고 예시'로 붙인다 — symterAI src/lib/examples.ts 이식.
// 모델이 학습하는 것이 아니라, 같은 관리원의 승인본에서 문체·구성·근거 표기를 따라 쓰게 하는 방식이다.
// - 같은 관리원·같은 리포트 유형의 승인(확정·발송) 판만 쓴다. 전문가가 고친 섹션이 있는 판을 먼저, 그다음 최근 판.
// - 예시의 사실·날짜·수량은 가져오지 못하게 지시문에 적고, 결과는 기존 검증(verifyDraft)이 다시 확인한다.
// - AI_REPORT_EXAMPLES=0 이면 쓰지 않는다.

import { query } from '../../db.js';
import { EXAMPLES_HEADER } from './prompts.js';

const MAX_EXAMPLES = 2;
const EXAMPLE_CHARS = 1200;

/** 줄 단위로 글자 수 한도까지만 남긴다(문장 중간에서 자르지 않는다). */
function clip(body, limit) {
  if (body.length <= limit) return body;
  const out = [];
  let n = 0;
  for (const line of body.split('\n')) {
    if (n + line.length + 1 > limit) break;
    out.push(line);
    n += line.length + 1;
  }
  return `${out.join('\n').trimEnd()}\n(이하 생략)`;
}

/**
 * → { text, used: [{ reportId, version, editedSections }] } 또는 null(승인본 없음·꺼짐)
 * excludeFarmId: 같은 양식장의 리포트는 예시로 쓰지 않는다(이번 메모와 사실이 겹칠 수 있어서).
 */
export async function approvedExamples(orgId, type, { excludeFarmId = null } = {}) {
  if (process.env.AI_REPORT_EXAMPLES === '0') return null;
  const { rows } = await query(
    `select r.id as report_id, v.version, v.body, v.edited_sections
       from ai_reports r join ai_report_versions v on v.report_id = r.id and v.version = r.version
      where r.org_id = $1 and r.type = $2 and r.status in ('confirmed', 'sent')
        and ($3::uuid is null or r.farm_id is distinct from $3::uuid)
      order by v.approved_at desc limit 30`,
    [orgId, type, excludeFarmId],
  );
  const picks = rows
    .map((r) => ({ r, edited: Array.isArray(r.edited_sections) ? r.edited_sections : [] }))
    // 정렬은 안정적이므로 같은 그룹 안에서는 최근 순이 유지된다
    .sort((a, b) => Number(b.edited.length > 0) - Number(a.edited.length > 0))
    .slice(0, MAX_EXAMPLES);
  if (!picks.length) return null;
  const blocks = picks.map(({ r, edited }, i) => {
    const note = edited.length ? `전문가가 고친 섹션: ${edited.join(', ')}` : '전문가 수정 없이 승인';
    return `〔예시 ${i + 1} — ${note}〕\n${clip(r.body, EXAMPLE_CHARS)}`;
  });
  return {
    text: `${EXAMPLES_HEADER}\n\n${blocks.join('\n\n')}`,
    used: picks.map(({ r, edited }) => ({ reportId: r.report_id, version: r.version, editedSections: edited })),
  };
}
