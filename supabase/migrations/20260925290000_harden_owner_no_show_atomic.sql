-- Harden owner no-show recording: ownership, role, timing and cancelled-state checks.
CREATE OR REPLACE FUNCTION public.owner_record_no_show_atomic(p_booking_id uuid,p_owner_id uuid,p_notes text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_now timestamptz:=timezone('utc',now()); v_player_id uuid;
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin')
  THEN RETURN jsonb_build_object('success',false,'message','غير مصرح: تسجيل عدم الحضور متاح فقط لمالك الملعب أو الإدارة.'); END IF;
 END IF;
 IF v_booking.status='no_show' THEN RETURN jsonb_build_object('success',true,'message','تم تسجيل عدم الحضور مسبقاً.'); END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تسجيل عدم الحضور لحجز ملغى.'); END IF;
 IF v_booking.end_time IS NULL OR v_booking.end_time>v_now THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تسجيل عدم الحضور قبل انتهاء موعد الحجز.'); END IF;
 v_player_id:=coalesce(v_booking.user_id,v_booking.created_by_user_id);
 UPDATE public.bookings SET status='no_show',is_paid=(coalesce(deposit_paid,0)>0),
 payment_status=CASE WHEN coalesce(deposit_paid,0)>0 THEN 'paid' ELSE payment_status END,
 cancellation_reason='غياب اللاعب وعدم الحضور بالموعد المحدد (العربون تعويض للملعب)',
 notes=CASE WHEN length(trim(coalesce(p_notes,'')))>0 THEN coalesce(notes,'')||' | '||trim(p_notes) ELSE notes END,updated_at=v_now
 WHERE id=p_booking_id;
 IF v_player_id IS NOT NULL THEN
  UPDATE public.users SET fair_play_score=greatest(0,coalesce(fair_play_score,100)-10),updated_at=v_now WHERE id=v_player_id;
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_player_id,'تسجيل عدم حضور (No-Show)',
   'تم تسجيل عدم حضورك للمباراة المقررة في '||coalesce(v_booking.stadium_name,'الملعب')||'. تم احتساب العربون تعويضاً للملعب وفق شروط الحجز.','booking_no_show',v_now);
 END IF;
 RETURN jsonb_build_object('success',true,'message','تم تسجيل عدم حضور اللاعب واعتماد العربون كتعويض للملعب بنجاح.');
END;$function$;
REVOKE EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid,uuid,text) FROM anon,public;
GRANT EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid,uuid,text) TO authenticated,service_role;