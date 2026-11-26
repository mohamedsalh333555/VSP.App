-- =============================================================
-- VSP Phase 2D: Retire Private Team League (دوري الفرق الخاص)
-- Keeps existing schema/refund safety intact while blocking new
-- client creation, join, payment prep, and match writes.
-- Migration: 20261126070000_sunset_team_league.sql
-- =============================================================
BEGIN;

DO $$
DECLARE
  fn_sig text;
BEGIN
  FOR fn_sig IN
    SELECT oid::regprocedure::text
    FROM pg_proc
    WHERE pronamespace = 'public'::regnamespace
      AND proname = ANY (ARRAY[
        'create_team_league',
        'join_team_league',
        'prepare_team_league_payment',
        'submit_team_league_match_result',
        'confirm_team_league_match_result',
        'cancel_team_league'
      ])
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn_sig);
  END LOOP;
END $$;

COMMIT;
