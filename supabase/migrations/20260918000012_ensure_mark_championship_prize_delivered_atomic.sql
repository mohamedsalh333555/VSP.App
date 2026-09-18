-- ==============================================================================
-- Migration: 20260918000012_ensure_mark_championship_prize_delivered_atomic.sql
-- Description: Formalize and ensure mark_championship_prize_delivered_atomic in migrations
-- ==============================================================================

-- 1. Ensure columns exist on public.championships
ALTER TABLE public.championships
ADD COLUMN IF NOT EXISTS prize_pool NUMERIC NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS prize_delivered BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS prize_delivered_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS prize_delivered_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS prize_delivery_notes TEXT;

-- 2. Ensure mark_championship_prize_delivered_atomic function
CREATE OR REPLACE FUNCTION public.mark_championship_prize_delivered_atomic(
    p_championship_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
    v_caller_id UUID := auth.uid();
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Authorization: service_role, admin, co_founder, or championship owner
    IF COALESCE(auth.role(), '') != 'service_role' THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً.');
        END IF;
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
        END IF;
        IF (v_champ.owner_id IS DISTINCT FROM v_caller_id) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بتوثيق تسليم الجائزة. العملية مقتصرة على منظم البطولة أو الإدارة.');
        END IF;
    ELSE
        SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
        END IF;
    END IF;

    -- 2. Status verification
    IF v_champ.status != 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تسليم الجائزة إلا بعد اكتمال وتتويج بطل البطولة رسمياً.');
    END IF;

    -- 3. Double-handover prevention
    IF COALESCE(v_champ.prize_delivered, false) = true THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'تم توثيق تسليم الجائزة المالية لهذه البطولة مسبقاً ولا يمكن تكرار التسليم.'
        );
    END IF;

    -- 4. Mark prize delivered atomically
    UPDATE public.championships
    SET prize_delivered = true,
        prize_delivered_at = v_now,
        prize_delivered_by = v_caller_id,
        prize_delivery_notes = TRIM(COALESCE(p_notes, '')),
        updated_at = v_now
    WHERE id = p_championship_id;

    -- 5. Audit log in transactions table
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        p_championship_id,
        v_champ.champion_user_id,
        COALESCE(v_champ.prize_pool, 0.00),
        'prize_payout',
        'cash',
        'completed',
        'توثيق تسليم الجائزة المالية يداً بيد لكابتن الفريق البطل',
        jsonb_build_object(
            'handover_by', v_caller_id,
            'handover_at', v_now,
            'notes', TRIM(COALESCE(p_notes, '')),
            'champion_team_id', v_champ.champion_team_id,
            'champion_team_name', v_champ.champion_team_name,
            'amount', COALESCE(v_champ.prize_pool, 0.00)
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم توثيق تسليم الجائزة المالية بنجاح.',
        'prize_delivered_at', v_now,
        'amount', COALESCE(v_champ.prize_pool, 0.00)
    );
END;
$$;

-- 3. Secure permissions
REVOKE EXECUTE ON FUNCTION public.mark_championship_prize_delivered_atomic(UUID, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mark_championship_prize_delivered_atomic(UUID, TEXT) TO authenticated, service_role;
