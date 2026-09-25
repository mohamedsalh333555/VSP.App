-- Harden legacy team-tournament refund status: idempotency and server-only execution.
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text,p_refund_status text,p_paymob_refund_id text DEFAULT NULL,p_error_message text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_order record; v_existing_role text; v_now timestamptz:=timezone('utc',now()); v_admin_id uuid;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_existing_role FROM public.users WHERE id=auth.uid();
  IF coalesce(v_existing_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','غير مصرح.'); END IF;
 END IF;
 IF p_refund_status NOT IN ('refunded','refund_failed_manual_review') THEN RETURN jsonb_build_object('success',false,'error','حالة الاسترداد غير صالحة.'); END IF;
 SELECT * INTO v_order FROM public.tournament_orders WHERE order_reference=p_order_reference FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','طلب اشتراك البطولة غير موجود.'); END IF;
 IF v_order.payment_status='refunded' THEN RETURN jsonb_build_object('success',true,'already_refunded',true,'order_reference',p_order_reference,'status','refunded'); END IF;
 IF v_order.payment_status NOT IN ('paid','refund_failed_manual_review') THEN RETURN jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','current_status',v_order.payment_status); END IF;
 UPDATE public.tournament_orders SET payment_status=p_refund_status,updated_at=v_now WHERE id=v_order.id;
 UPDATE public.transactions SET status=CASE WHEN p_refund_status='refunded' THEN 'completed' ELSE 'failed' END,
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now)
 WHERE championship_id=v_order.championship_id AND type='refund' AND metadata->>'order_reference'=p_order_reference;
 IF p_refund_status='refunded' THEN
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_order.captain_user_id,'تم استرداد رسوم اشتراك البطولة بنجاح','تمت إعادة مبلغ رسوم الاشتراك ('||v_order.amount||' ج.م) بنجاح عبر Paymob (مرجع: '||coalesce(p_paymob_refund_id,'')||').','tournament_refund',v_now);
 ELSE
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_order.captain_user_id,'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)','تعذر الاسترداد التلقائي للرسوم ('||v_order.amount||' ج.م). تم تحويل العملية للمراجعة اليدوية.','tournament_refund_manual',v_now);
  FOR v_admin_id IN SELECT id FROM public.users WHERE role IN ('admin','co_founder','cofounder','super_admin') LOOP
   INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_admin_id,'تنبيه مالي: فشل استرداد رسوم بطولة فرق','فشل استرداد الطلب '||p_order_reference||' (المبلغ: '||v_order.amount||' ج.م). السبب: '||coalesce(p_error_message,'Paymob API error')||'.','admin_alert',v_now);
  END LOOP;
 END IF;
 RETURN jsonb_build_object('success',true,'order_reference',p_order_reference,'status',p_refund_status,'paymob_refund_id',p_paymob_refund_id);
END;$function$;
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text,text,text,text) FROM anon,public,authenticated;
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text,boolean,text,text) FROM anon,public,authenticated;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text,boolean,text,text) TO service_role;