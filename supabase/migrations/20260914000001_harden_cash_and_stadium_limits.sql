-- Migration: 20260914000001_harden_cash_and_stadium_limits.sql
-- Description: Harden cash confirmation idempotency, block cancelled bookings, serialize stadium creation to prevent subscription limit races, and pin search_path on SECURITY DEFINER functions.

-- ============================================================================
-- 1. HARDEN CASH BOOKING ATOMIC RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id UUID,
    p_owner_id UUID,
    p_total_price NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
BEGIN
    -- 1. جلب بيانات الحجز وقفل السجل لمنع أي تعديل متزامن
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'الحجز غير موجود.'
        );
    END IF;

    -- 2. التحقق من الصلاحية: المالك الحقيقي للملعب أو الإدارة أو service_role أو postgres
    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role 
        FROM public.users 
        WHERE id = auth.uid();

        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object(
                'success', false, 
                'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.'
            );
        END IF;
    END IF;

    -- 3. منع تحصيل حجز ملغي إطلاقاً
    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
            USING ERRCODE = 'P0003', DETAIL = 'BOOKING_CANCELLED';
    END IF;

    -- 4. التحقق من عدم التكرار (Idempotency Check): إذا كان الحجز مسدداً ومؤكداً بالفعل، إرجاع نجاح دون أي تكرار مالي
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

    -- 5. حساب المبلغ المستلم كاش فعلياً (إجمالي السعر ناقص أي عربون مدفوع مسبقاً)
    v_cash_amount := GREATEST(0, COALESCE(v_booking.total_price, p_total_price, 0) - COALESCE(v_booking.deposit_paid, 0));
    IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
        v_cash_amount := v_booking.total_price;
    END IF;

    -- 6. تحديث حالة الحجز إلى مدفوع ومؤكد بالكامل
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        status = 'confirmed',
        deposit_paid = COALESCE(v_booking.total_price, p_total_price),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- 7. إدراج قيد في سجل المعاملات المالية المركزي
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
        'already_confirmed', false,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'total_price', COALESCE(v_booking.total_price, p_total_price)
    );
END;
$$;

-- ============================================================================
-- 2. PARTIAL UNIQUE INDEX FOR CASH SETTLEMENT DEFENSE-IN-DEPTH
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_unique_cash_settlement
ON public.transactions (booking_id)
WHERE type = 'cash_settlement' AND status = 'completed';

-- ============================================================================
-- 3. CONCURRENCY-SAFE STADIUM SUBSCRIPTION LIMIT TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_owner RECORD;
    v_current_count INT;
    v_max_allowed INT := 0;
    v_is_active_trial BOOLEAN := FALSE;
    v_is_sub_active BOOLEAN := FALSE;
BEGIN
    -- تجاهل إذا كان معرف المالك غير محدد
    IF NEW.owner_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- قفل سجل مالك الملعب FOR UPDATE لمنع سباق التزامن (Concurrency Lock)
    -- في حالة وصول طلبي إنشاء متزامنين، يتم إيقاف الطلب الثاني حتى ينتهي الأول
    PERFORM 1
    FROM public.users
    WHERE id = NEW.owner_id
    FOR UPDATE;

    -- جلب بيانات المالك بعد الاستحواذ على القفل
    SELECT role, subscription_plan, subscription_expires_at, trial_ends_at, created_at
    INTO v_owner
    FROM public.users
    WHERE id = NEW.owner_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'مالك الملعب المحدد غير موجود في النظام.';
    END IF;

    -- استثناء المسؤولين ومؤسسي المنصة من حدود الباقات
    IF v_owner.role IN ('admin', 'co_founder') THEN
        RETURN NEW;
    END IF;

    -- التحقق من صلاحية الفترة التجريبية (إما تاريخ صريح أو مهلة 60 يوماً من الإنشاء)
    v_is_active_trial := (
        COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
        (
            (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
            (v_owner.trial_ends_at IS NULL AND v_owner.created_at + INTERVAL '60 days' > NOW())
        )
    );

    -- التحقق من صلاحية الاشتراك المدفوع
    v_is_sub_active := (
        v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
    );

    -- تحديد الحد الأقصى للملاعب المسموحة
    IF v_owner.subscription_plan = 'pro' AND v_is_sub_active THEN
        v_max_allowed := 3;
    ELSIF (v_owner.subscription_plan = 'basic' AND v_is_sub_active) OR v_is_active_trial THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 0;
    END IF;

    -- حساب عدد الملاعب الحالية النشطة غير المحذوفة للمالك
    SELECT COUNT(*) INTO v_current_count
    FROM public.stadiums
    WHERE owner_id = NEW.owner_id
      AND is_deleted_by_owner = false
      AND (TG_OP = 'INSERT' OR id <> NEW.id);

    -- التحقق وفرض الحد مع إرجاع كود خطأ قياسي ثابت
    IF v_current_count >= v_max_allowed THEN
        IF v_max_allowed = 0 THEN
            RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: انتهت صلاحية باقة الاشتراك الخاصة بك. يرجى تجديد الاشتراك لإضافة ملاعب.'
                USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
        ELSE
            RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: وصلت للحد الأقصى للملاعب في باقتك الحالية (% ملعب). يرجى الترقية لإضافة ملاعب أخرى.', v_max_allowed
                USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- تحديث الدالة check_owner_stadium_limit لتتوافق مع نفس القفل المنطقي
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.check_owner_stadium_limit_trigger();
END;
$$;

-- توحيد التريجر وإعادة ربطه بالدالة الآمنة
DROP TRIGGER IF EXISTS trg_check_owner_stadium_limit ON public.stadiums;
DROP TRIGGER IF EXISTS trg_enforce_owner_stadium_limit ON public.stadiums;

CREATE TRIGGER trg_enforce_owner_stadium_limit
BEFORE INSERT ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.check_owner_stadium_limit_trigger();
