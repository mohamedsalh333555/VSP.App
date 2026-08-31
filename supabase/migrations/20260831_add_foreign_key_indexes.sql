-- Migration: Add missing Foreign Key indexes & drop redundant duplicate indexes
-- Date: 2026-08-31
-- Description: Improves JOIN query performance across championships, matchups, tournaments, and chat.

-- 1. Create missing indexes on foreign keys
CREATE INDEX IF NOT EXISTS idx_championships_owner_id ON public.championships(owner_id);
CREATE INDEX IF NOT EXISTS idx_matchup_results_booking_id ON public.matchup_results(booking_id);
CREATE INDEX IF NOT EXISTS idx_matchup_results_team_a_id ON public.matchup_results(team_a_id);
CREATE INDEX IF NOT EXISTS idx_matchup_results_team_b_id ON public.matchup_results(team_b_id);
CREATE INDEX IF NOT EXISTS idx_player_trophies_user_id ON public.player_trophies(user_id);
CREATE INDEX IF NOT EXISTS idx_tournament_orders_captain_user_id ON public.tournament_orders(captain_user_id);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_next_match_id ON public.tournament_matches(next_match_id);
CREATE INDEX IF NOT EXISTS idx_championship_roster_guests_roster_id ON public.championship_roster_guests(roster_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON public.chat_messages(sender_id);

-- 2. Drop duplicate index on users.phone
DROP INDEX IF EXISTS public.users_phone_unique_idx;
