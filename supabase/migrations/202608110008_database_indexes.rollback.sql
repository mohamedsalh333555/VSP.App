-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110008: DATABASE INDEXES
-- ==============================================================================

DROP INDEX IF EXISTS public.idx_bookings_stadium_start_status;
DROP INDEX IF EXISTS public.idx_bookings_user_status;
DROP INDEX IF EXISTS public.idx_bookings_owner_opdate;
DROP INDEX IF EXISTS public.idx_stadiums_owner_gov;
DROP INDEX IF EXISTS public.idx_teams_captain_gov;
DROP INDEX IF EXISTS public.idx_tournament_matches_status_date;
DROP INDEX IF EXISTS public.idx_chat_messages_booking_created;
