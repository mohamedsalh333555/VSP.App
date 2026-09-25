-- Cancel abandoned tournament payment orders -- 2026-09-26
create or replace function public.cancel_tournament_payment_order_atomic(p_order_reference text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $f$
declare v_caller uuid:=auth.uid(); v_order record; v_found boolean:=false;
begin
 if v_caller is null then return jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً.'); end if;
 select id,user_id,payment_status into v_order from public.tournament_orders where order_reference=p_order_reference for update;
 if found then v_found:=true;
 else select id,user_id,payment_status into v_order from public.team_league_payments where order_reference=p_order_reference for update;
      if found then v_found:=true; end if;
 end if;
 if not v_found then return jsonb_build_object('success',false,'error','طلب الدفع غير موجود.'); end if;
 if v_order.user_id is distinct from v_caller and not public.is_admin_or_cofounder(v_caller) then return jsonb_build_object('success',false,'error','غير مصرح.'); end if;
 if v_order.payment_status='paid' then return jsonb_build_object('success',false,'error','الطلب مدفوع بالفعل ولا يمكن إلغاؤه.'); end if;
 if v_order.payment_status not in ('pending','cancelled') then return jsonb_build_object('success',true,'status',v_order.payment_status); end if;
 update public.tournament_orders set payment_status='cancelled',updated_at=now() where order_reference=p_order_reference and payment_status='pending';
 update public.team_league_payments set payment_status='cancelled',updated_at=now() where order_reference=p_order_reference and payment_status='pending';
 return jsonb_build_object('success',true,'status','cancelled','order_reference',p_order_reference);
end;
$f$;
revoke all on function public.cancel_tournament_payment_order_atomic(text) from public,anon;
grant execute on function public.cancel_tournament_payment_order_atomic(text) to authenticated;
