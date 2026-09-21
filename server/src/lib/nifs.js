// Ported from D:\202609\index.mjs (국립수산과학원 실시간 어장정보 조회기).
// Same normalization logic, reshaped into an importable async function
// instead of a CLI script, so the Express route can call it directly and
// Flutter Web never talks to the NIFS API (and its CORS policy) itself.

const API_URL = 'https://www.nifs.go.kr/OpenAPI_json?id=risaList';
const DEFAULT_API_KEY = 'qPwOeIrU-2607-STVDAI-1822';

const LAYER_NAMES = { '1': '표층', '2': '중층', '3': '저층' };
const STATUS_NAMES = { '1': '정상', '2': '점검' };

export async function fetchRealtimeObservations({ station } = {}) {
  const apiKey = process.env.NIFS_API_KEY || DEFAULT_API_KEY;
  const url = `${API_URL}&key=${encodeURIComponent(apiKey)}`;
  const response = await fetch(url, { headers: { Accept: 'application/json' } });
  const body = await response.text();

  if (!response.ok) {
    throw new Error(`NIFS API HTTP 오류 ${response.status}: ${body.slice(0, 300)}`);
  }

  let payload;
  try {
    payload = JSON.parse(body);
  } catch {
    throw new Error(`NIFS API가 JSON이 아닌 응답을 반환했습니다: ${body.slice(0, 300)}`);
  }

  const header = findObject(payload, ['resultCode', 'resultMsg']);
  if (header?.resultCode && !['00', '0', '200'].includes(String(header.resultCode))) {
    throw new Error(`NIFS API 오류 ${header.resultCode}: ${header.resultMsg ?? '알 수 없는 오류'}`);
  }

  let items = findItems(payload);
  if (station) {
    items = items.filter(
      (item) => String(item.sta_cde ?? '').includes(station) || String(item.sta_nam_kor ?? '').includes(station),
    );
  }
  return items.map(normalizeItem);
}

function normalizeItem(item) {
  return {
    stationCode: item.sta_cde ?? '-',
    stationName: item.sta_nam_kor ?? '-',
    observedDate: item.obs_dat ?? '-',
    observedTime: item.obs_tim ?? '-',
    layer: LAYER_NAMES[item.obs_lay] ?? item.obs_lay ?? '-',
    waterTempC: item.wtr_tmp === '' || item.wtr_tmp == null ? null : Number(item.wtr_tmp),
    status: STATUS_NAMES[item.repaire_gbn] ?? item.repaire_gbn ?? '-',
  };
}

function findItems(value, result = []) {
  if (Array.isArray(value)) {
    for (const item of value) findItems(item, result);
  } else if (value && typeof value === 'object') {
    if ('sta_cde' in value || 'sta_nam_kor' in value) result.push(value);
    else for (const child of Object.values(value)) findItems(child, result);
  }
  return result;
}

function findObject(value, keys) {
  if (!value || typeof value !== 'object') return null;
  if (keys.every((key) => key in value)) return value;
  for (const child of Object.values(value)) {
    const found = findObject(child, keys);
    if (found) return found;
  }
  return null;
}

// Farmed fish live at mid/bottom depth, not the surface, so when a station
// reports more than one layer, prefer 저층 (bottom) > 중층 (mid) > 표층
// (surface) rather than whichever happened to come first in the feed.
const LAYER_PRIORITY = ['저층', '중층', '표층'];

export function pickPreferredObservation(observations) {
  const withTemp = observations.filter((o) => o.waterTempC != null);
  for (const layer of LAYER_PRIORITY) {
    const match = withTemp.find((o) => o.layer === layer);
    if (match) return match;
  }
  return withTemp[0] ?? null;
}
