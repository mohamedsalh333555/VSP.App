-- Read-only 2026-11-17 vsp-staging pg_get_functiondef snapshot.
-- NOT a migration. Only for disposable-Postgres idempotency testing.
CREATE OR REPLACE FUNCTION public.record_booking_payment_atomic(p_booking_id uuid, p_user_id uuid, p_paymob_transaction_id text, p_paymob_order_id text, p_payment_method text, p_principal_amount numeric, p_gross_amount numeric, p_is_deposit boolean DEFAULT false, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking          record;
  v_existing_tx      record;
  v_total_collected  numeric := 0;
  v_total_gross      numeric := 0;
  v_remaining_before numeric := 0;
  v_vsp_rate         numeric;
  v_gateway_rate     numeric;
  v_gateway_fixed    numeric;
  v_vsp_fee          numeric;
  v_gateway_fee      numeric;
  v_expected_gross   numeric;
  v_new_collected    numeric;
  v_new_gross        numeric;
  v_is_final         boolean;
  v_now              timestamptz := timezone('utc', now());
  v_tx_id            uuid;
  v_payment_method   text := lower(coalesce(p_payment_method, 'card'));
  v_card_origin      text := lower(coalesce(p_metadata->>'card_origin', 'local'));
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

  SELECT
    booking_vsp_rate,
    CASE
      WHEN v_payment_method = 'wallet'  THEN booking_paymob_wallet_rate
      WHEN v_card_origin   = 'foreign'  THEN booking_paymob_foreign_rate
      ELSE booking_paymob_local_rate
    END,
    booking_paymob_fixed_fee
  INTO v_vsp_rate, v_gateway_rate, v_gateway_fixed
  FROM public.platform_fee_config
  WHERE id = 1;

  IF v_vsp_rate IS NULL OR v_gateway_rate IS NULL OR v_gateway_fixed IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_fee_configuration_unavailable');
  END IF;

  v_vsp_fee        := round(p_principal_amount * v_vsp_rate,                       2);
  v_gateway_fee    := round(p_principal_amount * v_gateway_rate + v_gateway_fixed,  2);
  v_expected_gross := round(p_principal_amount + v_vsp_fee + v_gateway_fee,         2);

  IF abs(p_gross_amount - v_expected_gross) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'gross_amount_mismatch',
      'expected_gross_amount', v_expected_gross, 'received_gross_amount', p_gross_amount,
      'principal_amount', p_principal_amount, 'vsp_fee', v_vsp_fee, 'gateway_fee', v_gateway_fee);
  END IF;

  v_new_collected := round(v_total_collected + p_principal_amount, 2);
  v_new_gross     := round(v_total_gross     + p_gross_amount,     2);
  v_is_final      := v_new_collected >= round(coalesce(v_booking.total_price, 0), 2) - 0.01;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, gross_amount, type, status, payment_method,
    reference_number, paymob_transaction_id, description, metadata, created_at, updated_at
  ) VALUES (
    p_user_id, p_booking_id, p_principal_amount, p_gross_amount,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'payment' ELSE 'deposit' END,
    'completed', v_payment_method,
    p_paymob_transaction_id, p_paymob_transaction_id,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'دفع حجز ملعب' ELSE 'دفع عربون حجز ملعب' END,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'principal_amount',    p_principal_amount,
      'gross_amount_charged', p_gross_amount,
      'vsp_fee',             v_vsp_fee,
      'gateway_fee',         v_gateway_fee,
      'total_payment_fees',  round(v_vsp_fee + v_gateway_fee, 2),
      'paymob_order_id',     p_paymob_order_id,
      'server_recorded_at',  v_now,
      'paymob_fee_policy',   'contract_2026_09'
    ),
    v_now, v_now
  ) RETURNING id INTO v_tx_id;

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
    vsp_commission          = (SELECT coalesce(sum(coalesce((metadata->>'vsp_fee')::numeric,0)),0)
                               FROM public.transactions
                               WHERE booking_id = p_booking_id AND type IN ('payment','deposit') AND status = 'completed'),
    gateway_fee             = (SELECT coalesce(sum(coalesce((metadata->>'gateway_fee')::numeric,0)),0)
                               FROM public.transactions
                               WHERE booking_id = p_booking_id AND type IN ('payment','deposit') AND status = 'completed'),
    platform_fee            = (SELECT coalesce(sum(coalesce((metadata->>'vsp_fee')::numeric,0)),0)
                               FROM public.transactions
                               WHERE booking_id = p_booking_id AND type IN ('payment','deposit') AND status = 'completed'),
    updated_at              = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success',          true,
    'idempotent',       false,
    'transaction_id',   v_tx_id,
    'booking_id',       p_booking_id,
    'principal_amount', p_principal_amount,
    'gross_amount',     p_gross_amount,
    'vsp_fee',          v_vsp_fee,
    'gateway_fee',      v_gateway_fee,
    'total_collected',  v_new_collected,
    'gross_total',      v_new_gross,
    'remaining_amount', round(greatest(coalesce(v_booking.total_price,0) - v_new_collected, 0), 2),
    'is_final_payment', v_is_final,
    'payment_status',   CASE WHEN v_is_final THEN 'paid' ELSE 'partially_paid' END
  );
END;
$function$
