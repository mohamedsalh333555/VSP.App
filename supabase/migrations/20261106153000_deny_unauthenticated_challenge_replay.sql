-- Deny idempotent replay unless the authenticated caller owns the booking.
-- Fail closed if the expected deployed function differs.
DO $migration$
DECLARE
  v_definition text;
  v_old text := 'IF v_existing_user_id IS NOT NULL AND v_caller IS NOT NULL AND v_existing_user_id <> v_caller THEN';
  v_new text := 'IF v_caller IS NULL OR v_existing_user_id IS DISTINCT FROM v_caller THEN';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'create_challenge_booking_atomic'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_challenge_code text, p_stadium_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_payment_method text, p_rent_ball boolean, p_idempotency_key text';
  IF v_definition IS NULL THEN RAISE EXCEPTION 'Challenge booking RPC not found'; END IF;
  IF position(v_new IN v_definition) > 0 AND position(v_old IN v_definition) = 0 THEN RETURN; END IF;
  IF (length(v_definition)-length(replace(v_definition,v_old,'')))/length(v_old) <> 1
    THEN RAISE EXCEPTION 'Unexpected replay ownership guard; audit required'; END IF;
  EXECUTE replace(v_definition,v_old,v_new);
END;
$migration$;
