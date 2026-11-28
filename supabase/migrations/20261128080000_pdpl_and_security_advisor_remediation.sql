-- ============================================================================
-- Migration: 20261128080000_pdpl_and_security_advisor_remediation.sql
-- Purpose: Remediate P0/P1 Supabase Security Advisor findings on Staging before
--          PDPL audit & independent verification:
--   1. public.import_paymob_reconciliation_row(text, numeric, text):
--      Fix auth.uid() IS NULL bypass and revoke PUBLIC/anon EXECUTE.
--   2. public.trg_award_field_championship_xp():
--      Revoke direct RPC EXECUTE from PUBLIC, anon, authenticated (triggers run internally).
--   3. public.get_challenge_opponent_repeat_status(uuid, uuid):
--      Ensure PUBLIC and anon cannot execute authenticated-only RPC.
--   4. public.vsp_cairo_month_key(timestamptz) & public.vsp_slice_avg_weight(jsonb, int, int):
--      Pin explicit search_path = public, pg_temp (resolve function_search_path_mutable).
--   5. public.immortal_winners_public view:
--      Switch to security_invoker = true (resolve security_definer_view ERROR).
-- ============================================================================

-- 1. Harden import_paymob_reconciliation_row against anon callers & missing auth.uid()
CREATE OR REPLACE FUNCTION public.import_paymob_reconciliation_row(
  p_paymob_txn_id text,
  p_actual_fee numeric,
  p_channel_class text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role TEXT;
  v_jwt_role TEXT := coalesce(auth.role(), '');
  v_tx record;
  v_diff NUMERIC(10,2);
  v_status TEXT;
BEGIN
  IF v_jwt_role <> 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'admin_required');
    END IF;
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF lower(coalesce(v_caller_role, '')) NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'admin_required');
    END IF;
  END IF;

  SELECT * INTO v_tx FROM public.transactions WHERE paymob_transaction_id = p_paymob_txn_id LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'transaction_not_found');
  END IF;

  v_diff := round(coalesce(v_tx.gateway_fee_collected, (v_tx.metadata->>'gateway_fee')::numeric, 0) - coalesce(p_actual_fee, 0), 2);
  v_status := CASE WHEN abs(v_diff) <= 0.05 THEN 'matched' ELSE 'mismatch' END;

  UPDATE public.transactions
  SET paymob_actual_fee = p_actual_fee,
      reconciliation_diff = v_diff,
      reconciliation_status = v_status,
      payment_channel_class = coalesce(p_channel_class, payment_channel_class),
      updated_at = timezone('utc', now())
  WHERE id = v_tx.id;

  IF v_tx.booking_id IS NOT NULL THEN
    UPDATE public.bookings
    SET paymob_actual_fee = p_actual_fee,
        reconciliation_diff = v_diff,
        reconciliation_status = v_status,
        payment_channel_class = coalesce(p_channel_class, payment_channel_class),
        updated_at = timezone('utc', now())
    WHERE id = v_tx.booking_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_tx.id,
    'booking_id', v_tx.booking_id,
    'gateway_fee_collected', coalesce(v_tx.gateway_fee_collected, 0),
    'paymob_actual_fee', p_actual_fee,
    'reconciliation_diff', v_diff,
    'reconciliation_status', v_status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.import_paymob_reconciliation_row(text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.import_paymob_reconciliation_row(text, numeric, text) TO authenticated, service_role;

-- 2. Trigger function must never be directly callable via PostgREST anon/authenticated RPC
REVOKE ALL ON FUNCTION public.trg_award_field_championship_xp() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_award_field_championship_xp() TO service_role;

-- 3. Authenticated-only helper should not remain executable by PUBLIC/anon
REVOKE ALL ON FUNCTION public.get_challenge_opponent_repeat_status(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_challenge_opponent_repeat_status(uuid, uuid) TO authenticated, service_role;

-- 4. Pin search_path on pure helper functions
ALTER FUNCTION public.vsp_cairo_month_key(timestamp with time zone) SET search_path = public, pg_temp;
ALTER FUNCTION public.vsp_slice_avg_weight(jsonb, integer, integer) SET search_path = public, pg_temp;

-- 5. Resolve security_definer_view ERROR on immortal_winners_public
ALTER VIEW public.immortal_winners_public SET (security_invoker = true);
