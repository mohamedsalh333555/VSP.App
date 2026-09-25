-- ==============================================================================
-- 🏆 VSP SPORTS PLATFORM — REALTIME ELO & STANDINGS CALCULATION FIX
-- File: supabase/migrations/20260925070000_fix_realtime_elo_calculation_and_standings.sql
-- ==============================================================================

-- 1️⃣ تحديث دالة احتساب الـ ELO اللحظي عند تأكيد نتيجة مباراة التحدي
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    home_elo INT;
    away_elo INT;
    new_home_elo INT;
    new_away_elo INT;
    outcome FLOAT;
BEGIN
    -- احتساب النقاط عند تأكيد نتيجة مباراة التحدي ولم تكن معالجة مسبقاً
    IF NEW.booking_type = 'challenge' 
       AND NEW.match_result_status = 'confirmed'
       AND NEW.final_outcome IS NOT NULL 
       AND COALESCE(NEW.elo_processed, false) = false THEN
        
        SELECT COALESCE(points, 1000) INTO home_elo FROM public.teams WHERE id = NEW.player_team_id;
        SELECT COALESCE(points, 1000) INTO away_elo FROM public.teams WHERE id = NEW.opponent_team_id;

        IF home_elo IS NOT NULL AND away_elo IS NOT NULL THEN
            IF NEW.final_outcome = 'homeWin' THEN outcome := 1.0;
            ELSIF NEW.final_outcome = 'draw' THEN outcome := 0.5;
            ELSE outcome := 0.0;
            END IF;

            new_home_elo := round(home_elo + 32 * (outcome - (1.0 / (1.0 + power(10, (away_elo - home_elo)::float / 400.0)))));
            new_away_elo := round(away_elo + 32 * ((1.0 - outcome) - (1.0 / (1.0 + power(10, (home_elo - away_elo)::float / 400.0)))));

            UPDATE public.teams 
            SET points = GREATEST(0, new_home_elo), 
                matches_played = COALESCE(matches_played, 0) + 1,
                wins = COALESCE(wins, 0) + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                draws = COALESCE(draws, 0) + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = COALESCE(losses, 0) + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.player_team_id;

            UPDATE public.teams 
            SET points = GREATEST(0, new_away_elo), 
                matches_played = COALESCE(matches_played, 0) + 1,
                wins = COALESCE(wins, 0) + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                draws = COALESCE(draws, 0) + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = COALESCE(losses, 0) + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.opponent_team_id;

            NEW.elo_processed := true;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- 2️⃣ إعادة ربط التريجر ليشمل حقل match_result_status
DROP TRIGGER IF EXISTS trg_calculate_elo ON public.bookings;
DROP TRIGGER IF EXISTS trg_match_completed ON public.bookings;

CREATE TRIGGER trg_calculate_elo
BEFORE UPDATE OF status, final_outcome, match_result_status ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.calculate_elo_on_match_completion();

GRANT EXECUTE ON FUNCTION public.calculate_elo_on_match_completion() TO authenticated, service_role;
