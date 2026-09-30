-- ==============================================================================
-- Migration: 20260930050000_vsp_team_league_ssot_and_creator_authority.sql
-- Description:
--   1. Enforce Creator Sole Authority: No system auto-confirm. Creator confirms all results.
--   2. Enforce Single State Machine: scheduled -> awaiting_submissions -> awaiting_confirmation / disputed -> confirmed -> locked.
--   3. Server-side hard enforcement of 15-minute lock on confirmation.
--   4. True Circle/Berger Round-Robin Fixtures generation (every team plays once per round, support 4-8 teams with bye for odd counts).
--   5. Pure Standings with rigorous Head-to-Head (H2H) tie-breaking and ZERO goals.
--   6. Security tightening: Revoke anon execution, require authenticated, search_path isolation.
--   7. Drop obsolete legacy functions.
-- ==============================================================================

-- 1. Drop obsolete legacy and updated RPCs before re-creating
DROP FUNCTION IF EXISTS public.record_league_match_result(UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS public.record_league_match_result(UUID, INTEGER, INTEGER, UUID);
DROP FUNCTION IF EXISTS public.resolve_team_league_dispute(UUID, TEXT);
DROP FUNCTION IF EXISTS public.generate_team_league_fixtures(UUID);
DROP FUNCTION IF EXISTS public.get_team_league_standings(UUID);
DROP FUNCTION IF EXISTS public.get_team_active_league(UUID);
DROP FUNCTION IF EXISTS public.submit_team_league_match_result(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.confirm_team_league_match_result(UUID, TEXT);

-- 2. Update tournament_matches check constraints and migrate status
ALTER TABLE public.tournament_matches DROP CONSTRAINT IF EXISTS chk_tm_result_status;

-- Migrate any old statuses to the new single state machine
UPDATE public.tournament_matches
SET result_status = CASE
  WHEN result_status IN ('pending', 'awaiting_result') THEN 'scheduled'
  WHEN result_status = 'result_one_side' THEN 'awaiting_submissions'
  WHEN result_status IS NULL THEN 'scheduled'
  ELSE result_status
END
WHERE championship_id IN (SELECT id FROM public.championships WHERE type = 'team_league');

ALTER TABLE public.tournament_matches
ADD CONSTRAINT chk_tm_result_status
CHECK (result_status IN (
  'scheduled',
  'awaiting_submissions',
  'awaiting_confirmation',
  'disputed',
  'confirmed',
  'locked'
));

-- 3. Canonical Circle/Berger Round-Robin Fixture Generator
CREATE OR REPLACE FUNCTION public.generate_team_league_fixtures(p_championship_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type TEXT;
  v_teams UUID[];
  v_team_count INTEGER;
  v_virtual_count INTEGER;
  v_rounds_count INTEGER;
  v_matches_per_round INTEGER;
  v_interval_days INTEGER;
  v_start_date DATE;
  v_round_idx INTEGER;
  v_match_idx INTEGER;
  v_t1_idx INTEGER;
  v_t2_idx INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_bye_dummy UUID := '00000000-0000-0000-0000-000000000000'::UUID;
BEGIN
  -- Verify championship exists and is team_league
  SELECT type, COALESCE(match_interval_days, 7), COALESCE(start_date, CURRENT_DATE)
  INTO v_type, v_interval_days, v_start_date
  FROM public.championships
  WHERE id = p_championship_id;

  IF v_type IS NULL OR v_type != 'team_league' THEN
    RAISE EXCEPTION 'Championship is not a valid team_league';
  END IF;

  -- Delete existing fixtures if unplayed
  DELETE FROM public.tournament_matches
  WHERE championship_id = p_championship_id
    AND (result_status IS NULL OR result_status = 'scheduled')
    AND result_confirmed_at IS NULL;

  -- Fetch participating teams sorted deterministically
  SELECT ARRAY_AGG(team_id ORDER BY joined_at ASC, id ASC)
  INTO v_teams
  FROM public.championship_participants
  WHERE championship_id = p_championship_id;

  v_team_count := COALESCE(ARRAY_LENGTH(v_teams, 1), 0);
  IF v_team_count < 4 OR v_team_count > 8 THEN
    RAISE EXCEPTION 'Team league requires between 4 and 8 teams (current: %)', v_team_count;
  END IF;

  -- If odd count, append dummy team for BYE scheduling
  IF v_team_count % 2 != 0 THEN
    v_teams := v_teams || v_bye_dummy;
    v_virtual_count := v_team_count + 1;
  ELSE
    v_virtual_count := v_team_count;
  END IF;

  v_rounds_count := v_virtual_count - 1;
  v_matches_per_round := v_virtual_count / 2;

  -- Generate fixtures using standard Circle/Berger rotation algorithm
  -- Fixed team at index (v_virtual_count - 1)
  -- Rotating remaining (v_virtual_count - 1) teams
  FOR v_round_idx IN 0..(v_rounds_count - 1) LOOP
    FOR v_match_idx IN 0..(v_matches_per_round - 1) LOOP
      IF v_match_idx = 0 THEN
        v_t1_idx := v_virtual_count - 1;
        v_t2_idx := (v_round_idx) % (v_virtual_count - 1);
      ELSE
        v_t1_idx := (v_round_idx + v_match_idx) % (v_virtual_count - 1);
        v_t2_idx := (v_round_idx - v_match_idx + (v_virtual_count - 1)) % (v_virtual_count - 1);
      END IF;

      -- 1-based index into v_teams array
      v_home_id := v_teams[v_t1_idx + 1];
      v_away_id := v_teams[v_t2_idx + 1];

      -- Alternate home/away between rounds for balance
      IF v_round_idx % 2 = 1 AND v_match_idx = 0 THEN
        DECLARE
          v_temp UUID := v_home_id;
        BEGIN
          v_home_id := v_away_id;
          v_away_id := v_temp;
        END;
      END IF;

      -- Skip BYE matches
      IF v_home_id = v_bye_dummy OR v_away_id = v_bye_dummy THEN
        CONTINUE;
      END IF;

      INSERT INTO public.tournament_matches (
        championship_id,
        stage,
        week_number,
        match_index,
        home_team_id,
        away_team_id,
        match_day,
        status,
        result_status,
        is_completed
      ) VALUES (
        p_championship_id,
        'league',
        v_round_idx + 1,
        v_match_idx,
        v_home_id,
        v_away_id,
        v_start_date + ((v_round_idx * v_interval_days) * interval '1 day'),
        'scheduled',
        'scheduled',
        false
      );
    END LOOP;
  END LOOP;
END;
$$;

-- 4. Result Submission RPC: Team Captain submits perspective
-- Rule: Does NOT auto-confirm. If matching -> awaiting_confirmation. If conflicting -> disputed.
CREATE OR REPLACE FUNCTION public.submit_team_league_match_result(
  p_match_id UUID,
  p_team_id UUID,
  p_result TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_match RECORD;
  v_champ RECORD;
  v_user_id UUID := auth.uid();
  v_is_captain BOOLEAN := false;
  v_existing_sub RECORD;
  v_opp_sub RECORD;
  v_new_status TEXT;
  v_reconciled_outcome TEXT := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_result NOT IN ('win', 'draw', 'loss') THEN
    RAISE EXCEPTION 'Invalid result outcome. Must be win, draw, or loss.';
  END IF;

  -- 1. Fetch match & championship
  SELECT tm.*, c.type AS champ_type, c.creator_id
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.champ_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  -- 2. Verify team is part of this match
  IF p_team_id != v_match.home_team_id AND p_team_id != v_match.away_team_id THEN
    RAISE EXCEPTION 'Team does not belong to this match';
  END IF;

  -- 3. Verify user is captain or player of the team
  SELECT (captain_id = v_user_id) INTO v_is_captain
  FROM public.teams
  WHERE id = p_team_id;

  IF NOT v_is_captain THEN
    -- Check if user is an approved player
    IF NOT EXISTS (
      SELECT 1 FROM public.players 
      WHERE team_id = p_team_id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'You are not authorized to submit results for this team';
    END IF;
  END IF;

  -- 4. Server-Side 15-minute lock check:
  -- If already confirmed and 15 mins passed, or already locked -> HARD BLOCK
  IF v_match.result_status = 'locked' OR 
     (v_match.result_confirmed_at IS NOT NULL AND v_match.result_confirmed_at + interval '15 minutes' < clock_timestamp()) THEN
    -- Enforce lock in DB
    UPDATE public.tournament_matches 
    SET result_status = 'locked', result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;
    
    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- 5. Upsert submission for this team
  INSERT INTO public.team_league_match_submissions (
    match_id,
    team_id,
    submitted_by,
    result,
    submitted_at,
    submission_version
  ) VALUES (
    p_match_id,
    p_team_id,
    v_user_id,
    p_result,
    clock_timestamp(),
    1
  )
  ON CONFLICT (match_id, team_id) DO UPDATE SET
    submitted_by = EXCLUDED.submitted_by,
    result = EXCLUDED.result,
    submitted_at = clock_timestamp(),
    submission_version = public.team_league_match_submissions.submission_version + 1;

  -- 6. Check opponent submission
  SELECT * INTO v_opp_sub
  FROM public.team_league_match_submissions
  WHERE match_id = p_match_id AND team_id != p_team_id;

  IF v_opp_sub.id IS NULL THEN
    -- Only one team submitted so far
    v_new_status := 'awaiting_submissions';
  ELSE
    -- Both teams submitted!
    -- Check reconciliation between home and away perspectives
    DECLARE
      v_home_res TEXT;
      v_away_res TEXT;
    BEGIN
      IF p_team_id = v_match.home_team_id THEN
        v_home_res := p_result;
        v_away_res := v_opp_sub.result;
      ELSE
        v_home_res := v_opp_sub.result;
        v_away_res := p_result;
      END IF;

      IF (v_home_res = 'win' AND v_away_res = 'loss') THEN
        v_reconciled_outcome := 'home_win';
        v_new_status := 'awaiting_confirmation';
      ELSIF (v_home_res = 'loss' AND v_away_res = 'win') THEN
        v_reconciled_outcome := 'away_win';
        v_new_status := 'awaiting_confirmation';
      ELSIF (v_home_res = 'draw' AND v_away_res = 'draw') THEN
        v_reconciled_outcome := 'draw';
        v_new_status := 'awaiting_confirmation';
      ELSE
        -- Dispute / Conflict
        v_reconciled_outcome := NULL;
        v_new_status := 'disputed';
      END IF;
    END;
  END IF;

  -- 7. Update match state (NO AUTO CONFIRM: waiting for Creator!)
  UPDATE public.tournament_matches
  SET
    result_status = v_new_status,
    confirmed_outcome = CASE WHEN v_new_status = 'awaiting_confirmation' THEN v_reconciled_outcome ELSE NULL END,
    dispute_created_at = CASE WHEN v_new_status = 'disputed' THEN COALESCE(dispute_created_at, clock_timestamp()) ELSE NULL END
  WHERE id = p_match_id;

  -- 8. Audit log
  INSERT INTO public.team_league_result_audits (
    match_id,
    championship_id,
    team_id,
    actor_id,
    action,
    payload
  ) VALUES (
    p_match_id,
    v_match.championship_id,
    p_team_id,
    v_user_id,
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

-- 5. Creator Sole Authority Confirmation RPC: League Creator confirms or resolves match
-- Can be called when status is awaiting_confirmation or disputed, or within 15 minutes of confirmed.
CREATE OR REPLACE FUNCTION public.confirm_team_league_match_result(
  p_match_id UUID,
  p_outcome TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_match RECORD;
  v_champ RECORD;
  v_user_id UUID := auth.uid();
  v_winner_id UUID := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_outcome NOT IN ('home_win', 'draw', 'away_win') THEN
    RAISE EXCEPTION 'Invalid outcome. Must be home_win, draw, or away_win';
  END IF;

  -- 1. Fetch match and championship
  SELECT tm.*, c.creator_id, c.type AS champ_type
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.champ_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  -- 2. Strictly check creator authority
  IF v_match.creator_id != v_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only the league creator can confirm or resolve match results';
  END IF;

  -- 3. Server-Side 15-minute lock check:
  IF v_match.result_status = 'locked' OR 
     (v_match.result_confirmed_at IS NOT NULL AND v_match.result_confirmed_at + interval '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches 
    SET result_status = 'locked', result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;
    
    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- 4. Calculate winner
  IF p_outcome = 'home_win' THEN
    v_winner_id := v_match.home_team_id;
  ELSIF p_outcome = 'away_win' THEN
    v_winner_id := v_match.away_team_id;
  ELSE
    v_winner_id := NULL;
  END IF;

  -- 5. Update match to 'confirmed' and start 15-minute timer
  UPDATE public.tournament_matches
  SET
    result_status = 'confirmed',
    confirmed_outcome = p_outcome,
    winner_id = v_winner_id,
    result_confirmed_at = COALESCE(result_confirmed_at, clock_timestamp()),
    dispute_resolved_at = CASE WHEN v_match.result_status = 'disputed' THEN clock_timestamp() ELSE dispute_resolved_at END,
    dispute_resolved_by = CASE WHEN v_match.result_status = 'disputed' THEN v_user_id ELSE dispute_resolved_by END,
    status = 'completed',
    is_completed = true
  WHERE id = p_match_id;

  -- 6. Audit log
  INSERT INTO public.team_league_result_audits (
    match_id,
    championship_id,
    actor_id,
    action,
    payload
  ) VALUES (
    p_match_id,
    v_match.championship_id,
    v_user_id,
    'creator_confirm_result',
    jsonb_build_object(
      'confirmed_outcome', p_outcome,
      'previous_status', v_match.result_status,
      'winner_id', v_winner_id
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

-- 6. Pure Standings RPC with Exact Head-to-Head (H2H) Tie-Breaker (No Goals)
CREATE OR REPLACE FUNCTION public.get_team_league_standings(p_championship_id UUID)
RETURNS TABLE (
  rank BIGINT,
  team_id UUID,
  team_name TEXT,
  team_logo_url TEXT,
  played INTEGER,
  won INTEGER,
  drawn INTEGER,
  lost INTEGER,
  points INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  WITH base_stats AS (
    SELECT 
      t.id AS b_team_id,
      t.name AS b_team_name,
      t.logo_url AS b_team_logo_url,
      COALESCE(COUNT(m.id) FILTER (WHERE m.result_status IN ('confirmed', 'locked')), 0)::INTEGER AS b_played,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
          AND (
            (m.home_team_id = t.id AND m.confirmed_outcome = 'home_win') OR
            (m.away_team_id = t.id AND m.confirmed_outcome = 'away_win')
          )
      ), 0)::INTEGER AS b_won,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
          AND m.confirmed_outcome = 'draw'
      ), 0)::INTEGER AS b_drawn,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
          AND (
            (m.home_team_id = t.id AND m.confirmed_outcome = 'away_win') OR
            (m.away_team_id = t.id AND m.confirmed_outcome = 'home_win')
          )
      ), 0)::INTEGER AS b_lost
    FROM public.championship_participants cp
    JOIN public.teams t ON t.id = cp.team_id
    LEFT JOIN public.tournament_matches m 
      ON m.championship_id = p_championship_id 
      AND (m.home_team_id = t.id OR m.away_team_id = t.id)
    WHERE cp.championship_id = p_championship_id
    GROUP BY t.id, t.name, t.logo_url
  ),
  with_points AS (
    SELECT 
      s.b_team_id,
      s.b_team_name,
      s.b_team_logo_url,
      s.b_played,
      s.b_won,
      s.b_drawn,
      s.b_lost,
      ((s.b_won * 3) + (s.b_drawn * 1))::INTEGER AS b_points
    FROM base_stats s
  ),
  -- Calculate Head-to-Head points exclusively against teams that share the exact same total points
  with_h2h AS (
    SELECT
      p.b_team_id,
      p.b_team_name,
      p.b_team_logo_url,
      p.b_played,
      p.b_won,
      p.b_drawn,
      p.b_lost,
      p.b_points,
      COALESCE(
        SUM(
          CASE 
            WHEN (m.home_team_id = p.b_team_id AND m.confirmed_outcome = 'home_win') OR
                 (m.away_team_id = p.b_team_id AND m.confirmed_outcome = 'away_win') THEN 3
            WHEN m.confirmed_outcome = 'draw' THEN 1
            ELSE 0
          END
        ), 0
      )::INTEGER AS h2h_points
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
      ORDER BY 
        h.b_points DESC,
        h.h2h_points DESC,
        h.b_won DESC,
        h.b_team_name ASC,
        h.b_team_id ASC
    ) AS rank,
    h.b_team_id AS team_id,
    h.b_team_name AS team_name,
    h.b_team_logo_url AS team_logo_url,
    h.b_played AS played,
    h.b_won AS won,
    h.b_drawn AS drawn,
    h.b_lost AS lost,
    h.b_points AS points
  FROM with_h2h h
  ORDER BY rank ASC;
END;
$$;

-- 7. Updated get_team_active_league RPC with Single State Machine & Submissions
CREATE OR REPLACE FUNCTION public.get_team_active_league(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_matches JSONB;
  v_standings JSONB;
  v_teams JSONB;
  v_user_id UUID := auth.uid();
  v_is_creator BOOLEAN := false;
BEGIN
  -- 1. Find the active championship for this team
  SELECT c.*
  INTO v_champ
  FROM public.championships c
  JOIN public.championship_participants cp ON cp.championship_id = c.id
  WHERE cp.team_id = p_team_id
    AND c.type = 'team_league'
    AND c.status IN ('draft', 'ongoing', 'active', 'published')
  ORDER BY c.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_is_creator := (v_champ.creator_id = v_user_id);

  -- 2. Fetch participating teams
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'name', t.name,
      'logo_url', t.logo_url,
      'captain_id', t.captain_id,
      'joined_at', cp.joined_at,
      'prepaid_by_creator', COALESCE(cp.prepaid_by_creator, false)
    ) ORDER BY cp.joined_at ASC
  )
  INTO v_teams
  FROM public.championship_participants cp
  JOIN public.teams t ON t.id = cp.team_id
  WHERE cp.championship_id = v_champ.id;

  -- 3. Fetch matches with both team submissions and 15m lock check
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'championship_id', m.championship_id,
      'week_number', m.week_number,
      'match_index', m.match_index,
      'stage', m.stage,
      'home_team_id', m.home_team_id,
      'home_team_name', ht.name,
      'away_team_id', m.away_team_id,
      'away_team_name', at.name,
      'confirmed_outcome', m.confirmed_outcome,
      'result_status', CASE 
        WHEN m.result_status = 'confirmed' AND m.result_confirmed_at IS NOT NULL AND m.result_confirmed_at + interval '15 minutes' < clock_timestamp() THEN 'locked'
        ELSE COALESCE(m.result_status, 'scheduled')
      END,
      'status', m.status,
      'is_completed', (m.result_status IN ('confirmed', 'locked') OR (m.result_confirmed_at IS NOT NULL)),
      'result_confirmed_at', m.result_confirmed_at,
      'result_locked_at', m.result_locked_at,
      'dispute_created_at', m.dispute_created_at,
      'match_day', m.match_day,
      'booking_id', m.booking_id,
      'my_team_submission', (
        SELECT sub.result 
        FROM public.team_league_match_submissions sub 
        WHERE sub.match_id = m.id AND sub.team_id = p_team_id
      ),
      'opponent_team_submission', (
        SELECT sub.result 
        FROM public.team_league_match_submissions sub 
        WHERE sub.match_id = m.id AND sub.team_id != p_team_id
      ),
      'home_submission', (
        SELECT sub.result 
        FROM public.team_league_match_submissions sub 
        WHERE sub.match_id = m.id AND sub.team_id = m.home_team_id
      ),
      'away_submission', (
        SELECT sub.result 
        FROM public.team_league_match_submissions sub 
        WHERE sub.match_id = m.id AND sub.team_id = m.away_team_id
      )
    ) ORDER BY m.week_number ASC, m.match_index ASC
  )
  INTO v_matches
  FROM public.tournament_matches m
  JOIN public.teams ht ON ht.id = m.home_team_id
  JOIN public.teams at ON at.id = m.away_team_id
  WHERE m.championship_id = v_champ.id;

  -- 4. Fetch Pure Standings
  SELECT jsonb_agg(
    jsonb_build_object(
      'rank', s.rank,
      'team_id', s.team_id,
      'team_name', s.team_name,
      'team_logo_url', s.team_logo_url,
      'played', s.played,
      'won', s.won,
      'drawn', s.drawn,
      'lost', s.lost,
      'points', s.points
    ) ORDER BY s.rank ASC
  )
  INTO v_standings
  FROM public.get_team_league_standings(v_champ.id) s;

  RETURN jsonb_build_object(
    'id', v_champ.id,
    'name', v_champ.name,
    'type', v_champ.type,
    'status', v_champ.status,
    'max_teams', v_champ.max_teams,
    'current_teams_count', COALESCE(jsonb_array_length(v_teams), 0),
    'match_interval_days', COALESCE(v_champ.match_interval_days, 7),
    'paid_by_creator_count', COALESCE(v_champ.paid_by_creator_count, 1),
    'is_creator', v_is_creator,
    'governorate', v_champ.governorate,
    'teams', COALESCE(v_teams, '[]'::jsonb),
    'matches', COALESCE(v_matches, '[]'::jsonb),
    'standings', COALESCE(v_standings, '[]'::jsonb)
  );
END;
$$;

-- 8. Security hardening: Revoke anon & public, Grant authenticated
REVOKE ALL ON FUNCTION public.generate_team_league_fixtures(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_team_league_fixtures(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_team_league_match_result(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_team_league_match_result(UUID, UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.confirm_team_league_match_result(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_team_league_match_result(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_team_league_standings(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_league_standings(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.get_team_active_league(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_active_league(UUID) TO authenticated;
