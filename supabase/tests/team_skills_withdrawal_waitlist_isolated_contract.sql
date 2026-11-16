-- Local PostgreSQL test of actual admin review and captain withdrawal RPCs.
-- No hosted database, player account, payment or notification writes.
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
create function vsp_skills_private.is_admin() returns boolean language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;

create table public.users(id uuid primary key,is_blocked boolean default false);
create table public.teams(id uuid primary key,captain_id uuid not null);
create table public.team_skills_cups(
 id uuid primary key,status text not null,starts_at timestamptz not null,
 max_teams integer not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 captain_id uuid not null,status text not null,
 hospitality_payment_status text not null default 'unpaid',
 checked_in_at timestamptz,rejection_reason text,
 reviewed_by uuid,reviewed_at timestamptz);
create table public.team_skills_roster(
 cup_id uuid not null,registration_id uuid not null,
 player_id uuid not null,active boolean not null default true);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
create table public.notifications(
 user_id uuid,title text,body text,message text,type text,metadata jsonb);
-- REAL_TEAM_WITHDRAWAL_AND_REVIEW_FUNCTIONS

insert into public.users(id,is_blocked) values
 ('00000000-0000-0000-0000-000000009001',false),
 ('00000000-0000-0000-0000-000000009999',false);
insert into public.users(id,is_blocked)
select ('00000000-0000-0000-0000-'||lpad((9300+i)::text,12,'0'))::uuid,false
from generate_series(1,8) i;
insert into public.teams(id,captain_id)
select ('00000000-0000-0000-0000-'||lpad((200+i)::text,12,'0'))::uuid,
 ('00000000-0000-0000-0000-'||lpad((9300+i)::text,12,'0'))::uuid
from generate_series(1,8) i;
insert into public.team_skills_cups(id,status,starts_at,max_teams) values
 ('00000000-0000-0000-0000-000000000001','registration',now()+interval '2 days',4);
insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status)
select ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000001'::uuid,
 ('00000000-0000-0000-0000-'||lpad((200+i)::text,12,'0'))::uuid,
 ('00000000-0000-0000-0000-'||lpad((9300+i)::text,12,'0'))::uuid,
 case when i<=4 then 'pending' else 'waitlist' end
from generate_series(1,8) i;
insert into public.team_skills_roster(cup_id,registration_id,player_id)
select '00000000-0000-0000-0000-000000000001'::uuid,
 ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,
 ('00000000-0000-0000-0000-'||lpad((20000+i*100+j)::text,12,'0'))::uuid
from generate_series(1,8) i cross join generate_series(1,5) j;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);

do $full_list$
declare denied boolean:=false;
begin
 begin perform public.team_skills_review_registration(
   '00000000-0000-0000-0000-000000000102','waitlist',null);
 exception when others then
  if position('waitlist capacity reached' in sqlerrm)>0 then denied:=true;
  else raise;end if;end;
 if not denied then raise exception 'ADMIN_OVERFILLED_WAITLIST';end if;
end $full_list$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009999',false);
do $outsider$
declare denied boolean:=false;
begin
 begin perform public.team_skills_withdraw_registration(
   '00000000-0000-0000-0000-000000000101');
 exception when others then
  if position('Current captain can only withdraw' in sqlerrm)>0 then
   denied:=true;else raise;end if;end;
 if not denied then raise exception 'NONCAPTAIN_WITHDREW_TEAM';end if;
end $outsider$;

-- Captain of team 8 withdraws a waitlist application.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009308',false);
select public.team_skills_withdraw_registration(
 '00000000-0000-0000-0000-000000000108');
do $released$
begin
 if exists(select 1 from public.team_skills_roster
  where registration_id='00000000-0000-0000-0000-000000000108' and active) then
  raise exception 'WITHDRAWN_ROSTER_STILL_RESERVED';end if;
end $released$;

-- The freed waitlist slot permits a pending -> waitlist review.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
select public.team_skills_review_registration(
 '00000000-0000-0000-0000-000000000102','waitlist',null);
do $no_op$
declare blocked boolean:=false;
begin
 begin
  perform public.team_skills_review_registration(
   '00000000-0000-0000-0000-000000000102','waitlist',null);
 exception when others then
  if position('already in requested state' in sqlerrm)>0 then blocked:=true;
  else raise;end if;end;
 if not blocked then raise exception 'DUPLICATE_REVIEW_WROTE_AUDIT';end if;
end $no_op$;

-- Captain withdraws pending place; admin can promote waiting registration.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009301',false);
select public.team_skills_withdraw_registration(
 '00000000-0000-0000-0000-000000000101');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
select public.team_skills_review_registration(
 '00000000-0000-0000-0000-000000000105','approved',null);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009305',false);
do $captain_approved$
declare denied boolean:=false;
begin
 begin perform public.team_skills_withdraw_registration(
   '00000000-0000-0000-0000-000000000105');
 exception when others then
  if position('Current captain can only withdraw' in sqlerrm)>0 then denied:=true;
  else raise;end if;end;
 if not denied then raise exception 'CAPTAIN_CANCELLED_APPROVED_TEAM';end if;
end $captain_approved$;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
do $admin_reason$
declare denied boolean:=false;
begin
 begin perform public.team_skills_withdraw_registration(
  '00000000-0000-0000-0000-000000000105','short');
 exception when others then
  if position('Documented admin withdrawal reason' in sqlerrm)>0 then denied:=true;
  else raise;end if;end;
 if not denied then raise exception 'ADMIN_CANCELLED_WITHOUT_REASON';end if;
end $admin_reason$;
update public.team_skills_registrations set hospitality_payment_status='verified'
where id='00000000-0000-0000-0000-000000000105';
do $paid$
declare denied boolean:=false;
begin
 begin perform public.team_skills_withdraw_registration(
   '00000000-0000-0000-0000-000000000105',
   'Documented event team withdrawal');
 exception when others then
  if position('Hospitality settlement requires manual admin review' in sqlerrm)>0 then denied:=true;
  else raise;end if;end;
 if not denied then raise exception 'PAID_TEAM_WITHDRAWN_WITHOUT_SETTLEMENT';end if;
end $paid$;
update public.team_skills_registrations set hospitality_payment_status='unpaid'
where id='00000000-0000-0000-0000-000000000105';
select public.team_skills_withdraw_registration(
 '00000000-0000-0000-0000-000000000105',
 'Admin documented before-event cancellation');

do $audit$
begin
 if (select count(*) from public.team_skills_audit
    where action='withdraw_registration')<>3 then
  raise exception 'MISSING_THREE_WITHDRAWAL_AUDITS';end if;
 if (select count(*) from public.notifications
   where metadata->>'event'='registration_withdrawn'
     and user_id='00000000-0000-0000-0000-000000009305')<>1 then
  raise exception 'ADMIN_WITHDRAWAL_NOTIFICATION_NOT_TO_CAPTAIN';end if;
 if (select count(*) from public.team_skills_registrations
    where status='withdrawn')<>3 then
  raise exception 'WRONG_NUMBER_OF_WITHDRAWN_REGISTRATIONS';end if;
 if exists(select 1 from public.team_skills_roster a
  join public.team_skills_registrations b on b.id=a.registration_id
  where b.status='withdrawn' and a.active) then
  raise exception 'WITHDRAWN_ROSTER_STILL_BLOCKS_PLAYERS';end if;
 if (select count(*) from public.team_skills_registrations
  where status in ('pending','approved'))>4
 or (select count(*) from public.team_skills_registrations
  where status='waitlist')>4 then
  raise exception 'TEAM_WAITLIST_CAPACITY_VIOLATED';end if;
end $audit$;
