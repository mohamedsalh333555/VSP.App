-- ==============================================================================
-- 🔒 VSP MIGRATION: Phase 96 Hardening
-- File: 20260909_phase96_harden_cron_cash_settlement_and_disputes.sql
-- Description:
--   1. Protect tournament matches from deletion by securing prepare_tournament_bracket
--   2. Fix cash settlement accounting in confirm_cash_booking_atomic (preserve deposit, record true cash)
--   3. Secure request_join_public_match against player impersonation (auth.uid verification)
--   4. Secure dispute_no_show_with_gps against GPS/no-show fraud (caller & booking membership check)
--   5. Secure background cron routines (auto_reconcile_past_bookings, auto_reconcile_all_past_bookings, auto_expire_pending_locks)
-- ==============================================================================

-- 1️⃣ حماية مباريات البطولات واستبدال دالة المسح العشوائي prepare_tournament_bracket
CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket(p_championship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
BEGIN
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً لإعداد جدول البطولة.');
    END IF;

    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط منظم البطولة أو الأدمن يمكنه إعداد الشجرة.');
        END IF;
    END IF;

    -- تفويض آمن ومحمي للدالة المركزية لإعداد الشجرة والمباريات
    RETURN public.generate_tournament_bracket_atomic(p_championship_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.prepare_tournament_bracket(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prepare_tournament_bracket(UUID) TO authenticated, service_role;


-- 2️⃣ تحصين قيد الكاش وحفظ العربون بدقة في confirm_cash_booking_atomic
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id UUID,
    p_owner_id UUID,
    p_total_price NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_cash_to_collect NUMERIC := 0.0;
BEGIN
    -- 1. جلب بيانات الحجز وقفل السجل
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 🔒 2. التحقق الصارم من الهوية والصلاحية: المالك الحقيقي للملعب أو الإدارة أو service_role
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- إذا كان الحجز مسدداً بالكامل بالفعل
    IF v_booking.is_paid = TRUE AND v_booking.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'message', 'الحجز مسدد بالكامل مسبقاً.', 'booking_id', p_booking_id);
    END IF;

    -- حساب المبلغ النقدي الفعلي المحصل بالملعب
    -- إذا كان مسدداً منه عربون أونلاين: الكاش المحصل = الإجمالي - العربون المسدد
    IF (v_booking.needs_deposit = TRUE OR v_booking.is_deposit_paid = TRUE) AND COALESCE(v_booking.deposit_paid, v_booking.deposit_amount, 0) > 0 THEN
        v_cash_to_collect := GREATEST(0.0, v_booking.total_price - COALESCE(NULLIF(v_booking.deposit_paid, 0), v_booking.deposit_amount, 0.0));
    ELSE
        v_cash_to_collect := v_booking.total_price;
    END IF;

    -- 3. تحديث حالة الحجز إلى مدفوع دون طمس قيمة العربون الإلكتروني المسدد
    UPDATE public.bookings
    SET is_paid = TRUE,
        payment_status = 'paid',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- 4. إدراج قيد في سجل المعاملات بالمبلغ النقدي الفعلي المحصل باليد فقط
    IF v_cash_to_collect > 0 THEN
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
            ROUND(v_cash_to_collect, 2),
            'cash_settlement',
            'completed',
            'cash',
            'تحصيل متبقي كاش بالملعب لحجز #' || substring(p_booking_id::text, 1, 8),
            timezone('utc'::text, now())
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'booking_id', p_booking_id, 
        'cash_collected', ROUND(v_cash_to_collect, 2),
        'total_price', v_booking.total_price
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(UUID, UUID, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(UUID, UUID, NUMERIC) TO authenticated, service_role;


-- 3️⃣ منع انتحال هوية اللاعبين في طلب الانضمام للمباريات العامة request_join_public_match
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
BEGIN
    v_booking_uuid := p_booking_id::UUID;
    v_user_uuid := p_user_id::UUID;

    -- 🔒 التحقق الصارم من الهوية لمنع إقحام لاعبين آخرين
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RAISE EXCEPTION 'unauthorized: login required';
        END IF;

        IF auth.uid() != v_user_uuid THEN
            RAISE EXCEPTION 'forbidden: cannot join on behalf of another user';
        END IF;
    END IF;

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
      AND (created_by_user_id::text = p_user_id OR p_user_id = ANY(COALESCE(joined_user_ids::text[], ARRAY[]::text[])))
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

REVOKE EXECUTE ON FUNCTION public.request_join_public_match(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_join_public_match(TEXT, TEXT) TO authenticated, service_role;


-- 4️⃣ تأمين نزاع عدم الحضور dispute_no_show_with_gps ضد التزييف
CREATE OR REPLACE FUNCTION public.dispute_no_show_with_gps(
    p_booking_id TEXT,
    p_player_id TEXT,
    p_lat NUMERIC,
    p_lng NUMERIC,
    p_accuracy NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_stadium RECORD;
    v_distance_meters NUMERIC;
    v_player_uuid UUID;
BEGIN
    v_player_uuid := p_player_id::UUID;

    -- 🔒 التحقق الصارم من هوية مقدم النزاع
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RAISE EXCEPTION 'unauthorized: login required';
        END IF;

        IF auth.uid() != v_player_uuid THEN
            RAISE EXCEPTION 'forbidden: cannot dispute penalty on behalf of another player';
        END IF;
    END IF;

    -- 1. التحقق من دقة الـ GPS (يجب أن تكون <= 50 متراً لمنع التزييف)
    IF p_accuracy > 50 THEN
        RAISE EXCEPTION 'gps_accuracy_too_low';
    END IF;

    -- 2. جلب بيانات الحجز
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'booking_not_found';
    END IF;

    -- 🔒 التحقق من أن اللاعب هو طرف أصيل في الحجز
    IF (v_booking.created_by_user_id IS DISTINCT FROM v_player_uuid) AND
       (NOT (p_player_id = ANY(COALESCE(v_booking.joined_user_ids::text[], ARRAY[]::text[])))) THEN
        RAISE EXCEPTION 'forbidden: player is not a participant in this booking';
    END IF;

    -- 3. التحقق من مهلة الـ 60 دقيقة من نهاية المباراة
    IF NOW() > (v_booking.end_time + INTERVAL '60 minutes') THEN
        RAISE EXCEPTION 'dispute_window_expired';
    END IF;

    -- 4. جلب إحداثيات الملعب
    SELECT * INTO v_stadium
    FROM public.stadiums
    WHERE id = v_booking.stadium_id;

    IF v_stadium.lat IS NULL OR v_stadium.lng IS NULL THEN
        RAISE EXCEPTION 'stadium_coordinates_missing';
    END IF;

    -- 5. حساب المسافة الجغرافية (Haversine Formula)
    v_distance_meters := 6371000 * acos(
        LEAST(1.0, GREATEST(-1.0,
            cos(radians(v_stadium.lat)) * cos(radians(p_lat)) *
            cos(radians(p_lng) - radians(v_stadium.lng)) +
            sin(radians(v_stadium.lat)) * sin(radians(p_lat))
        ))
    );

    -- يجب أن يكون اللاعب ضمن نطاق 150 متراً من الملعب
    IF v_distance_meters > 150 THEN
        RAISE EXCEPTION 'not_at_stadium';
    END IF;

    -- 6. إلغاء عقوبة الـ No-Show وإعادة النقاط للاعب
    UPDATE public.users
    SET no_show_count = GREATEST(0, COALESCE(no_show_count, 0) - 1),
        is_blocked = FALSE,
        fair_play_score = LEAST(100, COALESCE(fair_play_score, 100) + 10),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_player_uuid;

    -- تسجيل حل النزاع في سجل التدقيق
    INSERT INTO public.audit_logs (
        action, entity, record_id, changed_by, old_data, new_data, created_at
    ) VALUES (
        'dispute_no_show_resolved_via_gps',
        'users',
        v_player_uuid,
        v_player_uuid,
        jsonb_build_object('booking_id', p_booking_id, 'distance_meters', ROUND(v_distance_meters, 1)),
        jsonb_build_object('status', 'penalty_cleared', 'verified_gps', true),
        timezone('utc'::text, now())
    );

    RETURN TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.dispute_no_show_with_gps(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_no_show_with_gps(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC) TO authenticated, service_role;


-- 5️⃣ تأمين وضبط دوال الـ Background Cron والصيانة الزمنية
-- أ) auto_reconcile_past_bookings: تحصين النطاق عند استدعائها من التطبيق
CREATE OR REPLACE FUNCTION public.auto_reconcile_past_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
BEGIN
    -- إذا كان الاستدعاء قادماً من مستخدم مسجل في التطبيق: يُقيد التحديث بملاعب المالك فقط
    IF v_caller_id IS NOT NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            UPDATE public.bookings
            SET status = 'completed',
                updated_at = NOW()
            WHERE end_time < NOW()
              AND status = 'confirmed'
              AND owner_id = v_caller_id;
            RETURN;
        END IF;
    END IF;

    -- إذا كان الاستدعاء من الأدمن أو النظام الداخلي / pg_cron
    UPDATE public.bookings
    SET status = 'completed',
        updated_at = NOW()
    WHERE end_time < NOW()
      AND status = 'confirmed';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.auto_reconcile_past_bookings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_reconcile_past_bookings() TO authenticated, service_role;


-- ب) auto_reconcile_all_past_bookings: إزالة تعليم الكاش كمسدد تلقائياً وحصرها بالـ service_role
CREATE OR REPLACE FUNCTION public.auto_reconcile_all_past_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        RAISE EXCEPTION 'Security Alert: Direct client invocation of auto_reconcile_all_past_bookings is prohibited.';
    END IF;

    -- تحديث حالة الحجز للمنتهي دون التلاعب بحالة سداد الكاش
    UPDATE public.bookings
    SET status = 'completed',
        updated_at = NOW()
    WHERE end_time < NOW()
      AND status = 'confirmed';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.auto_reconcile_all_past_bookings() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_reconcile_all_past_bookings() TO service_role;


-- ج) auto_expire_pending_locks: حظر الوصول غير المصرح به
REVOKE EXECUTE ON FUNCTION public.auto_expire_pending_locks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_expire_pending_locks() TO authenticated, service_role;
