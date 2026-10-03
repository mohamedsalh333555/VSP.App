CREATE OR REPLACE FUNCTION public.leave_private_collective_match_atomic(
  p_booking_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
    AND booking_type = 'open_join'
    AND is_private = true
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_booking.status IN ('completed','cancelled','expired') THEN RAISE EXCEPTION 'LEAVE_BLOCKED'; END IF;
  IF v_booking.end_time <= timezone('utc', now()) THEN RAISE EXCEPTION 'LEAVE_BLOCKED'; END IF;
  IF v_booking.created_by_user_id = p_user_id THEN RAISE EXCEPTION 'HOST_CANNOT_LEAVE'; END IF;
  IF NOT (p_user_id = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'NOT_JOINED';
  END IF;

  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings
  SET joined_user_ids = array_remove(joined_user_ids, p_user_id),
      updated_at = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.remove_private_collective_participant_atomic(
  p_booking_id uuid,
  p_participant_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
    AND booking_type = 'open_join'
    AND is_private = true
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid <> v_booking.created_by_user_id AND v_uid <> v_booking.owner_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;
  IF v_booking.status IN ('completed','cancelled','expired') OR v_booking.end_time <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'MATCH_NOT_EDITABLE';
  END IF;
  IF p_participant_id = v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_CANNOT_BE_REMOVED'; END IF;
  IF NOT (p_participant_id = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'PARTICIPANT_NOT_FOUND';
  END IF;

  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings
  SET joined_user_ids = array_remove(joined_user_ids, p_participant_id),
      updated_at = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.leave_private_collective_match_atomic(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_private_collective_match_atomic(uuid,uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.remove_private_collective_participant_atomic(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.remove_private_collective_participant_atomic(uuid,uuid) TO authenticated;
