import sys
sys.path.append('.')
from scripts.db_client import run_sql

sql = """
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
    v_prize NUMERIC;
    v_trophy_title TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_member_rec RECORD;
    v_awarded_count INT := 0;
BEGIN
    -- 1. Lock championship row
    SELECT * INTO v_champ 
    FROM public.championships 
    WHERE id = p_championship_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    -- 2. Authorization: organizer (owner) or admin/co_founder or service_role
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can crown tournament champion');
            END IF;
        END IF;
    END IF;

    -- 3. Resolve team name
    IF p_champion_team_name IS NULL OR TRIM(p_champion_team_name) = '' THEN
        SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
    ELSE
        v_team_name := p_champion_team_name;
    END IF;

    -- 4. Calculate documentary prize amount (prize_pool or grand_prize)
    v_prize := COALESCE(NULLIF(v_champ.prize_pool, 0), v_champ.grand_prize, 0);
    v_trophy_title := 'بطل بطولة ' || COALESCE(v_champ.name, 'VSP');

    -- 5. Update championship state
    UPDATE public.championships
    SET status = 'completed',
        champion_team_id = p_champion_team_id,
        champion_team_name = v_team_name,
        winner_team_id = p_champion_team_id,
        winner_team_name = v_team_name,
        updated_at = v_now
    WHERE id = p_championship_id;

    -- 6. Update team points and championships count (if not already crowned)
    IF v_champ.status IS DISTINCT FROM 'completed' OR v_champ.champion_team_id IS DISTINCT FROM p_champion_team_id THEN
        UPDATE public.teams
        SET championships_won = COALESCE(championships_won, 0) + 1,
            points = COALESCE(points, 0) + 100,
            updated_at = v_now
        WHERE id = p_champion_team_id;
    END IF;

    -- 7. Award trophies to ALL team members AND captain without duplicates
    FOR v_member_rec IN (
        SELECT DISTINCT u.user_id
        FROM (
            SELECT user_id FROM public.team_members WHERE team_id = p_champion_team_id
            UNION
            SELECT captain_id AS user_id FROM public.teams WHERE id = p_champion_team_id
        ) u
        WHERE u.user_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM public.player_trophies pt
              WHERE pt.user_id = u.user_id
                AND pt.championship_id = p_championship_id
          )
    ) LOOP
        INSERT INTO public.player_trophies (
            id,
            user_id,
            championship_id,
            title,
            prize_won,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_member_rec.user_id,
            p_championship_id,
            v_trophy_title,
            v_prize,
            v_now
        );

        -- Send celebratory notification to each champion player
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            message,
            type,
            metadata,
            created_at
        ) VALUES (
            v_member_rec.user_id,
            'مبروك! تتويجك بطلاً للبطولة',
            'تهانينا! لقد تم تتويج فريقك "' || COALESCE(v_team_name, '') || '" بطلاً لبطولة "' || COALESCE(v_champ.name, '') || '". تم إضافة الكأس إلى سجلك الشخصي!',
            'تهانينا! لقد تم تتويج فريقك "' || COALESCE(v_team_name, '') || '" بطلاً لبطولة "' || COALESCE(v_champ.name, '') || '". تم إضافة الكأس إلى سجلك الشخصي!',
            'tournament_champion',
            jsonb_build_object(
                'championship_id', p_championship_id,
                'team_id', p_champion_team_id,
                'team_name', v_team_name,
                'prize_won', v_prize
            ),
            v_now
        );

        v_awarded_count := v_awarded_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'champion_team_id', p_champion_team_id,
        'championship_id', p_championship_id,
        'team_name', v_team_name,
        'trophies_awarded', v_awarded_count,
        'prize_per_trophy', v_prize
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) TO authenticated;
"""

if __name__ == "__main__":
    print("Deploying updated crown_tournament_champion_atomic...")
    run_sql(sql)
    print("Successfully deployed crown_tournament_champion_atomic!")
