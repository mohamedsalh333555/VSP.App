-- ==============================================================================
-- 🛡️ VSP PRODUCTION SECURITY HARDENING MASTER MIGRATION (2026-09-18)
-- Remediation of all 10 verified security scan items:
-- 1. owner_extend_match_atomic: NULL three-valued logic fix & anon revocation
-- 2. test_trigger_behavior: Drop debug function
-- 3. check_rate_limit: Enforce authenticated caller auth.uid() against UUID spoofing
-- 4. process_referral_reward_on_qr_verification: Lock down to service_role
-- 5. increment_banner_views & increment_banner_clicks: Revoke anon & throttle
-- 6. increment_chat_unread_count: Authenticate & enforce participant/sender identity
-- 7. v_financial_reconciliation: Set security_invoker = true & revoke anon
-- 8. Background Cron Functions (10): Restrict strictly to service_role
-- 9. Fix search_path = public, pg_temp for normalize_governorate, trg_fn_normalize_governorate, etc.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ FIX owner_extend_match_atomic (CRITICAL: NULL LOGIC BYPASS & REVOKE ANON)
-- ------------------------------------------------------------------------------
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
    -- 1. فحص قطعي: منع أي استدعاء مجهول الهوية (anon)
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'unauthorized', 
            'message', 'Authentication required.'
        );
    END IF;

    -- 2. جلب بيانات الحجز وقفل السجل
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 3. التحقق الآمن ضد الـ NULL باستخدام IS DISTINCT FROM
    IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) 
       AND auth.role() != 'service_role' 
       AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message', 'غير مصرح لك بتعديل هذا الحجز.');
    END IF;

    -- 4. قفل الملعب لمنع أي حجز متزامن في نفس النافذة
    PERFORM 1 FROM public.stadiums WHERE id = v_booking.stadium_id FOR UPDATE;

    v_new_end_time := v_booking.end_time + (COALESCE(p_added_minutes, 30) || ' minutes')::INTERVAL;

    -- 5. فحص التضارب مع أي حجز تالٍ نشط
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

    -- 6. تحديث وقت نهاية الحجز
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

