-- Minimal disposable Postgres fixture. No production tables or credentials.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;
 end if;
 if not exists(select 1 from pg_roles where rolname='anon') then
   create role anon;
 end if;
end $roles$;

create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean
language sql stable set search_path='' as $$ select false $$;
grant usage on schema auth,vsp_skills_private to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function vsp_skills_private.is_admin() to authenticated;

create table public.team_members(team_id uuid not null,user_id uuid not null);
create table public.team_skills_cups(id uuid primary key,status text not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 captain_id uuid not null,status text not null);
create table public.team_skills_officials(
 cup_id uuid not null,user_id uuid not null,role text not null);
create table public.team_skills_scores(
 id uuid primary key,cup_id uuid not null,registration_id uuid not null,status text not null);
create table public.team_skills_goalkeeper_trials(
 id uuid primary key,cup_id uuid not null,goalkeeper_id uuid not null);

alter table public.team_skills_registrations enable row level security;
alter table public.team_skills_scores enable row level security;
alter table public.team_skills_goalkeeper_trials enable row level security;
grant select on public.team_members,public.team_skills_cups,
 public.team_skills_registrations,public.team_skills_officials,
 public.team_skills_scores,public.team_skills_goalkeeper_trials to authenticated;

-- THE FIXED RLS MIGRATION IS INJECTED HERE
-- TEAM_SKILLS_RLS_MIGRATION

insert into public.team_skills_cups(id,status) values
 ('00000000-0000-0000-0000-000000000011','registration'),
 ('00000000-0000-0000-0000-000000000022','registration');
insert into public.team_members(team_id,user_id) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000009001');
insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status) values
 ('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000009002','pending'),
 ('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000022',
  '00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000009003','pending');
insert into public.team_skills_officials(cup_id,user_id,role) values
 ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000009001','judge');
insert into public.team_skills_scores(id,cup_id,registration_id,status) values
 ('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000111','pending'),
 ('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000022',
  '00000000-0000-0000-0000-000000000222','pending');
insert into public.team_skills_goalkeeper_trials(id,cup_id,goalkeeper_id) values
 ('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000009004'),
 ('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000022',
 '00000000-0000-0000-0000-000000009005');

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $test$
declare registrations integer; scores integer; keepers integer;
begin
 select count(*) into registrations from public.team_skills_registrations;
 select count(*) into scores from public.team_skills_scores;
 select count(*) into keepers from public.team_skills_goalkeeper_trials;
 if registrations<>1 or scores<>1 or keepers<>1 then
   raise exception 'CROSS_CUP_READ_LEAK: registration %, score %, keeper %',
     registrations,scores,keepers;
 end if;
end $test$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009099',true);
do $outsider$
begin
 if exists(select 1 from public.team_skills_registrations)
 or exists(select 1 from public.team_skills_scores)
 or exists(select 1 from public.team_skills_goalkeeper_trials) then
  raise exception 'OUTSIDER_CAN_READ_PRIVATE_CUP_DATA';
 end if;
end $outsider$;
rollback;
