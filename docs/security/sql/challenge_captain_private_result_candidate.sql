-- RESULT-01/02/03 candidate: isolated PostgreSQL contract first; NOT deployed.
-- Convert to a versioned migration only after staging readback, trigger review,
-- and a safe owner-approved rollout. Do not apply directly to production.
-- Existing unagreed legacy submissions must be reconciled separately.
DO $block$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE booking_type = 'challenge'
      AND match_result_status = 'waitingOpponent'
      AND (pending_outcome IS NOT NULL OR result_submitted_by_team_id IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'CHALLENGE_LEGACY_PENDING_REQUIRES_MIGRATION';
  END IF;
END;
$block$;

CREATE TABLE public.challenge_captain_result_entries (
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  submitter_id uuid NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('homeWin','draw','awayWin')),
  revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (booking_id, team_id)
);
CREATE TABLE public.challenge_captain_result_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  team_id uuid NOT NULL,
  submitter_id uuid NOT NULL,
  old_outcome text,
  new_outcome text NOT NULL CHECK (new_outcome IN ('homeWin','draw','awayWin')),
  revision integer NOT NULL CHECK (revision > 0),
  submitted_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX challenge_captain_result_audit_booking_order
  ON public.challenge_captain_result_audit(booking_id, id);
ALTER TABLE public.challenge_captain_result_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_captain_result_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.challenge_captain_result_entries, public.challenge_captain_result_audit
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.challenge_captain_result_entries, public.challenge_captain_result_audit
  TO service_role;

CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(
  p_booking_id uuid, p_team_id uuid, p_outcome text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_captain uuid;
  v_previous record;
  v_count integer;
  v_distinct integer;
  v_final text;
  v_revision integer;
  v_other_submitted boolean;
  v_previous_override text := current_setting('vsp.system_override', true);
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('homeWin','draw','awayWin') THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_OUTCOME');
  END IF;

  -- The booking row lock serializes simultaneous captain submissions.
  SELECT * INTO v_booking FROM public.bookings
    WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND');
  END IF;
  IF v_booking.booking_type <> 'challenge' THEN
    RETURN jsonb_build_object('success',false,'error','NOT_A_CHALLENGE');
  END IF;
  IF v_booking.match_result_status = 'confirmed' THEN
    RETURN jsonb_build_object('success',false,'error','RESULT_ALREADY_FINALIZED');
  END IF;
  IF v_booking.status <> 'confirmed' THEN
    RETURN jsonb_build_object('success',false,'error','BOOKING_NOT_ELIGIBLE');
  END IF;
  IF v_booking.end_time > now() THEN
    RETURN jsonb_build_object('success',false,'error','MATCH_NOT_FINISHED');
  END IF;
  IF v_booking.player_team_id IS NULL OR v_booking.opponent_team_id IS NULL
     OR v_booking.player_team_id=v_booking.opponent_team_id
     OR (p_team_id IS DISTINCT FROM v_booking.player_team_id
         AND p_team_id IS DISTINCT FROM v_booking.opponent_team_id) THEN
    RETURN jsonb_build_object('success',false,'error','TEAM_NOT_IN_BOOKING');
  END IF;
  SELECT captain_id INTO v_captain FROM public.teams WHERE id=p_team_id;
  IF NOT FOUND OR v_captain IS DISTINCT FROM v_caller_id THEN
    RETURN jsonb_build_object('success',false,'error','CAPTAIN_ONLY');
  END IF;

  SELECT * INTO v_previous FROM public.challenge_captain_result_entries
   WHERE booking_id=p_booking_id AND team_id=p_team_id;
  IF NOT FOUND OR v_previous.outcome IS DISTINCT FROM p_outcome THEN
    INSERT INTO public.challenge_captain_result_entries
      (booking_id,team_id,submitter_id,outcome,revision,submitted_at)
    VALUES (p_booking_id,p_team_id,v_caller_id,p_outcome,1,now())
    ON CONFLICT (booking_id,team_id) DO UPDATE
    SET submitter_id=excluded.submitter_id, outcome=excluded.outcome,
        revision=challenge_captain_result_entries.revision+1,
        submitted_at=excluded.submitted_at
    RETURNING revision INTO v_revision;

    INSERT INTO public.challenge_captain_result_audit
      (booking_id,team_id,submitter_id,old_outcome,new_outcome,revision)
    VALUES (p_booking_id,p_team_id,v_caller_id,
      CASE WHEN v_previous IS NULL THEN NULL ELSE v_previous.outcome END,
      p_outcome,v_revision);
  END IF;

  SELECT count(*),count(DISTINCT outcome),min(outcome)
    INTO v_count,v_distinct,v_final
    FROM public.challenge_captain_result_entries WHERE booking_id=p_booking_id;

  -- The private entries retain both captains' independent choices on mismatch.
  IF v_count=2 AND v_distinct=1 THEN
    -- The existing booking protection trigger requires a scoped internal write.
    -- Restore the previous setting before returning to the caller.
    PERFORM set_config('vsp.system_override','true',true);
    UPDATE public.bookings SET match_result_status='confirmed',
      status='completed',final_outcome=v_final,pending_outcome=NULL,
      result_submitted_by_team_id=NULL,requires_admin_intervention=false,
      updated_at=now()
    WHERE id=p_booking_id;
    PERFORM set_config('vsp.system_override',coalesce(v_previous_override,''),true);
    RETURN jsonb_build_object('success',true,'state','confirmed','finalized',true);
  END IF;

  v_other_submitted := v_count=2;
  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings SET
    match_result_status=CASE WHEN v_other_submitted THEN 'disputed'
                             ELSE 'waitingOpponent' END,
    final_outcome=NULL,pending_outcome=NULL,
    result_submitted_by_team_id=CASE WHEN v_other_submitted THEN NULL ELSE p_team_id END,
    requires_admin_intervention=false,updated_at=now()
  WHERE id=p_booking_id;
  PERFORM set_config('vsp.system_override',coalesce(v_previous_override,''),true);
  -- Never return another captain's outcome. An independent client may only
  -- learn whether a result was submitted, not which outcome was selected.
  RETURN jsonb_build_object('success',true,
    'state',CASE WHEN v_other_submitted THEN 'mismatch' ELSE 'waitingOpponent' END,
    'finalized',false,'opponent_submitted',v_other_submitted);
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text)
  TO authenticated, service_role;

-- Private read-back: each authenticated captain can retrieve their own
-- submission, not the opposing team's outcome or revision history.
CREATE OR REPLACE FUNCTION public.get_my_challenge_result_submission(
  p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_my_team_id uuid;
  v_submission record;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  SELECT booking_type,player_team_id,opponent_team_id
    INTO v_booking FROM public.bookings WHERE id=p_booking_id;
  IF NOT FOUND OR v_booking.booking_type IS DISTINCT FROM 'challenge' THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;

  SELECT t.id INTO v_my_team_id
  FROM public.teams AS t
  WHERE t.captain_id=v_caller_id
    AND t.id IN (v_booking.player_team_id,v_booking.opponent_team_id)
  ORDER BY CASE WHEN t.id=v_booking.player_team_id THEN 0 ELSE 1 END
  LIMIT 1;
  IF v_my_team_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','NOT_AUTHORIZED');
  END IF;

  SELECT outcome,revision,submitted_at INTO v_submission
    FROM public.challenge_captain_result_entries
    WHERE booking_id=p_booking_id AND team_id=v_my_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',true,'submitted',false);
  END IF;
  RETURN jsonb_build_object('success',true,'submitted',true,
    'my_outcome',v_submission.outcome,
    'my_revision',v_submission.revision,
    'submitted_at',v_submission.submitted_at);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_challenge_result_submission(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_challenge_result_submission(uuid)
  TO authenticated, service_role;
