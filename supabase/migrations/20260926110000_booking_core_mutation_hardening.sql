-- Booking core-field mutation hardening -- 2026-09-26
create or replace function public.protect_booking_sensitive_fields()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $function$
declare v_is_admin boolean:=false;
begin
  if coalesce(auth.role(),'')='service_role'
     or (auth.uid() is null and session_user in ('postgres','supabase_admin')) then return new; end if;
  if current_setting('vsp.system_override',true)='true'
     or current_setting('vsp.internal_payment_call',true)='true' then return new; end if;

  if auth.uid() is not null then
    select role in ('admin','co_founder','cofounder','super_admin') into v_is_admin
    from public.users where id=auth.uid();
  end if;
  if coalesce(v_is_admin,false) then return new; end if;

  if old.stadium_id is distinct from new.stadium_id
     or old.owner_id is distinct from new.owner_id
     or old.user_id is distinct from new.user_id
     or old.created_by_user_id is distinct from new.created_by_user_id
     or old.start_time is distinct from new.start_time
     or old.end_time is distinct from new.end_time
     or old.booking_type is distinct from new.booking_type then
    raise exception 'PERMISSION_DENIED: Booking core identity and schedule are server-authoritative.'
      using errcode='42501',detail='UNAUTHORIZED_BOOKING_CORE_UPDATE';
  end if;

  if old.status is distinct from new.status then
    raise exception 'PERMISSION_DENIED: Booking status changes must use the official atomic workflow.'
      using errcode='42501',detail='UNAUTHORIZED_BOOKING_STATUS_UPDATE';
  end if;

  if old.payment_status is distinct from new.payment_status
     or old.is_paid is distinct from new.is_paid
     or old.is_deposit_paid is distinct from new.is_deposit_paid
     or old.deposit_paid is distinct from new.deposit_paid
     or old.deposit_amount is distinct from new.deposit_amount
     or old.payment_method is distinct from new.payment_method
     or old.payment_transaction_id is distinct from new.payment_transaction_id
     or old.paymob_txn_id is distinct from new.paymob_txn_id
     or old.paymob_order_id is distinct from new.paymob_order_id
     or old.paymob_transaction_id is distinct from new.paymob_transaction_id
     or old.webhook_verified is distinct from new.webhook_verified
     or old.webhook_processed_at is distinct from new.webhook_processed_at then
    raise exception 'PERMISSION_DENIED: Payment state can only be changed by payment workflows.'
      using errcode='42501',detail='UNAUTHORIZED_PAYMENT_STATE_UPDATE';
  end if;

  if old.total_price is distinct from new.total_price
     or old.platform_fee is distinct from new.platform_fee
     or old.vsp_commission is distinct from new.vsp_commission
     or old.gateway_fee is distinct from new.gateway_fee
     or old.refund_amount is distinct from new.refund_amount
     or old.refund_transaction_id is distinct from new.refund_transaction_id
     or old.refunded_at is distinct from new.refunded_at
     or old.refund_payment_method is distinct from new.refund_payment_method then
    raise exception 'PERMISSION_DENIED: Financial booking fields are immutable from the client.'
      using errcode='42501',detail='UNAUTHORIZED_FINANCIAL_UPDATE';
  end if;

  if old.cancelled_at is distinct from new.cancelled_at
     or old.cancellation_reason is distinct from new.cancellation_reason then
    raise exception 'PERMISSION_DENIED: Cancellation records are server-authoritative.'
      using errcode='42501',detail='UNAUTHORIZED_CANCELLATION_UPDATE';
  end if;

  return new;
end;
$function$;
drop trigger if exists trg_protect_booking_sensitive_fields on public.bookings;
create trigger trg_protect_booking_sensitive_fields
before update on public.bookings for each row
execute function public.protect_booking_sensitive_fields();
