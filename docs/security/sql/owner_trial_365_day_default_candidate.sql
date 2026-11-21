-- CANDIDATE ONLY — Issue #42. NOT applied to staging or production.
-- A new owner should not silently receive a 365-day Pro entitlement.
-- The deliberate seven-day Pro trial remains activated by start_owner_trial()
-- after a user action, with ledger and identity checks.
-- Existing owner trial_ends_at data is preserved; grandfathering needs review.
--
-- Guard against unexpected default drift instead of overwriting a later
-- legitimate policy. Idempotent if the column already has no default.
DO $guard$
DECLARE
  v_default text;
BEGIN
  SELECT pg_get_expr(d.adbin, d.adrelid)
    INTO v_default
  FROM pg_attribute a
  LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE a.attrelid = 'public.users'::regclass
    AND a.attname = 'trial_ends_at';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OWNER_TRIAL_COLUMN_MISSING';
  END IF;
  IF v_default IS NULL THEN
    RETURN;
  END IF;
  IF v_default <> '(timezone(''utc''::text, now()) + ''365 days''::interval)' THEN
    RAISE EXCEPTION 'OWNER_TRIAL_DEFAULT_SOURCE_DRIFT: %', v_default;
  END IF;

  ALTER TABLE public.users ALTER COLUMN trial_ends_at DROP DEFAULT;
END;
$guard$;
