-- =========================================================
-- Phase 5: Transaction-Safe Booking Engine
-- Idempotency Key + Auto-Cancel Expired Pending Bookings
-- =========================================================

-- 1. Add idempotency_key column to bookings
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

-- 2. Create unique index to prevent duplicate bookings (double tap / retry)
CREATE UNIQUE INDEX IF NOT EXISTS uq_booking_idempotency
  ON public.bookings (idempotency_key)
  WHERE idempotency_key IS NOT NULL AND status != 'cancelled';

CREATE INDEX IF NOT EXISTS idx_bookings_idempotency
  ON public.bookings (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 3. Create auto-cancel function for expired pending bookings
CREATE OR REPLACE FUNCTION public.cancel_expired_pending_bookings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_cancelled_count INT;
    v_now TIMESTAMPTZ := now();
BEGIN
    WITH cancelled AS (
        UPDATE public.bookings
        SET
            status = 'cancelled',
            cancellation_reason = 'auto_expired_pending_payment',
            cancelled_at = v_now,
            updated_at = v_now
        WHERE
            status = 'pending'
            AND payment_method IN ('paymob', 'card', 'wallet', 'online')
            AND is_paid = FALSE
            AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now
        RETURNING id
    )
    SELECT COUNT(*) INTO v_cancelled_count FROM cancelled;

    RETURN jsonb_build_object(
        'success', true,
        'cancelled_count', v_cancelled_count,
        'ran_at', v_now
    );
END;
$$;

-- 4. Security Hardening: Revoke execute permissions on security definer function
-- Prevents anon, authenticated, or service_role from calling this RPC directly.
-- Only postgres (function owner / pg_cron) can execute this function.
REVOKE EXECUTE ON FUNCTION public.cancel_expired_pending_bookings()
FROM PUBLIC, anon, authenticated, service_role;

-- 5. Schedule cron job to run every minute via pg_cron (Job: vsp-cancel-expired-bookings)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Remove existing job if present
        PERFORM cron.unschedule('vsp-cancel-expired-bookings')
        WHERE EXISTS (
            SELECT 1 FROM cron.job WHERE jobname = 'vsp-cancel-expired-bookings'
        );

        -- Schedule to run every minute (* * * * *)
        PERFORM cron.schedule(
            'vsp-cancel-expired-bookings',
            '* * * * *',
            'SELECT public.cancel_expired_pending_bookings();'
        );
    END IF;
END;
$$;
