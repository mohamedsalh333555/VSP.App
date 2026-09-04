-- ==============================================================================
-- 🔒 VSP PLATFORM - UNIFIED VERIFICATION SOURCE OF TRUTH
-- Description:
-- 1. Unifies verification strictly into verification_status:
--    'unverified' | 'pending' | 'approved' | 'rejected'
-- 2. Hardens trigger: Prevents setting verification_status = 'approved'
--    if is_registration_complete is false or phone is missing.
-- 3. Automatically synchronizes is_identity_verified with verification_status.
-- ==============================================================================

BEGIN;

-- 1. Update any NULL or legacy verification_status to 'unverified'
UPDATE public.users 
SET verification_status = 'unverified' 
WHERE verification_status IS NULL OR verification_status = '';

-- 2. Set default value for verification_status
ALTER TABLE public.users 
ALTER COLUMN verification_status SET DEFAULT 'unverified';

-- 3. Function to enforce verification consistency
CREATE OR REPLACE FUNCTION public.check_user_verification_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Only allow 'approved' if registration is actually complete
    IF NEW.verification_status = 'approved' AND (NEW.is_registration_complete IS NOT TRUE OR NEW.phone IS NULL OR length(trim(NEW.phone)) < 9) THEN
        RAISE EXCEPTION 'Integrity Error: Cannot approve an owner whose registration is incomplete (missing phone or incomplete profile).';
    END IF;

    -- Synchronize boolean flag automatically from verification_status
    IF NEW.verification_status = 'approved' THEN
        NEW.is_identity_verified := true;
    ELSIF NEW.verification_status IN ('unverified', 'pending', 'rejected') THEN
        NEW.is_identity_verified := false;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_user_verification_integrity ON public.users;
CREATE TRIGGER trg_check_user_verification_integrity
BEFORE INSERT OR UPDATE OF verification_status, is_registration_complete, phone
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.check_user_verification_integrity();

COMMIT;
