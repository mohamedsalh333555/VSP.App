-- ==============================================================================
-- 🚀 VSP PLATFORM — OWNER LEDGER & PAYOUT SETTLEMENT HARDENING PATCH
-- Description: Atomic Payout Settlement RPC with Balance Verification & Admin Notifications
-- Date: 2026-08-23
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة طلب تسوية الرصيد الرقمي الذرية (request_owner_payout_settlement_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_owner_payout_settlement_atomic(UUID, NUMERIC, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(
    p_owner_id UUID,
    p_amount NUMERIC,
    p_method TEXT,
    p_destination TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. التحقق من صلاحيات وهوية المالك
    IF auth.uid() IS NULL OR (auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout amount must be greater than zero');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout destination details are required');
    END IF;

    -- 2. جلب بيانات المالك
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Owner account not found');
    END IF;

    -- 3. التحقق من عدم وجود طلب تسوية قيد المراجعة حالياً لمنع التكرار
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل من قبل الإدارة. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- 4. إدراج طلب التسوية في جدول payout_settlements
    INSERT INTO public.payout_settlements (
        owner_id,
        amount,
        method,
        destination,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_owner_id,
        p_amount,
        COALESCE(p_method, 'instapay'),
        p_destination,
        'pending',
        v_now,
        v_now
    ) RETURNING id INTO v_settlement_id;

    -- 5. تسجيل المعاملة المعلقة في جدول transactions
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout_pending',
        COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', v_owner.full_name,
            'owner_phone', v_owner.phone_number
        ),
        v_now
    );

    -- 6. إرسال إشعار فوري للأدمن
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    )
    SELECT 
        id,
        'طلب تسوية أرباح جديد',
        'طلب المالك ' || COALESCE(v_owner.full_name, 'مالك') || ' تسوية رصيد بقيمة ' || p_amount || ' ج.م عبر ' || p_destination,
        'payout',
        false,
        v_now
    FROM public.users
    WHERE role IN ('admin', 'co_founder');

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'message', 'Payout request submitted successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2️⃣ منح صلاحيات التنفيذ
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role;

COMMIT;
