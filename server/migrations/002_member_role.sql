alter table members add column role text not null default 'staff' check (role in ('owner', 'director', 'staff', 'employee'));

update members set role = 'owner' where is_owner = true;
