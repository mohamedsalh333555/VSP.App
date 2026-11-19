-- Repair a production/Staging CHECK constraint that permits only
-- (pending, paid, failed, refunded), while existing shipped RPCs write:
-- cancelled, cancelled_withdrawal, refund_pending,
-- refund_requested, refund_failed_manual_review.
--
-- No new tables, roles, RLS policies, financial side effects, or changed
-- booking/pricing semantics. This migration is SOURCE ONLY until approved.
-- Transactional: if validation fails, restore the original constraint.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '2min';

ALTER TABLE public.team_league_payments
  DROP CONSTRAINT IF EXISTS team_league_payments_status_ck;

ALTER TABLE public.team_league_payments
  ADD CONSTRAINT team_league_payments_status_ck
  CHECK (payment_status IN (
    'pending',
    'paid',
    'failed',
    'refunded',
    'cancelled',
    'cancelled_withdrawal',
    'refund_pending',
    'refund_requested',
    'refund_failed_manual_review'
  )) NOT VALID;

-- Force the database to check historical rows; a mismatch aborts the
-- whole transaction rather than leaving a silently unenforced contract.
ALTER TABLE public.team_league_payments
  VALIDATE CONSTRAINT team_league_payments_status_ck;
COMMIT;
