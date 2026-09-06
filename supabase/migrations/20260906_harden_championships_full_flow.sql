-- ==============================================================================
-- Migration: 20260906_harden_championships_full_flow.sql
-- Description: Comprehensive hardening for Championships Flow:
--   1. Centralized atomic bracket generation (generate_tournament_bracket_atomic)
--   2. Forward prepare_tournament_bracket_atomic to generate full fixtures safely
--   3. Secure join_championship_atomic against unpaid team backdoor
--   4. Over-capacity and race condition protection in confirm_tournament_order_atomic
--   5. Player trophies awarding for all team members in crown_tournament_champion_atomic
--   6. Status updates and transaction auditing in leave_championship_atomic
--   7. RLS hardening on championships insert (restricting to owners & admins)
-- ==============================================================================

-- 1️⃣ CENTRALIZED ATOMIC BRACKET GENERATION
-- ==============================================================================
DROP FUNCTION IF EXISTS public.generate_tournament_bracket_atomic(UUID);

CREATE OR REPLACE FUNCTION public.generate_tournament_bracket_atomic(p_championship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
    v_team_ids UUID[];
    v_total_teams INT;
    v_capacity INT := 4;
    v_total_rounds INT;
    v_start_round INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_match_count INT;
    v_shuffled_ids UUID[];
    v_slots UUID[];
    v_r INT;
    v_m INT;
    v_home_id UUID;
    v_away_id UUID;
    v_home_name TEXT;
    v_away_name TEXT;
    v_next_m INT;
    v_is_home_slot BOOLEAN;
BEGIN
    -- 1. Authentication and Authorization Check
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً.');
    END IF;

    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط منظم البطولة أو الأدمن يمكنه إطلاق القرعة.');
        END IF;
    END IF;

    IF v_champ.status = 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'هذه البطولة منتهية بالفعل.');
    END IF;

    -- Protect existing ongoing matches with recorded scores
    IF EXISTS (
        SELECT 1 FROM public.tournament_matches 
        WHERE championship_id = p_championship_id 
          AND (is_completed = true OR home_score IS NOT NULL OR away_score IS NOT NULL)
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إعادة توليد القرعة لوجود مباريات مسجلة النتائج أو مكتملة بالفعل.');
    END IF;

    -- 2. Select eligible teams (Strict Zero-Trust)
    IF COALESCE(v_champ.entry_fee, 0) > 0 THEN
        v_team_ids := COALESCE(v_champ.paid_teams, ARRAY[]::UUID[]);
    ELSE
        v_team_ids := COALESCE(v_champ.joined_teams, ARRAY[]::UUID[]);
    END IF;

    v_total_teams := COALESCE(array_length(v_team_ids, 1), 0);
    IF v_total_teams < 2 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب وجود فريقين مسجلين ومستوفين لشروط السداد على الأقل لبدء البطولة.');
    END IF;

    -- 3. Calculate target bracket capacity (power of 2: 4, 8, 16, 32)
    IF v_total_teams <= 4 THEN
        v_capacity := 4;
        v_total_rounds := 2; -- rounds: 1, 0
    ELSIF v_total_teams <= 8 THEN
        v_capacity := 8;
        v_total_rounds := 3; -- rounds: 2, 1, 0
    ELSIF v_total_teams <= 16 THEN
        v_capacity := 16;
        v_total_rounds := 4; -- rounds: 3, 2, 1, 0
    ELSE
        v_capacity := 32;
        v_total_rounds := 5; -- rounds: 4, 3, 2, 1, 0
    END IF;

    v_start_round := v_total_rounds - 1;

    -- 4. Clear any unplayed matches for this championship
    DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;

    -- 5. Create temporary working table for bracket generation
    CREATE TEMP TABLE temp_bracket_matches (
        round_idx INT,
        match_idx INT,
        match_id UUID DEFAULT gen_random_uuid(),
        next_match_id UUID,
        home_team_id UUID,
        home_team_name TEXT,
        away_team_id UUID,
        away_team_name TEXT,
        home_score INT,
        away_score INT,
        winner_id UUID,
        status TEXT DEFAULT 'scheduled',
        is_completed BOOLEAN DEFAULT false
    ) ON COMMIT DROP;

    -- Populate blank match nodes for all rounds (from start_round down to 0)
    FOR v_r IN REVERSE v_start_round..0 LOOP
        v_match_count := (1 << v_r); -- 2^v_r
        FOR v_m IN 0..(v_match_count - 1) LOOP
            INSERT INTO temp_bracket_matches (round_idx, match_idx)
            VALUES (v_r, v_m);
        END LOOP;
    END LOOP;

    -- Link each match to its parent in next round (next_match_id)
    UPDATE temp_bracket_matches curr
    SET next_match_id = parent.match_id
    FROM temp_bracket_matches parent
    WHERE parent.round_idx = curr.round_idx - 1
      AND parent.match_idx = (curr.match_idx / 2)
      AND curr.round_idx > 0;

    -- 6. Shuffle and populate first round
    SELECT ARRAY_AGG(t_id ORDER BY random()) INTO v_shuffled_ids
    FROM unnest(v_team_ids) AS t_id;

    -- Build slots array of length v_capacity
    v_slots := ARRAY[]::UUID[];
    FOR i IN 1..v_capacity LOOP
        IF i <= v_total_teams THEN
            v_slots := array_append(v_slots, v_shuffled_ids[i]);
        ELSE
            v_slots := array_append(v_slots, NULL); -- BYE
        END IF;
    END LOOP;

    -- Populate match participants in start_round
    v_match_count := (1 << v_start_round);
    FOR v_m IN 0..(v_match_count - 1) LOOP
        v_home_id := v_slots[(v_m * 2) + 1];
        v_away_id := v_slots[(v_m * 2) + 2];
        
        v_home_name := NULL;
        IF v_home_id IS NOT NULL THEN
            SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
        END IF;

        v_away_name := NULL;
        IF v_away_id IS NOT NULL THEN
            SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;
        END IF;

        -- BYE Logic Handling
        IF v_home_id IS NOT NULL AND v_away_id IS NULL THEN
            -- Home team automatically advances via BYE
            UPDATE temp_bracket_matches
            SET home_team_id = v_home_id,
                home_team_name = v_home_name,
                winner_id = v_home_id,
                home_score = 0,
                away_score = 0,
                is_completed = true,
                status = 'completed'
            WHERE round_idx = v_start_round AND match_idx = v_m;

            -- Propagate to next match
            v_next_m := v_m / 2;
            v_is_home_slot := (v_m % 2 = 0);
            IF v_start_round > 0 THEN
                IF v_is_home_slot THEN
                    UPDATE temp_bracket_matches
                    SET home_team_id = v_home_id, home_team_name = v_home_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                ELSE
                    UPDATE temp_bracket_matches
                    SET away_team_id = v_home_id, away_team_name = v_home_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                END IF;
            END IF;

        ELSIF v_home_id IS NULL AND v_away_id IS NOT NULL THEN
            -- Away team automatically advances via BYE
            UPDATE temp_bracket_matches
            SET away_team_id = v_away_id,
                away_team_name = v_away_name,
                winner_id = v_away_id,
                home_score = 0,
                away_score = 0,
                is_completed = true,
                status = 'completed'
            WHERE round_idx = v_start_round AND match_idx = v_m;

            -- Propagate to next match
            v_next_m := v_m / 2;
            v_is_home_slot := (v_m % 2 = 0);
            IF v_start_round > 0 THEN
                IF v_is_home_slot THEN
                    UPDATE temp_bracket_matches
                    SET home_team_id = v_away_id, home_team_name = v_away_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                ELSE
                    UPDATE temp_bracket_matches
                    SET away_team_id = v_away_id, away_team_name = v_away_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                END IF;
            END IF;

        ELSE
            -- Normal match
            UPDATE temp_bracket_matches
            SET home_team_id = v_home_id,
                home_team_name = v_home_name,
                away_team_id = v_away_id,
                away_team_name = v_away_name
            WHERE round_idx = v_start_round AND match_idx = v_m;
        END IF;
    END LOOP;

    -- 7. Bulk Insert from temp table into permanent tournament_matches
    -- Ordered by round_idx ASC (Round 0 -> 1 -> 2) to satisfy next_match_id FK constraint!
    INSERT INTO public.tournament_matches (
        id,
        championship_id,
        round_index,
        match_index,
        next_match_id,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        home_score,
        away_score,
        winner_id,
        status,
        is_completed,
        created_at,
        updated_at
    )
    SELECT 
        match_id,
        p_championship_id,
        round_idx,
        match_idx,
        next_match_id,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        home_score,
        away_score,
        winner_id,
        status,
        is_completed,
        v_now,
        v_now
    FROM temp_bracket_matches
    ORDER BY round_idx ASC;

    -- 8. Update Championship status to ongoing
    UPDATE public.championships
    SET status = 'ongoing',
        updated_at = v_now
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true,
        'championship_id', p_championship_id,
        'capacity', v_capacity,
        'total_teams', v_total_teams,
        'rounds_count', v_total_rounds,
        'message', 'تم توليد شجرة المباريات وإطلاق البطولة بنجاح.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_tournament_bracket_atomic(UUID) TO authenticated, service_role;


-- 2️⃣ FORWARD prepare_tournament_bracket_atomic SAFELY
-- ==============================================================================
-- Replace legacy wipe function with safe generation delegator
CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket_atomic(p_championship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.generate_tournament_bracket_atomic(p_championship_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.prepare_tournament_bracket_atomic(UUID) TO authenticated, service_role;


-- 3️⃣ SECURE join_championship_atomic AGAINST UNPAID TEAM BACKDOOR
-- ==============================================================================
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
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً للانضمام للبطولة.');
    END IF;

    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'انتهى التسجيل في هذه البطولة أو أنها لم تبدأ بعد.');
    END IF;

    -- Check registration_deadline
    IF v_champ.registration_deadline IS NOT NULL
       AND v_now > v_champ.registration_deadline
       AND COALESCE(auth.role(), '') != 'service_role'
    THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid())
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')
        THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'انتهت فترة التسجيل في هذه البطولة. لا يمكن إضافة فرق جديدة.'
            );
        END IF;
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود.');
    END IF;

    IF COALESCE(auth.role(), '') != 'service_role' THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_team.captain_id IS DISTINCT FROM auth.uid())
           AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder'))
           AND (v_champ.owner_id IS DISTINCT FROM auth.uid())
        THEN
            RETURN jsonb_build_object('success', false, 'error', 'فقط كابتن الفريق أو منظم البطولة يمكنه تسجيل الفريق.');
        END IF;
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'هذا الفريق مسجل في البطولة بالفعل.');
    END IF;

    v_joined_count := COALESCE(array_length(v_champ.joined_teams, 1), 0);
    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة مكتملة العدد. لا يمكن إضافة فرق جديدة.');
    END IF;

    -- 🔒 STRICTURE: In paid tournaments, regular players MUST go through payment order
    IF COALESCE(v_champ.entry_fee, 0) > 0 AND (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'هذه البطولة تتطلب سداد رسوم الاشتراك؛ يرجى إتمام السداد لتأكيد الانضمام.'
            );
        END IF;
    END IF;

    -- Update championship with new team
    UPDATE public.championships
    SET
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), p_team_id),
        paid_teams   = array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), p_team_id),
        updated_at = v_now
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تسجيل الفريق في البطولة بنجاح.',
        'is_paid', true,
        'joined_teams_count', v_joined_count + 1
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;


