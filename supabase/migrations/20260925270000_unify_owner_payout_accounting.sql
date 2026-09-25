-- Unify owner payout accounting and fix hybrid/deposit principal accounting.
-- Owner earnings are the principal actually collected online; fees are charged on top.
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
 v_caller_id uuid:=auth.uid(); v_role text; v_total_online_revenue numeric:=0; v_total_platform_fees numeric:=0;
 v_net_online_earnings numeric:=0; v_total_withdrawn numeric:=0; v_pending_payouts numeric:=0;
 v_available_balance numeric:=0; v_cash_revenue numeric:=0; v_count int:=0;
BEGIN
 IF v_caller_id IS NULL AND current_user NOT IN ('postgres','service_role') THEN RETURN jsonb_build_object('success',false,'error','Authentication required'); END IF;
 IF v_caller_id IS NOT NULL THEN
  SELECT role INTO v_role FROM public.users WHERE id=v_caller_id;
  IF v_caller_id<>p_owner_id AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') AND current_user NOT IN ('postgres','service_role') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized access to financial records'); END IF;
 END IF;
 SELECT COALESCE(SUM(CASE WHEN COALESCE(b.deposit_paid,0)>0 AND COALESCE(b.deposit_paid,0)<b.total_price THEN b.deposit_paid ELSE b.total_price END),0),
        COALESCE(SUM(COALESCE(b.platform_fee,0)),0),COUNT(*)
 INTO v_total_online_revenue,v_total_platform_fees,v_count
 FROM public.bookings b
 WHERE b.owner_id=p_owner_id AND lower(COALESCE(b.payment_method,''))<>'cash'
   AND (b.payment_status='paid' OR b.is_paid=true) AND b.status IN ('completed','no_show');
 v_net_online_earnings:=v_total_online_revenue;
 SELECT COALESCE(SUM(amount),0) INTO v_total_withdrawn FROM public.payout_settlements WHERE owner_id=p_owner_id AND status='completed';
 SELECT COALESCE(SUM(amount),0) INTO v_pending_payouts FROM public.payout_settlements WHERE owner_id=p_owner_id AND status IN ('pending','approved');
 v_available_balance:=GREATEST(0,v_net_online_earnings-v_total_withdrawn-v_pending_payouts);
 SELECT COALESCE(SUM(total_price),0) INTO v_cash_revenue FROM public.bookings WHERE owner_id=p_owner_id
 AND lower(COALESCE(payment_method,''))='cash' AND (payment_status='paid' OR is_paid=true) AND status IN ('completed','no_show');
 RETURN jsonb_build_object('success',true,'owner_id',p_owner_id,'total_online_revenue',round(v_total_online_revenue,2),
 'total_platform_fees',round(v_total_platform_fees,2),'net_online_earnings',round(v_net_online_earnings,2),
 'total_withdrawn',round(v_total_withdrawn,2),'pending_payouts',round(v_pending_payouts,2),
 'available_balance',round(v_available_balance,2),'cash_revenue',round(v_cash_revenue,2),'completed_bookings_count',v_count);
END;$function$;

