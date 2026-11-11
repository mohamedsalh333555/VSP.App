-- Only reviewed authorization/replay scopes change; no financial formulas or business rows.

DO $dependency$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.require_active_admin_actor()')
   AND NOT prosecdef AND proconfig=ARRAY['search_path=pg_catalog, public, pg_temp']::text[]
   AND encode(sha256(convert_to(prosrc,'UTF8')),'hex')='2f286baefee2743bee8f5ab27db6fe7ff17e443bf5d0bcd7a5663b34f0231f5e')
 THEN RAISE EXCEPTION 'BOOKING_ADMIN_HELPER_SOURCE_DRIFT';END IF;
END;$dependency$;

DO $ensure$
DECLARE o oid:=to_regprocedure('public.vsp_is_trusted_server_actor()');
BEGIN
 IF o IS NULL THEN EXECUTE $create_helper$CREATE OR REPLACE FUNCTION public.vsp_is_trusted_server_actor()
RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,pg_temp AS $helper_body$
DECLARE v_jwt_role text:=COALESCE(auth.jwt()->>'role','');
BEGIN
 IF v_jwt_role='service_role' THEN RETURN true;END IF;
 RETURN auth.uid() IS NULL AND v_jwt_role=''
   AND session_user IN('postgres','supabase_admin')
   AND COALESCE(current_setting('role',true),'none') IN('none','postgres','supabase_admin','service_role');
END;
$helper_body$;
$create_helper$;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=o AND NOT prosecdef
    AND proconfig=ARRAY['search_path=pg_catalog, public, pg_temp']::text[]
    AND encode(sha256(convert_to(prosrc,'UTF8')),'hex')='a14d67e86a0ce668c77d118ab86da7acbc501019074db97bb6fe61d29270c444')
   OR has_function_privilege('anon',o,'EXECUTE') OR has_function_privilege('authenticated',o,'EXECUTE')
   OR has_function_privilege('service_role',o,'EXECUTE') THEN RAISE EXCEPTION 'BOOKING_HELPER_SOURCE_DRIFT';END IF;
 END IF;
END;$ensure$;
REVOKE ALL ON FUNCTION public.vsp_is_trusted_server_actor() FROM PUBLIC,anon,authenticated,service_role;

DO $ensure$
DECLARE o oid:=to_regprocedure('public.vsp_require_registered_actor()');
BEGIN
 IF o IS NULL THEN EXECUTE $create_helper$CREATE OR REPLACE FUNCTION public.vsp_require_registered_actor()
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,pg_temp AS $helper_body$
BEGIN
 IF public.vsp_is_trusted_server_actor() THEN RETURN;END IF;
 IF auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.users u WHERE u.id=auth.uid()) THEN RETURN;END IF;
 RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501';
END;
$helper_body$;
$create_helper$;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=o AND NOT prosecdef
    AND proconfig=ARRAY['search_path=pg_catalog, public, pg_temp']::text[]
    AND encode(sha256(convert_to(prosrc,'UTF8')),'hex')='c78b1be3db77cb93b77ab491e30413eb9c112b7d51279ebce978c72eecab3248')
   OR has_function_privilege('anon',o,'EXECUTE') OR has_function_privilege('authenticated',o,'EXECUTE')
   OR has_function_privilege('service_role',o,'EXECUTE') THEN RAISE EXCEPTION 'BOOKING_HELPER_SOURCE_DRIFT';END IF;
 END IF;
END;$ensure$;
REVOKE ALL ON FUNCTION public.vsp_require_registered_actor() FROM PUBLIC,anon,authenticated,service_role;

