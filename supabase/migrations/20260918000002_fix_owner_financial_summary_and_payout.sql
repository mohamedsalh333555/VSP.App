-- =============================================================================
-- Migration: 20260918000002_fix_owner_financial_summary_and_payout.sql
-- Description:
--   1. Harden get_owner_financial_summary to enforce SSOT accounting:
--      - Only completed matches (status = 'completed') feed available_balance.
--      - Confirmed matches (status = 'confirmed') are quarantined in escrow_online_revenue.
--      - Handles partial deposits accurately (deposit_paid vs cash remainder).
--   2. Harden request_owner_payout_settlement_atomic to block payout requests
--      exceeding completed match earnings (prevents withdrawing escrow).
-- =============================================================================

-- ============================================================
-- (1) إصلاح get_owner_financial_summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_completed_online_rev NUMERIC := 0.0;   -- مباريات مكتملة فقط (جاهزة للصرف)
    v_escrow_online_rev NUMERIC := 0.0;      -- مباريات مؤكدة قادمة (أمانات محتجزة)
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_completed_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_completed_cash_rev NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
    v_debt_limit NUMERIC := 500.0;
    v_is_debt_blocked BOOLEAN := false;
    v_completed_bookings_count INT := 0;
BEGIN
    -- التحقق من الصلاحيات والتوثيق
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id != p_owner_id
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    -- مديونية الكاش وحدود الحساب
    SELECT accumulated_cash_debt, debt_limit, is_debt_blocked
    INTO v_accumulated_debt, v_debt_limit, v_is_debt_blocked
    FROM public.users WHERE id = p_owner_id;

    -- 1. ✅ الإيرادات الأونلاين المكتملة فعلاً (جاهزة للصرف والسحب)
    -- مع مراعاة احتساب مبلغ العربون فقط إذا كان الحجز جزئياً وتم دفع الباقي كاش بالملعب
    SELECT
        COALESCE(SUM(
            CASE 
                WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
                ELSE total_price
            END
        ), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0),
        COUNT(*)
    INTO
        v_completed_online_rev,
        v_total_gateway_fees,
        v_total_vsp_commission,
        v_completed_bookings_count
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';  -- ✅ مكتملة فقط

    -- 2. ⏳ أموال الضمان للمباريات المؤكدة القادمة (Escrow - لا تدخل في الرصيد القابل للسحب)
    SELECT COALESCE(SUM(
        CASE 
            WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
            ELSE total_price
        END
    ), 0.0)
    INTO v_escrow_online_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'confirmed';  -- ⏳ محتجزة حتى تكتمل المباراة

    -- صافي الأرباح القابلة للسحب
    v_net_completed_earnings := v_completed_online_rev - v_total_gateway_fees - v_total_vsp_commission;

    -- 3. المسحوبات المؤكدة والمعلقة
    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    -- 4. ✅ الرصيد الحقيقي القابل للسحب (بعد خصم المسحوبات ومديونية الكاش)
    v_available_balance := GREATEST(0.0,
        v_net_completed_earnings
        - v_total_withdrawn
        - v_pending_payouts
        - COALESCE(v_accumulated_debt, 0.0)
    );

    -- 5. إيرادات الكاش المستلمة بالملعب للمباريات المكتملة
    SELECT COALESCE(SUM(
        CASE 
            WHEN LOWER(COALESCE(payment_method, '')) = 'cash' THEN total_price
            WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN (total_price - deposit_paid)
            ELSE 0.0
        END
    ), 0.0) INTO v_completed_cash_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';  -- ✅ مكتملة فقط

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'total_online_revenue', ROUND(v_completed_online_rev + v_escrow_online_rev, 2),
        'completed_online_revenue', ROUND(v_completed_online_rev, 2),
        'escrow_online_revenue', ROUND(v_escrow_online_rev, 2),
        'total_gateway_fees', ROUND(v_total_gateway_fees, 2),
        'total_vsp_commission', ROUND(v_total_vsp_commission, 2),
        'net_online_earnings', ROUND(v_net_completed_earnings, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'cash_revenue', ROUND(v_completed_cash_rev, 2),
        'accumulated_cash_debt', ROUND(COALESCE(v_accumulated_debt, 0.0), 2),
        'debt_limit', ROUND(COALESCE(v_debt_limit, 500.0), 2),
        'is_debt_blocked', COALESCE(v_is_debt_blocked, false),
        'completed_bookings_count', v_completed_bookings_count
    );
