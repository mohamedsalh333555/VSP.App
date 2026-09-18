-- ==============================================================================
-- 🛡️ VSP MIGRATION: 20260918000012_allow_signup_role_selection_and_trial_ledger.sql
-- 1. Create permanent public.owner_trial_ledger to track consumed trial periods (by email & phone)
-- 2. Update trg_fn_protect_user_sensitive_fields to allow initial role assignment during registration
-- 3. Harden set_user_role_on_signup to check trial ledger and assign proper trial or expired status
-- ==============================================================================

BEGIN;

-- 1️⃣ دفتر تسجيل الفترات التجريبية للملاك لمنع استهلاك 60 يوم متكررة عند إعادة التسجيل
CREATE TABLE IF NOT EXISTS public.owner_trial_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    phone TEXT,
    first_trial_started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    original_trial_ends_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_owner_trial_ledger_email 
  ON public.owner_trial_ledger (lower(trim(email)));

CREATE UNIQUE INDEX IF NOT EXISTS idx_owner_trial_ledger_phone 
  ON public.owner_trial_ledger (phone) 
  WHERE phone IS NOT NULL AND phone != '';

-- تفعيل RLS على دفتر التجارب (مقتصر على الأدمن و service_role فقط)
ALTER TABLE public.owner_trial_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner_trial_ledger_admin_all" ON public.owner_trial_ledger;
CREATE POLICY "owner_trial_ledger_admin_all" ON public.owner_trial_ledger
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 2️⃣ تحديث تريجر الحماية السيادي: السماح باختيار الرتبة الابتدائية من player إلى owner فقط أثناء التسجيل
CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_admin boolean := false;
  v_has_override boolean := false;
BEGIN
  -- 1. السماح المباشر لجلسات النظام الداخلية الخالصة (Postgres / Service Role)
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    RETURN NEW;
  END IF;

  -- 2. التحقق من صلاحية الأدمن المعتمد
  IF auth.uid() IS NOT NULL THEN
    v_is_admin := public.is_admin_or_cofounder(auth.uid());
  END IF;

  IF COALESCE(v_is_admin, false) THEN
    RETURN NEW;
  END IF;

  -- 3. قراءة متغير التجاوز النظامي إن وُجد
  v_has_override := (current_setting('vsp.system_override', true) = 'true');

  -- 4. الحظر السيادي (Tier A) مع استثناء صريح وآمن لمرحلة التسجيل الأولية:
  -- أ) تغيير الرتبة: مسموح فقط وفقط من player إلى owner، وأثناء عدم اكتمال التسجيل، ولصاحب الحساب نفسه
  IF (OLD.role IS DISTINCT FROM NEW.role) THEN
    IF NOT (
      COALESCE(OLD.is_registration_complete, false) = false
      AND OLD.role = 'player'
      AND NEW.role = 'owner'
      AND auth.uid() = OLD.id
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Modifying sovereign security fields (role) is strictly restricted to platform administrators.'
        USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SOVEREIGN_FIELD_UPDATE';
    END IF;
  END IF;

  -- ب) حقول الباقة والتجربة: مسموح بتعيينها تلقائياً فقط إذا كان الحساب قيد التسجيل الأولي
  IF (OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan) OR
     (OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at) OR
     (OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at) THEN
    IF NOT (
      COALESCE(OLD.is_registration_complete, false) = false
      AND auth.uid() = OLD.id
      AND NEW.subscription_plan IN ('free', 'free_trial', 'expired')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Modifying sovereign security fields (subscription/trial) is strictly restricted to platform administrators.'
        USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SOVEREIGN_FIELD_UPDATE';
    END IF;
  END IF;

  -- ج) حقول التحقق والحظر: محظورة كلياً على المستخدم العادي
  IF (OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified) OR
     (OLD.verification_status IS DISTINCT FROM NEW.verification_status) OR
     (OLD.is_blocked IS DISTINCT FROM NEW.is_blocked) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Modifying sovereign security fields (verification/blocked) is strictly restricted to platform administrators.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SOVEREIGN_FIELD_UPDATE';
  END IF;

  -- 5. الحقول التشغيلية (Tier B): ديون، حظر كاش، غياب، رسوم، نقاط
  IF (OLD.accumulated_cash_debt IS DISTINCT FROM NEW.accumulated_cash_debt) OR
     (OLD.debt_limit IS DISTINCT FROM NEW.debt_limit) OR
     (OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked) OR
     (OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned) OR
     (OLD.no_show_count IS DISTINCT FROM NEW.no_show_count) OR
     (OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees) OR
     (OLD.points IS DISTINCT FROM NEW.points) THEN
    IF NOT v_has_override THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Direct modification of operational financial/penalty fields is restricted to atomic system procedures.'
        USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_OPERATIONAL_FIELD_UPDATE';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;


