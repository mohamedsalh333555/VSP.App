-- VSP Phase 1.1: remove TRUNCATE from public API roles.
-- Reviewed against production grants: anon currently has TRUNCATE on 57 relations;
-- authenticated currently has TRUNCATE on 59 relations.
-- This does not change SELECT/INSERT/UPDATE/DELETE privileges or RLS policies.

REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- Default ACLs currently grant TRUNCATE to both roles for objects created by
-- both postgres and supabase_admin. Revoke the default grants for both creators.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE TRUNCATE ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE TRUNCATE ON TABLES FROM anon, authenticated;

-- Fail the migration if any existing public table/partition still grants TRUNCATE
-- to either API role, whether directly or by role inheritance.
DO $$
DECLARE
  v_remaining integer;
BEGIN
  SELECT count(*)
    INTO v_remaining
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r', 'p')
    AND (
      has_table_privilege('anon', c.oid, 'TRUNCATE')
      OR has_table_privilege('authenticated', c.oid, 'TRUNCATE')
    );

  IF v_remaining > 0 THEN
    RAISE EXCEPTION
      'VSP security hardening failed: % public tables still grant TRUNCATE to anon/authenticated',
      v_remaining;
  END IF;
END;
$$;
