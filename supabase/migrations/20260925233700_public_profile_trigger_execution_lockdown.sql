REVOKE ALL ON FUNCTION public.sync_user_public_profile() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sync_user_public_profile() TO service_role;