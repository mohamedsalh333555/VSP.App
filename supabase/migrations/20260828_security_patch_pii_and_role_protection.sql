-- ==============================================================================
-- Migration: 20260828_security_patch_pii_and_role_protection.sql
-- Description: Hardening public.users RLS against Anon PII Phone Scraping and direct Role Mutation
-- ==============================================================================

-- 1. Hardened Trigger: protect_user_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
  v_caller_uid uuid := auth.uid();
BEGIN
  -- If called in background trigger or service_role without user context
  IF v_caller_uid IS NULL AND current_user = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Check if caller is explicit admin/co_founder
  IF v_caller_uid IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_uid;
    IF v_caller_role IN ('admin', 'co_founder') THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Strictly guard role modification
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

-- 2. Hardened RLS Policy: Prevent unauthenticated Anon from scraping users / phones
DROP POLICY IF EXISTS "users_select_policy" ON public.users;
DROP POLICY IF EXISTS "users_select_anon" ON public.users;
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;

CREATE POLICY "users_select_policy" ON public.users 
FOR SELECT 
USING (
  auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND auth.uid() = id)
  OR (auth.uid() IS NOT NULL AND is_blocked = false)
);
