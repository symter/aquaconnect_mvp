-- 변경 이력 now also records memos (등록·수정·완료·삭제, 댓글 등록·삭제), so
-- 원장 can see deleted memos and every memo's history in one place.
alter table audit_logs drop constraint if exists audit_logs_entity_type_check;
alter table audit_logs
  add constraint audit_logs_entity_type_check check (entity_type in ('member', 'farm', 'organization', 'memo'));
create index if not exists audit_logs_org_id_entity_type_created_at_idx on audit_logs(org_id, entity_type, created_at desc);
