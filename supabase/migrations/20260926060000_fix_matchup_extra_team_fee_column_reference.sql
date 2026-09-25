-- Fix the matchup extra-team payment lookup to use the actual transactions.type column.
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
  SELECT EXISTS(SELECT 1 FROM public.transactions WHERE booking_id=p_booking_id AND type='matchup_extra_teams_fee' AND status IN ('paid','completed')) INTO v_paid;
  IF NOT v_paid THEN RAISE EXCEPTION 'LIMIT_REACHED_EXTRA_FEE_REQUIRED: Adding more than 5 teams requires 25 EGP extra fee'; END IF;
 END IF;
 INSERT INTO public.matchup_teams(booking_id,team_id,added_by_user_id,joined_at) VALUES(p_booking_id,v_target_team.id,v_caller_id,timezone('utc',now()));
 UPDATE public.teams SET active_invite_code=NULL,invite_code_expires_at=NULL WHERE id=v_target_team.id;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'team_id',v_target_team.id,'team_name',v_target_team.name,'logo_url',v_target_team.logo_url,'total_teams_now',v_current_count+1);
END $$;
GRANT EXECUTE ON FUNCTION public.add_team_to_matchup_by_code(uuid,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.add_team_to_matchup_by_code(uuid,text) FROM anon,public;
