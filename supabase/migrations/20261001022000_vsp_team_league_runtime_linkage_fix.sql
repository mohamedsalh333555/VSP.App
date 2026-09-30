-- ==============================================================================
-- Migration: 20261001022000_vsp_team_league_runtime_linkage_fix.sql
-- Purpose:
--   1. Repair Team League runtime reads to use the actual championships schema.
--   2. Remove references to the nonexistent championship_participants table.
--   3. Use template_type='team_league' as the Team League discriminator.
--   4. Use championships.joined_teams as the canonical participant source.
--   5. Generate Team League fixtures from joined_teams and persist team names.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_team_active_league(p_team_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_champ RECORD;
  v_matches JSONB;
  v_standings JSONB;
  v_teams JSONB;
  v_user_id UUID := auth.uid();
  v_is_creator BOOLEAN := false;
BEGIN
  SELECT c.*
    INTO v_champ
  FROM public.championships c
  WHERE c.template_type = 'team_league'
    AND p_team_id::text = ANY(COALESCE(c.joined_teams, '{}'::text[]))
    AND c.status IN ('open', 'ongoing', 'completed')
  ORDER BY c.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_is_creator := (v_champ.owner_id = v_user_id);

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'name', t.name,
      'logo_url', t.logo_url,
      'captain_id', t.captain_id,
      'captain_phone', u.phone,
      'joined_at', v_champ.created_at,
      'prepaid_by_creator',
        (t.id::text = ANY(COALESCE(v_champ.paid_teams, '{}'::text[])))
    )
    ORDER BY jt.ordinality ASC
  )
  INTO v_teams
  FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[])) WITH ORDINALITY AS jt(team_id_text, ordinality)
  JOIN public.teams t ON t.id = jt.team_id_text::uuid
  LEFT JOIN public.users u ON u.id = t.captain_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'championship_id', m.championship_id,
      'week_number', COALESCE(m.week_number, m.round_index + 1),
      'match_index', m.match_index,
      'stage', m.stage,
      'home_team_id', m.home_team_id,
      'home_team_name', ht.name,
      'away_team_id', m.away_team_id,
      'away_team_name', at.name,
      'home_score', m.home_score,
      'away_score', m.away_score,
      'winner_id', m.winner_id,
      'winner_name', m.winner_name,
      'confirmed_outcome', m.confirmed_outcome,
      'result_status',
        CASE
          WHEN m.result_status = 'confirmed'
           AND m.result_confirmed_at IS NOT NULL
           AND m.result_confirmed_at + interval '15 minutes' < clock_timestamp()
            THEN 'locked'
          ELSE COALESCE(m.result_status, 'scheduled')
        END,
      'status', m.status,
      'is_completed',
        (m.result_status IN ('confirmed', 'locked')
         OR (m.result_confirmed_at IS NOT NULL)),
      'scheduled_time', m.scheduled_time,
      'result_confirmed_at', m.result_confirmed_at,
      'result_locked_at', m.result_locked_at,
      'dispute_created_at', m.dispute_created_at,
      'match_day', m.match_day,
      'booking_id', m.booking_id,
      'stadium_name', m.stadium_name,
      'my_team_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id = p_team_id
      ),
      'opponent_team_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id <> p_team_id
        LIMIT 1
      ),
      'home_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id = m.home_team_id
      ),
      'away_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id = m.away_team_id
      )
    )
    ORDER BY COALESCE(m.week_number, m.round_index + 1) ASC, m.match_index ASC
  )
  INTO v_matches
  FROM public.tournament_matches m
  JOIN public.teams ht ON ht.id = m.home_team_id
  JOIN public.teams at ON at.id = m.away_team_id
  WHERE m.championship_id = v_champ.id;

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
    'champion_team_id', v_champ.champion_team_id,
    'champion_team_name', v_champ.champion_team_name,
    'governorate', v_champ.governorate,
    'teams', COALESCE(v_teams, '[]'::jsonb),
    'matches', COALESCE(v_matches, '[]'::jsonb),
    'standings', COALESCE(v_standings, '[]'::jsonb)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_team_league_fixtures(p_championship_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_template_type TEXT;
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
  v_home_name TEXT;
  v_away_name TEXT;
  v_bye_dummy UUID := '00000000-0000-0000-0000-000000000000'::UUID;
  v_now TIMESTAMPTZ := timezone('utc', now());
BEGIN
  SELECT template_type,
         COALESCE(match_interval_days, 7),
         COALESCE(start_date::date, CURRENT_DATE)
    INTO v_template_type, v_interval_days, v_start_date
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF v_template_type IS NULL OR v_template_type <> 'team_league' THEN
    RAISE EXCEPTION 'Championship is not a valid team_league';
  END IF;

  SELECT ARRAY_AGG(jt.team_id_text::uuid ORDER BY jt.ordinality)
    INTO v_teams
  FROM unnest(
    COALESCE(
      (SELECT joined_teams
       FROM public.championships
       WHERE id = p_championship_id),
      '{}'::text[]
    )
  ) WITH ORDINALITY AS jt(team_id_text, ordinality);

  v_team_count := COALESCE(ARRAY_LENGTH(v_teams, 1), 0);

  IF v_team_count < 4 OR v_team_count > 8 THEN
    RAISE EXCEPTION 'Team league requires between 4 and 8 teams (current: %)', v_team_count;
  END IF;

  IF v_team_count % 2 <> 0 THEN
    v_teams := v_teams || v_bye_dummy;
    v_virtual_count := v_team_count + 1;
  ELSE
    v_virtual_count := v_team_count;
  END IF;

  v_rounds_count := v_virtual_count - 1;
  v_matches_per_round := v_virtual_count / 2;

  DELETE FROM public.tournament_matches
  WHERE championship_id = p_championship_id
    AND COALESCE(result_status, 'scheduled') = 'scheduled'
    AND result_confirmed_at IS NULL
    AND COALESCE(is_completed, false) = false;

  FOR v_round_idx IN 0..(v_rounds_count - 1) LOOP
    FOR v_match_idx IN 0..(v_matches_per_round - 1) LOOP
      IF v_match_idx = 0 THEN
        v_t1_idx := v_virtual_count - 1;
        v_t2_idx := v_round_idx % (v_virtual_count - 1);
      ELSE
        v_t1_idx := (v_round_idx + v_match_idx) % (v_virtual_count - 1);
        v_t2_idx := (v_round_idx - v_match_idx + (v_virtual_count - 1)) % (v_virtual_count - 1);
      END IF;

      v_home_id := v_teams[v_t1_idx + 1];
      v_away_id := v_teams[v_t2_idx + 1];

      IF v_round_idx % 2 = 1 AND v_match_idx = 0 THEN
        DECLARE
          v_temp UUID := v_home_id;
        BEGIN
          v_home_id := v_away_id;
          v_away_id := v_temp;
        END;
      END IF;

      IF v_home_id = v_bye_dummy OR v_away_id = v_bye_dummy THEN
        CONTINUE;
      END IF;

      SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
      SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;

      INSERT INTO public.tournament_matches (
        championship_id,
        stage,
        week_number,
        match_index,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        match_day,
        status,
        result_status,
        is_completed,
        created_at,
        updated_at
      ) VALUES (
        p_championship_id,
        'league',
        v_round_idx + 1,
        v_match_idx,
        v_home_id,
        v_home_name,
        v_away_id,
        v_away_name,
        v_start_date + (v_round_idx * v_interval_days),
        'scheduled',
        'scheduled',
        false,
        v_now,
        v_now
      );
    END LOOP;
  END LOOP;

  UPDATE public.championships
  SET status = 'ongoing',
      registration_locked_at = COALESCE(registration_locked_at, v_now),
      updated_at = v_now
  WHERE id = p_championship_id
    AND status = 'open';
END;
$function$;

-- The actual production schema has no championship_participants table.
-- Team League participant reads are sourced from championships.joined_teams.
