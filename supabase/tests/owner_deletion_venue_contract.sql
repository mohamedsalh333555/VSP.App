BEGIN;
DO $test$
DECLARE owner_id uuid:=gen_random_uuid(); venue_id uuid:=gen_random_uuid(); result jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(owner_id,'owner@example.invalid');
  INSERT INTO public.users(id,role) VALUES(owner_id,'owner');
  INSERT INTO public.stadiums(id,owner_id,name,location,governorate,price_per_hour,base_price)
    VALUES(venue_id,owner_id,'Fixture','Fixture','Aswan',100,100);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',owner_id)::text,true);
  SET LOCAL ROLE authenticated;
  result:=public.delete_user_permanently(owner_id);
  IF result->>'error' IS DISTINCT FROM 'ACTIVE_OWNER_STADIUMS' THEN RAISE EXCEPTION 'Active venue guard failed: %',result; END IF;
  RESET ROLE;
  UPDATE public.stadiums SET is_deleted_by_owner=true WHERE id=venue_id;
  SET LOCAL ROLE authenticated;
  result:=public.delete_user_permanently(owner_id);
  IF result->>'auth_user_deleted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Archived venue owner deletion failed: %',result; END IF;
  RESET ROLE;
  IF EXISTS(SELECT FROM auth.users u WHERE u.id=owner_id) OR EXISTS(SELECT FROM public.users u WHERE u.id=owner_id) THEN RAISE EXCEPTION 'Owner account remains'; END IF;
END;
$test$;
ROLLBACK;
