-- Run the canonical Team Skills create-cup routine against disposable PostgreSQL.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated')
 then create role authenticated;end if;
 if not exists(select 1 from pg_roles where rolname='anon')
 then create role anon;end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table public.users(
 id uuid primary key, role text not null, is_blocked boolean not null);
create table public.stadiums(id uuid primary key,governorate text);
create table public.team_skills_cups(
 id uuid primary key default gen_random_uuid(),name text not null,
 governorate text not null,stadium_id uuid not null,
 starts_at timestamptz not null,ends_at timestamptz not null,
 max_teams integer not null,hospitality_fee numeric not null,
 prizes jsonb not null,image_url text,
 created_by uuid not null,status text not null default 'draft');
create table public.team_skills_phases(
 cup_id uuid not null,stage_no integer not null,code text not null,
 name_ar text not null,category text not null,weight numeric not null,
 metric text not null,target numeric,best_ms integer,worst_ms integer);
create table public.team_skills_audit(
 cup_id uuid not null,actor_id uuid not null,action text not null);
-- Mirror the existing authenticated SELECT grants on the live cup,
-- phase configuration and admin-visible audit tables for positive readback.
-- In this disposable fixture only, readback is not a cross-account RLS test.
grant select on public.team_skills_cups,public.team_skills_phases,
 public.team_skills_audit to authenticated;
-- ACTUAL_TEAM_SKILLS_ADMIN_CHECK
-- ACTUAL_TEAM_SKILLS_CREATE_CUP
grant usage on schema vsp_skills_private to authenticated;
grant execute on function vsp_skills_private.is_admin() to authenticated;
insert into public.users(id,role,is_blocked) values
('00000000-0000-0000-0000-000000009001','admin',false),
('00000000-0000-0000-0000-000000009002','admin',true),
('00000000-0000-0000-0000-000000009003','player',false);
insert into public.stadiums(id,governorate) values
('00000000-0000-0000-0000-000000000101','Aswan'),
('00000000-0000-0000-0000-000000000102','Cairo');
begin;
do $anon_denied$
begin
 if has_function_privilege('anon',
 'public.team_skills_create_cup(text,text,uuid,timestamptz,timestamptz,integer,numeric,jsonb,text)',
 'EXECUTE') then raise exception 'ANON_CAN_CREATE_CUP';end if;
end $anon_denied$;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009003',true);
do $player_denied$
declare denied boolean:=false;
begin
 begin
 perform public.team_skills_create_cup(
  'Unofficial team cup','Aswan',
  '00000000-0000-0000-0000-000000000101',
  now()+interval '2 days',now()+interval '2 days 150 minutes');
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'PLAYER_CREATED_CUP';end if;
end $player_denied$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009002',true);
do $blocked_admin_denied$
declare denied boolean:=false;
begin
 begin
 perform public.team_skills_create_cup(
  'Blocked admin cup','Aswan',
  '00000000-0000-0000-0000-000000000101',
  now()+interval '2 days',now()+interval '2 days 150 minutes');
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'BLOCKED_ADMIN_CREATED_CUP';end if;
end $blocked_admin_denied$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009001',true);
do $cross_stadium_denied$
declare denied boolean:=false;
begin
 begin
 perform public.team_skills_create_cup(
  'Wrong venue location','Cairo',
  '00000000-0000-0000-0000-000000000101',
  now()+interval '2 days',now()+interval '2 days 150 minutes');
 exception when others then
  if position('stadium governorate mismatch' in lower(sqlerrm))>0
  then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'CROSS_GOVERNORATE_CUP_CREATED';end if;
end $cross_stadium_denied$;
do $positive_admin_creation$
declare v_cup uuid;
begin
 v_cup:=public.team_skills_create_cup(
  'Aswan Skills Cup','  asWAN  ',
  '00000000-0000-0000-0000-000000000101',
  now()+interval '2 days',now()+interval '2 days 150 minutes',
  4, 50, '[]'::jsonb, null);
 if v_cup is null or not exists(
   select 1 from public.team_skills_cups
   where id=v_cup and name='Aswan Skills Cup'
     and governorate='Aswan' and status='draft'
     and created_by='00000000-0000-0000-0000-000000009001'
     and max_teams=4 and hospitality_fee=50)
 then raise exception 'ADMIN_DRAFT_CUP_NOT_CREATED';end if;
 if (select count(*) from public.team_skills_phases where cup_id=v_cup)<>12
 or (select sum(weight) from public.team_skills_phases where cup_id=v_cup)<>100
 or (select count(*) from public.team_skills_audit
     where cup_id=v_cup and action='create_cup')<>1
 then raise exception 'CUP_STAGES_OR_AUDIT_INCORRECT';end if;
end $positive_admin_creation$;
reset role;
do $no_extra_side_effects$
begin
 if (select count(*) from public.team_skills_cups)<>1
 or (select count(*) from public.team_skills_audit)<>1
 or (select count(*) from public.team_skills_phases)<>12
 then raise exception 'DENIED_CUP_CREATION_LEFT_ROWS';end if;
end $no_extra_side_effects$;
rollback;
