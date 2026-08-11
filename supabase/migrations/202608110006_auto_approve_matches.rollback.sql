-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110006: AUTO-APPROVE MATCH RESULTS
-- ==============================================================================

SELECT cron.unschedule('auto-approve-matches-24h');
DROP FUNCTION IF EXISTS public.auto_approve_tournament_matches_24h();
