-- Migration: 20260914_fix_confirm_cash_booking_atomic.sql
-- Fix: Remove non-existent 'currency' column from transactions insertion in confirm_cash_booking_atomic
-- Also correctly calculate the remaining cash amount when a deposit was already paid online.

CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id UUID,
    p_owner_id UUID,
    p_total_price NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
BEGIN
    -- 1. جلب بيانات الحجز وقفل السجل
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. التحقق من الصلاحية: المالك الحقيقي للملعب أو الإدارة أو service_role أو postgres
    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- التحقق من عدم التكرار (Idempotency check: منع تكرار قيود المعاملات المالية لحجز مسدد بالفعل)
    IF v_booking.is_paid IS TRUE AND v_booking.payment_status = 'paid' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'total_price', v_booking.total_price
        );
    END IF;

    -- حساب المبلغ المستلم كاش فعلياً (إجمالي السعر ناقص أي عربون مدفوع مسبقاً)
    v_cash_amount := GREATEST(0, COALESCE(v_booking.total_price, p_total_price, 0) - COALESCE(v_booking.deposit_paid, 0));
    IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
        v_cash_amount := v_booking.total_price;
    END IF;

    -- 3. تحديث حالة الحجز إلى مدفوع ومكتمل بالكامل
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        deposit_paid = COALESCE(v_booking.total_price, p_total_price),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- 4. إدراج قيد في سجل المعاملات المالية المركزي (بدون عمود currency غير الموجود في الجدول)
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
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'total_price', COALESCE(v_booking.total_price, p_total_price)
    );
END;
$$;
