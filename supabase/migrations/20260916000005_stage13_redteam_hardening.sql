-- ==============================================================================
-- MIGRATION: 20260916000005_stage13_redteam_hardening.sql
-- STAGE 13: Fraud, Abuse & Red-Team Security Hardening
-- ==============================================================================

-- 1. Bulletproof Booking Sensitive Fields Protection Trigger
CREATE OR REPLACE FUNCTION public.protect_booking_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin boolean := false;
BEGIN
  -- 1. Allow internal postgres and service_role system processes ONLY when no client auth identity is set
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    RETURN NEW;
  END IF;

  -- 2. Allow trusted internal atomic RPCs within the transaction via system override
  IF current_setting('vsp.system_override', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- 3. Verify if caller is an authoritative administrator
  IF auth.uid() IS NOT NULL THEN
    SELECT (role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))
    INTO v_is_admin
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  IF COALESCE(v_is_admin, false) THEN
    RETURN NEW;
  END IF;

  -- 4. For normal authenticated users (players / owners), strictly block direct mutation of sensitive financial/state fields:
  -- A. Payment State & Confirmation:
  IF (OLD.is_paid IS DISTINCT FROM NEW.is_paid AND NEW.is_paid = true) OR
     (OLD.payment_status IS DISTINCT FROM NEW.payment_status AND NEW.payment_status IN ('paid', 'completed', 'refunded')) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Direct manipulation of payment status is prohibited. Use payment RPCs or official webhooks.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_PAYMENT_STATE_UPDATE';
  END IF;

  -- B. Booking Status Confirmation & Completion:
  IF (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'completed')) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Direct confirmation or completion of bookings is prohibited. Confirmation must occur via atomic checkout RPC.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_BOOKING_STATUS_UPDATE';
  END IF;

  -- C. Financial Price & Deposit Tampering:
  IF (OLD.total_price IS DISTINCT FROM NEW.total_price AND (OLD.payment_transaction_id NOT LIKE 'MANUAL%')) OR
     (OLD.deposit_paid IS DISTINCT FROM NEW.deposit_paid) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Booking prices and deposits cannot be modified directly.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_PRICE_MODIFICATION';
  END IF;

  -- D. Refund Transaction & Amount Tampering:
  IF (OLD.refund_transaction_id IS DISTINCT FROM NEW.refund_transaction_id) OR
     (OLD.refund_amount IS DISTINCT FROM NEW.refund_amount) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Refund transaction details cannot be modified directly.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_REFUND_FIELD_MODIFICATION';
  END IF;

  RETURN NEW;
END;
$$;

-- Ensure trigger is active BEFORE UPDATE on bookings
DROP TRIGGER IF EXISTS trg_protect_booking_sensitive_fields ON public.bookings;
CREATE TRIGGER trg_protect_booking_sensitive_fields
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_booking_sensitive_fields();