-- 4️⃣ OVER-CAPACITY & RACE CONDITION PROTECTION IN confirm_tournament_order_atomic
-- ==============================================================================
DROP FUNCTION IF EXISTS public.confirm_tournament_order_atomic(TEXT, TEXT);

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
    v_caller_role TEXT;
    v_joined_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 🔒 Restrict call to service_role (or admin)
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Tournament orders can only be confirmed via server webhook.');
        END IF;
    END IF;

    SELECT * INTO v_order FROM public.tournament_orders 
    WHERE order_reference = p_order_reference FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament order not found');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Order already confirmed');
    END IF;

    -- Fetch and lock the championship row
    SELECT * INTO v_champ FROM public.championships 
    WHERE id = v_order.championship_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Associated championship not found');
    END IF;

    v_joined_count := COALESCE(array_length(v_champ.joined_teams, 1), 0);

    -- 🛡️ RACE CONDITION CHECK: Championship closed or full between order and payment
    IF v_champ.status != 'open' OR v_joined_count >= v_champ.max_teams THEN
        UPDATE public.tournament_orders
        SET payment_status = 'failed_over_capacity',
            paymob_transaction_id = p_paymob_transaction_id,
            updated_at = v_now
        WHERE id = v_order.id;

        -- Record transaction entry for audit & accounting
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
            v_order.championship_id,
            v_order.captain_user_id,
            v_order.amount,
            'refund',
            'paymob',
            'completed',
            'استرداد رسوم البطولة لاكتمال المقاعد',
            jsonb_build_object(
                'paymob_transaction_id', p_paymob_transaction_id,
                'order_reference', p_order_reference,
                'team_id', v_order.team_id,
                'reason', 'tournament_full'
            ),
            v_now
        );

        -- Send push/in-app notification to captain
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.captain_user_id,
            'تعذر الانضمام للبطولة (اكتملت المقاعد)',
            'نعتذر، اكتملت مقاعد البطولة أثناء إتمام عملية الدفع. تم توثيق حركة استرداد المبلغ لك وسيتم إرجاعه لحسابك.',
            'tournament_update',
            v_now
        );

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Championship is full or closed; payment logged for refund',
            'refunded', true
        );
    END IF;

    -- Standard Confirmation: Update order status
    UPDATE public.tournament_orders
    SET 
        payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = v_now
    WHERE id = v_order.id;

    -- Add team to championship joined and paid lists
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), v_order.team_id),
        paid_teams = array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), v_order.team_id),
        updated_at = v_now
    WHERE id = v_order.championship_id;

    -- Log transaction
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
        v_order.championship_id,
        v_order.captain_user_id,
        v_order.amount,
        'digital',
        'paymob',
        'completed',
        'سداد رسوم اشتراك بطولة فرق',
        jsonb_build_object(
            'paymob_transaction_id', p_paymob_transaction_id,
            'order_reference', p_order_reference,
            'team_id', v_order.team_id
        ),
        v_now
    );

    RETURN jsonb_build_object('success', true, 'order_id', v_order.id, 'team_id', v_order.team_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) TO service_role;


