-- create_team_league omitted the required championships.end_date value.
-- Derive it from the existing single-round format and configured interval.

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.create_team_league(text,uuid,text,integer,integer,text,integer)'::regprocedure;
  v_definition text;
BEGIN
  v_definition := pg_get_functiondef(v_signature);
  v_definition := replace(
    v_definition,
    E'    start_date,\n    entry_fee,',
    E'    start_date,\n    end_date,\n    entry_fee,'
  );
  v_definition := replace(
    v_definition,
    E'    now(),\n    v_fee,',
    E'    now(),\n    now() + make_interval(days => (v_max - 1) * v_interval),\n    v_fee,'
  );

  IF v_definition NOT LIKE '%make_interval(days => (v_max - 1) * v_interval)%' THEN
    RAISE EXCEPTION 'Unable to align team league end_date contract';
  END IF;

  EXECUTE v_definition;
END;
$migration$;

