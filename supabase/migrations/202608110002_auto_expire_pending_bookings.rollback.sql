-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110002: AUTO-EXPIRE PENDING BOOKINGS
-- ==============================================================================

SELECT cron.unschedule('expire-pending-bookings-90s');

DROP FUNCTION IF EXISTS public.auto_expire_pending_bookings_90s();
