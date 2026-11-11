-- Staging only. No customer data selected; all fixture writes roll back.
BEGIN;
DO $$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); BEGIN
  PERFORM set_config('test.provision_player',a::text,true);
  PERFORM set_config('test.provision_owner',b::text,true);
  INSERT INTO auth.users(id,email,raw_user_meta_data)
    VALUES(a,a::text||'@provision.invalid','{"role":"admin","full_name":"Synthetic profile"}'::jsonb),
          (b,b::text||'@provision.invalid','{}'::jsonb);
END; $$;
SELECT set_config('vsp.system_override','false',true);
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN PERFORM public.provision_registration_profile('player');
    RAISE EXCEPTION 'FAIL anon provisioning';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated"}',true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.provision_registration_profile('player');
  IF r->>'error' IS DISTINCT FROM 'AUTHENTICATION_REQUIRED' THEN RAISE EXCEPTION 'FAIL missing identity'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',gen_random_uuid())::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.provision_registration_profile('player');
  IF r->>'error' IS DISTINCT FROM 'AUTH_USER_NOT_FOUND' THEN RAISE EXCEPTION 'FAIL deleted auth user'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.provision_player'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.provision_registration_profile('admin');
  IF r->>'error' IS DISTINCT FROM 'INVALID_ROLE' THEN RAISE EXCEPTION 'FAIL privileged role'; END IF;
  r:=public.provision_registration_profile(NULL);
  IF r->>'error' IS DISTINCT FROM 'INVALID_ROLE' THEN RAISE EXCEPTION 'FAIL null role'; END IF;
  BEGIN
    INSERT INTO public.users(id,role) VALUES(current_setting('test.provision_player')::uuid,'admin');
    RAISE EXCEPTION 'FAIL direct privileged profile insert';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  r:=public.provision_registration_profile('player');
  IF r->'success' IS DISTINCT FROM 'true'::jsonb OR r->'created' IS DISTINCT FROM 'true'::jsonb THEN
    RAISE EXCEPTION 'FAIL player provision: %',r; END IF;
  IF current_setting('vsp.system_override',true) IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'FAIL leaked system override'; END IF;
  r:=public.provision_registration_profile('owner');
  IF r->'created' IS DISTINCT FROM 'false'::jsonb THEN RAISE EXCEPTION 'FAIL replay resets existing profile'; END IF;
  BEGIN
    DELETE FROM public.users WHERE id=current_setting('test.provision_player')::uuid;
    RAISE EXCEPTION 'FAIL direct profile deletion';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.provision_player')::uuid
     AND role='player' AND is_email_verified=false AND is_registration_complete=false
     AND subscription_plan='free' AND trial_ends_at IS NULL AND name='Synthetic profile')
  THEN RAISE EXCEPTION 'FAIL metadata privilege/verification/trial escalation or replay'; END IF;
END; $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.provision_owner'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.provision_registration_profile('owner');
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL owner provision'; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.provision_owner')::uuid
     AND role='owner' AND subscription_plan='expired' AND trial_ends_at IS NULL)
  THEN RAISE EXCEPTION 'FAIL canonical owner trial policy'; END IF;
END; $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.provision_player'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.cancel_incomplete_registration_atomic(current_setting('test.provision_player')::uuid);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL explicit server cancellation after revoke: %',r; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM auth.users WHERE id=current_setting('test.provision_player')::uuid)
     OR EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.provision_player')::uuid)
  THEN RAISE EXCEPTION 'FAIL deleted profile remains'; END IF;
END; $$;
SELECT 'PASS provisioning: anon/missing/deleted identity, invalid roles, direct insert/delete denial, explicit success, metadata/verification/trial boundaries, replay, canonical owner plan, server deletion, override restoration' AS result;
ROLLBACK;
