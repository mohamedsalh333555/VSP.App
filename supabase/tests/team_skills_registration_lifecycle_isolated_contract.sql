-- Real Team Skills registration lifecycle; disposable localhost SQL only.
-- Exercises the canonical status and captain registration RPC functions.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
create table public.users (id uuid primary key,is_blocked boolean default false);
create table public.teams (id uuid primary key,captain_id uuid not null);
create table public.team_members(team_id uuid not null,user_id uuid not null);
create table public.team_skills_cups (
 id uuid primary key, status text not null, starts_at timestamptz not null,
 max_teams integer not null, published_at timestamptz);
create table public.team_skills_registrations(
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null,team_id uuid not null,captain_id uuid not null,
 goalkeeper_id uuid not null,representative_id uuid not null,
 status text not null default 'pending', unique(cup_id,team_id));
create table public.team_skills_roster(
 cup_id uuid not null,registration_id uuid not null,player_id uuid not null,
 position text not null,active boolean not null default true);
create table public.team_skills_scores(
 registration_id uuid not null,status text not null);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
-- REAL_TEAM_SKILLS_STATUS_FUNCTION
-- REAL_TEAM_SKILLS_REGISTRATION_FUNCTION
grant execute on function public.team_skills_set_status(uuid,text) to authenticated;
grant execute on function public.team_skills_register(uuid,uuid,uuid[],uuid,uuid)
to authenticated;
grant select on public.team_skills_cups,public.team_skills_registrations,
 public.team_skills_roster,public.team_skills_audit,public.team_members to authenticated;
insert into public.team_skills_cups(id,status,starts_at,max_teams) values
('00000000-0000-0000-0000-000000000001','draft',now()+interval '2 days',4),
('00000000-0000-0000-0000-000000000002','draft',now()+interval '2 days',4),
('00000000-0000-0000-0000-000000000003','registration',now()-interval '1 day',4);
insert into public.teams(id,captain_id) values
('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000009101'),
('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000009102');
insert into public.team_members(team_id,user_id)
select '00000000-0000-0000-0000-000000000101'::uuid,
('00000000-0000-0000-0000-'||lpad((1001+n)::text,12,'0'))::uuid
from generate_series(1,5) n
union all
select '00000000-0000-0000-0000-000000000102'::uuid,
('00000000-0000-0000-0000-'||lpad((1101+n)::text,12,'0'))::uuid
from generate_series(1,5) n;
insert into public.users(id)
select captain_id from public.teams union select user_id from public.team_members;

-- A captain cannot publish a draft or advance tournament status.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009101',true);
do $no_unauthorised_status$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_set_status('00000000-0000-0000-0000-000000000001','registration');
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'CAPTAIN_PUBLISHED_DRAFT';end if;
end $no_unauthorised_status$;
reset role;
do $no_side_effects$
begin
 if (select status from public.team_skills_cups where id='00000000-0000-0000-0000-000000000001')<>'draft'
 or (select count(*) from public.team_skills_audit)<>0 then
 raise exception 'DENIED_PUBLICATION_MUTATED_ROWS';end if;
end $no_side_effects$;

-- Admin explicitly publishes, writes publication date, and audits once.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
select public.team_skills_set_status('00000000-0000-0000-0000-000000000001','registration');
reset role;
do $published$
begin
 if not exists(select 1 from public.team_skills_cups where
 id='00000000-0000-0000-0000-000000000001' and status='registration'
 and published_at is not null) then raise exception 'PUBLICATION_NOT_PERSISTED';end if;
 if (select count(*) from public.team_skills_audit where action='change_status'
 and details->>'old'='draft' and details->>'new'='registration')<>1
 then raise exception 'PUBLICATION_NOT_AUDITED_ONCE';end if;
end $published$;

-- Genuine canonical registration accepts five eligible players, not
-- a fake UI placeholder or server-side direct INSERT from the user.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009101',true);
select public.team_skills_register(
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000101',
 array(select user_id from public.team_members
 where team_id='00000000-0000-0000-0000-000000000101' order by user_id),
 '00000000-0000-0000-0000-000000001002',
 '00000000-0000-0000-0000-000000001003');
reset role;
do $registered$
begin
 if (select count(*) from public.team_skills_registrations
 where cup_id='00000000-0000-0000-0000-000000000001'
 and status='pending')<>1
 or (select count(*) from public.team_skills_roster
 where cup_id='00000000-0000-0000-0000-000000000001' and active)<>5
 or (select count(*) from public.team_skills_roster
 where cup_id='00000000-0000-0000-0000-000000000001'
 and position='goalkeeper')<>1
 or (select count(*) from public.team_skills_audit
 where action='register_team')<>1 then
 raise exception 'CAPTAIN_REAL_REGISTRATION_MISSING';end if;
end $registered$;

-- Admin closes enrollment by starting competition. All historical
-- registrations, roster and previous publication timestamp remain.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
select public.team_skills_set_status('00000000-0000-0000-0000-000000000001','live');
reset role;
do $closed$
declare date_before timestamptz;
begin
 if (select status from public.team_skills_cups
 where id='00000000-0000-0000-0000-000000000001')<>'live'
 or (select published_at from public.team_skills_cups
 where id='00000000-0000-0000-0000-000000000001') is null
 or (select count(*) from public.team_skills_audit
 where action='change_status' and details->>'old'='registration'
 and details->>'new'='live')<>1 then
 raise exception 'CLOSURE_NOT_APPLIED_OR_AUDITED';end if;
end $closed$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009102',true);
do $denied_post_close$
declare people uuid[];denied boolean:=false;
begin
 select array_agg(user_id order by user_id) into people
 from public.team_members where team_id='00000000-0000-0000-0000-000000000102';
 begin
  perform public.team_skills_register(
   '00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000102',
   people,people[1],people[2]);
 exception when others then
  if position('registration closed' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'LATE_REGISTRATION_AFTER_LIVE';end if;
end $denied_post_close$;
reset role;
do $closed_no_side_effect$
begin
 if (select count(*) from public.team_skills_registrations)<>1
 or (select count(*) from public.team_skills_roster)<>5
 or (select count(*) from public.team_skills_audit)<>3 then
 raise exception 'FAILED_LATE_SIGNUP_CHANGED_REGISTRATION_OR_AUDIT';end if;
end $closed_no_side_effect$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $invalid_transitions$
declare denied boolean:=false;reopen_denied boolean:=false;
begin
 begin perform public.team_skills_set_status(
 '00000000-0000-0000-0000-000000000001','registration');
 exception when others then
  if position('invalid status transition' in lower(sqlerrm))>0 then
   reopen_denied:=true;else raise;end if;
 end;
 begin perform public.team_skills_set_status(
 '00000000-0000-0000-0000-000000000002','live');
 exception when others then
  if position('invalid status transition' in lower(sqlerrm))>0 then
   denied:=true;else raise;end if;
 end;
 if not reopen_denied or not denied then
 raise exception 'UNSAFE_REOPEN_OR_DRAFT_TO_LIVE';end if;
end $invalid_transitions$;
reset role;
rollback;
