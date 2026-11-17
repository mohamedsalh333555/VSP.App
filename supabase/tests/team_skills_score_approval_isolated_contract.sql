-- Disposable local PostgreSQL: enforce admin-only approval of one pending
-- skills score, audit exactly once, and reject repeated/unknown approvals.
-- Actual current approval RPC is injected from the checked-in migration.
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
language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
create table public.team_skills_registrations (
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 status text not null
);
create table public.team_skills_scores (
 id uuid primary key, cup_id uuid not null, registration_id uuid not null,
 status text not null, computed_points numeric not null,
 approved_by uuid, approved_at timestamptz
);
create table public.team_skills_audit (
 cup_id uuid not null, actor_id uuid not null, action text not null,
 subject_id uuid not null, details jsonb not null
);
-- ACTUAL_TEAM_SKILLS_LEADERBOARD_VIEW_HERE
-- ACTUAL_TEAM_SKILLS_APPROVE_SCORE_FUNCTION_HERE
insert into public.team_skills_registrations(id,cup_id,team_id,status) values
('00000000-0000-0000-0000-000000000201',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000301','approved'),
('00000000-0000-0000-0000-000000000202',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000302','approved');
insert into public.team_skills_scores(
 id,cup_id,registration_id,status,computed_points) values
('00000000-0000-0000-0000-000000000111',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000201','pending',8.75),
('00000000-0000-0000-0000-000000000112',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000202','pending',10);
do $pending_not_ranked$
begin
 if (select count(*) from public.team_skills_leaderboard
     where cup_id='00000000-0000-0000-0000-000000000001'
      and points=0 and completed_stages=0)<>2
 then raise exception 'UNAPPROVED_SCORE_LEAKED_INTO_RANKING';end if;
end $pending_not_ranked$;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009009',true);
do $unauthorized$
declare denied boolean:=false;
begin
 begin
   perform public.team_skills_approve_score(
     '00000000-0000-0000-0000-000000000111');
 exception when others then
   if position('not authorized' in lower(sqlerrm))>0 then
     denied:=true;
   else raise;end if;
 end;
 if not denied then raise exception 'NONADMIN_APPROVED_PENDING_SCORE';end if;
end $unauthorized$;
reset role;
do $verify_denial$
begin
 if exists(select 1 from public.team_skills_audit) or
    exists(select 1 from public.team_skills_scores
      where status='approved')
 then raise exception 'DENIED_APPROVAL_CHANGED_SCORE_OR_AUDIT';end if;
end $verify_denial$;

set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009001',true);
select public.team_skills_approve_score(
 '00000000-0000-0000-0000-000000000111');
reset role;
do $verified$
begin
 if not exists(select 1 from public.team_skills_scores
   where id='00000000-0000-0000-0000-000000000111'
     and status='approved'
     and approved_by='00000000-0000-0000-0000-000000009001'
     and approved_at is not null
     and computed_points=8.75)
 then raise exception 'ADMIN_SCORE_APPROVAL_MISSING';end if;
 if (select count(*) from public.team_skills_audit
    where action='approve_score'
      and subject_id='00000000-0000-0000-0000-000000000111'
      and actor_id='00000000-0000-0000-0000-000000009001'
      and details->>'points'='8.75')<>1
 then raise exception 'APPROVAL_AUDIT_NOT_EXACTLY_ONCE';end if;
 if (select status from public.team_skills_scores
     where id='00000000-0000-0000-0000-000000000112')<>'pending'
 then raise exception 'APPROVAL_TOUCHED_WRONG_SCORE';end if;
 if not exists(
   select 1 from public.team_skills_leaderboard
   where registration_id='00000000-0000-0000-0000-000000000201'
     and points=8.75 and completed_stages=1 and all_stages_approved=false)
 or not exists(
   select 1 from public.team_skills_leaderboard
   where registration_id='00000000-0000-0000-0000-000000000202'
     and points=0 and completed_stages=0)
 then raise exception 'APPROVAL_NOT_REFLECTED_IN_SCOPED_STANDINGS';end if;
end $verified$;

set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009001',true);
do $repeat_guard$
declare repeated_denied boolean:=false;unknown_denied boolean:=false;
begin
 begin
   perform public.team_skills_approve_score(
     '00000000-0000-0000-0000-000000000111');
 exception when others then
   if position('not pending' in lower(sqlerrm))>0 then
     repeated_denied:=true;
   else raise;end if;
 end;
 begin
   perform public.team_skills_approve_score(
     '00000000-0000-0000-0000-000000000999');
 exception when others then
   if position('not pending' in lower(sqlerrm))>0 then
     unknown_denied:=true;
   else raise;end if;
 end;
 if not repeated_denied or not unknown_denied then
   raise exception 'DUPLICATE_OR_UNKNOWN_APPROVAL_ACCEPTED';end if;
end $repeat_guard$;
reset role;
do $final_audit$
begin
 if (select count(*) from public.team_skills_audit)<>1 or
    (select count(*) from public.team_skills_scores
      where status='approved')<>1
 then raise exception 'DUPLICATE_APPROVAL_CREATED_SIDE_EFFECT';end if;
 if (select points from public.team_skills_leaderboard where
    registration_id='00000000-0000-0000-0000-000000000201')<>8.75
 then raise exception 'DUPLICATE_APPROVAL_CHANGED_STANDINGS';end if;
end $final_audit$;
rollback;
