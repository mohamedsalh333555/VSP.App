-- Disposable PostgreSQL finality contract: actual award/score triggers
-- from the latest migrations, with no authenticated data or hosted DB.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema vsp_skills_private;
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,status text not null);
create table public.team_skills_leaderboard(
 registration_id uuid not null,cup_id uuid not null,team_id uuid not null,
 points numeric not null,completed_stages integer not null,
 all_stages_approved boolean not null);
create table public.team_skills_awards(
 cup_id uuid not null,award_type text not null,team_id uuid not null);
create table public.team_skills_knockout(cup_id uuid not null);
create table public.team_skills_scores(
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null,raw_value numeric not null);
-- CHAMPION_FINALITY_REAL_MIGRATIONS
-- The production seeding-freeze trigger was created by migration 84000.
-- In this disposable fixture there is no full cup schema, so recreate
-- that trigger on the local test table after the updated function loads.
create trigger team_skills_freeze_score_after_seed
before insert or update or delete on public.team_skills_scores
for each row execute function vsp_skills_private.guard_score_after_seeding();


insert into public.team_skills_registrations(id,cup_id,status)
select ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,
       '00000000-0000-0000-0000-000000000001'::uuid,'approved'
from generate_series(1,4) i;
insert into public.team_skills_leaderboard(
 registration_id,cup_id,team_id,points,completed_stages,all_stages_approved)
select ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,
       '00000000-0000-0000-0000-000000000001'::uuid,
       ('00000000-0000-0000-0000-'||lpad((200+i)::text,12,'0'))::uuid,
       case when i=1 then 100 else 0 end,
       case when i=1 then 12 else 0 end,
       i=1
from generate_series(1,4) i;
insert into public.team_skills_scores(cup_id,raw_value)
values('00000000-0000-0000-0000-000000000001',10);

do $incomplete$
declare blocked boolean:=false;
begin
 begin
  insert into public.team_skills_awards(cup_id,award_type,team_id)
  values('00000000-0000-0000-0000-000000000001','team_champion',
         '00000000-0000-0000-0000-000000000201');
 exception when others then
  if position('all teams have 12 approved stages' in sqlerrm)>0 then
    blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'INCOMPLETE_TEAMS_AWARDED_TITLE';end if;
end $incomplete$;
update public.team_skills_leaderboard
set completed_stages=12,all_stages_approved=true,
    points=case when team_id='00000000-0000-0000-0000-000000000201'
                then 100 else 50 end;
-- A losing team cannot claim an undisputed 100-point skills title.
do $wrong_team_claim$
declare blocked boolean:=false;
begin
 begin
  insert into public.team_skills_awards(cup_id,award_type,team_id)
  values('00000000-0000-0000-0000-000000000001','team_champion',
         '00000000-0000-0000-0000-000000000202');
 exception when others then
  if position('wrong team' in lower(sqlerrm))>0 then
    blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'LOSING_TEAM_CLAIMED_SKILLS_TITLE';end if;
 if (select count(*) from public.team_skills_awards)<>0
 then raise exception 'DISPUTED_SKILLS_TITLE_LEFT_AWARD';end if;
end $wrong_team_claim$;
insert into public.team_skills_awards(cup_id,award_type,team_id)
values('00000000-0000-0000-0000-000000000001','team_champion',
       '00000000-0000-0000-0000-000000000201');

do $frozen$
declare blocked_update boolean:=false;
blocked_delete boolean:=false;
blocked_insert boolean:=false;
begin
 begin
   update public.team_skills_scores set raw_value=11
   where cup_id='00000000-0000-0000-0000-000000000001';
 exception when others then
   if position('champion announced' in lower(sqlerrm))>0 then
     blocked_update:=true;else raise;end if;
 end;
 begin
   delete from public.team_skills_scores
   where cup_id='00000000-0000-0000-0000-000000000001';
 exception when others then
   if position('champion announced' in lower(sqlerrm))>0 then
     blocked_delete:=true;else raise;end if;
 end;
 begin
   insert into public.team_skills_scores(cup_id,raw_value)
   values('00000000-0000-0000-0000-000000000001',7);
 exception when others then
   if position('champion announced' in lower(sqlerrm))>0 then
     blocked_insert:=true;else raise;end if;
 end;
 if not blocked_update or not blocked_delete or not blocked_insert then
   raise exception 'CHAMPION_TITLE_DID_NOT_FREEZE_SCORES update %, delete %, insert %',
     blocked_update,blocked_delete,blocked_insert;end if;
end $frozen$;

-- A fully completed cup with a tied top score is not allowed to crown
-- the arbitrary first team, even when both claimants have all 12 stages.
update public.team_skills_leaderboard
set points=100
where team_id='00000000-0000-0000-0000-000000000202';
do $tie$
declare blocked boolean:=false;
begin
 begin
  insert into public.team_skills_awards(cup_id,award_type,team_id)
  values('00000000-0000-0000-0000-000000000001','team_champion',
         '00000000-0000-0000-0000-000000000202');
 exception when others then
  if position('unresolved points tie' in lower(sqlerrm))>0 then
     blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'TIED_CHAMPION_WAS_CROWNED';end if;
end $tie$;
