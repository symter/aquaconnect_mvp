-- AI 리포트 판 관리·발송·종합 리포트(symterAI reports 흐름 이식).
-- 초안 → 확정(= 승인, 판 저장) → 발송. 발송 후 고치려면 '새 판 만들기'로 초안으로 되돌리고,
-- 양식장은 다시 발송될 때까지 이전 발송본을 본다. 기존 데이터는 지우지 않는다.

alter table ai_reports drop constraint if exists ai_reports_status_check;
alter table ai_reports add constraint ai_reports_status_check check (status in ('draft', 'confirmed', 'sent'));

-- farm = 양식장 관리 리포트, agency = 관리원 전체 양식장 종합 리포트(farm_id 없음)
alter table ai_reports add column type text not null default 'farm';
alter table ai_reports add constraint ai_reports_type_check check (type in ('farm', 'agency'));
alter table ai_reports alter column farm_id drop not null;
alter table ai_reports add constraint ai_reports_farm_required check (type = 'agency' or farm_id is not null);

-- 지금까지 승인된 판 수, 마지막 발송
alter table ai_reports add column version integer not null default 0;
alter table ai_reports add column sent_at timestamptz;
alter table ai_reports add column sent_by_name text;
create index ai_reports_org_type_created_at_idx on ai_reports(org_id, type, created_at desc);

-- 확정할 때마다 그 시점 본문을 한 판으로 남긴다. 이전 판은 지우지 않는다.
create table ai_report_versions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references ai_reports(id) on delete cascade,
  version integer not null,
  body text not null,
  final_opinion text not null default '',
  approved_by_name text not null default '',
  approved_at timestamptz not null default now(),
  -- AI 원본과 비교해 전문가가 고친 섹션 제목
  edited_sections jsonb not null default '[]',
  unique (report_id, version)
);

-- 양식장에 보낸 그대로(발송 스냅샷). 공유 링크로 양식장이 보는 것은 이 표의 최신 행이다.
create table ai_report_sends (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references ai_reports(id) on delete cascade,
  farm_id uuid not null references farms(id) on delete cascade,
  version integer not null,
  body text not null,
  final_opinion text not null default '',
  edited_sections jsonb not null default '[]',
  meta jsonb,
  farm_name text not null default '',
  org_name text not null default '',
  period_start date not null,
  period_end date not null,
  memo_count integer not null default 0,
  comment_count integer not null default 0,
  approved_by_name text not null default '',
  approved_at timestamptz,
  sent_by_name text not null default '',
  sent_at timestamptz not null default now()
);
create index ai_report_sends_farm_id_sent_at_idx on ai_report_sends(farm_id, sent_at desc);

-- 이미 확정된 리포트는 1판으로 기록해 둔다.
update ai_reports set version = 1 where status = 'confirmed';
insert into ai_report_versions (report_id, version, body, final_opinion, approved_by_name, approved_at)
  select id, 1, body, final_opinion, coalesce(confirmed_by_name, ''), coalesce(confirmed_at, created_at)
    from ai_reports where status = 'confirmed';
