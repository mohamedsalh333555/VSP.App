-- Run only on the VSP staging project. Synthetic RPC inputs; no booking is
-- inserted, and the surrounding transaction rolls back.
BEGIN;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
DO $test$
DECLARE
  s record;
  t timestamptz;
  r jsonb;
  v_key text := 'synthetic-price-mismatch-' || gen_random_uuid()::text;
  v_expected numeric;
  v_found boolean := false;
BEGIN
  FOR s IN SELECT * FROM public.stadiums
    WHERE is_verified=true AND coalesce(is_blocked,false)=false
      AND coalesce(is_deleted_by_owner,false)=false
      AND coalesce(price_per_hour,base_price,0)>0
    ORDER BY id LIMIT 5
  LOOP
    FOR t IN SELECT generate_series(now()+interval '2 days',
                                    now()+interval '4 days',
                                    interval '30 minutes')
    LOOP
      IF public.vsp_validate_stadium_booking_window(
        s.opening_time,s.closing_time,s.break_start_time,s.break_end_time,
        s.is_split_shift,s.maintenance_until,t,t+interval '1 hour'
      ) THEN
        v_expected := round(coalesce(s.price_per_hour,s.base_price,0),2);
        r := public.create_booking_atomic(
          s.id::text, gen_random_uuid()::text, s.owner_id::text,
          t,t+interval '1 hour','personal',v_expected+1000,
          p_payment_method=>'paymob',p_idempotency_key=>v_key
        );
        IF r->>'code' IS DISTINCT FROM 'PRICE_MISMATCH'
           OR (r->>'expected_total_price')::numeric IS DISTINCT FROM v_expected
           OR EXISTS(SELECT 1 FROM public.bookings WHERE idempotency_key=v_key)
        THEN
          RAISE EXCEPTION 'STAGING_PRICE_GUARD_FAILED: %', r;
        END IF;
        v_found := true;
        EXIT;
      END IF;
    END LOOP;
    EXIT WHEN v_found;
  END LOOP;
  IF NOT v_found THEN RAISE EXCEPTION 'NO_ELIGIBLE_STAGING_WINDOW'; END IF;
  RAISE NOTICE 'PASS: stale price rejected before booking insert';
END;
$test$;
ROLLBACK;
