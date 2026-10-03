-- Challenge results are never auto-approved after a timeout.
-- Both captains must explicitly submit matching outcomes.
CREATE OR REPLACE FUNCTION public.auto_reconcile_single_entry_results()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
BEGIN
  RETURN;
END;
$function$;