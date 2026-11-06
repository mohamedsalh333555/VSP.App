-- Staging-only security regression: uses an existing active challenge booking.
-- Run as a privileged test operator. Simulated auth.uid() claims are NOT
-- a substitute for two real authenticated client sessions.
-- This script does not insert, update, or delete application rows.
-- Validate RPC grants independently of privileged test session JWT claims.
DO $grants$
DECLARE v_rpc oid;
BEGIN
  SELECT p.oid INTO v_rpc FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'create_challenge_booking_atomic';
  IF v_rpc IS NULL THEN RAISE EXCEPTION 'Challenge booking RPC missing'; END IF;
  IF has_function_privilege('anon', v_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute challenge booking RPC';
  END IF;
  IF NOT has_function_privilege('authenticated', v_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated role cannot execute challenge booking RPC';
  END IF;
  IF NOT has_function_privilege('service_role', v_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Service role cannot execute challenge booking RPC';
  END IF;
  RAISE NOTICE 'PASS: challenge RPC role grants';
END $grants$;

DO $test$
DECLARE
  v_booking record;
  v_result jsonb;
  v_other uuid := '00000000-0000-4000-8000-000000000001'::uuid;
BEGIN
  SELECT id, user_id, idempotency_key INTO v_booking
  FROM public.bookings
  WHERE booking_type = 'challenge'
    AND idempotency_key IS NOT NULL
    AND status <> 'cancelled'
  LIMIT 1;

  IF NOT FOUND OR v_booking.user_id IS NULL OR v_booking.user_id = v_other THEN
    RAISE EXCEPTION 'No safe challenge replay fixture available';
  END IF;

  -- Privileged invocation without JWT claims must not disclose a booking.
  PERFORM set_config('request.jwt.claim.sub', '', true);
  v_result := public.create_challenge_booking_atomic(
    'invalid', '00000000-0000-0000-0000-000000000000',
    now(), now() + interval '1 hour', 'cash', false,
    v_booking.idempotency_key
  );
  IF v_result->>'error' IS DISTINCT FROM 'IDEMPOTENCY_KEY_COLLISION'
     OR v_result ? 'booking_id' THEN
    RAISE EXCEPTION 'Unauthenticated replay guard failed';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  v_result := public.create_challenge_booking_atomic(
    'invalid', '00000000-0000-0000-0000-000000000000',
    now(), now() + interval '1 hour', 'cash', false,
    v_booking.idempotency_key
  );
  IF v_result->>'error' IS DISTINCT FROM 'IDEMPOTENCY_KEY_COLLISION'
     OR v_result ? 'booking_id' THEN
    RAISE EXCEPTION 'Cross-user replay guard failed';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_booking.user_id::text, true);
  v_result := public.create_challenge_booking_atomic(
    'invalid', '00000000-0000-0000-0000-000000000000',
    now(), now() + interval '1 hour', 'cash', false,
    v_booking.idempotency_key
  );
  IF v_result->>'booking_id' IS DISTINCT FROM v_booking.id::text
     OR v_result->>'idempotent' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Same-user replay failed';
  END IF;
  RAISE NOTICE 'PASS: missing JWT, cross-user collision, and same-user replay';
END $test$;
