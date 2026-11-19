-- ISOLATED FIXTURE ONLY. Source/claims/DB behavior, not real OAuth/provider calls.
BEGIN;
DO $$ BEGIN
 IF has_function_privilege('anon','public.vsp_is_trusted_server_actor()','EXECUTE')
 OR has_function_privilege('authenticated','public.vsp_require_registered_actor()','EXECUTE') THEN RAISE EXCEPTION 'FAIL booking helper directly exposed';END IF;
END;$$;
DO $$ DECLARE r text;a uuid;b uuid;at_time timestamptz:=date_trunc('day',now()+interval '2 days')+interval '10 hours';BEGIN
 FOREACH r IN ARRAY ARRAY['owner_a','owner_b','customer','intruder','new_customer','blocked_admin','admin','missing'] LOOP
  a:=gen_random_uuid();PERFORM set_config('test.booking12.'||r,a::text,true);
  INSERT INTO auth.users(id,email) VALUES(a,a::text||'@booking-actor.invalid');
  IF r<>'missing' THEN INSERT INTO public.users(id,role,is_blocked,is_registration_complete,p2p_instapay)
   VALUES(a,CASE WHEN r LIKE 'owner_%' THEN 'owner' WHEN r IN('blocked_admin','admin') THEN 'admin' ELSE 'player' END,r='blocked_admin',true,'synthetic@instapay');END IF;
 END LOOP;
 a:=gen_random_uuid();PERFORM set_config('test.booking12.stadium',a::text,true);
 INSERT INTO public.stadiums(id,owner_id,name,location,governorate,price_per_hour,base_price,is_verified,opening_time,closing_time)
 VALUES(a,current_setting('test.booking12.owner_a')::uuid,'Synthetic venue','Synthetic location','Aswan',100,100,true,'00:00','00:00');
 INSERT INTO public.platform_business_rules(id,booking_min_duration_minutes,booking_max_duration_hours,manual_booking_max_duration_hours,payment_lock_minutes,booking_past_grace_minutes,cash_no_show_limit,player_cancellation_grace_minutes,player_cancellation_cutoff_hours,late_cancellation_cutoff_hours)
 VALUES(1,60,2,4,10,15,3,20,6,6);
 PERFORM set_config('test.booking12.start',at_time::text,true);
 FOREACH r IN ARRAY ARRAY['cash','cancel','cancel_three','manual','no_show','cancelled','idempotent','online_earned'] LOOP
  b:=gen_random_uuid();PERFORM set_config('test.booking12.'||r,b::text,true);
  INSERT INTO public.bookings(id,stadium_id,owner_id,user_id,created_by_user_id,start_time,end_time,total_price,payment_method,payment_source,payment_status,is_paid,deposit_paid,status,payment_transaction_id,idempotency_key,refund_amount)
  VALUES(b,a,current_setting('test.booking12.owner_a')::uuid,current_setting('test.booking12.customer')::uuid,current_setting('test.booking12.customer')::uuid,
   CASE WHEN r IN('no_show','online_earned') THEN now()-interval '2 hours' ELSE at_time END,
   CASE WHEN r IN('no_show','online_earned') THEN now()-interval '1 hour' WHEN r='idempotent' THEN at_time+interval '12 hours' ELSE at_time+interval '1 hour' END,
   100,CASE WHEN r='online_earned' THEN 'paymob' ELSE 'cash' END,CASE WHEN r='online_earned' THEN 'paymob' ELSE 'cash' END,
   CASE WHEN r='online_earned' THEN 'paid' ELSE 'pending' END,r='online_earned',CASE WHEN r='online_earned' THEN 100 ELSE 0 END,
   CASE WHEN r='cancelled' THEN 'cancelled' WHEN r='online_earned' THEN 'completed' ELSE 'confirmed' END,
   CASE WHEN r='manual' THEN 'MANUAL_SYNTHETIC' ELSE NULL END,CASE WHEN r='idempotent' THEN 'SYNTHETIC_SCOPE_KEY' ELSE NULL END,
   CASE WHEN r='cancelled' THEN 73.25 ELSE 0 END);
 END LOOP;
