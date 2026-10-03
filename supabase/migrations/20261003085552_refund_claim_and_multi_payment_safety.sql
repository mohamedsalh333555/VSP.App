CREATE OR REPLACE FUNCTION public.claim_booking_gateway_refund_atomic(
  p_booking_id uuid,
  p_reason text DEFAULT 'cancelled'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_existing_refund record;
  v_source_tx record;
  v_source_count integer := 0;
  v_now timestamptz := timezone('utc', now());
  v_lease_until timestamptz;
  v_refund_amount numeric(10,2);
  v_refund_gross numeric(10,2);
  v_source_paymob_id text;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'booking_not_found'); END IF;

  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    RETURN jsonb_build_object('success', false, 'error', 'cash_booking_not_supported');
  END IF;

  SELECT count(*) INTO v_source_count
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND status = 'completed'
    AND type IN ('payment', 'deposit')
    AND lower(coalesce(payment_method, '')) <> 'cash'
    AND (paymob_transaction_id IS NOT NULL OR reference_number IS NOT NULL);

  IF v_source_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_refundable_paymob_payment');
  END IF;

  IF v_source_count > 1 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'multiple_paymob_payments_require_manual_refund',
      'payment_count', v_source_count
    );
  END IF;

  SELECT *
  INTO v_source_tx
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND status = 'completed'
    AND type IN ('payment', 'deposit')
    AND lower(coalesce(payment_method, '')) <> 'cash'
    AND (paymob_transaction_id IS NOT NULL OR reference_number IS NOT NULL)
  ORDER BY created_at DESC
  LIMIT 1;

  v_source_paymob_id := coalesce(v_source_tx.paymob_transaction_id, v_source_tx.reference_number);
  IF nullif(trim(v_source_paymob_id), '') IS NULL OR coalesce(v_source_tx.amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_refundable_paymob_transaction');
  END IF;

  v_refund_amount := round(coalesce(v_source_tx.amount, 0), 2);
  v_refund_gross := round(coalesce(v_source_tx.gross_amount, v_source_tx.amount), 2);
  v_lease_until := v_now + interval '5 minutes';

  SELECT id, status, metadata
  INTO v_existing_refund
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND type = 'refund'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF FOUND AND v_existing_refund.status = 'completed' THEN
    RETURN jsonb_build_object('success', true, 'already_refunded', true, 'booking_id', p_booking_id);
  END IF;

  IF FOUND AND v_existing_refund.status = 'pending' THEN
    v_meta := coalesce(v_existing_refund.metadata, '{}'::jsonb);
    IF coalesce((v_meta->>'refund_lease_expires_at')::timestamptz, 'epoch'::timestamptz) > v_now THEN
      RETURN jsonb_build_object('success', false, 'error', 'refund_in_progress',
        'booking_id', p_booking_id, 'refund_transaction_id', v_existing_refund.id,
        'lease_expires_at', v_meta->>'refund_lease_expires_at');
    END IF;
  END IF;

  IF FOUND AND v_existing_refund.status = 'pending' THEN
    UPDATE public.transactions SET
      amount = v_refund_amount,
      gross_amount = v_refund_gross,
      payment_method = coalesce(nullif(v_source_tx.payment_method, ''), payment_method),
      metadata = v_meta || jsonb_build_object(
        'source_transaction_id', v_source_tx.id,
        'paymob_transaction_id', v_source_paymob_id,
        'refund_principal', v_refund_amount,
        'refund_gross', v_refund_gross,
        'refund_reason', coalesce(p_reason, 'cancelled'),
        'refund_lease_expires_at', v_lease_until,
        'refund_claimed_at', v_now
      ),
      updated_at = v_now
    WHERE id = v_existing_refund.id;
  ELSE
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, reference_number, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(v_booking.created_by_user_id, v_booking.user_id),
      p_booking_id, v_refund_amount, v_refund_gross, 'refund', 'pending',
      coalesce(nullif(v_source_tx.payment_method, ''), 'paymob'),
      'REFUND_CLAIM_' || p_booking_id::text,
      'استرداد Paymob قيد المعالجة',
      jsonb_build_object(
        'source_transaction_id', v_source_tx.id,
        'paymob_transaction_id', v_source_paymob_id,
        'refund_principal', v_refund_amount,
        'refund_gross', v_refund_gross,
        'refund_reason', coalesce(p_reason, 'cancelled'),
        'refund_lease_expires_at', v_lease_until,
        'refund_claimed_at', v_now
      ),
      v_now, v_now
    )
    RETURNING id INTO v_existing_refund.id;
  END IF;

  UPDATE public.bookings SET
    status = 'cancelled',
    payment_status = 'refund_pending',
    payment_reconcile_state = 'refund_pending',
    refund_amount = v_refund_amount,
    cancellation_reason = coalesce(p_reason, cancellation_reason),
    cancelled_at = coalesce(cancelled_at, v_now),
    updated_at = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true, 'claimed', true,
    'refund_transaction_id', v_existing_refund.id,
    'source_transaction_id', v_source_tx.id,
    'paymob_transaction_id', v_source_paymob_id,
    'refund_amount', v_refund_amount,
    'refund_gross_amount', v_refund_gross,
    'lease_expires_at', v_lease_until
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'refund_already_claimed');
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.claim_booking_gateway_refund_atomic(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_booking_gateway_refund_atomic(uuid, text) TO service_role;