-- Disposable SQL regression: assigned but BLOCKED judges cannot submit either
-- regular skills scores or goalkeeper measurements. Organizer is read-only.
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean
language sql stable set search_path='' as $
 select auth.uid()='00000000-0000-0000-0000-000000009099'::uuid $;
create function vsp_skills_private.score(
 p_metric text,p_raw numeric,p_weight numeric,p_target numeric,p_best integer,p_worst integer)
returns numeric language sql immutable set search_path=''
as $$ select round(p_weight*p_raw/nullif(p_target,0),2) $$;

create table public.users(id uuid primary key,is_blocked boolean not null);
create table public.team_skills_officials(cup_id uuid,user_id uuid,role text);
create table public.team_skills_cups(id uuid primary key,status text);
create table public.team_skills_registrations(id uuid primary key,cup_id uuid,status text);
create table public.team_skills_phases(
 cup_id uuid,stage_no integer,metric text,weight numeric,target numeric,best_ms integer,worst_ms integer);
create table public.team_skills_scores(
 id uuid primary key default gen_random_uuid(),cup_id uuid,registration_id uuid,
 stage_no integer,raw_value numeric,computed_points numeric,entered_by uuid,status text default 'pending');
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
create table public.team_skills_goalkeeper_trials(
 id uuid primary key,cup_id uuid,status text,
 shots_on_target integer,saves integer,goals_conceded integer);
create table public.notifications(
 user_id uuid,title text,body text,message text,type text,metadata jsonb);
-- BLOCKED_JUDGE_FUNCTIONS_HERE

insert into public.users(id,is_blocked) values
 ('00000000-0000-0000-0000-000000009001',true);
insert into public.team_skills_cups(id,status)
values('00000000-0000-0000-0000-000000000001','live');
insert into public.team_skills_registrations(id,cup_id,status)
values('00000000-0000-0000-0000-000000000101',
       '00000000-0000-0000-0000-000000000001','approved');
insert into public.team_skills_officials(cup_id,user_id,role)
values('00000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000009001','judge');
insert into public.team_skills_phases(cup_id,stage_no,metric,weight,target) values
 ('00000000-0000-0000-0000-000000000001',1,'count',10,10),
 ('00000000-0000-0000-0000-000000000001',2,'count',10,10);
insert into public.team_skills_goalkeeper_trials(id,cup_id,status) values
 ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000001','scheduled'),
 ('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000001','scheduled');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);

do $deny_blocked$
declare denied_score boolean:=false;denied_keeper boolean:=false;
begin
 begin
  perform public.team_skills_record_score('00000000-0000-0000-0000-000000000101',1,5);
 exception when others then
  if position('Judge or admin only' in sqlerrm)>0 then denied_score:=true;else raise;end if;
 end;
 begin
  perform public.team_skills_record_goalkeeper('00000000-0000-0000-0000-000000000201',10,8,2);
 exception when others then
  if position('Judge only' in sqlerrm)>0 then denied_keeper:=true;else raise;end if;
 end;
 if not denied_score or not denied_keeper then
  raise exception 'BLOCKED_JUDGE_ACCEPTED: score %, goalkeeper %',denied_score,denied_keeper;
 end if;
end $deny_blocked$;
update public.users set is_blocked=false
where id='00000000-0000-0000-0000-000000009001';
select public.team_skills_record_score(
 '00000000-0000-0000-0000-000000000101',1,5);
select public.team_skills_record_goalkeeper(
 '00000000-0000-0000-0000-000000000201',10,8,2);
do $accepted$
begin
 if (select count(*) from public.team_skills_scores)<>1
 or (select count(*) from public.team_skills_goalkeeper_trials
  where status='completed')<>1 then
  raise exception 'ACTIVE_ASSIGNED_JUDGE_WAS_NOT_ACCEPTED';
 end if;
end $accepted$;
update public.team_skills_officials set role='organizer'
 where user_id='00000000-0000-0000-0000-000000009001';
do $deny_organizer$
declare score_denied boolean:=false;gk_denied boolean:=false;
begin
 begin
  perform public.team_skills_record_score('00000000-0000-0000-0000-000000000101',2,4);
 exception when others then
  if position('Judge or admin only' in sqlerrm)>0 then score_denied:=true;else raise;end if;
 end;
 begin
  perform public.team_skills_record_goalkeeper('00000000-0000-0000-0000-000000000202',10,8,2);
 exception when others then
  if position('Judge only' in sqlerrm)>0 then gk_denied:=true;else raise;end if;
 end;
 if not score_denied or not gk_denied then
  raise exception 'ORGANIZER_WROTE_JUDGE_MEASUREMENTS';
 end if;
end $deny_organizer$;

-- Revocation without globally blocking this VSP account.
update public.team_skills_officials set role='judge'
where user_id='00000000-0000-0000-0000-000000009001';
do $nonadmin_cannot_revoke$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_revoke_official(
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000009001',
    'Unprivileged requester is not an admin');
 exception when others then
  if position('Not authorized' in sqlerrm)>0 then denied:=true; else raise;end if;
 end;
 if not denied then raise exception 'JUDGE_COULD_REVOKE_THEMSELVES';end if;
end $nonadmin_cannot_revoke$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009099',false);
select public.team_skills_revoke_official(
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000009001',
    'Team judge has been reassigned by the event admin');
do $verify_revocation$
begin
 if exists(select 1 from public.team_skills_officials
  where cup_id='00000000-0000-0000-0000-000000000001'
    and user_id='00000000-0000-0000-0000-000000009001') then
  raise exception 'OFFICIAL_ASSIGNMENT_NOT_DELETED';end if;
 if (select count(*) from public.team_skills_audit
     where action='revoke_official')<>1 then
  raise exception 'MISSING_REVOCATION_AUDIT';end if;
 if (select count(*) from public.notifications
   where user_id='00000000-0000-0000-0000-000000009001'
    and metadata->>'event'='official_revoked')<>1 then
  raise exception 'MISSING_JUDGE_REVOCATION_NOTICE';end if;
end $verify_revocation$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
do $revoked_cannot_write$
declare denied_score boolean:=false;denied_keeper boolean:=false;
begin
 begin
  perform public.team_skills_record_score('00000000-0000-0000-0000-000000000101',2,5);
 exception when others then
  if position('Judge or admin only' in sqlerrm)>0 then denied_score:=true;else raise;end if;
 end;
 begin
  perform public.team_skills_record_goalkeeper('00000000-0000-0000-0000-000000000202',10,8,2);
 exception when others then
  if position('Judge only' in sqlerrm)>0 then denied_keeper:=true;else raise;end if;
 end;
 if not denied_score or not denied_keeper then
  raise exception 'REVOKED_OFFICIAL_CAN_WRITE: score %, keeper %',denied_score,denied_keeper;
 end if;
end $revoked_cannot_write$;