END;$$;
GRANT EXECUTE ON FUNCTION public.cancel_1v1_tournament_with_refund_requests(uuid,text) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic_impl(uuid,text) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid,text) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid,uuid,text) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.publish_1v1_final_standings_atomic(uuid) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.vsp_is_trusted_server_actor(),public.vsp_require_registered_actor() TO anon,authenticated,service_role;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon","user_metadata":{"role":"service_role"}}',true);
DO $$ BEGIN IF public.vsp_is_trusted_server_actor() THEN RAISE EXCEPTION 'FAIL untrusted native session accepted';END IF;END;$$;
SET LOCAL ROLE authenticated;
DO $probe$ DECLARE p jsonb;r jsonb;actor text;BEGIN
 FOREACH actor IN ARRAY ARRAY['no_subject','missing'] LOOP
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',CASE WHEN actor='missing' THEN current_setting('test.booking12.missing') ELSE NULL END,'user_metadata',jsonb_build_object('role','service_role'))::text,true);
  IF public.vsp_is_trusted_server_actor() THEN RAISE EXCEPTION 'FAIL untrusted native session accepted';END IF;
  FOR p IN SELECT * FROM jsonb_array_elements($calls$[{"signature": "public.cancel_1v1_tournament_with_refund_requests(uuid,text)", "query": "SELECT public.cancel_1v1_tournament_with_refund_requests(NULL::uuid,NULL::text)", "expected": "ADMIN_ACCESS_REQUIRED"}, {"signature": "public.cancel_booking_with_refund_atomic(uuid,text)", "query": "SELECT public.cancel_booking_with_refund_atomic(NULL::uuid,NULL::text)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.cancel_booking_with_refund_atomic(uuid,text,uuid)", "query": "SELECT public.cancel_booking_with_refund_atomic(NULL::uuid,NULL::text,NULL::uuid)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.cancel_booking_with_refund_atomic_impl(uuid,text)", "query": "SELECT public.cancel_booking_with_refund_atomic_impl(NULL::uuid,NULL::text)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric)", "query": "SELECT public.confirm_cash_booking_atomic(NULL::uuid,NULL::uuid,NULL::numeric,NULL::numeric)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)", "query": "SELECT public.create_booking_atomic(NULL::text,NULL::text,NULL::text,NULL::timestamp with time zone,NULL::timestamp with time zone,NULL::text,NULL::numeric,NULL::text,NULL::text,NULL::boolean,NULL::boolean,NULL::boolean,NULL::numeric,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::numeric,NULL::text,NULL::integer,NULL::integer)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.mark_1v1_prize_delivered_atomic(uuid,text)", "query": "SELECT public.mark_1v1_prize_delivered_atomic(NULL::uuid,NULL::text)", "expected": "ADMIN_ACCESS_REQUIRED"}, {"signature": "public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean)", "query": "SELECT public.owner_cancel_manual_booking_atomic(NULL::uuid,NULL::uuid,NULL::boolean)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer)", "query": "SELECT public.owner_create_manual_booking_atomic(NULL::uuid,NULL::uuid,NULL::timestamp with time zone,NULL::timestamp with time zone,NULL::text,NULL::text,NULL::text,NULL::numeric,NULL::numeric,NULL::integer)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.owner_record_no_show_atomic(uuid,uuid,text)", "query": "SELECT public.owner_record_no_show_atomic(NULL::uuid,NULL::uuid,NULL::text)", "expected": "AUTHENTICATION_REQUIRED"}, {"signature": "public.publish_1v1_final_standings_atomic(uuid)", "query": "SELECT public.publish_1v1_final_standings_atomic(NULL::uuid)", "expected": "ADMIN_ACCESS_REQUIRED"}, {"signature": "public.request_owner_payout_settlement_atomic(uuid,numeric,text,text)", "query": "SELECT public.request_owner_payout_settlement_atomic(NULL::uuid,NULL::numeric,NULL::text,NULL::text)", "expected": "AUTHENTICATION_REQUIRED"}]$calls$::jsonb) LOOP
   BEGIN
    EXECUTE p->>'query' INTO r;
    IF r->'success'='false'::jsonb AND r->>'error'=p->>'expected' THEN CONTINUE;END IF;
    RAISE EXCEPTION 'FAIL booking missing-identity guard: %',p->>'signature';
   EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM IS DISTINCT FROM p->>'expected' THEN RAISE;END IF;
   END;
  END LOOP;
 END LOOP;
