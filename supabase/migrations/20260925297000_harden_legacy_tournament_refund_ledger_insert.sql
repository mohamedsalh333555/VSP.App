create or replace function public.record_tournament_refund_status_atomic(p_order_reference text,p_refund_status text,p_paymob_refund_id text default null,p_error_message text default null,p_refund_amount numeric default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_order record; v_admin_id uuid; v_now timestamptz:=timezone('utc',now()); v_amount numeric; v_updated integer:=0;
begin
 if coalesce(auth.role(),'')<>'service_role' and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','غير مصرح: تحديث حالة الاسترداد مقتصر على الخادم.'); end if;
 if p_refund_status not in ('refunded','refund_failed_manual_review') then return jsonb_build_object('success',false,'error','حالة الاسترداد غير صالحة.'); end if;
 select * into v_order from public.tournament_orders where order_reference=p_order_reference for update;
 if not found then return jsonb_build_object('success',false,'error','طلب اشتراك البطولة غير موجود.'); end if;
 if v_order.payment_status='refunded' then return jsonb_build_object('success',true,'already_refunded',true,'order_reference',p_order_reference,'status','refunded'); end if;
 if v_order.payment_status not in ('paid','failed_over_capacity','refund_failed_manual_review') then return jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','current_status',v_order.payment_status); end if;
 v_amount:=round(coalesce(nullif(p_refund_amount,0),v_order.amount),2);
 if v_amount<=0 then return jsonb_build_object('success',false,'error','مبلغ الاسترداد غير صالح.'); end if;
 update public.tournament_orders set payment_status=p_refund_status,updated_at=v_now where id=v_order.id;
 update public.transactions set amount=v_amount,status=case when p_refund_status='refunded' then 'completed' else 'failed' end,metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now,'refund_amount',v_amount,'principal_amount',v_order.amount) where championship_id=v_order.championship_id and type='refund' and metadata->>'order_reference'=p_order_reference;
 get diagnostics v_updated = row_count;
 if v_updated=0 then
  insert into public.transactions(user_id,championship_id,amount,type,status,payment_method,reference_number,metadata,created_at,updated_at)
  values(v_order.captain_user_id,v_order.championship_id,v_amount,'refund',case when p_refund_status='refunded' then 'completed' else 'failed' end,'paymob','REFUND_'||p_order_reference,jsonb_build_object('order_reference',p_order_reference,'paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now,'refund_amount',v_amount,'principal_amount',v_order.amount),v_now,v_now);
 end if;
 if p_refund_status='refunded' then
  insert into public.notifications(user_id,title,body,type,created_at) values(v_order.captain_user_id,'تم استرداد رسوم اشتراك البطولة بنجاح','تمت إعادة مبلغ رسوم الاشتراك ('||v_amount||' ج.م) بنجاح عبر Paymob (مرجع: '||coalesce(p_paymob_refund_id,'')||').','tournament_refund',v_now);
 else
  insert into public.notifications(user_id,title,body,type,created_at) values(v_order.captain_user_id,'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)','تعذر الاسترداد التلقائي للرسوم ('||v_amount||' ج.م). تم تحويل العملية للمراجعة اليدوية.','tournament_refund_manual',v_now);
  for v_admin_id in select id from public.users where role in ('admin','co_founder','cofounder','super_admin') loop
   insert into public.notifications(user_id,title,body,type,created_at) values(v_admin_id,'تنبيه مالي: فشل استرداد رسوم بطولة فرق','فشل استرداد الطلب '||p_order_reference||' (المبلغ: '||v_amount||' ج.م). السبب: '||coalesce(p_error_message,'Paymob API error')||'.','admin_alert',v_now);
  end loop;
 end if;
 return jsonb_build_object('success',true,'order_reference',p_order_reference,'status',p_refund_status,'paymob_refund_id',p_paymob_refund_id,'refund_amount',v_amount,'ledger_recorded',true);
end; $$;
