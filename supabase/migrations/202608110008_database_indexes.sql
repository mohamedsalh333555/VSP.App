-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110008: HIGH-PERFORMANCE COMPOUND INDEXES
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_bookings_stadium_start_status 
ON public.bookings(stadium_id, start_time, status);

CREATE INDEX IF NOT EXISTS idx_bookings_user_status 
ON public.bookings(user_id, status);

CREATE INDEX IF NOT EXISTS idx_bookings_owner_opdate 
ON public.bookings(owner_id, operational_date);

CREATE INDEX IF NOT EXISTS idx_stadiums_owner_gov 
ON public.stadiums(owner_id, governorate);

CREATE INDEX IF NOT EXISTS idx_teams_captain_gov 
ON public.teams(captain_id, governorate);

CREATE INDEX IF NOT EXISTS idx_tournament_matches_status_date 
ON public.tournament_matches(status, submitted_at);

CREATE INDEX IF NOT EXISTS idx_chat_messages_booking_created 
ON public.chat_messages(booking_id, created_at);
