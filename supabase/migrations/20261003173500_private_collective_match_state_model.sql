ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS manual_player_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS collective_invite_token text,
  ADD COLUMN IF NOT EXISTS collective_invite_code text,
  ADD COLUMN IF NOT EXISTS collective_invite_active boolean NOT NULL DEFAULT true;

DO $$
DECLARE
  r record;
  v_token text;
  v_code text;
  v_manual integer;
BEGIN
  FOR r IN
    SELECT id, current_players, initial_players_count, joined_user_ids, status
    FROM public.bookings
    WHERE booking_type = 'open_join'
  LOOP
    v_manual := GREATEST(
      COALESCE(r.current_players, r.initial_players_count, 1)
      - COALESCE(cardinality(r.joined_user_ids), 0),
      0
    );
    LOOP
      v_token := encode(gen_random_bytes(18), 'hex');
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.bookings b WHERE b.collective_invite_token = v_token
      );
    END LOOP;
    LOOP
      v_code := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10));
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.bookings b WHERE b.collective_invite_code = v_code
      );
    END LOOP;
    UPDATE public.bookings
    SET
      is_private = true,
      manual_player_count = v_manual,
      current_players = COALESCE(cardinality(joined_user_ids), 0) + v_manual,
      collective_invite_token = COALESCE(collective_invite_token, v_token),
      collective_invite_code = COALESCE(collective_invite_code, v_code),
      collective_invite_active = status NOT IN ('cancelled','completed','expired'),
      updated_at = timezone('utc', now())
    WHERE id = r.id;
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_bookings_collective_invite_token
  ON public.bookings(collective_invite_token)
  WHERE collective_invite_token IS NOT NULL AND btrim(collective_invite_token) <> '';

CREATE UNIQUE INDEX IF NOT EXISTS ux_bookings_collective_invite_code
  ON public.bookings(collective_invite_code)
  WHERE collective_invite_code IS NOT NULL AND btrim(collective_invite_code) <> '';

CREATE OR REPLACE FUNCTION public.prepare_collective_booking_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_token text;
  v_code text;
BEGIN
  IF NEW.booking_type = 'open_join' THEN
    NEW.is_private := true;
    NEW.pending_user_ids := ARRAY[]::text[];
    NEW.manual_player_count := GREATEST(
      COALESCE(
        NEW.manual_player_count,
        COALESCE(NEW.current_players, NEW.initial_players_count, 1) - 1
      ),
      0
    );

    IF NEW.collective_invite_token IS NULL OR btrim(NEW.collective_invite_token) = '' THEN
      LOOP
        v_token := encode(gen_random_bytes(18), 'hex');
        EXIT WHEN NOT EXISTS (
          SELECT 1 FROM public.bookings b WHERE b.collective_invite_token = v_token
        );
      END LOOP;
      NEW.collective_invite_token := v_token;
    END IF;

    IF NEW.collective_invite_code IS NULL OR btrim(NEW.collective_invite_code) = '' THEN
      LOOP
        v_code := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10));
        EXIT WHEN NOT EXISTS (
          SELECT 1 FROM public.bookings b WHERE b.collective_invite_code = v_code
        );
      END LOOP;
      NEW.collective_invite_code := v_code;
    END IF;

    NEW.collective_invite_active := CASE
      WHEN NEW.status IN ('cancelled','completed','expired') THEN false
      ELSE COALESCE(NEW.collective_invite_active, true)
    END CASE;

    NEW.current_players :=
      COALESCE(cardinality(COALESCE(NEW.joined_user_ids, ARRAY[]::uuid[])), 0)
      + COALESCE(NEW.manual_player_count, 0);

    IF TG_OP = 'UPDATE'
       AND COALESCE(current_setting('vsp.system_override', true), '') <> 'true'
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
    NEW.manual_player_count := 0;
    NEW.collective_invite_token := NULL;
    NEW.collective_invite_code := NULL;
    NEW.collective_invite_active := false;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_prepare_collective_booking_fields ON public.bookings;
CREATE TRIGGER trg_prepare_collective_booking_fields
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.prepare_collective_booking_fields();

DELETE FROM public.booking_public_feed WHERE booking_type = 'open_join';