-- 3️⃣ تحصين دالة set_user_role_on_signup مع تتبع التجربة المجانية عبر دفتر owner_trial_ledger
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(
  p_role text, 
  p_user_id uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_current_role text;
  v_is_complete boolean;
  v_caller_role text;
  v_email text;
  v_phone text;
  v_existing_ledger RECORD;
  v_plan text := 'free';
  v_trial_ends_at timestamptz := NULL;
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 🔒 قصر الرتب المتاحة على player أو owner فقط
  IF p_role NOT IN ('player', 'owner') THEN
    RAISE EXCEPTION 'Invalid role assignment attempt (%s). Only player or owner allowed.', p_role;
  END IF;

  -- 🔒 منع الـ IDOR: المستخدم يمكنه تغيير رتبة حسابه فقط
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF (v_uid IS DISTINCT FROM auth.uid()) THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
        RAISE EXCEPTION 'Unauthorized: You can only set your own role.';
      END IF;
    END IF;
  END IF;

  SELECT role, is_registration_complete, email, phone 
  INTO v_current_role, v_is_complete, v_email, v_phone
  FROM public.users WHERE id = v_uid;

  -- حماية الرتب الإدارية
  IF v_current_role IN ('admin', 'co_founder', 'super_admin') THEN
    RETURN true;
  END IF;

  -- إذا كان التسجيل مكتملاً بالفعل للمستخدم العادي، يُمنع التغيير إلا بواسطة الأدمن
  IF COALESCE(v_is_complete, false) = true AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') AND COALESCE(auth.role(), '') != 'service_role' THEN
    RAISE EXCEPTION 'Registration already complete. Role change prohibited.';
  END IF;

  -- معالجة الفترة التجريبية للمالك عبر دفتر التجارب
  IF p_role = 'owner' THEN
    -- فحص الدفتر بالإيميل أو رقم الهاتف
    SELECT * INTO v_existing_ledger
    FROM public.owner_trial_ledger
    WHERE (lower(trim(email)) = lower(trim(COALESCE(v_email, ''))))
       OR (phone IS NOT NULL AND v_phone IS NOT NULL AND phone = v_phone)
    LIMIT 1;

    IF FOUND THEN
      -- سبق له التسجيل: احتساب ما تبقى من فترته الأصلية فقط
      IF v_existing_ledger.original_trial_ends_at > v_now THEN
        v_plan := 'free_trial';
        v_trial_ends_at := v_existing_ledger.original_trial_ends_at;
      ELSE
        v_plan := 'expired';
        v_trial_ends_at := v_existing_ledger.original_trial_ends_at;
      END IF;
    ELSE
      -- أول مرة يسجل كمالك: منحه 60 يوماً وتثبيتها في الدفتر
      v_trial_ends_at := v_now + interval '60 days';
      v_plan := 'free_trial';

      IF v_email IS NOT NULL AND trim(v_email) != '' THEN
        INSERT INTO public.owner_trial_ledger (
          email,
          phone,
          first_trial_started_at,
          original_trial_ends_at
        ) VALUES (
          lower(trim(v_email)),
          v_phone,
          v_now,
          v_trial_ends_at
        )
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;
  ELSE
    v_plan := 'free';
    v_trial_ends_at := NULL;
  END IF;

  -- تحديث بيانات المستخدم
  UPDATE public.users
  SET role = p_role,
      subscription_plan = v_plan,
      trial_ends_at = v_trial_ends_at,
      updated_at = v_now
  WHERE id = v_uid;

  RETURN true;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_user_role_on_signup(TEXT, UUID) TO authenticated, service_role;

COMMIT;
