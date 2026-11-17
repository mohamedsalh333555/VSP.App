-- Test the actual migration against disposable PostgreSQL, not hosted.
DO $role$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
END $role$;
CREATE TABLE public.teams(id uuid PRIMARY KEY,captain_id uuid,name text);
CREATE TABLE public.team_members(team_id uuid,user_id uuid,PRIMARY KEY(team_id,user_id));
CREATE TABLE public.team_membership_invitations(
 id uuid PRIMARY KEY,team_id uuid,invited_user_id uuid,invited_by uuid,
 status text,expires_at timestamptz,created_at timestamptz DEFAULT now(),
 responded_at timestamptz);
CREATE TABLE public.notifications(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,title text,body text,
 message text,type text,is_read boolean,created_at timestamptz,metadata jsonb);
-- ACTUAL_TEAM_INVITATION_NOTICE_MIGRATION
INSERT INTO public.teams(id,captain_id,name) VALUES
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000101','النيل'),
 ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000102','أسوان');
INSERT INTO public.team_membership_invitations(
 id,team_id,invited_user_id,invited_by,status,expires_at)
VALUES
 ('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000101',
  'pending',now()+interval '7 days'),
 ('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000102',
  'pending',now()+interval '7 days'),
 ('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000999',
  'pending',now()+interval '7 days'),
 ('00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000101',
  'pending',now()-interval '1 hour');
DO $initial$ BEGIN
 IF (SELECT count(*) FROM public.notifications)<>2
    OR (SELECT count(*) FROM public.notifications WHERE user_id=
     '00000000-0000-0000-0000-000000000201'
       AND metadata->>'event'='invitation_received'
       AND metadata->>'team_id'='00000000-0000-0000-0000-000000000001')<>1
    OR (SELECT count(*) FROM public.notifications WHERE user_id=
     '00000000-0000-0000-0000-000000000202'
       AND metadata->>'invitation_id'='00000000-0000-0000-0000-000000001002')<>1
    OR EXISTS(SELECT 1 FROM public.notifications WHERE user_id IN (
       '00000000-0000-0000-0000-000000000203',
       '00000000-0000-0000-0000-000000000204'))
 THEN RAISE EXCEPTION 'INVITE_WRONG_RECIPIENT_OR_EXPIRED'; END IF;
END $initial$;
-- Reissue of pending request via ON CONFLICT UPDATE does not create a
-- second received-notice, nor does cancellation claim a rejection.
UPDATE public.team_membership_invitations
 SET expires_at=now()+interval '8 days'
 WHERE id='00000000-0000-0000-0000-000000001001';
UPDATE public.team_membership_invitations
 SET status='cancelled',responded_at=now()
 WHERE id IN('00000000-0000-0000-0000-000000001003',
             '00000000-0000-0000-0000-000000001004');
-- Commit of accepted invitation must reflect a real membership.
UPDATE public.team_membership_invitations
 SET status='accepted',responded_at=now()
 WHERE id='00000000-0000-0000-0000-000000001001';
DO $no_fake_accept$ BEGIN
 IF (SELECT count(*) FROM public.notifications)<>2 THEN
 RAISE EXCEPTION 'UNBACKED_ACCEPTANCE_NOTIFICATION'; END IF;
END $no_fake_accept$;
-- Back to pending for the fixture to simulate the actual RPC atomic
-- INSERT team_member BEFORE UPDATE status and ensure a single notice.
UPDATE public.team_membership_invitations
 SET status='pending',responded_at=NULL
 WHERE id='00000000-0000-0000-0000-000000001001';
INSERT INTO public.team_members(team_id,user_id) VALUES
 ('00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000201');
UPDATE public.team_membership_invitations
 SET status='accepted',responded_at=now()
 WHERE id='00000000-0000-0000-0000-000000001001';
UPDATE public.team_membership_invitations
 SET status='accepted',responded_at=now()
 WHERE id='00000000-0000-0000-0000-000000001001';
-- Real decline: no corresponding membership and a not-yet-expired invite.
UPDATE public.team_membership_invitations
 SET status='declined',responded_at=now()
 WHERE id='00000000-0000-0000-0000-000000001002';
UPDATE public.team_membership_invitations
 SET status='declined',responded_at=now()
 WHERE id='00000000-0000-0000-0000-000000001002';
-- New invite whose deadline elapsed before response: no success/decline notice.
INSERT INTO public.team_membership_invitations(
 id,team_id,invited_user_id,invited_by,status,expires_at)
VALUES('00000000-0000-0000-0000-000000001005',
       '00000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000000205',
       '00000000-0000-0000-0000-000000000101',
       'pending',now()+interval '1 hour');
UPDATE public.team_membership_invitations
 SET status='declined',responded_at=now()+interval '2 hours'
 WHERE id='00000000-0000-0000-0000-000000001005';
DO $final$ BEGIN
 IF (SELECT count(*) FROM public.notifications)<>5
    OR (SELECT count(*) FROM public.notifications WHERE user_id=
     '00000000-0000-0000-0000-000000000101'
       AND metadata->>'event'='invitation_accepted'
       AND metadata->>'invitation_id'='00000000-0000-0000-0000-000000001001')<>1
    OR (SELECT count(*) FROM public.notifications WHERE user_id=
     '00000000-0000-0000-0000-000000000102'
       AND metadata->>'event'='invitation_declined'
       AND metadata->>'invitation_id'='00000000-0000-0000-0000-000000001002')<>1
    OR EXISTS(SELECT 1 FROM public.notifications WHERE
      user_id='00000000-0000-0000-0000-000000000999')
 THEN RAISE EXCEPTION 'TEAM_INVITE_RESPONSE_LEAK_OR_DUPLICATE'; END IF;
 IF has_function_privilege('anon',
  'vsp_notifications_private.notify_team_invitation_status()','EXECUTE')
 OR has_function_privilege('authenticated',
  'vsp_notifications_private.notify_team_invitation_status()','EXECUTE')
 THEN RAISE EXCEPTION 'INVITATION_TRIGGER_EXPOSED'; END IF;
 IF (SELECT count(*) FROM pg_trigger WHERE
      tgrelid='public.team_membership_invitations'::regclass
      AND tgenabled='O'
      AND tgname IN('trg_team_invitation_created_notice',
                    'trg_team_invitation_response_notice'))<>2
 THEN RAISE EXCEPTION 'INVITATION_TRIGGER_MISSING'; END IF;
END $final$;
