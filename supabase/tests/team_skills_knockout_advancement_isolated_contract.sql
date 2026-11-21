-- Disposable SQL acceptance of actual knockout seeding + match-approval RPC.
-- No hosted database/JWT. Database auth role identity simulated per transaction.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated')
 then create role authenticated;end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean
language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
create table public.team_skills_cups(
 id uuid primary key,status text not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,status text not null,created_at timestamptz default now());
create table public.team_skills_leaderboard(
 registration_id uuid not null,points numeric not null,
 completed_stages integer not null,all_stages_approved boolean not null);
create table public.team_skills_knockout(
 id uuid primary key default gen_random_uuid(),cup_id uuid not null,
 round_no int not null, match_no int not null,
 first_registration_id uuid,second_registration_id uuid,
 first_goals int,second_goals int,winner_registration_id uuid,
 status text not null,
 unique(cup_id,round_no,match_no),
 check(first_registration_id is null or second_registration_id is null
   or first_registration_id<>second_registration_id));
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
-- The real read-only knockout view permits authenticated SELECT; the
-- security-definer RPC still exclusively owns writes and authorization.
grant select on public.team_skills_knockout to authenticated;
-- INJECT_REAL_BRACKET_GENERATOR
-- INJECT_REAL_MATCH_APPROVAL
-- INJECT_KNOCKOUT_PENALTIES_MIGRATION

