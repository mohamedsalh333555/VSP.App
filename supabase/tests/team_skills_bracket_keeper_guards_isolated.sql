-- PostgreSQL isolated regression for future knockout placeholders and keeper ties.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then
  create role anon;end if;
end $roles$;
create schema vsp_skills_private;
create table public.team_skills_knockout(
 id uuid primary key default gen_random_uuid(),
 first_registration_id uuid,
 second_registration_id uuid,
 constraint team_skills_knockout_check
 check(first_registration_id is distinct from second_registration_id)
);
-- KNOCKOUT_FIX_HERE
insert into public.team_skills_knockout(first_registration_id,second_registration_id)
values(null,null),(null,'00000000-0000-0000-0000-000000000001');
do $check$
declare denied boolean:=false;
begin
 begin
  insert into public.team_skills_knockout(first_registration_id,second_registration_id)
  values('00000000-0000-0000-0000-000000000001',
         '00000000-0000-0000-0000-000000000001');
 exception when check_violation then denied:=true;
 end;
 if not denied then raise exception 'SAME_TEAM_ALLOWED_ON_BOTH_BRACKET_SIDES';end if;
 if (select count(*) from public.team_skills_knockout)<>2 then
  raise exception 'Unresolved future knockout slots are invalid';
 end if;
end $check$;

create table public.team_skills_awards(
 cup_id uuid not null,
 award_type text not null,
 player_id uuid
);
create table public.team_skills_goalkeeper_trials(
 cup_id uuid not null,
 goalkeeper_id uuid not null,
 shots_on_target integer not null,
 saves integer not null,
 status text not null
);
-- KEEPER_FIX_HERE
insert into public.team_skills_goalkeeper_trials(cup_id,goalkeeper_id,shots_on_target,saves,status)
values
('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000101',10,5,'approved'),
('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000102',10,5,'approved');
do $tie$
declare denied boolean:=false;
begin
 begin
  insert into public.team_skills_awards(cup_id,award_type,player_id)
  values('00000000-0000-0000-0000-000000000010','best_goalkeeper',
         '00000000-0000-0000-0000-000000000101');
 exception when others then
  if position('tie' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'ARBITRARY_KEEPER_TIE_AWARDED';end if;
end $tie$;
update public.team_skills_goalkeeper_trials set saves=4
where goalkeeper_id='00000000-0000-0000-0000-000000000102';
insert into public.team_skills_awards(cup_id,award_type,player_id)
values('00000000-0000-0000-0000-000000000010','best_goalkeeper',
       '00000000-0000-0000-0000-000000000101');
do $validate$
begin
 if (select count(*) from public.team_skills_awards)<>1
 then raise exception 'OBJECTIVE_GOALKEEPER_WINNER_REJECTED';end if;
end $validate$;
