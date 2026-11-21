-- Membership changes must be performed through audited SECURITY DEFINER RPCs.
-- SELECT policies are retained so roster displays and membership streams work.
-- Removing table DML grants blocks direct PostgREST INSERT/UPDATE/DELETE even
-- if an earlier RLS policy was overly permissive.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.team_members FROM anon, authenticated;

-- Explicitly remove any earlier client-facing write policies as defense in depth.
-- The permission revocation above is the authoritative gate; existing SELECT
-- policies are intentionally preserved.
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname, cmd
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'team_members'
      AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
  LOOP
    -- ALL policies may also provide SELECT. Preserve them so reads continue
    -- working; table-level DML grants still deny writes.
    IF p.cmd <> 'ALL' THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.team_members', p.policyname);
    END IF;
  END LOOP;
END;
$$;
