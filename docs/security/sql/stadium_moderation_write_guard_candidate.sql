-- REVIEW CANDIDATE — Issue #43. NOT APPLIED TO STAGING OR PRODUCTION.
-- This is an isolated PostgreSQL test candidate, not an approved migration.
-- Preserve admin/co-founder moderation and legitimate owner re-review/soft-delete.
-- Also review grants, update policies and existing functions before rollout.
CREATE OR REPLACE FUNCTION public.guard_stadium_moderation_fields()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $moderation$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF current_setting('request.jwt.claim.role', true) IS DISTINCT FROM 'authenticated' THEN
    RETURN NEW;
  END IF;

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'STADIUM_MODERATION_UNAUTHENTICATED' USING ERRCODE='42501';
  END IF;

  IF COALESCE(public.is_admin_or_cofounder(v_actor), false) THEN
    RETURN NEW;
  END IF;

  IF NEW.owner_id IS DISTINCT FROM v_actor OR
     (TG_OP = 'UPDATE' AND OLD.owner_id IS DISTINCT FROM v_actor) THEN
    RAISE EXCEPTION 'STADIUM_MODERATION_OTHER_OWNER' USING ERRCODE='42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- The live staging default was is_verified=true. A client omitting
    -- is_verified must NOT create an automatically published venue.
    IF COALESCE(NEW.is_verified, true) OR
       COALESCE(NEW.is_blocked, false) OR
       COALESCE(NEW.is_featured, false) OR
       COALESCE(NEW.rating, 0) <> 0 OR
       COALESCE(NEW.reviews_count, 0) <> 0 THEN
      RAISE EXCEPTION 'STADIUM_MODERATION_FIELD_FORBIDDEN'
        USING ERRCODE='42501';
    END IF;
    RETURN NEW;
  END IF;

  -- Owner may voluntarily unpublish an approved venue for review but may
  -- never promote an unapproved venue back to verified; admin remains separate.
  IF (NEW.is_verified IS TRUE AND OLD.is_verified IS DISTINCT FROM true) OR
     NEW.is_blocked IS DISTINCT FROM OLD.is_blocked OR
     NEW.rating IS DISTINCT FROM OLD.rating OR
     NEW.reviews_count IS DISTINCT FROM OLD.reviews_count OR
     NEW.is_featured IS DISTINCT FROM OLD.is_featured OR
     NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    RAISE EXCEPTION 'STADIUM_MODERATION_FIELD_FORBIDDEN'
      USING ERRCODE='42501';
  END IF;

  RETURN NEW;
END;
$moderation$;

REVOKE ALL ON FUNCTION public.guard_stadium_moderation_fields() FROM PUBLIC;

DROP TRIGGER IF EXISTS vsp_guard_stadium_moderation_fields ON public.stadiums;
CREATE TRIGGER vsp_guard_stadium_moderation_fields
BEFORE INSERT OR UPDATE ON public.stadiums
FOR EACH ROW EXECUTE FUNCTION public.guard_stadium_moderation_fields();
