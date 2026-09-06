-- ==============================================================================
-- Migration: 20260906_harden_1v1_tournament_lifecycle.sql
-- Description: Complete 1v1 Tournament Lifecycle Engine:
--   1. Schema enhancements for vsp_1v1_tournaments (scheduled_at, champion_user_id, status)
--   2. Atomic join RPC (join_1v1_tournament_atomic) with capacity and concurrency locks
--   3. Atomic leave RPC (leave_1v1_tournament_atomic) for withdrawal during registration
--   4. Atomic final publish RPC (publish_1v1_final_standings_atomic) with champion determination
--   5. Team 1v1 Champion Badge RPC (check_team_has_1v1_champion)
--   6. RLS security policies for registration and standings viewing
-- ==============================================================================

-- 1️⃣ SCHEMA ENHANCEMENTS
-- ==============================================================================
ALTER TABLE public.vsp_1v1_tournaments
ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS champion_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS vsp_1v1_tournaments_status_check;
ALTER TABLE public.vsp_1v1_tournaments ADD CONSTRAINT vsp_1v1_tournaments_status_check 
CHECK (status = ANY (ARRAY['draft'::text, 'registration_open'::text, 'in_progress'::text, 'completed'::text, 'published'::text, 'archived'::text]));

ALTER TABLE public.teams 
ADD COLUMN IF NOT EXISTS has_1v1_champion BOOLEAN DEFAULT false;

ALTER TABLE public.player_trophies 
ADD COLUMN IF NOT EXISTS tournament_1v1_id UUID REFERENCES public.vsp_1v1_tournaments(id) ON DELETE SET NULL;

ALTER TABLE public.vsp_1v1_tournament_players
ADD COLUMN IF NOT EXISTS registered_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Add partial unique constraint to prevent duplicate registrations by the same user in a tournament
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_1v1_tournament_user'
    ) THEN
        ALTER TABLE public.vsp_1v1_tournament_players
        ADD CONSTRAINT uq_1v1_tournament_user UNIQUE (tournament_id, user_id);
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 2️⃣ ATOMIC JOIN FUNCTION (Instant Mobile Registration)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.join_1v1_tournament_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_champ RECORD;
    v_current_count INT;
    v_user RECORD;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً للمشاركة.');
    END IF;

    -- Lock tournament row for concurrency
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'registration_open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'التسجيل في هذه البطولة مغلق حالياً.');
    END IF;

    -- Check if player is already registered
    IF EXISTS (
        SELECT 1 FROM public.vsp_1v1_tournament_players 
        WHERE tournament_id = p_tournament_id AND user_id = v_caller_id
    ) THEN
        RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
    END IF;

    -- Check capacity
    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = p_tournament_id;

    IF v_current_count >= v_champ.target_player_count THEN
        RETURN jsonb_build_object('success', false, 'error', 'عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.');
    END IF;

    -- Fetch user profile
    SELECT name, profile_image_url INTO v_user 
    FROM public.users 
    WHERE id = v_caller_id;

    -- Insert player into active tournament roster
    INSERT INTO public.vsp_1v1_tournament_players (
        tournament_id,
        user_id,
        player_name,
        avatar_url,
        tackles,
        goals,
        skills,
        registered_at
    ) VALUES (
        p_tournament_id,
        v_caller_id,
        COALESCE(NULLIF(TRIM(v_user.name), ''), 'لاعب'),
        COALESCE(v_user.profile_image_url, ''),
        0,
        0,
        0,
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'تم تسجيلك في البطولة بنجاح! حظاً موفقاً.',
        'player_count', v_current_count + 1
    );
END;
$$;

-- 3️⃣ ATOMIC LEAVE FUNCTION
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.leave_1v1_tournament_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_champ RECORD;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً.');
    END IF;

    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'registration_open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إلغاء التسجيل بعد انطلاق البطولة أو إغلاق التسجيل.');
    END IF;

    DELETE FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = p_tournament_id AND user_id = v_caller_id;

    RETURN jsonb_build_object('success', true, 'message', 'تم إلغاء تسجيلك في البطولة.');
END;
$$;

-- 4️⃣ FINAL PUBLISH FUNCTION (Standings & Champion Designation & Trophies/Badge Write-In)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.publish_1v1_final_standings_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_champ RECORD;
    v_champion_user_id UUID := NULL;
    v_champion_name TEXT := NULL;
    v_champion_team_id UUID := NULL;
    v_trophy_id UUID;
