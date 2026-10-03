-- 구성원 관리 is now server-backed: members can be deactivated (they keep
-- their records but can't sign in).
alter table members
  add column status text not null default 'active' check (status in ('active', 'inactive'));

-- 마이페이지 > 변경 이력: who changed which member / farm / institute data.
-- Rows older than 3 months are deleted by the server (lib/audit.js).
create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  actor_member_id uuid references members(id) on delete set null,
  actor_name text not null default '',
  entity_type text not null check (entity_type in ('member', 'farm', 'organization')),
  entity_id uuid,
  entity_name text not null default '',
  action text not null,
  -- [{ "field": "address", "label": "주소", "from": "...", "to": "..." }]
  changes jsonb not null default '[]',
  created_at timestamptz not null default now()
);
create index audit_logs_org_id_created_at_idx on audit_logs(org_id, created_at desc);
create index audit_logs_created_at_idx on audit_logs(created_at);
