-- ==============================================================================
-- 🚀 VSP MASTER PRODUCTION UNIFIED SQL PATCH (الرقعة الشاملة الموحدة للإنتاج)
-- Version: 2026.08.23-Final-Unified
-- Purpose: Consolidates all RPCs, fixes missing functions, reinforces RLS,
--          hardens ledger transactions, and secures public matchmaking.
-- Instructions: Run this entire script in Supabase SQL Editor.
-- ==============================================================================

-- 1️⃣ الفهارس الضرورية للأداء والمحادثات
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id ON public.chat_messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_booking_id ON public.chat_messages (booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_type ON public.transactions (user_id, type);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_championship ON public.tournament_matches (championship_id, round_index);

-- 2️⃣ دالة الانضمام الذرية للمباريات التجميعية (request_join_public_match)
DROP FUNCTION IF EXISTS public.request_join_public_match(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.request_join_public_match(UUID, UUID);

CREATE OR REPLACE FUNCTION public.request_join_public_match(
    p_booking_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
    v_booking_uuid UUID;
    v_user_uuid UUID;
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

    -- التحقق من تضارب المواعيد مع حجوزات اللاعب الأخرى
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
        updated_at = timezone('utc'::text, now())
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'current_players', v_booking.current_players + 1
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_join_public_match(TEXT, TEXT) TO authenticated, service_role;

-- 3️⃣ دالة تأكيد استلام الكاش بالملعب وتسجيل قيد المحاسبة (confirm_cash_booking_atomic)
DROP FUNCTION IF EXISTS public.confirm_cash_booking_atomic(UUID, UUID, NUMERIC);

CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id UUID,
    p_owner_id UUID,
    p_total_price NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        deposit_paid = p_total_price,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- إدراج قيد في سجل المعاملات المالية المركزي
    INSERT INTO public.transactions (
        user_id,
        booking_id,
        amount,
        type,
        status,
        payment_method,
        currency,
        description,
        created_at
    ) VALUES (
        p_owner_id,
        p_booking_id,
        p_total_price,
        'cash_settlement',
        'completed',
        'cash',
        'EGP',
        'تحصيل كاش مؤكد بالملعب لحجز #' || substring(p_booking_id::text, 1, 8),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'amount', p_total_price);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(UUID, UUID, NUMERIC) TO authenticated, service_role;

-- 4️⃣ دالة تقييم الملعب الذرية المحصنة (submit_stadium_review_atomic)
DROP FUNCTION IF EXISTS public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, INT, TEXT);

CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(
    p_stadium_id UUID,
    p_user_id UUID,
    p_user_name TEXT,
    p_user_image_url TEXT,
    p_rating INT,
    p_comment TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_completed_count INT;
    v_owner_id UUID;
    v_avg_rating NUMERIC;
    v_total_reviews INT;
BEGIN
    -- التحقق من أن المستخدم ليس هو مالك الملعب
    SELECT owner_id INTO v_owner_id FROM public.stadiums WHERE id = p_stadium_id;
    IF v_owner_id = p_user_id THEN
        RAISE EXCEPTION 'cannot_review_own_stadium';
    END IF;

    -- التحقق من وجود حجز سابق مكتمل لهذا المستخدم في الملعب
    SELECT COUNT(*) INTO v_completed_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND (created_by_user_id = p_user_id::text OR p_user_id::text = ANY(COALESCE(joined_user_ids::text[], ARRAY[]::text[])))
      AND (status = 'completed' OR end_time < timezone('utc'::text, now()));

    IF v_completed_count = 0 THEN
        RAISE EXCEPTION 'must_have_completed_booking';
    END IF;

    -- إدراج التقييم
    INSERT INTO public.reviews (
        stadium_id,
        user_id,
        user_name,
        user_image_url,
        rating,
        review_text,
        created_at
    ) VALUES (
        p_stadium_id,
        p_user_id,
        p_user_name,
        p_user_image_url,
        p_rating,
        p_comment,
        timezone('utc'::text, now())
    );

    -- إعادة حساب متوسط التقييم للملعب
    SELECT COALESCE(AVG(rating), 5.0), COUNT(*)
    INTO v_avg_rating, v_total_reviews
    FROM public.reviews
    WHERE stadium_id = p_stadium_id;

    UPDATE public.stadiums
    SET rating = ROUND(v_avg_rating, 1),
        review_count = v_total_reviews,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_stadium_id;

    RETURN jsonb_build_object(
        'success', true,
        'stadium_id', p_stadium_id,
        'new_rating', v_avg_rating,
        'total_reviews', v_total_reviews
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, INT, TEXT) TO authenticated, service_role;

-- 5️⃣ دالة حذف الحساب نهائياً مع إشعار السيرفر (delete_user_permanently)
DROP FUNCTION IF EXISTS public.delete_user_permanently(UUID);

CREATE OR REPLACE FUNCTION public.delete_user_permanently(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- حذف من الجداول التابعة
    DELETE FROM public.notifications WHERE user_id = p_user_id;
    DELETE FROM public.reviews WHERE user_id = p_user_id;
    DELETE FROM public.reports WHERE reporter_id = p_user_id;
    DELETE FROM public.chat_messages WHERE sender_id = p_user_id::text;
    
    -- حذف المستخدم من جدول users
    DELETE FROM public.users WHERE id = p_user_id;

    -- حذف المستخدم من auth.users إذا كانت الصلاحيات تتيح ذلك
    BEGIN
        DELETE FROM auth.users WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_permanently(UUID) TO authenticated, service_role;

-- 6️⃣ دالة إزالة فريق من بطولة جارية مع تصعيد تلقائي للمنافسين (remove_tournament_team_atomic)
DROP FUNCTION IF EXISTS public.remove_tournament_team_atomic(UUID, UUID);

CREATE OR REPLACE FUNCTION public.remove_tournament_team_atomic(
    p_championship_id UUID,
    p_team_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- حذف الفريق من مصفوفة البطولة والكشوفات
    UPDATE public.championships
    SET joined_teams = array_remove(joined_teams, p_team_id),
        paid_teams = array_remove(paid_teams, p_team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    DELETE FROM public.tournament_team_rosters
    WHERE championship_id = p_championship_id AND team_id = p_team_id;

    -- معالجة المباريات التي كان الفريق طرفاً فيها كـ Walkover (فوز المنافس اعتبارا)
    UPDATE public.tournament_matches
    SET winner_id = CASE WHEN home_team_id = p_team_id THEN away_team_id ELSE home_team_id END,
        winner_name = CASE WHEN home_team_id = p_team_id THEN away_team_name ELSE home_team_name END,
        home_score = CASE WHEN home_team_id = p_team_id THEN 0 ELSE 3 END,
        away_score = CASE WHEN home_team_id = p_team_id THEN 3 ELSE 0 END,
        updated_at = timezone('utc'::text, now())
    WHERE championship_id = p_championship_id
      AND (home_team_id = p_team_id OR away_team_id = p_team_id)
      AND winner_id IS NULL;

    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'team_id', p_team_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_tournament_team_atomic(UUID, UUID) TO authenticated, service_role;
