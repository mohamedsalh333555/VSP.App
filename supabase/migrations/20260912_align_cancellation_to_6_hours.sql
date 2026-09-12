-- ==============================================================================
-- MIGRATION: 20260912_align_cancellation_to_6_hours.sql
-- DESCRIPTION: Update cancel_booking_with_refund_atomic cutoff from 2 hours to 6 hours
--              incorporating the official 20-minute immediate grace window.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id uuid,
    p_user_id uuid,
    p_reason text DEFAULT 'Cancelled by user'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_tx_id UUID;
    v_caller_role TEXT;
    v_minutes_since_created NUMERIC;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 🔒 التحقق الصارم من هوية المستدعي (Authorization Check)
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

        IF (auth.uid() != v_booking.created_by_user_id)
           AND (auth.uid() != v_booking.owner_id)
           AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: يمكنك فقط إلغاء الحجوزات الخاصة بك أو بملاعبك.');
        END IF;
    END IF;

    -- Check 6-hour cutoff rule for players (with 20-minute grace window for quick buyer remorse)
    IF (auth.role() = 'service_role' OR auth.uid() = v_booking.created_by_user_id) THEN
        v_minutes_since_created := EXTRACT(EPOCH FROM (timezone('utc'::text, now()) - COALESCE(v_booking.created_at, timezone('utc'::text, now())))) / 60.0;
        
        -- If older than 20 minutes and match starts in <= 6 hours, block cancellation
        IF v_minutes_since_created > 20.0 AND v_booking.start_time <= (timezone('utc'::text, now()) + INTERVAL '6 hours') THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'cannot_cancel_within_6_hours',
                'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من إتمام الحجز وفقاً للائحة).'
            );
        END IF;
    END IF;

    -- Calculate refund amount if online payment was made
    IF v_booking.payment_status = 'paid' OR v_booking.payment_status = 'confirmed' THEN
        v_refund_amount := COALESCE(v_booking.deposit_amount, v_booking.deposit_paid, v_booking.total_price, 0.00);
    END IF;

    -- Update booking status to cancelled
    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = CASE WHEN v_refund_amount > 0 THEN 'refunded' ELSE payment_status END,
        cancellation_reason = p_reason,
        cancelled_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- Record refund transaction if applicable
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
            v_booking.created_by_user_id,
            p_booking_id,
            v_refund_amount,
            'refund',
            'completed',
            COALESCE(v_booking.payment_method, 'online'),
            'استرداد تلقائي لإلغاء الحجز قبل المهلة المحددة: ' || p_reason,
            timezone('utc'::text, now())
        ) RETURNING id INTO v_tx_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم إلغاء الحجز بنجاح.',
        'refund_amount', v_refund_amount,
        'booking_id', p_booking_id
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, uuid, text) TO authenticated, service_role;
