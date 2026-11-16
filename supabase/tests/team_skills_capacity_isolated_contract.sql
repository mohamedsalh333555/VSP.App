-- Disposable SQL contract: waitlist cannot exceed four approved teams.
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
grant usage on schema auth,vsp_skills_private to authenticated;
grant execute on function auth.uid(),vsp_skills_private.is_admin() to authenticated;
create table public.team_skills_cups(
 id uuid primary key,status text not null,starts_at timestamptz not null,max_teams integer not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,status text not null,
 rejection_reason text,reviewed_by uuid,reviewed_at timestamptz);
create table public.team_skills_roster(registration_id uuid not null,active boolean);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
grant select on public.team_skills_registrations to authenticated;
-- CAPACITY_MIGRATION_HERE

insert into public.team_skills_cups(id,status,starts_at,max_teams)
values('00000000-0000-0000-0000-000000000001','registration',now()+interval '2 days',4);
insert into public.team_skills_registrations(id,cup_id,status) values
 ('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000001','approved'),
 ('00000000-0000-0000-0000-000000000112','00000000-0000-0000-0000-000000000001','approved'),
 ('00000000-0000-0000-0000-000000000113','00000000-0000-0000-0000-000000000001','approved'),
 ('00000000-0000-0000-0000-000000000114','00000000-0000-0000-0000-000000000001','approved'),
 ('00000000-0000-0000-0000-000000000115','00000000-0000-0000-0000-000000000001','waitlist');

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $must_reject$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_review_registration(
    '00000000-0000-0000-0000-000000000115','approved',null);
 exception when others then
  if position('capacity' in lower(sqlerrm)) > 0 then denied:=true;
  else raise; end if;
 end;
 if not denied then raise exception 'WAITLIST_EXCEEDED_CUP_CAPACITY'; end if;
 if (select status from public.team_skills_registrations
     where id='00000000-0000-0000-0000-000000000115') <> 'waitlist'
 then raise exception 'Failed review changed status'; end if;
end $must_reject$;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009009',true);
do $outsider$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_review_registration(
    '00000000-0000-0000-0000-000000000115','rejected','Not eligible');
 exception when others then
  if position('not authorized' in lower(sqlerrm)) > 0 then denied:=true;
  else raise; end if;
 end;
 if not denied then raise exception 'NON_ADMIN_REVIEWED_REGISTRATION'; end if;
end $outsider$;
reset role;
update public.team_skills_registrations set status='withdrawn'
where id='00000000-0000-0000-0000-000000000111';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
select public.team_skills_review_registration(
  '00000000-0000-0000-0000-000000000115','approved',null);
do $after_slot$
begin
 if (select count(*) from public.team_skills_registrations
    where status='approved') <> 4 then
    raise exception 'VALID_WAITLIST_PROMOTION_DID_NOT_RESTORE_FOUR_TEAM_LIMIT';
 end if;
end $after_slot$;
rollback;
