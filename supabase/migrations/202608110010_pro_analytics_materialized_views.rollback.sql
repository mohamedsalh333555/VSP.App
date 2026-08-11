-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110010: PRO ANALYTICS MATERIALIZED VIEWS
-- ==============================================================================

SELECT cron.unschedule('refresh-pro-analytics-hourly');
DROP FUNCTION IF EXISTS public.refresh_pro_analytics_views();
DROP MATERIALIZED VIEW IF EXISTS public.mv_owner_revenue_by_source;
DROP MATERIALIZED VIEW IF EXISTS public.mv_stadium_peak_hours;
