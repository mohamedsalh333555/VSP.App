-- ==============================================================================
-- 🛡️ VSP SPORTS PLATFORM — PASS 2: DATABASE & SECURITY HARDENING (2026)
-- File: supabase/migrations/20260823_pass2_security_and_performance_hardening.sql
-- ==============================================================================
-- هذا السكريبت مستقل تماماً ويعالج جميع الثغرات الأمنية والأداء المكتشفة في Pass 1.
-- يرجى تشغيل هذا السكريبت في Supabase SQL Editor.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ إزالة الفهارس المكررة وإضافة الفهارس المركبة لتسريع الأداء (Indexes)
-- ------------------------------------------------------------------------------

-- حذف الفهرس المكرر على جدول الحجوزات (المطابق لـ idx_bookings_created_by_status)
DROP INDEX IF EXISTS public.idx_bookings_user_status;

-- فهرس مركب لتسريع استعلام حجوزات الملعب حسب التاريخ والشيفت
CREATE INDEX IF NOT EXISTS idx_bookings_stadium_operational_date 
ON public.bookings(stadium_id, operational_date);

-- فهرس مركب لفحص تضارب المواعيد ذرياً بسرعة فائقة
CREATE INDEX IF NOT EXISTS idx_bookings_conflict_check 
ON public.bookings(stadium_id, status, start_time, end_time);

-- فهرس مركب لتسريع مركز الإشعارات للمستخدم
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_created 
ON public.notifications(user_id, is_read, created_at DESC);

-- فهرس مركب لتسريع شجرة مباريات البطولات
CREATE INDEX IF NOT EXISTS idx_tournament_matches_bracket 
ON public.tournament_matches(championship_id, round_index, match_index);

-- فهرس مركب لرسائل المحادثات
CREATE INDEX IF NOT EXISTS idx_chat_messages_conv_created 
ON public.chat_messages(conversation_id, created_at DESC);


-- ------------------------------------------------------------------------------
-- 2️⃣ حماية وتأمين دالة الويب هوك (Restrict process_paymob_webhook to Service Role)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_paymob_webhook(
  p_booking_id TEXT,
  p_txn_id TEXT,
  p_order_id TEXT,
  p_success BOOLEAN,
  p_signature_verified BOOLEAN,
  p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_clean_id TEXT;
  v_existing_booking RECORD;
  v_already_processed BOOLEAN;
BEGIN
  -- التحقق من أن الاستدعاء قادم حصراً من الخدمة الداخلية أو service_role
  IF auth.role() IS NOT NULL AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Security Alert: Direct user invocation of payment webhook RPC is prohibited.';
  END IF;

  v_clean_id := split_part(p_booking_id, '_', 1);

  INSERT INTO public.webhook_logs (
    provider, event_type, txn_id, order_id, booking_id, payload, signature_verified, status
  )
  VALUES (
    'paymob',
    CASE WHEN p_success THEN 'payment_success' ELSE 'payment_failed' END,
    p_txn_id, p_order_id, 
    CASE WHEN v_clean_id ~ '^[0-9a-fA-F-]{36}$' THEN v_clean_id::uuid ELSE NULL END, 
    p_payload, p_signature_verified,
    CASE WHEN p_signature_verified THEN 'processed' ELSE 'unverified' END
  );

  IF p_txn_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.bookings
      WHERE paymob_txn_id = p_txn_id
        AND status = 'confirmed'
    ) INTO v_already_processed;

    IF v_already_processed THEN
      RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'duplicate_webhook_ignored',
        'booking_id', v_clean_id
      );
    END IF;
  END IF;

  SELECT * INTO v_existing_booking
  FROM public.bookings
  WHERE id::text = v_clean_id
  FOR UPDATE;

  IF v_existing_booking.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'booking_not_found',
      'message', 'No booking found matching the provided ID.'
    );
  END IF;

  IF p_success AND p_signature_verified THEN
    UPDATE public.bookings
    SET 
      status = 'confirmed',
      is_paid = TRUE,
      payment_status = 'paid',
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_verified = TRUE,
      webhook_processed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_existing_booking.id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'booking_id', v_existing_booking.id,
      'action', 'booking_confirmed'
    );
  ELSE
    UPDATE public.bookings
    SET 
      payment_status = 'failed',
      webhook_verified = p_signature_verified,
      webhook_processed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_existing_booking.id;

    RETURN jsonb_build_object(
      'success', FALSE,
      'booking_id', v_existing_booking.id,
      'action', 'payment_failed_recorded'
    );
  END IF;
END;
$$;

-- حظر الوصول العام وحصر الصلاحية بالـ service_role
REVOKE EXECUTE ON FUNCTION public.process_paymob_webhook FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_paymob_webhook TO service_role;


