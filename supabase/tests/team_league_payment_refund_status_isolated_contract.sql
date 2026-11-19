-- Isolated disposable PostgreSQL only: this file must NEVER execute
-- against a real Supabase project or any customer payment records.
\set ON_ERROR_STOP on

CREATE TABLE public.team_league_payments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_status text NOT NULL DEFAULT 'pending',
  CONSTRAINT team_league_payments_status_ck
    CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded'))
);
INSERT INTO public.team_league_payments(payment_status)
SELECT unnest(ARRAY['pending', 'paid', 'failed', 'refunded']);

-- Execute the real repository migration rather than duplicating SQL.
\i supabase/migrations/20261117173000_align_team_league_payment_refund_states.sql

DO $$
DECLARE status_value text;
DECLARE is_valid boolean;
BEGIN
  FOREACH status_value IN ARRAY ARRAY[
    'pending', 'paid', 'failed', 'refunded',
    'cancelled', 'cancelled_withdrawal', 'refund_pending',
    'refund_requested', 'refund_failed_manual_review'
  ] LOOP
    INSERT INTO public.team_league_payments (payment_status) VALUES (status_value);
    UPDATE public.team_league_payments
      SET payment_status = status_value WHERE id = 2;
  END LOOP;

  -- Extra statuses must remain prohibited: repair is not a free-text bypass.
  BEGIN
    INSERT INTO public.team_league_payments (payment_status)
    VALUES ('unverified_paid_claim');
    RAISE EXCEPTION 'Unexpected: arbitrary payment state accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  SELECT c.convalidated INTO is_valid
  FROM pg_constraint c
  WHERE c.conrelid = 'public.team_league_payments'::regclass
    AND c.conname = 'team_league_payments_status_ck';
  IF is_valid IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Refund status CHECK was not validated';
  END IF;
END $$;

-- Verify the migration can be rerun without losing existing valid data.
\i supabase/migrations/20261117173000_align_team_league_payment_refund_states.sql
SELECT count(*) AS tested_synthetic_rows FROM public.team_league_payments;
