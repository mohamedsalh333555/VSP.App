-- Disposable-only physical hospitality/check-in fixture.
create schema auth;
create schema vsp_skills_private;
create function auth.uid() returns uuid language sql stable set search_path=''
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function vsp_skills_private.is_admin() returns boolean language sql stable set search_path=''
as $$ select auth.uid()='00000000-0000-0000-0000-000000009001'::uuid $$;
create table public.team_skills_cups(
 id uuid primary key,status text not null,hospitality_fee numeric not null);
create table public.team_skills_registrations(
 id uuid primary key,cup_id uuid not null,status text not null,
 hospitality_payment_status text not null default 'unpaid',checked_in_at timestamptz);
create table public.team_skills_audit(
 cup_id uuid,actor_id uuid,action text,subject_id uuid,details jsonb);
-- CHECKIN_AND_RECEIPT_REAL_FUNCTIONS

insert into public.team_skills_cups(id,status,hospitality_fee) values
 ('00000000-0000-0000-0000-000000000001','registration',50),
 ('00000000-0000-0000-0000-000000000002','registration',0),
 ('00000000-0000-0000-0000-000000000003','cancelled',50);
insert into public.team_skills_registrations(id,cup_id,status) values
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','approved'),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','approved'),
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000002','approved'),
 ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000003','approved');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
do $unpaid$
declare blocked boolean:=false;
begin
 begin
  perform public.team_skills_check_in('00000000-0000-0000-0000-000000000101');
 exception when others then
  if position('before check-in' in sqlerrm)>0 then blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'UNPAID_HOSPITALITY_ACCEPTED_AT_ENTRY';end if;
end $unpaid$;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009002',false);
do $nonadmin$
declare blocked boolean:=false;
begin
 begin perform public.team_skills_confirm_hospitality(
   '00000000-0000-0000-0000-000000000101',false,null);
 exception when others then
  if position('Not authorized' in sqlerrm)>0 then blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'NONADMIN_CONFIRMED_CASH';end if;
end $nonadmin$;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',false);
select public.team_skills_confirm_hospitality(
 '00000000-0000-0000-0000-000000000101',false,null);
select public.team_skills_check_in('00000000-0000-0000-0000-000000000101');
select public.team_skills_check_in('00000000-0000-0000-0000-000000000101');
do $waiver_reason$
declare blocked boolean:=false;
begin
 begin perform public.team_skills_confirm_hospitality(
   '00000000-0000-0000-0000-000000000102',true,'short');
 exception when others then
  if position('Waiver reason required' in sqlerrm)>0 then blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'UNEXPLAINED_WAIVER_ACCEPTED';end if;
end $waiver_reason$;
select public.team_skills_confirm_hospitality(
 '00000000-0000-0000-0000-000000000102',true,'Documented approved exception');
select public.team_skills_check_in('00000000-0000-0000-0000-000000000102');
-- Zero hospitality cost is explicitly allowed without an invented payment.
select public.team_skills_check_in('00000000-0000-0000-0000-000000000103');
do $cancelled$
declare blocked boolean:=false;
begin
 begin perform public.team_skills_check_in('00000000-0000-0000-0000-000000000104');
 exception when others then
  if position('Check-in unavailable' in sqlerrm)>0 then blocked:=true;else raise;end if;
 end;
 if not blocked then raise exception 'CANCELLED_CUP_CHECKED_IN';end if;
end $cancelled$;
do $audit$
begin
 if (select count(*) from public.team_skills_registrations where checked_in_at is not null)<>3
 or (select count(*) from public.team_skills_audit where action='check_in')<>3
 or (select count(*) from public.team_skills_audit where action='hospitality_recorded')<>2
 then raise exception 'CASH_ATTENDANCE_AUDIT_INCONSISTENT';end if;
 if (select hospitality_payment_status from public.team_skills_registrations
  where id='00000000-0000-0000-0000-000000000101')<>'verified' then
  raise exception 'CASH_RECEIPT_NOT_RECORDED';end if;
 if (select hospitality_payment_status from public.team_skills_registrations
  where id='00000000-0000-0000-0000-000000000102')<>'waived' then
  raise exception 'DOCUMENTED_WAIVER_NOT_RECORDED';end if;
 if (select hospitality_payment_status from public.team_skills_registrations
  where id='00000000-0000-0000-0000-000000000103')<>'unpaid' then
  raise exception 'ZERO_FEE_TEAM_CHARGED';end if;
end $audit$;
