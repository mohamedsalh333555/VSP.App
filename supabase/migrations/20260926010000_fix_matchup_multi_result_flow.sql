-- Allow winner-stays matchups to record multiple results; duo remains single-result.
DROP INDEX IF EXISTS public.uq_matchup_results_booking_id;

CREATE OR REPLACE FUNCTION public.record_matchup_result_atomic(
 p_booking_id uuid,p_team_a_id uuid,p_team_b_id uuid,p_outcome text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
 v_caller_id uuid:=auth.uid(); v_booking record; v_result_id uuid;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,matchup_mode
 INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can record match results'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL THEN RAISE EXCEPTION 'Matchup is closed'; END IF;
 IF v_booking.status NOT IN ('confirmed','completed','started') THEN RAISE EXCEPTION 'Matchup booking is not active'; END IF;
 IF p_outcome NOT IN ('team_a_win','team_b_win','draw') THEN RAISE EXCEPTION 'Invalid outcome'; END IF;
 IF p_team_a_id=p_team_b_id THEN RAISE EXCEPTION 'Cannot record same team'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=p_team_a_id)
 OR NOT EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=p_team_b_id)
 THEN RAISE EXCEPTION 'Both teams must be registered'; END IF;
 IF v_booking.matchup_mode='duo' AND EXISTS(SELECT 1 FROM public.matchup_results WHERE booking_id=p_booking_id)
 THEN RAISE EXCEPTION 'Duo matchup already has a result'; END IF;
 INSERT INTO public.matchup_results(booking_id,team_a_id,team_b_id,outcome,recorded_by,created_at)
 VALUES(p_booking_id,p_team_a_id,p_team_b_id,p_outcome,v_caller_id,timezone('utc',now())) RETURNING id INTO v_result_id;
 RETURN jsonb_build_object('success',true,'idempotent',false,'result_id',v_result_id,'booking_id',p_booking_id,'outcome',p_outcome);
END $$;

GRANT EXECUTE ON FUNCTION public.record_matchup_result_atomic(uuid,uuid,uuid,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.record_matchup_result_atomic(uuid,uuid,uuid,text) FROM anon,public;
