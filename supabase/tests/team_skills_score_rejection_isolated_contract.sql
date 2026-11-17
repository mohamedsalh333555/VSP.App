-- Local-only contract: admin rejects pending skills score, corrects it,
-- and re-approves; no outside authority, duplicate audit or post-seed writes.
-- Inject canonical score calculator, approve/correct RPCs and new rejection RPC.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;
 end if;
 if not exists(select 1 from pg_roles where rolname='anon') then
   create role anon;
 end if;
end $roles$;
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean
language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
create table public.team_skills_cups(id uuid primary key,status text not null);
create table public.team_skills_phases (
 cup_id uuid not null,stage_no int not null, metric text,
 weight numeric,target numeric,best_ms int,worst_ms int
);
create table public.team_skills_scores(
 id uuid primary key,cup_id uuid not null,
 stage_no integer not null, status text not null,
 raw_value numeric not null, computed_points numeric not null,
 entered_by uuid,entered_at timestamptz,
 approved_by uuid,approved_at timestamptz
);
create table public.team_skills_knockout(cup_id uuid not null);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,
 details jsonb
);
-- SCORE_CALCULATION_HERE
-- APPROVE_SCORE_HERE
-- CORRECT_SCORE_HERE
-- REJECT_SCORE_HERE

insert into public.team_skills_cups values
('00000000-0000-0000-0000-000000000001','live'),
('00000000-0000-0000-0000-000000000002','cancelled');
insert into public.team_skills_phases
(cup_id,stage_no,metric,weight,target)
values('00000000-0000-0000-0000-000000000001',1,'count',10,10);
insert into public.team_skills_scores(
 id,cup_id,stage_no,status,raw_value,computed_points,entered_by)
values
('00000000-0000-0000-0000-000000000101',
 '00000000-0000-0000-0000-000000000001',1,'pending',5,5,
 '00000000-0000-0000-0000-000000009099'),
('00000000-0000-0000-0000-000000000102',
 '00000000-0000-0000-0000-000000000001',1,'approved',9,9,
 '00000000-0000-0000-0000-000000009099'),
('00000000-0000-0000-0000-000000000103',
 '00000000-0000-0000-0000-000000000001',1,'pending',3,3,
 '00000000-0000-0000-0000-000000009099'),
('00000000-0000-0000-0000-000000000104',
 '00000000-0000-0000-0000-000000000002',1,'pending',4,4,
 '00000000-0000-0000-0000-000000009099');

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009099',true);
do $outsider$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_reject_score(
    '00000000-0000-0000-0000-000000000101','Invalid measurement');
 exception when others then
  if position('not authorized' in lower(sqlerrm))>0 then
    denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'OUTSIDER_REJECTED_SCORE';end if;
end $outsider$;
reset role;
do $outsider_no_write$
begin
 if exists(select 1 from public.team_skills_audit) or
  (select status from public.team_skills_scores
   where id='00000000-0000-0000-0000-000000000101')<>'pending'
 then raise exception 'OUTSIDER_CHANGED_SCORE';end if;
end $outsider_no_write$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $bad_reason$
declare denied boolean:=false;
begin
 begin
  perform public.team_skills_reject_score(
    '00000000-0000-0000-0000-000000000101','bad');
 exception when others then
  if position('reason must contain' in lower(sqlerrm))>0 then
    denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'UNDOCUMENTED_SCORE_REJECTION';end if;
end $bad_reason$;
select public.team_skills_reject_score(
 '00000000-0000-0000-0000-000000000101','Measurement was not valid');
reset role;
do $rejected$
begin
 if not exists(select 1 from public.team_skills_scores
  where id='00000000-0000-0000-0000-000000000101'
  and status='rejected' and raw_value=5 and computed_points=5
  and approved_by is null and approved_at is null)
 then raise exception 'REJECT_DID_NOT_PRESERVE_UNAPPROVED_SCORE';end if;
 if (select status from public.team_skills_scores
  where id='00000000-0000-0000-0000-000000000102')<>'approved'
 then raise exception 'REJECT_MODIFIED_OTHER_SCORE';end if;
 if (select count(*) from public.team_skills_audit
   where action='reject_score'
    and subject_id='00000000-0000-0000-0000-000000000101'
    and actor_id='00000000-0000-0000-0000-000000009001'
    and details->>'reason'='Measurement was not valid'
    and details->>'old_raw'='5'
    and details->>'old_points'='5')<>1
 then raise exception 'REJECTION_AUDIT_NOT_EXACTLY_ONCE';end if;
