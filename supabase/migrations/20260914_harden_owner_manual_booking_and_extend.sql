-- ==============================================================================
-- Migration: 20260914_harden_owner_manual_booking_and_extend.sql
-- Description: 
--  1) Upgrade owner_create_manual_booking_atomic to include stadium_name,
--     host_name, user_id, and automatic cash transaction recording in transactions table.
--  2) Create owner_extend_match_atomic to atomically check for conflicts and
--     safely extend match duration without race conditions.
-- ==============================================================================

-- 1️⃣ دالة الحجز اليدوي الذرية المتطورة (owner_create_manual_booking_atomic)
CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(
    p_owner_id UUID,
    p_stadium_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_customer_name TEXT,
    p_customer_phone TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_total_price NUMERIC DEFAULT 0.0,
    p_collected_amount NUMERIC DEFAULT 0.0,
    p_current_players INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_stadium RECORD;
    v_overlap_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_booking_id UUID;
    v_payment_status TEXT;
    v_is_paid BOOLEAN;
    v_customer_clean TEXT;
BEGIN
    -- 1. التحقق من وجود وصلاحية الملعب والمالك
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found', 'message', 'الملعب غير موجود.');
    END IF;

    IF v_stadium.owner_id != p_owner_id AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized', 'message', 'غير مصرح لك بالحجز في هذا الملعب.');
    END IF;

    -- 2. قفل الملعب لمنع أي Race Condition متزامن
    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    -- 3. فحص التضارب الزمني مع أي حجز نشط آخر
    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'conflict', 'message', 'عذراً، هذا الموعد تم حجزه للتو أو يتعارض مع حجز آخر نشط.');
    END IF;

    -- 4. تحديد حالة الدفع
    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_collected_amount > 0 THEN 'partially_paid'
        ELSE 'pending'
    END;

    v_customer_clean := COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي');

    -- 5. إدراج الحجز اليدوي (مع stadium_name و host_name و player_team_name)
    INSERT INTO public.bookings (
        stadium_id,
        stadium_name,
        owner_id,
        user_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
        host_name,
        player_phone,
        notes,
        total_price,
        deposit_paid,
        is_deposit_paid,
        is_paid,
        payment_status,
        payment_method,
        payment_transaction_id,
        status,
        current_players,
        is_private,
        rent_ball,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        v_stadium.name,
        p_owner_id,
        p_owner_id,
        p_owner_id,
        p_start_time,
        p_end_time,
        'personal',
        v_customer_clean,
        v_customer_clean,
        NULLIF(TRIM(p_customer_phone), ''),
        NULLIF(TRIM(p_notes), ''),
        p_total_price,
        p_collected_amount,
        (p_collected_amount > 0),
        v_is_paid,
        v_payment_status,
        'cash',
        'MANUAL_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
        'confirmed',
        p_current_players,
        true,
        false,
        v_now,
        v_now
    )
    RETURNING id INTO v_booking_id;

    -- 6. تسجيل حركة الكاش في جدول transactions فوراً إذا تم تحصيل أي مبلغ نقدي
    IF p_collected_amount > 0 THEN
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
            p_owner_id,
            v_booking_id,
            p_collected_amount,
            'cash',
            'completed',
            'cash',
            'دفع ' || CASE WHEN v_is_paid THEN 'كامل' ELSE 'عربون' END || ' حجز يدوي: ' || COALESCE(v_stadium.name, 'الملعب'),
            v_now,
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'تم إنشاء الحجز اليدوي بنجاح.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, INT) TO authenticated, service_role;

-- 2️⃣ دالة تمديد المباراة الذرية (owner_extend_match_atomic)
CREATE OR REPLACE FUNCTION public.owner_extend_match_atomic(
    p_booking_id UUID,
    p_added_minutes INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_new_end_time TIMESTAMPTZ;
    v_conflict_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. جلب بيانات الحجز وقفل السجل
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. التحقق من الصلاحية
    IF v_booking.owner_id != auth.uid() AND auth.role() != 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message', 'غير مصرح لك بتعديل هذا الحجز.');
    END IF;

    -- 3. قفل الملعب لمنع أي حجز متزامن في نفس النافذة
    PERFORM 1 FROM public.stadiums WHERE id = v_booking.stadium_id FOR UPDATE;

    v_new_end_time := v_booking.end_time + (COALESCE(p_added_minutes, 30) || ' minutes')::INTERVAL;

    -- 4. فحص التضارب مع أي حجز تالٍ نشط
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id = v_booking.stadium_id
      AND id != p_booking_id
      AND status != 'cancelled'
      AND start_time < v_new_end_time
      AND end_time > v_booking.end_time;

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'conflict',
            'message', 'لا يمكن تمديد المباراة، يوجد حجز آخر يبدأ في هذا الوقت.'
        );
    END IF;

    -- 5. تحديث وقت نهاية الحجز
    UPDATE public.bookings
    SET end_time = v_new_end_time,
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_end_time', v_new_end_time,
        'message', 'تم تمديد المباراة 30 دقيقة إضافية بنجاح.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.owner_extend_match_atomic(UUID, INT) TO authenticated, service_role;
