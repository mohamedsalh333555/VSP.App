-- Open championships require an explicit registration deadline. Team leagues
-- use their dedicated payment/join lifecycle, so retain the existing immediate
-- start date and use that same boundary for registration_closes_at.

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.create_team_league(text,uuid,text,integer,integer,text,integer)'::regprocedure;
  v_definition text;
BEGIN
  v_definition := pg_get_functiondef(v_signature);
  v_definition := replace(
    v_definition,
    E'    start_date,\n    end_date,\n    entry_fee,',
    E'    start_date,\n    end_date,\n    registration_closes_at,\n    entry_fee,'
  );
  v_definition := replace(
    v_definition,
    E'    now(),\n    now() + make_interval(days => (v_max - 1) * v_interval),\n    v_fee,',
    E'    now(),\n    now() + make_interval(days => (v_max - 1) * v_interval),\n    now(),\n    v_fee,'
  );

  IF v_definition NOT LIKE '%registration_closes_at%' THEN
    RAISE EXCEPTION 'Unable to align team league registration deadline';
  END IF;

  EXECUTE v_definition;
END;
$migration$;

