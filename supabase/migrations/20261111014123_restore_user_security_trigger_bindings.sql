-- Restore bindings inspected read-only on production. Bodies remain unchanged.
DO $$
BEGIN
  IF to_regprocedure('public.trg_fn_protect_user_sensitive_fields()') IS NULL
     OR to_regprocedure('public.vsp_guard_sensitive_owner_profile_changes()') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_USER_SECURITY_FUNCTION_MISSING';
  END IF;
END;
$$;
CREATE OR REPLACE TRIGGER trg_protect_users_sensitive_fields
BEFORE UPDATE ON public.users FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_protect_user_sensitive_fields();
CREATE OR REPLACE TRIGGER trg_vsp_guard_sensitive_owner_profile_changes
BEFORE UPDATE ON public.users FOR EACH ROW
EXECUTE FUNCTION public.vsp_guard_sensitive_owner_profile_changes();
