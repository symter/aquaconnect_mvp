-- 메모 수정 이력: each row is one edit, holding the content as it stood
-- *before* that edit. Only owners/directors are sent the old content.
create table memo_edits (
  id uuid primary key default gen_random_uuid(),
  memo_id uuid not null references memos(id) on delete cascade,
  editor_member_id uuid references members(id) on delete set null,
  editor_name text not null default '',
  previous_content text not null,
  edited_at timestamptz not null default now()
);
create index memo_edits_memo_id_idx on memo_edits(memo_id, edited_at);
