-- Refuse client-forged financial and official competition receipts even when
-- the sender is permitted to insert generic notifications for themselves.
-- Restrictive RLS combines with ALL existing permissive INSERT policies.
-- Server-side trusted trigger functions run as postgres and bypass RLS.
drop policy if exists notifications_reserved_events_server_only on public.notifications;
create policy notifications_reserved_events_server_only
on public.notifications
as restrictive for insert to authenticated
with check (
  public.is_admin_or_cofounder((select auth.uid()))
  or (
    lower(coalesce(type,'')) not in (
      'payment_received','deposit_received','booking_confirmed',
      'refund_success','refund_pending'
    )
    and not (
      coalesce(metadata->>'source','')='booking'
      and coalesce(metadata->>'event','') in (
        'cash_booking_confirmed','cash_challenge_confirmed',
        'booking_cancelled','paymob_payment_confirmed'
      )
    )
    and coalesce(metadata->>'source','')<>'team_skills_cup'
  )
);
