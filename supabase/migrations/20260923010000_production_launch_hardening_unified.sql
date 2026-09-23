-- =====================================================================================
-- 🚀 VSP Production Launch Hardening & State Reconciliation (Unified)
-- =====================================================================================
-- التاريخ: 2026-09-23
-- النطاق الصارم المعتمد:
-- 1. إزالة الدوال الميتة والمهملة (Dead Code Elimination).
-- 2. سحب صلاحيات TRUNCATE و DELETE الخطيرة عن جدول users (Stage 1 Security).
-- 3. تحصين تريجر المستخدمين لمنع تصعيد الصلاحيات لـ admin مع الحفاظ على تسجيل المالك.
-- 4. التوثيق المالي للدوال الحية بأثر رجعي (completed only + عزل الـ Escrow).
-- =====================================================================================

-- 1️⃣ أولاً: حذف الدوال الميتة المتفق عليها
DROP FUNCTION IF EXISTS public.get_owner_copilot_financial_facts(uuid, date, date, uuid);
DROP FUNCTION IF EXISTS public.get_owner_copilot_financial_facts;
DROP FUNCTION IF EXISTS public.test_trigger_behavior();

-- 2️⃣ ثانياً: سحب الصلاحيات الخطيرة عن جدول users (Stage 1)
REVOKE TRUNCATE, DELETE, TRIGGER, REFERENCES ON TABLE public.users FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.users FROM authenticated;

-- 3️⃣ ثالثاً: تحصين تريجر المستخدمين ضد تصعيد الصلاحيات (مع ضمان مسار تسجيل المالك)
CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_is_admin BOOLEAN := false;
BEGIN
    -- السماح للخدمات الإدارية ولحساب postgres
    IF COALESCE(auth.role(), '') = 'service_role'
       OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        RETURN NEW;
    END IF;

    -- التحقق من صلاحيات المدير الحالية
    IF auth.uid() IS NOT NULL THEN
        SELECT (role = ANY (ARRAY['admin','co_founder','super_admin','cofounder']))
        INTO v_is_admin FROM public.users WHERE id = auth.uid();
    END IF;

    IF COALESCE(v_is_admin, false) THEN 
        RETURN NEW; 
    END IF;

    -- 🛡️ حماية الرتبة (Role):
    -- يُسمح فقط بتحويل player -> owner أثناء مرحلة التسجيل (is_registration_complete = false) لنفس المستخدم
    -- أي محاولة لإعطاء رتبة إدارية (admin / co_founder) تُرفض فوراً بـ PERMISSION_DENIED
    IF (OLD.role IS DISTINCT FROM NEW.role) THEN
        IF NOT (
            OLD.role = 'player' AND NEW.role = 'owner'
            AND COALESCE(OLD.is_registration_complete, false) = false
            AND auth.uid() = OLD.id
        ) THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: role change restricted to administrators.'
                USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SOVEREIGN_FIELD_UPDATE';
        END IF;
    END IF;

    -- 🛡️ حماية الحقول السيادية والحساسة
    IF (OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan AND
        NOT (COALESCE(OLD.is_registration_complete, false) = false AND auth.uid() = OLD.id)) OR
       (OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at) OR
       (OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at AND
        NOT (COALESCE(OLD.is_registration_complete, false) = false AND auth.uid() = OLD.id)) OR
       (OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees) OR
       (OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned) OR
       (OLD.no_show_count IS DISTINCT FROM NEW.no_show_count) OR
       (OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified) OR
       (OLD.verification_status IS DISTINCT FROM NEW.verification_status) OR
       (OLD.is_blocked IS DISTINCT FROM NEW.is_blocked) OR
       (OLD.accumulated_cash_debt IS DISTINCT FROM NEW.accumulated_cash_debt) OR
       (OLD.debt_limit IS DISTINCT FROM NEW.debt_limit) OR
       (OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked) OR
       (OLD.points IS DISTINCT FROM NEW.points) THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Modifying security-sensitive user fields is restricted.'
            USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SENSITIVE_FIELD_UPDATE';
    END IF;

    RETURN NEW;
END;
$function$;

-- 4️⃣ رابعاً: التوثيق المالي للدوال الحية بأثر رجعي
-- View: v_financial_reconciliation (حساب المكتمل فقط status = 'completed')
CREATE OR REPLACE VIEW public.v_financial_reconciliation AS
SELECT 
    u.id AS owner_id,
    u.name AS owner_name,
    u.phone AS owner_phone,
    count(b.id) FILTER (WHERE (b.status <> 'cancelled'::text)) AS active_bookings_count,
    COALESCE(sum(b.total_price) FILTER (WHERE ((b.payment_method <> 'cash'::text) AND ((b.payment_status = 'paid'::text) OR (b.is_paid = true)) AND (b.status = 'completed'::text))), 0.0) AS total_online_revenue,
    COALESCE(sum(COALESCE(b.gateway_fee, b.platform_fee, 0.0)) FILTER (WHERE ((b.payment_method <> 'cash'::text) AND ((b.payment_status = 'paid'::text) OR (b.is_paid = true)) AND (b.status = 'completed'::text))), 0.0) AS total_gateway_fees,
    COALESCE(sum(COALESCE(b.vsp_commission, round((b.total_price * 0.02), 2))) FILTER (WHERE (((b.payment_status = 'paid'::text) OR (b.is_paid = true)) AND (b.status = 'completed'::text))), 0.0) AS total_platform_commission,
    COALESCE(sum(b.total_price) FILTER (WHERE ((b.payment_method = 'cash'::text) AND ((b.payment_status = 'paid'::text) OR (b.is_paid = true)) AND (b.status = 'completed'::text))), 0.0) AS total_pitch_cash_revenue,
    COALESCE(u.accumulated_cash_debt, 0.0) AS accumulated_cash_debt,
    COALESCE(u.debt_limit, 500.0) AS debt_limit,
    COALESCE(u.is_debt_blocked, false) AS is_debt_blocked,
    COALESCE(( SELECT sum(ps.amount) AS sum
           FROM payout_settlements ps
          WHERE ((ps.owner_id = u.id) AND (ps.status = 'completed'::text))), 0.0) AS total_withdrawn,
    COALESCE(( SELECT sum(ps.amount) AS sum
           FROM payout_settlements ps
          WHERE ((ps.owner_id = u.id) AND (ps.status = ANY (ARRAY['pending'::text, 'approved'::text])))), 0.0) AS pending_payouts
   FROM (users u
     LEFT JOIN bookings b ON ((b.owner_id = u.id)))
  WHERE (u.role = ANY (ARRAY['owner'::text, 'admin'::text, 'co_founder'::text]))
  GROUP BY u.id, u.name, u.phone, u.accumulated_cash_debt, u.debt_limit, u.is_debt_blocked;

