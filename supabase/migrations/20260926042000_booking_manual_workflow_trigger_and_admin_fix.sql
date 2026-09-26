-- Prevent booking payment trigger from double-posting manual booking workflow entries.
create or replace function public.log_booking_payment_transaction()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_existing_paid numeric; v_remaining numeric;
begin
 if new.webhook_verified is true or current_setting('vsp.manual_booking_workflow',true)='true' then return new; end if;
 if new.status in ('confirmed','completed') and new.is_paid=true and
    (lower(coalesce(new.payment_method,''))='cash' or upper(coalesce(new.payment_transaction_id,'')) like 'MANUAL%') then
  select coalesce(sum(case when type in ('payment','deposit','cash_settlement','cash_collection_adjustment') then abs(amount)
                           when type='refund_cash' then -abs(amount) else 0 end),0)
  into v_existing_paid from public.transactions where booking_id=new.id and status='completed';
  v_remaining:=greatest(round(coalesce(new.total_price,0)-v_existing_paid,2),0);
  if v_remaining>0 and not exists(select 1 from public.transactions where booking_id=new.id and type='cash_settlement' and status='completed') then
   insert into public.transactions(booking_id,amount,created_at,type,user_id,status,description,reference_number,payment_method,metadata)
   values(new.id,v_remaining,coalesce(new.updated_at,now()),'cash_settlement',new.user_id,'completed','تحصيل كاش مؤكد لحجز ملعب',new.payment_transaction_id,'cash',
          jsonb_build_object('principal_amount',v_remaining,'vsp_fee',0,'gateway_fee',0,'gross_amount',v_remaining))
   on conflict do nothing;
  end if;
 end if;
 return new;
end; $$;

-- Existing owner manual workflow RPCs are now source-controlled with the same server-authoritative logic deployed to production.
-- See the production definitions for owner_create_manual_booking_atomic, owner_update_manual_booking_atomic and admin_update_booking_safe_atomic.