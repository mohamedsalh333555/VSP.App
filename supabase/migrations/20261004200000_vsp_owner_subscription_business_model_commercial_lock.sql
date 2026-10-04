-- VSP Owner Subscription Business Model — Final Commercial Lock
-- Applied to live Supabase DB on 2026-10-04
-- Invariants:
--   Basic: 0 EGP, perpetual free, max 1 stadium, core management.
--   Pro: 1000 EGP / mo, max 3 stadiums, VSP Copilot, priority search.
--   Pro Trial: 7 days, 0 EGP, 3 stadiums + Copilot, no 365-day fallback, duplicate trial prevented.

-- 1. Subscription plans catalog
INSERT INTO public.subscription_plans (
  code, name_ar, name_en, monthly_price, yearly_price, max_stadiums, trial_days, is_active, features, updated_at
)
VALUES
(
  'basic',
  'الباقة الأساسية',
  'Basic Plan',
  0.00,
  0.00,
  1,
  0,
  true,
  '["إدارة ملعب واحد بالكامل","جدول الحجوزات ولوحة التحكم اليومية","إدارة الدفع النقدي وحجوزات الملعب","تسجيل المعاملات المالية الأساسية"]'::jsonb,
  now()
)
ON CONFLICT (code) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  monthly_price = 0.00,
  yearly_price = 0.00,
  max_stadiums = 1,
  trial_days = 0,
  is_active = true,
  features = EXCLUDED.features,
  updated_at = now();

INSERT INTO public.subscription_plans (
  code, name_ar, name_en, monthly_price, yearly_price, max_stadiums, trial_days, is_active, features, updated_at
)
VALUES
(
  'pro',
  'باقة الاحتراف',
  'Pro Plan',
  1000.00,
  10000.00,
  3,
  7,
  true,
  '["إدارة حتى 3 ملاعب تحت حساب واحد","المساعد الذكي VSP Copilot لكتابة المنشورات والرسائل","لوحة تحليلات متقدمة وتوقعات الإشغال","تصدير تقارير الأرباح والحجوزات Excel","أولوية الظهور في نتائج بحث اللاعبين"]'::jsonb,
  now()
)
ON CONFLICT (code) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  monthly_price = 1000.00,
  yearly_price = 10000.00,
  max_stadiums = 3,
  trial_days = 7,
  is_active = true,
  features = EXCLUDED.features,
  updated_at = now();

-- 2. SSOT View: owner_subscription_status
CREATE OR REPLACE VIEW public.owner_subscription_status AS
WITH base AS (
  SELECT
    u.id AS owner_id,
    u.name,
    u.email,
    u.phone,
    u.role,
    u.subscription_plan,
    u.trial_ends_at,
    u.subscription_expires_at,
    now() AS server_now,
    COALESCE((
      SELECT count(*)::integer
      FROM public.stadiums s
      WHERE s.owner_id = u.id
        AND s.is_deleted_by_owner = false
    ), 0) AS active_stadiums_count
  FROM public.users u
  WHERE u.role = 'owner'
)
SELECT
  b.owner_id,
  b.name,
  b.email,
  b.phone,
  b.role,
  b.subscription_plan,
  b.trial_ends_at,
  b.subscription_expires_at,
  b.active_stadiums_count,
  CASE
    WHEN b.subscription_plan = 'pro'
         AND b.subscription_expires_at IS NOT NULL
         AND b.subscription_expires_at > b.server_now THEN 'active_paid'
    WHEN b.trial_ends_at IS NOT NULL
         AND b.trial_ends_at > b.server_now THEN 'active_trial'
    ELSE 'active_free'
  END AS effective_status,
  CASE
    WHEN b.subscription_plan = 'pro'
         AND b.subscription_expires_at IS NOT NULL
         AND b.subscription_expires_at > b.server_now THEN 'pro'
    WHEN b.trial_ends_at IS NOT NULL
         AND b.trial_ends_at > b.server_now THEN 'pro'
    ELSE 'basic'
  END AS effective_plan,
  CASE
    WHEN (b.subscription_plan = 'pro' AND b.subscription_expires_at > b.server_now)
         OR (b.trial_ends_at IS NOT NULL AND b.trial_ends_at > b.server_now) THEN 3
    ELSE 1
  END AS max_stadiums_allowed,
  CASE
    WHEN b.subscription_plan = 'pro'
         AND b.subscription_expires_at IS NOT NULL
         AND b.subscription_expires_at > b.server_now THEN true
    WHEN b.trial_ends_at IS NOT NULL
         AND b.trial_ends_at > b.server_now THEN true
    ELSE false
  END AS has_pro_features,
  b.active_stadiums_count < CASE
    WHEN (b.subscription_plan = 'pro' AND b.subscription_expires_at > b.server_now)
         OR (b.trial_ends_at IS NOT NULL AND b.trial_ends_at > b.server_now) THEN 3
    ELSE 1
  END AS can_add_stadium
