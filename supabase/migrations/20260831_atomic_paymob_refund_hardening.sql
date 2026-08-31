-- ==============================================================================
-- ATOMIC PAYMOB REFUND HARDENING & INTEGRATION MIGRATION
-- ==============================================================================

-- 1. Ensure refund fields exist on bookings table
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS refund_amount NUMERIC(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS refund_txn_id TEXT DEFAULT NULL;

-- 2. Update cancel_booking_with_refund_atomic SQL RPC
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT 'Cancelled by user'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_is_paid BOOLEAN := FALSE;
    v_tx_id UUID;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- Security Check: Caller must be the player, stadium owner, or admin
    IF v_booking.created_by_user_id <> p_user_id 
       AND v_booking.player_id <> p_user_id 
       AND v_booking.owner_id <> p_user_id 
       AND NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND role = 'admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإلغاء هذا الحجز.');
    END IF;

    -- Check 2-hour cutoff rule for player cancellations
    IF v_booking.created_by_user_id = p_user_id AND v_booking.start_time <= (timezone('utc'::text, now()) + INTERVAL '2 hours') THEN
        RETURN jsonb_build_object(
            'success', false, 
            'refund_reason', 'no_refund_too_late',
            'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة الاسترداد.'
        );
    END IF;

    -- Determine if booking has an online paid amount
    v_is_paid := (v_booking.payment_status IN ('paid', 'confirmed') OR v_booking.is_paid = TRUE OR v_booking.is_deposit_paid = TRUE);
    IF v_is_paid THEN
        v_refund_amount := COALESCE(v_booking.deposit_paid, v_booking.total_price, v_booking.deposit_amount, 0.00);
    END IF;

    -- If booking is paid and online, indicate to the caller that the Paymob Edge Function must process the refund
    IF v_is_paid AND v_refund_amount > 0 AND (v_booking.paymob_txn_id IS NOT NULL OR v_booking.payment_transaction_id IS NOT NULL) THEN
        RETURN jsonb_build_object(
            'success', true,
            'requires_gateway_refund', true,
            'refund_amount', v_refund_amount,
            'refund_reason', 'full_refund',
            'paymob_txn_id', COALESCE(v_booking.paymob_txn_id, v_booking.payment_transaction_id),
            'message', 'يتطلب استرداد المبلغ عبر بوابة الدفع Paymob.'
        );
    END IF;

    -- For unpaid bookings or cash walk-ins: perform immediate soft cancellation
    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = CASE WHEN v_is_paid AND v_refund_amount > 0 THEN 'refunded' ELSE 'unpaid' END,
        cancellation_reason = p_reason,
        refund_amount = v_refund_amount,
        cancelled_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- Log transaction ledger if applicable
    IF v_refund_amount > 0 THEN
        INSERT INTO public.transactions (
            user_id,
            booking_id,
            amount,
            type,
            status,
            payment_method,
            description,
            created_at
        ) VALUES (
            p_user_id,
            p_booking_id,
            v_refund_amount,
            'refund',
            'completed',
            v_booking.payment_method,
            'استرداد حجز ملغى: ' || v_booking.stadium_name,
            timezone('utc'::text, now())
        ) RETURNING id INTO v_tx_id;
    END IF;

    -- Notify Stadium Owner
    IF v_booking.owner_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            created_at
        ) VALUES (
            v_booking.owner_id,
            'إلغاء حجز في ملعبك ⚠️',
            'قام اللاعب بإلغاء حجزه المقرر في ' || v_booking.stadium_name || ' وتم إتاحة الموعد مجدداً.',
            'booking_cancelled',
            timezone('utc'::text, now())
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'requires_gateway_refund', false,
        'refund_amount', v_refund_amount,
        'refund_reason', CASE WHEN v_refund_amount > 0 THEN 'full_refund' ELSE 'unpaid_cancellation' END,
        'message', 'تم إلغاء الحجز بنجاح.'
    );
END;
$$;
