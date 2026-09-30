-- Migration: 20261001043000_tournament_rpc_security_hardening.sql
-- Description: Hardens tournament RPC surfaces against unauthorized anon access,
-- seals admin_update_1v1_tournament_status authorization to verified auth.uid(),
-- restricts auto_expire_pending_1v1_orders to internal server callers only,
-- and revokes public/anon access from tournament mutation RPCs.

-- ========================================================
-- 1. Fix admin_update_1v1_tournament_status
-- ========================================================
CREATE OR REPLACE FUNCTION public.admin_update_1v1_tournament_status(
  p_tournament_id uuid, 
  p_new_status text, 
  p_admin_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid UUID;
  v_caller_role TEXT;
  v_current_status TEXT;
  v_allowed_transitions JSONB := '{
    "draft": ["registration_open"],
    "registration_open": ["in_progress", "draft"],
    "in_progress": ["completed"],
    "completed": ["published"],
    "published": ["archived"]
  }';
BEGIN
  -- Verify caller role: internal service_role/postgres OR authenticated admin/co_founder/super_admin
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'يجب تسجيل الدخول لتنفيذ هذه العملية.';
    END IF;

    SELECT role INTO v_caller_role 
    FROM public.users 
    WHERE id = v_uid;

    IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')) THEN
      RAISE EXCEPTION 'غير مصرح: هذه العملية مخصصة لمديري النظام فقط.';
    END IF;
  END IF;

  -- Lock the row to prevent race conditions
  SELECT status INTO v_current_status
  FROM public.vsp_1v1_tournaments
  WHERE id = p_tournament_id
  FOR UPDATE;

  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'البطولة غير موجودة.';
  END IF;

  -- Idempotency check
  IF v_current_status = p_new_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'old_status', v_current_status,
      'new_status', p_new_status,
      'message', 'البطولة بالفعل في هذه الحالة.'
    );
  END IF;

  -- Validate status transition
  IF NOT (v_allowed_transitions->v_current_status) @> to_jsonb(p_new_status) THEN
    RAISE EXCEPTION 'تحويل غير مسموح لحالة البطولة: من % إلى %', v_current_status, p_new_status;
  END IF;

  UPDATE public.vsp_1v1_tournaments
  SET status = p_new_status,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true,
    'old_status', v_current_status,
    'new_status', p_new_status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_1v1_tournament_status(uuid, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_1v1_tournament_status(uuid, text, uuid) TO authenticated, service_role, postgres;

-- ========================================================
-- 2. Seal auto_expire_pending_1v1_orders (Server-only)
-- ========================================================
CREATE OR REPLACE FUNCTION public.auto_expire_pending_1v1_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count INT := 0;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    RAISE EXCEPTION 'غير مصرح: هذه العملية مخصصة للسيرفر فقط.';
  END IF;

  UPDATE public.vsp_1v1_tournament_orders
  SET payment_status = 'expired',
      updated_at = timezone('utc'::text, now())
  WHERE payment_status = 'pending'
    AND expires_at < timezone('utc'::text, now())
    AND expires_at IS NOT NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'expired_count', v_count);
END;
$function$;

REVOKE ALL ON FUNCTION public.auto_expire_pending_1v1_orders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_expire_pending_1v1_orders() TO service_role, postgres;

-- ========================================================
-- 3. Revoke PUBLIC and anon from the 4 tournament mutation RPCs
-- ========================================================
REVOKE ALL ON FUNCTION public.advance_groups_to_knockout_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.advance_groups_to_knockout_atomic(uuid) TO authenticated, service_role, postgres;

REVOKE ALL ON FUNCTION public.generate_regular_group_fixtures_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_regular_group_fixtures_atomic(uuid) TO authenticated, service_role, postgres;

REVOKE ALL ON FUNCTION public.generate_regular_league_fixtures_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_regular_league_fixtures_atomic(uuid) TO authenticated, service_role, postgres;

REVOKE ALL ON FUNCTION public.update_tournament_match_schedule_atomic(uuid, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_tournament_match_schedule_atomic(uuid, timestamp with time zone) TO authenticated, service_role, postgres;
