-- Server-generated settings that must survive restarts (e.g. the Web Push
-- VAPID key pair, created on first use when no env var provides one).
create table app_config (
  key text primary key,
  value text not null
);

-- One row per browser/device that allowed notifications for a member.
create table push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now()
);
create index push_subscriptions_member_id_idx on push_subscriptions(member_id);

-- The in-app 알림함 (notification inbox).
create table notifications (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  type text not null check (type in ('risk', 'memo', 'test')),
  title text not null,
  body text not null,
  link text,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_member_id_created_at_idx on notifications(member_id, created_at desc);

-- 마이페이지 > 알림 설정. No row = defaults (everything on).
create table notification_settings (
  member_id uuid primary key references members(id) on delete cascade,
  risk_alerts boolean not null default true,
  memo_alerts boolean not null default true
);
