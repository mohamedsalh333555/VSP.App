-- Migration: 20260925060000_fix_hybrid_deposit_accounting_and_past_cash_settlement.sql
-- Description:
--   1. Harden confirm_cash_booking_atomic:
--      - Preserve actual online deposit in deposit_paid (do not overwrite with total_price for hybrid bookings).
--      - Keep original online payment_method for hybrid bookings so it is accounted correctly.
--      - If booking is past its end_time, transition to 'completed' instead of rolling back to 'confirmed'.
--      - Record exact cash collected in transactions (cash_settlement).
--   2. Fix get_owner_financial_summary:
--      - Count only actual online portion (deposit_paid) for hybrid bookings into withdrawable digital balance.
--      - Count partially paid online bookings with deposits into escrow_online_revenue until match completion.
--      - Include no-show bookings with deposits as earned compensation for the owner.
--      - Correctly calculate cash revenue from pitch collections.
--   3. Harden owner_record_no_show_atomic:
--      - Automatically credit online deposit as owner compensation upon no-show.

-- 1. confirm_cash_booking_atomic
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
    v_total_price NUMERIC;
    v_target_status TEXT;
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
       AND v_booking.payment_status = 'paid' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'commission', 0,
            'total_price', v_booking.total_price,
            'payment_method', v_booking.payment_method
        );
    END IF;

    v_total_price := COALESCE(v_booking.total_price, p_total_price, 0.0);
    v_actual_deposit := COALESCE(v_booking.deposit_paid, 0.0);

    IF p_collected_amount IS NOT NULL AND p_collected_amount > 0 THEN
        v_cash_amount := p_collected_amount;
    ELSE
        IF v_actual_deposit > 0 AND v_actual_deposit < v_total_price THEN
            v_cash_amount := v_total_price - v_actual_deposit;
        ELSE
            v_cash_amount := v_total_price;
        END IF;
    END IF;

    IF v_now >= v_booking.end_time OR v_booking.status = 'completed' THEN
        v_target_status := 'completed';
    ELSE
        v_target_status := 'confirmed';
    END IF;

    IF v_actual_deposit > 0 AND v_actual_deposit < v_total_price THEN
        UPDATE public.bookings
        SET is_paid = true,
            payment_status = 'paid',
            status = v_target_status,
            deposit_paid = v_actual_deposit,
            vsp_commission = 0,
            updated_at = v_now
        WHERE id = p_booking_id;
    ELSE
        UPDATE public.bookings
        SET is_paid = true,
            payment_status = 'paid',
            payment_method = 'cash',
            status = v_target_status,
            deposit_paid = v_total_price,
            vsp_commission = 0,
            updated_at = v_now
        WHERE id = p_booking_id;
    END IF;

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
    DO UPDATE SET
        amount = EXCLUDED.amount,
        updated_at = v_now;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'deposit_paid', v_actual_deposit,
        'total_price', v_total_price,
        'commission', 0,
        'status', v_target_status,
        'payment_status', 'paid'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) FROM anon, public;


