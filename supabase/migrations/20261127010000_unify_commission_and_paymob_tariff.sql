-- ============================================================================
-- VSP Unified Commission (5% Player + 5% Owner) & Paymob Tariff (2.4% / 2.6% + 3 EGP)
-- Migration: 20261127010000_unify_commission_and_paymob_tariff.sql
-- Target: Staging verification first; never alters historical paid receipts.
-- ============================================================================
BEGIN;

-- 1. Extend platform_fee_config with explicit dual-commission, effective date, version & mode
ALTER TABLE public.platform_fee_config
  ADD COLUMN IF NOT EXISTS player_vsp_rate NUMERIC(6,4) NOT NULL DEFAULT 0.0500,
  ADD COLUMN IF NOT EXISTS owner_vsp_rate NUMERIC(6,4) NOT NULL DEFAULT 0.0500,
  ADD COLUMN IF NOT EXISTS effective_from TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  ADD COLUMN IF NOT EXISTS fee_version TEXT NOT NULL DEFAULT 'v2026_11_paymob_24_26',
  ADD COLUMN IF NOT EXISTS source_reference TEXT NOT NULL DEFAULT 'Paymob VSP Annex (2.4%+3 local/wallet, 2.6%+3 foreign)',
  ADD COLUMN IF NOT EXISTS gateway_fee_mode TEXT NOT NULL DEFAULT 'gross_up',
  ADD COLUMN IF NOT EXISTS foreign_surcharge_enabled BOOLEAN NOT NULL DEFAULT false;

-- Upsert row id=1 cleanly (works whether staging row was empty or populated)
INSERT INTO public.platform_fee_config (
  id,
  booking_vsp_rate,
  player_vsp_rate,
  owner_vsp_rate,
  booking_paymob_rate,
  booking_paymob_local_rate,
  booking_paymob_wallet_rate,
  booking_paymob_foreign_rate,
  booking_paymob_fixed_fee,
  vsp_applies_to_cash,
  paymob_applies_to_electronic,
  subscription_vsp_rate,
  subscription_paymob_rate,
  subscription_paymob_fixed_fee,
  effective_from,
  fee_version,
  source_reference,
  gateway_fee_mode,
  foreign_surcharge_enabled,
  updated_at
) VALUES (
  1,
  0.0500,
  0.0500,
  0.0500,
  0.0240,
  0.0240,
  0.0240,
  0.0260,
  3.00,
  false,
  true,
  0.0000,
  0.0240,
  3.00,
  '2026-11-27T00:00:00Z'::timestamptz,
  'v2026_11_paymob_24_26',
  'Paymob VSP Annex (2.4%+3 local/wallet, 2.6%+3 foreign)',
  'gross_up',
  false,
  timezone('utc', now())
)
ON CONFLICT (id) DO UPDATE SET
  booking_vsp_rate = EXCLUDED.booking_vsp_rate,
  player_vsp_rate = EXCLUDED.player_vsp_rate,
  owner_vsp_rate = EXCLUDED.owner_vsp_rate,
  booking_paymob_rate = EXCLUDED.booking_paymob_rate,
  booking_paymob_local_rate = EXCLUDED.booking_paymob_local_rate,
  booking_paymob_wallet_rate = EXCLUDED.booking_paymob_wallet_rate,
  booking_paymob_foreign_rate = EXCLUDED.booking_paymob_foreign_rate,
  booking_paymob_fixed_fee = EXCLUDED.booking_paymob_fixed_fee,
  paymob_applies_to_electronic = EXCLUDED.paymob_applies_to_electronic,
  effective_from = EXCLUDED.effective_from,
  fee_version = EXCLUDED.fee_version,
  source_reference = EXCLUDED.source_reference,
  gateway_fee_mode = EXCLUDED.gateway_fee_mode,
  updated_at = timezone('utc', now());

