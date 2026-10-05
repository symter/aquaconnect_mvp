-- Memos now remember which member wrote them (until now only the display
-- name "수산질병관리원 · <이름>" was stored). Existing memos are matched by
-- that name when it is unambiguous within the org.
alter table memos add column author_member_id uuid references members(id) on delete set null;
update memos mm
set author_member_id = m.id
from members m
where mm.author_type = 'institute'
  and m.org_id = mm.org_id
  and mm.author_name = '수산질병관리원 · ' || m.name
  and (select count(*) from members m2 where m2.org_id = mm.org_id and m2.name = m.name) = 1;

-- 메모 댓글.
create table memo_comments (
  id uuid primary key default gen_random_uuid(),
  memo_id uuid not null references memos(id) on delete cascade,
  author_member_id uuid references members(id) on delete set null,
  author_name text not null default '',
  content text not null,
  created_at timestamptz not null default now()
);
create index memo_comments_memo_id_idx on memo_comments(memo_id, created_at);

-- 메모 읽음: one row per member who has seen the memo.
create table memo_reads (
  memo_id uuid not null references memos(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (memo_id, member_id)
);

alter table notifications drop constraint notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in ('risk', 'memo', 'test', 'inquiry', 'comment', 'digest'));
