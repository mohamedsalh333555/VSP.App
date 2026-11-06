-- Staging-only security regression: uses an existing active challenge booking.
-- Run as a privileged test operator. Simulated auth.uid() claims are NOT
-- a substitute for two real authenticated client sessions.
-- This script does not insert, update, or delete application rows.
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
  RAISE NOTICE 'PASS: cross-user collision and same-user replay';
END $test$;
