-- Preserve authenticated team discovery while making the public data boundary explicit.
-- This view intentionally bypasses teams row-level policies because every signed-in
-- player can discover teams. Its SELECT list is an allowlist and must never include
-- captain_phone, active_invite_code, or invite_code_expires_at.
ALTER VIEW public.teams_public SET (security_barrier = true);

REVOKE ALL ON public.teams_public FROM PUBLIC, anon;
GRANT SELECT ON public.teams_public TO authenticated;

COMMENT ON VIEW public.teams_public IS
'Authenticated team directory. Intentionally exposes only public team profile/statistics columns for team discovery; never add captain_phone, active_invite_code, or invite_code_expires_at. SECURITY DEFINER behavior is intentional because raw teams RLS is member/captain restricted.';
