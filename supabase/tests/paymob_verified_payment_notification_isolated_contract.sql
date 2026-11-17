-- Insert actual migration here. Fixture must not use remote PostgreSQL.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema vsp_notifications_private;
create table public.stadiums(id uuid primary key,owner_id uuid,name text);
create table public.bookings(
 id uuid primary key,stadium_id uuid,owner_id uuid,
 user_id uuid,created_by_user_id uuid,paymob_txn_id text,
 paymob_order_id text,status text,payment_method text,
 payment_reconcile_state text,payment_status text,webhook_verified boolean);
create table public.transactions(
 id uuid primary key,booking_id uuid,user_id uuid,amount numeric,
 gross_amount numeric,type text,status text,payment_method text,
 metadata jsonb,paymob_transaction_id text,created_at timestamptz default now());
create table public.webhook_logs(
 id uuid primary key default gen_random_uuid(),
 provider text,event_type text,signature_verified boolean,
 status text,booking_id uuid,txn_id text,order_id text,payload jsonb);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid,title text,
 body text,message text,type text,is_read boolean,
 created_at timestamptz,booking_id uuid,metadata jsonb);
-- ACTUAL_PAYMOB_NOTIFICATION_MIGRATION

insert into public.stadiums(id,owner_id,name) values
 ('00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101','ملعب النيل');
insert into public.bookings(
 id,stadium_id,owner_id,user_id,created_by_user_id,
 paymob_txn_id,paymob_order_id,status,payment_method,
 payment_reconcile_state,payment_status,webhook_verified)
values
 ('00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000999',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000998',
  null,null,'pending','card','unpaid','pending',false),
 ('00000000-0000-0000-0000-000000001002',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000101',
  null,null,'pending','wallet','unpaid','pending',false);

-- A mutable client payment flag, even with an existing complete ledger
-- row, must not create a success receipt without an HMAC-verified callback.
insert into public.transactions(
 id,booking_id,user_id,amount,gross_amount,type,status,
 payment_method,metadata,paymob_transaction_id)
values
 ('00000000-0000-0000-0000-000000002001',
  '00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000102',
  50,55,'deposit','completed','card',
  '{"paymob_order_id":"order1"}','12345'),
 ('00000000-0000-0000-0000-000000002002',
  '00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000102',
  100,110,'payment','completed','card',
  '{"paymob_order_id":"order2"}','12346');
update public.bookings set paymob_txn_id='12345',paymob_order_id='order1',
 status='confirmed',webhook_verified=true,
 payment_reconcile_state='partially_paid',payment_status='partially_paid'
 where id='00000000-0000-0000-0000-000000001001';
do $no_signature$ begin
 if exists(select 1 from public.notifications) then
  raise exception 'UNSIGNED_PAYMENT_NOTIFICATION_LEAKED';end if;
end $no_signature$;
-- Even a signed-looking event is not sufficient with false signature or
-- wrong gross amount, wrong booking or wrong order correlation.
insert into public.webhook_logs(
 provider,event_type,signature_verified,status,booking_id,
 txn_id,order_id,payload)
values
 ('paymob','transaction_response',false,'success',
 '00000000-0000-0000-0000-000000001001','12345','order1',
 '{"success":true,"pending":false,"amount_cents":5500}'),
 ('paymob','transaction_response',true,'success',
 '00000000-0000-0000-0000-000000001001','12345','order1',
 '{"success":true,"pending":false,"amount_cents":5000}'),
 ('paymob','transaction_response',true,'success',
 '00000000-0000-0000-0000-000000001002','12345','order1',
 '{"success":true,"pending":false,"amount_cents":5500}'),
 ('paymob','transaction_response',true,'failed',
 '00000000-0000-0000-0000-000000001001','12345','order1',
 '{"success":false,"pending":false,"amount_cents":5500}');
update public.bookings set paymob_txn_id=null
where id='00000000-0000-0000-0000-000000001001';
update public.bookings set paymob_txn_id='12345'
where id='00000000-0000-0000-0000-000000001001';
do $negative_webhook$ begin
 if exists(select 1 from public.notifications) then
  raise exception 'FORGED_OR_WRONG_AMOUNT_WEBHOOK_CREATED_PAYMENT_RECEIPT';end if;
end $negative_webhook$;
-- Only this HMAC-successful, correct amount/booking/order/txn event
-- authorizes one receipt per actual owner + real booking user.
insert into public.webhook_logs(
 provider,event_type,signature_verified,status,booking_id,
 txn_id,order_id,payload)