-- 2. Snapshot & reconciliation columns on bookings & transactions (preserve legacy rows)
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS player_vsp_fee NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS owner_vsp_fee NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_vsp_commission NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS owner_net_amount NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fee_version TEXT,
  ADD COLUMN IF NOT EXISTS payment_channel_class TEXT,
  ADD COLUMN IF NOT EXISTS paymob_actual_fee NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS reconciliation_diff NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS reconciliation_status TEXT DEFAULT 'pending_reconciliation';

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS player_vsp_fee NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS owner_vsp_fee NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS owner_net_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS gateway_fee_collected NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS paymob_actual_fee NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS reconciliation_diff NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS reconciliation_status TEXT DEFAULT 'pending_reconciliation',
  ADD COLUMN IF NOT EXISTS fee_version TEXT,
  ADD COLUMN IF NOT EXISTS payment_channel_class TEXT;

-- 3. Payment Attempts table: locks agreed total & tariff snapshot before Paymob redirect
CREATE TABLE IF NOT EXISTS public.payment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  base_price_piasters BIGINT NOT NULL,
  player_vsp_fee_piasters BIGINT NOT NULL,
  owner_vsp_fee_piasters BIGINT NOT NULL,
  owner_net_piasters BIGINT NOT NULL,
  gateway_fee_piasters BIGINT NOT NULL,
  approved_total_piasters BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'EGP',
  payment_channel_class TEXT NOT NULL DEFAULT 'local_or_wallet',
  fee_version TEXT NOT NULL,
  gateway_fee_mode TEXT NOT NULL,
  paymob_order_id TEXT,
  status TEXT NOT NULL DEFAULT 'created',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_payment_attempts_booking_id ON public.payment_attempts(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_paymob_order_id ON public.payment_attempts(paymob_order_id);

ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_read_own_payment_attempts" ON public.payment_attempts;
CREATE POLICY "users_read_own_payment_attempts"
  ON public.payment_attempts
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND lower(coalesce(u.role, '')) IN ('admin', 'co_founder', 'cofounder', 'super_admin')
    )
  );

-- 4. Single Server-Authoritative Pricing Function (integer piaster arithmetic)
CREATE OR REPLACE FUNCTION public.calculate_booking_pricing_v2(
  p_base_price NUMERIC,
  p_channel TEXT DEFAULT 'local_card'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cfg public.platform_fee_config%ROWTYPE;
  v_channel TEXT := lower(coalesce(nullif(trim(p_channel), ''), 'local_card'));
  v_base_piasters BIGINT;
  v_player_vsp_piasters BIGINT;
  v_owner_vsp_piasters BIGINT;
  v_player_subtotal_piasters BIGINT;
  v_owner_net_piasters BIGINT;
  v_fixed_piasters BIGINT;
  v_gateway_rate NUMERIC(8,6);
  v_gateway_fee_piasters BIGINT;
  v_total_piasters BIGINT;
BEGIN
  IF p_base_price IS NULL OR p_base_price < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_base_price');
  END IF;

  SELECT * INTO v_cfg FROM public.platform_fee_config WHERE id = 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'fee_policy_unavailable');
  END IF;

  v_base_piasters := round(p_base_price * 100)::BIGINT;
  v_player_vsp_piasters := round(v_base_piasters * coalesce(v_cfg.player_vsp_rate, v_cfg.booking_vsp_rate, 0.05))::BIGINT;
  v_owner_vsp_piasters := round(v_base_piasters * coalesce(v_cfg.owner_vsp_rate, 0.05))::BIGINT;
  v_player_subtotal_piasters := v_base_piasters + v_player_vsp_piasters;
  v_owner_net_piasters := greatest(v_base_piasters - v_owner_vsp_piasters, 0);

  IF v_base_piasters = 0 OR v_cfg.paymob_applies_to_electronic IS NOT TRUE THEN
    v_gateway_rate := 0;
    v_gateway_fee_piasters := 0;
    v_total_piasters := v_player_subtotal_piasters;
  ELSE
    IF v_channel IN ('foreign', 'foreign_card') AND v_cfg.foreign_surcharge_enabled IS TRUE THEN
      v_gateway_rate := coalesce(v_cfg.booking_paymob_foreign_rate, 0.0260);
    ELSIF v_channel = 'wallet' THEN
      v_gateway_rate := coalesce(v_cfg.booking_paymob_wallet_rate, v_cfg.booking_paymob_local_rate, v_cfg.booking_paymob_rate, 0.0240);
    ELSE
      v_gateway_rate := coalesce(v_cfg.booking_paymob_local_rate, v_cfg.booking_paymob_rate, 0.0240);
    END IF;

    v_fixed_piasters := round(coalesce(v_cfg.booking_paymob_fixed_fee, 3.00) * 100)::BIGINT;

    IF v_cfg.gateway_fee_mode = 'convenience_fee_by_paymob' THEN
      v_gateway_fee_piasters := 0;
      v_total_piasters := v_player_subtotal_piasters;
    ELSIF v_cfg.gateway_fee_mode = 'gross_up' THEN
      v_total_piasters := round((v_player_subtotal_piasters + v_fixed_piasters)::NUMERIC / (1.0 - v_gateway_rate))::BIGINT;
      v_gateway_fee_piasters := greatest(v_total_piasters - v_player_subtotal_piasters, 0);
    ELSE
      -- additive_on_player_subtotal
      v_gateway_fee_piasters := round(v_player_subtotal_piasters * v_gateway_rate)::BIGINT + v_fixed_piasters;
      v_total_piasters := v_player_subtotal_piasters + v_gateway_fee_piasters;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'fee_version', v_cfg.fee_version,
    'effective_from', v_cfg.effective_from,
    'gateway_fee_mode', v_cfg.gateway_fee_mode,
    'foreign_surcharge_enabled', v_cfg.foreign_surcharge_enabled,
    'channel_class', v_channel,
    'player_vsp_rate', coalesce(v_cfg.player_vsp_rate, v_cfg.booking_vsp_rate),
    'owner_vsp_rate', v_cfg.owner_vsp_rate,
    'gateway_rate', v_gateway_rate,
    'gateway_fixed_fee', v_cfg.booking_paymob_fixed_fee,
    'base_price', round(v_base_piasters / 100.0, 2),
    'player_vsp_fee', round(v_player_vsp_piasters / 100.0, 2),
    'owner_vsp_fee', round(v_owner_vsp_piasters / 100.0, 2),
    'total_vsp_commission', round((v_player_vsp_piasters + v_owner_vsp_piasters) / 100.0, 2),
    'owner_net_amount', round(v_owner_net_piasters / 100.0, 2),
    'player_subtotal', round(v_player_subtotal_piasters / 100.0, 2),
    'gateway_fee', round(v_gateway_fee_piasters / 100.0, 2),
    'total_due', round(v_total_piasters / 100.0, 2),
    'total_due_piasters', v_total_piasters
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.calculate_booking_pricing_v2(NUMERIC, TEXT) TO anon, authenticated, service_role;

