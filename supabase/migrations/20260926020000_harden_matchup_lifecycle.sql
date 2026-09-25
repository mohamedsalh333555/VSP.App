-- Matchup lifecycle: lock booking while mutating, prevent post-end team changes,
-- and only allow result/closure after the scheduled match ends.
CREATE OR REPLACE FUNCTION public.confirm_matchup_atomic(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_teams_count int; v_mode text;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,start_time,end_time INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can confirm the matchup'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL THEN RAISE EXCEPTION 'Matchup is already closed'; END IF;
 IF v_booking.status='cancelled' OR v_booking.end_time<=timezone('utc',now()) THEN RAISE EXCEPTION 'Cannot confirm an ended or cancelled booking'; END IF;
 SELECT count(*) INTO v_teams_count FROM public.matchup_teams WHERE booking_id=p_booking_id;
 IF v_teams_count<2 THEN RAISE EXCEPTION 'Cannot confirm matchup: At least 2 teams must be added'; END IF;
 v_mode:=CASE WHEN v_teams_count=2 THEN 'duo' ELSE 'winner_stays' END;
 UPDATE public.bookings SET matchup_mode=v_mode,booking_type='matchup' WHERE id=p_booking_id;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'teams_count',v_teams_count,'matchup_mode',v_mode);
END $$;

CREATE OR REPLACE FUNCTION public.add_team_to_matchup_by_code(p_booking_id uuid,p_invite_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_target_team record; v_clean_code text:=upper(trim(p_invite_code)); v_current_count int; v_members int; v_paid boolean;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,end_time INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can add teams to the matchup'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL OR v_booking.status='cancelled' OR v_booking.end_time<=timezone('utc',now()) THEN RAISE EXCEPTION 'Cannot add teams to an ended or closed matchup'; END IF;
 IF length(v_clean_code)<4 THEN RAISE EXCEPTION 'Invalid invite code provided'; END IF;
 SELECT id,name,logo_url,captain_id,invite_code_expires_at INTO v_target_team FROM public.teams WHERE active_invite_code=v_clean_code FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invalid or expired invite code'; END IF;
 IF v_target_team.invite_code_expires_at IS NOT NULL AND v_target_team.invite_code_expires_at<timezone('utc',now()) THEN RAISE EXCEPTION 'This invite code has expired'; END IF;
 SELECT count(*) INTO v_members FROM public.team_members WHERE team_id=v_target_team.id;
 IF v_members<5 THEN RAISE EXCEPTION 'Team is incomplete (less than 5 members)'; END IF;
 IF EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=v_target_team.id) THEN RAISE EXCEPTION 'Team is already added to this matchup'; END IF;
 SELECT count(*) INTO v_current_count FROM public.matchup_teams WHERE booking_id=p_booking_id;
 IF v_current_count>=5 THEN
  SELECT EXISTS(SELECT 1 FROM public.transactions WHERE booking_id=p_booking_id AND transaction_type='matchup_extra_teams_fee' AND status IN ('paid','completed')) INTO v_paid;
  IF NOT v_paid THEN RAISE EXCEPTION 'LIMIT_REACHED_EXTRA_FEE_REQUIRED: Adding more than 5 teams requires 25 EGP extra fee'; END IF;
 END IF;
 INSERT INTO public.matchup_teams(booking_id,team_id,added_by_user_id,joined_at) VALUES(p_booking_id,v_target_team.id,v_caller_id,timezone('utc',now()));
 UPDATE public.teams SET active_invite_code=NULL,invite_code_expires_at=NULL WHERE id=v_target_team.id;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'team_id',v_target_team.id,'team_name',v_target_team.name,'logo_url',v_target_team.logo_url,'total_teams_now',v_current_count+1);
END $$;

CREATE OR REPLACE FUNCTION public.record_matchup_result_atomic(p_booking_id uuid,p_team_a_id uuid,p_team_b_id uuid,p_outcome text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_result_id uuid;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,matchup_mode,end_time INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can record match results'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL THEN RAISE EXCEPTION 'Matchup is closed'; END IF;
 IF v_booking.status NOT IN ('confirmed','completed','started') THEN RAISE EXCEPTION 'Matchup booking is not active'; END IF;
 IF timezone('utc',now())<v_booking.end_time THEN RAISE EXCEPTION 'MATCHUP_RESULT_TOO_EARLY: Result can be recorded only after the scheduled match ends'; END IF;
 IF p_outcome NOT IN ('team_a_win','team_b_win','draw') THEN RAISE EXCEPTION 'Invalid outcome'; END IF;
 IF p_team_a_id=p_team_b_id THEN RAISE EXCEPTION 'Cannot record same team'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=p_team_a_id) OR NOT EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=p_team_b_id) THEN RAISE EXCEPTION 'Both teams must be registered'; END IF;
 IF v_booking.matchup_mode='duo' AND EXISTS(SELECT 1 FROM public.matchup_results WHERE booking_id=p_booking_id) THEN RAISE EXCEPTION 'Duo matchup already has a result'; END IF;
 INSERT INTO public.matchup_results(booking_id,team_a_id,team_b_id,outcome,recorded_by,created_at) VALUES(p_booking_id,p_team_a_id,p_team_b_id,p_outcome,v_caller_id,timezone('utc',now())) RETURNING id INTO v_result_id;
 RETURN jsonb_build_object('success',true,'result_id',v_result_id,'booking_id',p_booking_id,'outcome',p_outcome);
END $$;

CREATE OR REPLACE FUNCTION public.close_matchup_atomic(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_results_count int;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,end_time INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can close the matchup'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL THEN RETURN jsonb_build_object('success',true,'already_closed',true,'booking_id',p_booking_id); END IF;
 IF timezone('utc',now())<v_booking.end_time THEN RAISE EXCEPTION 'Cannot close matchup before the scheduled match ends'; END IF;
 SELECT count(*) INTO v_results_count FROM public.matchup_results WHERE booking_id=p_booking_id;
 IF v_results_count=0 THEN RAISE EXCEPTION 'Cannot close matchup without recording at least one match result'; END IF;
 UPDATE public.bookings SET matchup_closed_at=timezone('utc',now()) WHERE id=p_booking_id;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'closed_at',timezone('utc',now()),'total_results_recorded',v_results_count);
END $$;