select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009001',false);
insert into public.team_skills_cups(id,status) values
('00000000-0000-0000-0000-000000000001','live'),
('00000000-0000-0000-0000-000000000002','cancelled');
insert into public.team_skills_registrations(id,cup_id,status,created_at)
select ('00000000-0000-0000-0000-'||lpad((100+i)::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000001', 'approved',
 now()+(i||' seconds')::interval from generate_series(1,4) i;
insert into public.team_skills_leaderboard(
 registration_id,points,completed_stages,all_stages_approved)
select id, 100-(row_number() over(order by id)),12,true
from public.team_skills_registrations;
do $seed$
begin
 if public.team_skills_generate_knockout(
  '00000000-0000-0000-0000-000000000001')<>4
 then raise exception 'DID_NOT_SEED_FOUR_TEAMS';end if;
 if (select count(*) from public.team_skills_knockout where
   cup_id='00000000-0000-0000-0000-000000000001')<>3
 then raise exception 'BRACKET_DID_NOT_CREATE_THREE_MATCHES';end if;
end $seed$;

-- An unseeded final is not a legitimate score event; no audit is written.
do $unready$
declare final_id uuid;denied boolean:=false;
begin
 select id into final_id from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000001' and round_no=2;
 begin
  perform public.team_skills_approve_knockout_match(final_id,1,0);
 exception when others then
  if position('match not ready' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'UNREADY_FINAL_APPROVED';end if;
end $unready$;

-- A judge/other authenticated role cannot promote a player to next round.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009099',true);
do $outsider$
declare match_id uuid;denied boolean:=false;
begin
 select id into match_id from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000001'
 and round_no=1 and match_no=1;
 begin
  perform public.team_skills_approve_knockout_match(match_id,3,1);
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then denied:=true;
  else raise;end if;
 end;
 if not denied then raise exception 'OUTSIDER_PROMOTED_KNOCKOUT';end if;
end $outsider$;
reset role;
select set_config('request.jwt.claim.sub',
 '00000000-0000-0000-0000-000000009001',true);

-- Admin must not approve a tie/negative result or create an audit for it.
do $invalid$
declare match_id uuid;denied boolean;
begin
 select id into match_id from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000001'
 and round_no=1 and match_no=1;
 denied:=false;
 begin
  perform public.team_skills_approve_knockout_match(match_id,1,1);
 exception when others then
  if position('decisive score required' in lower(sqlerrm))>0 then
   denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'TIED_MATCH_APPROVED';end if;
 denied:=false;
 begin
  perform public.team_skills_approve_knockout_match(match_id,-1,2);
 exception when others then
  if position('decisive score required' in lower(sqlerrm))>0 then
   denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'NEGATIVE_KNOCKOUT_GOALS_ACCEPTED';end if;
 if exists(select 1 from public.team_skills_audit where action='approve_knockout')
 then raise exception 'INVALID_RESULT_CREATED_AUDIT';end if;
end $invalid$;

-- Progress both semifinals into the right sides of the final and select the
-- winner by authoritative final result, not by a client-supplied UUID.
do $complete_bracket$
declare semi1 uuid;semi2 uuid;final_id uuid;
 a uuid;b uuid;champ uuid;returned uuid;denied boolean:=false;
begin
 select id,first_registration_id,second_registration_id
 into semi1,a,b from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000001'
 and round_no=1 and match_no=1;
 returned:=public.team_skills_approve_knockout_match(semi1,2,1);
 if returned<>a then raise exception 'FIRST_SEMI_WINNER_WRONG';end if;
 select id into semi2 from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000001'
 and round_no=1 and match_no=2;
 begin
  perform public.team_skills_approve_knockout_match(semi1,4,0);
 exception when others then
  if position('match not ready' in lower(sqlerrm))>0 then
    denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'DUPLICATE_SEMI_APPROVAL';end if;
 select second_registration_id into b from public.team_skills_knockout
 where id=semi2;
 returned:=public.team_skills_approve_knockout_match(semi2,0,3);
 if returned<>b then raise exception 'SECOND_SEMI_WINNER_WRONG';end if;
 select id,first_registration_id,second_registration_id
 into final_id,a,b from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000001'
 and round_no=2 and match_no=1;
 if a is null or b is null or a=b then
  raise exception 'FINAL_BRACKET_SIDES_NOT_POPULATED';end if;
 returned:=public.team_skills_approve_knockout_match(final_id,1,2);
 if returned<>b then raise exception 'FINAL_CHAMPION_NOT_WINNER';end if;
 if (select count(*) from public.team_skills_knockout
     where cup_id='00000000-0000-0000-0000-000000000001' and status='approved')<>3
 then raise exception 'NOT_ALL_MATCHES_APPROVED';end if;
 if (select count(*) from public.team_skills_audit
     where action='approve_knockout')<>3
 then raise exception 'AUDIT_EVENT_COUNT_INVALID';end if;
 denied:=false;
 begin
  perform public.team_skills_approve_knockout_match(final_id,9,0);
 exception when others then
  if position('match not ready' in lower(sqlerrm))>0 then
   denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'FINAL_APPROVED_TWICE';end if;
 if (select count(*) from public.team_skills_audit
     where action='approve_knockout')<>3
 then raise exception 'SECOND_FINAL_CREATED_DUPLICATE_AUDIT';end if;
end $complete_bracket$;

insert into public.team_skills_knockout(
 cup_id,round_no,match_no,first_registration_id,
 second_registration_id,status)
values(
 '00000000-0000-0000-0000-000000000002',1,1,
 '00000000-0000-0000-0000-000000000101',
 '00000000-0000-0000-0000-000000000102','scheduled');
do $cancelled$
declare match_id uuid;denied boolean:=false;
begin
 select id into match_id from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000002';
 begin
  perform public.team_skills_approve_knockout_match(match_id,2,0);
 exception when others then
  if position('after cancellation' in lower(sqlerrm))>0 then
   denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'CANCELLED_CUP_RESULT_APPROVED';end if;
 if (select status from public.team_skills_knockout where id=match_id)<>'scheduled'
 then raise exception 'CANCELLED_CUP_MATCH_MUTATED';end if;
end $cancelled$;

-- Separate completed, 4-team cup so the legacy non-draw approval tests above
-- remain unchanged. The server must decide the tied match by penalties.
insert into public.team_skills_cups(id,status) values
('00000000-0000-0000-0000-000000000003','live');
insert into public.team_skills_registrations(id,cup_id,status,created_at)
select ('00000000-0000-0000-0000-'||lpad((300+i)::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000003','approved',
 now()+(i||' seconds')::interval from generate_series(1,4) i;
insert into public.team_skills_leaderboard(
 registration_id,points,completed_stages,all_stages_approved)
select id,50-(row_number() over (order by id)),12,true
from public.team_skills_registrations
where cup_id='00000000-0000-0000-0000-000000000003';
select public.team_skills_generate_knockout(
 '00000000-0000-0000-0000-000000000003');

do $penalty_tie$
declare m1 uuid;m2 uuid;final_id uuid;first_id uuid;
 second_id uuid; winner uuid;denied boolean;
begin
 select id, first_registration_id,second_registration_id
 into m1,first_id,second_id from public.team_skills_knockout
 where cup_id='00000000-0000-0000-0000-000000000003'
 and round_no=1 and match_no=1;
 -- Ties must NOT silently be decided by the legacy three-argument endpoint.
 denied:=false;
 begin perform public.team_skills_approve_knockout_match(m1,1,1);
 exception when others then
  if position('decisive score required' in lower(sqlerrm))>0
  then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'LEGACY_DRAW_AUTO_ADVANCED';end if;
 denied:=false;
 begin perform public.team_skills_approve_knockout_penalties(m1,1,1,4,4);
 exception when others then
  if position('decisive penalty score required' in lower(sqlerrm))>0
  then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'TIED_PENALTIES_ADVANCED';end if;
 denied:=false;
 begin perform public.team_skills_approve_knockout_penalties(m1,1,0,4,3);
 exception when others then
  if position('require a tied' in lower(sqlerrm))>0
  then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'PENALTIES_ALLOWED_ON_CLEAR_REGULATION_WIN';end if;
 denied:=false;
 begin perform public.team_skills_approve_knockout_penalties(m1,2,2,-1,3);
 exception when others then
  if position('decisive penalty score required' in lower(sqlerrm))>0
  then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'NEGATIVE_PENALTIES_ADVANCED';end if;
 winner:=public.team_skills_approve_knockout_penalties(m1,1,1,4,5);
 if winner<>second_id or
  (select winner_registration_id from public.team_skills_knockout
   where id=m1)<>second_id
 then raise exception 'WRONG_TIED_SEMIFINAL_WINNER';end if;
 if not exists(select 1 from public.team_skills_knockout where id=m1
    and first_penalties=4 and second_penalties=5 and first_goals=1
    and second_goals=1 and status='approved') then
   raise exception 'PENALTY_EVIDENCE_NOT_PERSISTED';end if;
 if not exists(select 1 from public.team_skills_knockout
  where cup_id='00000000-0000-0000-0000-000000000003'
    and round_no=2 and match_no=1
    and first_registration_id=second_id)
 then raise exception 'PENALTY_WINNER_NOT_PROMOTED';end if;
 denied:=false;
 begin perform public.team_skills_approve_knockout_penalties(m1,1,1,5,4);
 exception when others then
  if position('match not ready' in lower(sqlerrm))>0
  then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'DUPLICATE_PENALTY_APPROVAL';end if;
 if (select count(*) from public.team_skills_audit
  where cup_id='00000000-0000-0000-0000-000000000003'
   and action='approve_knockout' and subject_id=m1
   and details->>'method'='penalties' and details->>'first_penalties'='4'
   and details->>'second_penalties'='5')<>1 then
   raise exception 'PENALTY_AUDIT_NOT_EXACTLY_ONCE';end if;
 select id into m2 from public.team_skills_knockout
  where cup_id='00000000-0000-0000-0000-000000000003'
    and round_no=1 and match_no=2;
 perform public.team_skills_approve_knockout_match(m2,2,1);
 select id into final_id from public.team_skills_knockout
  where cup_id='00000000-0000-0000-0000-000000000003'
    and round_no=2 and match_no=1;
 if not exists(select 1 from public.team_skills_knockout
  where id=final_id and first_registration_id is not null
   and second_registration_id is not null) then
   raise exception 'PENALTY_FINAL_NOT_READY';end if;
 perform public.team_skills_approve_knockout_penalties(final_id,0,0,3,2);
 if (select count(*) from public.team_skills_knockout
  where cup_id='00000000-0000-0000-0000-000000000003'
  and status='approved')<>3 then
   raise exception 'FINAL_PENALTY_DRAW_NOT_APPROVED';end if;
 if (select count(*) from public.team_skills_audit
  where cup_id='00000000-0000-0000-0000-000000000003'
  and action='approve_knockout')<>3 then
   raise exception 'PENALTY_FINAL_DUPLICATE_AUDITS';end if;
end $penalty_tie$;

rollback;
