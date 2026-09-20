-- =========================================================
-- Phase 5: Transaction-Safe Booking Engine
-- Idempotency Key + Auto-Cancel Expired Pending Bookings
-- =========================================================

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_booking_idempotency
  ON public.bookings (idempotency_key)
  WHERE idempotency_key IS NOT NULL AND status != 'cancelled';

CREATE INDEX IF NOT EXISTS idx_bookings_idempotency
  ON public.bookings (idempotency_key)
  WHERE idempotency_key IS NOT NULL;
