-- Exercise ACTUAL latest staging function body on disposable PostgreSQL.
create table public.bookings(
 id integer primary key,status text default 'pending',
 payment_method text,payment_transaction_id text,payment_source text,
 payment_status text default 'pending',payment_reconcile_state text,
 is_paid boolean default false,deposit_paid numeric default 0,total_price numeric default 100);
-- ACTUAL_ARABIC_PAYMENT_NORMALIZATION_MIGRATION
create trigger trigger_sync_payment_reconcile before insert or update on public.bookings
for each row execute function public.sync_payment_reconcile_state();

-- Pending electronic wallets may exist, but cannot be confirmed without
-- recorded payment state. Confirmed cash on arrival remains permitted.
insert into public.bookings(id,status,payment_method,payment_status) values
 (1,'confirmed','كاش عند الملعب','pending'),
 (2,'confirmed','Cash','pending'),
 (3,'pending','فودافون كاش','pending'),
 (4,'pending','vodafone_cash','pending'),
 (5,'pending','InstaPay','pending'),
 (6,'pending','تحويل بنكي','pending'),
 (7,'pending','Meeza','pending'),
 (8,'pending','بطاقة','pending'),
 (9,'pending','wallet','pending'),
 (10,'pending','Visa','pending'),
 (11,'pending','فودافون كاش','pending'),
 (12,'confirmed','دفع نقدي','pending'),
 (13,'pending','unrecognized','pending');

do $classification$
begin
 if (select payment_source from public.bookings where id=1)<>'cash'
 or (select payment_source from public.bookings where id=2)<>'cash'
 or (select payment_source from public.bookings where id=3)<>'vodafone_cash'
 or (select payment_source from public.bookings where id=4)<>'vodafone_cash'
 or (select payment_source from public.bookings where id=5)<>'instapay'
 or (select payment_source from public.bookings where id=6)<>'bank_transfer'
 or (select payment_source from public.bookings where id=7)<>'paymob'
 or (select payment_source from public.bookings where id=8)<>'paymob'
 or (select payment_source from public.bookings where id=9)<>'paymob'
 or (select payment_source from public.bookings where id=10)<>'paymob'
 or (select payment_source from public.bookings where id=13)<>'unknown'
 then raise exception 'ARABIC_PAYMENT_SOURCE_WRONGLY_CLASSIFIED';end if;
end $classification$;
-- Attempt transition without paid ledger: all known digital channels deny it.
do $reject_unpaid$
declare i int; denied boolean;
begin
 for i in 3..10 loop
 denied:=false;
 begin
 update public.bookings set status='confirmed' where id=i;
 exception when sqlstate 'P0005' then denied:=true;
 end;
 if not denied or (select status from public.bookings where id=i)<>'pending'
 then raise exception 'DIGITAL_BOOKING_CONFIRMED_UNPAID: %',i;end if;
 end loop;
end $reject_unpaid$;
-- A legacy venue-cash confirmed record cannot silently turn into a wallet
-- while retaining its "confirmed" status and "unpaid" reconcile state.
do $method_swap$
declare denied boolean:=false;
begin
 begin
 update public.bookings set payment_method='فودافون كاش' where id=1;
 exception when sqlstate 'P0005' then denied:=true;
 end;
 if not denied or
    (select payment_source from public.bookings where id=1)<>'cash'
 then raise exception 'LEGACY_CASH_TO_WALLET_BYPASSED_PAYMENT_MATRIX';end if;
end $method_swap$;
-- Paid electronic bookings become eligible for confirmed state without
-- overwriting refund state or misallocating source to cash.
update public.bookings set status='confirmed',payment_status='paid',
 is_paid=true where id in(3,4,5,6,7,8,9,10);
update public.bookings set status='confirmed',payment_status='partially_paid',
 deposit_paid=20 where id=11;
do $paid$
begin
 if (select count(*) from public.bookings
      where id between 3 and 10 and status='confirmed'
        and payment_reconcile_state='fully_paid')<>8
 or (select payment_reconcile_state from public.bookings where id=11)<>'partially_paid'
 or (select count(*) from public.bookings
      where id between 3 and 11 and payment_source='cash')<>0
 then raise exception 'APPROVED_ELECTRONIC_PAYMENT_RECONCILE_INVALID';end if;
end $paid$;
-- A payment/refund status cannot become paid merely by retaining an
-- irrelevant legacy payment source.
insert into public.bookings(id,status,payment_method,payment_status)
values (14,'pending','cash','refund_pending');
do $refund$ begin
 if (select payment_reconcile_state from public.bookings where id=14)<>'refund_pending'
 then raise exception 'REFUND_PRECEDENCE_REGRESSED';end if;
end $refund$;