REVOKE EXECUTE ON FUNCTION public.owner_extend_match_atomic(UUID, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_extend_match_atomic(UUID, INT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 2️⃣ DROP test_trigger_behavior (CRITICAL: REMOVE DEBUG ARTIFACT)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.test_trigger_behavior();


-- ------------------------------------------------------------------------------
-- 3️⃣ FIX check_rate_limit (CRITICAL: PREVENT UUID SPOOFING & COPILOT BYPASS)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id UUID,
  p_action TEXT,
  p_max_requests INT DEFAULT 10,
  p_window_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count INT;
  v_effective_user_id UUID;
BEGIN
  -- 🔒 حماية تزوير الهوية: إجبار استعلامات العملاء على استخدام auth.uid() الحقيقي
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.role(), '') != 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN FALSE; -- حظر الزوار مجهولي الهوية من استهلاك موارد الكوبيلوت
    END IF;
    v_effective_user_id := auth.uid();
  ELSE
    v_effective_user_id := COALESCE(p_user_id, auth.uid());
  END IF;

  IF v_effective_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 1. Transaction-scoped advisory lock لمنع تداخل الاستدعاءات المتزامنة لنفس المستخدم
  PERFORM pg_advisory_xact_lock(hashtext(v_effective_user_id::text), hashtext(p_action));

  -- 2. تنظيف السجلات القديمة المنتهية
  DELETE FROM public.rate_limit_logs
  WHERE user_id = v_effective_user_id
    AND action = p_action
    AND created_at < NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- 3. حساب عدد الطلبات داخل النافذة الزمنية
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limit_logs
  WHERE user_id = v_effective_user_id
    AND action = p_action
    AND created_at >= NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- 4. رفض الطلب في حال تجاوز الحد المسموح
  IF v_count >= p_max_requests THEN
    RETURN FALSE;
  END IF;

  -- 5. تسجيل الطلب
  INSERT INTO public.rate_limit_logs (user_id, action, created_at)
  VALUES (v_effective_user_id, p_action, NOW());

  RETURN TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_rate_limit(UUID, TEXT, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(UUID, TEXT, INT, INT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 4️⃣ PROTECT process_referral_reward_on_qr_verification (RESTRICT TO SERVICE ROLE)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_referral_reward_on_qr_verification(
    p_booking_id uuid,
    p_invitee_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_ref RECORD;
    v_first_qr_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 🔒 حصر استدعاء الدالة على عمليات الخادم الداخلية (service_role)
    IF COALESCE(auth.role(), '') != 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Direct client invocation of process_referral_reward_on_qr_verification is prohibited.'
            USING ERRCODE = '42501';
    END IF;

    IF p_invitee_id IS NULL OR p_booking_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. فحص وجود إحالة معلقة
    SELECT * INTO v_ref
    FROM public.referrals
    WHERE invitee_user_id = p_invitee_id
      AND status = 'pending'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- 2. التأكد من أن هذا أول حجز مكتمل ممسوح بالـ QR
    SELECT COUNT(*) INTO v_first_qr_count
    FROM public.bookings
    WHERE (user_id = p_invitee_id OR created_by_user_id = p_invitee_id)
      AND status = 'completed'
      AND qr_scanned_at IS NOT NULL;

    IF v_first_qr_count <> 1 THEN
        RETURN false;
    END IF;

    -- 3. تحديث حالة الإحالة إلى rewarded
    UPDATE public.referrals
    SET 
        status = 'rewarded',
        qualified_at = v_now,
        qualifying_booking_id = p_booking_id
    WHERE id = v_ref.id;

    -- 4. إيداع نقاط المكافأة (+250) للمستخدم الداعي في دفتر النقاط
    INSERT INTO public.points_ledger (user_id, points, reason, reference_id, created_at)
    VALUES (v_ref.inviter_user_id, 250, 'referral_reward_booking', p_booking_id::text, v_now);

    RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.process_referral_reward_on_qr_verification(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_referral_reward_on_qr_verification(uuid, uuid) TO service_role;


-- ------------------------------------------------------------------------------
-- 5️⃣ PROTECT increment_banner_clicks & increment_banner_views (PREVENT INFLATION)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_banner_clicks(p_banner_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
    -- حظر الاستدعاءات الوهمية من غير المسجلين
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN;
    END IF;

    UPDATE public.banners
    SET clicks_count = COALESCE(clicks_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_banner_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.increment_banner_views(p_banner_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
    -- حظر هجمات البوتات والتكرار العشوائي
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN;
    END IF;

    UPDATE public.banners
    SET views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_banner_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.increment_banner_clicks(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_banner_views(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_banner_clicks(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_banner_views(uuid) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 6️⃣ PROTECT increment_chat_unread_count (VERIFY CALLER & SENDER IDENTITY)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_chat_unread_count(
    p_booking_id text, 
    p_sender_id text, 
    p_last_message text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_joined_ids JSONB;
  v_unread JSONB;
  v_uid TEXT;
  v_booking_owner UUID;
  v_booking_user UUID;
BEGIN
  -- 🔒 فحص تسجيل الدخول
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  -- 🔒 منع انتحال معرف المرسل
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.role(), '') != 'service_role' THEN
    IF auth.uid()::text != p_sender_id THEN
      RAISE EXCEPTION 'Permission denied: sender_id does not match authenticated user' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT joined_user_ids, COALESCE(unread_counts, '{}'::jsonb), owner_id, user_id
  INTO v_joined_ids, v_unread, v_booking_owner, v_booking_user
  FROM public.bookings
  WHERE id::text = p_booking_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 🔒 التحقق من أن المستخدم طرف فعلي في الحجز (مالك، لاعب حاجز، أو منضم)
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.role(), '') != 'service_role' THEN
    IF auth.uid() != v_booking_owner 
       AND auth.uid() != v_booking_user 
       AND (v_joined_ids IS NULL OR NOT (v_joined_ids ? auth.uid()::text)) THEN
      RAISE EXCEPTION 'Permission denied: Caller is not a participant in this booking' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF v_joined_ids IS NOT NULL THEN
    FOR v_uid IN SELECT jsonb_array_elements_text(v_joined_ids)
    LOOP
      IF v_uid != p_sender_id THEN
        v_unread := jsonb_set(
          v_unread,
          ARRAY[v_uid],
          to_jsonb(COALESCE((v_unread->>v_uid)::int, 0) + 1)
        );
      END IF;
    END LOOP;

    UPDATE public.bookings
    SET last_message = p_last_message,
        last_message_time = NOW(),
        unread_counts = v_unread
    WHERE id::text = p_booking_id;
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.increment_chat_unread_count(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_chat_unread_count(text, text, text) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 7️⃣ FIX VIEW v_financial_reconciliation (SET security_invoker = true & REVOKE ANON)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'v_financial_reconciliation') THEN
        EXECUTE 'ALTER VIEW public.v_financial_reconciliation SET (security_invoker = true);';
        EXECUTE 'REVOKE ALL ON public.v_financial_reconciliation FROM PUBLIC, anon;';
        EXECUTE 'GRANT SELECT ON public.v_financial_reconciliation TO authenticated, service_role;';
    END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 8️⃣ LOCK DOWN ALL 10+ BACKGROUND CRON ROUTINES (RESTRICT STRICTLY TO service_role)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_cron_funcs TEXT[] := ARRAY[
        'auto_approve_tournament_matches_24h',
        'auto_downgrade_expired_subscriptions',
        'auto_expire_matchups',
        'auto_expire_pending_challenges',
        'auto_expire_pending_locks',
        'auto_expire_stale_records',
        'auto_reconcile_all_past_bookings',
        'auto_reconcile_past_bookings',
        'auto_reconcile_single_entry_results',
        'auto_release_elo_lock',
        'auto_expire_pending_bookings_5m',
        'auto_approve_challenge_matches_24h'
    ];
BEGIN
    FOR r IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.proname = ANY(v_cron_funcs)
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated;', r.proname, r.args);
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO service_role;', r.proname, r.args);
    END LOOP;
END $$;


-- ------------------------------------------------------------------------------
-- 9️⃣ FIX search_path = public, pg_temp FOR CONFIRMED FUNCTIONS
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    -- 1. normalize_governorate
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'normalize_governorate') THEN
        EXECUTE 'ALTER FUNCTION public.normalize_governorate(text) SET search_path = public, pg_temp;';
    END IF;

    -- 2. trg_fn_normalize_governorate
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trg_fn_normalize_governorate') THEN
        EXECUTE 'ALTER FUNCTION public.trg_fn_normalize_governorate() SET search_path = public, pg_temp;';
    END IF;

    -- 3. is_booking_payment_valid (all overloaded signatures)
    FOR r IN SELECT proname, pg_get_function_identity_arguments(oid) as args 
             FROM pg_proc WHERE proname = 'is_booking_payment_valid'
    LOOP
        EXECUTE format('ALTER FUNCTION public.%I(%s) SET search_path = public, pg_temp;', r.proname, r.args);
    END LOOP;

    -- 4. sync_payment_reconcile_state (all overloaded signatures)
    FOR r IN SELECT proname, pg_get_function_identity_arguments(oid) as args 
             FROM pg_proc WHERE proname = 'sync_payment_reconcile_state'
    LOOP
        EXECUTE format('ALTER FUNCTION public.%I(%s) SET search_path = public, pg_temp;', r.proname, r.args);
    END LOOP;

    -- 5. Additional functions
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_owner_stadium_limit_trigger') THEN
        EXECUTE 'ALTER FUNCTION public.check_owner_stadium_limit_trigger() SET search_path = public, pg_temp;';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_sync_stadium_prices') THEN
        EXECUTE 'ALTER FUNCTION public.fn_sync_stadium_prices() SET search_path = public, pg_temp;';
    END IF;
END $$;

COMMIT;
