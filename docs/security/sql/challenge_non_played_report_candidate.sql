-- Candidate RESULT-09/10/12: non-played challenges, NOT DEPLOYABLE.
-- Must be installed atomically with the captain-result candidate. Before
-- deployment implement captain appeal/review/restore, consumer read isolation,
-- account deletion retention policy and real two-session concurrency tests.
-- This function must not call owner_record_no_show_atomic or change payments.
CREATE TABLE public.challenge_non_played_reports (
  booking_id uuid PRIMARY KEY REFERENCES public.bookings(id) ON DELETE RESTRICT,
  reported_by_owner_id uuid NOT NULL,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 8 AND 500),
  status text NOT NULL DEFAULT 'excluded' CHECK (status = 'excluded'),
  original_outcome text,
  ranking_reversed boolean NOT NULL DEFAULT false,
  reported_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.challenge_non_played_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.challenge_non_played_reports FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.challenge_non_played_reports TO service_role;

CREATE OR REPLACE FUNCTION public.owner_report_challenge_not_played_atomic(
  p_booking_id uuid,p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_booking record;
  v_home_points integer;
  v_away_points integer;
  v_home_wins integer;
  v_away_wins integer;
  v_home_draws integer;
  v_away_draws integer;
  v_home_losses integer;
  v_away_losses integer;
  v_reversed boolean := false;
  v_updated integer;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 8 AND 500 THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_REASON');
  END IF;
  -- Same row lock as submit_challenge_result_atomic; the two paths serialize.
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;
  IF v_booking.booking_type <> 'challenge' OR
     v_booking.owner_id IS DISTINCT FROM v_actor THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;
  IF v_booking.end_time > now() THEN
    RETURN jsonb_build_object('success',false,'error','MATCH_NOT_FINISHED');
  END IF;
  IF v_booking.status NOT IN ('confirmed','completed') THEN
    RETURN jsonb_build_object('success',false,'error','BOOKING_NOT_ELIGIBLE');
  END IF;
  IF EXISTS(SELECT 1 FROM public.challenge_non_played_reports
            WHERE booking_id=p_booking_id) THEN
    RETURN jsonb_build_object('success',true,'state','excluded',
      'already_reported',true,'ranking_reversed',false);
  END IF;

  IF COALESCE(v_booking.elo_processed,false) THEN
    IF v_booking.match_result_status <> 'confirmed'
       OR v_booking.final_outcome NOT IN ('homeWin','awayWin','draw')
       OR v_booking.player_team_id IS NULL
       OR v_booking.opponent_team_id IS NULL
       OR v_booking.player_team_id=v_booking.opponent_team_id THEN
      RAISE EXCEPTION 'CHALLENGE_RANKING_INCONSISTENT';
    END IF;
    v_home_points:=CASE WHEN v_booking.final_outcome='homeWin' THEN 3
                        WHEN v_booking.final_outcome='draw' THEN 1 ELSE 0 END;
    v_away_points:=CASE WHEN v_booking.final_outcome='awayWin' THEN 3
                        WHEN v_booking.final_outcome='draw' THEN 1 ELSE 0 END;
    v_home_wins:=(v_home_points=3)::integer;
    v_away_wins:=(v_away_points=3)::integer;
    v_home_draws:=(v_home_points=1)::integer;
    v_away_draws:=(v_away_points=1)::integer;
    v_home_losses:=(v_home_points=0)::integer;
    v_away_losses:=(v_away_points=0)::integer;

    -- Atomic deltas, not re-setting the full standings; fail if source
    -- counters are inconsistent rather than hiding an underflow with GREATEST.
    UPDATE public.teams
      SET points=COALESCE(points,0)-v_home_points,
          matches_played=COALESCE(matches_played,0)-1,
          wins=COALESCE(wins,0)-v_home_wins,
          draws=COALESCE(draws,0)-v_home_draws,
          losses=COALESCE(losses,0)-v_home_losses,
          updated_at=now()
    WHERE id=v_booking.player_team_id
      AND COALESCE(points,0)>=v_home_points
      AND COALESCE(matches_played,0)>=1
      AND COALESCE(wins,0)>=v_home_wins
      AND COALESCE(draws,0)>=v_home_draws
      AND COALESCE(losses,0)>=v_home_losses;
    GET DIAGNOSTICS v_updated=ROW_COUNT;
    IF v_updated<>1 THEN RAISE EXCEPTION 'HOME_RANKING_REVERSE_FAILED'; END IF;

    UPDATE public.teams
      SET points=COALESCE(points,0)-v_away_points,
          matches_played=COALESCE(matches_played,0)-1,
          wins=COALESCE(wins,0)-v_away_wins,
          draws=COALESCE(draws,0)-v_away_draws,
          losses=COALESCE(losses,0)-v_away_losses,
          updated_at=now()
    WHERE id=v_booking.opponent_team_id
      AND COALESCE(points,0)>=v_away_points
      AND COALESCE(matches_played,0)>=1
      AND COALESCE(wins,0)>=v_away_wins
      AND COALESCE(draws,0)>=v_away_draws
      AND COALESCE(losses,0)>=v_away_losses;
    GET DIAGNOSTICS v_updated=ROW_COUNT;
    IF v_updated<>1 THEN RAISE EXCEPTION 'AWAY_RANKING_REVERSE_FAILED'; END IF;
    v_reversed:=true;
  END IF;

  INSERT INTO public.challenge_non_played_reports
    (booking_id,reported_by_owner_id,reason,original_outcome,ranking_reversed)
  VALUES (p_booking_id,v_actor,btrim(p_reason),v_booking.final_outcome,v_reversed);

  -- Never call attendance/financial no-show functions from this flow.
  RETURN jsonb_build_object('success',true,'state','excluded',
    'already_reported',false,'ranking_reversed',v_reversed);
END;
$function$;

REVOKE ALL ON FUNCTION public.owner_report_challenge_not_played_atomic(uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.owner_report_challenge_not_played_atomic(uuid,text)
  TO authenticated, service_role;
