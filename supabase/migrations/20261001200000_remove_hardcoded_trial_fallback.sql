-- Migration: 20261001200000_remove_hardcoded_trial_fallback.sql
-- Description:
--   1. Completely remove hardcoded 365 and 1 fallbacks from evaluate_owner_stadium_capacity.
--      - Trial duration is read strictly from public.subscription_plans WHERE code = 'basic' AND is_active = true.
--      - If no active configuration exists, fails closed (no trial duration is invented).
--   2. Completely remove hardcoded 365 and 1 fallbacks from owner_subscription_status VIEW.
--      - If no active basic configuration exists, trial status is expired and max_stadiums is 0 (fails closed).
--   3. Keep existing production behavior: basic.trial_days is 365, so trial remains 365 days.

-- -----------------------------------------------------------------------------
-- 1. evaluate_owner_stadium_capacity WITHOUT HARDCODED TRIAL FALLBACK
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
  v_trial_days         integer;
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
  -- Strict SSOT: No hardcoded fallback. If missing or inactive, trial fails closed.
  SELECT sp.trial_days INTO v_trial_days
  FROM public.subscription_plans sp
  WHERE sp.code = 'basic' AND sp.is_active = true;

  -- 4. Check active trial status (fails closed if v_trial_days IS NULL)
  IF v_trial_days IS NOT NULL AND v_trial_days > 0 THEN
    v_is_active_trial := (
      COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
      (
        (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
        (v_owner.trial_ends_at IS NULL AND v_owner.created_at + (v_trial_days || ' days')::interval > NOW())
      )
    );
  ELSE
    -- Missing or inactive configuration: fail closed (no invented business rule)
    v_is_active_trial := (
      COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
      v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()
    );
  END IF;

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
    -- Trial capacity matches the base active plan in subscription_plans (fails closed to 0 if missing)
    SELECT COALESCE(sp.max_stadiums, 0) INTO v_allowed_count
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

REVOKE ALL ON FUNCTION public.evaluate_owner_stadium_capacity(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.evaluate_owner_stadium_capacity(uuid, uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. owner_subscription_status VIEW WITHOUT HARDCODED TRIAL FALLBACK
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
         (
           (u.trial_ends_at IS NOT NULL AND u.trial_ends_at > now()) OR
           (
             u.trial_ends_at IS NULL AND
             (SELECT sp.trial_days FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true) IS NOT NULL AND
             u.created_at + ((SELECT sp.trial_days FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true) || ' days')::interval > now()
           )
         ) THEN 'active_trial'
    ELSE 'expired'
  END AS effective_status,
  CASE
    WHEN u.subscription_plan IS NOT NULL AND u.subscription_expires_at > now() THEN 
      COALESCE((SELECT sp.max_stadiums FROM public.subscription_plans sp WHERE sp.code = u.subscription_plan AND sp.is_active = true), 0)
    WHEN COALESCE(u.subscription_plan, 'free_trial') = 'free_trial' AND 
         (
           (u.trial_ends_at IS NOT NULL AND u.trial_ends_at > now()) OR
           (
             u.trial_ends_at IS NULL AND
             (SELECT sp.trial_days FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true) IS NOT NULL AND
             u.created_at + ((SELECT sp.trial_days FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true) || ' days')::interval > now()
           )
         ) THEN 
      COALESCE((SELECT sp.max_stadiums FROM public.subscription_plans sp WHERE sp.code = 'basic' AND sp.is_active = true), 0)
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
