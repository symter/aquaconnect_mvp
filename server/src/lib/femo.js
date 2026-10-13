// Ported from D:\py\croll\main.py (국립수산과학원 어장환경관측자료 조회기).
// The femoSeaList feed is a periodic field survey (roughly quarterly per
// point), not a live sensor, but it is the only NIFS source for salinity,
// DO, pH, nutrients etc. — the realtime risaList feed only carries water
// temperature. Survey points carry their own coordinates, so callers ask
// for "the nearest point to this lat/lon" and get its latest survey.

const API_URL = 'https://www.nifs.go.kr/api/OpenAPI_json';
const DEFAULT_API_KEY = 'qPwOeIrU-2610-FAJMGF-2155';
const SERVICE_ID = 'femoSeaList';

// A year of data is ~700KB and changes a few times a year, so keep it in
// memory. `refresh` may bypass the cache, but not more often than this.
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const MIN_REFRESH_INTERVAL_MS = 60 * 1000;

let cache = null; // { fetchedAt: number, observations: [] }
let inFlight = null;

async function fetchYear(year) {
  const apiKey = process.env.NIFS_FEMO_API_KEY || DEFAULT_API_KEY;
  const params = new URLSearchParams({
    id: SERVICE_ID,
    key: apiKey,
    sdate: `${year}0101`,
    edate: `${year}1231`,
  });
  let lastError;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(`${API_URL}?${params}`, { headers: { Accept: 'application/json' } });
      if (!response.ok) throw new Error(`NIFS 어장환경 API HTTP 오류 ${response.status}`);
      const payload = await response.json();
      const header = payload?.header ?? {};
      if (header.resultCode !== '00') {
        throw new Error(`NIFS 어장환경 API 오류 [${header.resultCode}] ${header.resultMsg ?? ''}`);
      }
      return payload?.body?.item ?? [];
    } catch (err) {
      lastError = err;
      if (attempt < 2) await new Promise((r) => setTimeout(r, 2000));
    }
  }
  throw lastError;
}

async function loadObservations({ refresh = false } = {}) {
  const now = Date.now();
  const age = cache ? now - cache.fetchedAt : Infinity;
  const stale = age > CACHE_TTL_MS || (refresh && age > MIN_REFRESH_INTERVAL_MS);
  if (cache && !stale) return cache;
  if (inFlight) return inFlight;

  // This year's surveys may not be published yet, so always include last
  // year as well; the nearest point's newest record wins either way.
  const year = new Date().getFullYear();
  inFlight = Promise.all([fetchYear(year - 1), fetchYear(year)])
    .then(([prev, curr]) => {
      cache = {
        fetchedAt: Date.now(),
        observations: [...prev, ...curr].map(normalizeItem).filter((o) => o.latitude != null && o.longitude != null),
      };
      return cache;
    })
    .catch((err) => {
      // Serve stale data rather than nothing if NIFS is briefly down.
      if (cache) return cache;
      throw err;
    })
    .finally(() => {
      inFlight = null;
    });
  return inFlight;
}

// Called at boot so the first user doesn't wait on the ~5s NIFS download.
export function warmWaterQualityCache() {
  loadObservations().catch((err) => console.error('어장환경 데이터 미리 불러오기 실패:', err.message));
}

/**
 * The latest survey at the point closest to [latitude, longitude], plus
 * how far away that point is. Null when no point is within [maxDistanceKm].
 */
export async function fetchNearestWaterQuality({ latitude, longitude, refresh = false, maxDistanceKm = 50 }) {
  const { fetchedAt, observations } = await loadObservations({ refresh });

  const latestByPoint = new Map();
  for (const o of observations) {
    const current = latestByPoint.get(o.pointId);
    if (!current || o.observedAt > current.observedAt) latestByPoint.set(o.pointId, o);
  }

  let best = null;
  for (const o of latestByPoint.values()) {
    const distanceKm = haversineKm(latitude, longitude, o.latitude, o.longitude);
    if (!best || distanceKm < best.distanceKm) best = { ...o, distanceKm };
  }
  if (!best || best.distanceKm > maxDistanceKm) return null;

  return {
    ...best,
    distanceKm: Math.round(best.distanceKm * 10) / 10,
    fetchedAt: new Date(fetchedAt).toISOString(),
  };
}

const VALUE_FIELDS = {
  temp: 'TEMP',
  salinity: 'SAL',
  ph: 'PH',
  dissolvedOxygen: 'DO',
  cod: 'COD',
  ammonia: 'NH4_N',
  nitrate: 'NO3_N',
  nitrite: 'NO2_N',
  din: 'DIN',
  totalNitrogen: 'TN',
  dip: 'DIP',
  totalPhosphorus: 'TP',
  silicate: 'SIL',
  chlorophyll: 'CHL',
  suspendedSolids: 'SS',
};

function normalizeItem(item) {
  const surface = {};
  const bottom = {};
  for (const [key, field] of Object.entries(VALUE_FIELDS)) {
    surface[key] = toNumber(item[`${field}_S`]);
    bottom[key] = toNumber(item[`${field}_B`]);
  }
  const pad = (v) => String(v ?? '0').padStart(2, '0');
  // Survey times are Korean local time with no offset in the feed.
  const observedAt = `${item.DATE_Y}-${pad(item.DATE_M)}-${pad(item.DATE_D)}T${pad(item.TIME_H)}:${pad(item.TIME_I)}:00+09:00`;
  return {
    pointId: `${item.FISHERY}|${item.KIND}|${item.LOCATION_POINT}`,
    fishery: item.FISHERY ?? '-',
    kind: item.KIND ?? '-',
    point: item.LOCATION_POINT ?? '-',
    latitude: parseDms(item.LATITUDE),
    longitude: parseDms(item.LONGITUDE),
    observedAt,
    weather: item.WEATHER || null,
    depthM: toNumber(item.DEPTH),
    transparencyM: toNumber(item.M),
    surface,
    bottom,
  };
}

// '35°55´20˝' → 35.9222
function parseDms(text) {
  const parts = String(text ?? '').match(/\d+(?:\.\d+)?/g);
  if (!parts) return null;
  const [d, m = 0, s = 0] = parts.map(Number);
  return d + m / 60 + s / 3600;
}

function toNumber(value) {
  if (value === '' || value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLon = (lon2 - lon1) * rad;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
}
