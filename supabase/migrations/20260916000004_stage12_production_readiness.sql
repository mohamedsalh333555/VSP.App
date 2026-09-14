-- ==============================================================================
-- MIGRATION: 20260916000004_stage12_production_readiness.sql
-- STAGE 12: Production Readiness, Reliability, Background Automation & Index Audit
-- ==============================================================================

-- 1. Fix Tournament Matches Schema & Auto-Approve Cron Reliability
ALTER TABLE IF EXISTS public.tournament_matches
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.auto_approve_tournament_matches_24h()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'tournament_matches' 
      AND column_name = 'submitted_at'
  ) THEN
    UPDATE public.tournament_matches
    SET 
      status = 'approved',
      updated_at = NOW()
    WHERE 
      status = 'pending_confirmation'
      AND submitted_at <= NOW() - INTERVAL '24 hours';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_approve_tournament_matches_24h() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_approve_tournament_matches_24h() TO postgres, service_role;

-- 2. Clean Up Stale Cron Run Details & Register Daily Maintenance Job
CREATE OR REPLACE FUNCTION public.cleanup_stale_cron_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Purge execution logs older than 7 days to prevent unbounded table bloat
  DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '7 days';
END;
$$;

REVOKE ALL ON FUNCTION public.cleanup_stale_cron_logs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_cron_logs() TO postgres, service_role;

-- Schedule daily cron log cleanup at 04:00 UTC if not already scheduled
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'vsp_daily_cron_log_cleanup') THEN
      PERFORM cron.schedule('vsp_daily_cron_log_cleanup', '0 4 * * *', 'SELECT public.cleanup_stale_cron_logs();');
    END IF;
  END IF;
END;
$$;

-- 3. Eliminate Unindexed Foreign Keys & High Volume Query Bottlenecks
-- A. Unindexed Foreign Key on referrals(qualifying_booking_id)
CREATE INDEX IF NOT EXISTS idx_referrals_qualifying_booking 
  ON public.referrals(qualifying_booking_id) 
  WHERE qualifying_booking_id IS NOT NULL;

-- B. GIN Index on bookings(pending_user_ids) for public gathering query optimization
CREATE INDEX IF NOT EXISTS idx_bookings_pending_users_gin 
  ON public.bookings USING gin (pending_user_ids) 
  WHERE pending_user_ids IS NOT NULL;

-- C. Partial Index on users(role, is_debt_blocked) for fast debt gating
CREATE INDEX IF NOT EXISTS idx_users_owner_debt_blocked 
  ON public.users (role, is_debt_blocked) 
  WHERE role = 'owner' AND is_debt_blocked = true;

-- 4. Initial Run of Cron Log Cleanup to Free Table Bloat Immediately
DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '7 days';