-- 5️⃣ PLAYER TROPHIES & CROWNING IN crown_tournament_champion_atomic
-- ==============================================================================
DROP FUNCTION IF EXISTS public.crown_tournament_champion_atomic(UUID, UUID, TEXT);

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
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    -- Authorization: organizer or admin
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

    -- Update championship state
    UPDATE public.championships
    SET status = 'completed',
        champion_team_id = p_champion_team_id,
        champion_team_name = v_team_name,
        winner_team_id = p_champion_team_id,
        winner_team_name = v_team_name,
        updated_at = v_now
    WHERE id = p_championship_id;

    -- Update team points and championships count
    UPDATE public.teams
    SET championships_won = COALESCE(championships_won, 0) + 1,
        points = COALESCE(points, 0) + 100,
        updated_at = v_now
    WHERE id = p_champion_team_id;

    -- 🏆 AWARD TROPHIES TO ALL TEAM MEMBERS AND CAPTAIN!
    INSERT INTO public.player_trophies (user_id, championship_id, title, prize_won, created_at)
    SELECT DISTINCT 
        u.user_id, 
        p_championship_id, 
        'بطل بطولة ' || COALESCE(v_champ.name, 'VSP'), 
        COALESCE(v_champ.grand_prize, 0), 
        v_now
    FROM (
        SELECT user_id FROM public.team_members WHERE team_id = p_champion_team_id
        UNION
        SELECT captain_id AS user_id FROM public.teams WHERE id = p_champion_team_id
    ) u
    WHERE u.user_id IS NOT NULL;

    RETURN jsonb_build_object(
        'success', true,
        'champion_team_id', p_champion_team_id,
        'championship_id', p_championship_id,
        'team_name', v_team_name
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) TO authenticated, service_role;


