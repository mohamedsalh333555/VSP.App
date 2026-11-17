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
 winner_registration_id uuid,status text not null,
 first_goals int,second_goals int,first_penalties int,second_penalties int);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,details jsonb);
create table public.team_skills_awards(cup_id uuid not null);
create table public.team_skills_scores(
 id uuid primary key default gen_random_uuid(),
 cup_id uuid not null,status text not null,raw_value numeric not null);
-- FINAL_SEEDING_FUNCTIONS_HERE
-- SAFE_REGENERATION_FUNCTION_HERE

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


-- Actual server RPC must seed every permitted roster size (5,6,7,8)
-- without missing or duplicated first-round teams, and never regenerate.
-- Four-team behavior and the twelve-stage/freeze gates are asserted above.
do $every_size$
declare n integer; idx integer; cup uuid; team uuid;
 first_round_count integer; byes integer; participants integer;
 denied boolean;
begin
 for n in 5..8 loop
   cup:=('00000000-0000-0000-0000-'||lpad((200+n)::text,12,'0'))::uuid;
   insert into public.team_skills_cups(id,status) values(cup,'live');
   for idx in 1..n loop
     team:=('00000000-0000-0000-0000-'||
       lpad((n*100+idx)::text,12,'0'))::uuid;
     insert into public.team_skills_registrations(id,cup_id,status,created_at)
     values(team,cup,'approved',now()+(idx||' seconds')::interval);
     insert into public.team_skills_leaderboard(
       registration_id,points,completed_stages,all_stages_approved)
     values(team,100-idx,12,true);
   end loop;
   if public.team_skills_generate_knockout(cup)<>8 then
     raise exception 'WRONG_BRACKET_SIZE_FOR_%',n;end if;
   select count(*),count(*) filter(where status='approved'
       and winner_registration_id is not null)
     into first_round_count,byes
     from public.team_skills_knockout
     where cup_id=cup and round_no=1;
   if first_round_count<>4 or byes<>8-n then
     raise exception 'INVALID_BYE_COUNT_FOR_%: %',n,byes;end if;
   select count(*) into participants
   from public.team_skills_knockout k
   cross join lateral unnest(array[k.first_registration_id,
                                   k.second_registration_id]) member
   where k.cup_id=cup and k.round_no=1 and member is not null;
   if participants<>n or
      (select count(distinct member)
       from public.team_skills_knockout k
       cross join lateral unnest(array[k.first_registration_id,
                                       k.second_registration_id]) member
       where k.cup_id=cup and k.round_no=1 and member is not null)<>n
   then raise exception 'DUPLICATE_OR_MISSING_SEEDED_TEAM_FOR_%',n;end if;
   if (select count(*) from public.team_skills_knockout
       where cup_id=cup)<>7 then
     raise exception 'MISSING_FUTURE_ROUND_FOR_%',n;end if;
   denied:=false;
   begin
     perform public.team_skills_generate_knockout(cup);
   exception when others then
     if position('already exists' in lower(sqlerrm))>0 then
       denied:=true;
     else raise;end if;
   end;
   if not denied or
      (select count(*) from public.team_skills_knockout
       where cup_id=cup)<>7 then
     raise exception 'BRACKET_REGEN_DUPLICATED_MATCHES_FOR_%',n;end if;
 end loop;
end $every_size$;


-- A supported re-generation repairs the unplayed bracket IN PLACE.
-- It retains every match UUID (unlike DELETE/reseed), restores byes,
-- never touches skills scores, and refuses any played game or awarded title.
do $safe_regenerate$
declare n integer; cup uuid; before_ids uuid[]; after_ids uuid[];
 initial_seeds text[]; final_seeds text[]; original_score numeric;
 denied boolean:=false;
