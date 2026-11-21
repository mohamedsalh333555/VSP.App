-- RESULT-06: time alone must never certify a team challenge result.
-- Keep both signatures for existing workers; do not change tournament rules,
-- booking settlement, attendance, payments or fair-play scores.
CREATE OR REPLACE FUNCTION public.auto_approve_challenge_matches_24h()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $function$
BEGIN
  RETURN jsonb_build_object(
    'success', true,
    'resolved_matches_count', 0,
    'disabled', true,
    'reason', 'CAPTAIN_AGREEMENT_REQUIRED'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.auto_reconcile_single_entry_results()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $function$
BEGIN
  RETURN;
END;
$function$;

REVOKE ALL ON FUNCTION public.auto_approve_challenge_matches_24h() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.auto_reconcile_single_entry_results() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_approve_challenge_matches_24h() TO service_role;
GRANT EXECUTE ON FUNCTION public.auto_reconcile_single_entry_results() TO service_role;

-- Unschedule only dedicated calls, irrespective of job name. Mixed commands
-- and tournament/financial maintenance jobs remain untouched; the harmless
-- compatibility functions also protect calls from external schedulers.
DO $block$
DECLARE v_job record;
BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    FOR v_job IN
      SELECT jobid FROM cron.job
      WHERE command ~* '^\s*select\s+(public\.)?(auto_approve_challenge_matches_24h|auto_reconcile_single_entry_results)\s*\(\s*\)\s*;?\s*$'
    LOOP
      PERFORM cron.unschedule(v_job.jobid);
    END LOOP;
  END IF;
END;
$block$;
