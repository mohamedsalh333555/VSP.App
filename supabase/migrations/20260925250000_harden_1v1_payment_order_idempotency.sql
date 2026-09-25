-- Harden 1v1 payment order creation: server-authoritative positive fee and
-- one reusable pending order per player/tournament.
CREATE UNIQUE INDEX IF NOT EXISTS ux_1v1_pending_order_player_tournament
ON public.vsp_1v1_tournament_orders (tournament_id, user_id)
WHERE payment_status = 'pending';

CREATE OR REPLACE FUNCTION public.create_1v1_payment_order_atomic(p_tournament_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
DECLARE v_caller_id uuid:=auth.uid(); v_champ record; v_current_count integer; v_existing record; v_order_id uuid; v_order_ref text;
BEGIN
 IF v_caller_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً للمشاركة.'); END IF;
 SELECT * INTO v_champ FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','البطولة غير موجودة.'); END IF;
 IF v_champ.status<>'registration_open' THEN RETURN jsonb_build_object('success',false,'error','التسجيل في هذه البطولة مغلق حالياً.'); END IF;
 IF COALESCE(v_champ.entry_fee,0)<=0 THEN RETURN jsonb_build_object('success',false,'error','رسوم البطولة غير صالحة حالياً.'); END IF;
 IF EXISTS(SELECT 1 FROM public.vsp_1v1_tournament_players WHERE tournament_id=p_tournament_id AND user_id=v_caller_id AND payment_status='paid') THEN
  RETURN jsonb_build_object('success',false,'already_registered',true,'error','أنت مسجل ودافع بالفعل في هذه البطولة.');
 END IF;
 SELECT * INTO v_existing FROM public.vsp_1v1_tournament_orders WHERE tournament_id=p_tournament_id AND user_id=v_caller_id AND payment_status='pending' ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
 IF FOUND THEN RETURN jsonb_build_object('success',true,'existing_order',true,'order_id',v_existing.id,'order_reference',v_existing.order_reference,'amount',v_existing.amount,'tournament_id',p_tournament_id,'tournament_name',v_champ.name); END IF;
 SELECT count(*) INTO v_current_count FROM public.vsp_1v1_tournament_players WHERE tournament_id=p_tournament_id AND payment_status='paid';
 IF v_current_count>=v_champ.target_player_count THEN RETURN jsonb_build_object('success',false,'error','عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.'); END IF;
 v_order_id:=gen_random_uuid();
 v_order_ref:='TOURN_1V1_'||substring(v_order_id::text,1,8)||'_'||floor(extract(epoch from now()))::bigint;
 INSERT INTO public.vsp_1v1_tournament_orders(id,tournament_id,user_id,amount,order_reference,payment_status,created_at,updated_at)
 VALUES(v_order_id,p_tournament_id,v_caller_id,round(v_champ.entry_fee,2),v_order_ref,'pending',timezone('utc',now()),timezone('utc',now()));
 RETURN jsonb_build_object('success',true,'order_id',v_order_id,'order_reference',v_order_ref,'amount',round(v_champ.entry_fee,2),'tournament_id',p_tournament_id,'tournament_name',v_champ.name);
END;$function$;
REVOKE EXECUTE ON FUNCTION public.create_1v1_payment_order_atomic(uuid) FROM anon,public;
GRANT EXECUTE ON FUNCTION public.create_1v1_payment_order_atomic(uuid) TO authenticated,service_role;
