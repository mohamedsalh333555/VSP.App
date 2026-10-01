-- ==============================================================================
-- Migration: 20261002030000_tournament_groups_type_and_completion_guard_ssot.sql
-- Purpose:
--   1. Harden crown_tournament_champion_atomic:
--      - Strictly type-based branching: type = 'league' vs all other tournament types.
--      - Disallow type = 'groups' from crowning directly from group stage standings.
--      - Require groups tournaments to advance to knockout bracket and complete the final.
--      - Knockout & groups require actual final match completed + confirmed and winner matching champion.
--   2. Harden transition_championship_status_atomic:
--      - Guarantees ongoing -> completed enforces champion_team_id IS NOT NULL
--        and all matches completed + result_status IN ('confirmed', 'locked').
--      - Returns both 'new_status' and 'status' for backward/forward compatibility.
--   3. Reconciles migration history into supabase_migrations.schema_migrations.
-- ==============================================================================

-- 1. crown_tournament_champion_atomic
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
  v_is_owner BOOLEAN;
  v_is_admin BOOLEAN;
  v_caller_role TEXT;
  v_now TIMESTAMPTZ := timezone('utc'::text, now());
  v_team_name TEXT;
  v_prize NUMERIC;
  v_trophy_title TEXT;
  v_roster_id UUID;
  v_is_frozen BOOLEAN;
  v_member RECORD;
  v_awarded INT := 0;
  v_final_match RECORD;
  v_top_league_team_id UUID;
BEGIN
  -- 1. Lock and fetch championship
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- Idempotency check: if already completed with this exact champion, return success
  IF v_champ.status = 'completed' AND v_champ.champion_team_id = p_champion_team_id THEN
    RETURN jsonb_build_object(
      'success', true,
      'champion_team_id', v_champ.champion_team_id,
      'champion_team_name', v_champ.champion_team_name,
      'message', 'already_crowned'
    );
  END IF;

  IF v_champ.status = 'completed' AND v_champ.champion_team_id IS DISTINCT FROM p_champion_team_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_COMPLETED: Championship is already completed with a different champion');
  END IF;

  -- Authorization check
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    v_is_owner := (v_champ.owner_id IS NOT DISTINCT FROM auth.uid());
    IF NOT v_is_owner THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      v_is_admin := (COALESCE(v_caller_role, '') IN ('admin', 'co_founder', 'cofounder', 'super_admin'));
      IF NOT v_is_admin THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can crown tournament champion');
      END IF;
    END IF;
  END IF;

  -- 2. Verify team registered and paid/confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.championship_registrations
    WHERE championship_id = p_championship_id
      AND team_id = p_champion_team_id
      AND registration_status = 'confirmed'
  ) AND NOT (p_champion_team_id::TEXT = ANY(coalesce(v_champ.paid_teams, ARRAY[]::TEXT[]))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'champion_team_not_confirmed');
  END IF;

  -- 3. Verify Championship Structure and Winner SSOT (STRICTLY BY CHAMPIONSHIP TYPE)
  IF COALESCE(v_champ.type, '') = 'league' THEN
    -- =========================================================
    -- REGULAR LEAGUE / ROUND-ROBIN CHAMPIONSHIP
    -- =========================================================
    -- 1. All league matches must be completed and authoritative (confirmed/locked)
    IF EXISTS (
      SELECT 1 FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND (status != 'completed' OR COALESCE(result_status, '') NOT IN ('confirmed', 'locked'))
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'MATCHES_NOT_COMPLETED: All league matches must be completed and confirmed before crowning');
    END IF;

    -- 2. Determine champion from authoritative standings (1st place)
    SELECT s.team_id INTO v_top_league_team_id
    FROM public.get_championship_standings(p_championship_id, NULL) s
    LIMIT 1;

    IF v_top_league_team_id IS NULL OR v_top_league_team_id != p_champion_team_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'CHAMPION_MUST_BE_LEAGUE_LEADER: Champion must finish 1st in league standings');
    END IF;

  ELSE
    -- =========================================================
    -- GROUPS, CUP, OR KNOCKOUT TOURNAMENTS
    -- =========================================================
    -- For 'groups', 'cup', or 'knockout', crowning MUST happen via the actual knockout final!
    -- Group-stage leader can NEVER be crowned directly without advancing through knockout.
    SELECT * INTO v_final_match
    FROM public.tournament_matches
    WHERE championship_id = p_championship_id
      AND round_index = 0
      AND next_match_id IS NULL
      AND stage IN ('final', 'knockout', 'cup')
    ORDER BY id
    LIMIT 1;

    IF NOT FOUND THEN
      SELECT * INTO v_final_match
      FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND stage = 'final'
      LIMIT 1;
    END IF;

    IF NOT FOUND THEN
      IF COALESCE(v_champ.type, '') = 'groups' THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'FINAL_MATCH_NOT_FOUND: Groups tournament requires advancing to knockout bracket before crowning champion'
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'FINAL_MATCH_NOT_FOUND: Knockout tournament requires final match before crowning champion'
        );
      END IF;
    END IF;

    -- Final match must be completed, authoritative, and winner must match champion
    IF v_final_match.status != 'completed' OR COALESCE(v_final_match.result_status, '') NOT IN ('confirmed', 'locked') THEN
      RETURN jsonb_build_object('success', false, 'error', 'FINAL_MATCH_NOT_COMPLETED: Final match must be completed and confirmed before crowning');
    END IF;

    IF v_final_match.winner_id IS NULL OR v_final_match.winner_id != p_champion_team_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'CHAMPION_IS_NOT_FINAL_WINNER: Crowned team must be the winner of the final match');
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


