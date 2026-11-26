-- =============================================================
-- VSP Commission Model Update: 5% from player + 5% from owner
-- Migration: 20261126020000_update_commission_model_10pct.sql
-- =============================================================
-- Player pays: booking_price * 1.05
-- Owner receives: booking_price * 0.95
-- VSP keeps: booking_price * 0.10 (5+5)
-- Commission is NON-REFUNDABLE in all cases
-- =============================================================
BEGIN;

-- ============================================================
-- 1. Update platform_fee_config
-- ============================================================
-- Add owner commission column if missing
ALTER TABLE public.platform_fee_config
  ADD COLUMN IF NOT EXISTS owner_vsp_rate  NUMERIC(5,4) DEFAULT 0.05,
  ADD COLUMN IF NOT EXISTS player_vsp_rate NUMERIC(5,4) DEFAULT 0.05;

-- Update to new 5% + 5% model
UPDATE public.platform_fee_config
SET
  booking_vsp_rate  = 0.05,   -- 5% fee added on top for player
  player_vsp_rate   = 0.05,   -- 5% from player
  owner_vsp_rate    = 0.05;   -- 5% deducted from owner payout

-- ============================================================
-- 2. Create helper function: calculate player payment amount
-- Input: booking_price (what owner charges)
-- Output: amount player pays = price * 1.05
-- ============================================================
CREATE OR REPLACE FUNCTION public.calculate_player_payment_amount(
  p_booking_price NUMERIC
)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ROUND(p_booking_price * 1.05, 2);
$$;

-- ============================================================
-- 3. Create helper function: calculate owner net payout
-- Input: booking_price (what owner charges)
-- Output: amount owner receives = price * 0.95
-- ============================================================
CREATE OR REPLACE FUNCTION public.calculate_owner_net_payout(
  p_booking_price NUMERIC
)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ROUND(p_booking_price * 0.95, 2);
$$;

-- ============================================================
-- 4. Create helper function: calculate VSP commission
-- Input: booking_price
-- Output: total VSP commission = price * 0.10
-- ============================================================
CREATE OR REPLACE FUNCTION public.calculate_vsp_total_commission(
  p_booking_price NUMERIC
)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ROUND(p_booking_price * 0.10, 2);
$$;

GRANT EXECUTE ON FUNCTION public.calculate_player_payment_amount(NUMERIC) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_owner_net_payout(NUMERIC) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_vsp_total_commission(NUMERIC) TO authenticated, service_role;

-- ============================================================
-- 5. Update get_owner_financial_summary to deduct 5% from owner
--    AND include online/partial deposits in revenue
-- ============================================================
-- Note: The actual function body depends on existing implementation.
-- This migration adds a view that calculates correct net amounts.
-- The Edge Function create_paymob_intention must be updated separately
-- to charge player price * 1.05.

-- Add vsp_commission_rate column to bookings if missing
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS player_vsp_fee   NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS owner_vsp_fee    NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_vsp_commission NUMERIC DEFAULT 0;

