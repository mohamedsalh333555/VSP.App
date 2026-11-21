-- Test the actual advancement trigger against isolated PostgreSQL.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema vsp_skills_private;
create table public.team_skills_cups(id uuid primary key,status text);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid,team_id uuid,captain_id uuid,status text);
create table public.team_skills_knockout(
 id uuid primary key,cup_id uuid,round_no integer,match_no integer,
 first_registration_id uuid,second_registration_id uuid,
 winner_registration_id uuid,status text);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid,
 title text,body text,message text,type text,metadata jsonb);
-- ACTUAL_KNOCKOUT_ADVANCEMENT_NOTICE

insert into public.team_skills_cups(id,status) values
 ('00000000-0000-0000-0000-000000000001','live'),
 ('00000000-0000-0000-0000-000000000002','cancelled'),
 ('00000000-0000-0000-0000-000000000003','draft');
insert into public.team_skills_registrations(id,cup_id,team_id,captain_id,status) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000301','approved'),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000302','approved'),
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000303','approved'),
 ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000304','approved'),
 ('00000000-0000-0000-0000-000000000105','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000205','00000000-0000-0000-0000-000000000305','approved');
insert into public.team_skills_knockout(
 id,cup_id,round_no,match_no,first_registration_id,
 second_registration_id,winner_registration_id,status) values
 ('00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000001',1,1,
  '00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000103',
  '00000000-0000-0000-0000-000000000101','approved'),
 ('00000000-0000-0000-0000-000000000402','00000000-0000-0000-0000-000000000001',1,2,
  '00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000103',
  '00000000-0000-0000-0000-000000000102','approved'),
 ('00000000-0000-0000-0000-000000000403','00000000-0000-0000-0000-000000000001',2,1,
  null,null,null,'scheduled'),
 ('00000000-0000-0000-0000-000000000404','00000000-0000-0000-0000-000000000002',1,1,
  '00000000-0000-0000-0000-000000000104',null,
  '00000000-0000-0000-0000-000000000104','approved'),
 ('00000000-0000-0000-0000-000000000405','00000000-0000-0000-0000-000000000002',2,1,
  null,null,null,'scheduled'),
 ('00000000-0000-0000-0000-000000000406','00000000-0000-0000-0000-000000000003',1,1,
  '00000000-0000-0000-0000-000000000105',null,
  '00000000-0000-0000-0000-000000000105','approved'),
 ('00000000-0000-0000-0000-000000000407','00000000-0000-0000-0000-000000000003',2,1,
  null,null,null,'scheduled');
-- No announcement for a scheduled match just because a first-round bracket exists.
do $before_ready$ begin
 if exists(select 1 from public.notifications) then
  raise exception 'ANNOUNCED_KNOCKOUT_BEFORE_WIN';end if;
end $before_ready$;
update public.team_skills_knockout set first_registration_id=
 '00000000-0000-0000-0000-000000000101'
where id='00000000-0000-0000-0000-000000000403';
update public.team_skills_knockout set second_registration_id=
 '00000000-0000-0000-0000-000000000102'
where id='00000000-0000-0000-0000-000000000403';
-- Re-saving same slots must never resend winner notification.
update public.team_skills_knockout
set first_registration_id='00000000-0000-0000-0000-000000000101'
where id='00000000-0000-0000-0000-000000000403';
-- Attempt to put a losing team in a new round must never notify it.
update public.team_skills_knockout
set second_registration_id='00000000-0000-0000-0000-000000000103'
where id='00000000-0000-0000-0000-000000000403';
-- Cancelled/draft events cannot notify even if a previous match was approved.
update public.team_skills_knockout
set first_registration_id='00000000-0000-0000-0000-000000000104'
where id='00000000-0000-0000-0000-000000000405';
update public.team_skills_knockout
set first_registration_id='00000000-0000-0000-0000-000000000105'
where id='00000000-0000-0000-0000-000000000407';
do $assert$
begin
 if (select count(*) from public.notifications)<>2
 or (select count(*) from public.notifications where user_id=
   '00000000-0000-0000-0000-000000000301'
   and metadata->>'event'='knockout_advancement'
   and metadata->>'match_id'='00000000-0000-0000-0000-000000000401'
   and metadata->>'next_round'='2'
   and metadata->>'cup_id'='00000000-0000-0000-0000-000000000001')<>1
 or (select count(*) from public.notifications where user_id=
   '00000000-0000-0000-0000-000000000302'
   and metadata->>'event'='knockout_advancement'
   and metadata->>'match_id'='00000000-0000-0000-0000-000000000402')<>1
 or exists(select 1 from public.notifications where user_id in (
   '00000000-0000-0000-0000-000000000303',
   '00000000-0000-0000-0000-000000000304',
   '00000000-0000-0000-0000-000000000305'))
 then raise exception 'UNVERIFIED_KNOCKOUT_ADVANCEMENT_NOTICE';end if;
 if has_function_privilege('anon',
    'vsp_skills_private.notify_knockout_advancement()','EXECUTE')
 or has_function_privilege('authenticated',
    'vsp_skills_private.notify_knockout_advancement()','EXECUTE')
 then raise exception 'ADVANCEMENT_NOTIFY_DIRECT_EXECUTE_EXPOSED';end if;
 if (select count(*) from pg_trigger where
      tgrelid='public.team_skills_knockout'::regclass
      and tgname='team_skills_knockout_advancement_notify' and tgenabled='O')<>1
 then raise exception 'ADVANCEMENT_NOTIFY_TRIGGER_MISSING';end if;
end $assert$;
