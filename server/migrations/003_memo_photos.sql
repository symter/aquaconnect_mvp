create table memo_photos (
  id uuid primary key default gen_random_uuid(),
  memo_id uuid not null references memos(id) on delete cascade,
  content_type text not null,
  data bytea not null,
  created_at timestamptz not null default now()
);
create index memo_photos_memo_id_idx on memo_photos(memo_id, created_at);
