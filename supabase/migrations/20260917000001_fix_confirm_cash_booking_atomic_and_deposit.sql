-- Migration: 20260917000001_fix_confirm_cash_booking_atomic_and_deposit.sql
-- Description:
-- 1. Fix Problem 1: Explicitly set payment_method = 'cash' upon cash collection so it never remains or reverts to 'online'.
-- 2. Fix Problem 2: Preserve only actual online deposit in deposit_paid instead of bloating it with total_price.

CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id uuid,
    p_owner_id uuid,
    p_total_price numeric DEFAULT NULL::numeric,
    p_collected_amount numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_booking RECORD;
    v_owner RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
    v_commission NUMERIC;
    v_new_debt NUMERIC;
    v_is_blocked BOOLEAN;
    v_actual_deposit NUMERIC;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. قفل صف الحجز في الداتابيز لمنع التضارب (Concurrency & Race condition guard)
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. فحص الصلاحيات: مسموح فقط لمالك الملعب الحقيقي أو الأدمن
    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role 
        FROM public.users 
        WHERE id = auth.uid();

        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- 3. منع تحصيل الحجوزات الملغاة
    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
            USING ERRCODE = 'P0003', DETAIL = 'BOOKING_CANCELLED';
    END IF;

    -- 4. فحص الأمان (Idempotency): إذا تم سداده مسبقاً وتأكيده ككاش لا نكرر المديونية
    IF v_booking.is_paid IS TRUE AND v_booking.payment_status = 'paid' AND v_booking.payment_method = 'cash' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً ككاش.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'total_price', v_booking.total_price
        );
    END IF;

    -- 5. قفل صف المالك لاحتساب المديونية بدقة
    SELECT * INTO v_owner
    FROM public.users
    WHERE id = v_booking.owner_id
    FOR UPDATE;

    -- 6. احتساب مبلغ الكاش الفعلي المستلم بالملعب
    IF p_collected_amount IS NOT NULL AND p_collected_amount > 0 THEN
        v_cash_amount := p_collected_amount;
    ELSE
        v_cash_amount := GREATEST(0, COALESCE(v_booking.total_price, p_total_price, 0) - COALESCE(v_booking.deposit_paid, 0));
        IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
            v_cash_amount := v_booking.total_price;
        END IF;
    END IF;

    -- 🛡️ حل المشكلة الثانية: الحفاظ على العربون الإلكتروني الحقيقي فقط دون نفخه بكامل المبلغ
    v_actual_deposit := COALESCE(v_booking.deposit_paid, 0.0);

    -- 7. احتساب عمولة المنصة (2%) وإضافتها لمديونية المالك النقدية
    v_commission := COALESCE(NULLIF(v_booking.vsp_commission, 0), round(v_cash_amount * 0.02, 2));
    v_new_debt := COALESCE(v_owner.accumulated_cash_debt, 0) + v_commission;
    v_is_blocked := (v_new_debt >= COALESCE(v_owner.debt_limit, 500.00));

    -- 8. تحديث مديونية المالك وحالته
    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users
    SET 
        accumulated_cash_debt = v_new_debt,
        is_debt_blocked = v_is_blocked,
        updated_at = v_now
    WHERE id = v_booking.owner_id;

    -- 9. 🛡️ تحديث الحجز: تطبيق حل المشكلتين جذرياً:
    -- (أ) حل مشكلة الـ online: إجبار payment_method أن تكون 'cash' صراحة
    -- (ب) حل مشكلة تضارب الأرباح: وضع deposit_paid بالعربون الحقيقي المسدد إلكترونياً فقط وليس كامل المبلغ
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        payment_method = 'cash', -- إصلاح إجباري
        status = 'confirmed',
        vsp_commission = v_commission,
        deposit_paid = v_actual_deposit, -- إصلاح عدم نفخ العربون
        updated_at = v_now
    WHERE id = p_booking_id;

    -- 10. تسجيل قيد المعاملة النقدية في المعاملات المالية
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
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'commission', v_commission,
        'new_debt', v_new_debt,
        'is_blocked', v_is_blocked,
        'total_price', COALESCE(v_booking.total_price, p_total_price),
        'deposit_paid', v_actual_deposit,
        'payment_method', 'cash'
    );
END;
$function$;

-- الصلاحيات
GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) FROM anon, public;
