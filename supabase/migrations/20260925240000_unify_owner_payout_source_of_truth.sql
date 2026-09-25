-- VSP: owner payout must use the same financial source of truth as the owner dashboard.
-- Owner receives the full online principal actually collected.
-- VSP/Paymob fees are charged on top to the payer and are not deducted from owner proceeds.

CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(
    p_owner_id uuid,
    p_amount numeric,
    p_method text DEFAULT 'instapay',
    p_destination text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_pending_count integer;
    v_settlement_id uuid;
    v_owner record;
    v_caller_role text;
    v_now timestamptz := timezone('utc'::text, now());
    v_online_earned numeric := 0;
    v_total_withdrawn numeric := 0;
    v_pending_payouts numeric := 0;
    v_available_balance numeric := 0;
BEGIN
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres','service_role') THEN
        RETURN jsonb_build_object('success',false,'error','Authentication required');
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres','service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
            RETURN jsonb_build_object('success',false,'error','Unauthorized payout request');
        END IF;
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success',false,'error','يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR length(trim(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success',false,'error','بيانات جهة التحويل مطلوبة.');
    END IF;

    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success',false,'error','حساب المالك غير موجود.');
    END IF;

    SELECT count(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending','approved');

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success',false,'error','لديك طلب سحب قيد المراجعة بالفعل.');
    END IF;

    SELECT COALESCE(SUM(
        CASE
            WHEN COALESCE(b.deposit_paid,0) > 0 AND COALESCE(b.deposit_paid,0) < b.total_price
            THEN b.deposit_paid
            ELSE b.total_price
        END
    ),0)
    INTO v_online_earned
    FROM public.bookings b
    WHERE b.owner_id = p_owner_id
      AND lower(COALESCE(b.payment_method,'')) != 'cash'
      AND (b.payment_status = 'paid' OR b.is_paid = true)
      AND b.status IN ('completed','no_show');

    SELECT COALESCE(SUM(amount),0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount),0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending','approved');

    v_available_balance := GREATEST(0, v_online_earned - v_total_withdrawn - v_pending_payouts);

    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success',false,
            'error','المبلغ المطلوب ('||round(p_amount,2)||' ج.م) يتجاوز رصيدك المتاح للسحب ('||round(v_available_balance,2)||' ج.م).'
        );
    END IF;

    INSERT INTO public.payout_settlements(owner_id,amount,method,destination,status,created_at,updated_at)
    VALUES(p_owner_id,round(p_amount,2),coalesce(nullif(trim(p_method),''),'instapay'),trim(p_destination),'pending',v_now,v_now)
    RETURNING id INTO v_settlement_id;

    INSERT INTO public.transactions(user_id,amount,type,status,payment_method,metadata,created_at,updated_at)
    VALUES(
        p_owner_id,round(p_amount,2),'payout_pending','pending',
        coalesce(nullif(trim(p_method),''),'instapay'),
        jsonb_build_object('settlement_id',v_settlement_id,'destination',trim(p_destination),
          'owner_name',coalesce(v_owner.name,'Unknown Owner'),'owner_phone',coalesce(v_owner.phone,''),
          'remaining_balance_after',round(v_available_balance-p_amount,2)),
        v_now,v_now
    );

    INSERT INTO public.notifications(user_id,title,body,type,is_read,created_at)
    SELECT id,'طلب سحب أرباح جديد',
      'طلب المالك '||coalesce(v_owner.name,'مالك')||' سحب '||round(p_amount,2)||' ج.م عبر '||coalesce(nullif(trim(p_method),''),'instapay'),
      'payout',false,v_now
    FROM public.users
    WHERE role IN ('admin','co_founder','cofounder','super_admin');

    RETURN jsonb_build_object('success',true,'settlement_id',v_settlement_id,
      'available_balance',round(v_available_balance-p_amount,2),
      'message','تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.');
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) TO authenticated, service_role;
