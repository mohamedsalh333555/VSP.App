create schema auth;
create function auth.role() returns text language sql stable as $$ select 'service_role'::text $$;
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
create table public.bookings(
 id uuid primary key,user_id uuid,created_by_user_id uuid,total_price numeric,
 status text default 'pending',is_paid boolean default false,payment_status text default 'unpaid',
 is_deposit_paid boolean default false,deposit_paid numeric default 0,
 gross_amount_charged numeric default 0,payment_transaction_id text,
 paymob_txn_id text,paymob_order_id text,paymob_transaction_id text,
 payment_method text,webhook_verified boolean default false,
 webhook_processed_at timestamptz,vsp_commission numeric default 0,
 gateway_fee numeric default 0,platform_fee numeric default 0,updated_at timestamptz
);
create table public.transactions(
 id uuid primary key default gen_random_uuid(),user_id uuid,booking_id uuid,
 amount numeric,gross_amount numeric,type text,status text,payment_method text,
 reference_number text,paymob_transaction_id text,description text,metadata jsonb,
 created_at timestamptz,updated_at timestamptz
);
create table public.platform_fee_config(id int primary key,
 booking_vsp_rate numeric,booking_paymob_wallet_rate numeric,
 booking_paymob_foreign_rate numeric,booking_paymob_local_rate numeric,
 booking_paymob_fixed_fee numeric);
insert into public.platform_fee_config values(1,0,0,0,0,0);
-- ACTUAL_STAGING_PAYMENT_LEDGER_RPC
insert into public.bookings(id,user_id,created_by_user_id,total_price) values
 ('00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000101',100),
 ('00000000-0000-0000-0000-000000001002',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000102',100);
do $assert$
declare first jsonb; replay jsonb; other jsonb; user_wrong jsonb; gross_wrong jsonb;
begin
 first:=public.record_booking_payment_atomic(
 '00000000-0000-0000-0000-000000001001',
 '00000000-0000-0000-0000-000000000101',
 '9911001','order-a','card',40,40,false,'{}'::jsonb);
 if first->>'success'<>'true' or first->>'idempotent'='true'
 or first->>'payment_status'<>'partially_paid'
 then raise exception 'PAYMOB_INITIAL_ACCOUNTING_FAILED: %',first;end if;
 if (select count(*) from public.transactions where
  booking_id='00000000-0000-0000-0000-000000001001'
  and paymob_transaction_id='9911001')<>1
 then raise exception 'FIRST_PAYMOB_TRANSACTION_NOT_RECORDED';end if;

 replay:=public.record_booking_payment_atomic(
 '00000000-0000-0000-0000-000000001001',
 '00000000-0000-0000-0000-000000000101',
 '9911001','order-a','card',40,40,false,'{}'::jsonb);
 if replay->>'success'<>'true' or replay->>'idempotent'<>'true'
 or (select count(*) from public.transactions)<>1
 then raise exception 'PAYMOB_IDEMPOTENT_REPLAY_FAILED: %',replay;end if;

 other:=public.record_booking_payment_atomic(
 '00000000-0000-0000-0000-000000001002',
 '00000000-0000-0000-0000-000000000102',
 '9911001','order-b','wallet',40,40,false,'{}'::jsonb);
 if other->>'success'<>'false'
  or other->>'error'<>'transaction_already_bound_to_other_booking'
  or (select count(*) from public.transactions)<>1
  or (select status from public.bookings where id='00000000-0000-0000-0000-000000001002')<>'pending'
 then raise exception 'PAYMOB_ID_REUSED_FOR_OTHER_BOOKING: %',other;end if;

 user_wrong:=public.record_booking_payment_atomic(
 '00000000-0000-0000-0000-000000001002',
 '00000000-0000-0000-0000-000000000101',
 '9911002','order-b','card',40,40,false,'{}'::jsonb);
 if user_wrong->>'error'<>'payment_user_mismatch'
 then raise exception 'PAYMOB_WRONG_USER_ACCEPTED: %',user_wrong;end if;

 gross_wrong:=public.record_booking_payment_atomic(
 '00000000-0000-0000-0000-000000001002',
 '00000000-0000-0000-0000-000000000102',
 '9911002','order-b','card',40,39,false,'{}'::jsonb);
 if gross_wrong->>'error'<>'gross_amount_mismatch'
 then raise exception 'PAYMOB_WRONG_GROSS_ACCEPTED: %',gross_wrong;end if;
 if (select count(*) from public.transactions)<>1
 then raise exception 'INVALID_PAYMENT_CHANGED_LEDGER';end if;
end $assert$;
