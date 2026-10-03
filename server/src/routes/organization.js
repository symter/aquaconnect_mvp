import { Router } from 'express';

import { requireAuth } from '../auth.js';
import { query } from '../db.js';
import { AUDIT_RETENTION, diffFields, recordAudit } from '../lib/audit.js';
import { formatPhone, validatePhone } from '../lib/validators.js';

// The signed-in member's institute (관리원 정보) and its 변경 이력.
export const organizationRouter = Router();
organizationRouter.use(requireAuth);

function toOrgJson(row) {
  return {
    id: row.id,
    name: row.name,
    address: row.address ?? '',
    phone: row.phone ?? '',
    businessRegNo: row.business_reg_no ?? '',
  };
}

async function me(memberId) {
  const { rows } = await query(
    `select m.role, m.org_id, o.id, o.name, o.address, o.phone, o.business_reg_no
     from members m join organizations o on o.id = m.org_id where m.id = $1`,
    [memberId],
  );
  return rows[0];
}

organizationRouter.get('/', async (req, res) => {
  res.json(toOrgJson(await me(req.memberId)));
});

const ORG_FIELDS = [
  ['name', '관리원명'],
  ['address', '주소'],
  ['phone', '대표 연락처'],
];

organizationRouter.put('/', async (req, res) => {
  const current = await me(req.memberId);
  if (!['owner', 'director'].includes(current.role)) {
    return res.status(403).json({ error: '소유자·원장만 관리원 정보를 수정할 수 있습니다.' });
  }
  const name = String(req.body?.name ?? '').trim();
  const address = String(req.body?.address ?? '').trim();
  const phoneRaw = String(req.body?.phone ?? '').trim();
  if (!name) return res.status(400).json({ error: '관리원명을 입력해 주세요.' });
  if (!address) return res.status(400).json({ error: '주소를 입력해 주세요.' });
  if (phoneRaw && validatePhone(phoneRaw)) return res.status(400).json({ error: '연락처를 정확히 입력해 주세요.' });
  const phone = phoneRaw ? formatPhone(phoneRaw) : null;

  const { rows } = await query(
    'update organizations set name = $2, address = $3, phone = $4 where id = $1 returning *',
    [current.org_id, name, address, phone],
  );
  const changes = diffFields(current, rows[0], ORG_FIELDS);
  if (changes.length) {
    await recordAudit({
      orgId: current.org_id,
      actorId: req.memberId,
      entityType: 'organization',
      entityId: current.org_id,
      entityName: name,
      action: 'update',
      changes,
    });
  }
  res.json(toOrgJson(rows[0]));
});

// 변경 이력, newest first. `before` (ISO time) pages backwards; `type`
// filters to member / farm / organization.
organizationRouter.get('/audit-logs', async (req, res) => {
  const type = ['member', 'farm', 'organization'].includes(req.query.type) ? req.query.type : null;
  const before = req.query.before && !Number.isNaN(Date.parse(req.query.before)) ? new Date(req.query.before) : null;
  const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 100);
  const { rows } = await query(
    `select * from audit_logs
     where org_id = (select org_id from members where id = $1)
       and created_at > now() - interval '${AUDIT_RETENTION}'
       and ($2::text is null or entity_type = $2)
       and ($3::timestamptz is null or created_at < $3)
     order by created_at desc
     limit $4`,
    [req.memberId, type, before, limit + 1],
  );
  const page = rows.slice(0, limit);
  res.json({
    items: page.map((r) => ({
      id: r.id,
      actorName: r.actor_name,
      entityType: r.entity_type,
      entityName: r.entity_name,
      action: r.action,
      changes: r.changes ?? [],
      createdAt: r.created_at,
    })),
    nextBefore: rows.length > limit ? page[page.length - 1].created_at : null,
  });
});
