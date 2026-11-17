-- Disposable PostgreSQL test of ACTUAL cancellation migration.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create table public.stadiums(id uuid primary key,owner_id uuid,name text);
create table public.bookings(
 id uuid primary key,stadium_id uuid,owner_id uuid,
 user_id uuid,created_by_user_id uuid,status text);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid,title text,body text,message text,type text,
 is_read boolean,created_at timestamptz,booking_id uuid,metadata jsonb);
-- ACTUAL_BOOKING_CANCELLATION_MIGRATION
insert into public.stadiums(id,owner_id,name)
values('00000000-0000-0000-0000-000000000001',
'00000000-0000-0000-0000-000000000101','ملعب النيل');
insert into public.bookings(
 id,stadium_id,owner_id,user_id,created_by_user_id,status)
values
 ('00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000999',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000998','confirmed'),
 ('00000000-0000-0000-0000-000000001002',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000999',
  '00000000-0000-0000-0000-000000000101',null,'pending'),
 ('00000000-0000-0000-0000-000000001003',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000999',
  '00000000-0000-0000-0000-000000000103',null,'pending'),
 ('00000000-0000-0000-0000-000000001004',
  '00000000-0000-0000-0000-000000000999',
  '00000000-0000-0000-0000-000000000998',
  '00000000-0000-0000-0000-000000000103',null,'confirmed'),
 ('00000000-0000-0000-0000-000000001005',
  '00000000-0000-0000-0000-000000000001',
  null,null,'00000000-0000-0000-0000-000000000998','confirmed');
-- No initial 'cancelled' events, no notices on unrelated status changes.
update public.bookings set status='expired'
where id='00000000-0000-0000-0000-000000001003';
do $before_cancel$ begin
 if exists(select 1 from public.notifications) then
  raise exception 'NON_CANCELLED_BOOKING_NOTICE_LEAK';end if;
end $before_cancel$;
update public.bookings set status='cancelled'
where id in ('00000000-0000-0000-0000-000000001001',
             '00000000-0000-0000-0000-000000001002',
             '00000000-0000-0000-0000-000000001004',
             '00000000-0000-0000-0000-000000001005');
-- Retry same status and simulate reentrant cancellation; no duplicate.
update public.bookings set status='cancelled'
where id='00000000-0000-0000-0000-000000001001';
update public.bookings set status='confirmed'
where id='00000000-0000-0000-0000-000000001001';
update public.bookings set status='cancelled'
where id='00000000-0000-0000-0000-000000001001';
do $verify$
begin
 if (select count(*) from public.notifications)<>4
 or (select count(*) from public.notifications
      where booking_id='00000000-0000-0000-0000-000000001001')<>2
 or (select count(*) from public.notifications
      where booking_id='00000000-0000-0000-0000-000000001001'
        and user_id='00000000-0000-0000-0000-000000000101'
        and metadata->>'event'='booking_cancelled'
        and metadata->>'recipient_role'='venue_owner')<>1
 or (select count(*) from public.notifications
      where booking_id='00000000-0000-0000-0000-000000001001'
        and user_id='00000000-0000-0000-0000-000000000102'
        and metadata->>'event'='booking_cancelled'
        and metadata->>'recipient_role'='booker')<>1
 or (select count(*) from public.notifications
      where booking_id='00000000-0000-0000-0000-000000001002')<>1
 or (select count(*) from public.notifications
      where booking_id='00000000-0000-0000-0000-000000001005')<>1
 or exists(select 1 from public.notifications
      where user_id in ('00000000-0000-0000-0000-000000000999',
                        '00000000-0000-0000-0000-000000000998',
                        '00000000-0000-0000-0000-000000000103'))
 or exists(select 1 from public.notifications
      where body like '%تم الاسترداد%' or body like '%تم الدفع%'
        or body like '%تم رد المبلغ%')
 then raise exception 'BOOKING_CANCELLATION_MESSAGE_LEAK_OR_DUP';end if;
 if has_function_privilege('anon',
    'vsp_notifications_private.notify_booking_cancelled()','EXECUTE')
 or has_function_privilege('authenticated',
    'vsp_notifications_private.notify_booking_cancelled()','EXECUTE')
 then raise exception 'BOOKING_CANCEL_TRIGGER_DIRECT_EXECUTE_EXPOSED';end if;
 if (select count(*) from pg_trigger where
       tgrelid='public.bookings'::regclass
       and tgname='trg_booking_cancelled_notify' and tgenabled='O')<>1
 then raise exception 'BOOKING_CANCEL_TRIGGER_NOT_ENABLED';end if;
end $verify$;
