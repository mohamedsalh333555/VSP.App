-- ==============================================================================
-- Migration: Smart Refund System (Schema, Constraints, Indexes, and View)
-- ==============================================================================

-- 1. Ensure columns exist on public.bookings
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS refund_transaction_id TEXT,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refund_payment_method TEXT;

-- 2. Constraints for payment and refund methods
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'bookings_payment_method_check'
  ) THEN
    ALTER TABLE public.bookings
      ADD CONSTRAINT bookings_payment_method_check
      CHECK (payment_method = ANY (ARRAY[
        'cash'::text, 'card'::text, 'wallet'::text, 'online'::text, 
        'paymob'::text, 'instapay'::text, 'vodafone_cash'::text
      ]));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'bookings_refund_payment_method_check'
  ) THEN
    ALTER TABLE public.bookings
      ADD CONSTRAINT bookings_refund_payment_method_check
      CHECK (refund_payment_method IS NULL OR refund_payment_method = ANY (ARRAY[
        'card'::text, 'wallet'::text, 'cash'::text, 'bank_transfer'::text
      ]));
  END IF;
END $$;

-- 3. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_refund_status 
  ON public.bookings (status, payment_status);

CREATE INDEX IF NOT EXISTS idx_bookings_refund_txn 
  ON public.bookings (refund_transaction_id);

-- 4. View: v_bookings_with_refund
CREATE OR REPLACE VIEW public.v_bookings_with_refund AS
SELECT 
  id,
  created_by_user_id,
  owner_id,
  stadium_name,
  start_time,
  end_time,
  total_price,
  payment_method,
  payment_status,
  status,
  refund_amount,
  refund_transaction_id,
  refunded_at,
  refund_payment_method,
  cancelled_at,
  platform_fee,
  CASE
    WHEN (COALESCE(refund_payment_method, payment_method) = ANY (ARRAY['wallet'::text, 'vodafone_cash'::text, 'instapay'::text])) THEN 'wallet'::text
    WHEN (COALESCE(refund_payment_method, payment_method) = ANY (ARRAY['card'::text, 'paymob'::text, 'online'::text])) THEN 'card'::text
    ELSE 'cash'::text
  END AS refund_channel,
  CASE
    WHEN (COALESCE(refund_payment_method, payment_method) = ANY (ARRAY['wallet'::text, 'vodafone_cash'::text, 'instapay'::text])) THEN 'minutes'::text
    WHEN (COALESCE(refund_payment_method, payment_method) = ANY (ARRAY['card'::text, 'paymob'::text, 'online'::text])) THEN '3-5_business_days'::text
    ELSE 'immediate'::text
  END AS refund_eta,
  COALESCE(refund_transaction_id, payment_reference, paymob_transaction_id) AS display_refund_ref
FROM public.bookings
WHERE status = 'cancelled'::text AND payment_status = 'refunded'::text;

COMMENT ON VIEW public.v_bookings_with_refund IS 'Optimized query view for cancelled bookings with calculated smart refund channel and ETA.';
