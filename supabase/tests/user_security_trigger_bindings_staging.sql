-- Staging only: synthetic account, transaction always rolled back.
BEGIN;
DO $$ DECLARE u uuid:=gen_random_uuid(); BEGIN
  PERFORM set_config('test.guard_uid',u::text,true);
  INSERT INTO auth.users(id,email) VALUES(u,u::text||'@guard.compliance.invalid');
  INSERT INTO public.users(id,role,is_registration_complete,accumulated_cash_debt)
    VALUES(u,'owner',false,5);
END; $$;
-- The email sync fixture trigger uses a transaction-local system flag.
-- Clear it before emulating a separate authenticated client request.
SELECT set_config('vsp.system_override','false',true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.guard_uid'))::text,true);
DO $$ DECLARE statement text; BEGIN
  FOREACH statement IN ARRAY ARRAY[
    'role=''admin''','subscription_plan=''pro''',
    'accumulated_cash_debt=0','is_registration_complete=true'
  ] LOOP
    BEGIN
      EXECUTE 'UPDATE public.users SET '||statement||' WHERE id=$1'
        USING current_setting('test.guard_uid')::uuid;
      RAISE EXCEPTION 'FAIL sensitive update allowed: %',statement;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
  FOREACH statement IN ARRAY ARRAY[
    'phone=''01000000001''','p2p_bank=''synthetic-bank''',
    'p2p_instapay=''synthetic-instapay''','p2p_vodafone=''synthetic-vodafone'''
  ] LOOP
    BEGIN
      EXECUTE 'UPDATE public.users SET '||statement||' WHERE id=$1'
        USING current_setting('test.guard_uid')::uuid;
      RAISE EXCEPTION 'FAIL recent authentication bypassed: %',statement;
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'recent_password_verification_required' THEN RAISE; END IF;
    END;
  END LOOP;
  UPDATE public.users SET name='Synthetic allowed profile edit'
    WHERE id=current_setting('test.guard_uid')::uuid;
  IF NOT FOUND THEN RAISE EXCEPTION 'FAIL ordinary profile edit blocked'; END IF;
END; $$;
SELECT set_config('request.jwt.claims',jsonb_build_object(
  'role','authenticated','sub',current_setting('test.guard_uid'),
  'amr',jsonb_build_array(jsonb_build_object('method','password','timestamp',extract(epoch from now())::bigint))
)::text,true);
DO $$ BEGIN
  UPDATE public.users SET p2p_bank='synthetic-recent-auth-bank'
    WHERE id=current_setting('test.guard_uid')::uuid;
  IF NOT FOUND THEN RAISE EXCEPTION 'FAIL recent authentication update blocked'; END IF;
END; $$;
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=current_setting('test.guard_uid')::uuid
    AND role='owner' AND accumulated_cash_debt=5 AND is_registration_complete=false
    AND subscription_plan IS DISTINCT FROM 'pro'
    AND name='Synthetic allowed profile edit'
    AND p2p_bank='synthetic-recent-auth-bank')
  THEN RAISE EXCEPTION 'FAIL final protected/allowed values'; END IF;
END; $$;
SELECT 'PASS: 8 denied sensitive updates, ordinary profile update, recent password update, final state; rollback' AS result;
ROLLBACK;
