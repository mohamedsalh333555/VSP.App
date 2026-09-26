-- Financial lifecycle coherence: cash settlement + payment source + refund states
alter table public.bookings drop constraint if exists bookings_payment_status_check;
alter table public.bookings add constraint bookings_payment_status_check
check (payment_status = any(array['pending','unpaid','paid','partially_paid','refunded','failed','refund_pending','refund_failed']));

alter table public.bookings drop constraint if exists bookings_payment_reconcile_state_check;
alter table public.bookings add constraint bookings_payment_reconcile_state_check
check (payment_reconcile_state = any(array['unpaid','partially_paid','fully_paid','refunded','refund_pending','refund_failed']));

create or replace function public.log_booking_payment_transaction()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_existing_paid numeric; v_remaining numeric;
begin
  if new.webhook_verified is true then return new; end if;
  if new.status in ('confirmed','completed') and new.is_paid=true
     and (lower(coalesce(new.payment_method,''))='cash' or upper(coalesce(new.payment_transaction_id,'')) like 'MANUAL%') then
    select coalesce(sum(case
      when type in ('payment','deposit','cash_settlement','cash_collection_adjustment') then abs(amount)
      when type='refund_cash' then -abs(amount) else 0 end),0)
    into v_existing_paid
    from public.transactions where booking_id=new.id and status='completed';
    v_remaining:=greatest(round(coalesce(new.total_price,0)-v_existing_paid,2),0);
    if v_remaining>0 and not exists(select 1 from public.transactions where booking_id=new.id and type='cash_settlement' and status='completed') then
      insert into public.transactions(booking_id,amount,created_at,type,user_id,status,description,reference_number,payment_method,metadata)
      values(new.id,v_remaining,coalesce(new.updated_at,now()),'cash_settlement',new.user_id,'completed',
        'تحصيل كاش مؤكد لحجز ملعب',new.payment_transaction_id,'cash',
        jsonb_build_object('principal_amount',v_remaining,'vsp_fee',0,'gateway_fee',0,'gross_amount',v_remaining))
      on conflict do nothing;
    end if;
  end if;
  if new.status='cancelled' and new.payment_status='refunded' and old.payment_status is distinct from 'refunded'
     and coalesce(new.refund_amount,0)>0 and not exists(
       select 1 from public.transactions where booking_id=new.id
       and type in ('refund','refund_card','refund_wallet','refund_cash','refund_pending')
       and status in ('pending','completed')) then
    insert into public.transactions(booking_id,amount,created_at,type,user_id,status,description,reference_number,payment_method)
    values(new.id,new.refund_amount,coalesce(new.refunded_at,now()),'refund',new.user_id,'completed',
      'استرداد مالي - إلغاء حجز',coalesce(new.refund_transaction_id,new.payment_reference),
      coalesce(new.refund_payment_method,new.payment_method))
    on conflict do nothing;
  end if;
  return new;
end; $$;

create or replace function public.sync_payment_reconcile_state()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if lower(coalesce(new.payment_method,''))='cash' or upper(coalesce(new.payment_transaction_id,'')) like 'MANUAL%' then
    new.payment_source:='cash';
  elsif lower(coalesce(new.payment_method,'')) in ('paymob','card','online','wallet','visa','mastercard','meeza') then
    new.payment_source:='paymob';
  elsif lower(coalesce(new.payment_method,''))='instapay' then
    new.payment_source:='instapay';
  elsif lower(coalesce(new.payment_method,''))='vodafone_cash' then
    new.payment_source:='vodafone_cash';
  end if;
  if new.payment_status='refunded' then new.payment_reconcile_state:='refunded';
  elsif new.payment_status='refund_pending' then new.payment_reconcile_state:='refund_pending';
  elsif new.payment_status='refund_failed' then new.payment_reconcile_state:='refund_failed';
  elsif new.is_paid=true or new.payment_status='paid' then new.payment_reconcile_state:='fully_paid';
  elsif coalesce(new.deposit_paid,0)>0 and new.deposit_paid<new.total_price then new.payment_reconcile_state:='partially_paid';
  else new.payment_reconcile_state:='unpaid'; end if;
  return new;
end; $$;

with cash_truth as (
 select b.id,b.user_id,b.total_price,greatest(round(b.total_price-coalesce(sum(case
   when t.type in ('payment','deposit','cash_settlement','cash_collection_adjustment') then abs(t.amount)
   when t.type='refund_cash' then -abs(t.amount) else 0 end),0),2),0) remaining
 from public.bookings b left join public.transactions t on t.booking_id=b.id and t.status='completed'
 where b.payment_method='cash' and b.is_paid=true and b.payment_status='paid'
 group by b.id,b.user_id,b.total_price)
insert into public.transactions(booking_id,user_id,amount,type,status,payment_method,description,reference_number,metadata)
select id,user_id,remaining,'cash_settlement','completed','cash',
 'تسوية دفترية تلقائية لحجز كاش مؤكد قبل توحيد دفتر التحصيل',
 'RECONCILE_CASH_'||id::text,
 jsonb_build_object('reconciliation','booking_paid_without_cash_settlement','source_total_price',total_price)
from cash_truth where remaining>0
and not exists(select 1 from public.transactions x where x.booking_id=cash_truth.id and x.type='cash_settlement' and x.status='completed')
on conflict do nothing;

update public.bookings set payment_source='cash' where payment_method='cash' and payment_source<>'cash';