BEGIN
    -- Admin authorization
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط الأدمن يمكنه اعتماد ونشر النتائج.');
        END IF;
    END IF;

    -- Lock tournament row
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    -- Find top player by total_points DESC, then goals, skills, tackles
    SELECT user_id, player_name INTO v_champion_user_id, v_champion_name
    FROM public.vsp_1v1_tournament_players
    WHERE tournament_id = p_tournament_id
    ORDER BY total_points DESC, goals DESC, skills DESC, tackles DESC
    LIMIT 1;

    IF v_champion_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يوجد لاعبين مسجلين في البطولة لتتويج بطل.');
    END IF;

    -- Archive previous completed/published tournaments
    UPDATE public.vsp_1v1_tournaments
    SET status = 'archived'
    WHERE status IN ('completed', 'published') AND id != p_tournament_id;

    -- Complete and publish target tournament
    UPDATE public.vsp_1v1_tournaments
    SET 
        status = 'completed',
        published_at = timezone('utc'::text, now()),
        champion_user_id = v_champion_user_id
    WHERE id = p_tournament_id;

    -- 🏆 1. INSERT INTO player_trophies (Personal Trophy Registry)
    IF NOT EXISTS (
        SELECT 1 FROM public.player_trophies 
        WHERE user_id = v_champion_user_id 
          AND (tournament_1v1_id = p_tournament_id OR title = 'بطل تحدي 1v1 - ' || COALESCE(v_champ.name, 'VSP 1v1'))
    ) THEN
        INSERT INTO public.player_trophies (
            id,
            user_id,
            tournament_1v1_id,
            title,
            prize_won,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_champion_user_id,
            p_tournament_id,
            'بطل تحدي 1v1 - ' || COALESCE(v_champ.name, 'VSP 1v1'),
            0,
            timezone('utc'::text, now())
        )
        RETURNING id INTO v_trophy_id;
    END IF;

    -- 👑 2. WRITE-IN TO teams FOR THE CHAMPION'S TEAM
    -- Reset current 1v1 champion flag from any other team
    UPDATE public.teams
    SET has_1v1_champion = false
    WHERE has_1v1_champion = true;

    -- Locate champion team (either as captain or roster member)
    SELECT team_id INTO v_champion_team_id
    FROM (
        SELECT id AS team_id FROM public.teams WHERE captain_id = v_champion_user_id
        UNION
        SELECT team_id FROM public.team_members WHERE user_id = v_champion_user_id
    ) t
    LIMIT 1;

    IF v_champion_team_id IS NOT NULL THEN
        UPDATE public.teams
        SET 
            has_1v1_champion = true,
            unlocked_badges = CASE 
                WHEN '1v1_champion' = ANY(COALESCE(unlocked_badges, ARRAY[]::text[])) 
                THEN unlocked_badges
                ELSE array_append(COALESCE(unlocked_badges, ARRAY[]::text[]), '1v1_champion')
            END,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_champion_team_id;
    END IF;

    -- 3. Backward-compatible update to legacy vsp_1vs1_players if row exists
    UPDATE public.vsp_1vs1_players
    SET titles = COALESCE(titles, 0) + 1,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_champion_user_id;

    RETURN jsonb_build_object(
        'success', true, 
        'tournament_id', p_tournament_id,
        'champion_user_id', v_champion_user_id,
        'champion_name', v_champion_name,
        'champion_team_id', v_champion_team_id,
        'trophy_recorded', true,
        'trophy_id', v_trophy_id,
        'team_badge_written', (v_champion_team_id IS NOT NULL)
    );
END;
$$;

-- 5️⃣ CHECK TEAM HAS 1v1 CHAMPION FUNCTION (Badge on Team Card)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.check_team_has_1v1_champion(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_has_champ BOOLEAN := false;
    v_latest_champ_user UUID;
BEGIN
    -- 0. Check persisted flag on team first (direct write-in column)
    SELECT COALESCE(has_1v1_champion, false) INTO v_has_champ
    FROM public.teams
    WHERE id = p_team_id;

    IF v_has_champ THEN
        RETURN true;
    END IF;

    -- 1. Check if unlocked_badges array contains 1v1_champion
    SELECT EXISTS (
        SELECT 1 FROM public.teams 
        WHERE id = p_team_id AND '1v1_champion' = ANY(COALESCE(unlocked_badges, ARRAY[]::text[]))
    ) INTO v_has_champ;

    IF v_has_champ THEN
        RETURN true;
    END IF;

    -- 2. Find champion of latest completed 1v1 tournament
    SELECT champion_user_id INTO v_latest_champ_user
    FROM public.vsp_1v1_tournaments
    WHERE status IN ('completed', 'published') AND champion_user_id IS NOT NULL
    ORDER BY published_at DESC NULLS LAST, created_at DESC
    LIMIT 1;

    IF v_latest_champ_user IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.teams WHERE id = p_team_id AND captain_id = v_latest_champ_user
            UNION ALL
            SELECT 1 FROM public.team_members WHERE team_id = p_team_id AND user_id = v_latest_champ_user
        ) INTO v_has_champ;

        IF v_has_champ THEN
            RETURN true;
        END IF;
    END IF;

    -- 3. Fallback check on legacy table if applicable
    SELECT EXISTS (
        SELECT 1
        FROM public.team_members tm
        JOIN public.vsp_1vs1_players p1v1 ON tm.user_id = p1v1.id
        WHERE tm.team_id = p_team_id AND p1v1.titles > 0
    ) INTO v_has_champ;

    RETURN COALESCE(v_has_champ, false);
END;
$$;

-- 6️⃣ RLS POLICIES FOR 1v1 TABLES
-- ==============================================================================
ALTER TABLE public.vsp_1v1_tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vsp_1v1_tournament_players ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active or completed 1v1 tournaments" ON public.vsp_1v1_tournaments;
CREATE POLICY "Anyone can view active or completed 1v1 tournaments"
ON public.vsp_1v1_tournaments
AS PERMISSIVE FOR SELECT
TO authenticated, anon
USING (status IN ('registration_open', 'in_progress', 'completed', 'published', 'archived'));

DROP POLICY IF EXISTS "Anyone can view tournament players" ON public.vsp_1v1_tournament_players;
CREATE POLICY "Anyone can view tournament players"
ON public.vsp_1v1_tournament_players
AS PERMISSIVE FOR SELECT
TO authenticated, anon
USING (true);

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.join_1v1_tournament_atomic(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.leave_1v1_tournament_atomic(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.publish_1v1_final_standings_atomic(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_team_has_1v1_champion(UUID) TO authenticated, anon, service_role;
