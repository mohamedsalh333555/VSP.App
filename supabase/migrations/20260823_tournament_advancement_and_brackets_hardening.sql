-- ==============================================================================
-- 🚀 VSP PLATFORM — TOURNAMENT ADVANCEMENT & BRACKET HARDENING PATCH
-- Description: Atomic Match Score Recording, Winner Progression & Safe Bracket Reset
-- Date: 2026-08-23
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة تسجيل نتيجة المباراة وتصعيد الفائز ذرّياً (record_match_result_and_advance_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.record_match_result_and_advance_atomic(
    UUID, INT, INT, INT, INT, UUID, TEXT, JSONB
);

CREATE OR REPLACE FUNCTION public.record_match_result_and_advance_atomic(
    p_match_id UUID,
    p_home_score INT,
    p_away_score INT,
    p_home_penalties INT DEFAULT NULL,
    p_away_penalties INT DEFAULT NULL,
    p_winner_id UUID DEFAULT NULL,
    p_winner_name TEXT DEFAULT NULL,
    p_goal_details JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_match RECORD;
    v_champ RECORD;
    v_next_match RECORD;
    v_slot_field TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. جلب بيانات المباراة الحالية وقفلها
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- 2. تحديث نتيجة المباراة الحالية
    UPDATE public.tournament_matches
    SET 
        home_score = p_home_score,
        away_score = p_away_score,
        home_penalties = p_home_penalties,
        away_penalties = p_away_penalties,
        winner_id = p_winner_id,
        status = 'completed',
        is_completed = true,
        goal_details = COALESCE(p_goal_details, '[]'::jsonb),
        updated_at = v_now
    WHERE id = p_match_id;

    -- 3. إذا كانت هناك مباراة تالية، تصعيد الفائز فوراً
    IF v_match.next_match_id IS NOT NULL AND p_winner_id IS NOT NULL THEN
        -- تحديد الخانة (home أو away) بناء على مؤشر المباراة
        IF (v_match.match_index % 2 = 0) THEN
            UPDATE public.tournament_matches
            SET 
                home_team_id = p_winner_id,
                home_team_name = p_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        ELSE
            UPDATE public.tournament_matches
            SET 
                away_team_id = p_winner_id,
                away_team_name = p_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        END IF;
    ELSIF v_match.round_index = 0 AND p_winner_id IS NOT NULL THEN
        -- 4. المباراة النهائية: تتويج بطل البطولة
        UPDATE public.championships
        SET 
            champion_team_id = p_winner_id,
            champion_team_name = p_winner_name,
            status = 'completed',
            updated_at = v_now
        WHERE id = v_match.championship_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'match_id', p_match_id,
        'winner_id', p_winner_id,
        'is_final', (v_match.round_index = 0),
        'message', 'Match score recorded and winner advanced atomically'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2️⃣ دالة تهيئة وبدء القرعة بأمان (prepare_tournament_bracket_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.prepare_tournament_bracket_atomic(UUID);

CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket_atomic(
    p_championship_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    -- مسح أي مباريات سابقة للبطولة
    DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;

    -- تحديث حالة البطولة إلى ongoing
    UPDATE public.championships
    SET 
        status = 'ongoing',
        champion_team_id = NULL,
        champion_team_name = NULL,
        updated_at = v_now
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true,
        'championship_id', p_championship_id,
        'message', 'Tournament bracket prepared successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3️⃣ منح صلاحيات التنفيذ
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.record_match_result_and_advance_atomic(UUID, INT, INT, INT, INT, UUID, TEXT, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.prepare_tournament_bracket_atomic(UUID) TO authenticated, service_role;

COMMIT;
