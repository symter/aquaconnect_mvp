-- 마이페이지 > 하루 요약 설정. No row = defaults (daily at 16:00 KST and the
-- weekly Monday-morning summary both on). last_*_on (KST dates) record what
-- was already sent so a restart never sends the same summary twice.
create table digest_settings (
  member_id uuid primary key references members(id) on delete cascade,
  daily_enabled boolean not null default true,
  daily_time text not null default '16:00' check (daily_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  weekly_enabled boolean not null default true,
  last_daily_on date,
  last_weekly_on date
);
