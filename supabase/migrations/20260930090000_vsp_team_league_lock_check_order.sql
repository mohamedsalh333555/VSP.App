-- ============================================================
-- MIGRATION: 20260930090000_vsp_team_league_lock_check_order
-- PURPOSE  : Check the 15-minute Team League result lock before
--            the confirmation state gate so expired results are
--            persisted as locked in the database.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.confirm_team_league_match_result(
  p_match_id uuid,
  p_outcome text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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

  IF v_match.creator_id != v_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only the league creator can confirm or resolve match results';
  END IF;

  -- Lock MUST be checked before the state gate.
  -- An expired confirmed result is persisted as locked before returning the lock error.
  IF v_match.result_status = 'locked' OR
     (v_match.result_confirmed_at IS NOT NULL
      AND v_match.result_confirmed_at + INTERVAL '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches
    SET result_status    = 'locked',
        result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;

    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- Both teams must have submitted before creator can act.
  IF v_match.result_status NOT IN ('awaiting_confirmation', 'disputed') THEN
    RAISE EXCEPTION
      'INVALID_STATE: Cannot confirm. Both teams must submit their results first. Current status: %',
      COALESCE(v_match.result_status, 'scheduled');
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
      dispute_resolved_at = CASE WHEN v_match.result_status = 'disputed'
                                 THEN clock_timestamp()
                                 ELSE dispute_resolved_at END,
      dispute_resolved_by = CASE WHEN v_match.result_status = 'disputed'
                                 THEN v_user_id
                                 ELSE dispute_resolved_by END,
      status              = 'completed',
      is_completed        = true
  WHERE id = p_match_id;

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
$function$;

REVOKE ALL ON FUNCTION public.confirm_team_league_match_result(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_team_league_match_result(uuid, text) TO authenticated;

COMMIT;
