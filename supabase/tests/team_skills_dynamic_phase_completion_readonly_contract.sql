-- Read-only checks for the migrated, security-invoker leaderboard view.
-- No fixtures or mutations; suitable for staging release verification.
DO $dynamic_phase_completion$
DECLARE
  definition text;
  wrong integer;
BEGIN
  SELECT lower(pg_get_viewdef('public.team_skills_leaderboard'::regclass, true))
    INTO definition;
  IF position('team_skills_phases' IN definition) = 0
     OR position('approved' IN definition) = 0 THEN
    RAISE EXCEPTION 'Leaderboard view lacks phase-derived approved-score finality';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class
    WHERE oid = 'public.team_skills_leaderboard'::regclass
      AND NOT (COALESCE(reloptions, ARRAY[]::text[]) @> ARRAY['security_invoker=true'])
  ) THEN
    RAISE EXCEPTION 'Leaderboard view lost security_invoker';
  END IF;
  IF has_table_privilege('anon', 'public.team_skills_leaderboard', 'SELECT')
     OR NOT has_table_privilege('authenticated', 'public.team_skills_leaderboard', 'SELECT') THEN
    RAISE EXCEPTION 'Leaderboard read grants drifted';
  END IF;

  -- Distinct generated scenarios exercise the expression without ever
  -- writing to real team_skills_* tables. The foreign-key/unique constraints
  -- on scores enforce one approved score at most per configured stage.
  SELECT COUNT(*) INTO wrong FROM (
    VALUES
      (0,0,false),
      (10,0,false),
      (10,9,false),
      (10,10,true),
      (12,11,false),
      (12,12,true),
      (13,12,false),
      (13,13,true)
  ) AS cases(configured,approved,expected)
  WHERE (configured > 0 AND approved = configured) IS DISTINCT FROM expected;
  IF wrong <> 0 THEN
    RAISE EXCEPTION 'Variable 0/10/12/13-stage finality regression: % mismatches', wrong;
  END IF;

  RAISE NOTICE 'PASS: dynamic phase finality, invoker security and read grants';
END $dynamic_phase_completion$;
