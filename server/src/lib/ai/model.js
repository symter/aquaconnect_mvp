// AI 모델 연결(서버 전용) — symterAI src/lib/model.ts 의 OpenAI 호환 경로 이식 + Claude(Anthropic) 경로.
// 어느 AI 를 쓸지는 앱(lib/main.dart)이 요청에 provider 로 싣는다. 키는 환경변수에서만
// 읽고, 상태·오류·응답에 절대 싣지 않는다.
//
// 모델은 고르지 않는다. 각 AI 의 모델을 좋은 것부터 차례로 써 보고, 한도 소진(429)·과부하·
// 없는 모델이면 다음(낮은) 모델로 넘어간다(usage.js 의 modelPlan 이 순서를 정한다).

export class AiError extends Error {
  constructor(message, status = 502) {
    super(message);
    this.status = status;
  }
}

// dailyLimit: 하루 요청 한도(RPD). Gemini 는 무료 등급 값, Claude 는 하루 한도가 없어 null(제한 없음).
// 결제를 연결했거나 비용을 묶고 싶으면 MODEL_DAILY_LIMITS 로 덮어쓴다(예: {"gemini-3.8-flash":10000,"claude-opus-5-5":30}).
export const PROVIDERS = {
  gemini: {
    label: 'Gemini',
    keyEnv: ['GEMINI_API_KEY', 'MODEL_API_KEY'],
    modelsEnv: 'GEMINI_MODELS',
    models: [
      { id: 'gemini-3.8-flash', label: 'Gemini 3.8 Flash', description: '최신 Flash · 가장 정교한 정리', dailyLimit: 20 },
      { id: 'gemini-3.6-flash', label: 'Gemini 3.6 Flash', description: 'Flash 이전 버전', dailyLimit: 20 },
      { id: 'gemini-3.5-flash', label: 'Gemini 3.5 Flash', description: '품질과 속도의 균형', dailyLimit: 20 },
      { id: 'gemini-3.5-flash-lite', label: 'Gemini 3.5 Flash Lite', description: '한도 넉넉 · 사실 오류가 더 잦아 꼼꼼한 검토 필요', dailyLimit: 500 },
    ],
  },
  claude: {
    label: 'Claude',
    keyEnv: ['ANTHROPIC_API_KEY', 'CLAUDE_API_KEY'],
    modelsEnv: 'CLAUDE_MODELS',
    models: [
      { id: 'claude-opus-5-5', label: 'Claude Opus 5.5', description: '가장 정교한 정리', dailyLimit: null },
      { id: 'claude-sonnet-5-5', label: 'Claude Sonnet 5.5', description: '품질과 속도의 균형', dailyLimit: null },
      { id: 'claude-haiku-5-5', label: 'Claude Haiku 5.5', description: '가장 빠름 · 꼼꼼한 검토 필요', dailyLimit: null },
    ],
  },
};

export const DEFAULT_PROVIDER = 'gemini';
export const isProvider = (p) => Object.hasOwn(PROVIDERS, p);

const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/openai';
const CLAUDE_BASE_URL = 'https://api.anthropic.com';

function apiKey(provider) {
  for (const name of PROVIDERS[provider].keyEnv) {
    const v = process.env[name]?.trim();
    if (v) return v;
  }
  return null;
}

function limitOverrides() {
  try {
    return JSON.parse(process.env.MODEL_DAILY_LIMITS || '{}');
  } catch {
    return {};
  }
}

/**
 * 그 AI 의 모델 목록(좋은 것부터). GEMINI_MODELS / CLAUDE_MODELS 에 쉼표로 적으면 그 순서·목록을 쓴다
 * (새 모델이 나왔을 때 코드 수정 없이 바꿀 수 있게). 목록에 없는 id 는 이름 그대로 붙인다.
 */
export function modelOptions(provider) {
  const p = PROVIDERS[provider];
  const overrides = limitOverrides();
  const wanted = process.env[p.modelsEnv]?.split(',').map((s) => s.trim()).filter(Boolean);
  const base = wanted?.length
    ? wanted.map((id) => p.models.find((m) => m.id === id) ?? { id, label: id, description: '', dailyLimit: null })
    : p.models;
  return base.map((m) => ({ ...m, dailyLimit: overrides[m.id] != null ? Number(overrides[m.id]) || null : m.dailyLimit }));
}

export function modelStatus(provider) {
  const p = PROVIDERS[provider];
  const configured = Boolean(apiKey(provider));
  return {
    configured,
    provider,
    providerLabel: p.label,
    note: configured
      ? '연결 설정이 있습니다(실제 호출 성공은 사용 시 확인).'
      : `미연결 — 서버에 ${p.keyEnv[0]} 가 없습니다.`,
  };
}

export const notConfiguredMessage = (provider) =>
  `AI(${PROVIDERS[provider].label})가 연결되지 않았습니다. 서버에 ${PROVIDERS[provider].keyEnv[0]} 를 설정해 주세요.`;

/** 느린 응답 대비 대기 시간(ms). 기본 Gemini 180초, Claude 300초. */
const timeoutMs = (provider) => Number(process.env.MODEL_TIMEOUT_MS) || (provider === 'claude' ? 300_000 : 180_000);

