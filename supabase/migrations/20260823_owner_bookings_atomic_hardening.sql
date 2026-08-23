-- ==============================================================================
-- 🚀 VSP PLATFORM — OWNER BOOKINGS & ATOMIC SLOT LOCK HARDENING PATCH
-- Description: Race-condition-free manual booking & maintenance slot lock RPCs
-- Date: 2026-08-23
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة الحجز اليدوي الذرية لمنع التضارب نهائياً (owner_create_manual_booking_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.owner_create_manual_booking_atomic(
    UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, INT
);

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
BEGIN
    -- 1. التحقق من وجود وصلاحية الملعب والمالك
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
    END IF;

    IF v_stadium.owner_id != p_owner_id AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to stadium');
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
        RETURN jsonb_build_object('success', false, 'error', 'Slot already booked or overlaps with an active match');
    END IF;

    -- 4. تحديد حالة الدفع
    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_collected_amount > 0 THEN 'partially_paid'
        ELSE 'pending'
    END;

    -- 5. إدراج الحجز اليدوي
    INSERT INTO public.bookings (
        stadium_id,
        owner_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
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
        p_owner_id,
        p_owner_id,
        p_start_time,
        p_end_time,
        'personal',
        COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي'),
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

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Manual booking created successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2️⃣ دالة قفل الساعة السريعة للصيانة أو الصلاة (owner_lock_slot_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.owner_lock_slot_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);

CREATE OR REPLACE FUNCTION public.owner_lock_slot_atomic(
    p_owner_id UUID,
    p_stadium_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_reason TEXT DEFAULT 'صيانة دورية'
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
BEGIN
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
    END IF;

    -- قفل الملعب لمنع أي Race Condition
    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Slot already booked or overlaps with an active match');
    END IF;

    INSERT INTO public.bookings (
        stadium_id,
        owner_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
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
        p_owner_id,
        p_owner_id,
        p_start_time,
        p_end_time,
        'personal',
        COALESCE(NULLIF(TRIM(p_reason), ''), 'مغلق للصيانة'),
        'قفل مخصص من إدارة الملعب',
        0.0,
        0.0,
        false,
        true,
        'paid',
        'cash',
        'LOCK_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
        'confirmed',
        0,
        true,
        false,
        v_now,
        v_now
    )
    RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Slot locked successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3️⃣ منح الصلاحيات
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.owner_lock_slot_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated, service_role;

COMMIT;
