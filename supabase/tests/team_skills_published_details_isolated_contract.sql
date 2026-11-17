-- Team Skills published details and admin-only publication, disposable PostgreSQL.
-- The real production-source is_admin, RLS policy and set_status RPC are injected.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;end if;
 if not exists(select 1 from pg_roles where rolname='anon') then
   create role anon;end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table public.users(
 id uuid primary key, role text not null, is_blocked boolean not null default false);
create table public.team_skills_cups (
 id uuid primary key,name text not null,governorate text not null,
 status text not null,published_at timestamptz);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,status text not null);
create table public.team_skills_scores(
 id uuid primary key,registration_id uuid not null,status text not null);
create table public.team_skills_audit(
 cup_id uuid not null,actor_id uuid not null,action text not null,details jsonb not null);
alter table public.team_skills_cups enable row level security;
revoke all on table public.team_skills_cups from public,anon,authenticated;
grant select on public.team_skills_cups to authenticated;
-- ACTUAL_TEAM_SKILLS_IS_ADMIN
-- ACTUAL_TEAM_SKILLS_PUBLISHED_POLICY
-- ACTUAL_TEAM_SKILLS_SET_STATUS
revoke all on function public.team_skills_set_status(uuid,text) from public,anon;
grant execute on function public.team_skills_set_status(uuid,text) to authenticated;
grant usage on schema vsp_skills_private to authenticated;
grant execute on function vsp_skills_private.is_admin() to authenticated;
insert into public.users(id,role,is_blocked) values
('00000000-0000-0000-0000-000000009001','admin',false),
('00000000-0000-0000-0000-000000009002','admin',true),
('00000000-0000-0000-0000-000000009003','player',false);
insert into public.team_skills_cups(id,name,governorate,status) values
('00000000-0000-0000-0000-000000000001','Draft','Aswan','draft'),
('00000000-0000-0000-0000-000000000002','Registration','Aswan','registration'),
('00000000-0000-0000-0000-000000000003','Live','Aswan','live'),
('00000000-0000-0000-0000-000000000004','Completed','Cairo','completed'),
('00000000-0000-0000-0000-000000000005','Cancelled','Cairo','cancelled');

begin;
-- Ordinary player: sees status-published records, not unpublished draft.
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009003',true);
do $player_reads$
begin
 if (select count(*) from public.team_skills_cups)<>4
 or exists(select 1 from public.team_skills_cups where status='draft')
 then raise exception 'PLAYER_CAN_READ_DRAFT_OR_LOST_PUBLISHED_CUP';end if;
end $player_reads$;
do $player_cannot_publish$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_set_status(
   '00000000-0000-0000-0000-000000000001','registration');
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'PLAYER_PUBLISHED_DRAFT';end if;
end $player_cannot_publish$;
reset role;
do $no_unauthorized_mutation$
begin
 if (select status from public.team_skills_cups
     where name='Draft')<>'draft'
 or (select count(*) from public.team_skills_audit)<>0
 then raise exception 'DENIED_PUBLICATION_MUTATED_EVENT';end if;
 if has_table_privilege('authenticated','public.team_skills_cups','UPDATE')
 or has_table_privilege('anon','public.team_skills_cups','SELECT')
 then raise exception 'DANGEROUS_DIRECT_WRITE_OR_ANONYMOUS_CUP_READ';end if;
end $no_unauthorized_mutation$;
-- Blocked admin cannot see drafts or publish.
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009002',true);
do $blocked_admin$
declare denied boolean:=false;
begin
 if (select count(*) from public.team_skills_cups)<>4
 then raise exception 'BLOCKED_ADMIN_SAW_DRAFT';end if;
 begin
  perform public.team_skills_set_status(
   '00000000-0000-0000-0000-000000000001','registration');
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'BLOCKED_ADMIN_PUBLISHED_DRAFT';end if;
end $blocked_admin$;
reset role;
-- Active global admin is allowed to preview and publish their platform cup.
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009001',true);
do $admin_draft$
begin
 if (select count(*) from public.team_skills_cups)<>5
 then raise exception 'ADMIN_CANNOT_PREVIEW_DRAFT';end if;
end $admin_draft$;
select public.team_skills_set_status(
 '00000000-0000-0000-0000-000000000001','registration');
reset role;
do $published_and_audited$
begin
 if not exists(select 1 from public.team_skills_cups
   where name='Draft' and status='registration'
     and published_at is not null) then
   raise exception 'PUBLICATION_DID_NOT_PERSIST';end if;
 if (select count(*) from public.team_skills_audit
     where action='change_status'
      and details->>'old'='draft' and details->>'new'='registration')<>1
 then raise exception 'PUBLICATION_AUDIT_MISSING_OR_DUPLICATED';end if;
end $published_and_audited$;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009003',true);
do $new_published_visible$
begin
 if (select count(*) from public.team_skills_cups)<>5
 or not exists(select 1 from public.team_skills_cups
   where name='Draft' and status='registration'
   and published_at is not null)
 then raise exception 'NEWLY_PUBLISHED_CUP_NOT_VISIBLE_TO_PLAYER';end if;
end $new_published_visible$;
reset role;
rollback;
