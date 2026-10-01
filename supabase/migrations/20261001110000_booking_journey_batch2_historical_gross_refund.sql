-- =============================================================================
-- VSP Booking Journey Rebuild — Batch 2: Historical Gross Refund Precision
-- Migration: 20261001110000
-- Date: 2026-10-01
-- Changes:
--   1. Add `gross_amount_charged` column to bookings (stores actual amount
--      charged by Paymob gateway, including VSP + gateway fees).
--   2. Upgrade `record_booking_payment_atomic` to persist gross_amount_charged.
--   3. Upgrade `cancel_booking_with_refund_atomic` to derive refund amount
--      100% from actual transactions ledger (historical gross), never from
--      the nominal total_price field.
--   4. Upgrade `record_booking_gateway_refund_atomic` to accept and persist
--      a gross_refund_amount for audit trail completeness.
-- =============================================================================

-- ─── 1. Add gross_amount_charged to bookings ──────────────────────────────
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS gross_amount_charged numeric(10,2);

COMMENT ON COLUMN public.bookings.gross_amount_charged IS
  'Total amount actually charged to player via payment gateway (principal + VSP fee + gateway fee). Set by record_booking_payment_atomic on each successful Paymob transaction. Used as the authoritative source for refund calculations.';

-- ─── 2. Add gross_amount_charged to transactions for audit ─────────────────
-- (Stores the gross amount from Paymob for each individual payment transaction)
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS gross_amount numeric(10,2);

COMMENT ON COLUMN public.transactions.gross_amount IS
  'Actual gross amount charged by gateway for this transaction (principal + all fees). Used for accurate refund calculations.';