DO $patch$
DECLARE v_plan constant jsonb:=$plan$[{"signature": "public.cancel_1v1_tournament_with_refund_requests(uuid,text)", "before_sha256": "a67788c1ca70ce13fce9eefded98ef76f8811dd213910fc757633084876780ca", "after_sha256": "c6f5c5711667175f1615b105172728b80f395273c8e71880d85e62a5c1c0b7da", "operations": [{"old": "current_user NOT IN ('postgres', 'service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}], "begin_offset": 208, "injection": "\n  PERFORM public.require_active_admin_actor();\n", "origins": ["production"]}, {"signature": "public.cancel_booking_with_refund_atomic(uuid,text)", "before_sha256": "bf337428b3862d03e4aa00577f78fbf046dd4f4d0b94158b9d5185aa4a9e5df2", "after_sha256": "b42baabb17d48f55785101d0d296d3d13f964083ec266c6a376b16c2fc4831df", "operations": [{"old": "current_user NOT IN ('postgres', 'service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id = auth.uid();"}, {"old": "IF v_booking.status = 'completed' THEN", "new": "IF coalesce(auth.role(), '') <> 'service_role' AND NOT public.vsp_is_trusted_server_actor() THEN\n    IF auth.uid() IS NULL THEN\n      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', '\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0623\u0648\u0644\u0627\u064b \u0644\u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u062d\u062c\u0632.');\n    END IF;\n    SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id = auth.uid();\n    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id\n       AND auth.uid() IS DISTINCT FROM v_booking.user_id\n       AND auth.uid() IS DISTINCT FROM v_booking.owner_id\n       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN\n      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', '\u063a\u064a\u0631 \u0645\u0635\u0631\u062d: \u0644\u0627 \u064a\u0645\u0643\u0646\u0643 \u0625\u0644\u063a\u0627\u0621 \u0647\u0630\u0627 \u0627\u0644\u062d\u062c\u0632.');\n    END IF;\n  END IF;\n\n  IF v_booking.status = 'completed' THEN"}], "begin_offset": 461, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production"]}, {"signature": "public.cancel_booking_with_refund_atomic(uuid,text,uuid)", "before_sha256": "665f96195514c96387f4e3e70a49571326662e75d2238cb63820240c0f4ecbd2", "after_sha256": "a96e44d4c159710552ad55b6f71b4167bd60c402ae061d40e2344badbf160413", "operations": [{"old": "current_user NOT IN ('postgres', 'service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id = auth.uid();"}, {"old": "IF v_booking.status = 'completed' THEN", "new": "IF coalesce(auth.role(), '') <> 'service_role' AND NOT public.vsp_is_trusted_server_actor() THEN\n    IF auth.uid() IS NULL THEN\n      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', '\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0623\u0648\u0644\u0627\u064b \u0644\u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u062d\u062c\u0632.');\n    END IF;\n    SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id = auth.uid();\n    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id\n       AND auth.uid() IS DISTINCT FROM v_booking.user_id\n       AND auth.uid() IS DISTINCT FROM v_booking.owner_id\n       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN\n      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', '\u063a\u064a\u0631 \u0645\u0635\u0631\u062d: \u0644\u0627 \u064a\u0645\u0643\u0646\u0643 \u0625\u0644\u063a\u0627\u0621 \u0647\u0630\u0627 \u0627\u0644\u062d\u062c\u0632.');\n    END IF;\n  END IF;\n\n  IF v_booking.status = 'completed' THEN"}], "begin_offset": 461, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production"]}, {"signature": "public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric)", "before_sha256": "b66c382bdcc5d35b55f4b42f4c32bcb52bfd4d7601dce45d4f4259732a2e337f", "after_sha256": "cacf8501d4ce363d2c406b623fdf45ea4ad01d53df718bc9aed9e3393ab3bd9f", "operations": [{"old": "current_user NOT IN ('postgres','service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=auth.uid();"}], "begin_offset": 209, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production"]}, {"signature": "public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)", "before_sha256": "550bf7a4c12e733853248166b676475ede8f3c7619bba978c80a7c8b68764727", "after_sha256": "caa5f3e1f53c4c790cff900984015fb6df8c73e11a70d9090cc8eacb51161f7c", "operations": [{"old": "current_user NOT IN ('postgres','service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller;", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=v_caller;"}, {"old": "WHERE idempotency_key=p_idempotency_key AND status<>'cancelled'\n    LIMIT 1;", "new": "WHERE idempotency_key=p_idempotency_key AND status<>'cancelled'\n      AND user_id::text=p_user_id\n      AND stadium_id::text=p_stadium_id\n      AND start_time=p_start_time AND end_time=p_end_time\n    LIMIT 1;"}], "begin_offset": 732, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production"]}, {"signature": "public.mark_1v1_prize_delivered_atomic(uuid,text)", "before_sha256": "0a8898c4b9a1e04dfa13bf4247275976d33db5710a86f7838edaba9fdbdb0c91", "after_sha256": "7356aafd5ff64503adfa97044f9d67af4e02167039e115dc12157e631cfdee7a", "operations": [{"old": "current_user != 'postgres'", "new": "NOT public.vsp_is_trusted_server_actor()"}], "begin_offset": 149, "injection": "\n  PERFORM public.require_active_admin_actor();\n", "origins": ["production"]}, {"signature": "public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean)", "before_sha256": "34a6a4a59711325ec1b9012d67453889615476c193e78195e3a475c7367df7f0", "after_sha256": "04aa9af88c0090d6ac4371ba8f6abb84d205f88b2e48578371d2f688e0435355", "operations": [{"old": "current_user NOT IN ('postgres','service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=auth.uid();"}], "begin_offset": 113, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production"]}, {"signature": "public.owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer)", "before_sha256": "80dfa6a6cc4d5d872342230af0d4218331b4dddc4bb816a67d92c78cc4f71e88", "after_sha256": "b725d7c4183ec464a914dd7c1de8ef8665a9f283ec97608ba3c19edb15357154", "operations": [{"old": "current_user in ('postgres','service_role')", "new": "public.vsp_is_trusted_server_actor()"}, {"old": "select role into v_role from public.users where id=auth.uid();", "new": "select CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END into v_role from public.users where id=auth.uid();"}], "begin_offset": 234, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production", "staging"]}, {"signature": "public.owner_record_no_show_atomic(uuid,uuid,text)", "before_sha256": "a6af1ebf13a0a2d6b5852d58f41b4cf33ee5a64a4937d98a9f80a11210dd2074", "after_sha256": "cc1fa8e621f8073678e9af4faa0d5ab1a7ea0415289433958749cd521c1c9006", "operations": [{"old": "current_user NOT IN ('postgres','service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=auth.uid();"}], "begin_offset": 112, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production"]}, {"signature": "public.publish_1v1_final_standings_atomic(uuid)", "before_sha256": "c214ce215bddc5b211ea13e6da593a819114b5ffc961f2915e4277d94d678801", "after_sha256": "b1d595651fcda0205430deb206ee716d6bd7a86ba049311c7cd6eb4098bedaf1", "operations": [{"old": "current_user <> 'postgres'", "new": "NOT public.vsp_is_trusted_server_actor()"}], "begin_offset": 139, "injection": "\n  PERFORM public.require_active_admin_actor();\n", "origins": ["production"]}, {"signature": "public.request_owner_payout_settlement_atomic(uuid,numeric,text,text)", "before_sha256": "b8ccbbf0b04e89cba69236ce6f7bd59f6d7a2a8c593e6cd837a7c604204d7791", "after_sha256": "e2dd82061d075ddd5774d44774aedab84ac9d4178787af59cb904a6702ecc57c", "operations": [{"old": "current_user not in ('postgres','service_role')", "new": "NOT public.vsp_is_trusted_server_actor()"}, {"old": "select role into v_caller_role from public.users where id=auth.uid();", "new": "select CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END into v_caller_role from public.users where id=auth.uid();"}], "begin_offset": 298, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["production", "staging"]}, {"signature": "public.cancel_1v1_tournament_with_refund_requests(uuid,text)", "before_sha256": "20c39d954c1ed2804e41755b68c2e921b865f32be7eebec9bf1f241955c9c0d3", "after_sha256": "9a6f708694bef9bf4a54d843758de0aac4613c682f9c8282a4770da0ed9fbfa7", "operations": [], "begin_offset": 208, "injection": "\n  PERFORM public.require_active_admin_actor();\n", "origins": ["staging"]}, {"signature": "public.cancel_booking_with_refund_atomic(uuid,text)", "before_sha256": "43538dd3f854434b1b0c772b70a295762b67da1eae24a996494c1faa9e5b64b4", "after_sha256": "032bcfd688a8a947cfe6de05cdbd8bbcf8dc92f93ee86f3c13b0a75f3ba76a5d", "operations": [], "begin_offset": 6, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["staging"]}, {"signature": "public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric)", "before_sha256": "8228a237caed5a778e558ac46239933f2b9076b2413d0bd4ec89f97b5e0ab1d2", "after_sha256": "9d35ae969f4e2dedac683d136340d79aed662c97d7eec4847ca49164f12ce542", "operations": [{"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=auth.uid();"}], "begin_offset": 209, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["staging"]}, {"signature": "public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)", "before_sha256": "9bf9b787e0a97c225c9b3fc19833f0139176c8ed421480aa4cc01519c056e0dd", "after_sha256": "5ed83cb1c5464e488eabd5b20363349aae54574fe73f3313108efab3407f62e7", "operations": [{"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller;", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=v_caller;"}], "begin_offset": 732, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["staging"]}, {"signature": "public.mark_1v1_prize_delivered_atomic(uuid,text)", "before_sha256": "35f05b4c36bc0adb8dc218b750ddfe9f766ba4d580390b59f8bba591493655ae", "after_sha256": "ae4b1d4dac7fc9dd7966e6fa7ac1590211fdc11e7dedc4cbdf3eb9d08e04c7aa", "operations": [], "begin_offset": 149, "injection": "\n  PERFORM public.require_active_admin_actor();\n", "origins": ["staging"]}, {"signature": "public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean)", "before_sha256": "07a9e29c6061f248d03583e2ff94be8d963077c0e4f001df2e97fc0f5b7a4896", "after_sha256": "f1ebe1589126f6d7f6ebf83cea8b57bf25897f7ac79188002f1729e6d55b2836", "operations": [{"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=auth.uid();"}], "begin_offset": 113, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["staging"]}, {"signature": "public.owner_record_no_show_atomic(uuid,uuid,text)", "before_sha256": "b734fa9cd69e3df9b8499879b80ff7e80bee13fde13a30553314a9567ad05373", "after_sha256": "ce6c1a64b01644a6bb46b9f2e0523959d2d1756943150e0923809a55b077cd6e", "operations": [{"old": "SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id=auth.uid();"}], "begin_offset": 112, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["staging"]}, {"signature": "public.publish_1v1_final_standings_atomic(uuid)", "before_sha256": "4baacf310a99f0911720a997e1254ae8101e0df69c1f87949af5fb1bac859504", "after_sha256": "95ced2e6c8d807827af3f5d79cd17bfe2cee56badcf5647c83fa9dadef898b2f", "operations": [], "begin_offset": 139, "injection": "\n  PERFORM public.require_active_admin_actor();\n", "origins": ["staging"]}, {"signature": "public.cancel_booking_with_refund_atomic_impl(uuid,text)", "before_sha256": "17fb59fcf02cc70037e1ae3d3bc033fa46304d98c7b0bdd07be2ef5c80b7db25", "after_sha256": "697d61b930ffe501cf62eb457f35c7d163445657f009ea725c1fe9e1f2a8cab8", "operations": [{"old": "SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();", "new": "SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id = auth.uid();"}, {"old": "IF v_booking.status = 'completed' THEN", "new": "IF coalesce(auth.role(), '') <> 'service_role' THEN\n    IF auth.uid() IS NULL THEN\n      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', '\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0623\u0648\u0644\u0627\u064b \u0644\u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u062d\u062c\u0632.');\n    END IF;\n    SELECT CASE WHEN COALESCE(is_blocked,false) AND role IN ('admin','co_founder','cofounder','super_admin') THEN ''::text ELSE role END INTO v_caller_role FROM public.users WHERE id = auth.uid();\n    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id\n       AND auth.uid() IS DISTINCT FROM v_booking.user_id\n       AND auth.uid() IS DISTINCT FROM v_booking.owner_id\n       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN\n      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', '\u063a\u064a\u0631 \u0645\u0635\u0631\u062d: \u0644\u0627 \u064a\u0645\u0643\u0646\u0643 \u0625\u0644\u063a\u0627\u0621 \u0647\u0630\u0627 \u0627\u0644\u062d\u062c\u0632.');\n    END IF;\n  END IF;\n\n  IF v_booking.status = 'completed' THEN"}], "begin_offset": 461, "injection": "\n  PERFORM public.vsp_require_registered_actor();\n", "origins": ["staging"]}]$plan$::jsonb;
 s text;o oid;b text;n text;d text;h text;v record;op jsonb;is_definer boolean;language_name text;missing integer:=0;changed integer:=0;
BEGIN
 FOR s IN SELECT DISTINCT p.signature FROM jsonb_to_recordset(v_plan) AS p(signature text) LOOP
  o:=to_regprocedure(s)::oid;
  IF o IS NULL THEN missing:=missing+1;CONTINUE;END IF;
  SELECT p.prosrc,p.prosecdef,l.lanname INTO b,is_definer,language_name FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang WHERE p.oid=o;
  IF NOT is_definer OR language_name<>'plpgsql' THEN RAISE EXCEPTION 'BOOKING_ACTOR_KIND_DRIFT: %',s;END IF;
  h:=encode(sha256(convert_to(b,'UTF8')),'hex');
  IF EXISTS(SELECT 1 FROM jsonb_to_recordset(v_plan) AS p(signature text,after_sha256 text) WHERE p.signature=s AND p.after_sha256=h) THEN CONTINUE;END IF;
  SELECT p.* INTO v FROM jsonb_to_recordset(v_plan) AS p(signature text,before_sha256 text,after_sha256 text,operations jsonb,begin_offset integer,injection text) WHERE p.signature=s AND p.before_sha256=h LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_ACTOR_SOURCE_DRIFT: %',s;END IF;
  n:=b;
  FOR op IN SELECT * FROM jsonb_array_elements(v.operations) LOOP
   IF position(op->>'old' in n)=0 THEN RAISE EXCEPTION 'BOOKING_ACTOR_FRAGMENT_DRIFT: %',s;END IF;
   n:=replace(n,op->>'old',op->>'new');
  END LOOP;
  IF lower(substring(n FROM v.begin_offset-4 FOR 5))<>'begin' THEN RAISE EXCEPTION 'BOOKING_ACTOR_OFFSET_DRIFT: %',s;END IF;
  n:=substring(n FROM 1 FOR v.begin_offset)||v.injection||substring(n FROM v.begin_offset+1);
  IF encode(sha256(convert_to(n,'UTF8')),'hex')<>v.after_sha256 THEN RAISE EXCEPTION 'BOOKING_ACTOR_HASH_MISMATCH: %',s;END IF;
  d:=pg_get_functiondef(o);
  IF length(d)-length(replace(d,b,''))<>length(b) THEN RAISE EXCEPTION 'BOOKING_ACTOR_AMBIGUOUS: %',s;END IF;
  EXECUTE replace(d,b,n);changed:=changed+1;
 END LOOP;
 RAISE NOTICE 'BOOKING_ACTOR_GUARDS changed=%, absent=%',changed,missing;
END;$patch$;


-- Only the legacy production signature overlaps the two-argument cancellation.
-- Recreate it atomically because PostgreSQL cannot remove defaults in place.
DO $overloads$
DECLARE
  target regprocedure := to_regprocedure('public.cancel_booking_with_refund_atomic(uuid,text,uuid)');
  original text;
  old_args constant text := 'p_booking_id uuid, p_reason text DEFAULT ''إلغاء حجز من المستخدم''::text, p_user_id uuid DEFAULT NULL::uuid';
  new_args constant text := 'p_booking_id uuid, p_reason text, p_user_id uuid';
BEGIN
  IF target IS NULL THEN RETURN; END IF;
  IF pg_get_function_arguments(target)=new_args THEN RETURN; END IF;
  IF pg_get_function_arguments(target)<>old_args
     OR NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=target AND proowner=current_user::regrole)
     OR EXISTS (SELECT FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                WHERE p.oid=target AND (a.grantee NOT IN (p.proowner,'authenticated'::regrole,'service_role'::regrole) OR a.is_grantable))
     OR has_function_privilege('anon',target,'EXECUTE')
     OR NOT has_function_privilege('authenticated',target,'EXECUTE')
     OR NOT has_function_privilege('service_role',target,'EXECUTE')
     OR obj_description(target,'pg_proc') IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected cancellation function metadata';
  END IF;
  original := pg_get_functiondef(target);
  EXECUTE 'DROP FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid) RESTRICT';
  EXECUTE replace(original,old_args,new_args);
  CREATE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid,p_user_id uuid)
  RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog,public,pg_temp
  AS 'SELECT public.cancel_booking_with_refund_atomic($1,''إلغاء حجز من المستخدم''::text,$2)';
  REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid),
    public.cancel_booking_with_refund_atomic(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
  GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid),
    public.cancel_booking_with_refund_atomic(uuid,uuid) TO authenticated,service_role;
END;
$overloads$;

-- Legacy no-show and sports routines use a score initialized to 100.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fair_play_score integer NOT NULL DEFAULT 100;
CREATE OR REPLACE FUNCTION public.protect_client_fair_play_score() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $score$
BEGIN
  IF current_user IN ('authenticated','anon') THEN
    IF TG_OP='INSERT' THEN NEW.fair_play_score:=100;
    ELSE NEW.fair_play_score:=OLD.fair_play_score;
    END IF;
  END IF;
  RETURN NEW;
END;
$score$;
REVOKE ALL ON FUNCTION public.protect_client_fair_play_score() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS protect_client_fair_play_score ON public.users;
CREATE TRIGGER protect_client_fair_play_score BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.protect_client_fair_play_score();
