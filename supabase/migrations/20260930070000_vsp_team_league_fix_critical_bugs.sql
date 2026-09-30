-- ============================================================
-- MIGRATION: 20260930070000_vsp_team_league_fix_critical_bugs
-- PURPOSE  : Fix 6 critical production bugs discovered in audit
-- DATE     : 2026-09-30
--
-- BUGS FIXED:
--   1. submit_team_league_match_result → c.creator_id (col not exist → owner_id)
--   2. submit_team_league_match_result → c.type check ('league' not 'team_league' → template_type)
--   3. submit_team_league_match_result → public.players (not exist → team_members)
--   4. confirm_team_league_match_result → same creator_id + type bugs
--   5. get_team_league_standings → championship_participants (not exist → joined_teams[])
--   6. create_team_league (7 args) → anon can execute (REVOKE)
-- LEGACY  : DROP record_league_match_result (goals-based, violates no-goals rule)
-- ============================================================

BEGIN;

-- ============================================================
-- FIX 1+2+3: submit_team_league_match_result
-- ============================================================
CREATE OR REPLACE FUNCTION public.submit_team_league_match_result(
  p_match_id uuid,
  p_team_id  uuid,
  p_result   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_match              RECORD;
  v_user_id            UUID := auth.uid();
  v_is_captain         BOOLEAN := false;
  v_opp_sub            RECORD;
  v_new_status         TEXT;
  v_reconciled_outcome TEXT := NULL;
  v_home_res           TEXT;
  v_away_res           TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_result NOT IN ('win', 'draw', 'loss') THEN
    RAISE EXCEPTION 'Invalid result outcome. Must be win, draw, or loss.';
  END IF;

  -- FIX #1+#2: Use c.owner_id (not c.creator_id) and c.template_type (not c.type)
  SELECT tm.*, c.template_type AS champ_template_type, c.owner_id AS creator_id
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.champ_template_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  IF p_team_id != v_match.home_team_id AND p_team_id != v_match.away_team_id THEN
    RAISE EXCEPTION 'Team does not belong to this match';
  END IF;

  -- FIX #3: Use public.team_members (not public.players which does not exist)
  SELECT (captain_id = v_user_id) INTO v_is_captain
  FROM public.teams WHERE id = p_team_id;

  IF NOT v_is_captain THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_id = p_team_id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'You are not authorized to submit results for this team';
    END IF;
  END IF;

  -- Server-side 15-minute hard lock
  IF v_match.result_status = 'locked' OR
     (v_match.result_confirmed_at IS NOT NULL
      AND v_match.result_confirmed_at + INTERVAL '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches
    SET result_status    = 'locked',
        result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;
    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- Upsert this team's submission
  INSERT INTO public.team_league_match_submissions (
    match_id, team_id, submitted_by, result, submitted_at, submission_version
  ) VALUES (
    p_match_id, p_team_id, v_user_id, p_result, clock_timestamp(), 1
  )
  ON CONFLICT (match_id, team_id) DO UPDATE SET
    submitted_by       = EXCLUDED.submitted_by,
    result             = EXCLUDED.result,
    submitted_at       = clock_timestamp(),
    submission_version = public.team_league_match_submissions.submission_version + 1;

  -- Check opponent submission
  SELECT * INTO v_opp_sub
  FROM public.team_league_match_submissions
  WHERE match_id = p_match_id AND team_id != p_team_id;

  IF v_opp_sub.id IS NULL THEN
    v_new_status := 'awaiting_submissions';
  ELSE
    IF p_team_id = v_match.home_team_id THEN
      v_home_res := p_result;
      v_away_res := v_opp_sub.result;
    ELSE
      v_home_res := v_opp_sub.result;
      v_away_res := p_result;
    END IF;

    IF v_home_res = 'win' AND v_away_res = 'loss' THEN
      v_reconciled_outcome := 'home_win';
      v_new_status         := 'awaiting_confirmation';
    ELSIF v_home_res = 'loss' AND v_away_res = 'win' THEN
      v_reconciled_outcome := 'away_win';
      v_new_status         := 'awaiting_confirmation';
    ELSIF v_home_res = 'draw' AND v_away_res = 'draw' THEN
      v_reconciled_outcome := 'draw';
      v_new_status         := 'awaiting_confirmation';
    ELSE
      v_reconciled_outcome := NULL;
      v_new_status         := 'disputed';
    END IF;
  END IF;

  -- Update match state (creator must still confirm)
  UPDATE public.tournament_matches
  SET result_status      = v_new_status,
      confirmed_outcome  = CASE WHEN v_new_status = 'awaiting_confirmation' THEN v_reconciled_outcome ELSE NULL END,
      dispute_created_at = CASE WHEN v_new_status = 'disputed' THEN COALESCE(dispute_created_at, clock_timestamp()) ELSE NULL END
  WHERE id = p_match_id;

  -- Audit log
  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, team_id, actor_id, action, payload
  ) VALUES (
    p_match_id, v_match.championship_id, p_team_id, v_user_id,
    'submit_result',
    jsonb_build_object(
      'result', p_result,
      'resulting_status', v_new_status,
      'reconciled_outcome', v_reconciled_outcome
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'match_id', p_match_id,
    'result_status', v_new_status,
    'reconciled_outcome', v_reconciled_outcome
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.submit_team_league_match_result(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_team_league_match_result(uuid, uuid, text) TO authenticated;


-- ============================================================
-- FIX 4: confirm_team_league_match_result
-- Bugs: c.creator_id (→ owner_id) and c.type (→ template_type)
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

  -- FIX: Use c.template_type (not c.type) and c.owner_id (not c.creator_id)
  SELECT tm.*, c.template_type AS champ_template_type, c.owner_id AS creator_id
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.champ_template_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  -- Creator-only authority (uses aliased creator_id = owner_id)
  IF v_match.creator_id != v_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only the league creator can confirm or resolve match results';
  END IF;

  -- Server-side 15-minute hard lock
  IF v_match.result_status = 'locked' OR
     (v_match.result_confirmed_at IS NOT NULL
      AND v_match.result_confirmed_at + INTERVAL '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches
    SET result_status    = 'locked',
        result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;
    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  IF p_outcome = 'home_win' THEN
    v_winner_id := v_match.home_team_id;
  ELSIF p_outcome = 'away_win' THEN
    v_winner_id := v_match.away_team_id;
  END IF;

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

  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, actor_id, action, payload
  ) VALUES (
    p_match_id, v_match.championship_id, v_user_id,
    'creator_confirm_result',
    jsonb_build_object(
      'confirmed_outcome', p_outcome,
      'previous_status',   v_match.result_status,
      'winner_id',         v_winner_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'match_id', p_match_id,
    'result_status', 'confirmed',
    'confirmed_outcome', p_outcome,
    'winner_id', v_winner_id
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.confirm_team_league_match_result(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_team_league_match_result(uuid, text) TO authenticated;


-- ============================================================
-- FIX 5: get_team_league_standings
-- Bug: championship_participants table does not exist
-- Fix: Use championships.joined_teams text[] to enumerate teams
-- Tie-breaker: Points → H2H Points → Total Wins → Name → UUID
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_team_league_standings(p_championship_id uuid)
RETURNS TABLE(
  rank          bigint,
  team_id       uuid,
  team_name     text,
  team_logo_url text,
  played        integer,
  won           integer,
  drawn         integer,
  lost          integer,
  points        integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN QUERY
  WITH enrolled_teams AS (
    -- FIX: championships.joined_teams (text[]) replaces championship_participants
    SELECT DISTINCT t.id AS e_team_id, t.name AS e_team_name, t.logo_url AS e_team_logo_url
    FROM public.championships ch
    CROSS JOIN LATERAL unnest(ch.joined_teams) AS jt(team_id_text)
    JOIN public.teams t ON t.id = jt.team_id_text::uuid
    WHERE ch.id = p_championship_id
  ),
  base_stats AS (
    SELECT
      et.e_team_id       AS b_team_id,
      et.e_team_name     AS b_team_name,
      et.e_team_logo_url AS b_team_logo_url,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
      ), 0)::INTEGER AS b_played,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked') AND (
          (m.home_team_id = et.e_team_id AND m.confirmed_outcome = 'home_win') OR
          (m.away_team_id = et.e_team_id AND m.confirmed_outcome = 'away_win')
        )
      ), 0)::INTEGER AS b_won,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
          AND m.confirmed_outcome = 'draw'
          AND (m.home_team_id = et.e_team_id OR m.away_team_id = et.e_team_id)
      ), 0)::INTEGER AS b_drawn,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked') AND (
          (m.home_team_id = et.e_team_id AND m.confirmed_outcome = 'away_win') OR
          (m.away_team_id = et.e_team_id AND m.confirmed_outcome = 'home_win')
        )
      ), 0)::INTEGER AS b_lost
    FROM enrolled_teams et
    LEFT JOIN public.tournament_matches m
      ON m.championship_id = p_championship_id
      AND (m.home_team_id = et.e_team_id OR m.away_team_id = et.e_team_id)
    GROUP BY et.e_team_id, et.e_team_name, et.e_team_logo_url
  ),
  with_points AS (
    SELECT s.*, ((s.b_won * 3) + (s.b_drawn * 1))::INTEGER AS b_points
    FROM base_stats s
  ),
  with_h2h AS (
    SELECT
      p.b_team_id, p.b_team_name, p.b_team_logo_url,
      p.b_played, p.b_won, p.b_drawn, p.b_lost, p.b_points,
      COALESCE(SUM(
        CASE
          WHEN (m.home_team_id = p.b_team_id AND m.confirmed_outcome = 'home_win') OR
               (m.away_team_id = p.b_team_id AND m.confirmed_outcome = 'away_win') THEN 3
          WHEN m.confirmed_outcome = 'draw'
           AND (m.home_team_id = p.b_team_id OR m.away_team_id = p.b_team_id)     THEN 1
          ELSE 0
        END
      ), 0)::INTEGER AS h2h_points
    FROM with_points p
    LEFT JOIN with_points rival
      ON rival.b_points = p.b_points AND rival.b_team_id != p.b_team_id
    LEFT JOIN public.tournament_matches m
      ON m.championship_id = p_championship_id
      AND m.result_status IN ('confirmed', 'locked')
      AND (
        (m.home_team_id = p.b_team_id AND m.away_team_id = rival.b_team_id) OR
        (m.away_team_id = p.b_team_id AND m.home_team_id = rival.b_team_id)
      )
    GROUP BY
      p.b_team_id, p.b_team_name, p.b_team_logo_url,
      p.b_played, p.b_won, p.b_drawn, p.b_lost, p.b_points
  )
  SELECT
    ROW_NUMBER() OVER (
      ORDER BY h.b_points DESC, h.h2h_points DESC, h.b_won DESC, h.b_team_name ASC, h.b_team_id ASC
    )           AS rank,
    h.b_team_id AS team_id,
    h.b_team_name AS team_name,
    h.b_team_logo_url AS team_logo_url,
    h.b_played  AS played,
    h.b_won     AS won,
    h.b_drawn   AS drawn,
    h.b_lost    AS lost,
    h.b_points  AS points
  FROM with_h2h h
  ORDER BY rank ASC;
