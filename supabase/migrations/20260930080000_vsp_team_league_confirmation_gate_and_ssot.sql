-- ============================================================
-- MIGRATION: 20260930080000_vsp_team_league_confirmation_gate_and_ssot
-- DATE     : 2026-09-30
--
-- FIXES:
--   1. confirm_team_league_match_result: Add state guard — creator cannot
--      confirm unless BOTH teams have submitted (status must be
--      awaiting_confirmation or disputed). Enforced server-side.
--   2. DROP create_team_league(text, uuid, text) — old 3-arg version is
--      dead code (Flutter calls 7-arg exclusively). Enforces SSOT.
--   3. INSERT migration records into supabase_migrations.schema_migrations
--      for previous migrations applied via execute_sql directly.
-- ============================================================

BEGIN;

-- ============================================================
-- FIX 1: confirm_team_league_match_result — state guard
-- Before this fix: creator could confirm a match still in 'scheduled'
-- or 'awaiting_submissions' (only 1 team submitted), bypassing the rule:
--   "Both teams submit → creator confirms"
-- After: Only 'awaiting_confirmation' or 'disputed' are valid states.
-- ============================================================
CREATE OR REPLACE FUNCTION public.confirm_team_league_match_result(
  p_match_id uuid,
  p_outcome  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_match     RECORD;
  v_user_id   UUID := auth.uid();
  v_winner_id UUID := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_outcome NOT IN ('home_win', 'draw', 'away_win') THEN
    RAISE EXCEPTION 'Invalid outcome. Must be home_win, draw, or away_win';
  END IF;

  -- Fetch match + championship (owner_id aliased as creator_id, template_type aliased as champ_template_type)
  SELECT tm.*, c.template_type AS champ_template_type, c.owner_id AS creator_id
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  -- Isolation: team_league only
  IF v_match.champ_template_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  -- Creator-only authority
  IF v_match.creator_id != v_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only the league creator can confirm or resolve match results';
  END IF;

  -- ⭐ NEW STATE GUARD: Both teams must have submitted before creator can act
  -- Valid states to confirm:
  --   'awaiting_confirmation' = both submitted, outcomes match → creator approves
  --   'disputed'              = both submitted, outcomes conflict → creator resolves
  -- Invalid states (only 0 or 1 team submitted):
  --   'scheduled', 'awaiting_submissions', 'confirmed', 'locked'
  IF v_match.result_status NOT IN ('awaiting_confirmation', 'disputed') THEN
    RAISE EXCEPTION
      'INVALID_STATE: Cannot confirm. Both teams must submit their results first. Current status: %',
      COALESCE(v_match.result_status, 'scheduled');
  END IF;

  -- Server-side 15-minute hard lock (confirmed → locked after 15 min)
  IF v_match.result_status = 'locked' OR
     (v_match.result_confirmed_at IS NOT NULL
      AND v_match.result_confirmed_at + INTERVAL '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches
    SET result_status    = 'locked',
        result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;
    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- Determine winner
  IF p_outcome = 'home_win' THEN
    v_winner_id := v_match.home_team_id;
  ELSIF p_outcome = 'away_win' THEN
    v_winner_id := v_match.away_team_id;
  END IF;

  -- Confirm the match → start 15-minute correction window
  UPDATE public.tournament_matches
  SET result_status       = 'confirmed',
      confirmed_outcome   = p_outcome,
      winner_id           = v_winner_id,
      result_confirmed_at = COALESCE(result_confirmed_at, clock_timestamp()),
      dispute_resolved_at = CASE WHEN v_match.result_status = 'disputed' THEN clock_timestamp() ELSE dispute_resolved_at END,
      dispute_resolved_by = CASE WHEN v_match.result_status = 'disputed' THEN v_user_id         ELSE dispute_resolved_by END,
      status              = 'completed',
      is_completed        = true
  WHERE id = p_match_id;

  -- Audit log
  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, actor_id, action, payload
  ) VALUES (
    p_match_id,
    v_match.championship_id,
    v_user_id,
    'creator_confirm_result',
    jsonb_build_object(
      'confirmed_outcome', p_outcome,
      'previous_status',   v_match.result_status,
      'winner_id',         v_winner_id
    )
  );

  RETURN jsonb_build_object(
    'success',           true,
    'match_id',          p_match_id,
    'result_status',     'confirmed',
    'confirmed_outcome', p_outcome,
    'winner_id',         v_winner_id
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.confirm_team_league_match_result(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_team_league_match_result(uuid, text) TO authenticated;


-- ============================================================
-- FIX 2: DROP old create_team_league(text, uuid, text) — 3 args
-- Flutter calls the 7-arg version exclusively. This function is
-- dead code and breaks SSOT (two creation paths, two payment flows).
-- Dropping it closes the legacy path permanently.
-- ============================================================
DROP FUNCTION IF EXISTS public.create_team_league(text, uuid, text);


-- ============================================================
-- FIX 3: Register previous execute_sql migrations in history
-- Migrations 20260930070000 was applied directly via execute_sql
-- and was not recorded. We record it now so migration state is
-- consistent with Production.
-- ============================================================
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES
  ('20260930070000', 'vsp_team_league_fix_critical_bugs')
ON CONFLICT (version) DO NOTHING;


-- ============================================================
-- VERIFICATION
-- ============================================================
DO $$
BEGIN
  -- 1. Confirm new RPC exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'confirm_team_league_match_result'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: confirm_team_league_match_result not found'; END IF;

  -- 2. Old 3-arg create_team_league must be gone
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'create_team_league'
      AND pg_catalog.pg_get_function_identity_arguments(p.oid) = 'p_league_name text, p_team_id uuid, p_governorate text'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: old 3-arg create_team_league still exists'; END IF;

  -- 3. New 7-arg create_team_league must still exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'create_team_league'
      AND pg_catalog.pg_get_function_identity_arguments(p.oid) LIKE '%max_teams%'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: new 7-arg create_team_league not found'; END IF;

  -- 4. Migration history must include our entry
  IF NOT EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '20260930070000'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: migration 20260930070000 not in history'; END IF;

  RAISE NOTICE 'ALL VERIFICATIONS PASSED';
END;
$$;

COMMIT;
