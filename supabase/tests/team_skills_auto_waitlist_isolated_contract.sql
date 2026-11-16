-- Disposable local PostgreSQL test of the real captain registration RPC.
create schema auth;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
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
from generate_series(1,9) i;
insert into public.team_members(team_id,user_id)
select ('00000000-0000-0000-0000-'||lpad((200+i)::text,12,'0'))::uuid,
       ('00000000-0000-0000-0000-'||lpad((5000+i*100+j)::text,12,'0'))::uuid
from generate_series(1,9) i cross join generate_series(1,5) j;

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
team_id uuid:='00000000-0000-0000-0000-000000000201';
players uuid[];
begin
 select array_agg(m.user_id order by m.user_id) into players
 from public.team_members m where m.team_id=team_id;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000999',true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',team_id,players,players[1],players[2]);
 exception when others then
   if position('Captain only' in sqlerrm)>0 then denied_captain:=true;else raise;end if;
 end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000901',true);
 begin
   perform public.team_skills_register(
     '00000000-0000-0000-0000-000000000001',team_id,players,players[1],players[2]);
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