FROM base b;

-- 3. evaluate_owner_stadium_capacity RPC
CREATE OR REPLACE FUNCTION public.evaluate_owner_stadium_capacity(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_rec record;
BEGIN
  IF p_owner_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'MISSING_OWNER_ID');
  END IF;

  SELECT * INTO v_rec
  FROM public.owner_subscription_status
  WHERE owner_id = p_owner_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'OWNER_NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'allowed', v_rec.can_add_stadium,
    'current_count', v_rec.active_stadiums_count,
    'max_allowed', v_rec.max_stadiums_allowed,
    'effective_plan', v_rec.effective_plan,
    'effective_status', v_rec.effective_status,
    'has_pro_features', v_rec.has_pro_features
  );
END;
$function$;

-- 4. create_owner_subscription_order RPC
CREATE OR REPLACE FUNCTION public.create_owner_subscription_order(
  p_plan_code text,
  p_billing_period text DEFAULT 'monthly'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_plan record;
  v_amount numeric;
  v_days integer;
  v_order_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
  END IF;

  IF p_plan_code = 'basic' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'BASIC_IS_FREE',
      'message', 'الباقة الأساسية مجانية بالكامل ولا تتطلب دفع إلكتروني'
    );
  END IF;

  SELECT * INTO v_plan
  FROM public.subscription_plans
  WHERE code = p_plan_code AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAN_NOT_FOUND');
  END IF;

  IF p_billing_period = 'yearly' THEN
    v_amount := v_plan.yearly_price;
    v_days := 365;
  ELSE
    v_amount := v_plan.monthly_price;
    v_days := 30;
  END IF;

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PAID_AMOUNT');
  END IF;

  INSERT INTO public.owner_subscription_orders (
    owner_id,
    plan_code,
    billing_period,
    amount,
    duration_days,
    status
  )
  VALUES (
    v_uid,
    p_plan_code,
    p_billing_period,
    v_amount,
    v_days,
    'pending_payment'
  )
  RETURNING id INTO v_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'amount', v_amount,
    'plan_code', p_plan_code,
    'billing_period', p_billing_period,
    'duration_days', v_days
  );
END;
$function$;

