-- Disposable local PostgreSQL test of the real captain registration RPC.
create schema auth;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table public.users(id uuid primary key,is_blocked boolean not null default false);
create table public.teams(id uuid primary key,captain_id uuid not null);
create table public.team_members(team_id uuid not null,user_id uuid not null);
create table public.team_skills_cups(
 id uuid primary key,status text not null,starts_at timestamptz not null,max_teams int not null);
create table public.team_skills_registrations(
 id uuid primary key default gen_random_uuid(),cup_id uuid not null,
 team_id uuid not null,captain_id uuid not null,
 goalkeeper_id uuid not null,representative_id uuid not null,
 status text not null default 'pending',
 unique(cup_id,team_id));
create table public.team_skills_roster(
 cup_id uuid not null,registration_id uuid not null,
 player_id uuid not null,position text not null,active boolean not null default true);
create unique index team_skills_active_player_unique
 on public.team_skills_roster(cup_id,player_id) where active;
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
-- AUTO_WAITLIST_REGISTRATION_FUNCTION

insert into public.team_skills_cups(id,status,starts_at,max_teams)
values('00000000-0000-0000-0000-000000000001','registration',
 now()+interval '3 days',4);
-- Separate captain and five roster members per team, unique across cup.
insert into public.teams(id,captain_id)
select ('00000000-0000-0000-0000-'||lpad((200+i)::text,12,'0'))::uuid,
       ('00000000-0000-0000-0000-'||lpad((900+i)::text,12,'0'))::uuid
from generate_series(1,10) i;
insert into public.team_members(team_id,user_id)
select ('00000000-0000-0000-0000-'||lpad((200+i)::text,12,'0'))::uuid,
       ('00000000-0000-0000-0000-'||lpad((5000+i*100+j)::text,12,'0'))::uuid
from generate_series(1,10) i cross join generate_series(1,5) j;
insert into public.users(id)
select distinct id from (
 select captain_id as id from public.teams
 union
 select user_id as id from public.team_members
) identities;

do $applications$
declare n integer;t uuid;capt uuid;people uuid[];receipt uuid;
v_status text; waitlist_full boolean:=false;
begin
 for n in 1..9 loop
   t:=('00000000-0000-0000-0000-'||lpad((200+n)::text,12,'0'))::uuid;
   capt:=('00000000-0000-0000-0000-'||lpad((900+n)::text,12,'0'))::uuid;
   select array_agg(m.user_id order by m.user_id) into people
   from public.team_members m where m.team_id=t;
   perform set_config('request.jwt.claim.sub',capt::text,true);
   if n=9 then
     begin
       perform public.team_skills_register(
         '00000000-0000-0000-0000-000000000001',t,people,people[1],people[2]);
     exception when others then
       if position('waitlist are full' in lower(sqlerrm))>0 then waitlist_full:=true;
       else raise;end if;
     end;
   else
     receipt:=public.team_skills_register(
       '00000000-0000-0000-0000-000000000001',t,people,people[1],people[2]);
     select r.status into v_status from public.team_skills_registrations r where r.id=receipt;
     if (n<=4 and v_status<>'pending') or (n>4 and v_status<>'waitlist') then
       raise exception 'Wrong registration status for captain %: %',n,v_status;
     end if;
   end if;
 end loop;
 if not waitlist_full then raise exception 'UNBOUNDED_WAITLIST';end if;
end $applications$;

do $guarantees$
declare denied_captain boolean:=false;denied_repeat boolean:=false;
v_team_id uuid:='00000000-0000-0000-0000-000000000201';
players uuid[];
begin
 select array_agg(m.user_id order by m.user_id) into players
 from public.team_members m where m.team_id=v_team_id;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000999',true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',v_team_id,players,players[1],players[2]);
 exception when others then
   if position('Captain only' in sqlerrm)>0 then denied_captain:=true;else raise;end if;
 end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000901',true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',v_team_id,players,players[1],players[2]);
 exception when others then
   if position('already registered' in lower(sqlerrm))>0 then denied_repeat:=true;else raise;end if;
 end;
 if not denied_captain or not denied_repeat then raise exception 'REGISTRATION_AUTH_FAILED';end if;
 if (select count(*) from public.team_skills_registrations where status='pending')<>4
 or (select count(*) from public.team_skills_registrations where status='waitlist')<>4
 or (select count(*) from public.team_skills_roster where active)<>40
 or (select count(*) from public.team_skills_audit where action='register_team')<>8
 then raise exception 'WAITLIST_COUNTS_OR_AUDIT_INVALID';end if;
