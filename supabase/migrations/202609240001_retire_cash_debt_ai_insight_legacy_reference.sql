-- Retire the remaining legacy cash-debt insight path.
-- Cash settlement is owner-settled: 0% VSP commission, 0 EGP Paymob fee, no debt blocking.
-- The legacy users debt columns remain only for compatibility; this removes business consumption from owner AI insights.
DO $$
DECLARE v_sql text; a int; b int; c int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_sql
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_owner_ai_operational_insights' LIMIT 1;

  a := strpos(v_sql, '    SELECT coalesce(accumulated_cash_debt, 0),');
  IF a > 0 THEN
    b := strpos(substr(v_sql, a), 'WHERE id = p_owner_id;') + a - 1;
    c := b + length('WHERE id = p_owner_id;') - 1;
    v_sql := substr(v_sql,1,a-1)
      || '    SELECT 0, 0, false INTO v_debt, v_debt_limit, v_is_debt_blocked;'
      || substr(v_sql,c+1);
  END IF;

  a := strpos(v_sql, '    IF v_debt_limit > 0 AND v_debt >= (v_debt_limit * 0.8) THEN');
  IF a > 0 THEN
    b := strpos(substr(v_sql,a), '    END IF;') + a - 1;
    c := b + length('    END IF;') - 1;
    v_sql := substr(v_sql,1,a-1) || substr(v_sql,c+1);
  END IF;

  EXECUTE v_sql;
END $$;
