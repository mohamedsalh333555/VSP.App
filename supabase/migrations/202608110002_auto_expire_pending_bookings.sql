-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110002: AUTO-EXPIRE PENDING BOOKINGS VIA PG_CRON
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.auto_expire_pending_bookings_5m()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to 5-minute payment timeout]'
  WHERE 
    status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND created_at <= NOW() - INTERVAL '5 minutes';
END;
$$;

-- Schedule job to run every minute
SELECT cron.schedule(
  'expire-pending-bookings-5m',
  '* * * * *',
  $$ SELECT public.auto_expire_pending_bookings_5m(); $$
);
