import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import 'express-async-errors';

import { authRouter } from './routes/auth.js';
import { diseaseInfoRouter } from './routes/diseaseInfo.js';
import { farmsRouter } from './routes/farms.js';
import { memosRouter } from './routes/memos.js';
import { oceanRouter } from './routes/ocean.js';
import { publicRouter } from './routes/public.js';
import { reportsRouter } from './routes/reports.js';
import { shareLinksRouter } from './routes/shareLinks.js';

const app = express();
app.use(cors());
// Memo photos arrive base64-encoded in the JSON body (up to 5 × 5MB).
app.use(express.json({ limit: '40mb' }));

app.get('/health', (req, res) => res.json({ ok: true }));

app.use('/api/auth', authRouter);
app.use('/api/farms', farmsRouter);
app.use('/api/memos', memosRouter);
app.use('/api/disease-info', diseaseInfoRouter);
app.use('/api/reports', reportsRouter);
app.use('/api/share-links', shareLinksRouter);
app.use('/api/ocean', oceanRouter);
app.use('/api/public', publicRouter);

// Keep this last: anything that throws inside a route (including a rejected
// promise from Express 4's own async wrapping) lands here instead of
// hanging the request.
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: '서버 오류가 발생했습니다.' });
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`AquaConnect API listening on :${port}`));
