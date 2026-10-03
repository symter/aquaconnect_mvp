-- 문의 left by a farm from its shared report page (/r/:token). Each one is
-- also mirrored into the memo feed and sent to the institute as an
-- 'inquiry' notification.
create table inquiries (
  id uuid primary key default gen_random_uuid(),
  share_link_id uuid not null references share_links(id) on delete cascade,
  farm_id uuid not null references farms(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);
create index inquiries_share_link_id_created_at_idx on inquiries(share_link_id, created_at desc);

alter table notifications drop constraint notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in ('risk', 'memo', 'test', 'inquiry'));
