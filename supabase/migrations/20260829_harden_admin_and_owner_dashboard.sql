-- ==============================================================================
-- 🔒 VSP PLATFORM — ADMIN & OWNER DASHBOARD ZERO-TRUST SECURITY PATCH
-- Description: Enforces strict Admin/Co-Founder & service_role authorization
--              across all administrative RPC functions (Payouts, Upgrades, Approvals, Disputes).
-- Date: 2026-08-29
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة توثيق حساب المالك والملاعب والبطولات (admin_approve_owner_atomic)
-- الحماية: حصر صلاحية التوثيق بالأدمن والمؤسسين والـ service_role
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_approve_owner_atomic(UUID);

CREATE OR REPLACE FUNCTION public.admin_approve_owner_atomic(
    p_owner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    UPDATE public.users
    SET verification_status = 'approved',
        is_identity_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_owner_id;

    UPDATE public.stadiums
    SET is_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_owner_id;

    UPDATE public.championships
    SET is_approved = true,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_owner_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تهانينا! تم توثيق حسابك كصاحب ملعب رسمي 🏆',
        'تمت مراجعة مستنداتك وتوثيق حسابك بنجاح. ملاعبك وبطولاتك أصبحت الآن ظاهرة لجميع اللاعبين.',
        'stadium_approved',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_approve_owner_atomic(UUID) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 2️⃣ دالة تسجيل صرف تسوية الأرباح المالية (admin_record_payout_settlement_atomic)
-- الحماية: حصر تسجيل الحركات المالية بالسيرفر والإدارة
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_record_payout_settlement_atomic(UUID, NUMERIC, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.admin_record_payout_settlement_atomic(
    p_owner_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_reference TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_tx_id UUID;
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid payout amount');
    END IF;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        status,
        payment_method,
        reference_number,
        description,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout',
        'completed',
        p_payment_method,
        p_reference,
        'تسوية أرباح مالك ملعب من إدارة VSP',
        timezone('utc'::text, now())
    ) RETURNING id INTO v_tx_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تم تحويل أرباحك بنجاح! 💸',
        'تم إرسال مبلغ ' || p_amount || ' ج.م إلى حسابك عبر ' || p_payment_method || ' برقم مرجع: ' || p_reference,
        'info',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'transaction_id', v_tx_id, 'amount', p_amount);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_record_payout_settlement_atomic(UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 3️⃣ دالة ترقية باقة اشتراك المالك (admin_upgrade_owner_subscription_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_upgrade_owner_subscription_atomic(UUID, TEXT, INT);

CREATE OR REPLACE FUNCTION public.admin_upgrade_owner_subscription_atomic(
    p_owner_id UUID,
    p_plan TEXT,
    p_days INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_expires_at TIMESTAMPTZ;
    v_plan_title TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_admin_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_admin_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    -- التحقق من صحة الباقة
    IF p_plan NOT IN ('free_trial', 'basic', 'pro') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid subscription plan');
    END IF;

    v_expires_at := v_now + (p_days || ' days')::interval;

    IF p_plan = 'free_trial' THEN
        UPDATE public.users
        SET 
            subscription_plan = 'free_trial',
            trial_ends_at = v_expires_at,
            subscription_expires_at = NULL,
            updated_at = v_now
        WHERE id = p_owner_id;
        v_plan_title := 'الفترة التجريبية المجانية';
    ELSE
        UPDATE public.users
        SET 
            subscription_plan = p_plan,
            subscription_expires_at = v_expires_at,
            updated_at = v_now
        WHERE id = p_owner_id;
        v_plan_title := CASE WHEN p_plan = 'pro' THEN 'الباقة الاحترافية (Pro 👑)' ELSE 'الباقة الأساسية (Basic)' END;
    END IF;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    ) VALUES (
        p_owner_id,
        'تم ترقية اشتراكك بنجاح! 🏆',
        'تهانينا! تم تفعيل ' || v_plan_title || ' لمدة ' || p_days || ' يوماً. استمتع بكامل المزايا الآن.',
        'subscription',
        false,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'plan', p_plan,
        'expires_at', v_expires_at,
        'message', 'Owner subscription upgraded successfully'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upgrade_owner_subscription_atomic(UUID, TEXT, INT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 4️⃣ دالة حل النزاعات واعتماد نتائج المباريات (admin_resolve_dispute_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_resolve_dispute_atomic(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.admin_resolve_dispute_atomic(
    p_booking_id UUID,
    p_final_outcome TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin authorization required');
        END IF;
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    UPDATE public.bookings
    SET status = 'completed',
        final_outcome = p_final_outcome,
        match_result_status = 'confirmed',
        pending_outcome = NULL,
        requires_admin_intervention = false,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    IF v_booking.player_team_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية للمباراة: ' || p_final_outcome, 'result_confirmation', timezone('utc'::text, now())
        FROM public.teams WHERE id = v_booking.player_team_id;
    END IF;

    IF v_booking.opponent_team_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية للمباراة: ' || p_final_outcome, 'result_confirmation', timezone('utc'::text, now())
        FROM public.teams WHERE id = v_booking.opponent_team_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'outcome', p_final_outcome);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_dispute_atomic(UUID, TEXT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 5️⃣ دالة اعتماد طلبات تسوية أرباح المالكين (approve_payout_settlement_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.approve_payout_settlement_atomic(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.approve_payout_settlement_atomic(
    p_settlement_id UUID,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_settlement RECORD;
    v_admin_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات المشرف
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_admin_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_admin_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Admin authorization required');
        END IF;
    END IF;

    SELECT * INTO v_settlement FROM public.payout_settlements WHERE id = p_settlement_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found');
    END IF;

    IF v_settlement.status = 'completed' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Settlement already completed');
    END IF;

    UPDATE public.payout_settlements
    SET 
        status = 'completed',
        admin_notes = p_admin_notes,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_settlement_id;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        v_settlement.owner_id,
        v_settlement.amount,
        'payout_disbursed',
        v_settlement.method,
        jsonb_build_object(
            'settlement_id', p_settlement_id,
            'destination', v_settlement.destination,
            'approved_by', auth.uid(),
            'notes', p_admin_notes
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'settlement_id', p_settlement_id, 'amount', v_settlement.amount);
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_payout_settlement_atomic(UUID, TEXT) TO authenticated, service_role;

COMMIT;