END;$probe$;
DO $$ DECLARE actor text;r jsonb;v_owner uuid:=current_setting('test.booking12.owner_a')::uuid;s uuid:=current_setting('test.booking12.stadium')::uuid;t timestamptz:=current_setting('test.booking12.start')::timestamptz;BEGIN
 FOREACH actor IN ARRAY ARRAY['owner_b','intruder','blocked_admin'] LOOP
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.booking12.'||actor))::text,true);
  r:=public.confirm_cash_booking_atomic(current_setting('test.booking12.cash')::uuid,v_owner,100,100);
  IF r->'success' IS DISTINCT FROM 'false'::jsonb OR coalesce(r->>'message','') NOT LIKE '%غير مصرح%' THEN RAISE EXCEPTION 'FAIL cross-owner cash confirmation';END IF;
  r:=public.owner_cancel_manual_booking_atomic(current_setting('test.booking12.manual')::uuid,v_owner,false);
  IF r->'success' IS DISTINCT FROM 'false'::jsonb OR coalesce(r->>'message','') NOT LIKE '%غير مصرح%' THEN RAISE EXCEPTION 'FAIL cross-owner manual cancellation';END IF;
  r:=public.owner_record_no_show_atomic(current_setting('test.booking12.no_show')::uuid,v_owner,'synthetic');
  IF r->'success' IS DISTINCT FROM 'false'::jsonb OR coalesce(r->>'message','') NOT LIKE '%غير مصرح%' THEN RAISE EXCEPTION 'FAIL cross-owner no-show';END IF;
  r:=public.owner_create_manual_booking_atomic(v_owner,s,t+interval '24 hours',t+interval '25 hours','Synthetic','01000000000',NULL,100,0,10);
  IF r->>'error' IS DISTINCT FROM 'UNAUTHORIZED' THEN RAISE EXCEPTION 'FAIL cross-owner manual creation';END IF;
  r:=public.request_owner_payout_settlement_atomic(v_owner,10,'instapay','synthetic@instapay');
  IF r->'success' IS DISTINCT FROM 'false'::jsonb OR coalesce(r->>'error','')<>'Unauthorized payout request' THEN RAISE EXCEPTION 'FAIL cross-owner payout';END IF;
  r:=public.cancel_booking_with_refund_atomic(current_setting('test.booking12.cancel')::uuid,'synthetic');
  IF r->>'code' IS DISTINCT FROM 'forbidden' THEN RAISE EXCEPTION 'FAIL unrelated booking cancellation';END IF;
  r:=public.cancel_booking_with_refund_atomic(current_setting('test.booking12.cancel_three')::uuid,'synthetic',NULL::uuid);
  IF r->>'code' IS DISTINCT FROM 'forbidden' THEN RAISE EXCEPTION 'FAIL unrelated legacy cancellation';END IF;
  r:=public.cancel_booking_with_refund_atomic(current_setting('test.booking12.cancelled')::uuid,'synthetic');
  IF r->>'code' IS DISTINCT FROM 'forbidden' OR r ? 'refund_amount' THEN RAISE EXCEPTION 'FAIL private cancelled-booking receipt';END IF;
 END LOOP;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.booking12.intruder'))::text,true);
DO $$ DECLARE r jsonb;s text:=current_setting('test.booking12.stadium');t timestamptz:=current_setting('test.booking12.start')::timestamptz;BEGIN
 r:=public.create_booking_atomic(s,current_setting('test.booking12.customer'),current_setting('test.booking12.owner_a'),t,t+interval '12 hours','personal',100,p_idempotency_key=>'SYNTHETIC_SCOPE_KEY');
 IF r->'success' IS DISTINCT FROM 'false'::jsonb THEN RAISE EXCEPTION 'FAIL booking user impersonation';END IF;
 r:=public.create_booking_atomic(s,current_setting('test.booking12.intruder'),current_setting('test.booking12.owner_a'),t,t+interval '12 hours','personal',100,p_idempotency_key=>'SYNTHETIC_SCOPE_KEY');
 IF r->'success' IS DISTINCT FROM 'false'::jsonb OR r ? 'booking_id' THEN RAISE EXCEPTION 'FAIL cross-user idempotent receipt';END IF;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.booking12.customer'))::text,true);
DO $$ DECLARE r jsonb;t timestamptz:=current_setting('test.booking12.start')::timestamptz;BEGIN
 r:=public.create_booking_atomic(current_setting('test.booking12.stadium'),auth.uid()::text,current_setting('test.booking12.owner_a'),t,t+interval '12 hours','personal',100,p_idempotency_key=>'SYNTHETIC_SCOPE_KEY');
 IF r->'idempotent' IS DISTINCT FROM 'true'::jsonb OR r->>'booking_id'<>current_setting('test.booking12.idempotent') THEN RAISE EXCEPTION 'FAIL own idempotent receipt';END IF;
 r:=public.cancel_booking_with_refund_atomic(current_setting('test.booking12.cancelled')::uuid,'retry');
 IF r->>'code' IS DISTINCT FROM 'already_cancelled' OR (r->>'refund_amount')::numeric<>73.25 THEN RAISE EXCEPTION 'FAIL own cancellation receipt';END IF;
 r:=public.cancel_booking_with_refund_atomic(current_setting('test.booking12.cancel')::uuid,'owned cancellation');
 IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL own booking cancellation';END IF;
 r:=public.cancel_booking_with_refund_atomic(current_setting('test.booking12.cancel_three')::uuid,'owned cancellation',NULL::uuid);
 IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL own legacy cancellation';END IF;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.booking12.owner_a'))::text,true);
