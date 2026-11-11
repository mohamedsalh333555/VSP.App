-- Additive compatibility guard: existing player/owner profile creation remains
-- allowed by existing grants/RLS. Privileged roles and all role changes use
-- authorized SECURITY DEFINER RPCs, not direct client table writes.
CREATE OR REPLACE FUNCTION public.guard_client_profile_role_mutations()
RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  -- SECURITY INVOKER is essential: trusted definer RPCs execute as their owner.
  -- Never use JWT user_metadata or a client-settable system flag for this gate.
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.role IS NULL OR NEW.role NOT IN ('player', 'owner') THEN
      RAISE EXCEPTION 'CLIENT_PROFILE_ROLE_FORBIDDEN' USING ERRCODE='42501';
    END IF;
  ELSIF OLD.role IS DISTINCT FROM NEW.role THEN
    RAISE EXCEPTION 'CLIENT_PROFILE_ROLE_CHANGE_FORBIDDEN' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_client_profile_role_mutations() FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE TRIGGER aaa_guard_client_profile_role
BEFORE INSERT OR UPDATE OF role ON public.users
FOR EACH ROW EXECUTE FUNCTION public.guard_client_profile_role_mutations();
