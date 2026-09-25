-- Booking lifecycle scheduler hardening -- 2026-09-26
create or replace function public.cancel_expired_pending_bookings()
returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $f$
declare v_cancelled_count int; v_now timestamptz:=now();
begin
 with cancelled as (
  update public.bookings set status='cancelled',
    cancellation_reason='auto_expired_pending_payment',cancelled_at=v_now,updated_at=v_now
  where status='pending' and payment_method in ('paymob','card','wallet','online')
    and is_paid=false
    and coalesce(locked_until,created_at+interval '8 minutes')<v_now
  returning id
 ) select count(*) into v_cancelled_count from cancelled;
 return jsonb_build_object('success',true,'cancelled_count',v_cancelled_count,'ran_at',v_now);
end;
$f$;
revoke execute on function public.cancel_expired_pending_bookings() from public,anon,authenticated;
create or replace function public.auto_reconcile_all_past_bookings()
returns void language plpgsql security definer set search_path=public,pg_temp
as $f$
begin
 update public.bookings set status='completed',updated_at=now()
 where end_time<now() and status='confirmed'
   and coalesce(booking_type,'personal') not in ('challenge','matchup','team');
end;
$f$;
revoke execute on function public.auto_reconcile_all_past_bookings() from public,anon,authenticated;