-- 2. get_owner_financial_summary
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_completed_online_rev NUMERIC := 0.0;
    v_escrow_online_rev NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_completed_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_completed_cash_rev NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
    v_debt_limit NUMERIC := 500.0;
    v_is_debt_blocked BOOLEAN := false;
    v_completed_bookings_count INT := 0;
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id != p_owner_id
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    SELECT accumulated_cash_debt, debt_limit, is_debt_blocked
    INTO v_accumulated_debt, v_debt_limit, v_is_debt_blocked
    FROM public.users WHERE id = p_owner_id;

    -- ✅ أرباح المنصة الإلكترونية القابلة للسحب (المكتملة + No-Show الذي فيه عربون)
    -- للحجوزات الإلكترونية الكاملة: يحسب total_price
    -- للحجوزات الهجينة (عربون + كاش): يحسب فقط deposit_paid المسدد إلكترونياً
    SELECT
        COALESCE(SUM(
            CASE 
                WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
                ELSE total_price
            END
        ), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0),
        COUNT(*)
    INTO v_completed_online_rev, v_total_gateway_fees, v_total_vsp_commission, v_completed_bookings_count
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status IN ('completed', 'no_show');

    -- ⏳ الضمان المحتجز (Escrow) - الحجوزات القادمة المؤكدة (سواء مسددة كلياً أو جزئياً بالعربون)
    SELECT COALESCE(SUM(
        CASE 
            WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
            ELSE total_price
        END
    ), 0.0)
    INTO v_escrow_online_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status IN ('paid', 'partially_paid') OR is_paid = true OR is_deposit_paid = true)
      AND status = 'confirmed';

    v_net_completed_earnings := v_completed_online_rev;

    -- المسحوبات المكتملة
    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    -- طلبات السحب قيد الانتظار
    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    -- الرصيد المتاح للسحب
    v_available_balance := GREATEST(0.0, v_completed_online_rev - v_total_withdrawn - v_pending_payouts);

    -- 💵 دخل الكاش المحصل بالملعب
    SELECT COALESCE(SUM(
        CASE 
            WHEN LOWER(COALESCE(payment_method, '')) = 'cash' THEN total_price
            WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN (total_price - deposit_paid)
            ELSE 0.0
        END
    ), 0.0) INTO v_completed_cash_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'total_online_revenue', ROUND(v_completed_online_rev + v_escrow_online_rev, 2),
        'completed_online_revenue', ROUND(v_completed_online_rev, 2),
        'escrow_online_revenue', ROUND(v_escrow_online_rev, 2),
        'total_gateway_fees', 0.0,
        'total_vsp_commission', 0.0,
        'net_online_earnings', ROUND(v_completed_online_rev, 2),
        'owner_online_earnings', ROUND(v_completed_online_rev, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'cash_revenue', ROUND(v_completed_cash_rev, 2),
        'accumulated_cash_debt', 0.0,
        'debt_limit', 0.0,
        'is_debt_blocked', false,
        'owner_total_revenue', ROUND(v_completed_online_rev + v_completed_cash_rev, 2),
        'completed_bookings_count', v_completed_bookings_count
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) FROM anon, public;


-- 3. owner_record_no_show_atomic
CREATE OR REPLACE FUNCTION public.owner_record_no_show_atomic(
    p_booking_id UUID,
    p_owner_id UUID,
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تسجيل عدم الحضور متاح فقط لمالك الملعب أو الإدارة.');
        END IF;
    END IF;

    IF v_booking.status = 'no_show' THEN
        RETURN jsonb_build_object('success', true, 'message', 'تم تسجيل عدم الحضور مسبقاً.');
    END IF;

    UPDATE public.bookings
    SET status = 'no_show',
        is_paid = (COALESCE(deposit_paid, 0.0) > 0.0),
        payment_status = CASE WHEN COALESCE(deposit_paid, 0.0) > 0.0 THEN 'paid' ELSE payment_status END,
        cancellation_reason = 'غياب اللاعب وعدم الحضور بالموعد المحدد (العربون تعويض للملعب)',
        notes = CASE WHEN LENGTH(TRIM(COALESCE(p_notes, ''))) > 0 THEN COALESCE(notes, '') || ' | ' || p_notes ELSE notes END,
        updated_at = v_now
    WHERE id = p_booking_id;

    IF v_booking.user_id IS NOT NULL OR v_booking.created_by_user_id IS NOT NULL THEN
        UPDATE public.users
        SET fair_play_score = GREATEST(0, COALESCE(fair_play_score, 100) - 10),
            updated_at = v_now
        WHERE id = COALESCE(v_booking.user_id, v_booking.created_by_user_id);
    END IF;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        COALESCE(v_booking.user_id, v_booking.created_by_user_id),
        'تسجيل عدم حضور (No-Show)',
        'تم تسجيل عدم حضورك للمباراة المقررة في ' || COALESCE(v_booking.stadium_name, 'الملعب') || '. تم احتساب العربون تعويضاً للملعب وفق شروط الحجز.',
        'booking_no_show',
        v_now
    );

    RETURN jsonb_build_object('success', true, 'message', 'تم تسجيل عدم حضور اللاعب واعتماد العربون كتعويض للملعب بنجاح.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid, uuid, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid, uuid, text) FROM anon, public;