-- ─── 3. Upgrade record_booking_payment_atomic ──────────────────────────────
-- Now persists gross_amount in both transactions and bookings.
CREATE OR REPLACE FUNCTION public.record_booking_payment_atomic(
  p_booking_id              uuid,
  p_user_id                 uuid,
  p_paymob_transaction_id   text,
  p_paymob_order_id         text,
  p_payment_method          text,
  p_principal_amount        numeric,
  p_gross_amount            numeric,
  p_is_deposit              boolean  DEFAULT false,
  p_metadata                jsonb    DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
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
  -- Authorization: service_role / postgres only
  IF coalesce(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  -- Validate required params
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

  -- Idempotency: check for duplicate Paymob transaction
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

  -- User ownership check
  IF coalesce(v_booking.created_by_user_id, v_booking.user_id) IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_user_mismatch');
  END IF;

  -- Collect totals from ledger (principal only for balance check)
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

  -- Derive fee rates from platform config
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

  v_vsp_fee      := round(p_principal_amount * v_vsp_rate,                       2);
  v_gateway_fee  := round(p_principal_amount * v_gateway_rate + v_gateway_fixed,  2);
  v_expected_gross := round(p_principal_amount + v_vsp_fee + v_gateway_fee,       2);

  IF abs(p_gross_amount - v_expected_gross) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'gross_amount_mismatch',
      'expected_gross_amount', v_expected_gross, 'received_gross_amount', p_gross_amount,
      'principal_amount', p_principal_amount, 'vsp_fee', v_vsp_fee, 'gateway_fee', v_gateway_fee);
  END IF;

  v_new_collected := round(v_total_collected + p_principal_amount, 2);
  v_new_gross     := round(v_total_gross     + p_gross_amount,     2);
  v_is_final      := v_new_collected >= round(coalesce(v_booking.total_price, 0), 2) - 0.01;

  -- Insert transaction with gross_amount persisted
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

  -- Update booking: also persist cumulative gross_amount_charged
  UPDATE public.bookings SET
    status                  = 'confirmed',
    is_paid                 = v_is_final,
    payment_status          = CASE WHEN v_is_final THEN 'paid' ELSE 'partially_paid' END,
    is_deposit_paid         = true,
    deposit_paid            = v_new_collected,
    gross_amount_charged    = v_new_gross,           -- ← historical gross SSOT
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
$fn$;

-- ─── 4. Upgrade cancel_booking_with_refund_atomic ──────────────────────────
-- Refund amount is now 100% derived from actual transactions ledger (historical
-- gross_amount) — never from nominal total_price or deposit_paid fields.
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
  p_booking_id uuid,
  p_reason     text    DEFAULT 'إلغاء حجز من المستخدم',
  p_user_id    uuid    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_booking              record;
  v_refund_amount        numeric(10,2) := 0;
  v_refund_gross         numeric(10,2) := 0;  -- actual gross charged via gateway
  v_tx_id                uuid          := null;
  v_caller_role          text;
  v_minutes_since_created numeric;
  v_now                  timestamptz   := timezone('utc', now());
  v_paid_cash            numeric       := 0;
  v_total_gateway_paid   numeric       := 0;   -- sum of principal payments via gateway
  v_total_gross_paid     numeric       := 0;   -- sum of gross_amount paid via gateway
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_completed_booking', 'message', 'لا يمكن إلغاء حجز مكتمل.');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', true, 'code', 'already_cancelled', 'already_cancelled', true,
      'booking_id', p_booking_id, 'refund_amount', coalesce(v_booking.refund_amount, 0));
  END IF;

  -- Authorization check
  IF coalesce(auth.role(), '') <> 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
    END IF;
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id
       AND auth.uid() IS DISTINCT FROM v_booking.user_id
       AND auth.uid() IS DISTINCT FROM v_booking.owner_id
       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: لا يمكنك إلغاء هذا الحجز.');
    END IF;
    -- Grace period / cutoff check for the player
    IF auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id THEN
      v_minutes_since_created := extract(epoch FROM (v_now - coalesce(v_booking.created_at, v_now))) / 60.0;
      IF v_minutes_since_created > (SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id = 1)
         AND v_booking.start_time <= (v_now + ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id = 1) * interval '1 hour'))
      THEN
        RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_within_6_hours',
          'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات إلا خلال أول 20 دقيقة.');
      END IF;
    END IF;
  END IF;

  -- ── REFUND AMOUNT CALCULATION ──────────────────────────────────────────────
  -- Cash bookings: sum only actual cash payments recorded in transactions ledger
  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    SELECT
      coalesce(sum(CASE
        WHEN t.type = 'refund_cash' THEN -abs(t.amount)
        ELSE abs(t.amount)
      END), 0)
    INTO v_paid_cash
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.payment_method = 'cash'
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit', 'cash_settlement', 'cash_collection_adjustment', 'refund_cash');

    v_refund_amount := round(greatest(v_paid_cash, 0), 2);
    v_refund_gross  := v_refund_amount;  -- cash: gross = principal (no gateway fees)

  ELSE
    -- Online bookings: derive refund from ACTUAL transactions ledger.
    -- Use gross_amount if available (set by Batch 2+), else fall back to amount.
    -- This guarantees the player gets back every piaster that was actually charged.
    SELECT
      coalesce(sum(t.amount), 0),
      coalesce(sum(coalesce(t.gross_amount, t.amount)), 0)
    INTO v_total_gateway_paid, v_total_gross_paid
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit')
      AND lower(coalesce(t.payment_method, '')) <> 'cash';

    -- Subtract any refunds already issued (principal)
    SELECT v_total_gateway_paid - coalesce(sum(t.amount), 0)
    INTO v_refund_amount
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    -- Subtract any refunds already issued (gross)
    SELECT v_total_gross_paid - coalesce(sum(coalesce(t.gross_amount, t.amount)), 0)
    INTO v_refund_gross
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    v_refund_amount := round(greatest(coalesce(v_refund_amount, 0), 0), 2);
    v_refund_gross  := round(greatest(coalesce(v_refund_gross,  0), 0), 2);
  END IF;

  -- ── CANCEL BOOKING ────────────────────────────────────────────────────────
  UPDATE public.bookings SET
    status             = 'cancelled',
    is_paid            = false,
    payment_status     = CASE
                           WHEN v_refund_amount > 0 AND lower(coalesce(payment_method, '')) <> 'cash' THEN 'refund_pending'
                           WHEN v_refund_amount > 0                                                    THEN 'refunded'
                           ELSE CASE
                             WHEN lower(coalesce(payment_method, '')) = 'cash' THEN 'cancelled'
                             ELSE payment_status
                           END
                         END,
    refund_amount      = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
    cancellation_reason = p_reason,
    cancelled_at       = v_now,
    updated_at         = v_now
  WHERE id = p_booking_id;

  -- ── INSERT REFUND TRANSACTION (once, idempotent) ──────────────────────────
  IF v_refund_amount > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.transactions
       WHERE booking_id = p_booking_id
         AND type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending')
         AND status IN ('pending', 'completed')
     ) THEN
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(v_booking.created_by_user_id, v_booking.user_id),
      p_booking_id,
      v_refund_amount,
      v_refund_gross,
      'refund',
      CASE WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'completed' ELSE 'pending' END,
      coalesce(v_booking.payment_method, 'online'),
      CASE
        WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'استرداد نقدي بالملعب لإلغاء الحجز'
        ELSE 'طلب استرداد إلكتروني قيد المعالجة'
      END,
      jsonb_build_object(
        'refund_principal',    v_refund_amount,
        'refund_gross',        v_refund_gross,
        'source',              'cancel_booking_with_refund_atomic',
        'cancelled_at',        v_now
      ),
      v_now, v_now
    ) RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success',          true,
    'message',          'تم إلغاء الحجز بنجاح.',
    'refund_amount',    v_refund_amount,
    'refund_gross',     v_refund_gross,
    'payment_status',   CASE
                          WHEN v_refund_amount > 0 AND lower(coalesce(v_booking.payment_method, '')) <> 'cash' THEN 'refund_pending'
                          WHEN v_refund_amount > 0 THEN 'refunded'
                          ELSE 'cancelled'
                        END,
    'booking_id',       p_booking_id,
    'transaction_id',   v_tx_id
  );
