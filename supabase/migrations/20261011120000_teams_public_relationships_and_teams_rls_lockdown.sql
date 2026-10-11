-- Migration: Task 6 Phase B - Lock down raw teams table RLS and add computed relationships to teams_public
-- 1. Computed relationship so PostgREST can embed team_members in teams_public
CREATE OR REPLACE FUNCTION public.team_members(public.teams_public)
RETURNS SETOF public.team_members
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.team_members WHERE team_id = $1.id;
$$;

REVOKE EXECUTE ON FUNCTION public.team_members(public.teams_public) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.team_members(public.teams_public) TO authenticated;

-- 2. Lock down SELECT on raw public.teams table
-- Public access must use public.teams_public view (which excludes captain_phone and active_invite_code).
-- Raw table access is restricted to:
-- - The team captain
-- - Active members of the team
-- - Platform administrators and cofounders
DROP POLICY IF EXISTS "teams_select" ON public.teams;
CREATE POLICY "teams_select" ON public.teams FOR SELECT TO authenticated
USING (
  auth.uid() = captain_id
  OR EXISTS (
    SELECT 1 FROM public.team_members tm
    WHERE tm.team_id = teams.id AND tm.user_id = auth.uid()
  )
  OR is_admin_or_cofounder(auth.uid())
);