CREATE OR REPLACE FUNCTION public.get_private_collective_match_details(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid := auth.uid();
  v_stadium public.stadiums%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id AND booking_type = 'open_join' AND is_private = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;

  IF v_uid <> v_booking.created_by_user_id
     AND v_uid <> v_booking.owner_id
     AND NOT (v_uid = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'COLLECTIVE_MATCH_ACCESS_DENIED';
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id = v_booking.stadium_id;
  RETURN jsonb_build_object(
    'id', v_booking.id,
    'stadium_id', v_booking.stadium_id,
    'stadium_name', v_booking.stadium_name,
    'stadium_image_url', v_booking.stadium_image_url,
    'stadium_location', v_stadium.location,
    'stadium_city', v_stadium.city,
    'stadium_governorate', v_stadium.governorate,
    'stadium_features', COALESCE(v_stadium.features, '{}'::jsonb),
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'operational_date', v_booking.operational_date,
    'booking_type', v_booking.booking_type,
    'host_name', v_booking.host_name,
    'host_avatar_url', v_booking.host_avatar_url,
    'is_private', true,
    'rent_ball', v_booking.rent_ball,
    'total_price', v_booking.total_price,
    'currency', v_booking.currency,
    'payment_method', v_booking.payment_method,
    'payment_status', v_booking.payment_status,
    'status', v_booking.status,
    'current_players', COALESCE(v_booking.current_players, 0),
    'manual_player_count', COALESCE(v_booking.manual_player_count, 0),
    'total_field_capacity', COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10),
    'created_by_user_id', v_booking.created_by_user_id,
    'owner_id', v_booking.owner_id,
    'joined_user_ids', COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]),
    'collective_invite_active', COALESCE(v_booking.collective_invite_active, false)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_private_collective_invite_details(p_invite_token text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_stadium public.stadiums%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE collective_invite_token = lower(trim(COALESCE(p_invite_token,'')))
    AND booking_type = 'open_join' AND is_private = true
    AND COALESCE(collective_invite_active, true) = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_FOUND'; END IF;
  IF v_booking.status IN ('cancelled','completed','expired')
     OR v_booking.end_time <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_AVAILABLE';
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id = v_booking.stadium_id;
  RETURN jsonb_build_object(
    'id', v_booking.id,
    'invite_token', v_booking.collective_invite_token,
    'stadium_id', v_booking.stadium_id,
    'stadium_name', v_booking.stadium_name,
    'stadium_image_url', v_booking.stadium_image_url,
    'stadium_location', v_stadium.location,
    'stadium_city', v_stadium.city,
    'stadium_governorate', v_stadium.governorate,
    'stadium_features', COALESCE(v_stadium.features, '{}'::jsonb),
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'operational_date', v_booking.operational_date,
    'booking_type', v_booking.booking_type,
    'host_name', v_booking.host_name,
    'host_avatar_url', v_booking.host_avatar_url,
    'is_private', true,
    'rent_ball', v_booking.rent_ball,
    'total_price', v_booking.total_price,
    'currency', v_booking.currency,
    'payment_method', v_booking.payment_method,
    'payment_status', v_booking.payment_status,
    'status', v_booking.status,
    'current_players', COALESCE(v_booking.current_players, 0),
    'manual_player_count', COALESCE(v_booking.manual_player_count, 0),
    'total_field_capacity', COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10),
    'joined_user_ids', COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]),
    'collective_invite_code', v_booking.collective_invite_code
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_private_collective_invite_by_code(p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_stadium public.stadiums%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE collective_invite_code = upper(trim(COALESCE(p_invite_code,'')))
    AND booking_type = 'open_join' AND is_private = true
    AND COALESCE(collective_invite_active, true) = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_FOUND'; END IF;
  IF v_booking.status IN ('cancelled','completed','expired')
     OR v_booking.end_time <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_AVAILABLE';
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id = v_booking.stadium_id;
  RETURN jsonb_build_object(
    'id', v_booking.id,
    'invite_token', v_booking.collective_invite_token,
    'stadium_id', v_booking.stadium_id,
    'stadium_name', v_booking.stadium_name,
    'stadium_image_url', v_booking.stadium_image_url,
    'stadium_location', v_stadium.location,
    'stadium_city', v_stadium.city,
    'stadium_governorate', v_stadium.governorate,
    'stadium_features', COALESCE(v_stadium.features, '{}'::jsonb),
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'host_name', v_booking.host_name,
    'host_avatar_url', v_booking.host_avatar_url,
    'total_price', v_booking.total_price,
    'currency', v_booking.currency,
    'payment_method', v_booking.payment_method,
    'payment_status', v_booking.payment_status,
    'status', v_booking.status,
    'current_players', COALESCE(v_booking.current_players, 0),
    'manual_player_count', COALESCE(v_booking.manual_player_count, 0),
    'total_field_capacity', COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10),
    'joined_user_ids', COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]),
    'collective_invite_code', v_booking.collective_invite_code
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_collective_invite_credentials(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking public.bookings%ROWTYPE; v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;
  SELECT * INTO v_booking FROM public.bookings
  WHERE id = p_booking_id AND booking_type='open_join' AND is_private=true;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid <> v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;
  RETURN jsonb_build_object(
    'booking_id', v_booking.id,
    'invite_token', v_booking.collective_invite_token,
    'invite_code', v_booking.collective_invite_code,
    'active', COALESCE(v_booking.collective_invite_active, false),
    'status', v_booking.status
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.join_private_collective_match_atomic(
  p_invite_token text, p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_stadium public.stadiums%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_capacity integer;
  v_joined_count integer;
  v_player_gov text;
  v_stadium_gov text;
  v_conflict integer;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF v_uid IS NULL OR v_uid <> p_user_id THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE collective_invite_token = lower(trim(COALESCE(p_invite_token,'')))
    AND booking_type='open_join' AND is_private=true
    AND COALESCE(collective_invite_active,true)=true
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_FOUND'; END IF;
  IF v_booking.status='cancelled' THEN RAISE EXCEPTION 'MATCH_CANCELLED'; END IF;
  IF v_booking.status='completed' THEN RAISE EXCEPTION 'MATCH_COMPLETED'; END IF;
  IF v_booking.end_time<=v_now THEN RAISE EXCEPTION 'MATCH_EXPIRED'; END IF;
  IF v_booking.status<>'confirmed' THEN RAISE EXCEPTION 'MATCH_AWAITING_HOST_PAYMENT'; END IF;

  SELECT * INTO v_user FROM public.users WHERE id=v_uid;
  IF COALESCE(v_user.is_blocked,false) THEN RAISE EXCEPTION 'USER_BLOCKED'; END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id=v_booking.stadium_id;
  v_player_gov := NULLIF(trim(v_user.governorate),'');
  v_stadium_gov := NULLIF(trim(v_stadium.governorate),'');
  IF v_player_gov IS NULL OR v_stadium_gov IS NULL THEN
    RAISE EXCEPTION 'GOVERNORATE_NOT_VERIFIED';
  END IF;
  IF public.normalize_governorate(v_player_gov) <> public.normalize_governorate(v_stadium_gov) THEN
    RAISE EXCEPTION 'COLLECTIVE_GOVERNORATE_MISMATCH';
  END IF;

  v_capacity := COALESCE(v_booking.total_field_capacity,v_booking.max_players,10);
  v_joined_count := COALESCE(cardinality(v_booking.joined_user_ids),0);
  IF COALESCE(v_booking.current_players,v_joined_count+COALESCE(v_booking.manual_player_count,0)) >= v_capacity THEN
    RAISE EXCEPTION 'MATCH_IS_FULL';
  END IF;
  IF v_uid=ANY(COALESCE(v_booking.joined_user_ids,ARRAY[]::uuid[])) THEN
    RAISE EXCEPTION 'ALREADY_JOINED';
  END IF;

  SELECT COUNT(*) INTO v_conflict
  FROM public.bookings b
  WHERE b.id<>v_booking.id AND b.status<>'cancelled'
    AND (b.created_by_user_id=v_uid OR v_uid=ANY(COALESCE(b.joined_user_ids,ARRAY[]::uuid[])))
    AND b.start_time<v_booking.end_time AND b.end_time>v_booking.start_time;
  IF v_conflict>0 THEN RAISE EXCEPTION 'TIME_CONFLICT'; END IF;

  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings
  SET joined_user_ids=array_append(COALESCE(joined_user_ids,ARRAY[]::uuid[]),v_uid),
      updated_at=v_now
  WHERE id=v_booking.id;

  RETURN jsonb_build_object('success',true,'booking_id',v_booking.id,
    'current_players',COALESCE(v_booking.current_players,0)+1,
    'manual_player_count',COALESCE(v_booking.manual_player_count,0),
    'host_user_id',v_booking.created_by_user_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_collective_manual_players_atomic(
  p_booking_id uuid, p_user_id uuid, p_manual_player_count integer
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid := auth.uid();
  v_joined_count integer;
  v_capacity integer;
  v_total integer;
  v_now timestamptz := timezone('utc',now());
BEGIN
  IF v_uid IS NULL OR v_uid<>p_user_id THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;
  IF p_manual_player_count<0 THEN RAISE EXCEPTION 'INVALID_MANUAL_PLAYER_COUNT'; END IF;

  SELECT * INTO v_booking FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid<>v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;
  IF v_booking.status IN ('cancelled','completed','expired') OR v_booking.end_time<=v_now THEN
    RAISE EXCEPTION 'MATCH_NOT_EDITABLE';
  END IF;

  v_joined_count:=COALESCE(cardinality(v_booking.joined_user_ids),0);
  v_capacity:=COALESCE(v_booking.total_field_capacity,v_booking.max_players,10);
  v_total:=v_joined_count+p_manual_player_count;
  IF v_total<1 THEN RAISE EXCEPTION 'INVALID_COLLECTIVE_TOTAL'; END IF;
  IF v_total>v_capacity THEN RAISE EXCEPTION 'EXCEEDS_TOTAL_STADIUM_CAPACITY'; END IF;

  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings
  SET manual_player_count=p_manual_player_count,
      current_players=v_total,
      updated_at=v_now
  WHERE id=p_booking_id;

  RETURN jsonb_build_object(
    'success',true,'booking_id',p_booking_id,
    'manual_player_count',p_manual_player_count,
    'joined_players_count',v_joined_count,
    'current_players',v_total,
    'remaining_players',v_capacity-v_total
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_private_match_invite_details(uuid) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.request_join_public_match(text,text) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.update_host_spots_atomic(uuid,uuid,integer) FROM PUBLIC,anon,authenticated;

REVOKE EXECUTE ON FUNCTION public.get_private_collective_match_details(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_private_collective_match_details(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_private_collective_invite_details(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_private_collective_invite_details(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_private_collective_invite_by_code(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_private_collective_invite_by_code(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_collective_invite_credentials(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_collective_invite_credentials(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.join_private_collective_match_atomic(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.join_private_collective_match_atomic(text,uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.update_collective_manual_players_atomic(uuid,uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.update_collective_manual_players_atomic(uuid,uuid,integer) TO authenticated;