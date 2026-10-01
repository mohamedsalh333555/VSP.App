-- ============================================================================
-- Migration: 20261001120000_phases2_to_6_join_leave_and_challenge_lifecycle.sql
-- Purpose:
--   Phase 2: Harden Open Join Server-Side (request_join_public_match & leave_public_match_atomic)
--   Phase 3 & 4 & 5: Flexible VSP- code handling in lookup_challenge_code and create_challenge_booking_atomic
--   Phase 6: Neutralize legacy challenge acceptance and pending auto-expiration
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Phase 6: Neutralize legacy challenge acceptance & expiration
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_challenge_atomic(p_booking_id uuid, p_accept boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  -- Challenge acceptance has been superseded by the direct single-use challenge code system.
  -- All challenges created via challenge codes are immediately confirmed.
  RETURN jsonb_build_object(
    'success', false,
    'error', 'LEGACY_CHALLENGE_FLOW_DISABLED',
    'message', 'تم استبدال نظام الموافقة بنظام كود التحدي المباشر. التحديات الجديدة مؤكدة فور الإنشاء.'
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.respond_to_challenge_atomic(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_challenge_atomic(uuid, boolean) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.auto_expire_pending_challenges()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  -- Neutralized: No longer auto-cancels confirmed challenge bookings.
  -- Only expires unconfirmed pending payment locks that exceeded their locked_until time.
  UPDATE public.bookings
  SET status = 'cancelled',
      cancellation_reason = 'payment_timeout',
      updated_at = timezone('utc', now())
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND locked_until IS NOT NULL
    AND locked_until < timezone('utc', now());
END;
$fn$;

REVOKE ALL ON FUNCTION public.auto_expire_pending_challenges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_expire_pending_challenges() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Phase 2: Harden request_join_public_match
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_join_public_match(p_booking_id text, p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_booking       record;
  v_user_conflict int;
  v_user_blocked  boolean;
  v_capacity      int;
  v_booking_uuid  uuid;
  v_user_uuid     uuid;
  v_now           timestamptz := timezone('utc', now());
BEGIN
  BEGIN
    v_booking_uuid := p_booking_id::uuid;
    v_user_uuid    := p_user_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_UUID_FORMAT' USING ERRCODE = '22P02';
  END;

  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF auth.uid() IS NULL OR auth.uid() <> v_user_uuid THEN
      RAISE EXCEPTION 'PERMISSION_DENIED' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking_uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  -- SSOT Gate: strictly open_join bookings allow public joining
  IF COALESCE(v_booking.booking_type, '') <> 'open_join' THEN
    RAISE EXCEPTION 'not_an_open_join_match';
  END IF;

  IF v_booking.is_private IS TRUE THEN RAISE EXCEPTION 'match_not_public'; END IF;
  IF v_booking.status = 'cancelled' THEN RAISE EXCEPTION 'match_cancelled'; END IF;
  IF v_booking.status = 'completed' THEN RAISE EXCEPTION 'match_already_completed'; END IF;
  IF v_booking.end_time <= v_now THEN RAISE EXCEPTION 'match_expired'; END IF;

  -- Block joining unpaid pending online bookings until host payment confirms
  IF v_booking.status NOT IN ('confirmed')
     AND NOT (v_booking.status = 'pending' AND lower(COALESCE(v_booking.payment_method, '')) = 'cash') THEN
    RAISE EXCEPTION 'match_not_confirmed';
  END IF;

  SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
  IF v_user_blocked IS TRUE THEN RAISE EXCEPTION 'user_blocked'; END IF;

  v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
  IF COALESCE(v_booking.current_players, 0) >= v_capacity THEN
    RAISE EXCEPTION 'match_is_full';
  END IF;

  IF v_user_uuid = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))
     OR v_booking.created_by_user_id = v_user_uuid THEN
    RAISE EXCEPTION 'already_joined';
  END IF;

  -- Time conflict check for joining player
  SELECT COUNT(*) INTO v_user_conflict FROM public.bookings
  WHERE status <> 'cancelled' AND id <> v_booking_uuid
    AND (created_by_user_id = v_user_uuid OR v_user_uuid = ANY(COALESCE(joined_user_ids, ARRAY[]::uuid[])))
    AND start_time < v_booking.end_time AND end_time > v_booking.start_time;

  IF v_user_conflict > 0 THEN RAISE EXCEPTION 'time_conflict'; END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::uuid[]), v_user_uuid),
      current_players = COALESCE(current_players, 0) + 1,
      updated_at = v_now
  WHERE id = v_booking_uuid;

  RETURN jsonb_build_object(
    'success',         true,
    'booking_id',      p_booking_id,
    'current_players', COALESCE(v_booking.current_players, 0) + 1,
    'host_user_id',    v_booking.created_by_user_id
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.request_join_public_match(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_join_public_match(text, text) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Phase 2: Harden leave_public_match_atomic
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.leave_public_match_atomic(p_booking_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_booking record;
  v_now     timestamptz := timezone('utc', now());
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
      RAISE EXCEPTION 'Unauthorized: You can only leave matches on your own behalf.';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;

  IF v_booking.status IN ('completed', 'cancelled', 'expired') THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave a % booking.', v_booking.status;
  END IF;

  IF v_booking.end_time <= v_now THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave a match that has already ended.';
  END IF;

  IF NOT (p_user_id = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'User is not a joined participant in this match';
  END IF;

  IF v_booking.created_by_user_id = p_user_id THEN
    RAISE EXCEPTION 'HOST_CANNOT_LEAVE: The host cannot leave. Cancel the booking instead.';
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET current_players = GREATEST(0, current_players - 1),
      joined_user_ids = array_remove(joined_user_ids, p_user_id),
      updated_at = v_now
  WHERE id = p_booking_id;

  RETURN true;
END;
$fn$;

REVOKE ALL ON FUNCTION public.leave_public_match_atomic(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_public_match_atomic(uuid, uuid) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Phase 3 & 4: Normalize code prefix in lookup_challenge_code
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lookup_challenge_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_caller         uuid := auth.uid();
  v_entry          record;
  v_team           record;
  v_members        int;
  v_caller_team_id uuid;
  v_clean_code     text;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  v_clean_code := upper(trim(COALESCE(p_code, '')));
  IF NOT v_clean_code LIKE 'VSP-%' AND length(v_clean_code) = 5 THEN
    v_clean_code := 'VSP-' || v_clean_code;
  END IF;

  SELECT * INTO v_entry
  FROM public.team_challenge_codes
  WHERE (code = v_clean_code OR code = upper(trim(p_code))) AND status = 'active'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CODE_INVALID_OR_USED');
  END IF;

  IF v_entry.expires_at IS NOT NULL AND v_entry.expires_at < timezone('utc', now()) THEN
    UPDATE public.team_challenge_codes SET status = 'expired' WHERE id = v_entry.id;
    RETURN jsonb_build_object('success', false, 'error', 'CODE_EXPIRED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  SELECT COUNT(*) INTO v_members FROM public.team_members WHERE team_id = v_entry.team_id;

  SELECT id INTO v_caller_team_id
  FROM public.teams WHERE captain_id = v_caller LIMIT 1;

  IF v_caller_team_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN');
  END IF;

  IF v_caller_team_id = v_entry.team_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM');
  END IF;

  RETURN jsonb_build_object(
    'success',              true,
    'opponent_team_id',     v_entry.team_id,
    'opponent_team_name',   v_team.name,
    'opponent_captain',     v_team.captain_name,
    'opponent_logo_url',    v_team.logo_url,
    'member_count',         v_members,
    'caller_team_id',       v_caller_team_id,
    'code_id',              v_entry.id,
    'code',                 v_entry.code
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.lookup_challenge_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lookup_challenge_code(text) TO authenticated, service_role;
