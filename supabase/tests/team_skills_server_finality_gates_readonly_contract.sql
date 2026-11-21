-- Read-only staging contract; does not mutate competition data.
DO $phase_finality_function_contract$
DECLARE bad integer;
BEGIN
  SELECT count(*) INTO bad
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname IN (
      'team_skills_set_status',
      'team_skills_generate_knockout',
      'team_skills_regenerate_knockout'
    )
    AND (
      NOT p.prosecdef
      OR NOT (COALESCE(p.proconfig,ARRAY[]::text[]) @> ARRAY['search_path=""'])
      OR position('vsp_skills_private.is_admin()' IN p.prosrc)=0
      OR position('all_stages_approved' IN p.prosrc)=0
      OR position('completed_stages<>12' IN p.prosrc)>0
    );
  IF bad>0 THEN
    RAISE EXCEPTION '% Team Skills privileged finality functions failed audit', bad;
  END IF;
  IF (SELECT count(*)
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname IN
      ('team_skills_set_status','team_skills_generate_knockout',
       'team_skills_regenerate_knockout'))<>3 THEN
    RAISE EXCEPTION 'Team Skills server finality function missing';
  END IF;
  RAISE NOTICE 'PASS: 3 admin-only finality gates use published view approval';
END $phase_finality_function_contract$;
