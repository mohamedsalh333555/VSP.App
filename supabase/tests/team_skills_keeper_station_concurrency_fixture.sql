-- Disposable four-team goalkeeper-station fixture for two-session SQL race.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
grant usage on schema auth,vsp_skills_private to authenticated;
grant execute on function auth.uid(),vsp_skills_private.is_admin() to authenticated;

create table public.team_skills_cups(
 id uuid primary key,status text not null,
 starts_at timestamptz not null,ends_at timestamptz not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 goalkeeper_id uuid not null,status text not null);
create table public.team_skills_goalkeeper_trials(
 id uuid primary key default gen_random_uuid(),cup_id uuid not null,
 goalkeeper_id uuid not null,opponent_team_id uuid not null,
 registration_id uuid not null,starts_at timestamptz not null,
 ends_at timestamptz not null,status text default 'scheduled');
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);

-- TEAM_SKILLS_KEEPER_TEAM_MIGRATION

insert into public.team_skills_cups(id,status,starts_at,ends_at) values(
 '00000000-0000-0000-0000-000000000001','live',
 now()+interval '2 days',now()+interval '2 days 3 hours');
insert into public.team_skills_registrations(id,cup_id,team_id,goalkeeper_id,status) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000301','approved'),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000302','approved'),
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000303','approved'),
 ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000304','approved');

-- Keep the winning transaction open while its opponent reaches the team lock.
create function public.fixture_delay_keeper_station() returns trigger
language plpgsql as $slow$
begin perform pg_sleep(0.35); return new;end $slow$;
create trigger fixture_delay_keeper_station
before insert on public.team_skills_goalkeeper_trials
for each row execute function public.fixture_delay_keeper_station();