DO $$ DECLARE r jsonb;t timestamptz:=current_setting('test.booking12.start')::timestamptz;BEGIN
 r:=public.confirm_cash_booking_atomic(current_setting('test.booking12.cash')::uuid,auth.uid(),999,100);
 IF r->'success' IS DISTINCT FROM 'false'::jsonb THEN RAISE EXCEPTION 'FAIL cash price tamper accepted';END IF;
 r:=public.confirm_cash_booking_atomic(current_setting('test.booking12.cash')::uuid,auth.uid(),100,100);
 IF r->'success' IS DISTINCT FROM 'true'::jsonb OR (r->>'commission')::numeric<>0 THEN RAISE EXCEPTION 'FAIL owned cash confirmation';END IF;
 r:=public.confirm_cash_booking_atomic(current_setting('test.booking12.cash')::uuid,auth.uid(),100,100);
 IF r->'already_confirmed' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL cash confirmation idempotency';END IF;
 r:=public.owner_cancel_manual_booking_atomic(current_setting('test.booking12.manual')::uuid,auth.uid(),false);
 IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL owned manual cancellation';END IF;
 r:=public.owner_record_no_show_atomic(current_setting('test.booking12.no_show')::uuid,auth.uid(),'synthetic no-show');
 IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL owned no-show';END IF;
 r:=public.owner_create_manual_booking_atomic(auth.uid(),current_setting('test.booking12.stadium')::uuid,t+interval '24 hours',t+interval '25 hours','Synthetic','01000000000',NULL,999,0,10);
 IF r->>'error' IS DISTINCT FROM 'PRICE_MISMATCH' THEN RAISE EXCEPTION 'FAIL manual price authority';END IF;
 r:=public.owner_create_manual_booking_atomic(auth.uid(),current_setting('test.booking12.stadium')::uuid,t+interval '24 hours',t+interval '25 hours','Synthetic','01000000000',NULL,100,0,10);
 IF r->'success' IS DISTINCT FROM 'true'::jsonb OR r->>'transaction_id' IS NULL THEN RAISE EXCEPTION 'FAIL owned manual creation %',r;END IF;
 r:=public.request_owner_payout_settlement_atomic(auth.uid(),10,'instapay','synthetic@instapay');
 IF r->'success' IS DISTINCT FROM 'true'::jsonb OR r->>'settlement_id' IS NULL THEN RAISE EXCEPTION 'FAIL owned payout';END IF;
 r:=public.request_owner_payout_settlement_atomic(auth.uid(),10,'instapay','synthetic@instapay');
 IF r->'success' IS DISTINCT FROM 'false'::jsonb THEN RAISE EXCEPTION 'FAIL duplicate pending payout';END IF;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.booking12.new_customer'))::text,true);
DO $$ DECLARE r jsonb;t timestamptz:=date_trunc('day',now()+interval '4 days')+interval '10 hours';BEGIN
 r:=public.create_booking_atomic(current_setting('test.booking12.stadium'),auth.uid()::text,current_setting('test.booking12.owner_b'),t,t+interval '1 hour','personal',99999,p_payment_status=>'paid',p_platform_fee=>999,p_idempotency_key=>'SYNTHETIC_NEW_BOOKING');
 IF r->'success' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'FAIL registered own booking creation: %',r;END IF;
 PERFORM set_config('test.booking12.created_booking',r->>'booking_id',true);
END;$$;
RESET ROLE;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.bookings WHERE id=current_setting('test.booking12.created_booking')::uuid AND owner_id=current_setting('test.booking12.owner_a')::uuid AND total_price=100 AND is_paid=false AND payment_status<>'paid' AND platform_fee=0 AND vsp_commission=0)
 THEN RAISE EXCEPTION 'FAIL authoritative booking owner/price/payment state';END IF;
 IF (SELECT count(*) FROM public.transactions WHERE booking_id=current_setting('test.booking12.cash')::uuid AND type='cash_settlement')<>1 THEN RAISE EXCEPTION 'FAIL duplicate cash settlement';END IF;
 IF (SELECT count(*) FROM public.payout_settlements WHERE owner_id=current_setting('test.booking12.owner_a')::uuid)<>1 THEN RAISE EXCEPTION 'FAIL payout actor/duplicate state';END IF;
END;$$;
SELECT 'PASS booking/cash/cancellation/manual/no-show/payout actor isolation, price authority, replay and authorized behavior' AS result;
ROLLBACK;
