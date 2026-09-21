-- ==============================================================================
-- Migration: 20260918000005_stage1_critical_privilege_and_grant_lockdown.sql
-- Stage: 1 (Critical - Privilege Escalation & Grant Lockdown)
-- Description:
--   1. Harden users_update_policy with column restriction on role (RLS Layer).
--   2. Rebuild trg_fn_protect_user_sensitive_fields with Fail-Closed / Allow-list model.
--      Sovereign fields (role, subscription, blocked, etc.) are strictly immune to system_override.
--   3. Synchronize is_admin_or_cofounder() to include super_admin (aligning DB & Flutter user_model).
--   4. Revoke open table-level GRANTs (TRUNCATE, DELETE, INSERT) on financial & audit tables.
-- ==============================================================================

BEGIN;

-- 1️⃣ تحصين دالة فحص الأدمن لتشمل الرتب الإدارية الرسمية وتتوافق 100% مع كود التطبيق
CREATE OR REPLACE FUNCTION public.is_admin_or_cofounder(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND role IN ('admin', 'co_founder', 'super_admin')
  );
$$;

-- 2️⃣ تحصين سياسة التحديث على جدول users لمنع أي مستخدم عادي من تغيير role عبر RLS
DROP POLICY IF EXISTS "users_update_policy" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

CREATE POLICY "users_update_policy" ON public.users
FOR UPDATE TO authenticated
USING ((select auth.uid()) = id)
WITH CHECK (
  (select auth.uid()) = id 
  AND role = (SELECT u.role FROM public.users u WHERE u.id = (select auth.uid()))
);

-- 3️⃣ إعادة كتابة تريجر حماية الحقول الحساسة بنمط Fail-Closed / Allow-list
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

  -- 3. قراءة متغير التجاوز النظامي إن وُجد (ملاحظة أمنية: لا يتم اعتباره تصريحاً مطلقاً)
  v_has_override := (current_setting('vsp.system_override', true) = 'true');

  -- 4. الحظر السيادي المطلق (Tier A): غير قابل للتجاوز إطلاقاً حتى مع system_override
  IF (OLD.role IS DISTINCT FROM NEW.role) OR
     (OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan) OR
     (OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at) OR
     (OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at) OR
     (OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified) OR
     (OLD.verification_status IS DISTINCT FROM NEW.verification_status) OR
     (OLD.is_blocked IS DISTINCT FROM NEW.is_blocked) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Modifying sovereign security fields (role/subscription/verification/blocked) is strictly restricted to platform administrators.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SOVEREIGN_FIELD_UPDATE';
  END IF;

  -- 5. الحقول التشغيلية (Tier B Allow-list):
  -- مسموح بتعديلها حصراً عند وجود system_override من الدوال الذرية (ديون، حظر كاش، غياب، رسوم، نقاط)
  -- وممنوع تعديلها كلياً من المستخدم العادي
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

-- ربط التريجر بجدول users
DROP TRIGGER IF EXISTS trg_protect_users_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_users_sensitive_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_protect_user_sensitive_fields();

-- 4️⃣ سحب امتيازات GRANT المفتوحة على الجداول المالية والتدقيق
-- A. webhook_logs
REVOKE ALL ON TABLE public.webhook_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.webhook_logs TO authenticated;
GRANT ALL ON TABLE public.webhook_logs TO service_role, postgres;

-- B. financial_audit_logs (صلاحية القراءة محفوظة للأدمن والمالك وصاحب العملية عبر RLS)
REVOKE ALL ON TABLE public.financial_audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.financial_audit_logs TO authenticated;
GRANT ALL ON TABLE public.financial_audit_logs TO service_role, postgres;

-- C. transactions (منع التعديل والإدخال المباشر وحصره بالدوال الذرية)
REVOKE ALL ON TABLE public.transactions FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE public.transactions FROM authenticated;
GRANT SELECT ON TABLE public.transactions TO authenticated;
GRANT ALL ON TABLE public.transactions TO service_role, postgres;

-- D. bookings
REVOKE ALL ON TABLE public.bookings FROM PUBLIC, anon;
REVOKE TRUNCATE, DELETE ON TABLE public.bookings FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.bookings TO authenticated;
GRANT ALL ON TABLE public.bookings TO service_role, postgres;

-- E. users
REVOKE ALL ON TABLE public.users FROM PUBLIC, anon;
REVOKE TRUNCATE, DELETE ON TABLE public.users FROM authenticated;
GRANT SELECT, UPDATE ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role, postgres;

COMMIT;