-- 5. start_owner_trial RPC
CREATE OR REPLACE FUNCTION public.start_owner_trial()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner public.users%ROWTYPE;
  v_existing public.owner_trial_ledger%ROWTYPE;
  v_now timestamptz := now();
  v_ends timestamptz;
  v_trial_days integer := 7;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_owner FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND OR v_owner.role <> 'owner' THEN
    RAISE EXCEPTION 'OWNER_ONLY' USING ERRCODE='42501';
  END IF;

  IF v_owner.subscription_plan = 'pro'
     AND v_owner.subscription_expires_at IS NOT NULL
     AND v_owner.subscription_expires_at > v_now THEN
    RETURN jsonb_build_object('success', false, 'error', 'PRO_SUBSCRIPTION_ALREADY_ACTIVE');
  END IF;

  IF v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > v_now THEN
    RETURN jsonb_build_object('success', true, 'already_active', true, 'trial_ends_at', v_owner.trial_ends_at);
  END IF;

  SELECT * INTO v_existing FROM public.owner_trial_ledger
  WHERE lower(trim(email)) = lower(trim(v_owner.email))
     OR (phone IS NOT NULL AND v_owner.phone IS NOT NULL AND phone = v_owner.phone)
     OR user_id = v_uid
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TRIAL_ALREADY_USED', 'trial_ends_at', v_existing.original_trial_ends_at);
  END IF;

  v_ends := v_now + make_interval(days => v_trial_days);

  INSERT INTO public.owner_trial_ledger (
    email, phone, user_id, first_trial_started_at, original_trial_ends_at
  )
  VALUES (
    lower(trim(v_owner.email)),
    nullif(trim(v_owner.phone), ''),
    v_uid,
    v_now,
    v_ends
  );

  UPDATE public.users
  SET trial_ends_at = v_ends,
      updated_at = v_now
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'already_active', false,
    'trial_started_at', v_now,
    'trial_ends_at', v_ends,
    'trial_days', v_trial_days
  );
END;
$function$;

-- 6. auto_downgrade_expired_subscriptions
CREATE OR REPLACE FUNCTION public.auto_downgrade_expired_subscriptions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_count integer := 0;
  v_rec record;
BEGIN
  FOR v_rec IN
    SELECT id, email
    FROM public.users
    WHERE role = 'owner'
      AND subscription_plan = 'pro'
      AND subscription_expires_at IS NOT NULL
      AND subscription_expires_at <= now()
  LOOP
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        updated_at = now()
    WHERE id = v_rec.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$function$;

-- 7. admin_set_owner_subscription_atomic
CREATE OR REPLACE FUNCTION public.admin_set_owner_subscription_atomic(
  p_owner_id uuid,
  p_plan text,
  p_days integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_caller_role text;
  v_current_plan text;
  v_current_expires_at timestamptz;
  v_now timestamptz := timezone('utc', now());
  v_base_time timestamptz;
  v_new_expires_at timestamptz;
  v_normalized_plan text := lower(trim(coalesce(p_plan, '')));
  v_days integer;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.users
  WHERE id = auth.uid();

  IF current_user NOT IN ('postgres','service_role')
     AND coalesce(auth.role(),'') <> 'service_role'
     AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can alter owner subscriptions';
  END IF;

  IF v_normalized_plan NOT IN ('free_trial','basic','pro') THEN
    RAISE EXCEPTION 'Invalid subscription plan';
  END IF;

  IF v_normalized_plan = 'basic' THEN
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'basic',
      'subscription_expires_at', null,
      'trial_ends_at', null,
      'server_time', v_now
    );
  ELSIF v_normalized_plan = 'free_trial' THEN
    v_days := 7;
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        trial_ends_at = v_now + make_interval(days => v_days),
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'basic',
      'subscription_expires_at', null,
      'trial_ends_at', v_now + make_interval(days => v_days),
      'server_time', v_now,
      'catalog_trial_days', v_days
    );
  ELSE
    v_days := coalesce(p_days, 30);
    IF v_days < 1 OR v_days > 3650 THEN
      RAISE EXCEPTION 'A valid subscription duration is required for paid plans';
    END IF;

    SELECT subscription_plan, subscription_expires_at
    INTO v_current_plan, v_current_expires_at
    FROM public.users
    WHERE id = p_owner_id
    FOR UPDATE;

    v_base_time := v_now;
    IF v_current_plan = 'pro'
       AND v_current_expires_at IS NOT NULL
       AND v_current_expires_at > v_now THEN
      v_base_time := v_current_expires_at;
    END IF;

    v_new_expires_at := v_base_time + make_interval(days => v_days);

    UPDATE public.users
    SET subscription_plan = 'pro',
        subscription_expires_at = v_new_expires_at,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'pro',
      'subscription_expires_at', v_new_expires_at,
      'trial_ends_at', null,
      'server_time', v_now
    );
  END IF;
END;
$function$;