-- 2. Explicitly add system_override to cancel_booking_with_refund_atomic
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id UUID,
    p_reason TEXT DEFAULT 'إلغاء حجز من المستخدم'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_tx_id UUID := NULL;
    v_caller_role TEXT;
    v_minutes_since_created NUMERIC;
    v_commission_amount NUMERIC := 0.00;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- Explicit system override for atomic internal mutation
    PERFORM set_config('vsp.system_override', 'true', true);

    -- 1. Row lock: Lock target booking row to prevent concurrent race conditions
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. Invariant: Cannot cancel already completed booking
    IF v_booking.status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'cannot_cancel_completed_booking',
            'message', 'عذراً، لا يمكن إلغاء أو استرداد حجز لمباراة مكتملة تم حضورها بالفعل.'
        );
    END IF;

    -- 3. Idempotency & State Guard: If booking is ALREADY cancelled, return safely without duplicating refund
    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', true,
            'code', 'already_cancelled',
            'already_cancelled', true,
            'message', 'الحجز ملغي بالفعل مسبقاً.',
            'booking_id', p_booking_id,
            'refund_amount', COALESCE(v_booking.refund_amount, 0.00)
        );
    END IF;

    -- 4. Authorization Check
    IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

        IF (auth.uid() != v_booking.created_by_user_id)
           AND (auth.uid() != v_booking.user_id)
           AND (auth.uid() != v_booking.owner_id)
           AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) THEN
            RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: يمكنك فقط إلغاء الحجوزات الخاصة بك أو بملاعبك.');
        END IF;
    END IF;

    -- 5. Check 6-hour cutoff rule for players (with 20-minute grace window)
    IF (COALESCE(auth.role(), '') != 'service_role') AND (auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id) THEN
        v_minutes_since_created := EXTRACT(EPOCH FROM (v_now - COALESCE(v_booking.created_at, v_now))) / 60.0;
        
        IF v_minutes_since_created > 20.0 AND v_booking.start_time <= (v_now + INTERVAL '6 hours') THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'cannot_cancel_within_6_hours',
                'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من إتمام الحجز وفقاً للائحة).'
            );
        END IF;
    END IF;

    -- 6. Calculate refund amount if payment was confirmed
    IF (v_booking.payment_status IN ('paid', 'confirmed') OR v_booking.is_paid IS TRUE OR v_booking.is_deposit_paid IS TRUE) THEN
        v_refund_amount := COALESCE(v_booking.deposit_paid, v_booking.deposit_amount, v_booking.total_price, 0.00);
    END IF;

    -- 7. Update booking status to cancelled, reset is_paid to false, set payment_status
    UPDATE public.bookings
    SET status = 'cancelled',
        is_paid = false,
        payment_status = CASE 
            WHEN v_refund_amount > 0 AND LOWER(COALESCE(payment_method, '')) != 'cash' THEN 'refund_pending' 
            WHEN v_refund_amount > 0 THEN 'refunded'
            ELSE payment_status 
        END,
        refund_amount = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
        cancellation_reason = p_reason,
        cancelled_at = v_now,
        updated_at = v_now
    WHERE id = p_booking_id;

    -- 8. If cash booking that was confirmed had 2% commission added to owner debt, reverse it atomically
    IF LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' AND (v_booking.is_paid IS TRUE OR v_booking.payment_status = 'paid') THEN
        v_commission_amount := COALESCE(v_booking.vsp_commission, round(COALESCE(v_booking.total_price, 0) * 0.02, 2));
        IF v_commission_amount > 0 AND v_booking.owner_id IS NOT NULL THEN
            UPDATE public.users
            SET accumulated_cash_debt = GREATEST(0.00, COALESCE(accumulated_cash_debt, 0.00) - v_commission_amount),
                is_debt_blocked = (GREATEST(0.00, COALESCE(accumulated_cash_debt, 0.00) - v_commission_amount) >= COALESCE(debt_limit, 500.00)),
                updated_at = v_now
            WHERE id = v_booking.owner_id;
        END IF;
    END IF;

    -- 9. Insert refund transaction ONLY IF one does not already exist for this booking (Strict Idempotency)
    IF v_refund_amount > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.transactions 
            WHERE booking_id = p_booking_id 
              AND type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending')
        ) THEN
            INSERT INTO public.transactions (
                user_id,
                booking_id,
                amount,
                type,
                status,
                payment_method,
                description,
                created_at,
                updated_at
            ) VALUES (
                COALESCE(v_booking.created_by_user_id, v_booking.user_id),
                p_booking_id,
                v_refund_amount,
                'refund',
                CASE WHEN LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' THEN 'completed' ELSE 'pending' END,
                COALESCE(v_booking.payment_method, 'online'),
                CASE WHEN LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' 
                     THEN 'استرداد نقدي فوري بالملعب لإلغاء الحجز: ' || p_reason
                     ELSE 'طلب استرداد إلكتروني قيد المعالجة البنكية: ' || p_reason 
                END,
                v_now,
                v_now
            ) RETURNING id INTO v_tx_id;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم إلغاء الحجز بنجاح.',
        'refund_amount', v_refund_amount,
        'payment_status', CASE WHEN v_refund_amount > 0 AND LOWER(COALESCE(v_booking.payment_method, '')) != 'cash' THEN 'refund_pending' ELSE 'refunded' END,
        'booking_id', p_booking_id,
        'transaction_id', v_tx_id
    );
END;
$$;
