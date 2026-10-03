-- Canonical Collective Match hardening.
-- Production applied: 20261003180000_collective_match_state_model_hardening_v4

CREATE OR REPLACE FUNCTION public.prepare_collective_booking_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_token text;
  v_code text;
BEGIN
  IF NEW.booking_type='open_join' THEN
    NEW.is_private:=true;
    NEW.pending_user_ids:=ARRAY[]::text[];

    IF TG_OP='INSERT' THEN
      NEW.manual_player_count:=GREATEST(
        COALESCE(NEW.initial_players_count,NEW.current_players,1)-1,0
      );
    ELSE
      NEW.manual_player_count:=GREATEST(COALESCE(NEW.manual_player_count,0),0);
    END IF;

    IF NEW.collective_invite_token IS NULL OR btrim(NEW.collective_invite_token)='' THEN
      LOOP
        v_token:=encode(gen_random_bytes(18),'hex');
        EXIT WHEN NOT EXISTS(
          SELECT 1 FROM public.bookings b WHERE b.collective_invite_token=v_token
        );
      END LOOP;
      NEW.collective_invite_token:=v_token;
    END IF;

    IF NEW.collective_invite_code IS NULL OR btrim(NEW.collective_invite_code)='' THEN
      LOOP
        v_code:=upper(substr(encode(gen_random_bytes(8),'hex'),1,10));
        EXIT WHEN NOT EXISTS(
          SELECT 1 FROM public.bookings b WHERE b.collective_invite_code=v_code
        );
      END LOOP;
      NEW.collective_invite_code:=v_code;
    END IF;

    NEW.collective_invite_active:=(NEW.status='confirmed');

    NEW.current_players:=
      COALESCE(cardinality(COALESCE(NEW.joined_user_ids,ARRAY[]::uuid[])),0)
      + COALESCE(NEW.manual_player_count,0);

    IF TG_OP='UPDATE'
       AND COALESCE(current_setting('vsp.system_override',true),'')<>'true'
       AND (
         NEW.joined_user_ids IS DISTINCT FROM OLD.joined_user_ids OR
         NEW.manual_player_count IS DISTINCT FROM OLD.manual_player_count OR
         NEW.current_players IS DISTINCT FROM OLD.current_players OR
         NEW.collective_invite_token IS DISTINCT FROM OLD.collective_invite_token OR
         NEW.collective_invite_code IS DISTINCT FROM OLD.collective_invite_code
       ) THEN
      RAISE EXCEPTION 'COLLECTIVE_FIELDS_ARE_SERVER_MANAGED';
    END IF;
  ELSE
    NEW.manual_player_count:=0;
    NEW.collective_invite_token:=NULL;
    NEW.collective_invite_code:=NULL;
    NEW.collective_invite_active:=false;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_prepare_collective_booking_fields ON public.bookings;
CREATE TRIGGER trg_prepare_collective_booking_fields
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.prepare_collective_booking_fields();

CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE' then
    delete from public.booking_public_feed where id=old.id;
    return old;
  end if;

  if new.is_private=false
     and new.booking_type<>'open_join'
     and new.status in ('pending','confirmed','completed') then
    insert into public.booking_public_feed (
      id,stadium_id,stadium_name,stadium_image_url,start_time,end_time,operational_date,
      booking_type,player_team_id,player_team_name,player_team_logo_url,host_name,host_avatar_url,
      opponent_team_id,opponent_team_name,opponent_team_logo_url,is_private,rent_ball,total_price,currency,
      status,match_result_status,home_score,away_score,final_outcome,current_players,players_per_team,
      total_field_capacity,matchup_mode,matchup_closed_at,created_at,updated_at
    ) values (
      new.id,new.stadium_id,new.stadium_name,new.stadium_image_url,new.start_time,new.end_time,new.operational_date,
      new.booking_type,new.player_team_id,new.player_team_name,new.player_team_logo_url,new.host_name,new.host_avatar_url,
      new.opponent_team_id,new.opponent_team_name,new.opponent_team_logo_url,new.is_private,new.rent_ball,new.total_price,new.currency,
      new.status,new.match_result_status,new.home_score,new.away_score,new.final_outcome,new.current_players,new.max_players,
      new.total_field_capacity,new.matchup_mode,new.matchup_closed_at,new.created_at,new.updated_at
    )
    on conflict(id) do update set updated_at=excluded.updated_at;
  else
    delete from public.booking_public_feed where id=new.id;
  end if;
  return new;
end;
$function$;

DROP FUNCTION IF EXISTS public.leave_private_collective_match_atomic(uuid,uuid);
CREATE OR REPLACE FUNCTION public.leave_private_collective_match_atomic(p_booking_id uuid,p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_booking public.bookings%rowtype; v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL OR v_uid<>p_user_id THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;
  SELECT * INTO v_booking FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_booking.status IN('completed','cancelled','expired') OR v_booking.end_time<=timezone('utc',now()) THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED';
  END IF;
  IF v_booking.created_by_user_id=v_uid THEN RAISE EXCEPTION 'HOST_CANNOT_LEAVE'; END IF;
  IF NOT(v_uid=ANY(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) THEN RAISE EXCEPTION 'NOT_JOINED'; END IF;
  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings SET joined_user_ids=array_remove(joined_user_ids,v_uid),updated_at=timezone('utc',now()) WHERE id=p_booking_id;
  RETURN true;
END;
$function$;

DROP FUNCTION IF EXISTS public.remove_private_collective_participant_atomic(uuid,uuid);
CREATE OR REPLACE FUNCTION public.remove_private_collective_participant_atomic(p_booking_id uuid,p_participant_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_booking public.bookings%rowtype; v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid<>v_booking.created_by_user_id AND v_uid<>v_booking.owner_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;
  IF p_participant_id=v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_CANNOT_BE_REMOVED'; END IF;
  IF v_booking.status IN('cancelled','completed','expired') OR v_booking.end_time<=timezone('utc',now()) THEN RAISE EXCEPTION 'MATCH_NOT_EDITABLE'; END IF;
  IF NOT(p_participant_id=ANY(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) THEN RAISE EXCEPTION 'NOT_JOINED'; END IF;
  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings SET joined_user_ids=array_remove(joined_user_ids,p_participant_id),updated_at=timezone('utc',now()) WHERE id=p_booking_id;
  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.request_join_public_match(text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.leave_public_match_atomic(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.update_host_spots_atomic(uuid,uuid,integer) FROM PUBLIC,anon,authenticated;
