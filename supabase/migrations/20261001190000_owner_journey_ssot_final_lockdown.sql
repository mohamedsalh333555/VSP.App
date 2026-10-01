-- Migration: 20261001190000_owner_journey_ssot_final_lockdown.sql
-- Description:
--   1. Lock down evaluate_owner_stadium_capacity:
--      - Revoke EXECUTE from PUBLIC and anon.
--      - Keep EXECUTE for authenticated, service_role, postgres.
--      - Add server-side caller validation: anon/cross-owner execution rejected with 42501 UNAUTHORIZED.
--      - Fix Trial SSOT: read trial_days directly from basic plan in subscription_plans (not MAX across unrelated plans).
--   2. Secure owner_subscription_status VIEW:
--      - Set WITH (security_invoker = true).
--      - Add row filter ensuring owners only see their own row (u.id = auth.uid() OR public.is_admin_or_cofounder(auth.uid()) OR current_user IN ('postgres', 'service_role')).
--      - Revoke SELECT from anon and PUBLIC.
--      - Fix Trial SSOT: read trial_days directly from basic plan in subscription_plans.
--   3. Separate Dashboard Operational Revenue from Realized Revenue:
--      - In get_owner_dashboard_analytics, differentiate realized_revenue (completed/no_show) from upcoming_confirmed_value (confirmed/upcoming).
--      - Expose both distinctly in JSON alongside total operational value.

