-- ==============================================================================
-- 🚀 VSP PLATFORM — PLAYER BOOKING & MATCHMAKING ATOMIC HARDENING PATCH
-- Description: Race-condition-free player online/deposit bookings & 5v5 matchmaking RPCs
-- Date: 2026-08-23
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة حجز اللاعب الذرية مع فحص التضارب التلقائي (player_create_booking_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.player_create_booking_atomic(
    UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, TEXT, INT, INT
);

CREATE OR REPLACE FUNCTION public.player_create_booking_atomic(
    p_player_id UUID,
    p_stadium_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_booking_type TEXT,
    p_player_team_id UUID DEFAULT NULL,
    p_player_team_name TEXT DEFAULT NULL,
    p_total_price NUMERIC DEFAULT 0.0,
    p_deposit_paid NUMERIC DEFAULT 0.0,
    p_is_private BOOLEAN DEFAULT TRUE,
    p_payment_method TEXT DEFAULT 'cash',
    p_transaction_id TEXT DEFAULT NULL,
    p_current_players INT DEFAULT 1,
    p_total_capacity INT DEFAULT 10
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
    v_player RECORD;
BEGIN
    -- 1. جلب وقفل سجل الملعب
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
    END IF;

    -- 2. جلب بيانات اللاعب
    SELECT * INTO v_player FROM public.users WHERE id = p_player_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Player profile not found');
    END IF;

    -- 3. فحص التضارب الزمني مع أي حجز نشط (أونلاين أو كاش)
    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'عذراً، تم حجز وتأكيد هذه الساعة للتو بواسطة لاعب آخر.');
    END IF;

    -- 4. تحديد حالة الدفع
    v_is_paid := (p_payment_method = 'online' AND (p_deposit_paid >= p_total_price OR p_total_price = 0));
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_deposit_paid > 0 THEN 'partially_paid'
        ELSE 'pending'
    END;

    -- 5. إدراج الحجز
    INSERT INTO public.bookings (
        stadium_id,
        owner_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_id,
        player_team_name,
        player_phone,
        total_price,
        deposit_paid,
        is_deposit_paid,
        is_paid,
        payment_status,
        payment_method,
        payment_transaction_id,
        status,
        is_private,
        current_players,
        total_field_capacity,
        joined_user_ids,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        v_stadium.owner_id,
        p_player_id,
        p_start_time,
        p_end_time,
        COALESCE(p_booking_type, 'personal'),
        p_player_team_id,
        COALESCE(p_player_team_name, v_player.full_name, 'لاعب'),
        v_player.phone_number,
        p_total_price,
        p_deposit_paid,
        (p_deposit_paid > 0),
        v_is_paid,
        v_payment_status,
        COALESCE(p_payment_method, 'cash'),
        COALESCE(p_transaction_id, 'PAY_' || EXTRACT(EPOCH FROM v_now)::BIGINT),
        'confirmed',
        p_is_private,
        p_current_players,
        p_total_capacity,
        ARRAY[p_player_id::TEXT],
        v_now,
        v_now
    )
    RETURNING id INTO v_booking_id;

    -- 6. إرسال إشعار فوري لمالك الملعب
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    ) VALUES (
        v_stadium.owner_id,
        'حجز جديد على ملعبك',
        'قام الكابتن ' || COALESCE(v_player.full_name, 'لاعب') || ' بحجز موعد جديد في ' || v_stadium.name,
        'booking',
        false,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Booking created successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2️⃣ دالة الانضمام الذرية للمباريات العامة والـ 5v5 (request_join_public_match)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_join_public_match(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.request_join_public_match(UUID, UUID);

CREATE OR REPLACE FUNCTION public.request_join_public_match(
    p_booking_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
    v_booking_uuid UUID;
    v_user_uuid UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    v_booking_uuid := p_booking_id::UUID;
    v_user_uuid := p_user_id::UUID;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = v_booking_uuid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'match_cancelled';
    END IF;

    SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
    IF v_user_blocked IS TRUE THEN
        RAISE EXCEPTION 'user_blocked';
    END IF;

    v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
    IF v_booking.current_players >= v_capacity THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    IF p_user_id = ANY(COALESCE(v_booking.joined_user_ids::text[], ARRAY[]::text[])) THEN
        RAISE EXCEPTION 'already_joined';
    END IF;

    -- التحقق من تضارب المواعيد مع مباريات اللاعب الأخرى
    SELECT COUNT(*) INTO v_user_conflict
    FROM public.bookings
    WHERE status != 'cancelled'
      AND id != v_booking_uuid
      AND (created_by_user_id = p_user_id OR p_user_id = ANY(COALESCE(joined_user_ids::text[], ARRAY[]::text[])))
      AND start_time < v_booking.end_time
      AND end_time > v_booking.start_time;

    IF v_user_conflict > 0 THEN
        RAISE EXCEPTION 'time_conflict';
    END IF;

    -- تنفيذ الانضمام وتحديث العدد
    UPDATE public.bookings
    SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::text[]), p_user_id),
        current_players = COALESCE(current_players, 0) + 1,
        updated_at = v_now
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'current_players', v_booking.current_players + 1
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3️⃣ منح الصلاحيات
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.player_create_booking_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, TEXT, INT, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_join_public_match(TEXT, TEXT) TO authenticated, service_role;

COMMIT;
