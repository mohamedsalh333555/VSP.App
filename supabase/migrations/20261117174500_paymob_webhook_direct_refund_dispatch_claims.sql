-- Source-only deployment candidate. Apply on isolated Staging only after
-- approval, before deploying the updated direct-refund Webhook Edge Function.
-- Explicitly service-role-only: no Data API access by ordinary users.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '2min';

CREATE TABLE public.paymob_refund_dispatch_claims (
  paymob_transaction_id text PRIMARY KEY,
  order_reference text NOT NULL,
  refund_context text NOT NULL,
  amount_cents bigint NOT NULL,
  status text NOT NULL DEFAULT 'claimed',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT paymob_direct_refund_id_ck
    CHECK (paymob_transaction_id ~ '^[1-9][0-9]*$'
      AND length(paymob_transaction_id) <= 40),
  CONSTRAINT paymob_direct_refund_order_ck
    CHECK (length(order_reference) BETWEEN 1 AND 256),
  CONSTRAINT paymob_direct_refund_context_ck
    CHECK (refund_context IN ('legacy_1v1', 'cancelled_booking')),
  CONSTRAINT paymob_direct_refund_amount_ck
    CHECK (amount_cents BETWEEN 1 AND 1000000000000),
  CONSTRAINT paymob_direct_refund_status_ck
    CHECK (status IN ('claimed', 'gateway_acknowledged', 'requires_reconciliation'))
);

ALTER TABLE public.paymob_refund_dispatch_claims ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.paymob_refund_dispatch_claims FROM PUBLIC;
REVOKE ALL ON TABLE public.paymob_refund_dispatch_claims FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.paymob_refund_dispatch_claims TO service_role;
-- No anon/authenticated policies; service_role can bypass RLS only on server.

COMMIT;
