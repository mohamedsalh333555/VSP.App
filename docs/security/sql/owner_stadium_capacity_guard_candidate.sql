-- SECURITY CANDIDATE ONLY — NOT APPLIED TO STAGING OR PRODUCTION.
-- Issue #41. Intended for review and a CLI-generated migration *after*
-- isolated contracts, owner-account tests, exact catalog checks and rollback.
--
-- All direct INSERTs and reactivations must obey the effective server plan.
-- Serialize per-owner writes by locking their existing users row, then count.
-- Security-definer body never accepts a client-supplied limit.
CREATE OR REPLACE FUNCTION public.guard_owner_stadium_capacity_write()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $owner_cap$
DECLARE
  v_actor uuid := auth.uid();
  v_allowed boolean;
  v_current integer;
  v_max integer;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- An existing active pitch may still be edited after downgrade; changes
    -- in active count or owner require the full quota evaluation.
    IF NEW.owner_id = OLD.owner_id
       AND COALESCE(OLD.is_deleted_by_owner, false) = false THEN
      RETURN NEW;
    END IF;
    IF NEW.owner_id = OLD.owner_id
       AND COALESCE(NEW.is_deleted_by_owner, false) = true THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Soft-deleted rows can be stored but must be checked on reactivation.
  IF COALESCE(NEW.is_deleted_by_owner, false) = true THEN
    RETURN NEW;
  END IF;

  -- Reject spoofed owner IDs before taking another tenant's row lock.
  IF current_setting('request.jwt.claim.role', true) = 'authenticated' THEN
    IF v_actor IS NULL OR
       (v_actor <> NEW.owner_id AND
        NOT COALESCE(public.is_admin_or_cofounder(v_actor), false)) THEN
      RAISE EXCEPTION 'STADIUM_OWNER_UNAUTHORIZED'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- The lock survives until the transaction finishes. Concurrent INSERTs for
  -- the same owner therefore cannot both observe one remaining stadium slot
  -- under normal READ COMMITTED PostgREST transactions.
  PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'STADIUM_OWNER_NOT_FOUND' USING ERRCODE = '23503';
  END IF;

  SELECT e.allowed, e.current_count, e.max_allowed
    INTO v_allowed, v_current, v_max
  FROM public.evaluate_owner_stadium_capacity(
    NEW.owner_id,
    CASE WHEN TG_OP = 'UPDATE' THEN NEW.id ELSE NULL::uuid END
  ) AS e;

  IF v_allowed IS DISTINCT FROM true
     OR v_current IS NULL
     OR v_max IS NULL
     OR v_current < 0 OR v_max < 1 OR v_current >= v_max THEN
    RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$owner_cap$;

REVOKE ALL ON FUNCTION public.guard_owner_stadium_capacity_write() FROM PUBLIC;

DROP TRIGGER IF EXISTS vsp_guard_owner_stadium_capacity_write
  ON public.stadiums;
CREATE TRIGGER vsp_guard_owner_stadium_capacity_write
BEFORE INSERT OR UPDATE OF owner_id, is_deleted_by_owner
ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.guard_owner_stadium_capacity_write();
