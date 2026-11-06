-- Block legacy RPC paths that could silently enroll a different player.
-- Team invitations are accepted atomically through respond_team_membership_invitation.
-- This migration must run AFTER 20261106170000_team_membership_invitations.sql.

CREATE OR REPLACE FUNCTION public.add_team_member_atomic(
  p_team_id uuid, p_user_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;
  -- Legacy captain-driven additions are no longer allowed. Captain must send
  -- an invitation; only the recipient can accept membership via the new RPC.
  RETURN jsonb_build_object(
    'success', false,
    'error', 'TEAM_INVITATION_REQUIRED',
    'message', 'Send an invitation and wait for the player to accept.'
  );
END;
$$;
REVOKE ALL ON FUNCTION public.add_team_member_atomic(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_team_member_atomic(uuid, uuid) TO authenticated;

-- Guard create_team_atomic without replacing its established validation logic.
-- The current implementation adds all p_member_uids directly, so enforce a
-- captain-only input before that function can execute.
CREATE OR REPLACE FUNCTION public.create_team_with_consent(
  p_data jsonb,
  p_member_uids uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;
  IF cardinality(p_member_uids) <> 1 OR p_member_uids[1] IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'TEAM_INVITATION_REQUIRED',
      'message', 'Create a team with its captain, then invite other players.'
    );
  END IF;
  RETURN public.create_team_atomic(p_data, p_member_uids);
END;
$$;
REVOKE ALL ON FUNCTION public.create_team_with_consent(jsonb, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_team_with_consent(jsonb, uuid[]) TO authenticated;

-- IMPORTANT: The old create_team_atomic RPC remains callable by clients until
-- it is replaced or its EXECUTE grant is revoked. Revoke client access now;
-- the consent wrapper above is SECURITY DEFINER and can still call it.
REVOKE ALL ON FUNCTION public.create_team_atomic(jsonb, uuid[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_team_atomic(jsonb, uuid[]) TO service_role;
