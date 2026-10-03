-- A farm with no NIFS reading yet / a report generated without one used to
-- store 0 here, which the app rendered as a real "0.0℃". Null now means
-- "no reading".
alter table farms alter column water_temp drop not null;
alter table farms alter column water_temp drop default;
update farms set water_temp = null where water_temp = 0;

alter table reports alter column avg_temp drop not null;
alter table reports alter column avg_temp drop default;
update reports set avg_temp = null where avg_temp = 0;

-- 최근 방문 is derived from the latest institute memo, so a report can
-- legitimately have none.
alter table reports alter column last_visit_days drop not null;
alter table reports alter column last_visit_days drop default;
update reports r set last_visit_days = null
where not exists (select 1 from memos m where m.farm_id = r.farm_id and m.author_type = 'institute');
