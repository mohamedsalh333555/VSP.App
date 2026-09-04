-- ==============================================================================
-- VSP PLATFORM - ABORT INCOMPLETE REGISTRATION
-- Description: Safe RPC to delete an incomplete user account (is_registration_complete=false)
--              from both public.users and auth.users.
-- Date: 2026-09-04
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.abort_registration()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid         UUID := auth.uid();
  v_is_complete BOOLEAN;
BEGIN
  -- 1. Must be authenticated
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- 2. Read the registration flag atomically
  SELECT is_registration_complete
    INTO v_is_complete
    FROM public.users
   WHERE id = v_uid;

  -- 3. If no public.users row found (edge case), still clean up auth
  IF NOT FOUND THEN
    DELETE FROM auth.users WHERE id = v_uid;
    RETURN jsonb_build_object('success', true, 'message', 'Auth record cleaned up (no public.users row found)');
  END IF;

  -- 4. Refuse to delete a COMPLETED account via this endpoint
  IF v_is_complete = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot abort a completed registration');
  END IF;

  -- 5. Delete public.users row first
  DELETE FROM public.users WHERE id = v_uid;

  -- 6. Delete from auth.users (fully removes the Supabase Auth account)
  DELETE FROM auth.users WHERE id = v_uid;

  RETURN jsonb_build_object('success', true, 'message', 'Incomplete registration aborted and account deleted');

EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'abort_registration error for uid=%: %', v_uid, SQLERRM;
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Only authenticated users can call this (enforced inside via auth.uid())
GRANT EXECUTE ON FUNCTION public.abort_registration() TO authenticated;

COMMIT;
