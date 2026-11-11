-- Staging only. All fixtures and writes are rolled back; no real accounts read.
BEGIN;
DO $$
DECLARE
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); e uuid := gen_random_uuid();
  conv uuid := gen_random_uuid(); msg uuid := gen_random_uuid();
BEGIN
  PERFORM set_config('test.vsp_a', a::text, true);
  PERFORM set_config('test.vsp_b', b::text, true);
  PERFORM set_config('test.vsp_c', c::text, true);
  PERFORM set_config('test.vsp_d', d::text, true);
  PERFORM set_config('test.vsp_e', e::text, true);
  PERFORM set_config('test.vsp_conv', conv::text, true);
  PERFORM set_config('test.vsp_msg', msg::text, true);
  INSERT INTO auth.users(id,email) SELECT u, u::text || '@compliance.invalid' FROM unnest(ARRAY[a,b,c,d,e]) u;
  INSERT INTO public.users(id,role,is_registration_complete,accumulated_cash_debt)
    VALUES (a,'player',false,0),(b,'player',true,0),(c,'player',null,0),
           (d,'player',false,1),(e,'player',false,0);
  INSERT INTO public.conversations(id,participant_ids,unread_counts)
    VALUES (conv,ARRAY[a,b],jsonb_build_object(a::text,2,b::text,3));
  INSERT INTO public.chat_messages(id,conversation_id,sender_id,sender_name,text,is_read)
    VALUES (msg,conv,b,'Synthetic test','Synthetic message',false);
END;
$$;
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.cancel_incomplete_registration_atomic(current_setting('test.vsp_a')::uuid);
    RAISE EXCEPTION 'FAIL anonymous cleanup allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.mark_chat_messages_as_read(current_setting('test.vsp_conv')::uuid,current_setting('test.vsp_a')::uuid);
    RAISE EXCEPTION 'FAIL anonymous read allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated"}',true);
DO $$ DECLARE r jsonb; BEGIN
  r := public.cancel_incomplete_registration_atomic(current_setting('test.vsp_a')::uuid);
  IF r->>'error' IS DISTINCT FROM 'AUTHENTICATION_REQUIRED' THEN RAISE EXCEPTION 'FAIL missing identity'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.vsp_c'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r := public.cancel_incomplete_registration_atomic(current_setting('test.vsp_b')::uuid);
  IF r->>'error' IS DISTINCT FROM 'UNAUTHORIZED' THEN RAISE EXCEPTION 'FAIL cross-account cleanup'; END IF;
  r := public.cancel_incomplete_registration_atomic(current_setting('test.vsp_c')::uuid);
  IF r->>'error' IS DISTINCT FROM 'REGISTRATION_NOT_INCOMPLETE' THEN RAISE EXCEPTION 'FAIL unknown completion'; END IF;
  BEGIN
    PERFORM public.mark_chat_messages_as_read(current_setting('test.vsp_conv')::uuid,current_setting('test.vsp_c')::uuid);
    RAISE EXCEPTION 'FAIL nonmember read allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.mark_chat_messages_as_read(current_setting('test.vsp_conv')::uuid,current_setting('test.vsp_a')::uuid);
    RAISE EXCEPTION 'FAIL impersonated read allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT is_read FROM public.chat_messages WHERE id=current_setting('test.vsp_msg')::uuid) IS DISTINCT FROM false
     OR (SELECT unread_counts->>current_setting('test.vsp_a') FROM public.conversations WHERE id=current_setting('test.vsp_conv')::uuid) IS DISTINCT FROM '2'
  THEN RAISE EXCEPTION 'FAIL denied request modified messages or counters'; END IF;
END; $$;
-- Simulates a stale client: server completion wins before cancellation arrives.
UPDATE public.users SET is_registration_complete=true WHERE id=current_setting('test.vsp_a')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.vsp_a'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r := public.cancel_incomplete_registration_atomic(current_setting('test.vsp_a')::uuid);
  IF r->>'error' IS DISTINCT FROM 'REGISTRATION_NOT_INCOMPLETE' THEN RAISE EXCEPTION 'FAIL stale profile deleted'; END IF;
  PERFORM public.mark_chat_messages_as_read(current_setting('test.vsp_conv')::uuid,current_setting('test.vsp_a')::uuid);
  PERFORM public.mark_chat_messages_as_read(current_setting('test.vsp_conv')::uuid,current_setting('test.vsp_a')::uuid);
  BEGIN
    PERFORM public.mark_chat_messages_as_read(null,current_setting('test.vsp_a')::uuid);
    RAISE EXCEPTION 'FAIL null conversation allowed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.mark_chat_messages_as_read(gen_random_uuid(),current_setting('test.vsp_a')::uuid);
    RAISE EXCEPTION 'FAIL missing conversation allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.vsp_d'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r := public.cancel_incomplete_registration_atomic(current_setting('test.vsp_d')::uuid);
  IF r->>'error' IS DISTINCT FROM 'OUTSTANDING_DEBT' THEN RAISE EXCEPTION 'FAIL debt guard bypassed'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.vsp_e'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r := public.cancel_incomplete_registration_atomic(current_setting('test.vsp_e')::uuid);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL incomplete cancellation: %',r; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT (SELECT is_read FROM public.chat_messages WHERE id=current_setting('test.vsp_msg')::uuid)
    OR (SELECT unread_counts->>current_setting('test.vsp_a') FROM public.conversations WHERE id=current_setting('test.vsp_conv')::uuid) IS DISTINCT FROM '0'
    OR (SELECT unread_counts->>current_setting('test.vsp_b') FROM public.conversations WHERE id=current_setting('test.vsp_conv')::uuid) IS DISTINCT FROM '3'
  THEN RAISE EXCEPTION 'FAIL authorized read/counter isolation'; END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE id=current_setting('test.vsp_e')::uuid)
     OR EXISTS (SELECT 1 FROM public.users WHERE id=current_setting('test.vsp_e')::uuid)
  THEN RAISE EXCEPTION 'FAIL incomplete account not deleted'; END IF;
  IF (SELECT count(*) FROM public.users WHERE id=ANY(ARRAY[current_setting('test.vsp_a')::uuid,current_setting('test.vsp_b')::uuid,current_setting('test.vsp_c')::uuid,current_setting('test.vsp_d')::uuid])) <> 4
  THEN RAISE EXCEPTION 'FAIL protected fixture was deleted'; END IF;
END; $$;
SELECT 'PASS: cleanup authorization/completion/debt/deletion and conversation authorization/idempotency/counter isolation; transaction rolled back' AS result;
ROLLBACK;
