-- 1. Fix confirm_cash_booking_atomic to preserve and reflect total collected price
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id uuid,
    p_owner_id uuid,
    p_total_price numeric DEFAULT NULL::numeric,
    p_collected_amount numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
    v_actual_deposit NUMERIC;
    v_total_paid NUMERIC;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    IF (COALESCE(auth.role(), '') NOT IN ('service_role'))
       AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role
        FROM public.users
        WHERE id = auth.uid();

        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()
            AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.'
            );
        END IF;
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
            USING ERRCODE = 'P0003', DETAIL = 'BOOKING_CANCELLED';
    END IF;

    IF v_booking.is_paid IS TRUE
       AND v_booking.payment_status = 'paid'
       AND LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً ككاش.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'commission', 0,
            'total_price', v_booking.total_price,
            'payment_method', 'cash'
        );
    END IF;

    IF p_collected_amount IS NOT NULL AND p_collected_amount > 0 THEN
        v_cash_amount := p_collected_amount;
    ELSE
        v_cash_amount := GREATEST(
            0,
            COALESCE(v_booking.total_price, p_total_price, 0)
            - COALESCE(v_booking.deposit_paid, 0)
        );
        IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
            v_cash_amount := v_booking.total_price;
        END IF;
    END IF;

    v_actual_deposit := COALESCE(v_booking.deposit_paid, 0.0);
    v_total_paid := COALESCE(v_booking.total_price, p_total_price, v_actual_deposit + v_cash_amount);

    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        payment_method = 'cash',
        status = 'confirmed',
        vsp_commission = 0,
        deposit_paid = v_total_paid,
        updated_at = v_now
    WHERE id = p_booking_id;

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
        v_booking.owner_id,
        p_booking_id,
        v_cash_amount,
        'cash_settlement',
        'completed',
        'cash',
        'تحصيل كاش مؤكد بالملعب لحجز #' || substring(p_booking_id::text, 1, 8),
        v_now
    )
    ON CONFLICT (booking_id) WHERE type = 'cash_settlement' AND status = 'completed'
    DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'commission', 0,
        'new_debt', 0,
        'is_blocked', false,
        'total_price', v_total_paid,
        'deposit_paid', v_total_paid,
        'payment_method', 'cash'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) FROM anon, public;


-- 2. Add owner_cancel_manual_booking_atomic
CREATE OR REPLACE FUNCTION public.owner_cancel_manual_booking_atomic(
    p_booking_id uuid,
    p_owner_id uuid,
    p_refund_deposit boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_deposit NUMERIC;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- Authorization check
    IF (COALESCE(auth.role(), '') NOT IN ('service_role'))
       AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()
            AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح.');
        END IF;
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', true, 'message', 'الحجز ملغي بالفعل مسبقاً.');
    END IF;

    v_deposit := COALESCE(v_booking.deposit_paid, 0.0);

    IF p_refund_deposit IS TRUE AND v_deposit > 0 THEN
        -- Record refund in transactions
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
            v_booking.owner_id,
            p_booking_id,
            v_deposit,
            'cash_refund',
            'completed',
            'cash',
            'استرداد عربون حجز يدوي ملغي: ' || COALESCE(v_booking.stadium_name, 'الملعب'),
            v_now,
            v_now
        );

        UPDATE public.bookings
        SET status = 'cancelled',
            deposit_paid = 0.0,
            is_deposit_paid = false,
            is_paid = false,
            cancellation_reason = 'تم إلغاء الحجز اليدوي ورد العربون للعميل',
            cancelled_at = v_now,
            updated_at = v_now
        WHERE id = p_booking_id;
    ELSE
        UPDATE public.bookings
        SET status = 'cancelled',
            cancellation_reason = CASE
                WHEN v_deposit > 0 THEN 'تم إلغاء الحجز اليدوي مع الاحتفاظ بالعربون كشرط جزائي'
                ELSE 'تم إلغاء الحجز اليدوي'
            END,
            cancelled_at = v_now,
            updated_at = v_now
        WHERE id = p_booking_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'deposit_refunded', p_refund_deposit AND v_deposit > 0,
        'refunded_amount', CASE WHEN p_refund_deposit AND v_deposit > 0 THEN v_deposit ELSE 0.0 END
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid, uuid, boolean) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid, uuid, boolean) FROM anon, public;
