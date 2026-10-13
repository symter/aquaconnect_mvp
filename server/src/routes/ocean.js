import { Router } from 'express';

import { fetchNearestWaterQuality } from '../lib/femo.js';
import { fetchRealtimeObservations } from '../lib/nifs.js';

export const oceanRouter = Router();

// No auth: this just mirrors the public NIFS feed, and having it open makes
// it trivial to sanity-check the proxy is alive after a Railway deploy.
oceanRouter.get('/realtime', async (req, res) => {
  try {
    const observations = await fetchRealtimeObservations({ station: req.query.station });
    res.json(observations);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

// Latest NIFS 어장환경 survey (salinity, DO, pH, nutrients, ...) at the
// survey point nearest to lat/lon. `refresh=1` bypasses the server cache.
oceanRouter.get('/quality', async (req, res) => {
  const latitude = Number(req.query.lat);
  const longitude = Number(req.query.lon);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ error: 'lat, lon 쿼리 파라미터가 필요합니다.' });
  }
  try {
    const quality = await fetchNearestWaterQuality({
      latitude,
      longitude,
      refresh: req.query.refresh === '1' || req.query.refresh === 'true',
    });
    res.json(quality);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});
