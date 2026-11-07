-- Close two confirmed Team League server-side gaps:
--   1. Restrict active-league reads to the league owner or a member of the
--      requested team, and only expose captain phone numbers to the owner or
--      the requested team's captain.
--   2. Reject result submissions until the fixture has a confirmed booking
--      and its scheduled kickoff has passed.

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
  v_is_requested_team_captain BOOLEAN := false;
  v_can_view_captain_phone BOOLEAN := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

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

  SELECT EXISTS (
    SELECT 1
    FROM public.teams t
    WHERE t.id = p_team_id
      AND t.captain_id = v_user_id
  )
  INTO v_is_requested_team_captain;

  IF NOT v_is_creator
     AND NOT v_is_requested_team_captain
     AND NOT EXISTS (
       SELECT 1
       FROM public.team_members tm
       WHERE tm.team_id = p_team_id
         AND tm.user_id = v_user_id
     ) THEN
    RAISE EXCEPTION 'Not authorized to view this team league';
  END IF;

  v_can_view_captain_phone :=
    v_is_creator OR v_is_requested_team_captain;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'name', t.name,
      'logo_url', t.logo_url,
      'captain_id', t.captain_id,
      'captain_phone',
        CASE WHEN v_can_view_captain_phone THEN u.phone ELSE NULL END,
      'joined_at', v_champ.created_at,
      'prepaid_by_creator',
        (t.id::text = ANY(COALESCE(v_champ.paid_teams, '{}'::text[])))
    )
    ORDER BY jt.ordinality ASC
  )
  INTO v_teams
  FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[]))
       WITH ORDINALITY AS jt(team_id_text, ordinality)
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
    ORDER BY COALESCE(m.week_number, m.round_index + 1) ASC,
             m.match_index ASC
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

REVOKE ALL ON FUNCTION public.get_team_active_league(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_active_league(uuid)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.enforce_team_league_submission_gate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_match RECORD;
  v_booking_status TEXT;
BEGIN
  SELECT tm.booking_id,
         tm.scheduled_time,
         tm.home_team_id,
         tm.away_team_id
    INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c
    ON c.id = tm.championship_id
   AND c.template_type = 'team_league'
  WHERE tm.id = NEW.match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Team League match not found';
  END IF;

  IF NEW.team_id <> v_match.home_team_id
     AND NEW.team_id <> v_match.away_team_id THEN
    RAISE EXCEPTION 'Team does not belong to this match';
  END IF;

  IF v_match.booking_id IS NULL THEN
    RAISE EXCEPTION 'MATCH_BOOKING_REQUIRED: A confirmed booking is required before result submission';
  END IF;

  IF v_match.scheduled_time IS NULL
     OR v_match.scheduled_time > clock_timestamp() THEN
    RAISE EXCEPTION 'MATCH_NOT_STARTED: Results can only be submitted after the scheduled kickoff';
  END IF;

  SELECT b.status
    INTO v_booking_status
  FROM public.bookings b
  WHERE b.id = v_match.booking_id;

  IF NOT FOUND OR v_booking_status NOT IN ('confirmed', 'completed') THEN
    RAISE EXCEPTION 'MATCH_BOOKING_NOT_CONFIRMED: The linked booking is not confirmed';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.enforce_team_league_submission_gate()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_team_league_submission_gate
  ON public.team_league_match_submissions;

CREATE TRIGGER trg_enforce_team_league_submission_gate
BEFORE INSERT OR UPDATE
ON public.team_league_match_submissions
FOR EACH ROW
EXECUTE FUNCTION public.enforce_team_league_submission_gate();