end $guarantees$;

-- The first eight captains are valid; use a tenth separate team to
-- prove suspended captain / roster denials occur before full waitlist.
do $blocked_enrollment$
declare team10 uuid:='00000000-0000-0000-0000-000000000210';
cap10 uuid:='00000000-0000-0000-0000-000000000910';
people uuid[];denied_cap boolean:=false;denied_player boolean:=false;
begin
 select array_agg(m.user_id order by m.user_id) into people
 from public.team_members m where m.team_id=team10;
 update public.users set is_blocked=true where id=cap10;
 perform set_config('request.jwt.claim.sub',cap10::text,true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',team10,people,people[1],people[2]);
 exception when others then
   if position('Blocked captain' in sqlerrm)>0 then denied_cap:=true;
   else raise;end if;
 end;
 update public.users set is_blocked=false where id=cap10;
 update public.users set is_blocked=true where id=people[1];
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',team10,people,people[1],people[2]);
 exception when others then
   if position('Blocked player' in sqlerrm)>0 then denied_player:=true;
   else raise;end if;
 end;
 if not denied_cap or not denied_player then
   raise exception 'BLOCKED_CAPTAIN_OR_ROSTER_ACCEPTED';
 end if;
 if exists(select 1 from public.team_skills_registrations
           where team_id=team10)
 then raise exception 'BLOCKED_TEAM_WROTE_REGISTRATION';end if;
end $blocked_enrollment$;


-- Enrollment closes at kickoff and while the cup is not in registration.
-- Even a fully booked waiting list must not mask the definitive close guard.
-- All attempts are rejected before any registration, roster or audit write.
update public.users set is_blocked=false
where id='00000000-0000-0000-0000-000000000910'
   or id in (select user_id from public.team_members
      where team_id='00000000-0000-0000-0000-000000000210');
update public.team_skills_cups set starts_at=now()-interval '1 minute'
where id='00000000-0000-0000-0000-000000000001';

do $registration_closure$
declare team10 uuid:='00000000-0000-0000-0000-000000000210';
 capt10 uuid:='00000000-0000-0000-0000-000000000910';
 people uuid[]; denied boolean:=false;
begin
 select array_agg(user_id order by user_id) into people
 from public.team_members where team_id=team10;
 perform set_config('request.jwt.claim.sub',capt10::text,true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',
     team10,people,people[1],people[2]);
 exception when others then
   if position('registration closed' in lower(sqlerrm))>0 then
     denied:=true;
   else raise;end if;
 end;
 if not denied then raise exception 'PAST_KICKOFF_ENROLLMENT_ACCEPTED';end if;
end $registration_closure$;

update public.team_skills_cups set status='draft',starts_at=now()+interval '3 days'
where id='00000000-0000-0000-0000-000000000001';
do $draft_closure$
declare team10 uuid:='00000000-0000-0000-0000-000000000210';
 capt10 uuid:='00000000-0000-0000-0000-000000000910';
 people uuid[]; denied boolean:=false;
begin
 select array_agg(user_id order by user_id) into people
 from public.team_members where team_id=team10;
 perform set_config('request.jwt.claim.sub',capt10::text,true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',
     team10,people,people[1],people[2]);
 exception when others then
   if position('registration closed' in lower(sqlerrm))>0 then
     denied:=true;
   else raise;end if;
 end;
 if not denied then raise exception 'DRAFT_ENROLLMENT_ACCEPTED';end if;
 if (select count(*) from public.team_skills_registrations)<>8
 or (select count(*) from public.team_skills_roster where active)<>40
 or (select count(*) from public.team_skills_audit
     where action='register_team')<>8
 then raise exception 'CLOSED_REGISTRATION_MUTATED_AUDITED_DATA';end if;
end $draft_closure$;
