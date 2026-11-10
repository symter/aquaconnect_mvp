-- 원장 = 관리원 안의 유일한 관리 권한. '소유자' 역할은 원장으로 통합하고,
-- 원장 지정·해제는 관리자 대시보드(/api/admin)에서만 한다.

alter table members drop constraint if exists members_role_check;
update members set role = 'director' where role = 'owner';
update members set is_owner = false where is_owner;
alter table members add constraint members_role_check check (role in ('director', 'staff', 'employee'));

-- 원장은 더 이상 초대로 줄 수 없다: 아직 안 쓴 원장 초대는 취소.
update invitations set revoked_at = now() where role = 'director' and accepted_at is null and revoked_at is null;
