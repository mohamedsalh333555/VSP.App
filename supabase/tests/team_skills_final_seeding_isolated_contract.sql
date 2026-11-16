-- Disposable PostgreSQL fixture; actual final-seeding function and trigger
-- are injected directly from the checked-in migration before running assertions.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;
 end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
create table public.team_skills_cups(id uuid primary key,status text not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,status text not null,created_at timestamptz default now());
create table public.team_skills_leaderboard(
 registration_id uuid not null,points numeric not null,
 completed_stages integer not null,all_stages_approved boolean not null);
create table public.team_skills_knockout(
 id uuid primary key default gen_random_uuid(), cup_id uuid not null,
 round_no integer not null,match_no integer not null,
 first_registration_id uuid,second_registration_id uuid,
 winner_registration_id uuid,status text not null);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,details jsonb);
create table public.team_skills_scores(
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null,status text not null,raw_value numeric not null);
-- FINAL_SEEDING_FUNCTIONS_HERE

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
insert into public.team_skills_cups(id,status)
values('00000000-0000-0000-0000-000000000001','live');
insert into public.team_skills_registrations(id,cup_id,status,created_at) values
('00000000-0000-0000-0000-000000000111','00000000-0000-0000-0000-000000000001','approved',now()),
('00000000-0000-0000-0000-000000000112','00000000-0000-0000-0000-000000000001','approved',now()),
('00000000-0000-0000-0000-000000000113','00000000-0000-0000-0000-000000000001','approved',now()),
('00000000-0000-0000-0000-000000000114','00000000-0000-0000-0000-000000000001','approved',now());
insert into public.team_skills_leaderboard(registration_id,points,completed_stages,all_stages_approved)
values
('00000000-0000-0000-0000-000000000111',100,12,true),
('00000000-0000-0000-0000-000000000112',90,12,true),
('00000000-0000-0000-0000-000000000113',80,11,false);
insert into public.team_skills_scores(id,cup_id,status,raw_value)
values('00000000-0000-0000-0000-000000000901',
       '00000000-0000-0000-0000-000000000001','approved',10);

do $early$
declare rejected boolean:=false;
begin
 begin
  perform public.team_skills_generate_knockout('00000000-0000-0000-0000-000000000001');
 exception when others then
  if position('12 skills stages' in sqlerrm)>0 then rejected:=true;
  else raise;end if;
 end;
 if not rejected then raise exception 'EARLY_KNOCKOUT_SEEDING_ALLOWED';end if;
 if exists(select 1 from public.team_skills_knockout) then
  raise exception 'EARLY_GENERATION_MODIFIED_BRACKET';end if;
end $early$;
update public.team_skills_leaderboard
set completed_stages=12,all_stages_approved=true
where registration_id='00000000-0000-0000-0000-000000000113';
insert into public.team_skills_leaderboard(registration_id,points,completed_stages,all_stages_approved)
values('00000000-0000-0000-0000-000000000114',70,12,true);
select public.team_skills_generate_knockout('00000000-0000-0000-0000-000000000001');

do $frozen$
declare denied boolean:=false;
begin
 if (select count(*) from public.team_skills_knockout)<>3 then
  raise exception 'WRONG_KNOCKOUT_MATCH_COUNT';end if;
 begin
  update public.team_skills_scores set raw_value=5
  where id='00000000-0000-0000-0000-000000000901';
 exception when others then
  if position('frozen' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'SCORE_MUTATED_AFTER_SEED';end if;
 denied:=false;
 begin
  delete from public.team_skills_scores
  where id='00000000-0000-0000-0000-000000000901';
 exception when others then
  if position('frozen' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'SCORE_DELETED_AFTER_SEED';end if;
 denied:=false;
 begin
  insert into public.team_skills_scores(cup_id,status,raw_value)
  values('00000000-0000-0000-0000-000000000001','pending',9);
 exception when others then
  if position('frozen' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'LATE_SCORE_ADDED_AFTER_SEED';end if;
 if (select raw_value from public.team_skills_scores
     where id='00000000-0000-0000-0000-000000000901')<>10 then
  raise exception 'BLOCKED_MUTATION_TOUCHED_ROW';end if;
end $frozen$;
