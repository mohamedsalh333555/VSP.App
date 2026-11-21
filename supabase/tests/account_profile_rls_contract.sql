-- Isolated fixture accounts; exercise actual users policies under real SQL roles.
BEGIN;
DO $$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); BEGIN
  PERFORM set_config('test.rls_player',a::text,true);
  PERFORM set_config('test.rls_owner',b::text,true);
  PERFORM set_config('test.rls_admin',c::text,true);
  INSERT INTO auth.users(id,email) SELECT u,u::text||'@rls.compliance.invalid' FROM unnest(ARRAY[a,b,c]) u;
  INSERT INTO public.users(id,role,name) VALUES(a,'player','Player'),(b,'owner','Owner'),(c,'admin','Admin');
END; $$;
SELECT set_config('vsp.system_override','false',true);
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM id FROM public.users;
    RAISE EXCEPTION 'FAIL anonymous profile read allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.rls_player'))::text,true);
DO $$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.users;
  IF n<>1 OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.rls_player')::uuid)
  THEN RAISE EXCEPTION 'FAIL player profile read isolation'; END IF;
  UPDATE public.users SET name='Unauthorized edit' WHERE id=current_setting('test.rls_owner')::uuid;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL player edited owner'; END IF;
  UPDATE public.users SET name='Allowed player edit' WHERE id=current_setting('test.rls_player')::uuid;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>1 THEN RAISE EXCEPTION 'FAIL own edit blocked'; END IF;
  BEGIN
    UPDATE public.users SET id=current_setting('test.rls_owner')::uuid WHERE id=current_setting('test.rls_player')::uuid;
    RAISE EXCEPTION 'FAIL identity reassignment allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.rls_owner'))::text,true);
DO $$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.users;
  IF n<>1 OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.rls_owner')::uuid)
  THEN RAISE EXCEPTION 'FAIL owner profile read isolation'; END IF;
  UPDATE public.users SET name='Unauthorized owner edit' WHERE id=current_setting('test.rls_player')::uuid;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL owner edited player'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.rls_admin'))::text,true);
DO $$ DECLARE n integer; BEGIN
  SELECT count(*) INTO n FROM public.users;
  IF n<>3 THEN RAISE EXCEPTION 'FAIL legitimate admin read blocked'; END IF;
  UPDATE public.users SET last_warning='Synthetic admin warning' WHERE id=current_setting('test.rls_owner')::uuid;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>1 THEN RAISE EXCEPTION 'FAIL legitimate admin moderation blocked'; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.rls_player')::uuid AND name='Allowed player edit')
     OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.rls_owner')::uuid AND name='Owner' AND last_warning='Synthetic admin warning')
  THEN RAISE EXCEPTION 'FAIL authorized/denied final state'; END IF;
END; $$;
SELECT 'PASS users RLS: anonymous denial, player/owner read and write isolation, own edit, identity reassignment denial, legitimate admin read/moderation' AS result;
ROLLBACK;
