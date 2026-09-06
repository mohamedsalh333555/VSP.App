import sys
sys.path.append('.')
from scripts.db_client import run_sql

sql = """
CREATE OR REPLACE FUNCTION public.record_match_result_and_advance_atomic(
    p_match_id uuid,
    p_home_score integer,
    p_away_score integer,
    p_home_penalties integer DEFAULT NULL::integer,
    p_away_penalties integer DEFAULT NULL::integer,
    p_winner_id uuid DEFAULT NULL::uuid,
    p_winner_name text DEFAULT NULL::text,
    p_goal_details jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_match RECORD;
    v_champ RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_min_players INT := 5;
    v_home_count INT := 0;
    v_away_count INT := 0;
    v_has_shortage BOOLEAN := FALSE;
    v_shortage_details TEXT := '';
    v_admin_rec RECORD;
    v_warning_title TEXT;
    v_warning_body TEXT;
BEGIN
    -- 1. جلب بيانات المباراة وقفلها
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- 2. التحقق من صلاحية مالك البطولة (owner_id) أو الأدمن
    SELECT * INTO v_champ FROM public.championships WHERE id = v_match.championship_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can submit scores');
            END IF;
        END IF;
    END IF;

    -- 3. فحص تحذيري: التحقق من الحد الأدنى للاعبين لكل فريق (دون منع تسجيل النتيجة)
    v_min_players := COALESCE(v_champ.min_players_per_team, 5);

    -- حساب عدد أعضاء الفريق الأول (home)
    IF v_match.home_team_id IS NOT NULL THEN
        SELECT COUNT(DISTINCT u.user_id) INTO v_home_count
        FROM (
            SELECT user_id FROM public.team_members WHERE team_id = v_match.home_team_id
            UNION
            SELECT captain_id AS user_id FROM public.teams WHERE id = v_match.home_team_id
        ) u
        WHERE u.user_id IS NOT NULL;

        IF v_home_count < v_min_players THEN
            v_has_shortage := TRUE;
            v_shortage_details := v_shortage_details || 'الفريق [' || COALESCE(v_match.home_team_name, 'Home') || '] يضم ' || v_home_count || ' لاعبين فقط (الحد الأدنى: ' || v_min_players || '). ';
        END IF;
    END IF;

    -- حساب عدد أعضاء الفريق الثاني (away)
    IF v_match.away_team_id IS NOT NULL THEN
        SELECT COUNT(DISTINCT u.user_id) INTO v_away_count
        FROM (
            SELECT user_id FROM public.team_members WHERE team_id = v_match.away_team_id
            UNION
            SELECT captain_id AS user_id FROM public.teams WHERE id = v_match.away_team_id
        ) u
        WHERE u.user_id IS NOT NULL;

        IF v_away_count < v_min_players THEN
            v_has_shortage := TRUE;
            v_shortage_details := v_shortage_details || 'الفريق [' || COALESCE(v_match.away_team_name, 'Away') || '] يضم ' || v_away_count || ' لاعبين فقط (الحد الأدنى: ' || v_min_players || '). ';
        END IF;
    END IF;

    -- إذا وجد نقص، إدراج إشعار تنبيه لكل مستخدمي admin / co_founder
    IF v_has_shortage THEN
        v_warning_title := 'تنبيه: نقص عدد اللاعبين في مباراة بطولة';
        v_warning_body := 'تم تسجيل نتيجة مباراة (الجولة ' || COALESCE(v_match.round_index::text, '1') || ' - المباراة ' || COALESCE(v_match.match_index::text, '1') || ') في بطولة "' || COALESCE(v_champ.name, '') || '" مع وجود نقص في عدد لاعبي الفريق: ' || v_shortage_details;

        FOR v_admin_rec IN (
            SELECT id FROM public.users 
            WHERE role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
        ) LOOP
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                message,
                type,
                metadata,
                created_at
            ) VALUES (
                v_admin_rec.id,
                v_warning_title,
                v_warning_body,
                v_warning_body,
                'match_roster_warning',
                jsonb_build_object(
                    'match_id', p_match_id,
                    'championship_id', v_match.championship_id,
                    'championship_name', v_champ.name,
                    'round_index', v_match.round_index,
                    'match_index', v_match.match_index,
                    'min_players_required', v_min_players,
                    'home_team_id', v_match.home_team_id,
                    'home_team_name', v_match.home_team_name,
                    'home_player_count', v_home_count,
                    'away_team_id', v_match.away_team_id,
                    'away_team_name', v_match.away_team_name,
                    'away_player_count', v_away_count,
                    'shortage_details', v_shortage_details
                ),
                v_now
            );
        END LOOP;
    END IF;

    -- 4. تحديث نتيجة المباراة الحالية (تسجيل النتيجة فعلياً دون تعطيل)
    UPDATE public.tournament_matches
    SET 
        home_score = p_home_score,
        away_score = p_away_score,
        home_penalties = p_home_penalties,
        away_penalties = p_away_penalties,
        winner_id = p_winner_id,
        winner_name = COALESCE(p_winner_name, winner_name),
        status = 'completed',
        is_completed = true,
        goal_details = COALESCE(p_goal_details, '[]'::jsonb)
    WHERE id = p_match_id;

    -- 5. تصعيد الفائز للمباراة التالية إذا وجدت
    IF v_match.next_match_id IS NOT NULL AND p_winner_id IS NOT NULL THEN
        IF (v_match.match_index % 2 = 0) THEN
            UPDATE public.tournament_matches
            SET home_team_id = p_winner_id,
                home_team_name = p_winner_name
            WHERE id = v_match.next_match_id;
        ELSE
            UPDATE public.tournament_matches
            SET away_team_id = p_winner_id,
                away_team_name = p_winner_name
            WHERE id = v_match.next_match_id;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'match_id', p_match_id,
        'winner_id', p_winner_id,
        'has_shortage_warning', v_has_shortage,
        'shortage_details', v_shortage_details
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.record_match_result_and_advance_atomic(uuid, integer, integer, integer, integer, uuid, text, jsonb) TO authenticated;
"""

if __name__ == "__main__":
    print("Deploying updated record_match_result_and_advance_atomic (clean column names)...")
    run_sql(sql)
    print("Successfully deployed record_match_result_and_advance_atomic!")
