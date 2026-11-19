-- ISOLATED FIXTURE ONLY: not a production installer or real OAuth test.
BEGIN;
DO $$ DECLARE r text; a uuid; BEGIN
  FOREACH r IN ARRAY ARRAY['blocked_admin','admin','owner','co_founder','missing'] LOOP
    a:=gen_random_uuid(); PERFORM set_config('test.policy.'||r,a::text,true);
    INSERT INTO auth.users(id,email) VALUES(a,a::text||'@policy-contract.invalid');
    IF r<>'missing' THEN INSERT INTO public.users(id,role,is_blocked)
      VALUES(a,CASE WHEN r='blocked_admin' THEN 'admin' ELSE r END,r='blocked_admin'); END IF;
  END LOOP;
  INSERT INTO public.app_config(id,is_maintenance) VALUES(900001,false);
  INSERT INTO public.platform_business_rules(id,booking_min_duration_minutes) VALUES(900001,60);
  INSERT INTO public.owner_documents(id,owner_id,status) VALUES
    (gen_random_uuid(),current_setting('test.policy.owner')::uuid,'pending'),
    (gen_random_uuid(),current_setting('test.policy.blocked_admin')::uuid,'pending');
  INSERT INTO storage.objects(id,bucket_id,name,owner) VALUES
    (gen_random_uuid(),'owner_documents',current_setting('test.policy.owner')||'/private.pdf',current_setting('test.policy.owner')::uuid),
    (gen_random_uuid(),'owner_documents',current_setting('test.policy.blocked_admin')||'/own.pdf',current_setting('test.policy.blocked_admin')::uuid);
  INSERT INTO public.vsp_1v1_tournament_players(id,user_id,payment_status) VALUES
    (gen_random_uuid(),current_setting('test.policy.owner')::uuid,'pending'),
    (gen_random_uuid(),current_setting('test.policy.owner')::uuid,'paid');
END; $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.policy.blocked_admin'))::text,true);
DO $$ DECLARE n integer; BEGIN
  BEGIN
    UPDATE public.users SET is_blocked=false WHERE id=auth.uid();
    RAISE EXCEPTION 'FAIL blocked administrator unblocked self';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM NOT LIKE 'PERMISSION_DENIED:%' THEN RAISE; END IF;
  END;
  UPDATE public.app_config SET is_maintenance=true WHERE id=900001;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL blocked admin changed application configuration'; END IF;
  UPDATE public.platform_business_rules SET booking_min_duration_minutes=5 WHERE id=900001;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL blocked admin changed business rules'; END IF;
  IF (SELECT count(*) FROM public.owner_documents)<>1 THEN RAISE EXCEPTION 'FAIL blocked admin document read isolation'; END IF;
  UPDATE public.owner_documents SET status='approved'; GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL blocked admin document moderation'; END IF;
  IF (SELECT count(*) FROM storage.objects)<>1 THEN RAISE EXCEPTION 'FAIL blocked admin storage read isolation'; END IF;
  DELETE FROM storage.objects WHERE owner=current_setting('test.policy.owner')::uuid;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL blocked admin deleted another owner object'; END IF;
  BEGIN
    INSERT INTO storage.objects(id,bucket_id,name,owner) VALUES(gen_random_uuid(),'banners','blocked-banner.png',auth.uid());
    RAISE EXCEPTION 'FAIL blocked admin banner upload';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  IF (SELECT count(*) FROM public.vsp_1v1_tournament_players)<>1 THEN
    RAISE EXCEPTION 'FAIL blocked admin sees unpaid participant or public paid row hidden';
  END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.policy.owner'))::text,true);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.owner_documents)<>1 OR (SELECT count(*) FROM storage.objects)<>1 THEN
    RAISE EXCEPTION 'FAIL ordinary owner read compatibility'; END IF;
  INSERT INTO public.owner_documents(id,owner_id,status) VALUES(gen_random_uuid(),auth.uid(),'pending');
  INSERT INTO storage.objects(id,bucket_id,name,owner) VALUES(gen_random_uuid(),'owner_documents',auth.uid()::text||'/new.pdf',auth.uid());
  INSERT INTO public.championships(id,owner_id,is_approved,name,type,start_date,end_date,entry_fee,grand_prize,governorate)
  VALUES(gen_random_uuid(),auth.uid(),false,'Synthetic ownership test','private',now()+interval '1 day',now()+interval '2 days',0,0,'Aswan');
END; $$;
DO $$ DECLARE r text; n integer; BEGIN
  FOREACH r IN ARRAY ARRAY['admin','co_founder'] LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.policy.'||r))::text,true);
    UPDATE public.app_config SET is_maintenance=true WHERE id=900001;
    GET DIAGNOSTICS n=ROW_COUNT;
    IF n<>1 THEN RAISE EXCEPTION 'FAIL active admin configuration compatibility'; END IF;
    UPDATE public.platform_business_rules SET booking_min_duration_minutes=45 WHERE id=900001;
    GET DIAGNOSTICS n=ROW_COUNT;
    IF n<>1 THEN RAISE EXCEPTION 'FAIL active admin scalar-role compatibility'; END IF;
    IF (SELECT count(*) FROM public.owner_documents)<>3 THEN RAISE EXCEPTION 'FAIL active admin document read'; END IF;
  END LOOP;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.policy.missing'))::text,true);
DO $$ DECLARE n integer; BEGIN
  UPDATE public.app_config SET is_maintenance=false WHERE id=900001;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 OR EXISTS(SELECT 1 FROM public.owner_documents) THEN RAISE EXCEPTION 'FAIL missing-profile policy access'; END IF;
END; $$;
RESET ROLE;
SELECT 'PASS blocked admin self-unblock/RLS/storage rejected, ownership/public branches and active admins preserved' AS result;
ROLLBACK;
