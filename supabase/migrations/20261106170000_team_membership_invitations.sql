-- Opt-in team membership invitations. Not applied to production by this commit.
CREATE TABLE IF NOT EXISTS public.team_membership_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  invited_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES public.users(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE UNIQUE INDEX IF NOT EXISTS team_membership_one_pending_invite
  ON public.team_membership_invitations(team_id, invited_user_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS team_membership_invite_recipient_idx
  ON public.team_membership_invitations(invited_user_id, status, created_at DESC);

ALTER TABLE public.team_membership_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.team_membership_invitations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.team_membership_invitations TO authenticated;

DROP POLICY IF EXISTS team_membership_invites_read ON public.team_membership_invitations;
CREATE POLICY team_membership_invites_read
  ON public.team_membership_invitations FOR SELECT TO authenticated
  USING (
    invited_user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.teams t
      WHERE t.id = team_id AND t.captain_id = (SELECT auth.uid())
    )
  );

CREATE OR REPLACE FUNCTION public.invite_team_member(p_team_id uuid, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_captain uuid;
  v_governorate text;
  v_user_governorate text;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;
  SELECT captain_id, governorate INTO v_captain, v_governorate
  FROM public.teams WHERE id = p_team_id FOR UPDATE;
  IF NOT FOUND OR v_captain IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the captain can invite players');
  END IF;
  IF p_user_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Captain is already a member');
  END IF;
  SELECT governorate INTO v_user_governorate
  FROM public.users WHERE id = p_user_id;
  IF NOT FOUND OR nullif(btrim(v_user_governorate), '') IS NULL
    OR lower(btrim(v_user_governorate)) IS DISTINCT FROM lower(btrim(v_governorate)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_GOVERNORATE_MISMATCH');
  END IF;
  IF EXISTS (SELECT 1 FROM public.team_members WHERE team_id = p_team_id AND user_id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already a member');
  END IF;
  -- Expired pending invites must not block a new invitation.
  UPDATE public.team_membership_invitations
  SET status = 'cancelled', responded_at = now()
  WHERE team_id = p_team_id AND invited_user_id = p_user_id
    AND status = 'pending' AND expires_at <= now();
  INSERT INTO public.team_membership_invitations(team_id, invited_user_id, invited_by)
  VALUES (p_team_id, p_user_id, auth.uid())
  ON CONFLICT (team_id, invited_user_id) WHERE status = 'pending'
  DO UPDATE SET expires_at = EXCLUDED.expires_at
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'invitation_id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_team_membership_invitation(
  p_invitation_id uuid, p_accept boolean
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_invite public.team_membership_invitations%ROWTYPE;
  v_captain uuid;
  v_team_governorate text;
  v_user_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;
  -- Serialize membership updates against other operations on the team.
  SELECT team_id INTO v_invite.team_id
  FROM public.team_membership_invitations WHERE id = p_invitation_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invitation not found');
  END IF;
  SELECT captain_id, governorate INTO v_captain, v_team_governorate
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
    SELECT governorate INTO v_user_governorate FROM public.users WHERE id = auth.uid();
    IF nullif(btrim(v_user_governorate), '') IS NULL
      OR lower(btrim(v_user_governorate)) IS DISTINCT FROM lower(btrim(v_team_governorate)) THEN
      RETURN jsonb_build_object('success', false, 'error', 'TEAM_GOVERNORATE_MISMATCH');
    END IF;
    IF (SELECT count(*) FROM public.team_members WHERE team_id = v_invite.team_id) >= 12 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Team is full');
    END IF;
    IF (SELECT count(*) FROM public.team_members WHERE user_id = auth.uid()) >= 3 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Player reached maximum teams');
    END IF;
    INSERT INTO public.team_members(team_id, user_id)
    VALUES (v_invite.team_id, auth.uid())
    ON CONFLICT (team_id, user_id) DO NOTHING;
  END IF;
  UPDATE public.team_membership_invitations
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END,
      responded_at = now()
  WHERE id = p_invitation_id;
  RETURN jsonb_build_object('success', true, 'accepted', p_accept, 'team_id', v_invite.team_id);
END;
$$;

REVOKE ALL ON FUNCTION public.invite_team_member(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_team_membership_invitation(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.invite_team_member(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_team_membership_invitation(uuid, boolean) TO authenticated;
