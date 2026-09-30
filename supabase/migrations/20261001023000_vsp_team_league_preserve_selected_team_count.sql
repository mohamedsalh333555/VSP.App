-- ==============================================================================
-- Migration: 20261001023000_vsp_team_league_preserve_selected_team_count.sql
-- Purpose:
--   Team League supports 4-8 teams. Preserve the selected max_teams value
--   instead of forcing every Team League to 4 teams.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.vsp_guard_team_league_structure()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  joined_count integer;
BEGIN
  IF NEW.template_type = 'team_league' THEN
    NEW.entry_fee := 30;

    IF NEW.max_teams IS NULL OR NEW.max_teams < 4 OR NEW.max_teams > 8 THEN
      RAISE EXCEPTION 'Team League must support between 4 and 8 teams';
    END IF;

    NEW.winning_points := 3;
    NEW.draw_points := 1;
    NEW.loss_points := 0;
    NEW.is_back_and_forth := false;
    NEW.number_of_groups := 1;
    NEW.is_two_legs := false;
    NEW.grand_prize := 0;
    NEW.prize_pool := 0;

    IF TG_OP = 'UPDATE' THEN
      SELECT COALESCE(array_length(OLD.joined_teams, 1), 0)
      INTO joined_count;

      IF joined_count > 0 THEN
        IF NEW.entry_fee IS DISTINCT FROM OLD.entry_fee
           OR NEW.max_teams IS DISTINCT FROM OLD.max_teams
           OR NEW.winning_points IS DISTINCT FROM OLD.winning_points
           OR NEW.draw_points IS DISTINCT FROM OLD.draw_points
           OR NEW.loss_points IS DISTINCT FROM OLD.loss_points
           OR NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth
           OR NEW.number_of_groups IS DISTINCT FROM OLD.number_of_groups
           OR NEW.is_two_legs IS DISTINCT FROM OLD.is_two_legs
           OR NEW.grand_prize IS DISTINCT FROM OLD.grand_prize
           OR NEW.prize_pool IS DISTINCT FROM OLD.prize_pool THEN
          RAISE EXCEPTION 'هيكل دوري VSP ثابت بعد انضمام أول فريق';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
