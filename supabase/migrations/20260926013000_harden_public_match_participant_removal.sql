-- Host/owner removal must not reuse the self-leave authorization RPC.
CREATE OR REPLACE FUNCTION public.remove_public_match_participant_atomic(p_booking_id uuid,p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_booking bookings%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF auth.uid()<>v_booking.created_by_user_id AND auth.uid()<>v_booking.owner_id THEN RAISE EXCEPTION 'Unauthorized: Only the host or stadium owner can remove a participant'; END IF;
 IF NOT (p_user_id=ANY(coalesce(v_booking.joined_user_ids,ARRAY[]::uuid[]))) THEN RAISE EXCEPTION 'User is not a joined participant'; END IF;
 UPDATE public.bookings SET joined_user_ids=array_remove(joined_user_ids,p_user_id),current_players=GREATEST(0,coalesce(current_players,0)-1),updated_at=timezone('utc',now()) WHERE id=p_booking_id;
 RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.remove_public_match_participant_atomic(uuid,uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.remove_public_match_participant_atomic(uuid,uuid) FROM anon,public;
