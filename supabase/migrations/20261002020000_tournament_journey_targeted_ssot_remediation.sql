-- ==============================================================================
-- Migration: 20261002020000_tournament_journey_targeted_ssot_remediation.sql
-- Purpose:
--   Targeted SSOT Remediation for Regular Championship / Tournament Journey:
--   1. Server-Authoritative Match Result (record_match_result_and_advance_atomic):
--      - Rejects negative scores.
--      - Requires valid winner for knockout/cup matches.
--      - Requires non-null, non-tied penalties for tied knockout matches.
--      - Rejects winner not participating in the match or score/winner mismatch.
--      - Persists authoritative status = 'completed', is_completed = true, result_status = 'confirmed'.
--   2. Standings SSOT (get_championship_standings):
--      - Strictly counts only authoritative completed results (result_status IN ('confirmed', 'locked')).
--      - Excludes disputed / unconfirmed results.
--   3. Champion SSOT (crown_tournament_champion_atomic):
--      - Locates actual final match (round_index = 0 AND next_match_id IS NULL) for bracketed tournaments.
--      - Requires final match to be completed with authoritative result (status = 'completed', result_status IN ('confirmed', 'locked')).
--      - Requires final_match.winner_id == p_champion_team_id.
--      - For non-bracketed (league), requires all matches completed and team is 1st in standings.
--      - Preserves frozen-roster requirement, server team name as SSOT, and idempotent same-champion behavior.
--   4. Completion Guard (transition_championship_status_atomic):
--      - ongoing -> completed strictly blocked unless:
--        a) champion is already crowned (champion_team_id IS NOT NULL).
--        b) all matches are completed (no matches with status != 'completed').
-- ==============================================================================

-- 1. record_match_result_and_advance_atomic
CREATE OR REPLACE FUNCTION public.record_match_result_and_advance_atomic(
    p_match_id UUID,
    p_home_score INT,
    p_away_score INT,
    p_home_penalties INT DEFAULT NULL,
    p_away_penalties INT DEFAULT NULL,
    p_winner_id UUID DEFAULT NULL,
    p_winner_name TEXT DEFAULT NULL,
    p_goal_details JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_match RECORD;
    v_champ RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_is_knockout BOOLEAN;
    v_expected_winner_id UUID;
    v_effective_winner_id UUID := p_winner_id;
    v_effective_winner_name TEXT := p_winner_name;
BEGIN
    -- 1. Reject negative scores
    IF p_home_score < 0 OR p_away_score < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_SCORE: Scores cannot be negative');
    END IF;

    IF (p_home_penalties IS NOT NULL AND p_home_penalties < 0) OR (p_away_penalties IS NOT NULL AND p_away_penalties < 0) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_PENALTIES: Penalty scores cannot be negative');
    END IF;

    -- 2. Fetch match and lock
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- Prevent modifying locked matches
    IF v_match.result_status = 'locked' THEN
        RETURN jsonb_build_object('success', false, 'error', 'LOCKED_MATCH: Match result is locked and cannot be modified');
    END IF;

    -- 3. Authorization (owner or admin)
    SELECT * INTO v_champ FROM public.championships WHERE id = v_match.championship_id;
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can submit scores');
            END IF;
        END IF;
    END IF;

    -- Both teams must be populated
    IF v_match.home_team_id IS NULL OR v_match.away_team_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'INCOMPLETE_MATCH: Both teams must be assigned before recording score');
    END IF;

    -- Determine if knockout match
    v_is_knockout := (
        v_match.next_match_id IS NOT NULL OR 
        v_match.stage IN ('knockout', 'cup', 'round_of_16', 'quarter_final', 'semi_final', 'final') OR 
        COALESCE(v_champ.type, '') = 'cup' OR 
        (v_match.round_index = 0 AND v_match.group_name IS NULL)
    );

    -- 4. Validate winner vs scores
    IF p_home_score != p_away_score THEN
        IF p_home_score > p_away_score THEN
            v_expected_winner_id := v_match.home_team_id;
        ELSE
            v_expected_winner_id := v_match.away_team_id;
        END IF;

        IF p_winner_id IS NOT NULL AND p_winner_id != v_expected_winner_id THEN
            RETURN jsonb_build_object('success', false, 'error', 'WINNER_MISMATCH: Winner does not match regular time score');
        END IF;
        v_effective_winner_id := v_expected_winner_id;
    ELSE
        -- Tied score (p_home_score = p_away_score)
        IF v_is_knockout THEN
            IF p_home_penalties IS NULL OR p_away_penalties IS NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'PENALTIES_REQUIRED: Tied knockout match requires penalties');
            END IF;
            IF p_home_penalties = p_away_penalties THEN
                RETURN jsonb_build_object('success', false, 'error', 'PENALTIES_TIED: Penalties cannot be tied in knockout match');
            END IF;

            IF p_home_penalties > p_away_penalties THEN
                v_expected_winner_id := v_match.home_team_id;
            ELSE
                v_expected_winner_id := v_match.away_team_id;
            END IF;

            IF p_winner_id IS NOT NULL AND p_winner_id != v_expected_winner_id THEN
                RETURN jsonb_build_object('success', false, 'error', 'WINNER_MISMATCH: Winner does not match penalty shootout result');
            END IF;
            v_effective_winner_id := v_expected_winner_id;
        ELSE
            -- Group stage / round-robin draw
            v_effective_winner_id := NULL;
            v_effective_winner_name := NULL;
        END IF;
    END IF;

    -- Winner must be one of the two participating teams
    IF v_effective_winner_id IS NOT NULL AND v_effective_winner_id NOT IN (v_match.home_team_id, v_match.away_team_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_WINNER: Winner must be one of the participating teams');
    END IF;

    -- Knockout matches require a winner
    IF v_is_knockout AND v_effective_winner_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'WINNER_REQUIRED: Knockout match requires a decisive winner');
    END IF;

    -- Resolve winner name if missing
    IF v_effective_winner_id IS NOT NULL AND (v_effective_winner_name IS NULL OR v_effective_winner_name = '') THEN
        IF v_effective_winner_id = v_match.home_team_id AND v_match.home_team_name IS NOT NULL THEN
            v_effective_winner_name := v_match.home_team_name;
        ELSIF v_effective_winner_id = v_match.away_team_id AND v_match.away_team_name IS NOT NULL THEN
            v_effective_winner_name := v_match.away_team_name;
        ELSE
            SELECT name INTO v_effective_winner_name FROM public.teams WHERE id = v_effective_winner_id;
        END IF;
    END IF;

    -- 5. Persist authoritative result
    UPDATE public.tournament_matches
    SET 
        home_score = p_home_score,
        away_score = p_away_score,
        home_penalties = p_home_penalties,
        away_penalties = p_away_penalties,
        winner_id = v_effective_winner_id,
        status = 'completed',
        is_completed = true,
        result_status = 'confirmed',
        goal_details = COALESCE(p_goal_details, '[]'::jsonb),
        updated_at = v_now
    WHERE id = p_match_id;

    -- 6. Advance winner to next match if applicable
    IF v_match.next_match_id IS NOT NULL AND v_effective_winner_id IS NOT NULL THEN
        IF (v_match.match_index % 2 = 0) THEN
            UPDATE public.tournament_matches
            SET home_team_id = v_effective_winner_id,
                home_team_name = v_effective_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        ELSE
            UPDATE public.tournament_matches
            SET away_team_id = v_effective_winner_id,
                away_team_name = v_effective_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'match_id', p_match_id,
        'winner_id', v_effective_winner_id,
        'status', 'completed',
        'result_status', 'confirmed'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_match_result_and_advance_atomic(UUID, INT, INT, INT, INT, UUID, TEXT, JSONB) TO authenticated, service_role;


