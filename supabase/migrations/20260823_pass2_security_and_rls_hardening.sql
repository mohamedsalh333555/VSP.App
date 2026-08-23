-- ============================================================================
-- 🛡️ VSP PRODUCTION SECURITY & RLS HARDENING MIGRATION (PASS 2 - CATEGORY 1)
-- File: supabase/migrations/20260823_pass2_security_and_rls_hardening.sql
-- ============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ تأمين دالة تحديد رتبة المستخدم ومنع التصعيد الإداري (Privilege Escalation Prevention)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(p_role text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_current_role text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to assign user role.';
  END IF;

  -- منع منح صلاحيات الإدارة ذاتياً نهائياً
  IF p_role NOT IN ('player', 'owner') THEN
    RAISE EXCEPTION 'Security Alert: Invalid role assignment attempt (%s). Only player or owner allowed.', p_role;
  END IF;

  SELECT role INTO v_current_role FROM public.users WHERE id = v_uid;

  -- إذا كان المستخدم مخصصاً كأدمن مسبقاً لا يتم تخفيضه
  IF v_current_role IN ('admin', 'co_founder') THEN
    RETURN true;
  END IF;

  UPDATE public.users
  SET 
    role = p_role,
    updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  RETURN true;
END;
$$;


-- ------------------------------------------------------------------------------
-- 2️⃣ حماية حقول المستخدم الحساسة ومنع التعديل المالي والتوثيق الذاتي (User Fields Protection)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- السماح للـ Service Role والخادم الداخلي
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  -- استعلام عن رتبة المستدعي
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

  -- السماح الكامل للإدارة
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع تعديل الرتبة وصلاحيات الحظر والاشتراكات والمحفظة من قبل المستخدم العادي
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Security Alert: Modifying user role directly is prohibited.';
  END IF;

  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'Security Alert: Modifying is_blocked status directly is prohibited.';
  END IF;

  IF NEW.is_identity_verified IS DISTINCT FROM OLD.is_identity_verified AND NEW.is_identity_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Self-verifying identity is prohibited.';
  END IF;

  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status AND NEW.verification_status IN ('approved', 'verified') THEN
    RAISE EXCEPTION 'Security Alert: Self-approving verification status is prohibited.';
  END IF;

  IF NEW.cash_booking_banned IS DISTINCT FROM OLD.cash_booking_banned THEN
    RAISE EXCEPTION 'Security Alert: Modifying cash_booking_banned status is prohibited.';
  END IF;

  IF NEW.no_show_count IS DISTINCT FROM OLD.no_show_count THEN
    RAISE EXCEPTION 'Security Alert: Modifying no_show_count directly is prohibited.';
  END IF;

  IF NEW.subscription_plan IS DISTINCT FROM OLD.subscription_plan THEN
    RAISE EXCEPTION 'Security Alert: Modifying subscription_plan directly is prohibited.';
  END IF;

  IF NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at THEN
    RAISE EXCEPTION 'Security Alert: Modifying trial_ends_at directly is prohibited.';
  END IF;

  IF NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
    RAISE EXCEPTION 'Security Alert: Modifying subscription_expires_at directly is prohibited.';
  END IF;

  IF NEW.total_platform_fees IS DISTINCT FROM OLD.total_platform_fees THEN
    RAISE EXCEPTION 'Security Alert: Modifying total_platform_fees directly is prohibited.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_user_sensitive_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.protect_user_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 3️⃣ حماية حقول الملاعب الحساسة (Stadiums Protection Trigger)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_stadium_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع توثيق أو فك حظر الملعب ذاتياً
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified AND NEW.is_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Stadium verification requires admin approval.';
  END IF;

  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked AND NEW.is_blocked = false THEN
    RAISE EXCEPTION 'Security Alert: Stadium unblocking requires admin approval.';
  END IF;

  -- منع التلاعب بالتقييم أو عدد المراجعات مباشرة من مالك الملعب
  IF NEW.rating IS DISTINCT FROM OLD.rating THEN
    NEW.rating := OLD.rating;
  END IF;

  IF NEW.reviews_count IS DISTINCT FROM OLD.reviews_count THEN
    NEW.reviews_count := OLD.reviews_count;
  END IF;

  IF NEW.is_featured IS DISTINCT FROM OLD.is_featured AND NEW.is_featured = true THEN
    RAISE EXCEPTION 'Security Alert: Featuring a stadium requires admin approval.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_stadium_sensitive_fields ON public.stadiums;
CREATE TRIGGER trg_protect_stadium_sensitive_fields
BEFORE UPDATE ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.protect_stadium_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 4️⃣ حماية إحصائيات الفرق ولوحة المتصدرين (Teams Stats Protection Trigger)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_team_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- إرجاع الإحصائيات التنافسية لقيمتها الأصلية إن تم التلاعب بها مباشرة
  NEW.points := OLD.points;
  NEW.wins := OLD.wins;
  NEW.draws := OLD.draws;
  NEW.losses := OLD.losses;
  NEW.matches_played := OLD.matches_played;
  NEW.current_winning_streak := OLD.current_winning_streak;
  NEW.championships_won := OLD.championships_won;
  NEW.is_official := OLD.is_official;
  NEW.verified_badge := OLD.verified_badge;
  NEW.attendance_score := OLD.attendance_score;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_teams_sensitive_fields ON public.teams;
CREATE TRIGGER trg_protect_teams_sensitive_fields
BEFORE UPDATE ON public.teams
FOR EACH ROW
EXECUTE FUNCTION public.protect_team_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 5️⃣ تأمين إنشاء الحجوزات ذرياً ومنع الحجز بأسماء الغير (Hardened create_booking_atomic)
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
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
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
    -- 🔒 التحقق من هوية المستدعي (منع انتحال الشخصية)
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإتمام الحجز.');
    END IF;

    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

    IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
        RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;

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

    -- فحص تضارب المواعيد بدقة
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

    -- ضبط الحالة الأولية للدفع
    IF p_payment_method IN ('paymob', 'card', 'wallet') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
    ELSE
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
-- 6️⃣ تأمين دالة تفعيل باقة Pro (Hardened activate_vsp_pro)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.activate_vsp_pro(
  p_owner_id text,
  p_transaction_id text,
  p_days integer DEFAULT 30
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
  v_owner_uuid uuid;
BEGIN
  -- التحقق من الصلاحيات الإدارية
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder') THEN
    RAISE EXCEPTION 'Security Alert: Only administrators can activate VSP Pro directly.';
  END IF;

  v_owner_uuid := p_owner_id::uuid;

  UPDATE public.users
  SET
    subscription_plan = 'pro',
    subscription_expires_at = NOW() + (p_days || ' days')::interval,
    updated_at = NOW()
  WHERE id = v_owner_uuid;

  RETURN true;
END;
$$;


-- ------------------------------------------------------------------------------
-- 7️⃣ تأمين دالة حذف الحساب نهائياً (Complete delete_user_permanently with auth.users cleanup)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_user_permanently(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

  IF auth.uid() != p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
    RAISE EXCEPTION 'Security Alert: Unauthorized account deletion request.';
  END IF;

  -- حذف كافة السجلات التابعة للمستخدم
  DELETE FROM public.booking_players WHERE user_id = p_user_id;
  DELETE FROM public.team_members WHERE user_id = p_user_id;
  DELETE FROM public.notifications WHERE user_id = p_user_id;
  DELETE FROM public.users WHERE id = p_user_id;
  
  -- إزالة السجل من auth.users إن وُجد
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;


-- ------------------------------------------------------------------------------
-- 8️⃣ إضافة سياسات RLS المفقودة (Add Missing RLS Policies)
-- ------------------------------------------------------------------------------

-- A. booking_players: تمكين القراءة لأطراف الحجز والإدارة
DROP POLICY IF EXISTS "booking_players_select_policy" ON public.booking_players;
CREATE POLICY "booking_players_select_policy" ON public.booking_players
FOR SELECT TO authenticated
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM public.bookings b 
    WHERE b.id = booking_players.booking_id 
      AND (b.owner_id = auth.uid() OR b.created_by_user_id = auth.uid() OR auth.uid() = ANY(COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))
  ) OR
  EXISTS (
    SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
  )
);

-- B. championship_roster_guests: تمكين القراءة العامة لضيوف قوائم البطولات
DROP POLICY IF EXISTS "roster_guests_select_policy" ON public.championship_roster_guests;
CREATE POLICY "roster_guests_select_policy" ON public.championship_roster_guests
FOR SELECT TO public
USING (true);

-- C. حماية بيانات المستخدمين العامة من تسريب البيانات الشخصية للـ anon
DROP POLICY IF EXISTS "users_select_anon" ON public.users;
CREATE POLICY "users_select_anon" ON public.users
FOR SELECT TO anon
USING (
  is_blocked = false AND 
  is_registration_complete = true
);


-- ------------------------------------------------------------------------------
-- 9️⃣ دالة الإغلاق الطارئ الذري للملعب وإلغاء الحجوزات المتأثرة (Atomic Emergency Closure)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_emergency_stadium_closure(
  p_stadium_id uuid,
  p_owner_id uuid,
  p_reason text,
  p_duration_hours integer DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_last_closure timestamptz;
  v_days_diff integer;
  v_maintenance_until timestamptz;
  v_affected_bookings_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Authentication required.');
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

  -- التحقق من ملكية الملعب
  IF NOT EXISTS (
    SELECT 1 FROM public.stadiums 
    WHERE id = p_stadium_id AND (owner_id = v_caller_id OR v_caller_role IN ('admin', 'co_founder'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإدارة هذا الملعب.');
  END IF;

  -- فحص آخر إغلاق طارئ (مهلة 30 يوم)
  SELECT last_emergency_closure_at INTO v_last_closure 
  FROM public.stadiums WHERE id = p_stadium_id;

  IF v_last_closure IS NOT NULL THEN
    v_days_diff := EXTRACT(DAY FROM (NOW() - v_last_closure));
    IF v_days_diff < 30 AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
      RETURN jsonb_build_object(
        'success', false, 
        'message', format('لقد استخدمت حق الإلغاء الطارئ لهذا الشهر مسبقاً. متبقي %s يوم لإعادة تفعيل الميزة.', 30 - v_days_diff)
      );
    END IF;
  END IF;

  v_maintenance_until := NOW() + (p_duration_hours || ' hours')::interval;

  -- تحديث حالة الملعب
  UPDATE public.stadiums
  SET
    maintenance_until = v_maintenance_until,
    maintenance_reason = p_reason,
    last_emergency_closure_at = NOW(),
    updated_at = NOW()
  WHERE id = p_stadium_id;

  -- تحويل الحجوزات المتداخلة للإلغاء الطارئ والمراجعة الإدارية
  UPDATE public.bookings
  SET
    emergency_cancel_status = 'pending_admin_approval',
    emergency_reason = p_reason,
    emergency_downtime_hours = p_duration_hours,
    updated_at = NOW()
  WHERE stadium_id = p_stadium_id
    AND status = 'confirmed'
    AND start_time >= NOW()
    AND start_time <= v_maintenance_until;

  GET DIAGNOSTICS v_affected_bookings_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'affected_bookings', v_affected_bookings_count,
    'maintenance_until', v_maintenance_until
  );
END;
$$;

