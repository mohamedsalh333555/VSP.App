-- Migration: 202609050003_phase3_add_missing_foreign_key_indexes.sql
-- Description: Add missing indexes on foreign key columns identified in the Performance Advisor audit.

CREATE INDEX IF NOT EXISTS idx_tournament_orders_team_id 
    ON public.tournament_orders(team_id);

CREATE INDEX IF NOT EXISTS idx_banners_created_by 
    ON public.banners(created_by);

CREATE INDEX IF NOT EXISTS idx_bookings_result_submitted_by_team_id 
    ON public.bookings(result_submitted_by_team_id);

CREATE INDEX IF NOT EXISTS idx_booking_players_user_id 
    ON public.booking_players(user_id);

CREATE INDEX IF NOT EXISTS idx_championships_champion_team_id 
    ON public.championships(champion_team_id);

CREATE INDEX IF NOT EXISTS idx_championship_roster_players_player_id 
    ON public.championship_roster_players(player_id);

CREATE INDEX IF NOT EXISTS idx_player_trophies_championship_id 
    ON public.player_trophies(championship_id);

CREATE INDEX IF NOT EXISTS idx_matchup_teams_team_id 
    ON public.matchup_teams(team_id);

CREATE INDEX IF NOT EXISTS idx_matchup_teams_added_by_user_id 
    ON public.matchup_teams(added_by_user_id);

CREATE INDEX IF NOT EXISTS idx_matchup_results_recorded_by 
    ON public.matchup_results(recorded_by);

CREATE INDEX IF NOT EXISTS idx_team_head_to_head_team_b_id 
    ON public.team_head_to_head(team_b_id);

CREATE INDEX IF NOT EXISTS idx_championships_champion_user_id 
    ON public.championships(champion_user_id);
