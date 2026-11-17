-- Disposable PostgreSQL only; never run against Supabase production/Staging.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
\i supabase/migrations/20261117174500_paymob_webhook_direct_refund_dispatch_claims.sql

DO $$
DECLARE enabled boolean;
BEGIN
  INSERT INTO public.paymob_refund_dispatch_claims
    (paymob_transaction_id, order_reference, refund_context, amount_cents)
  VALUES ('789123', 'TOURN_1V1_synthetic', 'legacy_1v1', 2500);

  BEGIN
    INSERT INTO public.paymob_refund_dispatch_claims
      (paymob_transaction_id, order_reference, refund_context, amount_cents)
    VALUES ('789123', 'TOURN_1V1_synthetic', 'legacy_1v1', 2500);
    RAISE EXCEPTION 'Duplicate refund claim was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.paymob_refund_dispatch_claims
      (paymob_transaction_id, order_reference, refund_context, amount_cents)
    VALUES ('790000', 'reference', 'unrecognized_context', 2500);
    RAISE EXCEPTION 'Untrusted refund context was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  SELECT c.relrowsecurity INTO enabled
  FROM pg_class c WHERE c.oid='public.paymob_refund_dispatch_claims'::regclass;
  IF enabled IS DISTINCT FROM true THEN RAISE EXCEPTION 'RLS is disabled'; END IF;
  IF has_table_privilege('anon', 'public.paymob_refund_dispatch_claims', 'INSERT')
    OR has_table_privilege('authenticated', 'public.paymob_refund_dispatch_claims', 'SELECT')
    OR has_table_privilege('authenticated', 'public.paymob_refund_dispatch_claims', 'UPDATE')
    THEN RAISE EXCEPTION 'An ordinary client can access provider refund claims'; END IF;
  IF NOT has_table_privilege('service_role', 'public.paymob_refund_dispatch_claims', 'INSERT')
    THEN RAISE EXCEPTION 'Server-only role cannot claim refunds'; END IF;
END $$;
SELECT 'PASS: unique direct refund claims, server-only grants, RLS and context constraints' AS result;
