-- Team discovery is intentionally available to every authenticated player.
-- Enforce that through RLS on the base table and make the directory view honor it.
-- Sensitive invite/contact fields remain unavailable to non-privileged clients.

DROP POLICY IF EXISTS teams_public_directory_select ON public.teams;
CREATE POLICY teams_public_directory_select
ON public.teams
FOR SELECT
TO authenticated
USING (true);

REVOKE SELECT (captain_phone, active_invite_code, invite_code_expires_at)
ON public.teams FROM authenticated;

ALTER VIEW public.teams_public SET (security_invoker = true);

-- The computed PostgREST relationship can now use caller privileges too.
CREATE OR REPLACE FUNCTION public.team_members(public.teams_public)
RETURNS SETOF public.team_members
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT tm.*
  FROM public.team_members AS tm
  WHERE tm.team_id = $1.id;
$$;

REVOKE EXECUTE ON FUNCTION public.team_members(public.teams_public) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.team_members(public.teams_public) TO authenticated;