GRANT SELECT ON public.v_financial_reconciliation TO authenticated, service_role;

-- Function: get_owner_financial_summary
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_completed_online_rev NUMERIC := 0.0;
    v_escrow_online_rev NUMERIC := 0.0;
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
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id != p_owner_id
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    SELECT accumulated_cash_debt, debt_limit, is_debt_blocked
    INTO v_accumulated_debt, v_debt_limit, v_is_debt_blocked
    FROM public.users WHERE id = p_owner_id;

    -- ✅ المكتملة فقط - قابلة للسحب
    SELECT
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0),
        COUNT(*)
    INTO v_completed_online_rev, v_total_gateway_fees, v_total_vsp_commission, v_completed_bookings_count
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    -- ⏳ محتجزة - للعرض فقط
    SELECT COALESCE(SUM(total_price), 0.0)
    INTO v_escrow_online_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'confirmed';

    v_net_completed_earnings := v_completed_online_rev;

    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    v_available_balance := GREATEST(0.0, v_completed_online_rev - v_total_withdrawn - v_pending_payouts);

    SELECT COALESCE(SUM(total_price), 0.0) INTO v_completed_cash_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) = 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'total_online_revenue', ROUND(v_completed_online_rev + v_escrow_online_rev, 2),
        'completed_online_revenue', ROUND(v_completed_online_rev, 2),
        'escrow_online_revenue', ROUND(v_escrow_online_rev, 2),
        'total_gateway_fees', 0.0,
        'total_vsp_commission', 0.0,
        'net_online_earnings', ROUND(v_completed_online_rev, 2),
        'owner_online_earnings', ROUND(v_completed_online_rev, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'cash_revenue', ROUND(v_completed_cash_rev, 2),
        'accumulated_cash_debt', 0.0,
        'debt_limit', 0.0,
        'is_debt_blocked', false,
        'owner_total_revenue', ROUND(v_completed_online_rev + v_completed_cash_rev, 2),
        'completed_bookings_count', v_completed_bookings_count
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated, service_role;

-- Function: request_owner_payout_settlement_atomic
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
    v_total_online_revenue NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
BEGIN
    IF (auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'بيانات جهة التحويل مطلوبة.');
    END IF;

    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'حساب المالك غير موجود.');
    END IF;

    v_accumulated_debt := COALESCE(v_owner.accumulated_cash_debt, 0.0);

    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- ✅ حماية مالية: الرصيد يُحسب من الحجوزات المكتملة فقط
    SELECT
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0)
    INTO v_total_online_revenue, v_total_gateway_fees, v_total_vsp_commission
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    v_net_online_earnings := v_total_online_revenue;

    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    v_available_balance := GREATEST(0.0, v_total_online_revenue - v_total_withdrawn - v_pending_payouts);

    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المبلغ المطلوب (' || p_amount || ' ج.م) يتجاوز رصيدك المتاح للسحب (' || ROUND(v_available_balance, 2) || ' ج.م). ملاحظة: مبالغ المباريات القادمة محتجزة حتى تكتمل.'
        );
    END IF;

    INSERT INTO public.payout_settlements (
        owner_id, amount, method, destination, status, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, COALESCE(p_method, 'instapay'), p_destination, 'pending', v_now, v_now
    ) RETURNING id INTO v_settlement_id;

    INSERT INTO public.transactions (
        user_id, amount, type, status, payment_method, metadata, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, 'payout_pending', 'pending', COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', COALESCE(v_owner.name, 'Unknown Owner'),
            'owner_phone', COALESCE(v_owner.phone, ''),
            'remaining_balance_after', ROUND(v_available_balance - p_amount, 2)
        ),
        v_now, v_now
    );

    INSERT INTO public.notifications (user_id, title, body, type, is_read, created_at)
    SELECT id,
        'طلب تسوية أرباح جديد',
        'طلب المالك ' || COALESCE(v_owner.name, 'مالك') || ' تسوية رصيد بقيمة ' || p_amount || ' ج.م عبر ' || p_destination,
        'payout', false, v_now
    FROM public.users WHERE role IN ('admin', 'co_founder');

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'available_balance', ROUND(v_available_balance - p_amount, 2),
        'message', 'تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid, numeric, text, text) TO authenticated, service_role;
