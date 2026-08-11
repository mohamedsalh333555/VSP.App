-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110010: PRO ANALYTICS MATERIALIZED VIEWS
-- ==============================================================================

-- 1. Stadium Peak Hours Materialized View
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_stadium_peak_hours AS
SELECT 
  stadium_id,
  EXTRACT(HOUR FROM (start_time AT TIME ZONE 'Africa/Cairo'))::INT AS slot_hour,
  COUNT(*) AS booking_count,
  SUM(total_price) AS total_revenue
FROM public.bookings
WHERE status IN ('confirmed', 'completed')
GROUP BY stadium_id, slot_hour;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_stadium_peak_hours 
ON public.mv_stadium_peak_hours(stadium_id, slot_hour);

-- 2. Owner Revenue by Source Materialized View (Direct vs Challenge)
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_owner_revenue_by_source AS
SELECT 
  owner_id,
  operational_date,
  booking_type,
  COUNT(*) AS total_bookings,
  SUM(total_price) AS total_revenue,
  SUM(COALESCE(platform_fee, 0)) AS total_platform_fees
FROM public.bookings
WHERE status IN ('confirmed', 'completed')
GROUP BY owner_id, operational_date, booking_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_owner_rev_source 
ON public.mv_owner_revenue_by_source(owner_id, operational_date, booking_type);

-- 3. Refresh function called by pg_cron
CREATE OR REPLACE FUNCTION public.refresh_pro_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_stadium_peak_hours;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_owner_revenue_by_source;
END;
$$;

-- Schedule hourly refresh via pg_cron
SELECT cron.schedule(
  'refresh-pro-analytics-hourly',
  '0 * * * *',
  $$ SELECT public.refresh_pro_analytics_views(); $$
);
