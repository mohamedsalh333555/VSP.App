-- ==============================================================================
-- 🚀 VSP PLATFORM — FINAL AUDIT REMEDIATION PATCH (SUPABASE SQL EDITOR)
-- Description: Payout Settlements Engine, Financial Ledger Hardening, 
--              and Championship Join Security Protection.
-- Date: 2026-08-23
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ جدول طلبات تسوية وصرف مستحقات المالكين (Payout Settlements Table)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payout_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    method TEXT NOT NULL CHECK (method IN ('instapay', 'wallet', 'bank', 'unknown')),
    destination TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- فهارس تسريع الاستعلامات
CREATE INDEX IF NOT EXISTS idx_payout_settlements_owner ON public.payout_settlements (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payout_settlements_status ON public.payout_settlements (status, created_at DESC);

-- تفعيل سياسات الأمان على مستوى الصف (RLS)
ALTER TABLE public.payout_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payout_settlements_select_policy" ON public.payout_settlements;
CREATE POLICY "payout_settlements_select_policy" ON public.payout_settlements
    FOR SELECT USING (
        auth.uid() = owner_id 
        OR EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
        )
    );

DROP POLICY IF EXISTS "payout_settlements_insert_policy" ON public.payout_settlements;
CREATE POLICY "payout_settlements_insert_policy" ON public.payout_settlements
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "payout_settlements_update_policy" ON public.payout_settlements;
CREATE POLICY "payout_settlements_update_policy" ON public.payout_settlements
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
        )
    );


-- ------------------------------------------------------------------------------
-- 2️⃣ دالة طلب تسوية وصرف المستحقات الذرية (Request Payout Settlement RPC)
-- ------------------------------------------------------------------------------
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
    v_settlement_id UUID;
    v_user_role TEXT;
BEGIN
    -- التحقق من هوية وصلاحية المالك
    IF auth.uid() IS NULL OR auth.uid() != p_owner_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout amount must be greater than zero');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout destination details are required');
    END IF;

    -- إدراج طلب التسوية في جدول payout_settlements
    INSERT INTO public.payout_settlements (
        owner_id,
        amount,
        method,
        destination,
        status
    ) VALUES (
        p_owner_id,
        p_amount,
        COALESCE(p_method, 'unknown'),
        p_destination,
        'pending'
    ) RETURNING id INTO v_settlement_id;

    -- تسجيل الحركة المالية في جدول المعاملات (transactions)
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
        'payout_request',
        p_method,
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'status', 'pending'
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'amount', p_amount,
        'message', 'Payout settlement requested successfully'
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 3️⃣ دالة اعتماد وصرف التسوية من الإدارة (Approve Payout Settlement RPC)
-- ------------------------------------------------------------------------------
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
    -- التحقق من صلاحيات المشرف
    SELECT role INTO v_admin_role FROM public.users WHERE id = auth.uid();
    IF v_admin_role NOT IN ('admin', 'co_founder') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Admin authorization required');
    END IF;

    SELECT * INTO v_settlement FROM public.payout_settlements WHERE id = p_settlement_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found');
    END IF;

    IF v_settlement.status = 'completed' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Settlement already completed');
    END IF;

    -- تحديث حالة طلب التسوية
    UPDATE public.payout_settlements
    SET 
        status = 'completed',
        admin_notes = p_admin_notes,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_settlement_id;

    -- تسجيل حركة التأكيد في جدول المعاملات
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

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Payout settlement completed and recorded successfully',
        'settlement_id', p_settlement_id
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 4️⃣ تحديث دالة الانضمام للبطولات مع تأمين الدفع (Hardened join_championship_atomic)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_championship_atomic(
    p_championship_id UUID,
    p_team_id UUID,
    p_is_paid BOOLEAN DEFAULT false,
    p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
    p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_total_paid_amount NUMERIC DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_joined_count INT;
    v_caller_role TEXT;
    v_is_owner_or_admin BOOLEAN := false;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship registration is closed');
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team is already registered in this championship');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NULL THEN v_joined_count := 0; END IF;

    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is already full');
    END IF;

    -- التحقق من صلاحية الداعي
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF v_caller_role IN ('admin', 'co_founder') OR v_champ.owner_id = auth.uid() THEN
        v_is_owner_or_admin := true;
    END IF;

    -- إضافة الفريق لقائمة الفرق المنضمة وقائمة المسددين
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), p_team_id),
        paid_teams = CASE 
            WHEN (p_is_paid OR v_champ.entry_fee = 0 OR v_is_owner_or_admin) 
            THEN array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), p_team_id)
            ELSE paid_teams 
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Team registered successfully in championship',
        'joined_teams_count', v_joined_count + 1
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 5️⃣ منح الصلاحيات للأدوار المعتمدة (Grant Permissions)
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_payout_settlement_atomic(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;
