-- Compatibility probe uses only synthetic accounts and transaction-local grants.
-- Never read or mutate existing customer accounts.
BEGIN;
DO $$ DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); BEGIN
  PERFORM set_config('test.role_player',a::text,true);
  PERFORM set_config('test.role_admin',b::text,true);
  PERFORM set_config('test.role_target',c::text,true);
  INSERT INTO auth.users(id,email) SELECT u,u::text||'@role.compliance.invalid' FROM unnest(ARRAY[a,b,c]) u;
  INSERT INTO public.users(id,role) VALUES(b,'admin');
END; $$;
-- Emulate old production table grants without changing deployed grants.
GRANT INSERT ON public.users TO authenticated;
SELECT set_config('vsp.system_override','false',true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.role_player'))::text,true);
DO $$ BEGIN
  BEGIN
    INSERT INTO public.users(id,role) VALUES(current_setting('test.role_player')::uuid,'admin');
    RAISE EXCEPTION 'FAIL privileged legacy insert';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'CLIENT_PROFILE_ROLE_FORBIDDEN' THEN RAISE; END IF;
  END;
  INSERT INTO public.users(id,role) VALUES(current_setting('test.role_player')::uuid,'player');
  BEGIN
    UPDATE public.users SET role='owner' WHERE id=current_setting('test.role_player')::uuid;
    RAISE EXCEPTION 'FAIL direct player role change';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'CLIENT_PROFILE_ROLE_CHANGE_FORBIDDEN' THEN RAISE; END IF;
  END;
END; $$;
DO $$ DECLARE r jsonb; BEGIN
  r:=public.set_user_role_on_signup('owner',current_setting('test.role_player')::uuid);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL authorized signup role RPC'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.role_admin'))::text,true);
DO $$ BEGIN
  BEGIN
    UPDATE public.users SET role='co_founder' WHERE id=current_setting('test.role_admin')::uuid;
    RAISE EXCEPTION 'FAIL admin escalated role';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'CLIENT_PROFILE_ROLE_CHANGE_FORBIDDEN' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO public.users(id,role) VALUES(current_setting('test.role_target')::uuid,'super_admin');
    RAISE EXCEPTION 'FAIL admin bypassed role creation RPC';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'CLIENT_PROFILE_ROLE_FORBIDDEN' THEN RAISE; END IF;
  END;
  -- Existing admin creation of ordinary profiles remains supported.
  INSERT INTO public.users(id,role) VALUES(current_setting('test.role_target')::uuid,'owner');
  UPDATE public.users SET last_warning='Synthetic moderation' WHERE id=current_setting('test.role_target')::uuid;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.role_player')::uuid AND role='owner')
     OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.role_admin')::uuid AND role='admin')
     OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.role_target')::uuid AND role='owner' AND last_warning='Synthetic moderation')
  THEN RAISE EXCEPTION 'FAIL role compatibility final state'; END IF;
END; $$;
SELECT 'PASS client role guard: privileged INSERT and direct role UPDATE denied, signup RPC and ordinary admin provisioning/moderation preserved' AS result;
ROLLBACK;
