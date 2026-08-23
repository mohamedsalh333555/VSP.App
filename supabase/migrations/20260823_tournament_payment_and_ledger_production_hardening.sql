-- ==============================================================================
-- 🏆 VSP PLATFORM — PRODUCTION PATCH: TOURNAMENT PAYMENTS & FINANCIAL LEDGER
-- Description: Server-Side Verified Tournament Orders, Webhook Confirmation, 
--              Transactions Table Hardening, and Owner Payout Settlements.
-- Date: 2026-08-23
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ تحديث جدول المعاملات المالية (Transactions Table Hardening)
-- ------------------------------------------------------------------------------
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS payment_method text,
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- إنشاء فهرس لتسريع استعلامات كشف حساب المالك
CREATE INDEX IF NOT EXISTS idx_transactions_user_created 
ON public.transactions (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_champ_created 
ON public.transactions (championship_id, created_at DESC) 
WHERE championship_id IS NOT NULL;


-- ------------------------------------------------------------------------------
-- 2️⃣ جدول طلبات سداد البطولات الموثقة (Tournament Orders Table)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tournament_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_reference TEXT UNIQUE NOT NULL,
    championship_id UUID NOT NULL REFERENCES public.championships(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    captain_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'cancelled')),
    player_ids UUID[] DEFAULT ARRAY[]::UUID[],
    guest_names TEXT[] DEFAULT ARRAY[]::TEXT[],
    paymob_transaction_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- فهارس جدول طلبات البطولات
CREATE INDEX IF NOT EXISTS idx_tournament_orders_ref ON public.tournament_orders (order_reference);
CREATE INDEX IF NOT EXISTS idx_tournament_orders_champ_team ON public.tournament_orders (championship_id, team_id);
CREATE INDEX IF NOT EXISTS idx_tournament_orders_status ON public.tournament_orders (payment_status);

-- ضبط سياسات الأمان (RLS) لجدول طلبات البطولات
ALTER TABLE public.tournament_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tournament_orders_select_policy" ON public.tournament_orders;
CREATE POLICY "tournament_orders_select_policy" ON public.tournament_orders
    FOR SELECT USING (
        auth.uid() = captain_user_id 
        OR EXISTS (
            SELECT 1 FROM public.championships c 
            WHERE c.id = tournament_orders.championship_id AND c.owner_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
        )
    );

DROP POLICY IF EXISTS "tournament_orders_insert_policy" ON public.tournament_orders;
CREATE POLICY "tournament_orders_insert_policy" ON public.tournament_orders
    FOR INSERT WITH CHECK (auth.uid() = captain_user_id);


-- ------------------------------------------------------------------------------
-- 3️⃣ دالة إنشاء طلب سداد بطولة مسبق (Create Tournament Order RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_tournament_order_atomic(
    p_championship_id UUID,
    p_team_id UUID,
    p_player_ids UUID[],
    p_guest_names TEXT[],
    p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_order_ref TEXT;
    v_order_id UUID;
    v_joined_count INT;
BEGIN
    -- التحقق من البطولة
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is not open for registration');
    END IF;

    -- التحقق من الفريق
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

    -- توليد رقم مرجعي فريد للطلب
    v_order_ref := 'CHAMP_' || SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 12);

    -- إدراج الطلب بحالة pending
    INSERT INTO public.tournament_orders (
        order_reference,
        championship_id,
        team_id,
        captain_user_id,
        amount,
        payment_status,
        player_ids,
        guest_names
    ) VALUES (
        v_order_ref,
        p_championship_id,
        p_team_id,
        auth.uid(),
        p_amount,
        'pending',
        COALESCE(p_player_ids, ARRAY[]::UUID[]),
        COALESCE(p_guest_names, ARRAY[]::TEXT[])
    ) RETURNING id INTO v_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_reference', v_order_ref,
        'amount', p_amount
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 4️⃣ دالة تأكيد سداد البطولة آلياً عبر الـ Webhook (Confirm Tournament Order RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(
    p_order_reference TEXT,
    p_paymob_transaction_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order RECORD;
    v_champ RECORD;
BEGIN
    SELECT * INTO v_order FROM public.tournament_orders 
    WHERE order_reference = p_order_reference FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament order not found');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Order already confirmed');
    END IF;

    -- تحديث حالة الطلب
    UPDATE public.tournament_orders
    SET 
        payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_order.id;

    -- إدراج الفريق في البطولة
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), v_order.team_id),
        paid_teams = array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), v_order.team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_order.championship_id;

    -- حفظ المعاملة المالية في جدول transactions
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        v_order.championship_id,
        v_order.captain_user_id,
        v_order.amount,
        'digital',
        'paymob',
        jsonb_build_object(
            'order_reference', v_order.order_reference,
            'paymob_transaction_id', p_paymob_transaction_id,
            'team_id', v_order.team_id
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Tournament order confirmed and team joined successfully',
        'championship_id', v_order.championship_id,
        'team_id', v_order.team_id
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 5️⃣ تحديث دالة الانضمام الذرية للبطولات (Hardened join_championship_atomic)
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

    -- التحقق من صلاحية الداعي: هل هو مالك البطولة أو أدمن لتجاوز قيد الدفع المجاني؟
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF v_caller_role IN ('admin', 'co_founder') OR v_champ.owner_id = auth.uid() THEN
        v_is_owner_or_admin := true;
    END IF;

    -- إضافة الفريق لقائمة الفرق المنضمة
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
-- 6️⃣ منح الصلاحيات للأدوار المعتمدة (Grant Permissions)
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;
