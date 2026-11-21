-- Disposable SQL fixture for team-registration transactional notifications.
create schema vsp_skills_private;
create table public.team_skills_registrations(
 id uuid primary key, cup_id uuid not null,
 team_id uuid not null,captain_id uuid not null,status text not null);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid not null,
 title text not null,body text not null,message text,
 type text not null,metadata jsonb,created_at timestamptz default now());
-- TEAM_SKILLS_NOTIFY_MIGRATION
-- TEAM_SKILLS_INITIAL_RECEIPT_MIGRATION

insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status)
values
('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000301','pending'),
('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000302','pending'),
('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000303','pending'),
('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000304','waitlist'),
('00000000-0000-0000-0000-000000000105','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000205','00000000-0000-0000-0000-000000000305','approved');

do $receipt$
declare n integer;pending_n integer;wait_n integer;approved_n integer;valid_n integer;
begin
 select count(*),
   count(*) filter(where n.metadata->>'status'='pending'),
   count(*) filter(where n.metadata->>'status'='waitlist'),
   count(*) filter(where n.metadata->>'status'='approved'),
   count(*) filter(where n.user_id=r.captain_id
     and n.metadata->>'registration_id'=r.id::text
     and n.metadata->>'cup_id'=r.cup_id::text)
 into n,pending_n,wait_n,approved_n,valid_n
 from public.notifications n
 join public.team_skills_registrations r
   on r.id::text=n.metadata->>'registration_id'
 where n.metadata->>'event'='registration_submitted';
 if n<>4 or pending_n<>3 or wait_n<>1 or approved_n<>0 or valid_n<>4 then
   raise exception 'INITIAL_CAPTAIN_RECEIPTS_INVALID: total %, pending %, waitlisted %, approved %, verified %',
     n,pending_n,wait_n,approved_n,valid_n;
 end if;
end $receipt$;

update public.team_skills_registrations set status='approved'
 where id='00000000-0000-0000-0000-000000000101';
update public.team_skills_registrations set status='approved'
 where id='00000000-0000-0000-0000-000000000101';
update public.team_skills_registrations set status='rejected'
 where id='00000000-0000-0000-0000-000000000102';
update public.team_skills_registrations set status='waitlist'
 where id='00000000-0000-0000-0000-000000000103';
do $assert$
declare total integer;uniq integer;correct integer;
begin
 select count(*), count(distinct n.metadata->>'registration_id'),
   count(*) filter (where n.user_id=r.captain_id and
       n.metadata->>'status'=r.status and
       n.metadata->>'cup_id'=r.cup_id::text)
 into total,uniq,correct
 from public.notifications n
 join public.team_skills_registrations r on r.id::text=n.metadata->>'registration_id'
 where n.metadata->>'event'='registration_review'
   and n.metadata->>'source'='team_skills_cup';
 if total<>3 or uniq<>3 or correct<>3 then
  raise exception 'BAD_TEAM_STATUS_NOTIFICATIONS: total %, unique %, scoped %',total,uniq,correct;
 end if;
end $assert$;

-- One more cup and captain. A receipt is written only on INSERT, and
-- a review notice only on a genuine state transition for that registration.
insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status)
values(
 '00000000-0000-0000-0000-000000000106',
 '00000000-0000-0000-0000-000000000002',
 '00000000-0000-0000-0000-000000000206',
 '00000000-0000-0000-0000-000000000306','waitlist');
do $second_cup_receipt$
declare found_receipt integer;
begin
 select count(*) into found_receipt from public.notifications n
 where n.user_id='00000000-0000-0000-0000-000000000306'
   and n.metadata->>'source'='team_skills_cup'
   and n.metadata->>'event'='registration_submitted'
   and n.metadata->>'status'='waitlist'
   and n.metadata->>'cup_id'='00000000-0000-0000-0000-000000000002'
   and n.metadata->>'team_id'='00000000-0000-0000-0000-000000000206'
   and n.metadata->>'registration_id'='00000000-0000-0000-0000-000000000106';
 if found_receipt<>1 or (select count(*) from public.notifications
   where user_id='00000000-0000-0000-0000-000000000306')<>1
 then raise exception 'CROSS_CUP_RECEIPT_MISROUTED';end if;
end $second_cup_receipt$;

update public.team_skills_registrations set status='approved'
where id='00000000-0000-0000-0000-000000000106';
update public.team_skills_registrations set status='approved'
where id='00000000-0000-0000-0000-000000000106';
do $review_after_real_status_change$
begin
 if (select count(*) from public.notifications n
   where n.user_id='00000000-0000-0000-0000-000000000306'
     and n.metadata->>'event'='registration_review'
     and n.metadata->>'status'='approved'
     and n.metadata->>'registration_id'='00000000-0000-0000-0000-000000000106'
     and n.metadata->>'cup_id'='00000000-0000-0000-0000-000000000002')<>1
 then raise exception 'REVIEW_NOT_TRIGGERED_ONCE';end if;
 if (select count(*) from public.notifications n
     where n.user_id='00000000-0000-0000-0000-000000000306')<>2
 or exists(select 1 from public.notifications n
     where n.metadata->>'registration_id'='00000000-0000-0000-0000-000000000106'
       and n.user_id<>'00000000-0000-0000-0000-000000000306')
 then raise exception 'REVIEW_DUPLICATED_OR_LEAKED_TO_WRONG_CAPTAIN';end if;
 if (select count(*) from public.notifications n
     where n.metadata->>'registration_id'='00000000-0000-0000-0000-000000000101'
       and n.user_id<>'00000000-0000-0000-0000-000000000301')<>0
 then raise exception 'PREVIOUS_CUP_REVIEW_LEAKED';end if;
 if exists(select 1 from public.notifications n
     where n.metadata->>'event'='registration_submitted'
       and n.metadata->>'status'='approved')
 then raise exception 'APPROVED_ROW_RECEIVED_FALSE_INITIAL_NOTICE';end if;
end $review_after_real_status_change$;

-- These triggers are internal, not callable public RPCs.
do $triggers_not_public$
begin
 if has_function_privilege('anon',
    'vsp_skills_private.notify_team_skills_registration_status()','EXECUTE')
 or has_function_privilege('authenticated',
    'vsp_skills_private.notify_team_skills_registration_status()','EXECUTE')
 or has_function_privilege('anon',
    'vsp_skills_private.notify_team_skills_registration_receipt()','EXECUTE')
 or has_function_privilege('authenticated',
    'vsp_skills_private.notify_team_skills_registration_receipt()','EXECUTE')
 then raise exception 'NOTIFICATION_TRIGGER_EXPOSED_AS_RPC';end if;
end $triggers_not_public$;
