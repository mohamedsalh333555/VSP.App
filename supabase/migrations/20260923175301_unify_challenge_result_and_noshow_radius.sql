-- Align the live payment-fee SSOT with the approved Paymob contract.
UPDATE public.platform_fee_config
SET
  booking_vsp_rate = 0.020000,
  booking_paymob_rate = 0.027500,
  booking_paymob_local_rate = 0.027500,
  booking_paymob_wallet_rate = 0.027500,
  booking_paymob_foreign_rate = 0.027500,
  booking_paymob_fixed_fee = 3.00,
  updated_at = timezone('utc', now())
WHERE id = 1;

CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(
  p_booking_id uuid, p_team_id uuid, p_outcome text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking RECORD; v_team RECORD; v_role text;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres','service_role') THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_outcome NOT IN ('homeWin','draw','awayWin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_OUTCOME');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_NOT_FOUND');
  END IF;
  IF v_booking.booking_type NOT IN ('challenge','team','matchup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_COMPETITIVE_BOOKING');
  END IF;
  IF v_booking.end_time > v_now THEN
    RETURN jsonb_build_object('success', false, 'error', 'MATCH_NOT_FINISHED');
  END IF;
  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_CANCELLED');
  END IF;
  IF p_team_id::text NOT IN (
    COALESCE(v_booking.player_team_id::text,''), COALESCE(v_booking.opponent_team_id::text,'')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_IN_BOOKING');
  END IF;

  IF current_user NOT IN ('postgres','service_role') THEN
    SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
    IF COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
      IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
      END IF;
    END IF;
  END IF;

  IF COALESCE(v_booking.match_result_status,'noResult')='noResult'
     OR v_booking.result_submitted_by_team_id=p_team_id THEN
    PERFORM set_config('vsp.system_override','true',true);
    UPDATE public.bookings SET
      pending_outcome=p_outcome,
      result_submitted_by_team_id=p_team_id,
      match_result_status='waitingOpponent',
      requires_admin_intervention=false,
      final_outcome=NULL,
      updated_at=v_now
    WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'state','waitingOpponent','finalized',false,'pending_outcome',p_outcome);
  END IF;

  IF v_booking.pending_outcome=p_outcome THEN
    PERFORM set_config('vsp.system_override','true',true);
    UPDATE public.bookings SET
      final_outcome=p_outcome,
      match_result_status='confirmed',
      status='completed',
      requires_admin_intervention=false,
      pending_outcome=NULL,
      result_submitted_by_team_id=NULL,
      updated_at=v_now
    WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'state','confirmed','finalized',true,'final_outcome',p_outcome);
  END IF;

  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings SET
    match_result_status='disputed',
    requires_admin_intervention=true,
    updated_at=v_now
  WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',false,'state','disputed','requires_admin_intervention',true,'error','RESULT_DISPUTED');
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.dispute_no_show_with_gps(
  p_booking_id text, p_player_id text, p_lat numeric, p_lng numeric, p_accuracy numeric
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_booking record; v_stadium record; v_distance_meters numeric;
  v_player_uuid uuid; v_booking_uuid uuid;
BEGIN
  BEGIN
    v_player_uuid:=p_player_id::uuid; v_booking_uuid:=p_booking_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_UUID_FORMAT: Invalid player or booking identifier' USING ERRCODE='22P02';
  END;

  IF COALESCE(auth.role(),'')!='service_role'
     AND NOT (auth.uid() IS NULL AND session_user IN ('postgres','supabase_admin')) THEN
    IF auth.uid() IS NULL OR auth.uid()!=v_player_uuid THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: You can only dispute penalties for your own account.' USING ERRCODE='42501';
    END IF;
  END IF;

  IF p_accuracy<0 OR p_accuracy>50 THEN RAISE EXCEPTION 'gps_accuracy_too_low'; END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id=v_booking_uuid;
  IF NOT FOUND THEN RAISE EXCEPTION 'booking_not_found'; END IF;
  IF v_booking.user_id!=v_player_uuid
     AND v_booking.created_by_user_id!=v_player_uuid
     AND NOT (v_player_uuid::text=ANY(COALESCE(v_booking.joined_user_ids::text[],ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Player was not a registered participant in this booking.' USING ERRCODE='42501';
  END IF;
  IF timezone('utc',now())>(v_booking.end_time+INTERVAL '60 minutes') THEN
    RAISE EXCEPTION 'dispute_window_expired';
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id=v_booking.stadium_id;
  IF v_stadium.lat IS NULL OR v_stadium.lng IS NULL THEN RAISE EXCEPTION 'stadium_coordinates_missing'; END IF;

  v_distance_meters:=6371000*acos(LEAST(1.0,GREATEST(-1.0,
    cos(radians(v_stadium.lat))*cos(radians(p_lat))*
    cos(radians(p_lng)-radians(v_stadium.lng))+
    sin(radians(v_stadium.lat))*sin(radians(p_lat))
  )));
  IF v_distance_meters>200 THEN RAISE EXCEPTION 'not_at_stadium'; END IF;

  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.users SET
    no_show_count=GREATEST(0,no_show_count-1),
    is_blocked=false,
    cash_booking_banned=CASE WHEN GREATEST(0,no_show_count-1)>=2 THEN true ELSE false END,
    updated_at=timezone('utc',now())
  WHERE id=v_player_uuid;

  UPDATE public.bookings SET
    is_dispute_approved=true,
    match_result_status='confirmed',
    updated_at=timezone('utc',now())
  WHERE id=v_booking_uuid;
  RETURN true;
END;
$function$;