-- 2. transition_championship_status_atomic
CREATE OR REPLACE FUNCTION public.transition_championship_status_atomic(
    p_championship_id UUID,
    p_new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_is_owner BOOLEAN;
  v_is_admin BOOLEAN;
  v_caller_role TEXT;
  v_matches_count INT;
BEGIN
  -- Validate target status value
  IF p_new_status NOT IN ('open', 'ongoing', 'completed', 'cancelled') THEN
    RAISE EXCEPTION 'INVALID_STATUS: Invalid championship status %', p_new_status;
  END IF;

  -- Lock and fetch championship
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  -- Authorization check
  v_is_owner := (v_champ.owner_id IS NOT DISTINCT FROM auth.uid());
  SELECT (
    COALESCE(auth.role(), '') = 'service_role' OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'cofounder', 'super_admin')
    )
  ) INTO v_is_admin;

  IF NOT v_is_owner AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: only owner or admin can transition championship status';
  END IF;

  IF p_new_status = 'cancelled' THEN
    RAISE EXCEPTION 'Cancellation must go through cancel_championship_atomic';
  END IF;

  IF v_champ.status = p_new_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', p_new_status,
      'new_status', p_new_status,
      'message', 'Already in requested status'
    );
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
  -- Cannot complete without crowning a champion and completing & confirming all matches
  ELSIF v_champ.status = 'ongoing' AND p_new_status = 'completed' THEN
    IF v_champ.champion_team_id IS NULL THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to completed without crowning champion via crown_tournament_champion_atomic';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND (status != 'completed' OR COALESCE(result_status, '') NOT IN ('confirmed', 'locked'))
    ) THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to completed while there are uncompleted or unconfirmed matches';
    END IF;

  ELSE
    RAISE EXCEPTION 'INVALID_TRANSITION: Cannot transition championship from % to %',
      v_champ.status, p_new_status;
  END IF;

  UPDATE public.championships
  SET status = p_new_status,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', p_championship_id,
    'previous_status', v_champ.status,
    'new_status', p_new_status,
    'status', p_new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_championship_status_atomic(UUID, TEXT) TO authenticated, service_role;

-- 3. Reconcile migration history into supabase_migrations.schema_migrations
INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
VALUES ('20261002030000', 'tournament_groups_type_and_completion_guard_ssot', ARRAY['tournament_groups_type_and_completion_guard_ssot'])
ON CONFLICT (version) DO NOTHING;
