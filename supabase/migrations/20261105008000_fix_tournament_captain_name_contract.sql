-- Align tournament registration snapshots with public.users.name.
-- The affected RPCs still referenced the removed users.full_name column.

DO $migration$
DECLARE
  v_signature regprocedure;
  v_definition text;
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'public.join_championship_atomic(uuid,uuid,uuid[],text[])'::regprocedure,
    'public.create_tournament_order_atomic(uuid,uuid,uuid[],text[],text)'::regprocedure
  ]
  LOOP
    v_definition := pg_get_functiondef(v_signature);
    v_definition := replace(
      v_definition,
      'SELECT id, full_name, phone INTO v_captain',
      'SELECT id, name, phone INTO v_captain'
    );
    v_definition := replace(v_definition, 'v_captain.full_name', 'v_captain.name');

    IF v_definition LIKE '%v_captain.full_name%'
       OR v_definition LIKE '%SELECT id, full_name, phone INTO v_captain%'
    THEN
      RAISE EXCEPTION 'Unable to align captain name contract for %', v_signature;
    END IF;

    EXECUTE v_definition;
  END LOOP;
END;
$migration$;

