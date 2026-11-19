-- Verified source migration against disposable PostgreSQL. No FCM/network.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema vsp_skills_private;
create table public.team_skills_cups(id uuid primary key,status text not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,team_id uuid not null,
 captain_id uuid not null,status text not null);
create table public.team_skills_scores(
 id uuid primary key,cup_id uuid not null,registration_id uuid not null,
 stage_no integer not null,computed_points numeric not null,
 status text not null,approved_by uuid,approved_at timestamptz);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid not null,
 title text,body text,message text,type text,metadata jsonb);
-- ACTUAL_TEAM_SKILLS_SCORE_NOTIFICATION_MIGRATION

insert into public.team_skills_cups(id,status) values
 ('00000000-0000-0000-0000-000000000001','live'),
 ('00000000-0000-0000-0000-000000000002','draft'),
 ('00000000-0000-0000-0000-000000000003','cancelled');
insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000301','approved'),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000302','pending'),
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000303','approved'),
 ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000304','approved'),
 ('00000000-0000-0000-0000-000000000105','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000205','00000000-0000-0000-0000-000000000305','approved');
insert into public.team_skills_scores(
 id,cup_id,registration_id,stage_no,computed_points,status,approved_by,approved_at)
values
 ('00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000101',1,20,'pending',null,null),
 ('00000000-0000-0000-0000-000000000402','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000102',2,10,'pending',null,null),
 ('00000000-0000-0000-0000-000000000403','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000103',3,15,'pending',null,null),
 ('00000000-0000-0000-0000-000000000404','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000104',4,15,'pending',null,null),
 ('00000000-0000-0000-0000-000000000405','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000101',5,15,'pending',null,null),
 ('00000000-0000-0000-0000-000000000406','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000105',6,17,'pending',null,null);
do $no_pending$ begin
 if (select count(*) from public.notifications)<>0 then
  raise exception 'PENDING_SCORE_LEAKED';end if;
end $no_pending$;

-- Invalid team status, unpublished and cancelled cups never announce scores.
update public.team_skills_scores set status='approved',
  approved_by='00000000-0000-0000-0000-000000000999',approved_at=now()
where id in (
 '00000000-0000-0000-0000-000000000402',
 '00000000-0000-0000-0000-000000000403',
 '00000000-0000-0000-0000-000000000404');
-- A status flag without a server-side approval receipt is insufficient.
update public.team_skills_scores set status='approved'
 where id='00000000-0000-0000-0000-000000000405';
do $no_false_approved$ begin
 if (select count(*) from public.notifications)<>0 then
  raise exception 'UNAPPROVED_OR_UNPUBLISHED_SCORE_LEAKED';end if;
end $no_false_approved$;

update public.team_skills_scores
set status='approved',approved_by='00000000-0000-0000-0000-000000000999',
    approved_at=now()
where id='00000000-0000-0000-0000-000000000401';
update public.team_skills_scores
set status='approved',approved_by='00000000-0000-0000-0000-000000000999',
    approved_at=now()
where id='00000000-0000-0000-0000-000000000406';
-- Reapproving after a correction and replaying status cannot duplicate.
update public.team_skills_scores set status='approved',computed_points=25
where id='00000000-0000-0000-0000-000000000401';
update public.team_skills_scores set status='rejected'
where id='00000000-0000-0000-0000-000000000401';
update public.team_skills_scores set status='approved',computed_points=25,
 approved_by='00000000-0000-0000-0000-000000000999',approved_at=now()
where id='00000000-0000-0000-0000-000000000401';
do $assert$
begin
 if (select count(*) from public.notifications)<>2
 or (select count(*) from public.notifications
   where user_id='00000000-0000-0000-0000-000000000301'
     and metadata->>'source'='team_skills_cup'
     and metadata->>'event'='phase_score_approved'
     and metadata->>'score_id'='00000000-0000-0000-0000-000000000401'
     and metadata->>'cup_id'='00000000-0000-0000-0000-000000000001'
     and metadata->>'registration_id'='00000000-0000-0000-0000-000000000101'
     and metadata->>'stage_no'='1'
     and body like '%20%')<>1
 or (select count(*) from public.notifications
    where user_id='00000000-0000-0000-0000-000000000305'
      and metadata->>'score_id'='00000000-0000-0000-0000-000000000406')<>1
 or exists (select 1 from public.notifications where user_id in (
      '00000000-0000-0000-0000-000000000302',
      '00000000-0000-0000-0000-000000000303',
      '00000000-0000-0000-0000-000000000304'))
 then raise exception 'SCORE_APPROVAL_NOTIFICATION_LEAK_OR_DUP';end if;
 if has_function_privilege('anon',
    'vsp_skills_private.notify_approved_phase_score()','EXECUTE')
 or has_function_privilege('authenticated',
    'vsp_skills_private.notify_approved_phase_score()','EXECUTE')
 then raise exception 'SCORE_NOTIFICATION_INTERNAL_RPC_EXPOSED';end if;
 if (select count(*) from pg_trigger
     where tgrelid='public.team_skills_scores'::regclass
     and tgname='team_skills_phase_approved_notify' and tgenabled='O')<>1
 then raise exception 'SCORE_APPROVAL_TRIGGER_NOT_ACTIVE';end if;
end $assert$;
