-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110009: RATE LIMITING
-- ==============================================================================

DROP FUNCTION IF EXISTS public.check_rate_limit(UUID, TEXT, INT, INT);
DROP TABLE IF EXISTS public.rate_limit_logs;
