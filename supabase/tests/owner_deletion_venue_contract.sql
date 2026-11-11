-- Isolated synthetic fixture; all changes are rolled back.
-- Cover active venues, archived venues with a pending future booking,
-- and finally an archived venue whose owner can be removed.
BEGIN;
DO $test$
<<owner_deletion_fixture>>
DECLARE
  owner_id uuid := gen_random_uuid();
  customer_id uuid := gen_random_uuid();
  venue_id uuid := gen_random_uuid();
  booking_id uuid := gen_random_uuid();
  slot_start timestamptz := now() + interval '2 days';
  result jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (owner_id, owner_id::text || '@owner.invalid'),
    (customer_id, customer_id::text || '@customer.invalid');
  INSERT INTO public.users(id,role) VALUES
    (owner_id,'owner'), (customer_id,'player');
  INSERT INTO public.stadiums(id,owner_id,name,location,governorate,price_per_hour,base_price)
    VALUES(venue_id,owner_id,'Fixture','Fixture','Aswan',100,100);

  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',owner_id)::text,true);
  SET LOCAL ROLE authenticated;
  result := public.delete_user_permanently(owner_id);
  IF result->>'error' IS DISTINCT FROM 'ACTIVE_OWNER_STADIUMS' THEN
    RAISE EXCEPTION 'Active venue guard failed: %',result;
  END IF;
  RESET ROLE;

  UPDATE public.stadiums SET is_deleted_by_owner=true WHERE id=venue_id;
  INSERT INTO public.bookings(
    id,stadium_id,owner_id,user_id,created_by_user_id,start_time,end_time,
    total_price,payment_method,payment_source,payment_status,is_paid,
    deposit_paid,status
  ) VALUES (
    booking_id,venue_id,owner_id,customer_id,customer_id,slot_start,
    slot_start+interval '1 hour',100,'cash','cash','pending',false,0,'pending'
  );
  SET LOCAL ROLE authenticated;
  result := public.delete_user_permanently(owner_id);
  IF result->>'error' IS DISTINCT FROM 'ACTIVE_OWNER_STADIUMS' THEN
    RAISE EXCEPTION 'Future booking on archived venue guard failed: %',result;
  END IF;
  RESET ROLE;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=owner_id) THEN
    RAISE EXCEPTION 'Denied owner deletion unexpectedly removed auth account';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.bookings b
    WHERE b.id=booking_id AND b.status='pending'
      AND b.stadium_id=venue_id
      AND b.owner_id=owner_deletion_fixture.owner_id
  ) THEN
    RAISE EXCEPTION 'Denied owner deletion changed pending booking';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.stadiums st
    WHERE st.id=venue_id AND st.owner_id=owner_deletion_fixture.owner_id
      AND st.is_deleted_by_owner IS TRUE
  ) THEN
    RAISE EXCEPTION 'Denied owner deletion changed archived venue';
  END IF;

  -- A confirmed future reservation must also block deletion.
  UPDATE public.bookings SET status='confirmed' WHERE id=booking_id;
  SET LOCAL ROLE authenticated;
  result := public.delete_user_permanently(owner_id);
  IF result->>'error' IS DISTINCT FROM 'ACTIVE_OWNER_STADIUMS' THEN
    RAISE EXCEPTION 'Confirmed future booking guard failed: %',result;
  END IF;
  RESET ROLE;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=owner_id)
     OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=owner_id) THEN
    RAISE EXCEPTION 'Confirmed booking guard removed owner account';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.bookings b
    WHERE b.id=booking_id AND b.status='confirmed'
      AND b.stadium_id=venue_id AND b.owner_id=owner_deletion_fixture.owner_id
  ) THEN
    RAISE EXCEPTION 'Denied owner deletion changed confirmed booking';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.stadiums st
    WHERE st.id=venue_id AND st.owner_id=owner_deletion_fixture.owner_id
      AND st.is_deleted_by_owner IS TRUE
  ) THEN
    RAISE EXCEPTION 'Confirmed booking guard changed archived venue';
  END IF;

  DELETE FROM public.bookings WHERE id=booking_id;
  SET LOCAL ROLE authenticated;
  result := public.delete_user_permanently(owner_id);
  IF result->>'auth_user_deleted' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Archived venue owner deletion failed: %',result;
  END IF;
  RESET ROLE;
  IF EXISTS(SELECT 1 FROM auth.users WHERE id=owner_id)
     OR EXISTS(SELECT 1 FROM public.users WHERE id=owner_id) THEN
    RAISE EXCEPTION 'Owner account remains';
  END IF;
  -- Keep the runner's final zero-account fixture invariant.
  DELETE FROM public.users WHERE id=customer_id;
  DELETE FROM auth.users WHERE id=customer_id;
END;
$test$;
ROLLBACK;