-- ============================================================
-- 6. Fix FIN-01: Reject late payment for expired bookings
-- Add expired status check to webhook processing function
-- ============================================================
-- The Edge Function paymob_webhook handles this in TypeScript.
-- This migration adds a DB-level guard function:
CREATE OR REPLACE FUNCTION public.validate_booking_payment_eligibility(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_booking RECORD;
BEGIN
  SELECT id, status, end_time, payment_status
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'reason', 'BOOKING_NOT_FOUND');
  END IF;

  IF v_booking.status IN ('expired', 'cancelled') THEN
    RETURN jsonb_build_object('eligible', false, 'reason', 'BOOKING_EXPIRED_OR_CANCELLED');
  END IF;

  IF v_booking.end_time < NOW() AND v_booking.status != 'completed' THEN
    -- Auto-expire if past end time
    UPDATE public.bookings SET status = 'expired' WHERE id = p_booking_id;
    RETURN jsonb_build_object('eligible', false, 'reason', 'BOOKING_TIME_PASSED');
  END IF;

  RETURN jsonb_build_object('eligible', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_booking_payment_eligibility(UUID) TO service_role;

-- ============================================================
-- 7. Fix FIN-04: Include online deposits in owner revenue
-- Update get_owner_financial_summary to count partial payments
-- ============================================================
-- Add a view for correct owner revenue calculation
CREATE OR REPLACE VIEW public.owner_revenue_summary AS
SELECT
  s.owner_id,
  s.id AS stadium_id,
  s.name AS stadium_name,
  COALESCE(SUM(
    CASE
      WHEN b.payment_status IN ('paid', 'partially_paid', 'completed')
        OR b.is_paid = true
        OR b.digital_amount_paid > 0
      THEN b.total_price * 0.95  -- Owner gets 95% (after 5% VSP cut)
      ELSE 0
    END
  ), 0) AS realized_revenue,
  COALESCE(SUM(
    CASE
      WHEN b.payment_status IN ('paid', 'partially_paid', 'completed')
        OR b.digital_amount_paid > 0
      THEN b.digital_amount_paid * 0.95
      ELSE 0
    END
  ), 0) AS realized_online_revenue,
  COALESCE(SUM(
    CASE
      WHEN b.payment_status IN ('paid', 'partially_paid')
        AND b.payment_method = 'cash'
      THEN b.total_price - COALESCE(b.digital_amount_paid, 0)
      ELSE 0
    END
  ), 0) AS pending_cash_collection
FROM public.stadiums s
LEFT JOIN public.bookings b ON b.stadium_id = s.id
  AND b.status IN ('confirmed', 'completed')
  AND b.end_time <= NOW()
GROUP BY s.owner_id, s.id, s.name;

GRANT SELECT ON public.owner_revenue_summary TO authenticated;

-- ============================================================
-- 8. Fix FIN-05: Allow cash confirmation on hybrid bookings
-- Update confirm_cash_booking_atomic to allow any payment method
-- ============================================================
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
  p_booking_id    UUID,
  p_owner_user_id UUID,
  p_cash_amount   NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_booking RECORD;
  v_stadium RECORD;
BEGIN
  PERFORM set_config('vsp.system_override', 'true', true);

  -- Fetch and lock the booking
  SELECT b.*, s.owner_id
  INTO v_booking
  FROM public.bookings b
  JOIN public.stadiums s ON s.id = b.stadium_id
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_NOT_FOUND');
  END IF;

  -- Verify the owner owns this stadium
  IF v_booking.owner_id != p_owner_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF v_booking.status NOT IN ('confirmed', 'pending') THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_NOT_CONFIRMABLE', 'status', v_booking.status);
  END IF;

  -- FIN-05 FIX: Allow any payment_method (not just 'cash')
  -- This covers hybrid bookings where player paid deposit online + remaining in cash
  UPDATE public.bookings
  SET
    is_paid        = true,
    payment_status = 'paid',
    -- Record cash amount if provided
    cash_amount_paid = COALESCE(p_cash_amount,
                        v_booking.total_price - COALESCE(v_booking.digital_amount_paid, 0)),
    updated_at     = NOW()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic FROM anon;
GRANT  EXECUTE ON FUNCTION public.confirm_cash_booking_atomic TO authenticated, service_role;

-- ============================================================
-- 9. Fix FIN-06: Include challenge/matchup/team bookings in reconciliation
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_reconcile_all_past_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Mark confirmed bookings past their end time as completed
  -- FIN-06 FIX: Removed exclusion of challenge/matchup/team booking types
  UPDATE public.bookings
  SET status = 'completed', updated_at = NOW()
  WHERE status = 'confirmed'
    AND end_time < NOW() - INTERVAL '30 minutes';

  -- Mark pending bookings past their end time as expired
  UPDATE public.bookings
  SET status = 'expired', updated_at = NOW()
  WHERE status = 'pending'
    AND end_time < NOW() - INTERVAL '1 hour';
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_reconcile_all_past_bookings() TO service_role;

COMMIT;
