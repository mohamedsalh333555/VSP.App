-- Isolated fixture only. Claims are injected; this is not an OAuth test.
BEGIN;
DO $$ DECLARE a uuid; r text; BEGIN
  FOREACH r IN ARRAY ARRAY['player','owner','admin','blocked_admin','co_founder','cofounder','super_admin','missing'] LOOP
    a:=gen_random_uuid();
    PERFORM set_config('test.admin.'||r,a::text,true);
    INSERT INTO auth.users(id,email) VALUES(a,a::text||'@admin-contract.invalid');
    IF r<>'missing' THEN
      INSERT INTO public.users(id,role,is_blocked,no_show_count)
      VALUES(a,CASE WHEN r='blocked_admin' THEN 'admin' ELSE r END,r='blocked_admin',4);
    END IF;
  END LOOP;
END; $$;
-- Grants are transaction-local and disappear with ROLLBACK.
GRANT EXECUTE ON FUNCTION public.require_active_admin_actor() TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_owner_subscription_atomic(uuid,text,integer),
  public.admin_toggle_user_block(uuid,boolean),public.admin_reset_no_show_count_atomic(uuid) TO anon,authenticated,service_role;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{}',true);
DO $$ BEGIN
  BEGIN
    PERFORM public.require_active_admin_actor();
    RAISE EXCEPTION 'FAIL anonymous admin guard accepted';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE; END IF;
  END;
END; $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE r text; q text; BEGIN
  FOREACH r IN ARRAY ARRAY['player','owner','blocked_admin','missing','no_sub'] LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',
      CASE WHEN r='no_sub' THEN NULL ELSE current_setting('test.admin.'||r) END,
      'user_metadata',jsonb_build_object('role','service_role','is_admin',true))::text,true);
    BEGIN
      PERFORM public.require_active_admin_actor();
      RAISE EXCEPTION 'FAIL unauthorized admin guard accepted: %',r;
    EXCEPTION WHEN insufficient_privilege THEN
      IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    FOREACH q IN ARRAY ARRAY[
      'SELECT public.admin_set_owner_subscription_atomic(NULL::uuid,NULL::text,NULL::integer)',
      'SELECT public.admin_toggle_user_block(NULL::uuid,NULL::boolean)',
      'SELECT public.admin_reset_no_show_count_atomic(NULL::uuid)'] LOOP
      BEGIN
        EXECUTE q;
        RAISE EXCEPTION 'FAIL admin RPC precondition: % %',r,q;
      EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM<>'ADMIN_ACCESS_REQUIRED' THEN
          RAISE EXCEPTION 'FAIL admin RPC precondition: unexpected error %',SQLERRM;
        END IF;
      WHEN OTHERS THEN
        RAISE EXCEPTION 'FAIL admin RPC precondition: %',SQLERRM;
      END;
    END LOOP;
  END LOOP;
  FOREACH r IN ARRAY ARRAY['admin','co_founder','cofounder','super_admin'] LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.admin.'||r))::text,true);
    PERFORM public.require_active_admin_actor();
  END LOOP;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.admin.admin'))::text,true);
DO $$ DECLARE r jsonb; a uuid:=current_setting('test.admin.owner')::uuid; BEGIN
  r:=public.admin_set_owner_subscription_atomic(a,'pro',30);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL subscription positive'; END IF;
  r:=public.admin_toggle_user_block(a,true);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL block positive'; END IF;
  r:=public.admin_reset_no_show_count_atomic(a);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL reset positive'; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.admin.owner')::uuid
    AND subscription_plan='pro' AND subscription_expires_at>now() AND is_blocked AND no_show_count=0)
    OR NOT EXISTS(SELECT 1 FROM public.system_audit_logs WHERE record_id=current_setting('test.admin.owner')::uuid AND action='admin_block_user')
  THEN RAISE EXCEPTION 'FAIL admin positive persisted effects'; END IF;
END; $$;
SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SELECT public.require_active_admin_actor();
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',true);
SELECT public.require_active_admin_actor();
SELECT 'PASS active-admin predicate, three RPC preconditions and positive fixture effects' AS result;
ROLLBACK;
