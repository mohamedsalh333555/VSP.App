-- STAGING ONLY: fresh synthetic owners, no production/global metrics or deletion.
BEGIN;
DO $$ DECLARE r text;a uuid;BEGIN
 FOREACH r IN ARRAY ARRAY['owner_a','owner_b','blocked_admin','admin','missing'] LOOP
  a:=gen_random_uuid();PERFORM set_config('test.legacy.'||r,a::text,true);
  INSERT INTO auth.users(id,email) VALUES(a,a::text||'@legacy-read-acceptance.invalid');
  IF r<>'missing' THEN INSERT INTO public.users(id,role,is_blocked)
   VALUES(a,CASE WHEN r LIKE 'owner_%' THEN 'owner' ELSE 'admin' END,r='blocked_admin');END IF;
 END LOOP;
END;$$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE actor text;target uuid; q text; r jsonb;BEGIN
 FOREACH actor IN ARRAY ARRAY['owner_b','blocked_admin','missing'] LOOP
  target:=CASE WHEN actor='missing' THEN current_setting('test.legacy.missing')::uuid ELSE current_setting('test.legacy.owner_a')::uuid END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.legacy.'||actor),'user_metadata',jsonb_build_object('role','admin'))::text,true);
  FOREACH q IN ARRAY ARRAY[
    format('SELECT public.get_owner_financial_summary(%L::uuid)',target),
    format('SELECT public.get_owner_ai_operational_insights(%L::uuid,''30d'')',target),
    format('SELECT public.get_owner_ai_stadium_comparison(%L::uuid,''30d'')',target)] LOOP
   BEGIN EXECUTE q;RAISE EXCEPTION 'FAIL staged legacy cross-owner/missing-profile report accepted';
   EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE;END IF;END;
  END LOOP;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY['owner_a','admin','blocked_admin'] LOOP
  target:=CASE WHEN actor='blocked_admin' THEN current_setting('test.legacy.blocked_admin')::uuid ELSE current_setting('test.legacy.owner_a')::uuid END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.legacy.'||actor))::text,true);
  FOREACH q IN ARRAY ARRAY[
    format('SELECT public.get_owner_financial_summary(%L::uuid)',target),
    format('SELECT public.get_owner_ai_operational_insights(%L::uuid,''30d'')',target),
    format('SELECT public.get_owner_ai_stadium_comparison(%L::uuid,''30d'')',target)] LOOP
   EXECUTE q INTO r;
   IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL staged own/active-admin report compatibility';END IF;
  END LOOP;
 END LOOP;
END;$$;
RESET ROLE;
SELECT 'PASS 9 staged report denials and9 own/active-admin compatibility calls; all synthetic rows roll back' AS result;
ROLLBACK;
