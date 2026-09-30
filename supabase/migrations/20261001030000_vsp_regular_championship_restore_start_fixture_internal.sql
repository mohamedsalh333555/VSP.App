-- Restore the internal fixture-generation function required by start_championship_atomic.
-- It delegates bracket construction to the canonical generator but preserves the
-- two-step lifecycle by restoring status=open after fixture generation.
CREATE OR REPLACE FUNCTION public.generate_tournament_bracket_fixtures_internal(p_championship_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  v_result := public.generate_tournament_bracket_atomic(p_championship_id);

  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION '%', COALESCE(v_result->>'error', 'تعذر توليد قرعة البطولة');
  END IF;

  -- start_championship_atomic owns the draw-ready transition.
  UPDATE public.championships
  SET status = 'open',
      registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.generate_tournament_bracket_fixtures_internal(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_tournament_bracket_fixtures_internal(uuid) TO postgres, service_role;
