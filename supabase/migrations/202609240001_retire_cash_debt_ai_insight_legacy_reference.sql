-- Retire the remaining legacy cash-debt insight path.
-- Cash settlement is owner-settled: 0% VSP commission, 0 EGP Paymob fee, no debt blocking.
-- The legacy users debt columns remain only for compatibility; this removes business consumption from owner AI insights.
DO $$
DECLARE v_sql text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_sql
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_owner_ai_operational_insights' LIMIT 1;

  v_sql := regexp_replace(v_sql, E'    SELECT coalesce\\(accumulated_cash_debt, 0\\),.*?WHERE id = p_owner_id;[[:space:]]*', '', 'n');
  v_sql := regexp_replace(v_sql, E'    IF v_debt_limit > 0 AND v_debt >= \\(v_debt_limit \\* 0\\.8\\) THEN.*?    END IF;[[:space:]]*', '', 'n');
  EXECUTE v_sql;
END $$;
