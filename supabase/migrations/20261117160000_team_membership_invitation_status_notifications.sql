-- In-app invitation lifecycle receipts from the authoritative invitation
-- row. The invitation RPC controls inserts/acceptance; clients have SELECT
-- only and cannot insert or mutate these rows directly.
-- No FCM delivery, team-membership auto-join or financial side effects.
CREATE SCHEMA IF NOT EXISTS vsp_notifications_private;
REVOKE ALL ON SCHEMA vsp_notifications_private FROM PUBLIC, anon, authenticated;

-- Prevent duplicated logical notifications on retry even when an invite
-- is re-read or a pending expires_at is extended.
CREATE UNIQUE INDEX IF NOT EXISTS vsp_team_invite_notice_once_per_event
ON public.notifications (
  user_id,
  (metadata->>'invitation_id'),
  (metadata->>'event')
)
WHERE metadata->>'source'='team_membership'
  AND metadata->>'invitation_id' IS NOT NULL
  AND metadata->>'event' IN (
    'invitation_received','invitation_accepted','invitation_declined'
  );

CREATE OR REPLACE FUNCTION vsp_notifications_private.notify_team_invitation_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_captain uuid;
  v_name text;
  v_target uuid;
  v_event text;
  v_title text;
  v_body text;
BEGIN
  SELECT t.captain_id, t.name INTO v_captain,v_name
  FROM public.teams t WHERE t.id=new.team_id;
  IF v_captain IS NULL
    OR new.invited_user_id IS NULL
    OR new.invited_user_id=v_captain
    OR new.invited_by IS DISTINCT FROM v_captain
  THEN RETURN new; END IF;
  v_name:=coalesce(nullif(btrim(v_name),''),'الفريق');

  IF tg_op='INSERT' THEN
    IF new.status<>'pending' OR new.expires_at<=now() THEN
      RETURN new;
    END IF;
    v_target:=new.invited_user_id;
    v_event:='invitation_received';
    v_title:='دعوة للانضمام إلى فريق';
    v_body:='وصلك طلب دعوة للانضمام إلى فريق '||left(v_name,100)||
      '. راجع دعوات الفرق للقبول أو الرفض.';
  ELSIF tg_op='UPDATE' THEN
    -- Renewing the deadline, failed/expired requests, and repeated response
    -- writes are not real acceptance/decline transitions.
    IF old.status<>'pending'
      OR new.status NOT IN ('accepted','declined')
      OR new.responded_at IS NULL
      OR new.responded_at<new.created_at
      OR new.expires_at<=new.responded_at THEN RETURN new; END IF;
    -- A success notice must not precede the actual membership insert.
    IF new.status='accepted' AND NOT EXISTS(
       SELECT 1 FROM public.team_members m
       WHERE m.team_id=new.team_id AND m.user_id=new.invited_user_id
    ) THEN RETURN new; END IF;
    IF new.status='declined' AND EXISTS(
       SELECT 1 FROM public.team_members m
       WHERE m.team_id=new.team_id AND m.user_id=new.invited_user_id
    ) THEN RETURN new; END IF;
    v_target:=v_captain;
    v_event:=CASE WHEN new.status='accepted'
      THEN 'invitation_accepted' ELSE 'invitation_declined' END;
    v_title:=CASE WHEN new.status='accepted'
      THEN 'تم قبول دعوة الانضمام إلى فريقك'
      ELSE 'تم رفض دعوة الانضمام إلى فريقك' END;
    v_body:=CASE WHEN new.status='accepted'
      THEN 'قبل لاعب دعوتك للانضمام إلى فريق '||left(v_name,100)||'.'
      ELSE 'رفض لاعب دعوتك للانضمام إلى فريق '||left(v_name,100)||'.' END;
  ELSE RETURN new; END IF;

  INSERT INTO public.notifications(
    user_id,title,body,message,type,is_read,created_at,metadata
  ) VALUES (
    v_target,v_title,v_body,v_body,'info',false,now(),
    jsonb_build_object(
      'source','team_membership','event',v_event,
      'invitation_id',new.id,'team_id',new.team_id,
      'invited_user_id',new.invited_user_id
    )
  ) ON CONFLICT DO NOTHING;
  RETURN new;
END;
$$;
REVOKE ALL ON FUNCTION vsp_notifications_private.notify_team_invitation_status()
  FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_team_invitation_created_notice
  ON public.team_membership_invitations;
CREATE TRIGGER trg_team_invitation_created_notice
  AFTER INSERT ON public.team_membership_invitations
  FOR EACH ROW EXECUTE FUNCTION
  vsp_notifications_private.notify_team_invitation_status();
DROP TRIGGER IF EXISTS trg_team_invitation_response_notice
  ON public.team_membership_invitations;
CREATE TRIGGER trg_team_invitation_response_notice
  AFTER UPDATE OF status ON public.team_membership_invitations
  FOR EACH ROW EXECUTE FUNCTION
  vsp_notifications_private.notify_team_invitation_status();
