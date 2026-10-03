-- Collective bookings are host-paid and must be settled online in full.
-- Production applied as migration 20261003182200_collective_full_online_payment.

CREATE OR REPLACE FUNCTION public.prepare_collective_booking_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_token text;
  v_code text;
  v_payment_method text;
BEGIN
  IF NEW.booking_type='open_join' THEN
    v_payment_method:=lower(trim(coalesce(NEW.payment_method,'')));

    IF v_payment_method NOT IN ('paymob','card','wallet','online') THEN
      RAISE EXCEPTION 'COLLECTIVE_REQUIRES_FULL_ONLINE_PAYMENT';
    END IF;

    NEW.is_private:=true;
    NEW.pending_user_ids:=ARRAY[]::text[];
    NEW.needs_deposit:=false;
    NEW.deposit_amount:=0;
    NEW.deposit_paid:=0;
    NEW.payment_method:='paymob';
    NEW.payment_status:=CASE WHEN NEW.status='confirmed' AND NEW.is_paid=true THEN 'paid' ELSE 'pending' END;

    IF TG_OP='INSERT' THEN
      NEW.manual_player_count:=GREATEST(COALESCE(NEW.initial_players_count,NEW.current_players,1)-1,0);
    ELSE
      NEW.manual_player_count:=GREATEST(COALESCE(NEW.manual_player_count,0),0);
    END IF;

    IF NEW.collective_invite_token IS NULL OR btrim(NEW.collective_invite_token)='' THEN
      LOOP
        v_token:=encode(gen_random_bytes(18),'hex');
        EXIT WHEN NOT EXISTS(SELECT 1 FROM public.bookings b WHERE b.collective_invite_token=v_token);
      END LOOP;
      NEW.collective_invite_token:=v_token;
    END IF;

    IF NEW.collective_invite_code IS NULL OR btrim(NEW.collective_invite_code)='' THEN
      LOOP
        v_code:=upper(substr(encode(gen_random_bytes(8),'hex'),1,10));
        EXIT WHEN NOT EXISTS(SELECT 1 FROM public.bookings b WHERE b.collective_invite_code=v_code);
      END LOOP;
      NEW.collective_invite_code:=v_code;
    END IF;

    NEW.collective_invite_active:=(NEW.status='confirmed' AND (NEW.payment_status='paid' OR NEW.payment_status='partially_paid'));
    NEW.current_players:=COALESCE(cardinality(COALESCE(NEW.joined_user_ids,ARRAY[]::uuid[])),0)+COALESCE(NEW.manual_player_count,0);

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
