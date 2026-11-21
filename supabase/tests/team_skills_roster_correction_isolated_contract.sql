-- Disposable PostgreSQL test. Inject the exact source migration and check
-- captain-only, pre-approval edits, atomic active roster and auditable outcome.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;
 end if;
 if not exists(select 1 from pg_roles where rolname='anon') then
   create role anon;
 end if;
end $roles$;
create schema auth;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;

create table public.users(id uuid primary key,is_blocked boolean);
create table public.teams(id uuid primary key,captain_id uuid not null);
create table public.team_members(team_id uuid not null,user_id uuid not null);
create table public.team_skills_cups(
 id uuid primary key,status text not null,starts_at timestamptz not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 captain_id uuid not null,goalkeeper_id uuid not null,representative_id uuid not null,
 status text not null,hospitality_payment_status text not null default 'unpaid',
 checked_in_at timestamptz);
create table public.team_skills_roster(
 cup_id uuid not null,registration_id uuid not null,player_id uuid not null,
 position text not null,active boolean not null default true,
 primary key(registration_id,player_id));
create unique index team_skills_roster_one_active_player
 on public.team_skills_roster(cup_id,player_id) where active;
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);

-- TEAM_SKILLS_PENDING_ROSTER_CORRECTION_MIGRATION

insert into public.users(id,is_blocked)
select ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,false
from generate_series(1,10) i;
insert into public.teams(id,captain_id) values
('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000101');
insert into public.team_members(team_id,user_id)
select '00000000-0000-0000-0000-000000000011'::uuid,
 ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid
from generate_series(1,7) i;
insert into public.team_skills_cups(id,status,starts_at)
values('00000000-0000-0000-0000-000000000021','registration',
 now()+interval '3 days');
insert into public.team_skills_registrations(
 id,cup_id,team_id,captain_id,goalkeeper_id,representative_id,status)
values(
 '00000000-0000-0000-0000-000000000031',
 '00000000-0000-0000-0000-000000000021',
 '00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000101',
 '00000000-0000-0000-0000-000000000101',
 '00000000-0000-0000-0000-000000000102','pending');
insert into public.team_skills_roster(cup_id,registration_id,player_id,position)
select
 '00000000-0000-0000-0000-000000000021'::uuid,
 '00000000-0000-0000-0000-000000000031'::uuid,
 ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,
 case when i=1 then 'goalkeeper' else 'field' end
from generate_series(1,5) i;

do $test$
declare
 c uuid:='00000000-0000-0000-0000-000000000031';
 roster uuid[];
 denied boolean:=false;
 cur_count int;old_count int;
begin
 select array_agg(('00000000-0000-0000-0000-'||
   lpad((100+i)::text,12,'0'))::uuid order by i)
 into roster from generate_series(2,6) i;
 perform set_config('request.jwt.claim.sub',
   '00000000-0000-0000-0000-000000000102',true);
 begin
  perform public.team_skills_correct_roster(c,roster,roster[1],roster[2]);
 exception when others then
  if position('Current captain' in sqlerrm)>0 then denied:=true;
  else raise; end if;
 end;
 if not denied then raise exception 'NONCAPTAIN_CORRECTED_TEAM';end if;

 perform set_config('request.jwt.claim.sub',
   '00000000-0000-0000-0000-000000000101',true);
 perform public.team_skills_correct_roster(c,roster,roster[1],roster[2]);
 select count(*) filter(where active),count(*) filter(where not active)
 into cur_count,old_count from public.team_skills_roster
 where registration_id=c;
 if cur_count<>5 or old_count<>1 then
  raise exception 'ROSTER_EDIT_NOT_ATOMIC current % inactive %',cur_count,old_count;
 end if;
 if (select goalkeeper_id from public.team_skills_registrations
  where id=c)<>roster[1] or
    (select representative_id from public.team_skills_registrations
  where id=c)<>roster[2] then
  raise exception 'KEEPER_OR_REP_NOT_UPDATED';
 end if;

 denied:=false;
 begin perform public.team_skills_correct_roster(c,roster,roster[1],roster[2]);
 exception when others then
  if position('No roster change' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'IDENTICAL_CORRECTION_ACCEPTED';end if;

 update public.users set is_blocked=true
 where id='00000000-0000-0000-0000-000000000107';
 denied:=false;
 begin perform public.team_skills_correct_roster(c,
   array['00000000-0000-0000-0000-000000000107'::uuid,
         roster[2],roster[3],roster[4],roster[5]],roster[2],roster[3]);
 exception when others then
  if position('Blocked player' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'BLOCKED_PLAYER_ADMITTED';end if;

 denied:=false;
 begin perform public.team_skills_correct_roster(c,
   array['00000000-0000-0000-0000-000000000110'::uuid,
         roster[2],roster[3],roster[4],roster[5]],roster[2],roster[3]);
 exception when others then
  if position('current team member' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'OUTSIDER_ADMITTED';end if;

 update public.team_skills_registrations set status='approved' where id=c;
 denied:=false;
 begin perform public.team_skills_correct_roster(c,
   array['00000000-0000-0000-0000-000000000101'::uuid,
         roster[2],roster[3],roster[4],roster[5]],roster[2],roster[3]);
 exception when others then
  if position('Current captain' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'APPROVED_ROSTER_CHANGED';end if;
 if (select count(*) from public.team_skills_audit
 where action='correct_pending_roster')<>1 then
  raise exception 'AUDIT_RECORD_COUNT_INVALID';end if;
end $test$;
