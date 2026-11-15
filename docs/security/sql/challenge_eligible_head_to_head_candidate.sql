-- Candidate: permission-scoped challenge-only head-to-head summary.
-- Not deployed; old matchup head-to-head and team-league ranks are separate.
-- Aggregates require the complete team history; booking RLS currently
-- allows only booker/owner/participant, not all team captains or members.
-- This narrow SECURITY DEFINER summary MUST check real roster membership
-- before reading bookings and returns totals only, never individual matches.
-- The private exclusion helper is non-exposed and reveals only a boolean.
CREATE OR REPLACE FUNCTION public.get_eligible_challenge_head_to_head_stats(
  p_team_a_id uuid,p_team_b_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp
AS $function$
DECLARE
  v_actor uuid:=auth.uid();
  v_team_a_wins integer;
  v_team_b_wins integer;
  v_draws integer;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_team_a_id IS NULL OR p_team_b_id IS NULL OR
     p_team_a_id=p_team_b_id THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_TEAM_PAIR');
  END IF;
  -- Do not let an unrelated authenticated player enumerate private history.
  -- Include captain transfers/roster membership only as currently recorded;
  -- historical membership eligibility still needs separate release review.
  IF NOT EXISTS(
    SELECT 1 FROM public.teams t
    WHERE t.id IN (p_team_a_id,p_team_b_id) AND t.captain_id=v_actor
  ) AND NOT EXISTS(
    SELECT 1 FROM public.team_members tm
    WHERE tm.team_id IN (p_team_a_id,p_team_b_id) AND tm.user_id=v_actor
  ) THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;
  SELECT
    count(*) FILTER (WHERE
      (b.player_team_id=p_team_a_id AND b.final_outcome='homeWin') OR
      (b.opponent_team_id=p_team_a_id AND b.final_outcome='awayWin')),
    count(*) FILTER (WHERE
      (b.player_team_id=p_team_b_id AND b.final_outcome='homeWin') OR
      (b.opponent_team_id=p_team_b_id AND b.final_outcome='awayWin')),
    count(*) FILTER (WHERE b.final_outcome='draw')
  INTO v_team_a_wins,v_team_b_wins,v_draws
  FROM public.bookings b
  WHERE b.booking_type='challenge'
    AND b.status='completed'
    AND b.match_result_status='confirmed'
    AND b.elo_processed IS TRUE
    AND b.final_outcome IN ('homeWin','awayWin','draw')
    AND (
      (b.player_team_id=p_team_a_id AND b.opponent_team_id=p_team_b_id)
       OR
      (b.player_team_id=p_team_b_id AND b.opponent_team_id=p_team_a_id)
    )
    AND NOT vsp_private.is_challenge_result_excluded(b.id);

  RETURN jsonb_build_object('success',true,
    'teamAWins',v_team_a_wins,'teamBWins',v_team_b_wins,
    'draws',v_draws,'totalMatches',
    v_team_a_wins+v_team_b_wins+v_draws);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_eligible_challenge_head_to_head_stats(uuid,uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_eligible_challenge_head_to_head_stats(uuid,uuid)
  TO authenticated,service_role;