CREATE OR REPLACE FUNCTION public.admin_record_payout_settlement_atomic(p_owner_id uuid,p_amount numeric,p_payment_method text,p_reference text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
 v_caller_role text; v_owner record; v_summary jsonb; v_available numeric; v_reference text;
 v_tx_id uuid:=gen_random_uuid(); v_settlement_id uuid; v_destination text; v_now timestamptz:=timezone('utc',now());
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized: Admin access required'); END IF;
 END IF;
 IF p_amount IS NULL OR p_amount<=0 THEN RETURN jsonb_build_object('success',false,'error','Invalid payout amount'); END IF;
 SELECT * INTO v_owner FROM public.users WHERE id=p_owner_id AND role IN ('owner','admin','co_founder','cofounder','super_admin') FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Owner not found'); END IF;
 IF nullif(trim(coalesce(p_reference,'')),'') IS NOT NULL THEN
  SELECT t.reference_number,t.id INTO v_reference,v_tx_id FROM public.transactions t
  WHERE t.type IN ('payout','payout_disbursed') AND t.reference_number=trim(p_reference) AND t.status='completed' LIMIT 1;
  IF FOUND THEN
   IF EXISTS(SELECT 1 FROM public.transactions t2 WHERE t2.id=v_tx_id AND t2.user_id=p_owner_id AND round(t2.amount,2)=round(p_amount,2))
   THEN RETURN jsonb_build_object('success',true,'idempotent',true,'transaction_id',v_tx_id,'reference_number',v_reference,'amount',p_amount); END IF;
   RETURN jsonb_build_object('success',false,'error','Payout reference already belongs to another transaction');
  END IF;
 END IF;
 v_summary:=public.get_owner_financial_summary(p_owner_id);
 IF coalesce((v_summary->>'success')::boolean,false) IS NOT TRUE THEN RETURN jsonb_build_object('success',false,'error',coalesce(v_summary->>'error','Owner financial summary unavailable')); END IF;
 v_available:=round(coalesce((v_summary->>'available_balance')::numeric,0),2);
 IF round(p_amount,2)>v_available+0.01 THEN RETURN jsonb_build_object('success',false,'error','Payout exceeds authoritative owner available balance','available_balance',v_available,'requested_amount',p_amount); END IF;
 v_reference:=coalesce(nullif(trim(p_reference),''),'PAYOUT_'||replace(v_tx_id::text,'-',''));
 v_destination:=CASE lower(coalesce(p_payment_method,''))
  WHEN 'vodafone_cash' THEN coalesce(v_owner.p2p_vodafone,'')
  WHEN 'instapay' THEN coalesce(v_owner.p2p_instapay,'')
  WHEN 'bank_transfer' THEN coalesce(v_owner.p2p_bank,'')
  ELSE coalesce(v_owner.p2p_vodafone,v_owner.p2p_instapay,v_owner.p2p_bank,'') END;
 IF nullif(trim(coalesce(v_destination,'')),'') IS NULL THEN RETURN jsonb_build_object('success',false,'error','Owner payout destination is missing'); END IF;
 INSERT INTO public.transactions(id,user_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
 VALUES(v_tx_id,p_owner_id,round(p_amount,2),'payout_disbursed','completed',lower(coalesce(p_payment_method,'vodafone_cash')),v_reference,'تسوية أرباح مالك ملعب من إدارة VSP',
 jsonb_build_object('server_recorded_at',v_now,'destination',v_destination),v_now,v_now);
 INSERT INTO public.payout_settlements(owner_id,amount,method,destination,status,admin_notes,created_at,updated_at)
 VALUES(p_owner_id,round(p_amount,2),lower(coalesce(p_payment_method,'vodafone_cash')),v_destination,'completed','Ref: '||v_reference,v_now,v_now) RETURNING id INTO v_settlement_id;
 UPDATE public.transactions SET metadata=metadata||jsonb_build_object('settlement_id',v_settlement_id) WHERE id=v_tx_id;
 INSERT INTO public.notifications(user_id,title,body,type,created_at)
 VALUES(p_owner_id,'تم تحويل أرباحك بنجاح! 💸','تم إرسال مبلغ '||round(p_amount,2)||' ج.م عبر '||lower(coalesce(p_payment_method,'vodafone_cash'))||' برقم مرجع: '||v_reference,'info',v_now);
 RETURN jsonb_build_object('success',true,'idempotent',false,'transaction_id',v_tx_id,'settlement_id',v_settlement_id,'reference_number',v_reference,'amount',round(p_amount,2),'server_time',v_now);
END;$function$;

CREATE OR REPLACE FUNCTION public.approve_payout_settlement_atomic(p_settlement_id uuid,p_admin_notes text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_settlement record; v_admin_role text; v_now timestamptz:=timezone('utc',now()); v_tx_id uuid;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN
  SELECT role INTO v_admin_role FROM public.users WHERE id=auth.uid();
  IF coalesce(v_admin_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Admin authorization required'); END IF;
 END IF;
 SELECT * INTO v_settlement FROM public.payout_settlements WHERE id=p_settlement_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Settlement record not found'); END IF;
 IF v_settlement.status='completed' THEN RETURN jsonb_build_object('success',true,'idempotent',true,'settlement_id',p_settlement_id,'amount',v_settlement.amount); END IF;
 IF v_settlement.status NOT IN ('pending','approved') THEN RETURN jsonb_build_object('success',false,'error','Settlement is not payable in its current state'); END IF;
 UPDATE public.payout_settlements SET status='completed',admin_notes=coalesce(p_admin_notes,admin_notes),updated_at=v_now WHERE id=p_settlement_id;
 SELECT id INTO v_tx_id FROM public.transactions WHERE type='payout_pending' AND status='pending' AND (metadata->>'settlement_id')=p_settlement_id::text ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
 IF v_tx_id IS NOT NULL THEN
  UPDATE public.transactions SET type='payout_disbursed',status='completed',description='صرف أرباح مالك ملعب بعد اعتماد الإدارة',
   metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('approved_by',auth.uid(),'approved_at',v_now,'admin_notes',p_admin_notes),updated_at=v_now WHERE id=v_tx_id;
 ELSE
  SELECT id INTO v_tx_id FROM public.transactions WHERE type='payout_disbursed' AND status='completed' AND (metadata->>'settlement_id')=p_settlement_id::text LIMIT 1;
  IF v_tx_id IS NULL THEN
   INSERT INTO public.transactions(user_id,amount,type,status,payment_method,reference_number,metadata,created_at,updated_at)
   VALUES(v_settlement.owner_id,v_settlement.amount,'payout_disbursed','completed',v_settlement.method,'SETTLEMENT_'||replace(p_settlement_id::text,'-',''),
    jsonb_build_object('settlement_id',p_settlement_id,'destination',v_settlement.destination,'approved_by',auth.uid(),'approved_at',v_now,'admin_notes',p_admin_notes),v_now,v_now) RETURNING id INTO v_tx_id;
  END IF;
 END IF;
 RETURN jsonb_build_object('success',true,'settlement_id',p_settlement_id,'transaction_id',v_tx_id,'amount',v_settlement.amount);
END;$function$;

REVOKE EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) FROM anon,public;
GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated,service_role;
REVOKE EXECUTE ON FUNCTION public.admin_record_payout_settlement_atomic(uuid,numeric,text,text) FROM anon,authenticated,public;
GRANT EXECUTE ON FUNCTION public.admin_record_payout_settlement_atomic(uuid,numeric,text,text) TO service_role;
REVOKE EXECUTE ON FUNCTION public.approve_payout_settlement_atomic(uuid,text) FROM anon,authenticated,public;
GRANT EXECUTE ON FUNCTION public.approve_payout_settlement_atomic(uuid,text) TO service_role;