-- -----------------------------------------------------------------------------
-- 1. LOCK DOWN evaluate_owner_stadium_capacity & FIX TRIAL SSOT
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.evaluate_owner_stadium_capacity(
  p_owner_id uuid,
  p_exclude_stadium_id uuid DEFAULT NULL
)
RETURNS TABLE (
  allowed boolean,
  current_count integer,
  max_allowed integer,
  is_trial boolean,
  is_sub_active boolean,
  plan_code text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner              public.users%ROWTYPE;
  v_allowed_count      integer := 0;
  v_active_count       integer := 0;
  v_is_active_trial    boolean := false;
  v_is_sub_active      boolean := false;
  v_trial_days         integer := 365;
  v_plan_record        public.subscription_plans%ROWTYPE;
BEGIN
  -- Caller authorization check:
  -- When executed by non-internal roles, ensure caller is authenticated and matches target owner or is admin/cofounder
  IF COALESCE(current_setting('request.jwt.claim.role', true), '') = 'authenticated' THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للتحقق من باقة المالك.'
        USING ERRCODE = '42501';
    END IF;
    IF auth.uid() <> p_owner_id AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالاطلاع على باقة مالك آخر.'
        USING ERRCODE = '42501';
    END IF;
  ELSIF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id THEN
    IF NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالاطلاع على باقة مالك آخر.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 1. Fetch owner record
  SELECT * INTO v_owner
  FROM public.users
  WHERE id = p_owner_id;

  IF v_owner.id IS NULL THEN
    RETURN QUERY SELECT false, 0, 0, false, false, ''::text, 'مالك الملعب غير موجود في النظام.'::text;
    RETURN;
  END IF;

  -- 2. Admins and co-founders bypass limits
  IF v_owner.role IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    SELECT count(*)::integer INTO v_active_count
    FROM public.stadiums
    WHERE owner_id = p_owner_id
      AND COALESCE(is_deleted_by_owner, false) = false
      AND (p_exclude_stadium_id IS NULL OR id <> p_exclude_stadium_id);

    RETURN QUERY SELECT true, v_active_count, 999, false, true, 'admin'::text, 'حساب إداري - ملاعب غير محدودة'::text;
    RETURN;
  END IF;

  -- 3. Read canonical trial duration directly from authoritative base trial plan ('basic')
  SELECT COALESCE(sp.trial_days, 365) INTO v_trial_days
  FROM public.subscription_plans sp
  WHERE sp.code = 'basic' AND sp.is_active = true;

  IF v_trial_days IS NULL THEN
    v_trial_days := 365;
  END IF;

  -- 4. Check active trial status
  v_is_active_trial := (
    COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
    (
      (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
      (v_owner.trial_ends_at IS NULL AND v_owner.created_at + (v_trial_days || ' days')::interval > NOW())
    )
  );

  -- 5. Check paid subscription status
  v_is_sub_active := (
    v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
  );

  -- 6. Read max_stadiums dynamically from subscription_plans based on active plan/state
  IF v_is_sub_active AND v_owner.subscription_plan IS NOT NULL THEN
    SELECT * INTO v_plan_record
    FROM public.subscription_plans
    WHERE code = v_owner.subscription_plan AND is_active = true;

    IF v_plan_record.code IS NOT NULL THEN
      v_allowed_count := v_plan_record.max_stadiums;
    ELSE
      v_allowed_count := 0;
    END IF;
  ELSIF v_is_active_trial THEN
    -- Trial capacity matches the base active plan in subscription_plans
    SELECT COALESCE(sp.max_stadiums, 1) INTO v_allowed_count
    FROM public.subscription_plans sp
    WHERE sp.code = 'basic' AND sp.is_active = true;
  ELSE
    v_allowed_count := 0;
  END IF;

  -- 7. Count existing active (non-soft-deleted) stadiums
  SELECT count(*)::integer INTO v_active_count
  FROM public.stadiums
  WHERE owner_id = p_owner_id
    AND COALESCE(is_deleted_by_owner, false) = false
    AND (p_exclude_stadium_id IS NULL OR id <> p_exclude_stadium_id);

  -- 8. Return evaluation result
  IF v_active_count >= v_allowed_count THEN
    IF v_allowed_count = 0 THEN
      RETURN QUERY SELECT false, v_active_count, v_allowed_count, v_is_active_trial, v_is_sub_active, COALESCE(v_owner.subscription_plan, 'none'),
        'انتهت صلاحية باقة الاشتراك الخاصة بك. يرجى تجديد الاشتراك لإضافة أو تفعيل ملاعب.'::text;
    ELSE
      RETURN QUERY SELECT false, v_active_count, v_allowed_count, v_is_active_trial, v_is_sub_active, COALESCE(v_owner.subscription_plan, 'none'),
        format('وصلت للحد الأقصى للملاعب في باقتك الحالية (%s ملعب). يرجى الترقية لإضافة أو تفعيل ملاعب أخرى.', v_allowed_count)::text;
    END IF;
  ELSE
    RETURN QUERY SELECT true, v_active_count, v_allowed_count, v_is_active_trial, v_is_sub_active, COALESCE(v_owner.subscription_plan, 'none'),
      'مسموح بإضافة أو تفعيل الملعب'::text;
  END IF;
END;
$$;

-- Explicitly revoke from PUBLIC and anon
REVOKE ALL ON FUNCTION public.evaluate_owner_stadium_capacity(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.evaluate_owner_stadium_capacity(uuid, uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. SECURE owner_subscription_status VIEW (SECURITY INVOKER + ROW ISOLATION)
-- -----------------------------------------------------------------------------

DROP VIEW IF EXISTS public.owner_subscription_status;

CREATE VIEW public.owner_subscription_status
WITH (security_invoker = true)
AS
SELECT 
  u.id,
  u.name,
  u.phone,
  u.verification_status,
  u.subscription_plan,
  u.trial_ends_at,
  u.subscription_expires_at,
  u.total_platform_fees,
  CASE
    WHEN u.subscription_plan IS NOT NULL AND u.subscription_expires_at > now() THEN 'active_paid'
    WHEN COALESCE(u.subscription_plan, 'free_trial') = 'free_trial' AND 
         COALESCE(u.trial_ends_at, u.created_at + ((SELECT COALESCE(trial_days, 365) FROM public.subscription_plans WHERE code = 'basic' AND is_active = true) || ' days')::interval) > now() THEN 'active_trial'
    ELSE 'expired'
  END AS effective_status,
  CASE
    WHEN u.subscription_plan IS NOT NULL AND u.subscription_expires_at > now() THEN 
      COALESCE((SELECT sp.max_stadiums FROM public.subscription_plans sp WHERE sp.code = u.subscription_plan AND sp.is_active = true), 0)
    WHEN COALESCE(u.subscription_plan, 'free_trial') = 'free_trial' AND 
         COALESCE(u.trial_ends_at, u.created_at + ((SELECT COALESCE(trial_days, 365) FROM public.subscription_plans WHERE code = 'basic' AND is_active = true) || ' days')::interval) > now() THEN 
      COALESCE((SELECT sp.max_stadiums FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true), 1)
    ELSE 0
  END AS max_stadiums_allowed
FROM public.users u
WHERE u.role = 'owner'
  AND (
    u.id = auth.uid()
    OR public.is_admin_or_cofounder(auth.uid())
    OR current_user IN ('postgres', 'service_role')
  );

REVOKE ALL ON public.owner_subscription_status FROM PUBLIC, anon;
GRANT SELECT ON public.owner_subscription_status TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. SEPARATE DASHBOARD OPERATIONAL REVENUE FROM REALIZED REVENUE
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_owner_dashboard_analytics(
  p_owner_id uuid,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone,
  p_court_id uuid DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result              JSON;
  v_total_op_hours      NUMERIC := 0;
  v_booked_hours        NUMERIC := 0;
  v_total_revenue       NUMERIC := 0;
  v_cash_revenue        NUMERIC := 0;
  v_online_revenue      NUMERIC := 0;
  v_realized_revenue    NUMERIC := 0;
  v_realized_cash       NUMERIC := 0;
  v_realized_online     NUMERIC := 0;
  v_upcoming_value      NUMERIC := 0;
  v_upcoming_cash       NUMERIC := 0;
  v_upcoming_online     NUMERIC := 0;
  v_total_bookings      INTEGER := 0;
  v_cash_bookings       INTEGER := 0;
  v_online_bookings     INTEGER := 0;
  v_period_days         INTEGER;
  v_avg_hourly_rate     NUMERIC := 200;
  v_stadium_count       INTEGER := 1;
BEGIN
  -- Server-side Authentication & Authorization Guard
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للوصول إلى تحليلات لوحة التحكم.'
      USING ERRCODE = '42501';
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
    IF NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالوصول إلى بيانات هذا المالك.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- عدد الأيام في الفترة
  v_period_days := GREATEST(1, DATE_PART('day', p_end_date - p_start_date)::INTEGER);

  -- متوسط سعر الساعة لملاعب المالك
  SELECT COALESCE(AVG(price_per_hour), 200)
  INTO v_avg_hourly_rate
  FROM stadiums
  WHERE owner_id = p_owner_id
    AND (p_court_id IS NULL OR id = p_court_id)
    AND price_per_hour > 0;

  IF v_avg_hourly_rate IS NULL OR v_avg_hourly_rate <= 0 THEN
    v_avg_hourly_rate := 200;
  END IF;

  -- حساب ساعات التشغيل الفعلية خلال الفترة من جدول court_operating_hours
  SELECT COALESCE(SUM(
    CASE
      WHEN oh.close_time > oh.open_time
        THEN EXTRACT(EPOCH FROM (oh.close_time - oh.open_time)) / 3600.0
      ELSE
        EXTRACT(EPOCH FROM ('24:00:00'::TIME - oh.open_time + oh.close_time)) / 3600.0
    END
  ) * v_period_days, 0)
  INTO v_total_op_hours
  FROM court_operating_hours oh
  JOIN stadiums c ON c.id = oh.court_id
  WHERE c.owner_id = p_owner_id
    AND (p_court_id IS NULL OR oh.court_id = p_court_id)
    AND oh.is_closed = FALSE;

  -- لو مفيش ساعات تشغيل معرّفة، افترض 10 ساعات يومياً كـ default معقول لكل ملعب
  IF v_total_op_hours = 0 THEN
    IF p_court_id IS NOT NULL THEN
      v_stadium_count := 1;
    ELSE
      SELECT GREATEST(1, COUNT(*)::INTEGER) 
      INTO v_stadium_count 
      FROM stadiums 
      WHERE owner_id = p_owner_id AND is_deleted_by_owner = FALSE;
    END IF;
    v_total_op_hours := 10.0 * v_period_days * v_stadium_count;
  END IF;

  -- 1. حساب الحجوزات والإيرادات التشغيلية الكلية للفترة (Operational Booking Metrics)
  SELECT
    COUNT(b.id),
    COUNT(b.id) FILTER (WHERE b.payment_method = 'cash' OR b.payment_source = 'pitch_cash'),
    COUNT(b.id) FILTER (WHERE NOT (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash')),
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN NOT (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0),
    COALESCE(SUM(
      GREATEST(0, EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600.0)
    ), 0)
  INTO
    v_total_bookings,
    v_cash_bookings,
    v_online_bookings,
    v_total_revenue,
    v_cash_revenue,
    v_online_revenue,
    v_booked_hours
  FROM bookings b
  WHERE b.owner_id = p_owner_id
    AND (p_court_id IS NULL OR b.stadium_id = p_court_id)
    AND b.start_time >= p_start_date
    AND b.start_time < p_end_date
    AND b.status IN ('confirmed', 'completed', 'upcoming');

  -- 2. الإيراد المحقق فعلياً (Realized Accounting Revenue: played completed or no-show bookings)
  SELECT
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN NOT (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0)
  INTO
    v_realized_revenue,
    v_realized_cash,
    v_realized_online
  FROM bookings b
  WHERE b.owner_id = p_owner_id
    AND (p_court_id IS NULL OR b.stadium_id = p_court_id)
    AND b.start_time >= p_start_date
    AND b.start_time < p_end_date
    AND b.status IN ('completed', 'no_show');

  -- 3. قيمة الحجوزات المؤكدة القادمة (Upcoming Confirmed Operational Value: future matches awaiting play)
  SELECT
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN NOT (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0)
  INTO
    v_upcoming_value,
    v_upcoming_cash,
    v_upcoming_online
  FROM bookings b
  WHERE b.owner_id = p_owner_id
    AND (p_court_id IS NULL OR b.stadium_id = p_court_id)
    AND b.start_time >= p_start_date
    AND b.start_time < p_end_date
    AND b.status IN ('confirmed', 'upcoming')
    AND b.end_time > now();

  -- ضمان التماسك الرياضي التام (total == cash + online دايماً)
  IF (v_total_revenue - (v_cash_revenue + v_online_revenue)) <> 0 THEN
    v_cash_revenue := v_total_revenue - v_online_revenue;
  END IF;

  -- بناء النتيجة JSON بفصل المحقق عن المتوقع
  SELECT json_build_object(
    'meta', json_build_object(
      'start_date',   p_start_date,
      'end_date',     p_end_date,
      'period_days',  v_period_days
    ),
    'revenue', json_build_object(
      'total',                     ROUND(v_total_revenue, 2),
      'cash',                      ROUND(v_cash_revenue, 2),
      'online',                    ROUND(v_online_revenue, 2),
      'cash_percentage',           CASE WHEN v_total_revenue > 0
                                     THEN ROUND((v_cash_revenue / v_total_revenue) * 100, 1)
                                     ELSE 0 END,
      'online_percentage',         CASE WHEN v_total_revenue > 0
                                     THEN ROUND((v_online_revenue / v_total_revenue) * 100, 1)
                                     ELSE 0 END,
      'realized_revenue',          ROUND(v_realized_revenue, 2),
      'realized_cash',             ROUND(v_realized_cash, 2),
      'realized_online',           ROUND(v_realized_online, 2),
      'upcoming_confirmed_value',  ROUND(v_upcoming_value, 2),
      'upcoming_cash_value',       ROUND(v_upcoming_cash, 2),
      'upcoming_online_value',     ROUND(v_upcoming_online, 2),
      'unrealized',                ROUND(
                                     GREATEST(v_total_op_hours - v_booked_hours, 0) * v_avg_hourly_rate,
                                   2)
    ),
    'bookings', json_build_object(
      'total_count',    v_total_bookings,
      'cash_count',     v_cash_bookings,
      'online_count',   v_online_bookings,
      'average_price',  CASE WHEN v_total_bookings > 0
                          THEN ROUND(v_total_revenue / v_total_bookings, 2)
                          ELSE 0 END
    ),
    'capacity', json_build_object(
      'total_operating_hours', ROUND(v_total_op_hours, 1),
      'booked_hours',          ROUND(v_booked_hours, 1),
      'unbooked_hours',        ROUND(GREATEST(v_total_op_hours - v_booked_hours, 0), 1),
      'occupancy_rate',        CASE WHEN v_total_op_hours > 0
                                 THEN ROUND((v_booked_hours / v_total_op_hours) * 100, 1)
                                 ELSE 0 END
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_owner_dashboard_analytics(uuid, timestamptz, timestamptz, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_owner_dashboard_analytics(uuid, timestamptz, timestamptz, uuid) TO authenticated, service_role;
