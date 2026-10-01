-- ============================================================================
-- Migration: 20261001240000_owner_journey_definitive_ssot.sql
-- Description: Owner Journey SSOT Definitive Closure:
--   1. Trial SSOT: Read trial duration strictly from subscription_plans ('basic')
--      in set_user_role_on_signup; fail closed if missing; eliminate hardcoded 60 days.
--   2. Subscription Expiration SSOT: auto_downgrade_expired_subscriptions sets 'expired'
--      and never reverts to fake 'free_trial' unless a valid original trial is still active.
--   3. Onboarding SSOT: update_owner_onboarding_atomic derives has_stadium authoritatively
--      from public.stadiums instead of blindly forcing true.
--   4. Stadium Capacity Limit SSOT: check_owner_stadium_limit delegates directly to
--      evaluate_owner_stadium_capacity, removing divergent legacy limits.
--   5. Operating Hours SSOT: get_owner_dashboard_analytics computes operating hours
--      directly from public.stadiums (shift + split break) without 10-hour fallback.
-- ============================================================================

-- 1. set_user_role_on_signup: Strict Catalog-driven Trial (No hardcoded 60 or 365 days)
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(p_role text, p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid               uuid := coalesce(p_user_id, auth.uid());
  v_user              record;
  v_trial             timestamptz;
  v_ledger            record;
  v_days              integer;
  v_plan_trial_days   integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_USER_ID');
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    IF v_uid IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  SELECT id, email, phone, role, is_registration_complete
  INTO v_user FROM public.users WHERE id = v_uid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF coalesce(v_user.is_registration_complete, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_ALREADY_COMPLETE');
  END IF;

  IF p_role NOT IN ('player', 'owner') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  IF p_role = 'owner' THEN
    -- Canonical trial duration from active basic plan in subscription_plans (Fail closed if missing)
    SELECT trial_days INTO v_plan_trial_days
    FROM public.subscription_plans
    WHERE code = 'basic' AND is_active = true;

    IF v_plan_trial_days IS NULL OR v_plan_trial_days <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'TRIAL_CONFIGURATION_MISSING');
    END IF;

    -- Check if owner identity already has a ledger entry
    SELECT * INTO v_ledger FROM public.owner_trial_ledger
    WHERE lower(trim(email)) = lower(trim(v_user.email))
       OR (phone IS NOT NULL AND v_user.phone IS NOT NULL AND phone = v_user.phone)
    LIMIT 1;

    IF FOUND THEN
      -- Existing trial: calculate remaining days from original trial, do NOT grant fresh trial
      v_days := greatest(0, extract(day from (v_ledger.original_trial_ends_at - now()))::integer);
      v_trial := CASE WHEN v_days > 0 THEN now() + (v_days || ' days')::interval ELSE now() END;
    ELSE
      -- New owner: trial duration strictly derived from subscription_plans catalog
      v_trial := now() + (v_plan_trial_days || ' days')::interval;
      INSERT INTO public.owner_trial_ledger(email, phone, user_id, original_trial_ends_at)
      VALUES(lower(trim(v_user.email)), v_user.phone, v_uid, v_trial)
      ON CONFLICT DO NOTHING;
    END IF;

    UPDATE public.users
    SET role = 'owner', subscription_plan = 'free_trial', trial_ends_at = v_trial
    WHERE id = v_uid AND coalesce(is_registration_complete, false) = false;
  ELSE
    UPDATE public.users SET role = 'player'
    WHERE id = v_uid AND coalesce(is_registration_complete, false) = false;
  END IF;

  RETURN jsonb_build_object('success', true, 'role', p_role, 'trial_ends_at', v_trial);
END;
$function$;

-- 2. auto_downgrade_expired_subscriptions: Accurate Downgrade (No fake free_trial)
CREATE OR REPLACE FUNCTION public.auto_downgrade_expired_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Unfeature stadiums for owners whose subscription or trial has expired
  UPDATE public.stadiums s
  SET is_featured = FALSE,
      updated_at = NOW()
  FROM public.users u
  WHERE s.owner_id = u.id
    AND s.is_featured = TRUE
    AND (
      (u.subscription_plan IN ('pro', 'basic') AND u.subscription_expires_at IS NOT NULL AND u.subscription_expires_at <= NOW())
      OR (u.subscription_plan = 'free_trial' AND u.trial_ends_at IS NOT NULL AND u.trial_ends_at <= NOW())
    );

  -- Downgrade expired paid subscriptions (pro/basic)
  -- If owner has a still-valid original trial (e.g. purchased paid plan during trial), revert to free_trial.
  -- Otherwise, mark as 'expired' to eliminate misleading fake trial states.
  UPDATE public.users
  SET subscription_plan = CASE
        WHEN trial_ends_at IS NOT NULL AND trial_ends_at > NOW() THEN 'free_trial'
        ELSE 'expired'
      END,
      updated_at = NOW()
  WHERE subscription_plan IN ('pro', 'basic')
    AND subscription_expires_at IS NOT NULL
    AND subscription_expires_at <= NOW();

  -- Mark expired free_trial accounts as 'expired'
  UPDATE public.users
  SET subscription_plan = 'expired',
      updated_at = NOW()
  WHERE subscription_plan = 'free_trial'
    AND trial_ends_at IS NOT NULL
    AND trial_ends_at <= NOW();
END;
$function$;

-- 3. update_owner_onboarding_atomic: Authoritative has_stadium derivation
CREATE OR REPLACE FUNCTION public.update_owner_onboarding_atomic(p_user_id uuid, p_additional_data jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_has_active_stadium boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
  END IF;

  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- Authoritatively derive whether owner has an active (non-soft-deleted) stadium
  SELECT EXISTS (
    SELECT 1 FROM public.stadiums
    WHERE owner_id = p_user_id AND coalesce(is_deleted_by_owner, false) = false
  ) INTO v_has_active_stadium;

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET has_stadium = v_has_active_stadium,
      is_onboarding_confirmed = true,
      additional_data = coalesce(additional_data, '{}'::jsonb) || coalesce(p_additional_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'has_stadium', v_has_active_stadium,
    'is_onboarding_confirmed', true
  );
END;
$function$;

-- 4. check_owner_stadium_limit: Delegate directly to canonical evaluate_owner_stadium_capacity
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval record;
BEGIN
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
$function$;

-- 5. get_owner_dashboard_analytics: Direct Stadium Schedule SSOT (No empty table, no 10h fallback)
CREATE OR REPLACE FUNCTION public.get_owner_dashboard_analytics(
  p_owner_id uuid,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone,
  p_court_id uuid DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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

  -- حساب ساعات التشغيل الفعلية من ملاعب المالك في جدول stadiums مباشرة (Single Source of Truth)
  SELECT COALESCE(SUM(
    CASE
      -- Calculate raw daily shift hours
      WHEN s.closing_time IS NOT NULL AND s.opening_time IS NOT NULL THEN
        (CASE
          WHEN s.closing_time > s.opening_time THEN
            EXTRACT(EPOCH FROM (s.closing_time - s.opening_time)) / 3600.0
          ELSE
            -- Overnight shift (e.g. 15:00 to 02:00)
            EXTRACT(EPOCH FROM ('24:00:00'::TIME - s.opening_time + s.closing_time)) / 3600.0
        END)
        -- Subtract split shift break if active
        - (CASE
            WHEN s.is_split_shift IS TRUE AND s.break_start_time IS NOT NULL AND s.break_end_time IS NOT NULL THEN
              (CASE
                WHEN s.break_end_time > s.break_start_time THEN
                  EXTRACT(EPOCH FROM (s.break_end_time - s.break_start_time)) / 3600.0
                ELSE
                  EXTRACT(EPOCH FROM ('24:00:00'::TIME - s.break_start_time + s.break_end_time)) / 3600.0
              END)
            ELSE 0.0
          END)
      ELSE 0.0
    END
  ) * v_period_days, 0)
  INTO v_total_op_hours
  FROM public.stadiums s
  WHERE s.owner_id = p_owner_id
    AND (p_court_id IS NULL OR s.id = p_court_id)
    AND COALESCE(s.is_deleted_by_owner, false) = false;

  -- 1. حساب الحجوزات والإيرادات التشغيلية الكلية للفترة (Operational Booking Metrics)
  SELECT
    COUNT(b.id),
    COUNT(b.id) FILTER (WHERE b.payment_source = 'cash' OR b.payment_method = 'cash'),
    COUNT(b.id) FILTER (WHERE b.payment_source <> 'cash' AND b.payment_method <> 'cash'),
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source <> 'cash' AND b.payment_method <> 'cash')
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
    COALESCE(SUM(CASE WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source <> 'cash' AND b.payment_method <> 'cash')
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
    COALESCE(SUM(CASE WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source <> 'cash' AND b.payment_method <> 'cash')
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
$function$;

-- Record migration in schema_migrations
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261001240000', 'owner_journey_definitive_ssot')
ON CONFLICT (version) DO NOTHING;