values('paymob','transaction_response',true,'success',
 '00000000-0000-0000-0000-000000001001','12345','order1',
 '{"success":true,"pending":false,"amount_cents":5500}');
update public.bookings set paymob_txn_id=null
where id='00000000-0000-0000-0000-000000001001';
update public.bookings set paymob_txn_id='12345'
where id='00000000-0000-0000-0000-000000001001';
-- Two more attempts (same receipt); index guarantees one logical notice.
update public.bookings set paymob_txn_id=null
where id='00000000-0000-0000-0000-000000001001';
update public.bookings set paymob_txn_id='12345'
where id='00000000-0000-0000-0000-000000001001';
do $first_verified$
begin
 if (select count(*) from public.notifications)<>2
 or (select count(*) from public.notifications
   where user_id='00000000-0000-0000-0000-000000000101'
     and booking_id='00000000-0000-0000-0000-000000001001'
     and metadata->>'payment_transaction_id'='00000000-0000-0000-0000-000000002001'
     and metadata->>'receipt_kind'='partial')<>1
 or (select count(*) from public.notifications
   where user_id='00000000-0000-0000-0000-000000000102'
     and metadata->>'event'='paymob_payment_confirmed')<>1
 or exists(select 1 from public.notifications
      where user_id in('00000000-0000-0000-0000-000000000998',
                       '00000000-0000-0000-0000-000000000999'))
 then raise exception 'PAYMOB_RECEIPT_WRONG_RECIPIENT_OR_DUPLICATED';end if;
end $first_verified$;
-- A second verified final payment on the same booking is distinct and
-- gets a new notice; the initial deposit is not reannounced.
insert into public.webhook_logs(
 provider,event_type,signature_verified,status,booking_id,
 txn_id,order_id,payload)
values('paymob','transaction_response',true,'success',
 '00000000-0000-0000-0000-000000001001','12346','order2',
 '{"success":true,"pending":false,"amount_cents":11000}');
update public.bookings set paymob_txn_id='12346',paymob_order_id='order2',
 payment_reconcile_state='fully_paid',payment_status='paid'
 where id='00000000-0000-0000-0000-000000001001';
do $second_verified$
begin
 if (select count(*) from public.notifications)<>4
 or (select count(*) from public.notifications
    where metadata->>'payment_transaction_id'='00000000-0000-0000-0000-000000002002'
      and metadata->>'receipt_kind'='complete')<>2
 then raise exception 'SECOND_PAYMENT_NOT_DISTINCT_OR_DUPLICATED';end if;
end $second_verified$;
-- Owner=booker is only one recipient, not two.
insert into public.transactions(
 id,booking_id,user_id,amount,gross_amount,type,status,
 payment_method,metadata,paymob_transaction_id)
values('00000000-0000-0000-0000-000000002003',
 '00000000-0000-0000-0000-000000001002',
 '00000000-0000-0000-0000-000000000101',
 30,34,'payment','completed','wallet',
 '{"paymob_order_id":"order3"}','12347');
insert into public.webhook_logs(
 provider,event_type,signature_verified,status,booking_id,
 txn_id,order_id,payload)
values('paymob','transaction_response',true,'success',
 '00000000-0000-0000-0000-000000001002','12347','order3',
 '{"success":true,"pending":false,"amount_cents":3400}');
update public.bookings set paymob_txn_id='12347',paymob_order_id='order3',
 webhook_verified=true,status='confirmed',
 payment_reconcile_state='fully_paid',payment_status='paid'
 where id='00000000-0000-0000-0000-000000001002';
do $same_recipient$
begin
 if (select count(*) from public.notifications where
   booking_id='00000000-0000-0000-0000-000000001002')<>1
 or (select count(*) from public.notifications)<>5
 then raise exception 'SELF_OWNED_BOOKING_PAYMENT_SENT_TWICE';end if;
 if has_function_privilege('anon',
     'vsp_notifications_private.notify_verified_paymob_payment()','EXECUTE')
 or has_function_privilege('authenticated',
     'vsp_notifications_private.notify_verified_paymob_payment()','EXECUTE')
 then raise exception 'PAYMOB_RECEIPT_RPC_PUBLICLY_EXECUTABLE';end if;
 if (select count(*) from pg_trigger where
     tgrelid='public.bookings'::regclass
       and tgname='trg_booking_verified_paymob_notice' and tgenabled='O')<>1
 then raise exception 'PAYMOB_RECEIPT_TRIGGER_MISSING';end if;
end $same_recipient$;
