-- ==============================================================================
-- Migration: 20261001033000_vsp_regular_tournament_format_server_authority.sql
-- Purpose:
--   Server-authoritative fixture generation for Regular Championship formats:
--     - Knockout / Cup
--     - Round-robin League
--     - Groups
--   Also restores the internal function required by start_championship_atomic,
--   adds group-to-knockout advancement, and centralizes match scheduling.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.generate_regular_league_fixtures_internal(p_championship_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_champ RECORD;
  v_team_ids UUID[];
  v_team_list UUID[];
  v_team_count INTEGER;
  v_virtual_count INTEGER;
  v_num_weeks INTEGER;
  v_matches_per_week INTEGER;
  v_week INTEGER;
  v_match INTEGER;
  v_home_idx INTEGER;
  v_away_idx INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_match_index INTEGER := 0;
  v_two_legs BOOLEAN := false;
  v_first_leg_weeks INTEGER;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_start_date DATE;
  v_result_count INTEGER := 0;
BEGIN
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'championship_not_found'; END IF;
  IF v_champ.template_type = 'team_league' OR v_champ.type <> 'league' THEN RAISE EXCEPTION 'wrong_tournament_format'; END IF;

  IF COALESCE(v_champ.entry_fee, 0) > 0 THEN
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[]) INTO v_team_ids
    FROM unnest(COALESCE(v_champ.paid_teams, '{}'::text[])) AS x;
  ELSE
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[]) INTO v_team_ids
    FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[])) AS x;
  END IF;

  v_team_count := COALESCE(array_length(v_team_ids, 1), 0);
  IF v_team_count < 2 THEN RAISE EXCEPTION 'insufficient_teams'; END IF;

  v_team_list := v_team_ids;
  IF v_team_count % 2 = 1 THEN v_team_list := v_team_list || NULL::uuid; END IF;

  v_virtual_count := array_length(v_team_list, 1);
  v_num_weeks := v_virtual_count - 1;
  v_matches_per_week := v_virtual_count / 2;
  v_two_legs := COALESCE(v_champ.is_two_legs, false);
  v_start_date := COALESCE(v_champ.start_date::date, CURRENT_DATE);

  DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;

  FOR v_week IN 0..(v_num_weeks - 1) LOOP
    FOR v_match IN 0..(v_matches_per_week - 1) LOOP
      v_home_idx := (v_week + v_match) % (v_virtual_count - 1);
      v_away_idx := (v_virtual_count - 1 - v_match + v_week) % (v_virtual_count - 1);
      IF v_match = 0 THEN v_away_idx := v_virtual_count - 1; END IF;

      v_home_id := v_team_list[v_home_idx + 1];
      v_away_id := v_team_list[v_away_idx + 1];

      IF v_home_id IS NOT NULL AND v_away_id IS NOT NULL THEN
        SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
        SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;

        INSERT INTO public.tournament_matches (
          championship_id, round_index, match_index, week_number, stage,
          home_team_id, home_team_name, away_team_id, away_team_name,
          match_day, status, result_status, is_completed, created_at, updated_at
        ) VALUES (
          p_championship_id, 0, v_match_index, v_week + 1, 'league',
          v_home_id, v_home_name, v_away_id, v_away_name,
          v_start_date + (v_week * COALESCE(v_champ.match_interval_days, 7)),
          'scheduled', 'scheduled', false, v_now, v_now
        );
        v_match_index := v_match_index + 1;
        v_result_count := v_result_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  IF v_two_legs THEN
    v_first_leg_weeks := v_num_weeks;
    FOR v_week IN 0..(v_first_leg_weeks - 1) LOOP
      FOR v_home_id, v_away_id, v_match IN
        SELECT home_team_id, away_team_id, match_index
        FROM public.tournament_matches
        WHERE championship_id = p_championship_id AND week_number = v_week + 1
        ORDER BY match_index
      LOOP
        SELECT name INTO v_home_name FROM public.teams WHERE id = v_away_id;
        SELECT name INTO v_away_name FROM public.teams WHERE id = v_home_id;

        INSERT INTO public.tournament_matches (
          championship_id, round_index, match_index, week_number, stage,
          home_team_id, home_team_name, away_team_id, away_team_name,
          match_day, status, result_status, is_completed, created_at, updated_at
        ) VALUES (
          p_championship_id, 0, v_match_index, v_week + v_first_leg_weeks + 1, 'league',
          v_away_id, v_home_name, v_home_id, v_away_name,
          v_start_date + ((v_week + v_first_leg_weeks) * COALESCE(v_champ.match_interval_days, 7)),
          'scheduled', 'scheduled', false, v_now, v_now
        );
        v_match_index := v_match_index + 1;
        v_result_count := v_result_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  RETURN v_result_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_regular_league_fixtures_atomic(p_championship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_count INTEGER;
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED'); END IF;
  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
  IF NOT EXISTS (
    SELECT 1 FROM public.championships c
    WHERE c.id = p_championship_id
      AND (c.owner_id = v_user_id OR COALESCE(v_role, '') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;

  v_count := public.generate_regular_league_fixtures_internal(p_championship_id);
  UPDATE public.championships
  SET registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id AND status = 'open';

  RETURN jsonb_build_object('success', true, 'format', 'league', 'matches_count', v_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_regular_group_fixtures_internal(p_championship_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_champ RECORD;
  v_team_ids UUID[];
  v_shuffled UUID[];
  v_team_count INTEGER;
  v_num_groups INTEGER;
  v_group_index INTEGER;
  v_group_name TEXT;
  v_group_team_ids UUID[];
  v_list UUID[];
  v_virtual_count INTEGER;
  v_num_weeks INTEGER;
  v_matches_per_week INTEGER;
  v_week INTEGER;
  v_match INTEGER;
  v_home_idx INTEGER;
  v_away_idx INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_match_index INTEGER := 0;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_start_date DATE;
  v_result_count INTEGER := 0;
BEGIN
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'championship_not_found'; END IF;
  IF v_champ.template_type = 'team_league' OR v_champ.type <> 'groups' THEN RAISE EXCEPTION 'wrong_tournament_format'; END IF;

  IF COALESCE(v_champ.entry_fee, 0) > 0 THEN
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[]) INTO v_team_ids
    FROM unnest(COALESCE(v_champ.paid_teams, '{}'::text[])) AS x;
  ELSE
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[]) INTO v_team_ids
    FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[])) AS x;
  END IF;

  v_team_count := COALESCE(array_length(v_team_ids, 1), 0);
  v_num_groups := GREATEST(2, LEAST(COALESCE(v_champ.number_of_groups, 2), 8));
  IF v_team_count < v_num_groups * 2 THEN RAISE EXCEPTION 'insufficient_teams_for_groups'; END IF;

  SELECT ARRAY_AGG(t.id ORDER BY random()) INTO v_shuffled
  FROM unnest(v_team_ids) AS x(team_id) JOIN public.teams t ON t.id = x.team_id;

  DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;
  v_start_date := COALESCE(v_champ.start_date::date, CURRENT_DATE);

  FOR v_group_index IN 0..(v_num_groups - 1) LOOP
    v_group_name := chr(65 + v_group_index);

    SELECT COALESCE(ARRAY_AGG(team_id ORDER BY ordinality), '{}'::uuid[]) INTO v_group_team_ids
    FROM (
      SELECT v_shuffled[i] AS team_id, i AS ordinality
      FROM generate_series(1, array_length(v_shuffled,1)) AS s(i)
      WHERE ((i - 1) % v_num_groups) = v_group_index
    ) q;

    v_list := v_group_team_ids;
    IF COALESCE(array_length(v_list,1),0) % 2 = 1 THEN v_list := v_list || NULL::uuid; END IF;

    v_virtual_count := array_length(v_list,1);
    v_num_weeks := v_virtual_count - 1;
    v_matches_per_week := v_virtual_count / 2;

    FOR v_week IN 0..(v_num_weeks - 1) LOOP
      FOR v_match IN 0..(v_matches_per_week - 1) LOOP
        v_home_idx := (v_week + v_match) % (v_virtual_count - 1);
        v_away_idx := (v_virtual_count - 1 - v_match + v_week) % (v_virtual_count - 1);
        IF v_match = 0 THEN v_away_idx := v_virtual_count - 1; END IF;

        v_home_id := v_list[v_home_idx + 1];
        v_away_id := v_list[v_away_idx + 1];

        IF v_home_id IS NOT NULL AND v_away_id IS NOT NULL THEN
          SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
          SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;

          INSERT INTO public.tournament_matches (
            championship_id, round_index, match_index, group_name, week_number, stage,
            home_team_id, home_team_name, away_team_id, away_team_name,
            match_day, status, result_status, is_completed, created_at, updated_at
          ) VALUES (
            p_championship_id, 99, v_match_index, v_group_name, v_week + 1, 'group_stage',
            v_home_id, v_home_name, v_away_id, v_away_name,
            v_start_date + (v_week * COALESCE(v_champ.match_interval_days, 7)),
            'scheduled', 'scheduled', false, v_now, v_now
          );
          v_match_index := v_match_index + 1;
          v_result_count := v_result_count + 1;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN v_result_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_regular_group_fixtures_atomic(p_championship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_count INTEGER;
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED'); END IF;
  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
  IF NOT EXISTS (
    SELECT 1 FROM public.championships c
    WHERE c.id = p_championship_id
      AND (c.owner_id = v_user_id OR COALESCE(v_role, '') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;

  v_count := public.generate_regular_group_fixtures_internal(p_championship_id);
  UPDATE public.championships
  SET registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id AND status = 'open';

  RETURN jsonb_build_object('success', true, 'format', 'groups', 'matches_count', v_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_tournament_bracket_fixtures_internal(p_championship_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_type TEXT;
  v_template TEXT;
  v_result JSONB;
BEGIN
  SELECT type, template_type INTO v_type, v_template
  FROM public.championships WHERE id = p_championship_id FOR UPDATE;

  IF v_template = 'team_league' THEN RAISE EXCEPTION 'wrong_tournament_format'; END IF;

  IF v_type = 'league' THEN
    PERFORM public.generate_regular_league_fixtures_internal(p_championship_id);
  ELSIF v_type = 'groups' THEN
    PERFORM public.generate_regular_group_fixtures_internal(p_championship_id);
  ELSE
    v_result := public.generate_tournament_bracket_atomic(p_championship_id);
    IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION '%', COALESCE(v_result->>'error', 'تعذر توليد قرعة البطولة');
    END IF;
  END IF;

  UPDATE public.championships
  SET status = 'open',
      registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.advance_groups_to_knockout_atomic(p_championship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_champ RECORD;
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_num_groups INTEGER;
  v_qualifiers INTEGER;
  v_pending INTEGER;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_group_idx INTEGER;
  v_group_name TEXT;
  v_row RECORD;
  v_qualified UUID[] := '{}'::uuid[];
  v_qualified_names TEXT[] := '{}'::text[];
  v_total INTEGER;
  v_capacity INTEGER := 2;
  v_rounds INTEGER;
  v_start_round INTEGER;
  v_r INTEGER;
  v_m INTEGER;
  v_match_counts INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
BEGIN
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
  IF v_user_id IS NULL OR (v_champ.owner_id IS DISTINCT FROM v_user_id AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF v_champ.type <> 'groups' OR v_champ.template_type = 'team_league' THEN
    RETURN jsonb_build_object('success', false, 'error', 'wrong_tournament_format');
  END IF;

  SELECT count(*) INTO v_pending
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id AND stage = 'group_stage'
    AND COALESCE(is_completed, false) = false;
  IF v_pending > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'group_stage_not_completed', 'pending_matches', v_pending);
  END IF;

  IF EXISTS (SELECT 1 FROM public.tournament_matches WHERE championship_id = p_championship_id AND stage = 'knockout') THEN
    RETURN jsonb_build_object('success', true, 'already_generated', true);
  END IF;

  v_num_groups := GREATEST(2, LEAST(COALESCE(v_champ.number_of_groups, 2), 8));
  v_qualifiers := GREATEST(1, LEAST(COALESCE(v_champ.qualifying_per_group, 2), 2));

  FOR v_group_idx IN 0..(v_num_groups - 1) BY 2 LOOP
    IF v_group_idx + 1 < v_num_groups THEN
      SELECT team_id, team_name INTO v_row
      FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx))
      LIMIT 1;
      IF v_row.team_id IS NOT NULL THEN
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END IF;

      IF v_qualifiers > 1 THEN
        SELECT team_id, team_name INTO v_row
        FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx + 1))
        LIMIT 1 OFFSET 1;
        IF v_row.team_id IS NOT NULL THEN
          v_qualified := array_append(v_qualified, v_row.team_id);
          v_qualified_names := array_append(v_qualified_names, v_row.team_name);
        END IF;
      END IF;

      SELECT team_id, team_name INTO v_row
      FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx + 1))
      LIMIT 1;
      IF v_row.team_id IS NOT NULL THEN
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END IF;

      IF v_qualifiers > 1 THEN
        SELECT team_id, team_name INTO v_row
        FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx))
        LIMIT 1 OFFSET 1;
        IF v_row.team_id IS NOT NULL THEN
          v_qualified := array_append(v_qualified, v_row.team_id);
          v_qualified_names := array_append(v_qualified_names, v_row.team_name);
        END IF;
      END IF;
    ELSE
      FOR v_row IN
        SELECT team_id, team_name
        FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx))
        LIMIT v_qualifiers
      LOOP
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END LOOP;
    END IF;
  END LOOP;

  v_total := COALESCE(array_length(v_qualified,1),0);
  IF v_total < 2 THEN RETURN jsonb_build_object('success', false, 'error', 'insufficient_qualified_teams'); END IF;

  WHILE v_capacity < v_total LOOP v_capacity := v_capacity * 2; END LOOP;
  v_rounds := floor(log(v_capacity::numeric) / log(2::numeric))::integer;
  v_start_round := v_rounds - 1;

  CREATE TEMP TABLE tmp_group_knockout (
    round_index integer, match_index integer, match_id uuid default gen_random_uuid(),
    next_match_id uuid, home_team_id uuid, home_team_name text,
    away_team_id uuid, away_team_name text, winner_id uuid,
    home_score integer, away_score integer, status text default 'scheduled',
    is_completed boolean default false
  ) ON COMMIT DROP;

  FOR v_r IN REVERSE v_start_round..0 LOOP
    v_match_counts := (1 << v_r);
    FOR v_m IN 0..(v_match_counts - 1) LOOP
      INSERT INTO tmp_group_knockout(round_index, match_index) VALUES (v_r, v_m);
    END LOOP;
  END LOOP;

  UPDATE tmp_group_knockout child
  SET next_match_id = parent.match_id
  FROM tmp_group_knockout parent
  WHERE child.round_index > 0
    AND parent.round_index = child.round_index - 1
    AND parent.match_index = child.match_index / 2;

  FOR v_m IN 0..((1 << v_start_round) - 1) LOOP
    v_home_id := CASE WHEN v_m * 2 + 1 <= v_total THEN v_qualified[v_m * 2 + 1] ELSE NULL END;
    v_away_id := CASE WHEN v_m * 2 + 2 <= v_total THEN v_qualified[v_m * 2 + 2] ELSE NULL END;
    v_home_name := CASE WHEN v_m * 2 + 1 <= v_total THEN v_qualified_names[v_m * 2 + 1] ELSE NULL END;
    v_away_name := CASE WHEN v_m * 2 + 2 <= v_total THEN v_qualified_names[v_m * 2 + 2] ELSE NULL END;

    UPDATE tmp_group_knockout
    SET home_team_id = v_home_id, home_team_name = v_home_name,
        away_team_id = v_away_id, away_team_name = v_away_name,
        winner_id = CASE
          WHEN v_home_id IS NOT NULL AND v_away_id IS NULL THEN v_home_id
          WHEN v_home_id IS NULL AND v_away_id IS NOT NULL THEN v_away_id
          ELSE NULL END,
        home_score = CASE WHEN (v_home_id IS NOT NULL) <> (v_away_id IS NOT NULL) THEN 0 ELSE NULL END,
        away_score = CASE WHEN (v_home_id IS NOT NULL) <> (v_away_id IS NOT NULL) THEN 0 ELSE NULL END,
        status = CASE WHEN (v_home_id IS NULL) <> (v_away_id IS NULL) THEN 'completed' ELSE 'scheduled' END,
        is_completed = ((v_home_id IS NULL) <> (v_away_id IS NOT NULL))
    WHERE round_index = v_start_round AND match_index = v_m;

    IF v_home_id IS NOT NULL AND v_away_id IS NULL AND v_start_round > 0 THEN
      IF v_m % 2 = 0 THEN
        UPDATE tmp_group_knockout SET home_team_id = v_home_id, home_team_name = v_home_name
        WHERE round_index = v_start_round - 1 AND match_index = v_m / 2;
      ELSE
        UPDATE tmp_group_knockout SET away_team_id = v_home_id, away_team_name = v_home_name
        WHERE round_index = v_start_round - 1 AND match_index = v_m / 2;
      END IF;
    ELSIF v_home_id IS NULL AND v_away_id IS NOT NULL AND v_start_round > 0 THEN
      IF v_m % 2 = 0 THEN
        UPDATE tmp_group_knockout SET home_team_id = v_away_id, home_team_name = v_away_name
        WHERE round_index = v_start_round - 1 AND match_index = v_m / 2;
      ELSE
        UPDATE tmp_group_knockout SET away_team_id = v_away_id, away_team_name = v_away_name
        WHERE round_index = v_start_round - 1 AND match_index = v_m / 2;
      END IF;
    END IF;
  END LOOP;

  INSERT INTO public.tournament_matches (
    id, championship_id, round_index, match_index, next_match_id,
    home_team_id, home_team_name, away_team_id, away_team_name,
    home_score, away_score, winner_id, status, is_completed, stage, created_at, updated_at
  )
  SELECT match_id, p_championship_id, round_index, match_index, next_match_id,
         home_team_id, home_team_name, away_team_id, away_team_name,
         home_score, away_score, winner_id, status, is_completed, 'knockout', v_now, v_now
  FROM tmp_group_knockout ORDER BY round_index ASC;

  UPDATE public.championships SET updated_at = v_now WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true, 'format', 'groups_to_knockout',
    'qualified_teams', v_total,
    'matches_count', (SELECT count(*) FROM public.tournament_matches WHERE championship_id = p_championship_id AND stage = 'knockout')
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_tournament_match_schedule_atomic(
  p_match_id uuid,
  p_scheduled_time timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_match RECORD;
  v_champ RECORD;
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_duration INTEGER;
  v_start TIMESTAMPTZ;
  v_end TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED'); END IF;

  SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'MATCH_NOT_FOUND'); END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = v_match.championship_id;
  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;

  IF v_champ.template_type = 'team_league' THEN RETURN jsonb_build_object('success', false, 'error', 'TEAM_LEAGUE_USES_OWN_SCHEDULING'); END IF;

  IF v_champ.owner_id IS DISTINCT FROM v_user_id
     AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF v_champ.status NOT IN ('open','ongoing') THEN RETURN jsonb_build_object('success', false, 'error', 'MATCH_SCHEDULING_LOCKED'); END IF;

  IF p_scheduled_time IS NULL THEN
    UPDATE public.tournament_matches
    SET scheduled_time = NULL, updated_at = timezone('utc', now())
    WHERE id = p_match_id;
    RETURN jsonb_build_object('success', true, 'scheduled_time', NULL);
  END IF;

  v_duration := COALESCE(v_champ.match_duration, 45);
  v_start := p_scheduled_time;
  v_end := p_scheduled_time + make_interval(mins => v_duration);

  IF v_match.home_team_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.tournament_matches other
    WHERE other.championship_id = v_match.championship_id AND other.id <> v_match.id
      AND other.scheduled_time IS NOT NULL
      AND (other.home_team_id = v_match.home_team_id OR other.away_team_id = v_match.home_team_id)
      AND v_start < other.scheduled_time + make_interval(mins => v_duration)
      AND v_end > other.scheduled_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_SCHEDULE_CONFLICT');
  END IF;

  IF v_match.away_team_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.tournament_matches other
    WHERE other.championship_id = v_match.championship_id AND other.id <> v_match.id
      AND other.scheduled_time IS NOT NULL
      AND (other.home_team_id = v_match.away_team_id OR other.away_team_id = v_match.away_team_id)
      AND v_start < other.scheduled_time + make_interval(mins => v_duration)
      AND v_end > other.scheduled_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_SCHEDULE_CONFLICT');
  END IF;

  UPDATE public.tournament_matches
  SET scheduled_time = p_scheduled_time, updated_at = timezone('utc', now())
  WHERE id = p_match_id;

  RETURN jsonb_build_object('success', true, 'scheduled_time', p_scheduled_time);
END;
$function$;

REVOKE ALL ON FUNCTION public.generate_regular_league_fixtures_internal(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_regular_league_fixtures_internal(uuid) TO postgres, service_role;
REVOKE ALL ON FUNCTION public.generate_regular_group_fixtures_internal(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_regular_group_fixtures_internal(uuid) TO postgres, service_role;
REVOKE ALL ON FUNCTION public.generate_tournament_bracket_fixtures_internal(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_tournament_bracket_fixtures_internal(uuid) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.generate_regular_league_fixtures_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.generate_regular_group_fixtures_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.advance_groups_to_knockout_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_tournament_match_schedule_atomic(uuid,timestamptz) TO authenticated, service_role;
