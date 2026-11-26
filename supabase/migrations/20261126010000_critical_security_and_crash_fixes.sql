-- =============================================================
-- VSP Security Hardening & Critical Crash Fixes
-- Migration: 20261126010000_critical_security_and_crash_fixes.sql
-- Fixes: SEC-01, SEC-04, SEC-05, SEC-06, SEC-07, SEC-08,
--        CRASH-01, CRASH-03, CRASH-05
-- =============================================================
BEGIN;

-- ============================================================
-- CRASH-01: Add missing columns to teams table
-- ============================================================
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS fair_play_score   INTEGER  DEFAULT 100,
  ADD COLUMN IF NOT EXISTS elo_rating        INTEGER  DEFAULT 1000,
  ADD COLUMN IF NOT EXISTS preferred_formation TEXT,
  ADD COLUMN IF NOT EXISTS is_active         BOOLEAN  DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_blocked        BOOLEAN  DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_verified       BOOLEAN  DEFAULT false;

-- ============================================================
-- CRASH-03: Fix typo in sync_booking_public_feed
-- excluded.opponent_team_logo → excluded.opponent_team_logo_url
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.is_private = true OR NEW.booking_type = 'private' THEN
    DELETE FROM public.booking_public_feed WHERE booking_id = NEW.id;
    RETURN NEW;
  END IF;

  INSERT INTO public.booking_public_feed (
    booking_id, stadium_id, start_time, end_time, booking_type,
    team_id, opponent_team_id, opponent_team_name, opponent_team_logo_url,
    is_open_join, current_players, max_players, status, updated_at
  )
  SELECT
    NEW.id, NEW.stadium_id, NEW.start_time, NEW.end_time, NEW.booking_type,
    NEW.team_id, NEW.opponent_team_id,
    (SELECT name  FROM public.teams WHERE id = NEW.opponent_team_id),
    (SELECT logo_url FROM public.teams WHERE id = NEW.opponent_team_id),
    COALESCE(NEW.is_open_join, false),
    COALESCE(NEW.current_players_count, 0),
    COALESCE(NEW.max_players, 0),
    NEW.status, NOW()
  ON CONFLICT (booking_id) DO UPDATE SET
    start_time             = excluded.start_time,
    end_time               = excluded.end_time,
    status                 = excluded.status,
    opponent_team_name     = excluded.opponent_team_name,
    opponent_team_logo_url = excluded.opponent_team_logo_url,
    current_players        = excluded.current_players,
    updated_at             = excluded.updated_at;

  RETURN NEW;
END;
$$;

-- ============================================================
-- CRASH-05: Add 'no_show' to bookings status constraint
-- ============================================================
ALTER TABLE public.bookings
  DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending','confirmed','completed','cancelled','expired','no_show'));

-- ============================================================
-- SEC-04: Fix inverted maintenance window check
-- ============================================================
CREATE OR REPLACE FUNCTION public.vsp_validate_stadium_booking_window()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_stadium RECORD;
BEGIN
  SELECT maintenance_until, is_active, is_blocked
  INTO v_stadium
  FROM public.stadiums
  WHERE id = NEW.stadium_id;

  -- Block if stadium is not active or blocked
  IF v_stadium.is_blocked = true THEN
    RAISE EXCEPTION 'STADIUM_BLOCKED';
  END IF;

  IF v_stadium.is_active = false THEN
    RAISE EXCEPTION 'STADIUM_INACTIVE';
  END IF;

  -- FIXED: Block bookings whose start_time falls BEFORE maintenance ends
  -- (previous logic was inverted)
  IF v_stadium.maintenance_until IS NOT NULL
     AND NEW.start_time < v_stadium.maintenance_until THEN
    RAISE EXCEPTION 'STADIUM_UNDER_MAINTENANCE'
      USING DETAIL = v_stadium.maintenance_until::text;
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================
-- SEC-05: Fix respond_booking_reschedule_atomic
-- Add set_config to bypass booking protection trigger
-- ============================================================
CREATE OR REPLACE FUNCTION public.respond_booking_reschedule_atomic(
  p_request_id  UUID,
  p_responder_id UUID,
  p_action      TEXT  -- 'accept' | 'reject'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_request  RECORD;
  v_booking  RECORD;
BEGIN
  -- Allow updating booking timing fields
  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_request
  FROM public.booking_reschedule_requests
  WHERE id = p_request_id AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_FOUND_OR_RESOLVED');
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = v_request.booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_NOT_FOUND');
  END IF;

  -- Only the opposing party can respond
  IF v_request.requested_by = p_responder_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_RESPOND_OWN_REQUEST');
  END IF;

  IF p_action = 'accept' THEN
    UPDATE public.bookings
    SET start_time = v_request.proposed_start_time,
        end_time   = v_request.proposed_end_time,
        updated_at = NOW()
    WHERE id = v_request.booking_id;

    UPDATE public.booking_reschedule_requests
    SET status = 'accepted', responded_at = NOW(), responded_by = p_responder_id
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'action', 'accepted');
  ELSE
    UPDATE public.booking_reschedule_requests
    SET status = 'rejected', responded_at = NOW(), responded_by = p_responder_id
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'action', 'rejected');
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.respond_booking_reschedule_atomic(UUID, UUID, TEXT) FROM anon;
GRANT  EXECUTE ON FUNCTION public.respond_booking_reschedule_atomic(UUID, UUID, TEXT) TO authenticated;