-- 6️⃣ AUDITING & WITHDRAWAL STATUS IN leave_championship_atomic
-- ==============================================================================
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
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    -- Authorization: captain or organizer or admin
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only team captain or championship organizer can remove team');
            END IF;
        END IF;
    END IF;

    -- Remove team from championship arrays
    UPDATE public.championships
    SET joined_teams = array_remove(joined_teams, p_team_id),
        paid_teams = array_remove(paid_teams, p_team_id),
        updated_at = v_now
    WHERE id = p_championship_id;

    -- Update tournament_orders if there was an order for this team
    UPDATE public.tournament_orders
    SET payment_status = 'cancelled_withdrawal',
        updated_at = v_now
    WHERE championship_id = p_championship_id 
      AND team_id = p_team_id 
      AND payment_status = 'paid';

    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'team_id', p_team_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_championship_atomic(UUID, UUID) TO authenticated, service_role;


-- 7️⃣ RLS HARDENING ON CHAMPIONSHIPS INSERT
-- ==============================================================================
DROP POLICY IF EXISTS "championships_insert" ON public."championships";

CREATE POLICY "championships_insert" ON public."championships" 
AS PERMISSIVE FOR INSERT TO authenticated 
WITH CHECK (
    ((select auth.uid()) = owner_id)
    AND EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = (select auth.uid()) 
          AND (users.role IN ('owner', 'admin', 'co_founder') OR users.has_stadium = true)
    )
);
