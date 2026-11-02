-- 월간 자동 리포트: 매달 초 서버가 지난달 양식장 리포트 초안을 자동으로 만든다(lib/monthlyReports.js).
-- 초안은 관리원이 검토·수정해 어가에 보낼 때까지 대기한다(자동 발송 없음).
-- source: manual(앱에서 직접 만듦) / auto(월간 자동 생성)
alter table ai_reports add column source text not null default 'manual';
alter table ai_reports add constraint ai_reports_source_check check (source in ('manual', 'auto'));
-- 같은 양식장·같은 달 자동 초안은 하나만
create unique index ai_reports_auto_farm_period_idx on ai_reports(farm_id, period_start, period_end)
  where source = 'auto' and type = 'farm';

-- 심터(관리자 포털)가 검토·수정한 때. 관리원 앱에 '심터 검토' 표시를 한다.
alter table ai_reports add column admin_reviewed_at timestamptz;

-- 자동 초안 도착 알림
alter table notifications drop constraint if exists notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in ('risk', 'memo', 'test', 'inquiry', 'comment', 'digest', 'mention', 'report'));
