-- Local-only RLS contract for the actual blocked-official read migration.
-- No network access, production credentials, or hosted-project data.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean language sql stable set search_path=''
as $$ select false $$;
grant usage on schema auth,vsp_skills_private to authenticated;
grant execute on function auth.uid(),vsp_skills_private.is_admin() to authenticated;

create table public.users(id uuid primary key,is_blocked boolean);
create table public.team_skills_cups(id uuid primary key,status text not null);
create table public.team_skills_officials(cup_id uuid not null,user_id uuid not null,role text not null);
create table public.team_skills_scores(id uuid primary key,cup_id uuid not null,status text not null);
create table public.team_skills_goalkeeper_trials(id uuid primary key,cup_id uuid not null);
alter table public.users enable row level security;
alter table public.team_skills_officials enable row level security;
alter table public.team_skills_scores enable row level security;
alter table public.team_skills_goalkeeper_trials enable row level security;
create policy users_select_policy on public.users for select to authenticated
using (id=(select auth.uid()));
grant select on public.users,public.team_skills_cups,public.team_skills_officials,
public.team_skills_scores,public.team_skills_goalkeeper_trials to authenticated;
-- CURRENT_BLOCKED_OFFICIAL_READ_MIGRATION

insert into public.users(id,is_blocked) values
('00000000-0000-0000-0000-000000009001',false),
('00000000-0000-0000-0000-000000009002',false),
('00000000-0000-0000-0000-000000009003',true);
insert into public.team_skills_cups(id,status) values
('00000000-0000-0000-0000-000000000011','live'),
('00000000-0000-0000-0000-000000000022','live');
insert into public.team_skills_officials(cup_id,user_id,role) values
('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000009001','judge'),
('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000009003','judge');
insert into public.team_skills_scores(id,cup_id,status) values
('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000011','pending'),
('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000022','pending'),
('00000000-0000-0000-0000-000000000333','00000000-0000-0000-0000-000000000022','approved');
insert into public.team_skills_goalkeeper_trials(id,cup_id) values
('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000011'),
('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000022');

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $active$
declare a integer;b integer;c integer;d integer;
begin
 select count(*) into a from public.team_skills_officials;
 select count(*) into b from public.team_skills_scores where status='pending';
 select count(*) into c from public.team_skills_goalkeeper_trials;
 select count(*) into d from public.team_skills_scores where status='approved';
 if a<>1 or b<>1 or c<>1 or d<>1 then
 raise exception 'ACTIVE_JUDGE_RLS_MISMATCH: assignment %, pending %, trial %, public %',a,b,c,d;
 end if;
end $active$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009002',true);
do $outsider$
begin
 if exists(select 1 from public.team_skills_officials)
 or exists(select 1 from public.team_skills_scores where status='pending')
 or exists(select 1 from public.team_skills_goalkeeper_trials)
 then raise exception 'OUTSIDER_PRIVATE_DATA_LEAK';end if;
 if (select count(*) from public.team_skills_scores where status='approved')<>1 then
 raise exception 'PUBLIC_APPROVED_SCORE_NOT_VISIBLE_TO_OUTSIDER';end if;
end $outsider$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009003',true);
do $blocked$
begin
 if exists(select 1 from public.team_skills_officials)
 or exists(select 1 from public.team_skills_scores where status='pending')
 or exists(select 1 from public.team_skills_goalkeeper_trials)
 then raise exception 'BLOCKED_JUDGE_PRIVATE_DATA_LEAK';end if;
 if (select count(*) from public.team_skills_scores where status='approved')<>1 then
 raise exception 'BLOCKED_ACTOR_LOST_PUBLIC_APPROVED_SCORES';end if;
end $blocked$;
rollback;
