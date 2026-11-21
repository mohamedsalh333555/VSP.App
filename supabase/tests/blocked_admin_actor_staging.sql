-- STAGING ONLY. Synthetic DB claims/metadata, not GoTrue or real file upload.
-- Everything, including the optional synthetic bucket, rolls back.
BEGIN;
DO $$ DECLARE a uuid; r text; BEGIN
  FOREACH r IN ARRAY ARRAY['blocked','admin','owner'] LOOP
    a:=gen_random_uuid(); PERFORM set_config('test.active_admin.'||r,a::text,true);
    INSERT INTO auth.users(id,email) VALUES(a,a::text||'@blocked-admin-acceptance.invalid');
    INSERT INTO public.users(id,role,is_blocked) VALUES(a,CASE WHEN r='owner' THEN 'owner' WHEN r='admin' THEN 'co_founder' ELSE 'admin' END,r='blocked');
  END LOOP;
  INSERT INTO storage.buckets(id,name,public) VALUES('owner_documents','owner_documents',false) ON CONFLICT(id) DO NOTHING;
  a:=gen_random_uuid();PERFORM set_config('test.active_admin.other_object',a::text,true);
  INSERT INTO storage.objects(id,bucket_id,name,owner,owner_id)
    VALUES(a,'owner_documents',current_setting('test.active_admin.owner')||'/compliance-only.pdf',current_setting('test.active_admin.owner')::uuid,current_setting('test.active_admin.owner'));
  a:=gen_random_uuid();PERFORM set_config('test.active_admin.own_object',a::text,true);
  INSERT INTO storage.objects(id,bucket_id,name,owner,owner_id)
    VALUES(a,'owner_documents',current_setting('test.active_admin.blocked')||'/compliance-only.pdf',current_setting('test.active_admin.blocked')::uuid,current_setting('test.active_admin.blocked'));
END; $$;
SELECT set_config('vsp.system_override','false',true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.active_admin.blocked'))::text,true);
DO $$ BEGIN
  BEGIN
    UPDATE public.users SET is_blocked=false WHERE id=auth.uid();
    RAISE EXCEPTION 'FAIL staged blocked administrator unblocked self';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM NOT LIKE 'PERMISSION_DENIED:%' THEN RAISE; END IF;
  END;
  UPDATE public.users SET name='Synthetic profile edit' WHERE id=auth.uid();
  IF EXISTS(SELECT 1 FROM storage.objects WHERE id=current_setting('test.active_admin.other_object')::uuid) THEN
    RAISE EXCEPTION 'FAIL staged blocked admin reads another owner metadata'; END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE id=current_setting('test.active_admin.own_object')::uuid) THEN
    RAISE EXCEPTION 'FAIL staged own-file access compatibility'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.active_admin.owner'))::text,true);
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE id=current_setting('test.active_admin.other_object')::uuid) THEN
    RAISE EXCEPTION 'FAIL staged ordinary owner file access'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.active_admin.admin'))::text,true);
DO $$ DECLARE r jsonb; BEGIN
  r:=public.admin_toggle_user_block(current_setting('test.active_admin.blocked')::uuid,false);
  IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL staged active founder moderation'; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.active_admin.blocked')::uuid AND is_blocked=false AND name='Synthetic profile edit') THEN
    RAISE EXCEPTION 'FAIL staged active actor final state'; END IF;
END; $$;
SELECT 'PASS staged self-unblock/private-storage denial, own-file/profile compatibility and active founder moderation; all fixtures roll back' AS result;
ROLLBACK;