-- ------------------------------------------------------------------------------
-- 3️⃣ تأمين إنشاء الحجوزات ومنع تخطي الدفع (Hardened create_booking_atomic)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id TEXT,
    p_user_id TEXT,
    p_owner_id TEXT,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_booking_type TEXT,
    p_total_price NUMERIC,
    p_stadium_name TEXT DEFAULT '',
    p_stadium_image_url TEXT DEFAULT '',
    p_is_private BOOLEAN DEFAULT TRUE,
    p_rent_ball BOOLEAN DEFAULT FALSE,
    p_needs_deposit BOOLEAN DEFAULT FALSE,
    p_deposit_amount NUMERIC DEFAULT 0,
    p_payment_method TEXT DEFAULT 'cash',
    p_payment_status TEXT DEFAULT 'pending',
    p_player_team_id TEXT DEFAULT NULL,
    p_player_team_name TEXT DEFAULT NULL,
    p_opponent_team_id TEXT DEFAULT NULL,
    p_opponent_team_name TEXT DEFAULT NULL,
    p_platform_fee NUMERIC DEFAULT 0.0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_conflict_count INT;
    v_new_booking_id UUID;
    v_stadium_verified BOOLEAN;
    v_stadium_blocked BOOLEAN;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_calculated_fee NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_final_deposit_paid NUMERIC;
BEGIN
    -- قفل الملعب استشارياً لمنع الحجز المزدوج في نفس اللحظة
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- التحقق من حالة الملعب
    SELECT is_verified, is_blocked INTO v_stadium_verified, v_stadium_blocked
    FROM public.stadiums WHERE id::text = p_stadium_id;

    IF v_stadium_verified IS NOT TRUE OR v_stadium_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- التحقق من حالة المستخدم
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    -- قيود عدم الحضور على الحجز النقدي
    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- قيد الحجز النقدي الواحد النشط
    IF p_payment_method = 'cash' THEN
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > NOW();

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- فحص تضارب المواعيد
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الوقت محجوز بالفعل لمباراة أخرى.');
    END IF;

    -- 🛡️ منع التلاعب بالدفع الإلكتروني من الكلاينت (Electronic Payments must start as pending)
    IF p_payment_method = 'paymob' OR p_payment_method = 'card' OR p_payment_method = 'wallet' THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
    ELSE
        -- الحجز النقدي مؤكد
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
    END IF;

    -- حساب رسوم المنصة بدقة في الخادم
    v_calculated_fee := round((p_total_price * 0.0475) + 3.0, 2);

    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price, platform_fee,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, created_at, updated_at
    ) VALUES (
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id::uuid, p_user_id::uuid, p_owner_id::uuid,
        p_start_time, p_end_time, p_booking_type, p_total_price, v_calculated_fee,
        p_stadium_name, p_stadium_image_url, p_is_private, p_rent_ball,
        p_needs_deposit, p_deposit_amount, v_final_deposit_paid,
        p_payment_method, 'pending', v_final_status, v_final_is_paid,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id::uuid], NOW(), NOW()
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 4️⃣ تصحيح سياسة تأكيد نتائج التحديات (challenge_results RLS Policy Fix)
-- ------------------------------------------------------------------------------

DROP POLICY IF EXISTS "challenge_results_update" ON public.challenge_results;

CREATE POLICY "challenge_results_update" ON public.challenge_results
FOR UPDATE TO authenticated
USING (
  -- يمكن التعديل من المنشئ وهو معلق، أو من الخصم لتأكيده
  (auth.uid()::text = submitted_by AND status = 'pending')
  OR (status = 'pending' AND confirmed_by IS NULL AND auth.uid()::text <> submitted_by)
  OR (auth.uid()::text = confirmed_by)
)
WITH CHECK (
  -- إذا تغيرت الحالة إلى مؤكدة، يجب أن يكون المؤكد هو الخصم فقط (وليس المنشئ نفسه)
  (status = 'confirmed' AND auth.uid()::text = confirmed_by AND auth.uid()::text <> submitted_by)
  OR (status = 'pending' AND auth.uid()::text = submitted_by)
);


-- ------------------------------------------------------------------------------
-- 5️⃣ تأمين دالة حذف المستخدم (delete_user_permanently Self-Check)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_user_permanently(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- استعلام عن رتبة المستدعي
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

  -- التحقق من أن المستخدم يحذف حسابه بنفسه أو أنه أدمن
  IF auth.uid() != p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
    RAISE EXCEPTION 'Security Alert: Unauthorized account deletion request.';
  END IF;

  -- حذف سجلات المستخدم المرتبطة
  DELETE FROM public.booking_players WHERE user_id = p_user_id;
  DELETE FROM public.team_members WHERE user_id = p_user_id;
  DELETE FROM public.notifications WHERE user_id = p_user_id;
  DELETE FROM public.users WHERE id = p_user_id;
END;
$$;


-- ------------------------------------------------------------------------------
-- 6️⃣ تثبيت search_path على جميع الدوال الإدارية (Search Path Hardening)
-- ------------------------------------------------------------------------------

ALTER FUNCTION public.leave_championship_atomic(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.crown_tournament_champion_atomic(uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.crown_individual_1v1_champion(uuid, uuid, numeric) SET search_path = public, pg_temp;
ALTER FUNCTION public.leave_public_match_atomic(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.update_host_spots_atomic(uuid, uuid, integer) SET search_path = public, pg_temp;