END;
$$;

REVOKE ALL    ON FUNCTION public.get_team_league_standings(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_league_standings(uuid) TO authenticated;


-- ============================================================
-- FIX 6: REVOKE anon from create_team_league (7 args)
-- Note: Must revoke from PUBLIC first (anon inherits from PUBLIC)
-- ============================================================
REVOKE ALL     ON FUNCTION public.create_team_league(
  text, uuid, text, integer, integer, text, integer
) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.create_team_league(
  text, uuid, text, integer, integer, text, integer
) FROM anon;

GRANT EXECUTE ON FUNCTION public.create_team_league(
  text, uuid, text, integer, integer, text, integer
) TO authenticated;


-- ============================================================
-- LEGACY: DROP record_league_match_result (goals-based)
-- Violates no-goals rule. Replaced by submit_team_league_match_result.
-- ============================================================
DROP FUNCTION IF EXISTS public.record_league_match_result(
  uuid, integer, integer, integer, integer
);


-- ============================================================
-- VERIFICATION
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'submit_team_league_match_result'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: submit_team_league_match_result not found'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'confirm_team_league_match_result'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: confirm_team_league_match_result not found'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_team_league_standings'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: get_team_league_standings not found'; END IF;

  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'record_league_match_result'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: record_league_match_result still exists'; END IF;

  RAISE NOTICE 'ALL VERIFICATIONS PASSED';
END;
$$;

COMMIT;