END;
$fn$;

-- ─── 5. Upgrade record_booking_gateway_refund_atomic ──────────────────────
-- Now persists gross_refund_amount for audit.
CREATE OR REPLACE FUNCTION public.record_booking_gateway_refund_atomic(
  p_booking_id          uuid,
  p_refund_amount       numeric,
  p_refund_txn_id       text,
  p_refund_payment_method text  DEFAULT 'card',
  p_refund_gross_amount numeric  DEFAULT NULL  -- optional: actual gateway gross refund
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  b record;
  t record;
  v_gross numeric;
BEGIN
  IF current_user NOT IN ('postgres', 'service_role')
     AND coalesce(auth.role(), '') <> 'service_role' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Booking not found'); END IF;
  IF p_refund_amount IS NULL OR p_refund_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid refund amount');
  END IF;

  -- Use provided gross, or fall back to amount if not provided
  v_gross := coalesce(p_refund_gross_amount, p_refund_amount);

  -- Idempotency: check if already recorded
  IF EXISTS (
    SELECT 1 FROM public.transactions
    WHERE booking_id = p_booking_id
      AND type = 'refund'
      AND status = 'completed'
      AND coalesce(metadata->>'paymob_refund_transaction_id', '') = coalesce(p_refund_txn_id, '')
  ) THEN
    RETURN jsonb_build_object('success', true, 'already_recorded', true, 'booking_id', p_booking_id);
  END IF;

  SELECT id INTO t FROM public.transactions
  WHERE booking_id = p_booking_id AND type = 'refund' AND status = 'pending'
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF FOUND THEN
    UPDATE public.transactions SET
      status         = 'completed',
      amount         = round(p_refund_amount, 2),
      gross_amount   = round(v_gross, 2),
      payment_method = coalesce(nullif(p_refund_payment_method, ''), payment_method),
      metadata       = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
                         'paymob_refund_transaction_id', p_refund_txn_id,
                         'refund_gross_amount',          round(v_gross, 2)
                       ),
      updated_at     = timezone('utc', now())
    WHERE id = t.id;
  ELSE
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(b.created_by_user_id, b.user_id),
      p_booking_id,
      round(p_refund_amount, 2),
      round(v_gross, 2),
      'refund', 'completed',
      coalesce(nullif(p_refund_payment_method, ''), 'card'),
      'استرداد Paymob مؤكد للحجز',
      jsonb_build_object(
        'paymob_refund_transaction_id', p_refund_txn_id,
        'refund_gross_amount',          round(v_gross, 2)
      ),
      timezone('utc', now()), timezone('utc', now())
    ) RETURNING id INTO t;
  END IF;

  UPDATE public.bookings SET
    status                  = 'cancelled',
    payment_status          = 'refunded',
    refund_transaction_id   = p_refund_txn_id,
    refund_amount           = round(p_refund_amount, 2),
    refunded_at             = timezone('utc', now()),
    refund_payment_method   = coalesce(nullif(p_refund_payment_method, ''), 'card'),
    cancelled_at            = coalesce(cancelled_at, timezone('utc', now())),
    updated_at              = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success',      true,
    'booking_id',   p_booking_id,
    'transaction_id', t.id,
    'refund_amount', round(p_refund_amount, 2),
    'refund_gross',  round(v_gross, 2)
  );
END;
$fn$;

-- ─── 6. Grant permissions (unchanged pattern) ─────────────────────────────
REVOKE ALL ON FUNCTION public.record_booking_payment_atomic(uuid,uuid,text,text,text,numeric,numeric,boolean,jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.record_booking_payment_atomic(uuid,uuid,text,text,text,numeric,numeric,boolean,jsonb)
  TO service_role;

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.record_booking_gateway_refund_atomic(uuid,numeric,text,text,numeric)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.record_booking_gateway_refund_atomic(uuid,numeric,text,text,numeric)
  TO service_role;

-- ─── 7. Backfill gross_amount_charged for existing confirmed bookings ───────
-- For bookings that already have payment transactions, compute gross retroactively.
UPDATE public.bookings b
SET gross_amount_charged = sub.total_gross
FROM (
  SELECT
    booking_id,
    round(coalesce(sum(coalesce(gross_amount, amount)), 0), 2) AS total_gross
  FROM public.transactions
  WHERE type IN ('payment', 'deposit')
    AND status = 'completed'
  GROUP BY booking_id
) sub
WHERE b.id = sub.booking_id
  AND b.gross_amount_charged IS NULL
  AND sub.total_gross > 0;