-- 5. Update record_booking_payment_atomic to snapshot player_vsp_fee, owner_vsp_fee, owner_net_amount, fee_version
CREATE OR REPLACE FUNCTION public.record_booking_payment_atomic(
  p_booking_id uuid,
  p_user_id uuid,
  p_paymob_transaction_id text,
  p_paymob_order_id text,
  p_payment_method text,
  p_principal_amount numeric,
  p_gross_amount numeric,
  p_is_deposit boolean DEFAULT false,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking          record;
  v_existing_tx      record;
  v_attempt          record;
  v_pricing          jsonb;
  v_total_collected  numeric := 0;
  v_total_gross      numeric := 0;
  v_remaining_before numeric := 0;
  v_player_vsp_fee   numeric := 0;
  v_owner_vsp_fee    numeric := 0;
  v_total_vsp_comm   numeric := 0;
  v_owner_net        numeric := 0;
  v_gateway_fee      numeric := 0;
  v_expected_gross   numeric := 0;
  v_fee_version      text;
  v_new_collected    numeric;
  v_new_gross        numeric;
  v_is_final         boolean;
  v_now              timestamptz := timezone('utc', now());
  v_tx_id            uuid;
  v_payment_method   text := lower(coalesce(p_payment_method, 'card'));
  v_card_origin      text := lower(coalesce(p_metadata->>'card_origin', 'local'));
  v_channel          text;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  IF p_booking_id IS NULL OR p_user_id IS NULL
     OR nullif(trim(p_paymob_transaction_id), '') IS NULL
     OR p_principal_amount IS NULL OR p_principal_amount <= 0
     OR p_gross_amount    IS NULL OR p_gross_amount    <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_arguments');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  -- Idempotency check by Paymob transaction ID
  SELECT id, amount, status, booking_id
  INTO v_existing_tx
  FROM public.transactions
  WHERE paymob_transaction_id = p_paymob_transaction_id
     OR reference_number = p_paymob_transaction_id
     OR reference_number = 'PAYMOB_' || p_paymob_transaction_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    IF v_existing_tx.booking_id IS DISTINCT FROM p_booking_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'transaction_already_bound_to_other_booking');
    END IF;
    RETURN jsonb_build_object('success', true, 'idempotent', true,
      'transaction_id', v_existing_tx.id, 'booking_id', p_booking_id,
      'principal_amount', v_existing_tx.amount);
  END IF;

  IF coalesce(v_booking.created_by_user_id, v_booking.user_id) IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_user_mismatch');
  END IF;

  SELECT
    coalesce(sum(amount), 0),
    coalesce(sum(coalesce(gross_amount, amount)), 0)
  INTO v_total_collected, v_total_gross
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND type IN ('payment', 'deposit')
    AND status = 'completed';

  v_remaining_before := round(greatest(coalesce(v_booking.total_price, 0) - v_total_collected, 0), 2);

  IF p_principal_amount > v_remaining_before + 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_exceeds_remaining_booking_balance',
      'remaining_amount', v_remaining_before, 'attempted_amount', p_principal_amount);
  END IF;

  v_channel := CASE
    WHEN v_payment_method = 'wallet' THEN 'wallet'
    WHEN v_card_origin = 'foreign' THEN 'foreign_card'
    ELSE 'local_card'
  END;

  -- Prefer the exact locked payment_attempt snapshot for this paymob_order_id
  SELECT * INTO v_attempt
  FROM public.payment_attempts
  WHERE booking_id = p_booking_id
    AND (p_paymob_order_id IS NULL OR paymob_order_id = p_paymob_order_id)
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_player_vsp_fee := round(v_attempt.player_vsp_fee_piasters / 100.0, 2);
    v_owner_vsp_fee  := round(v_attempt.owner_vsp_fee_piasters / 100.0, 2);
    v_total_vsp_comm := v_player_vsp_fee + v_owner_vsp_fee;
    v_owner_net      := round(v_attempt.owner_net_piasters / 100.0, 2);
    v_gateway_fee    := round(v_attempt.gateway_fee_piasters / 100.0, 2);
    v_expected_gross := round(v_attempt.approved_total_piasters / 100.0, 2);
    v_fee_version    := v_attempt.fee_version;
  ELSE
    v_pricing := public.calculate_booking_pricing_v2(p_principal_amount, v_channel);
    IF coalesce((v_pricing->>'success')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('success', false, 'error', coalesce(v_pricing->>'error', 'payment_fee_configuration_unavailable'));
    END IF;
    v_player_vsp_fee := (v_pricing->>'player_vsp_fee')::numeric;
    v_owner_vsp_fee  := (v_pricing->>'owner_vsp_fee')::numeric;
    v_total_vsp_comm := (v_pricing->>'total_vsp_commission')::numeric;
    v_owner_net      := (v_pricing->>'owner_net_amount')::numeric;
    v_gateway_fee    := (v_pricing->>'gateway_fee')::numeric;
    v_expected_gross := (v_pricing->>'total_due')::numeric;
    v_fee_version    := v_pricing->>'fee_version';
  END IF;

  IF abs(p_gross_amount - v_expected_gross) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'gross_amount_mismatch',
      'expected_gross_amount', v_expected_gross, 'received_gross_amount', p_gross_amount,
      'principal_amount', p_principal_amount, 'player_vsp_fee', v_player_vsp_fee, 'gateway_fee', v_gateway_fee);
  END IF;

  v_new_collected := round(v_total_collected + p_principal_amount, 2);
  v_new_gross     := round(v_total_gross     + p_gross_amount,     2);
  v_is_final      := v_new_collected >= round(coalesce(v_booking.total_price, 0), 2) - 0.01;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, gross_amount, type, status, payment_method,
    reference_number, paymob_transaction_id, description, metadata,
    player_vsp_fee, owner_vsp_fee, owner_net_amount, gateway_fee_collected,
    fee_version, payment_channel_class, reconciliation_status,
    created_at, updated_at
  ) VALUES (
    p_user_id, p_booking_id, p_principal_amount, p_gross_amount,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'payment' ELSE 'deposit' END,
    'completed', v_payment_method,
    p_paymob_transaction_id, p_paymob_transaction_id,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'دفع حجز ملعب' ELSE 'دفع عربون حجز ملعب' END,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'principal_amount',     p_principal_amount,
      'gross_amount_charged', p_gross_amount,
      'vsp_fee',              v_player_vsp_fee,
      'player_vsp_fee',       v_player_vsp_fee,
      'owner_vsp_fee',        v_owner_vsp_fee,
      'total_vsp_commission', v_total_vsp_comm,
      'owner_net_amount',     v_owner_net,
      'gateway_fee',          v_gateway_fee,
      'total_payment_fees',   round(v_player_vsp_fee + v_gateway_fee, 2),
      'fee_version',          v_fee_version,
      'paymob_order_id',      p_paymob_order_id,
      'server_recorded_at',   v_now
    ),
    v_player_vsp_fee, v_owner_vsp_fee, v_owner_net, v_gateway_fee,
    v_fee_version, v_channel, 'pending_reconciliation',
    v_now, v_now
  ) RETURNING id INTO v_tx_id;

  IF v_attempt.id IS NOT NULL THEN
    UPDATE public.payment_attempts
    SET status = 'paid', updated_at = v_now
    WHERE id = v_attempt.id;
  END IF;

  UPDATE public.bookings SET
    status                  = 'confirmed',
    is_paid                 = v_is_final,
    payment_status          = CASE WHEN v_is_final THEN 'paid' ELSE 'partially_paid' END,
    is_deposit_paid         = true,
    deposit_paid            = v_new_collected,
    gross_amount_charged    = v_new_gross,
    payment_transaction_id  = 'PAYMOB_' || p_paymob_transaction_id,
    paymob_txn_id           = p_paymob_transaction_id,
    paymob_order_id         = p_paymob_order_id,
    paymob_transaction_id   = p_paymob_transaction_id,
    payment_method          = v_payment_method,
    webhook_verified        = true,
    webhook_processed_at    = v_now,
    player_vsp_fee          = coalesce(player_vsp_fee, 0) + v_player_vsp_fee,
    owner_vsp_fee           = coalesce(owner_vsp_fee, 0) + v_owner_vsp_fee,
    total_vsp_commission    = coalesce(total_vsp_commission, 0) + v_total_vsp_comm,
    vsp_commission          = coalesce(vsp_commission, 0) + v_total_vsp_comm,
    owner_net_amount        = coalesce(owner_net_amount, 0) + v_owner_net,
    gateway_fee             = coalesce(gateway_fee, 0) + v_gateway_fee,
    fee_version             = coalesce(fee_version, v_fee_version),
    payment_channel_class   = coalesce(payment_channel_class, v_channel),
    updated_at              = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'idempotent', false,
    'transaction_id', v_tx_id,
    'booking_id', p_booking_id,
    'principal_amount', p_principal_amount,
    'gross_amount', p_gross_amount,
    'player_vsp_fee', v_player_vsp_fee,
    'owner_vsp_fee', v_owner_vsp_fee,
    'total_vsp_commission', v_total_vsp_comm,
    'owner_net_amount', v_owner_net,
    'gateway_fee', v_gateway_fee,
    'is_final_payment', v_is_final,
    'remaining_amount', round(greatest(coalesce(v_booking.total_price, 0) - v_new_collected, 0), 2)
  );
END;
$function$;

-- 6. Admin Paymob statement reconciliation RPC
CREATE OR REPLACE FUNCTION public.import_paymob_reconciliation_row(
  p_paymob_txn_id TEXT,
  p_actual_fee NUMERIC,
  p_channel_class TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role TEXT;
  v_tx record;
  v_diff NUMERIC(10,2);
  v_status TEXT;
BEGIN
  IF auth.uid() IS NOT NULL THEN
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

GRANT EXECUTE ON FUNCTION public.import_paymob_reconciliation_row(TEXT, NUMERIC, TEXT) TO authenticated, service_role;

COMMIT;