END;
$function$;


-- ============================================================
-- (2) إصلاح request_owner_payout_settlement_atomic
-- ============================================================
CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(
    p_owner_id uuid,
    p_amount numeric,
    p_method text DEFAULT 'instapay'::text,
    p_destination text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_completed_online_revenue NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
BEGIN
    -- 1. التحقق من التوثيق والصلاحيات
    IF (auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
        END IF;
    END IF;

    -- 2. التحقق من صحة المدخلات
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'بيانات جهة التحويل مطلوبة (رقم انستاباي أو المحفظة).');
    END IF;

    -- 3. قفل سجل المالك لمنع الـ race conditions
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'حساب المالك غير موجود.');
    END IF;

    v_accumulated_debt := COALESCE(v_owner.accumulated_cash_debt, 0.0);

    -- 4. التحقق من عدم وجود طلب تسوية معلق قيد المراجعة
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- 5. ✅ حساب الرصيد الصافي من الحجوزات المكتملة فقط (مع مراعاة العربون)
    SELECT
        COALESCE(SUM(
            CASE 
                WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
                ELSE total_price
            END
        ), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0)
    INTO
        v_completed_online_revenue,
        v_total_gateway_fees,
        v_total_vsp_commission
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';  -- ✅ مكتملة فقط - حماية مالية من سحب أموال الضمان

    v_net_online_earnings := v_completed_online_revenue - v_total_gateway_fees - v_total_vsp_commission;

    -- 6. خصم المسحوبات السابقة والمعلقة
    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    -- 7. ✅ الرصيد المتاح الحقيقي القابل للسحب
    v_available_balance := GREATEST(0.0,
        v_net_online_earnings - v_total_withdrawn - v_pending_payouts - v_accumulated_debt
    );

    -- 8. ✅ التحقق من كفاية الرصيد القابل للسحب الفعلي
    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المبلغ المطلوب (' || p_amount || ' ج.م) يتجاوز رصيدك المتاح للسحب (' || ROUND(v_available_balance, 2) || ' ج.م). ملاحظة: مبالغ المباريات القادمة محتجزة في الضمان حتى تكتمل المباراة.'
        );
    END IF;

    -- 9. إنشاء سجل طلب التسوية
    INSERT INTO public.payout_settlements (
        owner_id, amount, method, destination, status, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, COALESCE(p_method, 'instapay'),
        p_destination, 'pending', v_now, v_now
    ) RETURNING id INTO v_settlement_id;

    -- 10. تسجيل حركة قيد معلقة في دفتر المعاملات transactions
    INSERT INTO public.transactions (
        user_id, amount, type, status, payment_method, metadata, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, 'payout_pending', 'pending',
        COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', COALESCE(v_owner.name, 'Unknown Owner'),
            'owner_phone', COALESCE(v_owner.phone, ''),
            'remaining_balance_after', ROUND(v_available_balance - p_amount, 2)
        ),
        v_now, v_now
    );

    -- 11. إرسال إشعار للإدارة
    INSERT INTO public.notifications (user_id, title, body, type, is_read, created_at)
    SELECT
        id,
        'طلب تسوية أرباح جديد',
        'طلب المالك ' || COALESCE(v_owner.name, 'مالك') || ' تسوية رصيد بقيمة ' || p_amount || ' ج.م عبر ' || p_destination,
        'payout', false, v_now
    FROM public.users
    WHERE role IN ('admin', 'co_founder');

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'available_balance', ROUND(v_available_balance - p_amount, 2),
        'message', 'تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.'
    );
END;
$function$;

-- ============================================================
-- (3) صلاحيات التنفيذ
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid, numeric, text, text) TO authenticated, service_role;
