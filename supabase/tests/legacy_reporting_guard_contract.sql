-- ISOLATED FIXTURE ONLY. No production accounts or real OAuth/provider calls.
BEGIN;
DO $$ BEGIN
  IF has_function_privilege('anon','public.require_owner_or_active_admin_actor(uuid)','EXECUTE')
    OR has_function_privilege('authenticated','public.require_owner_or_active_admin_actor(uuid)','EXECUTE')
    OR has_function_privilege('service_role','public.require_owner_or_active_admin_actor(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL owner reporting helper directly exposed';
  END IF;
END; $$;
DO $$ DECLARE r text;a uuid;c uuid; BEGIN
  FOREACH r IN ARRAY ARRAY['owner_a','owner_b','admin','blocked_admin','victim','player','missing'] LOOP
    a:=gen_random_uuid();PERFORM set_config('test.reporting.'||r,a::text,true);
    INSERT INTO auth.users(id,email) VALUES(a,a::text||'@legacy-reporting.invalid');
    IF r<>'missing' THEN INSERT INTO public.users(id,role,is_blocked)
      VALUES(a,CASE WHEN r LIKE 'owner_%' THEN 'owner' WHEN r IN('admin','blocked_admin') THEN 'admin' ELSE 'player' END,r='blocked_admin');END IF;
  END LOOP;
  FOREACH r IN ARRAY ARRAY['owner_a','blocked_admin'] LOOP
    c:=gen_random_uuid();PERFORM set_config('test.reporting.champ_'||r,c::text,true);
    INSERT INTO public.championships(id,owner_id,name,type,start_date,end_date,entry_fee,grand_prize,governorate)
    VALUES(c,current_setting('test.reporting.'||r)::uuid,'Reporting fixture','private',now(),now()+interval '1 day',0,0,'Aswan');
  END LOOP;
  INSERT INTO public.transactions(id,amount,type,status) VALUES(gen_random_uuid(),17,'digital','completed');
END; $$;
GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid),public.get_owner_ai_operational_insights(uuid,text),public.get_owner_ai_stadium_comparison(uuid,text),public.get_admin_metrics(),public.get_admin_quick_metrics() TO anon;
-- The grant is transaction-local, exposing the inner authorization to the probe.
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
DO $$ DECLARE q text; BEGIN
  FOREACH q IN ARRAY ARRAY[
    'SELECT public.get_admin_metrics()', 'SELECT public.get_admin_quick_metrics()',
    'SELECT public.get_owner_financial_summary(NULL::uuid)',
    'SELECT public.get_owner_ai_operational_insights(NULL::uuid,''30d'')',
    'SELECT public.get_owner_ai_stadium_comparison(NULL::uuid,''30d'')'] LOOP
    BEGIN EXECUTE q; RAISE EXCEPTION 'FAIL anonymous legacy report accepted';
    EXCEPTION WHEN insufficient_privilege THEN
      IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
  END LOOP;
END; $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE actor text;target uuid:=current_setting('test.reporting.owner_a')::uuid;r jsonb; BEGIN
  FOREACH actor IN ARRAY ARRAY['owner_b','blocked_admin','player','missing'] LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.reporting.'||actor),'user_metadata',jsonb_build_object('role','admin'))::text,true);
    BEGIN PERFORM public.get_owner_financial_summary(target);RAISE EXCEPTION 'FAIL cross-owner financial report accepted';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE;END IF;END;
    BEGIN PERFORM public.get_owner_ai_operational_insights(target,'30d');RAISE EXCEPTION 'FAIL cross-owner operational report accepted';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE;END IF;END;
    BEGIN PERFORM public.get_owner_ai_stadium_comparison(target,'30d');RAISE EXCEPTION 'FAIL cross-owner stadium report accepted';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE;END IF;END;
    r:=public.get_tournament_financial_summary(current_setting('test.reporting.champ_owner_a')::uuid);
    IF r->'success' IS DISTINCT FROM 'false'::jsonb THEN RAISE EXCEPTION 'FAIL cross-owner tournament financial report accepted';END IF;
    r:=public.delete_user_permanently(current_setting('test.reporting.victim')::uuid);
    IF r->>'error' IS DISTINCT FROM 'UNAUTHORIZED' THEN RAISE EXCEPTION 'FAIL legacy unauthorized account deletion';END IF;
  END LOOP;
END; $$;
DO $$ DECLARE actor text;r jsonb;target uuid; BEGIN
  FOREACH actor IN ARRAY ARRAY['owner_a','admin'] LOOP
    target:=current_setting('test.reporting.owner_a')::uuid;
    PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.reporting.'||actor))::text,true);
    r:=public.get_owner_financial_summary(target);
    IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL own/admin financial report';END IF;
    r:=public.get_owner_ai_operational_insights(target,'30d');
    IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL own/admin operational report';END IF;
    r:=public.get_owner_ai_stadium_comparison(target,'30d');
    IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL own/admin stadium report';END IF;
    r:=public.get_tournament_financial_summary(current_setting('test.reporting.champ_owner_a')::uuid);
    IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL own/admin tournament report';END IF;
  END LOOP;
  r:=public.get_admin_metrics();
  IF NOT(r ? 'total_owners') THEN RAISE EXCEPTION 'FAIL active admin metrics';END IF;
  r:=public.get_admin_quick_metrics();
  IF (r->>'total_revenue')::numeric IS DISTINCT FROM 17::numeric THEN RAISE EXCEPTION 'FAIL active admin quick metrics';END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.reporting.blocked_admin'))::text,true);
DO $$ DECLARE r jsonb;q text; BEGIN
  FOREACH q IN ARRAY ARRAY['SELECT public.get_admin_metrics()','SELECT public.get_admin_quick_metrics()'] LOOP
    BEGIN EXECUTE q;RAISE EXCEPTION 'FAIL blocked admin metrics accepted';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE;END IF;END;
  END LOOP;
  r:=public.get_owner_financial_summary(auth.uid());
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL blocked own financial privacy access';END IF;
  r:=public.get_tournament_financial_summary(current_setting('test.reporting.champ_blocked_admin')::uuid);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL blocked own tournament access';END IF;
  r:=public.delete_user_permanently(auth.uid());
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL blocked own account deletion';END IF;
  BEGIN PERFORM public.get_owner_financial_summary(current_setting('test.reporting.blocked_admin')::uuid);
    RAISE EXCEPTION 'FAIL deleted-profile token read';
  EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE;END IF;END;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.reporting.admin'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.delete_user_permanently(current_setting('test.reporting.victim')::uuid);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL authorized other-account deletion';END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM auth.users WHERE id IN(current_setting('test.reporting.blocked_admin')::uuid,current_setting('test.reporting.victim')::uuid)) THEN
    RAISE EXCEPTION 'FAIL account deletion effects';END IF;
END; $$;
SELECT 'PASS legacy cross-owner/admin/deletion guards, own privacy/deletion and authorized admin behavior' AS result;
ROLLBACK;