-- 2. get_championship_standings
CREATE OR REPLACE FUNCTION public.get_championship_standings(p_championship_id uuid, p_group_name text DEFAULT NULL::text)
 RETURNS TABLE(team_id uuid, team_name text, played bigint, won bigint, drawn bigint, lost bigint, goals_for bigint, goals_against bigint, goal_difference bigint, points bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH group_teams AS (
    SELECT DISTINCT
      t.id AS t_id,
      t.name AS t_name
    FROM public.tournament_matches m
    JOIN public.teams t ON (t.id = m.home_team_id OR t.id = m.away_team_id)
    WHERE m.championship_id = p_championship_id
      AND (p_group_name IS NULL OR m.group_name = p_group_name)
      AND (m.stage = 'group_stage' OR m.stage = 'league')
    
    UNION
    
    SELECT cr.team_id AS t_id, t.name AS t_name
    FROM public.championship_rosters cr
    JOIN public.teams t ON t.id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND p_group_name IS NULL
  ),
  match_results AS (
    SELECT
      m.home_team_id AS t_id,
      1 AS p,
      CASE WHEN m.home_score > m.away_score THEN 1 ELSE 0 END AS w,
      CASE WHEN m.home_score = m.away_score THEN 1 ELSE 0 END AS d,
      CASE WHEN m.home_score < m.away_score THEN 1 ELSE 0 END AS l,
      COALESCE(m.home_score, 0) AS gf,
      COALESCE(m.away_score, 0) AS ga,
      CASE
        WHEN m.home_score > m.away_score THEN 3
        WHEN m.home_score = m.away_score THEN 1
        ELSE 0
      END AS pts
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
      AND m.status = 'completed'
      AND COALESCE(m.result_status, 'confirmed') IN ('confirmed', 'locked')
      AND (p_group_name IS NULL OR m.group_name = p_group_name)

    UNION ALL

    SELECT
      m.away_team_id AS t_id,
      1 AS p,
      CASE WHEN m.away_score > m.home_score THEN 1 ELSE 0 END AS w,
      CASE WHEN m.away_score = m.home_score THEN 1 ELSE 0 END AS d,
      CASE WHEN m.away_score < m.home_score THEN 1 ELSE 0 END AS l,
      COALESCE(m.away_score, 0) AS gf,
      COALESCE(m.away_score, 0) AS ga,
      CASE
        WHEN m.away_score > m.home_score THEN 3
        WHEN m.away_score = m.home_score THEN 1
        ELSE 0
      END AS pts
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
      AND m.status = 'completed'
      AND COALESCE(m.result_status, 'confirmed') IN ('confirmed', 'locked')
      AND (p_group_name IS NULL OR m.group_name = p_group_name)
  )
  SELECT
    gt.t_id AS team_id,
    MAX(gt.t_name) AS team_name,
    COALESCE(SUM(r.p), 0) AS played,
    COALESCE(SUM(r.w), 0) AS won,
    COALESCE(SUM(r.d), 0) AS drawn,
    COALESCE(SUM(r.l), 0) AS lost,
    COALESCE(SUM(r.gf), 0) AS goals_for,
    COALESCE(SUM(r.ga), 0) AS goals_against,
    COALESCE(SUM(r.gf) - SUM(r.ga), 0) AS goal_difference,
    COALESCE(SUM(r.pts), 0) AS points
  FROM group_teams gt
  LEFT JOIN match_results r ON r.t_id = gt.t_id
  GROUP BY gt.t_id
  ORDER BY points DESC, goal_difference DESC, goals_for DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_championship_standings(uuid, text) TO authenticated, service_role, anon;


-- 3. crown_tournament_champion_atomic
CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(
  p_championship_id UUID,
  p_champion_team_id UUID,
  p_champion_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_role TEXT;
  v_team_name TEXT;
  v_prize NUMERIC;
  v_trophy_title TEXT;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_member RECORD;
  v_roster_id UUID;
  v_is_frozen BOOLEAN := false;
  v_awarded INT := 0;
  v_final_match RECORD;
  v_top_league_team_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_champ.owner_id IS DISTINCT FROM auth.uid() AND coalesce(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 1. Immutable Champion Check: Once completed, champion CANNOT be changed
  IF v_champ.status = 'completed' THEN
    IF v_champ.champion_team_id = p_champion_team_id THEN
      RETURN jsonb_build_object('success', true, 'already_crowned', true, 'champion_team_id', p_champion_team_id);
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'championship_already_completed_with_different_champion');
    END IF;
  END IF;

  IF v_champ.status != 'ongoing' THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_ongoing');
  END IF;

  -- 2. Team Must Be Confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.championship_registrations
    WHERE championship_id = p_championship_id
      AND team_id = p_champion_team_id
      AND registration_status = 'confirmed'
  ) AND NOT (p_champion_team_id::TEXT = ANY(coalesce(v_champ.paid_teams, ARRAY[]::TEXT[]))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'champion_team_not_confirmed');
  END IF;

  -- 3. Verify Final Match Result / Standings SSOT
  -- Find final match if one exists (knockout / cup / groups bracket)
  SELECT * INTO v_final_match
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id
    AND round_index = 0
    AND next_match_id IS NULL
  LIMIT 1;

  IF FOUND THEN
    -- Final match exists: must be completed, authoritative, and winner must match champion!
    IF v_final_match.status != 'completed' OR COALESCE(v_final_match.result_status, 'confirmed') NOT IN ('confirmed', 'locked') THEN
      RETURN jsonb_build_object('success', false, 'error', 'FINAL_MATCH_NOT_COMPLETED: Final match must be completed before crowning');
    END IF;
    IF v_final_match.winner_id IS NULL OR v_final_match.winner_id != p_champion_team_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'CHAMPION_IS_NOT_FINAL_WINNER: Crowned team must be the winner of the final match');
    END IF;
  ELSE
    -- If no bracket final match (round-robin league), verify all matches are completed and team is 1st in standings
    IF EXISTS (
      SELECT 1 FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND status != 'completed'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'MATCHES_NOT_COMPLETED: All league matches must be completed before crowning');
    END IF;

    SELECT team_id INTO v_top_league_team_id
    FROM public.get_championship_standings(p_championship_id)
    LIMIT 1;

    IF v_top_league_team_id IS DISTINCT FROM p_champion_team_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'CHAMPION_MUST_BE_LEAGUE_LEADER: Champion must finish 1st in league standings');
    END IF;
  END IF;

  -- 4. Server Team Name is SSOT (Server Value Always Wins, client param ignored)
  SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  v_prize := coalesce(nullif(v_champ.prize_pool, 0), v_champ.grand_prize, 0);
  v_trophy_title := 'بطل بطولة ' || coalesce(v_champ.name, 'VSP');

  -- 5. Award Player Trophies Strictly to the Frozen Championship Roster (is_frozen = true)
  SELECT id, coalesce(is_frozen, false) INTO v_roster_id, v_is_frozen
  FROM public.championship_rosters
  WHERE championship_id = p_championship_id AND team_id = p_champion_team_id;

  IF v_roster_id IS NULL OR v_is_frozen IS NOT TRUE OR NOT EXISTS (
    SELECT 1 FROM public.championship_roster_players WHERE roster_id = v_roster_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FROZEN_ROSTER_REQUIRED');
  END IF;

  -- 6. Atomically Complete Championship
  UPDATE public.championships
  SET status = 'completed',
      champion_team_id = p_champion_team_id,
      champion_team_name = v_team_name,
      updated_at = v_now
  WHERE id = p_championship_id;

  -- 7. Distribute trophies to frozen roster players
  FOR v_member IN
    SELECT player_id AS user_id FROM public.championship_roster_players WHERE roster_id = v_roster_id
  LOOP
    IF v_member.user_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.player_trophies
        WHERE user_id = v_member.user_id AND championship_id = p_championship_id
      ) THEN
        INSERT INTO public.player_trophies(id, user_id, championship_id, title, prize_won, created_at)
        VALUES (gen_random_uuid(), v_member.user_id, p_championship_id, v_trophy_title, v_prize, v_now);
        v_awarded := v_awarded + 1;
      END IF;
    END IF;
  END LOOP;

  -- 8. Team Trophy & Prize
  UPDATE public.teams
  SET championships_won = coalesce(championships_won, 0) + 1,
      points = coalesce(points, 0) + 100,
      unlocked_badges = CASE
        WHEN 'cup_winner' = ANY(coalesce(unlocked_badges, ARRAY[]::TEXT[])) THEN unlocked_badges
        ELSE array_append(coalesce(unlocked_badges, ARRAY[]::TEXT[]), 'cup_winner')
      END,
      updated_at = v_now
  WHERE id = p_champion_team_id;

  RETURN jsonb_build_object(
    'success', true,
    'champion_team_id', p_champion_team_id,
    'champion_team_name', v_team_name,
    'players_awarded', v_awarded,
    'prize_awarded', v_prize
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) TO authenticated, service_role;


