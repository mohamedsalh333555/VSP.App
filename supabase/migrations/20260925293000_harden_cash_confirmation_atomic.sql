-- Harden cash confirmation: server-authoritative total, cash-only payment method,
-- exact outstanding collection, and owner identity binding.
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid,p_owner_id uuid,p_total_price numeric DEFAULT NULL,p_collected_amount numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_cash_amount numeric; v_actual_deposit numeric; v_total_price numeric; v_remaining numeric; v_target_status text; v_now timestamptz:=timezone('utc',now());
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder')
  THEN RETURN jsonb_build_object('success',false,'message','غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.'); END IF;
 END IF;
 IF v_booking.status='cancelled' THEN RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي' USING ERRCODE='P0003',DETAIL='BOOKING_CANCELLED'; END IF;
 IF coalesce(v_booking.payment_method,'')<>'cash' THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تأكيد حجز غير نقدي كتحصيل كاش.'); END IF;
 IF v_booking.is_paid IS TRUE AND v_booking.payment_status='paid' THEN
  RETURN jsonb_build_object('success',true,'message','الحجز مؤكد ومسدد بالفعل مسبقاً.','already_confirmed',true,'booking_id',p_booking_id,'amount',0,'commission',0,'total_price',v_booking.total_price,'payment_method',v_booking.payment_method);
 END IF;
 v_total_price:=coalesce(v_booking.total_price,0);
 IF v_total_price<=0 THEN RETURN jsonb_build_object('success',false,'message','قيمة الحجز غير صالحة.'); END IF;
 IF p_total_price IS NOT NULL AND abs(p_total_price-v_total_price)>0.01 THEN RETURN jsonb_build_object('success',false,'message','قيمة الحجز المرسلة لا تطابق القيمة المسجلة.','expected_total_price',v_total_price); END IF;
 v_actual_deposit:=greatest(coalesce(v_booking.deposit_paid,0),0);
 v_remaining:=greatest(round(v_total_price-v_actual_deposit,2),0);
 IF v_remaining<=0 THEN
  UPDATE public.bookings SET is_paid=true,payment_status='paid',status=case when v_now>=end_time then 'completed' else status end,updated_at=v_now WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',0,'deposit_paid',v_actual_deposit,'total_price',v_total_price,'commission',0,'status',case when v_now>=v_booking.end_time then 'completed' else v_booking.status end,'payment_status','paid','already_confirmed',true);
 END IF;
 IF p_collected_amount IS NULL THEN v_cash_amount:=v_remaining; ELSE v_cash_amount:=round(p_collected_amount,2); END IF;
 IF v_cash_amount<=0 OR v_cash_amount>v_remaining OR abs(v_cash_amount-v_remaining)>0.01 THEN RETURN jsonb_build_object('success',false,'message','تأكيد التحصيل لا يتم إلا للمبلغ النقدي المتبقي بالكامل.','remaining_amount',v_remaining); END IF;
 v_target_status:=case when v_now>=v_booking.end_time then 'completed' else 'confirmed' end;
 UPDATE public.bookings SET is_paid=true,payment_status='paid',status=v_target_status,deposit_paid=v_total_price,vsp_commission=0,updated_at=v_now WHERE id=p_booking_id;
 INSERT INTO public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at)
 VALUES(v_booking.owner_id,p_booking_id,v_cash_amount,'cash_settlement','completed','cash','تحصيل كاش مؤكد بالملعب لحجز #'||substring(p_booking_id::text,1,8),v_now,v_now)
 ON CONFLICT (booking_id) WHERE type='cash_settlement' AND status='completed' DO UPDATE SET amount=EXCLUDED.amount,updated_at=v_now;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',v_cash_amount,'deposit_paid',v_total_price,'total_price',v_total_price,'commission',0,'status',v_target_status,'payment_status','paid');
END;$function$;