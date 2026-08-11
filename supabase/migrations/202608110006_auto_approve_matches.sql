-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110006: AUTO-APPROVE MATCH RESULTS VIA PG_CRON
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.auto_approve_tournament_matches_24h()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tournament_matches') THEN
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

-- Schedule job to run every hour
SELECT cron.schedule(
  'auto-approve-matches-24h',
  '0 * * * *',
  $$ SELECT public.auto_approve_tournament_matches_24h(); $$
);
