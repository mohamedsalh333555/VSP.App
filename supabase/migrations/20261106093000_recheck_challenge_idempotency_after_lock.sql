-- Challenge booking replay must be rechecked after the per-stadium transaction lock.
-- Patch the currently installed function body rather than restoring an obsolete
-- full definition; abort if its expected shape has changed.
DO $migration$
DECLARE
  v_oid oid;
  v_definition text;
  v_anchor text := 'PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));';
  v_patch text := $patch$
  -- Recheck after serialization: a concurrent transaction may have inserted
  -- the same idempotency key while this transaction waited for the lock.
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT id, status, user_id
      INTO v_existing_id, v_existing_status, v_existing_user_id
    FROM public.bookings
    WHERE idempotency_key = trim(p_idempotency_key)
      AND status <> 'cancelled'
    LIMIT 1;
    IF FOUND THEN
      IF v_caller IS NULL OR v_existing_user_id IS DISTINCT FROM v_caller THEN
        RETURN jsonb_build_object(
          'success', false, 'error', 'IDEMPOTENCY_KEY_COLLISION'
        );
      END IF;
      RETURN jsonb_build_object(
        'success', true, 'booking_id', v_existing_id,
        'status', v_existing_status, 'idempotent', true
      );
    END IF;
  END IF;
$patch$;
BEGIN
  SELECT p.oid, pg_get_functiondef(p.oid)
    INTO v_oid, v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'create_challenge_booking_atomic'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_challenge_code text, p_stadium_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_payment_method text, p_rent_ball boolean, p_idempotency_key text';
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Expected challenge booking function signature missing';
  END IF;
  IF (length(v_definition) - length(replace(v_definition, v_anchor, '')))
      / length(v_anchor) <> 1 THEN
    RAISE EXCEPTION 'Challenge booking lock anchor missing or ambiguous';
  END IF;
  IF position('v_existing_user_id' IN v_definition) = 0
      OR position('IDEMPOTENCY_KEY_COLLISION' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Challenge replay ownership guard is missing; manual audit required';
  END IF;
  IF position('Recheck after serialization:' IN v_definition) > 0 THEN
    RETURN;
  END IF;
  EXECUTE replace(v_definition, v_anchor, v_anchor || E'\n' || v_patch);
END;
$migration$;
