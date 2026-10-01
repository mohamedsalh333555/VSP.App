-- Migration: 20261001180000_owner_journey_ssot_security_and_reactivation_guard.sql
-- Description:
--   1. Authoritative Subscription SSOT (evaluate_owner_stadium_capacity):
--      - Derives trial duration and max allowed stadiums dynamically from public.subscription_plans.
--      - Removes hardcoded 365, 1, and 3 from operational limits.
--      - All stadium limit checks call this single authoritative evaluator.
--      - Retires obsolete 0-arg check_owner_stadium_limit() trigger duplicate.
--      - Rebuilds owner_subscription_status view dynamically from subscription_plans without SECURITY DEFINER.
--   2. Stadium Reactivation Limit:
--      - Enforces stadium limit guard on is_deleted_by_owner (true -> false) reactivation transitions.
--   3. Security Hardening for get_owner_dashboard_analytics:
--      - Adds server-side caller verification (only owner or platform admins).
--      - Revokes public/anon EXECUTE permissions.
--   4. Verification Function Security Cleanup:
--      - Replaces deprecated auth.role() in submit_owner_verification with modern secure server-side check.

-- -----------------------------------------------------------------------------
-- 1. AUTHORITATIVE SUBSCRIPTION SSOT EVALUATOR
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

  -- 3. Read canonical trial duration from subscription_plans
  SELECT COALESCE(MAX(sp.trial_days), 365) INTO v_trial_days
  FROM public.subscription_plans sp
  WHERE sp.is_active = true;

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

-- -----------------------------------------------------------------------------
-- 2. UNIFIED STADIUM TRIGGER GUARD (CREATION & REACTIVATION)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.vsp_guard_stadium_owner_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_eval               record;
  v_caller             uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.owner_id IS NULL THEN
      RAISE EXCEPTION 'stadium_owner_required';
    END IF;

    -- Concurrency lock on owner record
    PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;

    SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(NEW.owner_id);
    IF NOT v_eval.allowed THEN
      RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: %', v_eval.message
        USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
    END IF;

    NEW.is_verified := false;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF v_caller = OLD.owner_id AND NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
      RAISE EXCEPTION 'owner_cannot_reassign_stadium: لا يمكن نقل ملكية الملعب لمستخدم آخر.';
    END IF;

    -- Stadium Reactivation Limit:
    -- When un-deleting a soft-deleted stadium (is_deleted_by_owner: true -> false)
    IF OLD.is_deleted_by_owner IS TRUE AND NEW.is_deleted_by_owner IS FALSE THEN
      PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;

      -- Check if reactivating this stadium would exceed allowed capacity
      SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(NEW.owner_id, NEW.id);
      IF NOT v_eval.allowed THEN
        RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: %', v_eval.message
          USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
      END IF;
    END IF;

    -- Reset verification if stadium critical specs changed by owner
    IF v_caller = OLD.owner_id THEN
      IF NEW.name IS DISTINCT FROM OLD.name
         OR NEW.location IS DISTINCT FROM OLD.location
         OR NEW.governorate IS DISTINCT FROM OLD.governorate
         OR NEW.price_per_hour IS DISTINCT FROM OLD.price_per_hour
         OR NEW.base_price IS DISTINCT FROM OLD.base_price
         OR NEW.players_per_team IS DISTINCT FROM OLD.players_per_team
         OR NEW.total_field_capacity IS DISTINCT FROM OLD.total_field_capacity
         OR NEW.opening_time IS DISTINCT FROM OLD.opening_time
         OR NEW.closing_time IS DISTINCT FROM OLD.closing_time
         OR NEW.needs_deposit IS DISTINCT FROM OLD.needs_deposit
         OR NEW.deposit_amount IS DISTINCT FROM OLD.deposit_amount
         OR NEW.images IS DISTINCT FROM OLD.images
         OR NEW.image_url IS DISTINCT FROM OLD.image_url
         OR NEW.features IS DISTINCT FROM OLD.features
         OR NEW.lat IS DISTINCT FROM OLD.lat
         OR NEW.lng IS DISTINCT FROM OLD.lng THEN
        NEW.is_verified := false;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. UNIFY check_owner_stadium_limit RPC & RETIRE 0-ARG DUPLICATE
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.check_owner_stadium_limit();

CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_eval record;
BEGIN
  IF v_caller IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'Authentication required');
  END IF;

  IF v_caller IS NOT NULL AND v_caller IS DISTINCT FROM p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
    IF NOT public.is_admin_or_cofounder(v_caller) THEN
      RETURN jsonb_build_object('allowed', false, 'message', 'Unauthorized access to owner stadium limits');
    END IF;
  END IF;

  SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(p_owner_id);

  RETURN jsonb_build_object(
    'allowed', v_eval.allowed,
    'current_count', v_eval.current_count,
    'max_allowed', v_eval.max_allowed,
    'is_trial', v_eval.is_trial,
    'is_sub_active', v_eval.is_sub_active,
    'plan_code', v_eval.plan_code,
    'message', v_eval.message
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_owner_stadium_limit(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_owner_stadium_limit(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. RECREATE owner_subscription_status VIEW FROM subscription_plans
-- -----------------------------------------------------------------------------

DROP VIEW IF EXISTS public.owner_subscription_status;

CREATE VIEW public.owner_subscription_status AS
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
         COALESCE(u.trial_ends_at, u.created_at + ((SELECT COALESCE(MAX(trial_days), 365) FROM public.subscription_plans WHERE is_active = true) || ' days')::interval) > now() THEN 'active_trial'
    ELSE 'expired'
  END AS effective_status,
  CASE
    WHEN u.subscription_plan IS NOT NULL AND u.subscription_expires_at > now() THEN 
      COALESCE((SELECT sp.max_stadiums FROM public.subscription_plans sp WHERE sp.code = u.subscription_plan AND sp.is_active = true), 0)
    WHEN COALESCE(u.subscription_plan, 'free_trial') = 'free_trial' AND 
         COALESCE(u.trial_ends_at, u.created_at + ((SELECT COALESCE(MAX(trial_days), 365) FROM public.subscription_plans WHERE is_active = true) || ' days')::interval) > now() THEN 
      COALESCE((SELECT sp.max_stadiums FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true), 1)
    ELSE 0
  END AS max_stadiums_allowed
FROM public.users u
WHERE u.role = 'owner';

GRANT SELECT ON public.owner_subscription_status TO authenticated, service_role;
REVOKE SELECT ON public.owner_subscription_status FROM anon;

-- -----------------------------------------------------------------------------
-- 5. SECURE get_owner_dashboard_analytics RPC (AUTHORIZATION & REVOKE ANON)
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

  -- حساب الحجوزات والإيرادات
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

  -- ضمان التماسك الرياضي التام (total == cash + online دايماً)
  IF (v_total_revenue - (v_cash_revenue + v_online_revenue)) <> 0 THEN
    v_cash_revenue := v_total_revenue - v_online_revenue;
  END IF;

  -- بناء النتيجة JSON
  SELECT json_build_object(
    'meta', json_build_object(
      'start_date',   p_start_date,
      'end_date',     p_end_date,
      'period_days',  v_period_days
    ),
    'revenue', json_build_object(
      'total',            ROUND(v_total_revenue, 2),
      'cash',             ROUND(v_cash_revenue, 2),
      'online',           ROUND(v_online_revenue, 2),
      'cash_percentage',  CASE WHEN v_total_revenue > 0
                            THEN ROUND((v_cash_revenue / v_total_revenue) * 100, 1)
                            ELSE 0 END,
      'online_percentage',CASE WHEN v_total_revenue > 0
                            THEN ROUND((v_online_revenue / v_total_revenue) * 100, 1)
                            ELSE 0 END,
      'unrealized',       ROUND(
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

REVOKE EXECUTE ON FUNCTION public.get_owner_dashboard_analytics(uuid, timestamptz, timestamptz, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_owner_dashboard_analytics(uuid, timestamptz, timestamptz, uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. VERIFICATION FUNCTION SECURITY CLEANUP (submit_owner_verification)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.submit_owner_verification(
  p_owner_id uuid DEFAULT NULL,
  p_additional_data jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid         uuid := COALESCE(p_owner_id, auth.uid());
  v_has_stadium boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
  END IF;

  -- Modern secure server-side authorization check (no deprecated auth.role())
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    IF v_uid IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  -- Check authoritative existence of active stadium
  SELECT EXISTS (
    SELECT 1 FROM public.stadiums 
    WHERE owner_id = v_uid AND COALESCE(is_deleted_by_owner, false) = false
  ) INTO v_has_stadium;

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET verification_status = 'pending',
      is_registration_complete = true,
      has_stadium = v_has_stadium,
      additional_data = COALESCE(additional_data, '{}'::jsonb) || COALESCE(p_additional_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'has_stadium', v_has_stadium,
    'message', 'Owner verification submitted successfully'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_owner_verification(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_owner_verification(uuid, jsonb) TO authenticated, service_role;
