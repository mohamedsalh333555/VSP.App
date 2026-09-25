-- Harden manual-booking cancellation: bind owner identity and prevent cancellation after booking start.
CREATE OR REPLACE FUNCTION public.owner_cancel_manual_booking_atomic(p_booking_id uuid,p_owner_id uuid,p_refund_deposit boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_now timestamptz:=timezone('utc',now()); v_deposit numeric;
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder') THEN RETURN jsonb_build_object('success',false,'message','غير مصرح.'); END IF;
 END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',true,'message','الحجز ملغي بالفعل مسبقاً.'); END IF;
 IF v_booking.start_time<=v_now THEN RETURN jsonb_build_object('success',false,'message','لا يمكن إلغاء الحجز اليدوي بعد بدء موعده.'); END IF;
 v_deposit:=coalesce(v_booking.deposit_paid,0);
 IF p_refund_deposit IS TRUE AND v_deposit>0 THEN
  INSERT INTO public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at)
  VALUES(v_booking.owner_id,p_booking_id,v_deposit,'cash_refund','completed','cash','استرداد عربون حجز يدوي ملغي: '||coalesce(v_booking.stadium_name,'الملعب'),v_now,v_now);
  UPDATE public.bookings SET status='cancelled',deposit_paid=0,is_deposit_paid=false,is_paid=false,cancellation_reason='تم إلغاء الحجز اليدوي ورد العربون للعميل',cancelled_at=v_now,updated_at=v_now WHERE id=p_booking_id;
 ELSE
  UPDATE public.bookings SET status='cancelled',cancellation_reason=CASE WHEN v_deposit>0 THEN 'تم إلغاء الحجز اليدوي مع الاحتفاظ بالعربون كشرط جزائي' ELSE 'تم إلغاء الحجز اليدوي' END,cancelled_at=v_now,updated_at=v_now WHERE id=p_booking_id;
 END IF;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'deposit_refunded',p_refund_deposit AND v_deposit>0,'refunded_amount',CASE WHEN p_refund_deposit AND v_deposit>0 THEN v_deposit ELSE 0 END);
END;$function$;
REVOKE EXECUTE ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean) FROM anon,public;
GRANT EXECUTE ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean) TO authenticated,service_role;