-- Serialize a player's invitation acceptances across different teams.
-- Locking only a team row is insufficient: two simultaneous acceptances for
-- two different teams can both observe two existing memberships and exceed 3.
CREATE OR REPLACE FUNCTION public.respond_team_membership_invitation(
  p_invitation_id uuid, p_accept boolean
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_invite public.team_membership_invitations%ROWTYPE;
  v_team_governorate text;
  v_user_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  -- The advisory lock is scoped to this transaction and this player.
  -- Acquire it before the team row lock for consistent lock ordering.
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 740125));

  SELECT team_id INTO v_invite.team_id
  FROM public.team_membership_invitations WHERE id = p_invitation_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invitation not found');
  END IF;

  SELECT governorate INTO v_team_governorate
  FROM public.teams WHERE id = v_invite.team_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team not found');
  END IF;

  SELECT * INTO v_invite FROM public.team_membership_invitations
  WHERE id = p_invitation_id FOR UPDATE;
  IF v_invite.invited_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invitation belongs to another player');
  END IF;
  IF v_invite.status <> 'pending' OR v_invite.expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invitation is no longer pending');
  END IF;

  IF p_accept THEN
    SELECT governorate INTO v_user_governorate
    FROM public.users WHERE id = auth.uid();
    IF nullif(btrim(v_user_governorate), '') IS NULL
      OR lower(btrim(v_user_governorate)) IS DISTINCT FROM lower(btrim(v_team_governorate)) THEN
      RETURN jsonb_build_object('success', false, 'error', 'TEAM_GOVERNORATE_MISMATCH');
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_id = v_invite.team_id AND user_id = auth.uid()
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Already a member');
    END IF;
    IF (SELECT count(*) FROM public.team_members WHERE team_id = v_invite.team_id) >= 12 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Team is full');
    END IF;
    IF (SELECT count(*) FROM public.team_members WHERE user_id = auth.uid()) >= 3 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Player reached maximum teams');
    END IF;
    INSERT INTO public.team_members(team_id, user_id)
    VALUES (v_invite.team_id, auth.uid());
  END IF;

  UPDATE public.team_membership_invitations
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END,
      responded_at = now()
  WHERE id = p_invitation_id;
  RETURN jsonb_build_object('success', true, 'accepted', p_accept, 'team_id', v_invite.team_id);
END;
$$;
REVOKE ALL ON FUNCTION public.respond_team_membership_invitation(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_team_membership_invitation(uuid, boolean) TO authenticated;
