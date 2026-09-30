import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { pool, query } from '../db.js';
import { orgIdForMember } from '../lib/orgScope.js';
import { notifyMembers } from '../lib/notify.js';
import { refreshReportQuietly } from './reports.js';

export const memosRouter = Router();
memosRouter.use(requireAuth);

const MAX_PHOTOS = 5;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const ALLOWED_PHOTO_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

function toMemoJson(row) {
  return {
    id: row.id,
    orgId: row.org_id,
    farmId: row.farm_id,
    farmName: row.farm_name,
    authorType: row.author_type,
    authorName: row.author_name,
    content: row.content,
    tags: row.tags ?? [],
    photoCount: row.photo_count,
    photoIds: row.photo_ids ?? [],
    readByFarm: row.read_by_farm,
    createdAt: row.created_at,
  };
}

const PHOTO_IDS_SQL = `coalesce(
  (select array_agg(p.id::text order by p.created_at) from memo_photos p where p.memo_id = mm.id),
  '{}'
) as photo_ids`;

memosRouter.get('/', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const farmId = req.query.farmId ?? null;
  const { rows } = await query(
    `select mm.*, f.name as farm_name, ${PHOTO_IDS_SQL}
     from memos mm left join farms f on f.id = mm.farm_id
     where mm.org_id = $1 and ($2::uuid is null or mm.farm_id = $2)
     order by mm.created_at desc`,
    [orgId, farmId],
  );
  res.json(rows.map(toMemoJson));
});

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

memosRouter.get('/photos/:photoId', async (req, res) => {
  if (!UUID_RE.test(req.params.photoId)) return res.status(404).json({ error: '사진을 찾을 수 없습니다.' });
  const orgId = await orgIdForMember(req.memberId);
  const { rows } = await query(
    `select p.content_type, p.data
     from memo_photos p join memos mm on mm.id = p.memo_id
     where p.id = $1 and mm.org_id = $2`,
    [req.params.photoId, orgId],
  );
  if (!rows[0]) return res.status(404).json({ error: '사진을 찾을 수 없습니다.' });
  res.set('Content-Type', rows[0].content_type);
  res.set('Cache-Control', 'private, max-age=31536000, immutable');
  res.send(rows[0].data);
});

function decodePhotos(photos) {
  if (!Array.isArray(photos)) return { decoded: [] };
  if (photos.length > MAX_PHOTOS) return { error: `사진은 최대 ${MAX_PHOTOS}장까지 첨부할 수 있습니다.` };
  const decoded = [];
  for (const photo of photos) {
    const contentType = photo?.contentType;
    if (!ALLOWED_PHOTO_TYPES.has(contentType)) return { error: '지원하지 않는 사진 형식입니다.' };
    const data = Buffer.from(String(photo?.dataBase64 ?? ''), 'base64');
    if (data.length === 0) return { error: '사진 데이터가 비어 있습니다.' };
    if (data.length > MAX_PHOTO_BYTES) return { error: '사진 한 장은 5MB 이하여야 합니다.' };
    decoded.push({ contentType, data });
  }
  return { decoded };
}

memosRouter.post('/', async (req, res) => {
  const orgId = await orgIdForMember(req.memberId);
  const { farmId = null, content, tags = [], photos = [] } = req.body ?? {};
  if (!content || !content.trim()) {
    return res.status(400).json({ error: '메모 내용을 입력해주세요.' });
  }
  const { decoded, error } = decodePhotos(photos);
  if (error) return res.status(400).json({ error });
  if (farmId) {
    const { rows: farmRows } = await query('select id from farms where org_id = $1 and id = $2', [orgId, farmId]);
    if (!farmRows[0]) return res.status(404).json({ error: '양식장을 찾을 수 없습니다.' });
  }

  const { rows: memberRows } = await query('select name from members where id = $1', [req.memberId]);
  const authorName = `수산질병관리원 · ${memberRows[0]?.name ?? ''}`;

  const client = await pool.connect();
  let memoRow;
  const photoIds = [];
  try {
    await client.query('begin');
    const { rows } = await client.query(
      `insert into memos (org_id, farm_id, author_type, author_name, content, tags, photo_count)
       values ($1, $2, 'institute', $3, $4, $5, $6)
       returning *`,
      [orgId, farmId, authorName, content, tags, decoded.length],
    );
    memoRow = rows[0];
    for (const photo of decoded) {
      const { rows: photoRows } = await client.query(
        'insert into memo_photos (memo_id, content_type, data) values ($1, $2, $3) returning id',
        [memoRow.id, photo.contentType, photo.data],
      );
      photoIds.push(photoRows[0].id);
    }
    await client.query('commit');
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
  }

  let farmName = null;
  if (memoRow.farm_id) {
    const { rows: farmRows } = await query('select name from farms where id = $1', [memoRow.farm_id]);
    farmName = farmRows[0]?.name ?? null;
    // A new 폐사 count / visit changes the farm's risk and 최근 방문.
    await refreshReportQuietly(memoRow.farm_id);
  }

  const preview = content.trim().replace(/\s+/g, ' ');
  await notifyMembers({
    orgId,
    excludeMemberId: req.memberId,
    type: 'memo',
    title: `새 메모 · ${farmName ?? '미지정'}`,
    body: `${memberRows[0]?.name ?? ''}: ${preview.length > 80 ? `${preview.slice(0, 80)}…` : preview}`,
    link: '/memo',
  });

  res.status(201).json(toMemoJson({ ...memoRow, farm_name: farmName, photo_ids: photoIds }));
});