begin
 cup:='00000000-0000-0000-0000-000000000001';
 select array_agg(id order by round_no,match_no)
 into before_ids from public.team_skills_knockout where cup_id=cup;
 if public.team_skills_regenerate_knockout(cup)<>4 then
   raise exception 'FOUR_TEAM_REGENERATION_WRONG_SIZE';end if;
 select array_agg(id order by round_no,match_no)
 into after_ids from public.team_skills_knockout where cup_id=cup;
 if before_ids is distinct from after_ids then
   raise exception 'FOUR_TEAM_REGENERATION_REPLACED_MATCH_IDS';end if;
 if (select raw_value from public.team_skills_scores
   where id='00000000-0000-0000-0000-000000000901')<>10 then
   raise exception 'REGENERATION_CHANGED_SKILLS_SCORE';end if;

 for n in 5..8 loop
   cup:=('00000000-0000-0000-0000-'||lpad((200+n)::text,12,'0'))::uuid;
   select array_agg(id order by round_no,match_no),
          array_agg(first_registration_id::text||':'||
            coalesce(second_registration_id::text,'BYE')
            order by round_no,match_no)
    into before_ids, initial_seeds from public.team_skills_knockout
    where cup_id=cup;
   if public.team_skills_regenerate_knockout(cup)<>8 or
      public.team_skills_regenerate_knockout(cup)<>8 then
     raise exception 'REGENERATION_WRONG_SIZE_%',n;end if;
   select array_agg(id order by round_no,match_no),
          array_agg(first_registration_id::text||':'||
            coalesce(second_registration_id::text,'BYE')
            order by round_no,match_no)
    into after_ids, final_seeds from public.team_skills_knockout
    where cup_id=cup;
   if before_ids is distinct from after_ids then
     raise exception 'REGENERATION_CHANGED_MATCH_IDS_FOR_%',n;end if;
   if (select count(*) from public.team_skills_knockout
       where cup_id=cup)<>7 or
      (select count(*) from public.team_skills_knockout
       where cup_id=cup and round_no=1 and status='approved'
         and second_registration_id is null)<>8-n then
      raise exception 'REGENERATION_WRONG_BYE_OR_MATCH_COUNT_FOR_%',n;
   end if;
   if (select count(*) from public.team_skills_audit
      where cup_id=cup and action='regenerate_knockout')<>2 then
     raise exception 'REGENERATION_NOT_AUDITED_TWICE_FOR_%',n;end if;
 end loop;

 -- An administered result makes the bracket irrevocably non-resettable.
 cup:='00000000-0000-0000-0000-000000000205';
 update public.team_skills_knockout set first_goals=2,second_goals=1,
 status='approved' where id=(select id from public.team_skills_knockout
 where cup_id=cup and status='scheduled' and round_no=1
 order by match_no limit 1);
 denied:=false;
 begin
   perform public.team_skills_regenerate_knockout(cup);
 exception when others then
   if position('played match' in lower(sqlerrm))>0 then denied:=true;
   else raise;end if;
 end;
 if not denied then raise exception 'PLAYED_MATCH_WIPED_BY_REGENERATION';end if;
 if (select count(*) from public.team_skills_knockout
   where cup_id=cup and first_goals=2 and second_goals=1)<>1 then
   raise exception 'FAILED_REGENERATION_CHANGED_REAL_RESULT';end if;

 -- Even an unplayed cup with an announced award must not be reseeded.
 cup:='00000000-0000-0000-0000-000000000206';
 insert into public.team_skills_awards(cup_id) values(cup);
 denied:=false;
 begin
  perform public.team_skills_regenerate_knockout(cup);
 exception when others then
  if position('award announcement' in lower(sqlerrm))>0 then
    denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'AWARDED_CUP_REGENERATED';end if;

 -- A completed/closed cup cannot reopen its results via regenerate.
 cup:='00000000-0000-0000-0000-000000000207';
 update public.team_skills_cups set status='completed' where id=cup;
 denied:=false;
 begin perform public.team_skills_regenerate_knockout(cup);
 exception when others then
  if position('only a live cup' in lower(sqlerrm))>0 then
    denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'COMPLETED_CUP_REGENERATED';end if;
end $safe_regenerate$;
