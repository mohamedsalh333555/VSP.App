-- Emergency rollback only; reopens the client-role mutation risk.
-- Never included in the automated forward migration manifest.
DROP TRIGGER IF EXISTS aaa_guard_client_profile_role ON public.users;
DROP FUNCTION IF EXISTS public.guard_client_profile_role_mutations();