-- ============================================================
-- SEC-06: Remove phone leak from get_team_active_league
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_team_active_league(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_league  RECORD;
  v_members JSONB;
BEGIN
  -- Verify caller is a member of this team
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_TEAM_MEMBER');
  END IF;

  SELECT c.* INTO v_league
  FROM public.championships c
  WHERE c.championship_type = 'team_league'
    AND p_team_id::text = ANY(c.joined_teams)
    AND c.status IN ('registration','active','ongoing')
  ORDER BY c.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', true, 'league', NULL);
  END IF;

  -- Return members WITHOUT phone numbers
  SELECT jsonb_agg(jsonb_build_object(
    'id',       u.id,
    'name',     u.name,
    'avatar',   u.profile_image_url
    -- phone intentionally excluded
  ))
  INTO v_members
  FROM public.users u
  JOIN public.team_members tm ON tm.user_id = u.id
  WHERE tm.team_id = p_team_id;

  RETURN jsonb_build_object(
    'success', true,
    'league', row_to_json(v_league),
    'members', COALESCE(v_members, '[]'::jsonb)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_team_active_league(UUID) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_team_active_league(UUID) TO authenticated;

-- ============================================================
-- SEC-07: Fix RLS on team_league_match_submissions
--         (was USING (true) = visible to all)
-- ============================================================
DROP POLICY IF EXISTS "team_league_submissions_select" ON public.team_league_match_submissions;
DROP POLICY IF EXISTS "select_team_league_match_submissions" ON public.team_league_match_submissions;

CREATE POLICY "team_members_see_own_league_submissions"
  ON public.team_league_match_submissions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      JOIN public.championships c ON c.id = team_league_match_submissions.championship_id
      WHERE tm.user_id = auth.uid()
        AND tm.team_id::text = ANY(c.joined_teams)
    )
  );

-- Fix RLS on team_league_result_audits
DROP POLICY IF EXISTS "team_league_audits_select" ON public.team_league_result_audits;
DROP POLICY IF EXISTS "select_team_league_result_audits" ON public.team_league_result_audits;

CREATE POLICY "team_members_see_own_league_audits"
  ON public.team_league_result_audits
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      JOIN public.championships c ON c.id = team_league_result_audits.championship_id
      WHERE tm.user_id = auth.uid()
        AND tm.team_id::text = ANY(c.joined_teams)
    )
  );

-- ============================================================
-- SEC-08: Restore INSERT grant on notifications
-- (lost in migration 20261010110500)
-- ============================================================
GRANT INSERT ON TABLE public.notifications TO authenticated;

-- ============================================================
-- SEC-02: Restrict most-dangerous admin-only RPCs
-- Remove PUBLIC/authenticated access; require service_role
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.admin_set_owner_subscription_atomic FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.admin_set_owner_subscription_atomic TO service_role;

REVOKE EXECUTE ON FUNCTION public.confirm_owner_subscription_payment FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.confirm_owner_subscription_payment TO service_role;

REVOKE EXECUTE ON FUNCTION public.admin_finalize_1v1_tournament_atomic FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.admin_finalize_1v1_tournament_atomic TO service_role;

REVOKE EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic TO service_role;

REVOKE EXECUTE ON FUNCTION public.start_championship_atomic FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.start_championship_atomic TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.activate_championship_competition_atomic FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.activate_championship_competition_atomic TO authenticated, service_role;

COMMIT;
