-- CANDIDATE ONLY: do NOT apply to staging/production without all result
-- candidates, drift checks and rollback plan. Supersedes only the scoring
-- trigger's function body, NOT the trigger object or any historical points.
--
-- Staging 2026-11-16: calculate_elo_on_match_completion has a 3/1/0
-- result rule but does NOT check private owner non-played exclusions. A
-- previously-unprocessed confirmed challenge could be awarded after it was
-- excluded if another update touches final_outcome/status/match_result_status.
--
-- Requires docs/security/sql/challenge_public_feed_exclusion_candidate.sql
-- to have installed vsp_private.is_challenge_result_excluded(uuid).
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
DECLARE
  home_points integer;
  away_points integer;
  v_changed integer;
BEGIN
  IF NEW.booking_type IS DISTINCT FROM 'challenge'
     OR NEW.status IS DISTINCT FROM 'completed'
     OR NEW.match_result_status IS DISTINCT FROM 'confirmed'
     OR COALESCE(NEW.elo_processed,false)
     OR NEW.final_outcome IS NULL THEN
    RETURN NEW;
  END IF;

  -- Private owner report is authoritative even when the historical
  -- confirmed result and elo_processed=false remain on the booking row.
  -- Never re-award an excluded match on a later unrelated booking UPDATE.
  IF vsp_private.is_challenge_result_excluded(NEW.id) THEN
    RETURN NEW;
  END IF;

  IF NEW.final_outcome NOT IN ('homeWin','awayWin','draw')
     OR NEW.player_team_id IS NULL
     OR NEW.opponent_team_id IS NULL
     OR NEW.player_team_id=NEW.opponent_team_id THEN
    RAISE EXCEPTION 'INVALID_ELIGIBLE_CHALLENGE_RESULT';
  END IF;

  home_points:=CASE WHEN NEW.final_outcome='homeWin' THEN 3
                    WHEN NEW.final_outcome='draw' THEN 1 ELSE 0 END;
  away_points:=CASE WHEN NEW.final_outcome='awayWin' THEN 3
                    WHEN NEW.final_outcome='draw' THEN 1 ELSE 0 END;

  UPDATE public.teams SET
    points=COALESCE(points,0)+home_points,
    matches_played=COALESCE(matches_played,0)+1,
    wins=COALESCE(wins,0)+CASE WHEN home_points=3 THEN 1 ELSE 0 END,
    draws=COALESCE(draws,0)+CASE WHEN home_points=1 THEN 1 ELSE 0 END,
    losses=COALESCE(losses,0)+CASE WHEN home_points=0 THEN 1 ELSE 0 END,
    updated_at=timezone('utc',now())
  WHERE id=NEW.player_team_id;
  GET DIAGNOSTICS v_changed=ROW_COUNT;
  IF v_changed<>1 THEN RAISE EXCEPTION 'HOME_SCORING_TEAM_NOT_FOUND'; END IF;

  UPDATE public.teams SET
    points=COALESCE(points,0)+away_points,
    matches_played=COALESCE(matches_played,0)+1,
    wins=COALESCE(wins,0)+CASE WHEN away_points=3 THEN 1 ELSE 0 END,
    draws=COALESCE(draws,0)+CASE WHEN away_points=1 THEN 1 ELSE 0 END,
    losses=COALESCE(losses,0)+CASE WHEN away_points=0 THEN 1 ELSE 0 END,
    updated_at=timezone('utc',now())
  WHERE id=NEW.opponent_team_id;
  GET DIAGNOSTICS v_changed=ROW_COUNT;
  IF v_changed<>1 THEN RAISE EXCEPTION 'AWAY_SCORING_TEAM_NOT_FOUND'; END IF;

  NEW.elo_processed:=true;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.calculate_elo_on_match_completion()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_elo_on_match_completion()
  TO service_role;