-- 4. transition_championship_status_atomic
CREATE OR REPLACE FUNCTION public.transition_championship_status_atomic(
  p_championship_id uuid,
  p_new_status      text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_champ         RECORD;
  v_user_id       UUID := auth.uid();
  v_is_owner      BOOLEAN;
  v_is_admin      BOOLEAN;
  v_matches_count INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  v_is_owner := (v_champ.owner_id = v_user_id);
  SELECT EXISTS(
    SELECT 1 FROM public.users
    WHERE id = v_user_id AND role IN ('admin','co_founder','super_admin','cofounder')
  ) INTO v_is_admin;

  IF NOT v_is_owner AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: only owner or admin can transition championship status';
  END IF;

  IF p_new_status = 'cancelled' THEN
    RAISE EXCEPTION 'Cancellation must go through cancel_championship_atomic';
  END IF;

  IF v_champ.status = p_new_status THEN
    RETURN jsonb_build_object('success', true, 'status', p_new_status, 'message', 'Already in requested status');
  END IF;

  -- Transition Guard:
  -- open -> ongoing: MUST have fixtures generated
  IF v_champ.status = 'open' AND p_new_status = 'ongoing' THEN
    SELECT COUNT(*) INTO v_matches_count
    FROM public.tournament_matches
    WHERE championship_id = p_championship_id;

    IF v_matches_count = 0 THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to ongoing without generated fixtures';
    END IF;

  -- ongoing -> completed: STRICT COMPLETION GUARD
  -- Cannot complete without crowning a champion and completing all matches
  ELSIF v_champ.status = 'ongoing' AND p_new_status = 'completed' THEN
    IF v_champ.champion_team_id IS NULL THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to completed without crowning champion via crown_tournament_champion_atomic';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND status != 'completed'
    ) THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to completed while there are uncompleted matches';
    END IF;

  ELSE
    RAISE EXCEPTION 'INVALID_TRANSITION: Cannot transition championship from % to %',
      v_champ.status, p_new_status;
  END IF;

  UPDATE public.championships
  SET status     = p_new_status,
      updated_at = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_championship_status_atomic(uuid, text) TO authenticated, service_role;
