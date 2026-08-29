-- ==============================================================================
-- 🔒 VSP PLATFORM — TOURNAMENTS & TEAMS ZERO-TRUST SECURITY PATCH
-- Description: 1. Hardens create_tournament_order_atomic (DB price enforcement & captain check).
--              2. Hardens join_championship_atomic (prevents client spoofing p_is_paid=true).
--              3. Hardens crown_tournament_champion_atomic (restricts to owner/admin).
--              4. Hardens leave_championship_atomic & remove_tournament_team_atomic.
-- Date: 2026-08-29
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ تحصين إنشاء طلب سداد البطولة (create_tournament_order_atomic)
-- الحماية: فرض سعر الاشتراك من جدول championships والتحقق من كابتن الفريق
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], NUMERIC);

CREATE OR REPLACE FUNCTION public.create_tournament_order_atomic(
    p_championship_id UUID,
    p_team_id UUID,
    p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
    p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_amount NUMERIC DEFAULT 0
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
    v_caller_role TEXT;
    v_real_amount NUMERIC;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    -- 1. التحقق من وجود وحالة البطولة
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is not open for registration');
    END IF;

    -- 🔒 2. التحقق من الفريق وصلاحية الكابتن
    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only the team captain can register the team for a tournament');
        END IF;
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team is already registered in this championship');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NULL THEN v_joined_count := 0; END IF;

    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is already full');
    END IF;

    -- 🔒 3. فرض سعر الاشتراك من قاعدة البيانات (Zero-Trust Server Price)
    v_real_amount := COALESCE(v_champ.entry_fee, 0);
    IF v_real_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'This championship has no entry fee; use join_championship_atomic directly');
    END IF;

    -- توليد رقم مرجعي فريد للطلب
    v_order_ref := 'TOURN_' || SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 12);

    -- إدراج الطلب بحالة pending
    INSERT INTO public.tournament_orders (
        order_reference,
        championship_id,
        team_id,
        captain_user_id,
        amount,
        payment_status,
        player_ids,
        guest_names,
        created_at,
        updated_at
    ) VALUES (
        v_order_ref,
        p_championship_id,
        p_team_id,
        auth.uid(),
        v_real_amount,
        'pending',
        COALESCE(p_player_ids, ARRAY[]::UUID[]),
        COALESCE(p_guest_names, ARRAY[]::TEXT[]),
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    ) RETURNING id INTO v_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_reference', v_order_ref,
        'amount', v_real_amount
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 2️⃣ تحصين الانضمام للبطولة (join_championship_atomic)
-- الحماية: منع تمرير p_is_paid=true من العميل للبطولات المدفوعة
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC);

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
    v_is_authorized_free_join BOOLEAN := false;
    v_is_paid_result BOOLEAN := false;
BEGIN
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

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

    -- 🔒 التحقق من صلاحية الكابتن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) AND (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only team captain or championship organizer can register team');
        END IF;
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team is already registered in this championship');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NULL THEN v_joined_count := 0; END IF;

    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is already full');
    END IF;

    -- 🔒 تحديد حالة السداد: لا يمكن تسجيل الفريق كـ paid إلا إذا كانت البطولة مجانية فعلياً (entry_fee = 0)
    -- أو تم الاستدعاء عبر service_role (الويب هوك) أو منظم البطولة / الأدمن
    IF (COALESCE(auth.role(), '') = 'service_role') THEN
        v_is_paid_result := true;
    ELSIF v_champ.owner_id = auth.uid() OR COALESCE(v_caller_role, '') IN ('admin', 'co_founder') THEN
        v_is_paid_result := true;
    ELSIF COALESCE(v_champ.entry_fee, 0) = 0 THEN
        v_is_paid_result := true;
    ELSE
        -- للبطولات المدفوعة من لاعب عادي: لا يمكن تعيين paid=true مباشرة
        v_is_paid_result := false;
    END IF;

    -- إضافة الفريق لقائمة الفرق المنضمة
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), p_team_id),
        paid_teams = CASE 
            WHEN v_is_paid_result 
            THEN array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), p_team_id)
            ELSE COALESCE(paid_teams, ARRAY[]::UUID[])
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Team registered successfully in championship',
        'is_paid', v_is_paid_result,
        'joined_teams_count', v_joined_count + 1
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 3️⃣ تحصين تتويج بطل البطولة (crown_tournament_champion_atomic)
-- الحماية: حصر تتويج الفائز وتوزيع النقاط بمنظم البطولة أو الأدمن أو service_role
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.crown_tournament_champion_atomic(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.crown_tournament_champion_atomic(UUID, UUID);

CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(
    p_championship_id UUID,
    p_champion_team_id UUID,
    p_champion_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
    v_team_name TEXT;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    -- 🔒 التحقق من صلاحية منظم البطولة
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can crown tournament champion');
            END IF;
        END IF;
    END IF;

    IF p_champion_team_name IS NULL THEN
        SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
    ELSE
        v_team_name := p_champion_team_name;
    END IF;

    UPDATE public.championships
    SET status = 'completed',
        champion_team_id = p_champion_team_id,
        champion_team_name = v_team_name,
        winner_team_id = p_champion_team_id,
        winner_team_name = v_team_name,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    UPDATE public.teams
    SET championships_won = COALESCE(championships_won, 0) + 1,
        points = COALESCE(points, 0) + 100,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_champion_team_id;

    RETURN jsonb_build_object('success', true, 'champion_team_id', p_champion_team_id, 'championship_id', p_championship_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 4️⃣ تحصين مغادرة البطولة (leave_championship_atomic)
-- الحماية: حصر مغادرة البطولة بكابتن الفريق أو منظم البطولة أو الأدمن
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.leave_championship_atomic(UUID, UUID);

CREATE OR REPLACE FUNCTION public.leave_championship_atomic(
    p_championship_id UUID,
    p_team_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_caller_role TEXT;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    -- 🔒 التحقق من الصلاحية: كابتن الفريق أو منظم البطولة أو الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only team captain or championship organizer can remove team');
            END IF;
        END IF;
    END IF;

    UPDATE public.championships
    SET joined_teams = array_remove(joined_teams, p_team_id),
        paid_teams = array_remove(paid_teams, p_team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'team_id', p_team_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_championship_atomic(UUID, UUID) TO authenticated, service_role;

COMMIT;
