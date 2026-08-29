-- ==============================================================================
-- 🔒 VSP SUPABASE MASTER SECURITY PATCH (COMPREHENSIVE RPC & SECURITY DEFINER AUDIT)
-- Description: Hardens all sensitive SECURITY DEFINER RPC functions against IDOR,
--              caller spoofing, unauthorized status mutations, and privilege escalation.
-- Date: 2026-08-29
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة تأكيد الدفع الكاش بالملعب (confirm_cash_booking_atomic)
-- الحماية: حصر الصلاحية بمالك الملعب الحقيقي أو الأدمن أو الـ service_role
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.confirm_cash_booking_atomic(UUID, UUID, NUMERIC);

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

    -- 3. تحديث حالة الحجز إلى مدفوع ومكتمل
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        deposit_paid = p_total_price,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- 4. إدراج قيد في سجل المعاملات المالية المركزي
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
        v_booking.owner_id,
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


-- ------------------------------------------------------------------------------
-- 2️⃣ دالة تأكيد سداد اشتراك البطولة (confirm_tournament_order_atomic)
-- الحماية: حصر التنفيذ حصرياً على الـ Webhook الخاص بالسيرفر أو الأدمن
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.confirm_tournament_order_atomic(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(
    p_order_reference TEXT,
    p_paymob_transaction_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order RECORD;
    v_caller_role TEXT;
BEGIN
    -- 🔒 حظر الاستدعاء من المستخدمين العاديين وحصره بالسيرفر
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Tournament orders can only be confirmed via server webhook.');
        END IF;
    END IF;

    SELECT * INTO v_order FROM public.tournament_orders 
    WHERE order_reference = p_order_reference FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament order not found');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Order already confirmed');
    END IF;

    -- تحديث حالة الطلب
    UPDATE public.tournament_orders
    SET 
        payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_order.id;

    -- إدراج الفريق في البطولة
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), v_order.team_id),
        paid_teams = array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), v_order.team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_order.championship_id;

    -- حفظ المعاملة المالية في جدول transactions
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        v_order.championship_id,
        v_order.captain_user_id,
        v_order.amount,
        'digital',
        'paymob',
        jsonb_build_object(
            'paymob_transaction_id', p_paymob_transaction_id,
            'order_reference', p_order_reference,
            'team_id', v_order.team_id
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'order_id', v_order.id, 'team_id', v_order.team_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) TO service_role;


-- ------------------------------------------------------------------------------
-- 3️⃣ دالة حذف المستخدم النهائي (delete_user_permanently)
-- الحماية: التحقق من أن المتصل يحذف حسابه الشخصي فقط أو أدمن
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.delete_user_permanently(UUID);

CREATE OR REPLACE FUNCTION public.delete_user_permanently(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من أن المتصل يحذف حسابه الشخصي فقط
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: يمكنك حذف حسابك الشخصي فقط.');
            END IF;
        END IF;
    END IF;

    -- حذف من الجداول التابعة
    DELETE FROM public.notifications WHERE user_id = p_user_id;
    DELETE FROM public.reviews WHERE user_id = p_user_id;
    DELETE FROM public.reports WHERE reporter_id = p_user_id;
    DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
    
    -- حذف المستخدم من جدول users
    DELETE FROM public.users WHERE id = p_user_id;

    -- حذف المستخدم من auth.users
    BEGIN
        DELETE FROM auth.users WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object('success', true, 'deleted_user_id', p_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_permanently(UUID) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 4️⃣ دالة تسجيل نتيجة المباراة وتصعيد الفائز (record_match_result_and_advance_atomic)
-- الحماية: حصر تسجيل النتائج بمالك البطولة الحقيقي أو الإدارة
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.record_match_result_and_advance_atomic(
    UUID, INT, INT, INT, INT, UUID, TEXT, JSONB
);

CREATE OR REPLACE FUNCTION public.record_match_result_and_advance_atomic(
    p_match_id UUID,
    p_home_score INT,
    p_away_score INT,
    p_home_penalties INT DEFAULT NULL,
    p_away_penalties INT DEFAULT NULL,
    p_winner_id UUID DEFAULT NULL,
    p_winner_name TEXT DEFAULT NULL,
    p_goal_details JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_match RECORD;
    v_champ RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. جلب بيانات المباراة وقفلها
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- 🔒 2. التحقق من صلاحية مالك البطولة (owner_id فقط)
    SELECT * INTO v_champ FROM public.championships WHERE id = v_match.championship_id;
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can submit scores');
            END IF;
        END IF;
    END IF;

    -- 3. تحديث نتيجة المباراة الحالية
    UPDATE public.tournament_matches
    SET 
        home_score = p_home_score,
        away_score = p_away_score,
        home_penalties = p_home_penalties,
        away_penalties = p_away_penalties,
        winner_id = p_winner_id,
        status = 'completed',
        is_completed = true,
        goal_details = COALESCE(p_goal_details, '[]'::jsonb),
        updated_at = v_now
    WHERE id = p_match_id;

    -- 4. تصعيد الفائز للمباراة التالية إذا وجدت
    IF v_match.next_match_id IS NOT NULL AND p_winner_id IS NOT NULL THEN
        IF (v_match.match_index % 2 = 0) THEN
            UPDATE public.tournament_matches
            SET home_team_id = p_winner_id,
                home_team_name = p_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        ELSE
            UPDATE public.tournament_matches
            SET away_team_id = p_winner_id,
                away_team_name = p_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'match_id', p_match_id, 'winner_id', p_winner_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_match_result_and_advance_atomic(UUID, INT, INT, INT, INT, UUID, TEXT, JSONB) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 5️⃣ دالة إرسال تقييم الملعب (submit_stadium_review_atomic)
-- الحماية: التأكد من أن التقييم يُرسل بهوية صاحب الحساب الحقيقي فقط
-- ------------------------------------------------------------------------------
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
SET search_path = public, pg_temp
AS $$
BEGIN
    -- 🔒 التحقق من أن المستخدم يقيّم بحسابه الحقيقي
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You cannot submit reviews on behalf of another user');
        END IF;
    END IF;

    IF p_rating < 1 OR p_rating > 5 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Rating must be between 1 and 5');
    END IF;

    -- إدراج أو تحديث التقييم
    INSERT INTO public.reviews (
        stadium_id,
        user_id,
        user_name,
        user_image_url,
        rating,
        comment,
        created_at
    ) VALUES (
        p_stadium_id,
        p_user_id,
        p_user_name,
        p_user_image_url,
        p_rating,
        p_comment,
        timezone('utc'::text, now())
    )
    ON CONFLICT (stadium_id, user_id) 
    DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        user_name = EXCLUDED.user_name,
        user_image_url = EXCLUDED.user_image_url,
        created_at = timezone('utc'::text, now());

    -- تحديث متوسط تقييم الملعب
    UPDATE public.stadiums
    SET 
        rating = (SELECT ROUND(AVG(rating)::numeric, 1) FROM public.reviews WHERE stadium_id = p_stadium_id),
        reviews_count = (SELECT COUNT(*) FROM public.reviews WHERE stadium_id = p_stadium_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_stadium_id;

    RETURN jsonb_build_object('success', true, 'stadium_id', p_stadium_id, 'rating', p_rating);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, INT, TEXT) TO authenticated, service_role;

COMMIT;
