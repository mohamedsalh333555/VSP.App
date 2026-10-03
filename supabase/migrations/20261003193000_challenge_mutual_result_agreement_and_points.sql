-- Challenge result agreement v2.
-- Both captains submit independently; only identical outcomes finalize.
-- Mismatches remain pending and never require Admin intervention.
CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(p_booking_id uuid,p_team_id uuid,p_outcome text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_team record; v_now timestamptz:=timezone('utc',now());
v_existing_team uuid; v_existing_outcome text;
BEGIN
 IF v_caller_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); END IF;
 IF p_outcome NOT IN ('homeWin','draw','awayWin') THEN RETURN jsonb_build_object('success',false,'error','INVALID_OUTCOME'); END IF;
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); END IF;
 IF v_booking.booking_type<>'challenge' THEN RETURN jsonb_build_object('success',false,'error','NOT_A_CHALLENGE'); END IF;
 IF v_booking.end_time>v_now THEN RETURN jsonb_build_object('success',false,'error','MATCH_NOT_FINISHED'); END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',false,'error','BOOKING_CANCELLED'); END IF;
 IF p_team_id NOT IN (v_booking.player_team_id,v_booking.opponent_team_id) THEN RETURN jsonb_build_object('success',false,'error','TEAM_NOT_IN_BOOKING'); END IF;
 SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
 IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller_id THEN RETURN jsonb_build_object('success',false,'error','CAPTAIN_ONLY'); END IF;
 IF v_booking.match_result_status='confirmed' THEN RETURN jsonb_build_object('success',false,'error','RESULT_ALREADY_FINALIZED'); END IF;

 v_existing_team:=v_booking.result_submitted_by_team_id; v_existing_outcome:=v_booking.pending_outcome;
 IF v_existing_team IS NULL OR v_existing_team=p_team_id THEN
   UPDATE public.bookings SET pending_outcome=p_outcome,result_submitted_by_team_id=p_team_id,match_result_status='waitingOpponent',
     requires_admin_intervention=false,final_outcome=NULL,updated_at=v_now WHERE id=p_booking_id;
   RETURN jsonb_build_object('success',true,'state','waitingOpponent','finalized',false,'pending_outcome',p_outcome,'submitted_by_team_id',p_team_id);
 END IF;

 IF v_existing_outcome=p_outcome THEN
   UPDATE public.bookings SET final_outcome=p_outcome,match_result_status='confirmed',status='completed',
     requires_admin_intervention=false,pending_outcome=NULL,result_submitted_by_team_id=NULL,updated_at=v_now WHERE id=p_booking_id;
   RETURN jsonb_build_object('success',true,'state','confirmed','finalized',true,'final_outcome',p_outcome);
 END IF;

 UPDATE public.bookings SET pending_outcome=p_outcome,result_submitted_by_team_id=p_team_id,match_result_status='waitingOpponent',
   requires_admin_intervention=false,final_outcome=NULL,updated_at=v_now WHERE id=p_booking_id;
 RETURN jsonb_build_object('success',true,'state','mismatch','finalized',false,'error','RESULT_MISMATCH',
   'latest_outcome',p_outcome,'latest_submitted_by_team_id',p_team_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text) TO authenticated,service_role;

-- Challenge standings use competition points: win 3, draw 1, loss 0.
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE home_points int; away_points int;
BEGIN
 IF NEW.booking_type='challenge' AND NEW.match_result_status='confirmed' AND NEW.final_outcome IS NOT NULL AND COALESCE(NEW.elo_processed,false)=false THEN
   home_points:=CASE WHEN NEW.final_outcome='homeWin' THEN 3 WHEN NEW.final_outcome='draw' THEN 1 ELSE 0 END;
   away_points:=CASE WHEN NEW.final_outcome='awayWin' THEN 3 WHEN NEW.final_outcome='draw' THEN 1 ELSE 0 END;
   UPDATE public.teams SET points=COALESCE(points,0)+home_points,matches_played=COALESCE(matches_played,0)+1,
     wins=COALESCE(wins,0)+CASE WHEN home_points=3 THEN 1 ELSE 0 END,draws=COALESCE(draws,0)+CASE WHEN home_points=1 THEN 1 ELSE 0 END,
     losses=COALESCE(losses,0)+CASE WHEN home_points=0 THEN 1 ELSE 0 END,updated_at=timezone('utc',now()) WHERE id=NEW.player_team_id;
   UPDATE public.teams SET points=COALESCE(points,0)+away_points,matches_played=COALESCE(matches_played,0)+1,
     wins=COALESCE(wins,0)+CASE WHEN away_points=3 THEN 1 ELSE 0 END,draws=COALESCE(draws,0)+CASE WHEN away_points=1 THEN 1 ELSE 0 END,
     losses=COALESCE(losses,0)+CASE WHEN away_points=0 THEN 1 ELSE 0 END,updated_at=timezone('utc',now()) WHERE id=NEW.opponent_team_id;
   NEW.elo_processed:=true;
 END IF;
 RETURN NEW;
END;
$function$;