// 이 응답이면 다음(낮은) 모델로 넘어간다: 한도 소진·과부하·일시 오류·없는 모델.
const FALL_THROUGH = new Set([404, 429, 500, 502, 503, 529]);

/** 한 모델에 한 번 요청. { status } (실패) 또는 { text, truncated, usage } 를 돌려준다. */
async function callGemini(model, system, user, { maxTokens, json }) {
  const base = (process.env.MODEL_BASE_URL?.trim() || GEMINI_BASE_URL).replace(/\/+$/, '');
  const effort = process.env.MODEL_REASONING_EFFORT?.trim() || 'low';
  const res = await fetch(`${base}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey('gemini')}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      max_tokens: maxTokens,
      temperature: 0.2,
      ...(effort && effort !== 'none' ? { reasoning_effort: effort } : {}),
      ...(json ? { response_format: { type: 'json_object' } } : {}),
    }),
    signal: AbortSignal.timeout(timeoutMs('gemini')),
  });
  if (!res.ok) return { status: res.status };
  const payload = await res.json();
  const choice = payload?.choices?.[0];
  return { text: choice?.message?.content, truncated: choice?.finish_reason === 'length', usage: payload?.usage ?? null };
}

/** Anthropic Messages API. JSON 은 프롬프트의 형식 규칙으로 받고, 파싱 쪽이 앞뒤 군더더기를 걷어 낸다. */
async function callClaude(model, system, user, { maxTokens }) {
  const base = (process.env.CLAUDE_BASE_URL?.trim() || CLAUDE_BASE_URL).replace(/\/+$/, '');
  const res = await fetch(`${base}/v1/messages`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey('claude'), 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({ model, max_tokens: maxTokens, system, messages: [{ role: 'user', content: user }] }),
    signal: AbortSignal.timeout(timeoutMs('claude')),
  });
  if (!res.ok) return { status: res.status };
  const payload = await res.json();
  const text = (payload?.content ?? []).filter((b) => b.type === 'text').map((b) => b.text).join('');
  const u = payload?.usage;
  return {
    text,
    truncated: payload?.stop_reason === 'max_tokens',
    usage: u ? { prompt_tokens: u.input_tokens ?? null, completion_tokens: u.output_tokens ?? null } : null,
  };
}

/**
 * system + user 한 번 호출. json=true 면 JSON 객체만 받도록 요청한다.
 * plan = { provider, models: [모델 id, 좋은 것부터] } — 한도 소진 등으로 넘어간 모델은 plan.models 에서
 * 빠지므로, 같은 plan 으로 이어지는 호출(중간 정리 → 최종 작성)은 그 모델을 다시 시도하지 않는다.
 * onResult({ model, outcome: 'ok'|'quota'|'error', usage }) 는 요청이 AI 서버에 닿을 때마다 불린다 — 사용량 집계용.
 */
export async function chat(system, user, { plan, maxTokens = 8000, json = false, onResult } = {}) {
  const provider = plan?.provider ?? DEFAULT_PROVIDER;
  if (!isProvider(provider)) throw new AiError('알 수 없는 AI 입니다.', 400);
  if (!apiKey(provider)) throw new AiError(notConfiguredMessage(provider), 503);
  const models = plan?.models ?? modelOptions(provider).map((m) => m.id);
  const call = provider === 'claude' ? callClaude : callGemini;

  let lastStatus = null;
  while (models.length) {
    const model = models[0];
    const report = async (outcome, usage = null) => {
      try {
        await onResult?.({ model, outcome, usage });
      } catch (err) {
        console.error('ai usage record failed', err);
      }
    };
    let r;
    try {
      r = await call(model, system, user, { maxTokens, json });
    } catch {
      throw new AiError('AI 서버에 연결하지 못했거나 응답 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    }
    if (r.status) {
      await report(r.status === 429 ? 'quota' : 'error');
      if (!FALL_THROUGH.has(r.status)) throw new AiError(`AI 서버 응답 오류(${r.status}). 서버 설정(API 키)을 확인해 주세요.`);
      console.warn(`ai: ${model} → ${r.status}, 다음 모델로 넘어감`);
      lastStatus = r.status;
      models.shift();
      continue;
    }
    await report('ok', r.usage);
    // 출력 한도에서 잘린 답변은 실제 AI 결과로 저장하지 않는다.
    if (r.truncated) throw new AiError('AI 답변이 출력 한도에서 잘렸습니다. 선택한 메모를 줄여 다시 시도해 주세요.');
    if (typeof r.text !== 'string' || !r.text.trim()) throw new AiError('AI 서버에서 표시할 답변을 받지 못했습니다.');
    return { text: r.text.trim(), model };
  }
  throw new AiError(
    lastStatus === 429
      ? '모든 AI 모델의 사용 한도를 다 썼습니다. 한도가 초기화된 뒤 다시 시도해 주세요.'
      : 'AI 서버가 응답하지 않습니다(모든 모델 시도). 잠시 후 다시 시도해 주세요.',
    lastStatus === 429 ? 429 : 502,
  );
}
