-- =============================================================
-- VSP Phase 2F: Unlock Owner Features (No Subscription Stadium Limits)
-- Only stadium verification gates stadium publishing/operations.
-- Migration: 20261126090000_unlock_owner_features.sql
-- =============================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.evaluate_owner_stadium_capacity(
  p_owner_id uuid,
  p_exclude_stadium_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE(
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
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_owner        public.users%ROWTYPE;
  v_active_count integer := 0;
BEGIN
  IF COALESCE(current_setting('request.jwt.claim.role', true), '') = 'authenticated' THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للتحقق من حساب المالك.'
        USING ERRCODE = '42501';
    END IF;
    IF auth.uid() <> p_owner_id AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالاطلاع على بيانات مالك آخر.'
        USING ERRCODE = '42501';
    END IF;
  ELSIF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id THEN
    IF NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالاطلاع على بيانات مالك آخر.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT * INTO v_owner
  FROM public.users
  WHERE id = p_owner_id;

  IF v_owner.id IS NULL THEN
    RETURN QUERY SELECT false, 0, 0, false, false, ''::text, 'مالك الملعب غير موجود في النظام.'::text;
    RETURN;
  END IF;

  SELECT count(*)::integer INTO v_active_count
  FROM public.stadiums
  WHERE owner_id = p_owner_id
    AND COALESCE(is_deleted_by_owner, false) = false
    AND (p_exclude_stadium_id IS NULL OR id <> p_exclude_stadium_id);

  RETURN QUERY SELECT true, v_active_count, 999, false, true, 'partner'::text,
    'مسموح بإضافة وتفعيل الملاعب بدون قيود باقات'::text;
END;
$function$;

COMMIT;
