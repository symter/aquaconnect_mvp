-- 구성원 초대: a single-use link (/#/invite/<code>) that lets someone sign up
-- straight into an institute with a preset role.
create table invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  code text not null unique,
  role text not null check (role in ('director', 'staff', 'employee')),
  -- Who it's for, as the inviter typed it ("김관리 010-…"); display only.
  note text not null default '',
  created_by uuid references members(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_member_id uuid references members(id) on delete set null,
  revoked_at timestamptz
);
create index invitations_org_id_idx on invitations(org_id, created_at desc);