end $rejected$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $repeat_reject$
declare duplicate_denied boolean:=false;
 approved_denied boolean:=false;
 unknown_denied boolean:=false;
begin
 begin
  perform public.team_skills_reject_score(
   '00000000-0000-0000-0000-000000000101','Repeated rejection attempt');
 exception when others then
  if position('only a pending' in lower(sqlerrm))>0 then
   duplicate_denied:=true;else raise;end if;
 end;
 begin
  perform public.team_skills_reject_score(
   '00000000-0000-0000-0000-000000000102','Reject approved score');
 exception when others then
  if position('only a pending' in lower(sqlerrm))>0 then
   approved_denied:=true;else raise;end if;
 end;
 begin
  perform public.team_skills_reject_score(
   '00000000-0000-0000-0000-000000000999','Unknown score identifier');
 exception when others then
  if position('score not found' in lower(sqlerrm))>0 then
   unknown_denied:=true;else raise;end if;
 end;
 if not duplicate_denied or not approved_denied or not unknown_denied then
  raise exception 'REJECT_REPEAT_OR_APPROVED_OR_UNKNOWN_ACCEPTED';end if;
end $repeat_reject$;

-- Existing correction API is the only way to return a rejected raw value
-- for admin reapproval. New user-facing re-entry by a judge is NOT claimed.
select public.team_skills_correct_score(
 '00000000-0000-0000-0000-000000000101',
 7,'Measured target was corrected');
reset role;
do $reentered$
begin
 if not exists(select 1 from public.team_skills_scores
   where id='00000000-0000-0000-0000-000000000101'
     and status='pending' and raw_value=7 and computed_points=7
     and approved_by is null and approved_at is null)
 then raise exception 'CORRECTED_SCORE_NOT_RETURNED_PENDING';end if;
 if (select count(*) from public.team_skills_audit
   where action='correct_score' and
   subject_id='00000000-0000-0000-0000-000000000101'
   and details->>'old_status'='rejected')<>1
 then raise exception 'CORRECTION_MISSING_REJECTED_HISTORY';end if;
end $reentered$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
select public.team_skills_approve_score(
 '00000000-0000-0000-0000-000000000101');
reset role;
do $full_cycle$
begin
 if not exists(select 1 from public.team_skills_scores
  where id='00000000-0000-0000-0000-000000000101'
    and status='approved' and raw_value=7 and computed_points=7
    and approved_by='00000000-0000-0000-0000-000000009001'
    and approved_at is not null)
 then raise exception 'CORRECTED_SCORE_NOT_APPROVED';end if;
 if (select count(*) from public.team_skills_audit
   where subject_id='00000000-0000-0000-0000-000000000101')<>3
 then raise exception 'REJECT_CORRECT_APPROVE_AUDIT_COUNT_MISMATCH';end if;
end $full_cycle$;

-- Once any finals exist, pending score rejection must fail and not
-- change the row or create another audit event.
insert into public.team_skills_knockout values(
 '00000000-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
do $post_seed$
declare denied boolean:=false;closed_denied boolean:=false;
begin
 begin
  perform public.team_skills_reject_score(
   '00000000-0000-0000-0000-000000000103','After knockout seeded');
 exception when others then
  if position('already seeded' in lower(sqlerrm))>0 then
   denied:=true;else raise;end if;
 end;
 begin
  perform public.team_skills_reject_score(
   '00000000-0000-0000-0000-000000000104','Cancelled tournament');
 exception when others then
  if position('active tournament' in lower(sqlerrm))>0 then
   closed_denied:=true;else raise;end if;
 end;
 if not denied or not closed_denied then
  raise exception 'CANCELLED_OR_SEEDED_SCORE_REJECTION_ACCEPTED';end if;
end $post_seed$;
reset role;
do $no_extra_audit$
begin
 if (select count(*) from public.team_skills_audit)<>3 or
  (select count(*) from public.team_skills_scores
   where status='pending')<>2
 then raise exception 'INVALID_REJECTION_CREATED_EXTRA_SIDE_EFFECTS';end if;
end $no_extra_audit$;
rollback;
