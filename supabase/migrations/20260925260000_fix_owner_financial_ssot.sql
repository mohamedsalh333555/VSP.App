-- Owner financial SSOT: platform/Paymob fees are charged on top to the payer.
-- Therefore owner net earnings equal the principal collected, not principal minus platform_fee.
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
 SELECT COALESCE(SUM(b.total_price),0),COALESCE(SUM(COALESCE(b.platform_fee,0)),0),COUNT(*) INTO v_total_online_revenue,v_total_platform_fees,v_count
 FROM public.bookings b WHERE b.owner_id=p_owner_id AND lower(COALESCE(b.payment_method,''))<>'cash'
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
REVOKE EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) FROM anon,public;
GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated,service_role;