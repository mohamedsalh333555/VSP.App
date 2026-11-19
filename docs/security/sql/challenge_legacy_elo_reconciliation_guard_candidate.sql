-- Candidate only: DO NOT apply to hosted Supabase automatically.
-- On read-only staging 2026-11-16: this old reconciler uses an incompatible
-- Elo formula; 0 cron jobs call it and 0 confirmed challenges are unprocessed.
-- Keep signature for trusted external callers; do not re-award ranking points.
-- Historical unprocessed rows require an independent, reviewed repair plan.
CREATE OR REPLACE FUNCTION public.reconcile_daily_elo_ratings()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
BEGIN
  RETURN;
END;
$function$;
REVOKE ALL ON FUNCTION public.reconcile_daily_elo_ratings()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_daily_elo_ratings()
  TO service_role;
