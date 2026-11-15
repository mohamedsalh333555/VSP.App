-- Candidate RESULT-11: appeals and authorized review of a non-played challenge.
-- NOT a versioned migration; do not deploy without captain/owner real-session
-- tests, standings reconciliation, retention design, and staged rollback plan.
-- Must be installed AFTER the captain-result and report candidates in one
-- isolated transaction. No score/booking/payment changes during appeals.
CREATE TABLE public.challenge_non_played_appeals (
  booking_id uuid NOT NULL REFERENCES public.challenge_non_played_reports(booking_id) ON DELETE RESTRICT,
  team_id uuid NOT NULL REFERENCES public.teams(id),
  captain_id uuid NOT NULL,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 8 AND 500),
  revision integer NOT NULL DEFAULT 1 CHECK (revision>=1),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (booking_id,team_id)
);
CREATE TABLE public.challenge_non_played_review_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES public.challenge_non_played_reports(booking_id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL,
  team_id uuid,
  event text NOT NULL CHECK (event IN ('appeal','appeal_edited','uphold','restore')),
  previous_state text,
  new_state text NOT NULL,
  reason text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX challenge_non_played_review_audit_booking_idx
  ON public.challenge_non_played_review_audit(booking_id,id);
ALTER TABLE public.challenge_non_played_appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_non_played_review_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.challenge_non_played_appeals,
  public.challenge_non_played_review_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT ON TABLE public.challenge_non_played_appeals,
  public.challenge_non_played_review_audit TO service_role;

CREATE OR REPLACE FUNCTION public.captain_appeal_challenge_non_played_atomic(
  p_booking_id uuid, p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
DECLARE
  v_actor uuid:=auth.uid();
  v_booking record;
  v_report record;
  v_my_team uuid;
  v_current record;
  v_revision integer;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 8 AND 500 THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_REASON');
  END IF;
  -- Use the same booking row lock for report/appeal/review/submit.
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.booking_type IS DISTINCT FROM 'challenge' THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;
  SELECT * INTO v_report FROM public.challenge_non_played_reports
    WHERE booking_id=p_booking_id;
  IF NOT FOUND OR v_report.status IS DISTINCT FROM 'excluded' THEN
    RETURN jsonb_build_object('success',false,'error','REPORT_NOT_OPEN');
  END IF;
  SELECT id INTO v_my_team FROM public.teams
    WHERE captain_id=v_actor
      AND id IN (v_booking.player_team_id,v_booking.opponent_team_id)
    LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','CAPTAIN_ONLY');
  END IF;
  SELECT * INTO v_current FROM public.challenge_non_played_appeals
    WHERE booking_id=p_booking_id AND team_id=v_my_team;
  IF FOUND AND v_current.reason=btrim(p_reason) THEN
    RETURN jsonb_build_object('success',true,'state','under_review',
      'already_submitted',true,'revision',v_current.revision);
  END IF;
  INSERT INTO public.challenge_non_played_appeals
    (booking_id,team_id,captain_id,reason)
  VALUES (p_booking_id,v_my_team,v_actor,btrim(p_reason))
  ON CONFLICT (booking_id,team_id) DO UPDATE SET
    captain_id=EXCLUDED.captain_id,
    reason=EXCLUDED.reason,
    revision=challenge_non_played_appeals.revision+1,
    updated_at=now()
  RETURNING revision INTO v_revision;
  INSERT INTO public.challenge_non_played_review_audit
    (booking_id,actor_user_id,team_id,event,previous_state,new_state,reason)
  VALUES (p_booking_id,v_actor,v_my_team,
    CASE WHEN v_current IS NULL THEN 'appeal' ELSE 'appeal_edited' END,
    v_report.status,v_report.status,btrim(p_reason));
  RETURN jsonb_build_object('success',true,'state','under_review',
    'already_submitted',false,'revision',v_revision);
END;
$function$;

CREATE OR REPLACE FUNCTION public.review_challenge_non_played_atomic(
  p_booking_id uuid,p_decision text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
DECLARE
  v_actor uuid:=auth.uid();
  v_role text;
  v_booking record;
  v_report record;
  v_latest_appeal timestamptz;
  v_home_points integer;
  v_away_points integer;
  v_home_wins integer;
  v_away_wins integer;
  v_home_draws integer;
  v_away_draws integer;
  v_home_losses integer;
  v_away_losses integer;
  v_changed integer;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('uphold','restore')
     OR p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 8 AND 500 THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_REVIEW');
  END IF;
  -- Only the server-validated admin/cofounder roles may restore points.
  -- A venue owner and either captain must never call this as adjudicator.
  SELECT role INTO v_role FROM public.users WHERE id=v_actor;
  IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.booking_type IS DISTINCT FROM 'challenge' THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;
  SELECT * INTO v_report FROM public.challenge_non_played_reports
    WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','REPORT_NOT_FOUND');
  END IF;
  IF v_report.status='restored' THEN
    IF p_decision='restore' THEN
      RETURN jsonb_build_object('success',true,'state','restored','already_reviewed',true);
    END IF;
    RETURN jsonb_build_object('success',false,'error','REPORT_ALREADY_RESTORED');
  END IF;

  IF p_decision='uphold' THEN
    SELECT max(updated_at) INTO v_latest_appeal
      FROM public.challenge_non_played_appeals WHERE booking_id=p_booking_id;
    IF v_report.review_decision='uphold' AND v_report.reviewed_at IS NOT NULL
       AND (v_latest_appeal IS NULL OR v_latest_appeal<=v_report.reviewed_at) THEN
      RETURN jsonb_build_object('success',true,'state','excluded','already_reviewed',true);
    END IF;
    UPDATE public.challenge_non_played_reports
    SET reviewed_by_admin_id=v_actor, reviewed_at=now(),
        review_decision='uphold',review_reason=btrim(p_reason)
    WHERE booking_id=p_booking_id;
    INSERT INTO public.challenge_non_played_review_audit
      (booking_id,actor_user_id,event,previous_state,new_state,reason)
    VALUES (p_booking_id,v_actor,'uphold','excluded','excluded',btrim(p_reason));
    RETURN jsonb_build_object('success',true,'state','excluded',
      'already_reviewed',false);
  END IF;

  IF COALESCE(v_report.ranking_reversed,false) THEN
    IF v_report.ranking_restored OR v_booking.elo_processed IS DISTINCT FROM true
       OR v_booking.match_result_status IS DISTINCT FROM 'confirmed'
       OR v_booking.final_outcome IS DISTINCT FROM v_report.original_outcome
       OR v_booking.final_outcome NOT IN ('homeWin','awayWin','draw')
       OR v_booking.player_team_id IS NULL OR v_booking.opponent_team_id IS NULL
       OR v_booking.player_team_id=v_booking.opponent_team_id THEN
      RAISE EXCEPTION 'CHALLENGE_RESTORE_RANKING_INCONSISTENT';
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
    UPDATE public.teams SET
      points=COALESCE(points,0)+v_home_points,
      matches_played=COALESCE(matches_played,0)+1,
      wins=COALESCE(wins,0)+v_home_wins,
      draws=COALESCE(draws,0)+v_home_draws,
      losses=COALESCE(losses,0)+v_home_losses,
      updated_at=now() WHERE id=v_booking.player_team_id;
    GET DIAGNOSTICS v_changed=ROW_COUNT;
    IF v_changed<>1 THEN RAISE EXCEPTION 'HOME_RESTORE_FAILED'; END IF;
    UPDATE public.teams SET
      points=COALESCE(points,0)+v_away_points,
      matches_played=COALESCE(matches_played,0)+1,
      wins=COALESCE(wins,0)+v_away_wins,
      draws=COALESCE(draws,0)+v_away_draws,
      losses=COALESCE(losses,0)+v_away_losses,
      updated_at=now() WHERE id=v_booking.opponent_team_id;
    GET DIAGNOSTICS v_changed=ROW_COUNT;
    IF v_changed<>1 THEN RAISE EXCEPTION 'AWAY_RESTORE_FAILED'; END IF;
  END IF;

  UPDATE public.challenge_non_played_reports
  SET status='restored',ranking_restored=ranking_reversed,
      reviewed_by_admin_id=v_actor,reviewed_at=now(),
      review_decision='restore',review_reason=btrim(p_reason)
  WHERE booking_id=p_booking_id;
  INSERT INTO public.challenge_non_played_review_audit
    (booking_id,actor_user_id,event,previous_state,new_state,reason)
  VALUES (p_booking_id,v_actor,'restore','excluded','restored',btrim(p_reason));
  RETURN jsonb_build_object('success',true,'state','restored',
    'already_reviewed',false,'ranking_restored',v_report.ranking_reversed);
END;
$function$;

-- The public-facing status deliberately omits private appeal reasons,
-- votes, identities and administrative review notes. An unrelated user
-- receives the same NOT_AUTHORIZED result for missing/private bookings.
CREATE OR REPLACE FUNCTION public.get_my_challenge_non_played_status(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
DECLARE
 v_actor uuid:=auth.uid();
 v_booking record;
 v_report record;
 v_team_id uuid;
 v_allowed boolean;
 v_latest_appeal timestamptz;
BEGIN
 IF v_actor IS NULL THEN
   RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
 END IF;
 SELECT owner_id,booking_type,player_team_id,opponent_team_id INTO v_booking
   FROM public.bookings WHERE id=p_booking_id;
 IF NOT FOUND OR v_booking.booking_type IS DISTINCT FROM 'challenge' THEN
   RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
 END IF;
 SELECT id INTO v_team_id FROM public.teams
   WHERE captain_id=v_actor
   AND id IN (v_booking.player_team_id,v_booking.opponent_team_id) LIMIT 1;
 v_allowed:= v_actor=v_booking.owner_id OR v_team_id IS NOT NULL;
 IF NOT v_allowed THEN
   RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
 END IF;
 SELECT * INTO v_report FROM public.challenge_non_played_reports
   WHERE booking_id=p_booking_id;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('success',true,'reported',false);
 END IF;
 SELECT max(updated_at) INTO v_latest_appeal
   FROM public.challenge_non_played_appeals WHERE booking_id=p_booking_id;
 RETURN jsonb_build_object('success',true,'reported',true,
    'state',v_report.status,
    'under_review',v_report.status='excluded'
      AND v_latest_appeal IS NOT NULL
      AND (v_report.reviewed_at IS NULL OR v_latest_appeal>v_report.reviewed_at),
    'my_appeal_submitted',v_team_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM public.challenge_non_played_appeals
       WHERE booking_id=p_booking_id AND team_id=v_team_id));
END;
$function$;

REVOKE ALL ON FUNCTION public.captain_appeal_challenge_non_played_atomic(uuid,text)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.review_challenge_non_played_atomic(uuid,text,text)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.get_my_challenge_non_played_status(uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.captain_appeal_challenge_non_played_atomic(uuid,text)
  TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.review_challenge_non_played_atomic(uuid,text,text)
  TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_challenge_non_played_status(uuid)
  TO authenticated,service_role;
