-- Disposable SQL contract: actual roster-approval trigger, independent
-- of any hosted user data. Simulates a waiting application's changed roster.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
end $roles$;
create schema vsp_skills_private;
create table public.users(id uuid primary key,is_blocked boolean default false);
create table public.teams(id uuid primary key,captain_id uuid not null);
create table public.team_members(team_id uuid not null,user_id uuid not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 captain_id uuid not null,goalkeeper_id uuid not null,
 representative_id uuid not null,status text not null);
create table public.team_skills_roster(
 registration_id uuid not null,cup_id uuid not null,player_id uuid not null,
 active boolean not null default true,position text not null);
-- ACTUAL_TEAM_SKILLS_APPROVAL_ROSTER_GUARD

insert into public.users(id,is_blocked) values
 ('00000000-0000-0000-0000-000000009001',false),
 ('00000000-0000-0000-0000-000000009002',false),
 ('00000000-0000-0000-0000-000000009003',false),
 ('00000000-0000-0000-0000-000000009004',false),
 ('00000000-0000-0000-0000-000000009005',false),
 ('00000000-0000-0000-0000-000000009006',false);
insert into public.teams(id,captain_id) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000009001');
insert into public.team_members(team_id,user_id)
select '00000000-0000-0000-0000-000000000101',
 ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid
from generate_series(9001,9005) i;
insert into public.team_skills_registrations(
 id,cup_id,team_id,captain_id,goalkeeper_id,representative_id,status)
values('00000000-0000-0000-0000-000000000201',
       '00000000-0000-0000-0000-000000000301',
       '00000000-0000-0000-0000-000000000101',
       '00000000-0000-0000-0000-000000009001',
       '00000000-0000-0000-0000-000000009001',
       '00000000-0000-0000-0000-000000009002','pending');
insert into public.team_skills_roster(registration_id,cup_id,player_id,active,position)
select '00000000-0000-0000-0000-000000000201',
       '00000000-0000-0000-0000-000000000301',
       ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
       true,case when i=9001 then 'goalkeeper' else 'field' end
from generate_series(9001,9005) i;

-- Every failed update is caught and rolled back to the previous row
-- without elevating a single Team Skills registration to approved.
update public.users set is_blocked=true where id='00000000-0000-0000-0000-000000009001';
do $blocked_captain$
declare denied boolean:=false;
begin
 begin update public.team_skills_registrations set status='approved'
  where id='00000000-0000-0000-0000-000000000201';
 exception when others then
  if position('Captain changed or is blocked' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'SUSPENDED_CAPTAIN_APPROVED';end if;
end $blocked_captain$;
update public.users set is_blocked=false where id='00000000-0000-0000-0000-000000009001';

update public.users set is_blocked=true where id='00000000-0000-0000-0000-000000009003';
do $blocked_player$
declare denied boolean:=false;
begin
 begin update public.team_skills_registrations set status='approved'
  where id='00000000-0000-0000-0000-000000000201';
 exception when others then
  if position('Blocked player cannot be approved' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'SUSPENDED_PLAYER_APPROVED';end if;
end $blocked_player$;
update public.users set is_blocked=false where id='00000000-0000-0000-0000-000000009003';

delete from public.team_members
where user_id='00000000-0000-0000-0000-000000009004';
do $departed$
declare denied boolean:=false;
begin
 begin update public.team_skills_registrations set status='approved'
  where id='00000000-0000-0000-0000-000000000201';
 exception when others then
  if position('still belong to the team' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'DEPARTED_PLAYER_APPROVED';end if;
end $departed$;
insert into public.team_members(team_id,user_id) values(
 '00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000009004');

update public.team_skills_roster set active=false
where player_id='00000000-0000-0000-0000-000000009005';
do $four_players$
declare denied boolean:=false;
begin
 begin update public.team_skills_registrations set status='approved'
  where id='00000000-0000-0000-0000-000000000201';
 exception when others then
  if position('exactly five active players' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'INCOMPLETE_ROSTER_APPROVED';end if;
end $four_players$;
update public.team_skills_roster set active=true
where player_id='00000000-0000-0000-0000-000000009005';

update public.team_skills_roster set position='field'
where player_id='00000000-0000-0000-0000-000000009001';
do $no_keeper$
declare denied boolean:=false;
begin
 begin update public.team_skills_registrations set status='approved'
  where id='00000000-0000-0000-0000-000000000201';
 exception when others then
  if position('one goalkeeper' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'GOALKEEPER_MISSING_BUT_APPROVED';end if;
end $no_keeper$;
update public.team_skills_roster set position='goalkeeper'
where player_id='00000000-0000-0000-0000-000000009001';

update public.teams set captain_id='00000000-0000-0000-0000-000000009006';
do $captain_changed$
declare denied boolean:=false;
begin
 begin update public.team_skills_registrations set status='approved'
  where id='00000000-0000-0000-0000-000000000201';
 exception when others then
  if position('Captain changed or is blocked' in sqlerrm)>0 then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'NONCANONICAL_CAPTAIN_APPROVED';end if;
end $captain_changed$;
update public.teams set captain_id='00000000-0000-0000-0000-000000009001';

update public.team_skills_registrations set status='approved'
 where id='00000000-0000-0000-0000-000000000201';
do $approved$
begin
 if (select status from public.team_skills_registrations
 where id='00000000-0000-0000-0000-000000000201')<>'approved'
 then raise exception 'VALID_ROSTER_NOT_APPROVED';end if;
end $approved$;
