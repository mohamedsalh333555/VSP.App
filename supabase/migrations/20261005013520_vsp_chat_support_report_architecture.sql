-- VSP chat/support/report architecture hardening
-- Product rules:
-- * direct chat only through a real booking/match/challenge/tournament relationship
-- * support is Ticket + Messages; legacy support chats are read-only
-- * reports target user/booking/match, with booking/chat context
-- * direct chat remains readable, but writing closes 7 days after relationship end

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS context_type text,
  ADD COLUMN IF NOT EXISTS context_id uuid;

ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS context_type text,
  ADD COLUMN IF NOT EXISTS context_id uuid,
  ADD COLUMN IF NOT EXISTS booking_id uuid,
  ADD COLUMN IF NOT EXISTS conversation_id uuid;

CREATE INDEX IF NOT EXISTS idx_conversations_direct_context
  ON public.conversations(type, context_type, context_id);

CREATE INDEX IF NOT EXISTS idx_conversations_booking
  ON public.conversations(booking_id);

CREATE INDEX IF NOT EXISTS idx_reports_context
  ON public.reports(context_type, context_id, created_at desc);

CREATE INDEX IF NOT EXISTS idx_reports_booking
  ON public.reports(booking_id);

CREATE INDEX IF NOT EXISTS idx_reports_conversation
  ON public.reports(conversation_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='public.reports'::regclass
      AND conname='reports_target_type_check_v2'
  ) THEN
    ALTER TABLE public.reports
      ADD CONSTRAINT reports_target_type_check_v2
      CHECK (target_type IN ('user','booking','match'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject text NOT NULL,
  category text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','waiting_user','resolved','closed')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low','normal','high','urgent')),
  context_type text
    CHECK (context_type IS NULL OR context_type IN ('booking','match','challenge','tournament','report','refund')),
  context_id uuid,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE SET NULL,
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  source text NOT NULL DEFAULT 'in_app'
    CHECK (source IN ('in_app','whatsapp_escalation')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  last_message_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_requester
  ON public.support_tickets(requester_id, updated_at desc);

CREATE INDEX IF NOT EXISTS idx_support_tickets_status
  ON public.support_tickets(status, priority, updated_at desc);

CREATE INDEX IF NOT EXISTS idx_support_tickets_assignee
  ON public.support_tickets(assigned_to, updated_at desc);

CREATE TABLE IF NOT EXISTS public.support_ticket_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL,
  is_internal boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_messages_ticket
  ON public.support_ticket_messages(ticket_id, created_at);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_tickets_user_select ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_staff_select ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_user_insert ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_staff_update ON public.support_tickets;

CREATE POLICY support_tickets_user_select
ON public.support_tickets
FOR SELECT TO authenticated
USING (requester_id = auth.uid());

CREATE POLICY support_tickets_staff_select
ON public.support_tickets
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  )
);

CREATE POLICY support_tickets_user_insert
ON public.support_tickets
FOR INSERT TO authenticated
WITH CHECK (requester_id = auth.uid());

CREATE POLICY support_tickets_staff_update
ON public.support_tickets
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  )
);

DROP POLICY IF EXISTS support_ticket_messages_user_select ON public.support_ticket_messages;
DROP POLICY IF EXISTS support_ticket_messages_staff_select ON public.support_ticket_messages;
DROP POLICY IF EXISTS support_ticket_messages_user_insert ON public.support_ticket_messages;
DROP POLICY IF EXISTS support_ticket_messages_staff_insert ON public.support_ticket_messages;

CREATE POLICY support_ticket_messages_user_select
ON public.support_ticket_messages
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = support_ticket_messages.ticket_id
      AND t.requester_id = auth.uid()
      AND support_ticket_messages.is_internal = false
  )
);

CREATE POLICY support_ticket_messages_staff_select
ON public.support_ticket_messages
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.support_tickets t
    JOIN public.users u ON u.id = auth.uid()
    WHERE t.id = support_ticket_messages.ticket_id
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  )
);

CREATE POLICY support_ticket_messages_user_insert
ON public.support_ticket_messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND is_internal = false
  AND EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = support_ticket_messages.ticket_id
      AND t.requester_id = auth.uid()
      AND t.status IN ('open','in_progress','waiting_user')
  )
);

CREATE POLICY support_ticket_messages_staff_insert
ON public.support_ticket_messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.support_tickets t
    JOIN public.users u ON u.id = auth.uid()
    WHERE t.id = support_ticket_messages.ticket_id
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  )
);

CREATE OR REPLACE FUNCTION public.vsp_is_admin_actor()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  );
$$;

REVOKE EXECUTE ON FUNCTION public.vsp_is_admin_actor() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vsp_is_admin_actor() TO authenticated;

CREATE OR REPLACE FUNCTION public.vsp_user_is_booking_participant(p_booking_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.id = p_booking_id
      AND (
        b.owner_id = p_user_id
        OR b.user_id = p_user_id
        OR b.created_by_user_id = p_user_id
        OR p_user_id = ANY(coalesce(b.joined_user_ids, ARRAY[]::uuid[]))
      )
  );
$$;

REVOKE EXECUTE ON FUNCTION public.vsp_user_is_booking_participant(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vsp_user_is_booking_participant(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.vsp_user_is_tournament_participant(p_championship_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.championships c
    WHERE c.id = p_championship_id
      AND c.owner_id = p_user_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.championship_registrations cr
    JOIN public.teams t ON t.id = cr.team_id
    LEFT JOIN public.team_members tm ON tm.team_id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND cr.registration_status IN ('pending','confirmed')
      AND (
        cr.captain_id = p_user_id
        OR t.captain_id = p_user_id
        OR tm.user_id = p_user_id
      )
  );
$$;

REVOKE EXECUTE ON FUNCTION public.vsp_user_is_tournament_participant(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vsp_user_is_tournament_participant(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.vsp_chat_write_allowed(p_conversation_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_conv record;
  v_end timestamptz;
BEGIN
  SELECT * INTO v_conv
  FROM public.conversations
  WHERE id = p_conversation_id
    AND p_user_id = ANY(participant_ids);

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF coalesce(v_conv.type,'direct') <> 'direct' THEN
    RETURN false;
  END IF;

  IF v_conv.context_type IN ('booking','match','challenge') AND v_conv.booking_id IS NOT NULL THEN
    SELECT end_time INTO v_end FROM public.bookings WHERE id = v_conv.booking_id;
  ELSIF v_conv.context_type = 'tournament' AND v_conv.context_id IS NOT NULL THEN
    SELECT end_date INTO v_end FROM public.championships WHERE id = v_conv.context_id;
  ELSE
    RETURN false;
  END IF;

  RETURN v_end IS NOT NULL
     AND timezone('utc', now()) <= v_end + interval '7 days';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.vsp_chat_write_allowed(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vsp_chat_write_allowed(uuid,uuid) TO authenticated;

-- Block generic client-created conversations. Direct/support creation now goes through secured RPCs.
DROP POLICY IF EXISTS conversations_modify_unified ON public.conversations;
DROP POLICY IF EXISTS conversations_select_unified ON public.conversations;

CREATE POLICY conversations_select_unified
ON public.conversations
FOR SELECT TO authenticated
USING (
  (auth.uid() = ANY(participant_ids))
  OR (
    type = 'support'
    AND public.vsp_is_admin_actor()
  )
  OR (
    auth.uid() = (SELECT b.owner_id FROM public.bookings b WHERE b.id = conversations.booking_id)
  )
);

CREATE POLICY conversations_update_participant
ON public.conversations
FOR UPDATE TO authenticated
USING (auth.uid() = ANY(participant_ids) AND type='direct')
WITH CHECK (
  auth.uid() = ANY(participant_ids)
  AND type='direct'
  AND participant_ids IS NOT DISTINCT FROM (
    SELECT c2.participant_ids FROM public.conversations c2 WHERE c2.id = conversations.id
  )
);

CREATE POLICY conversations_delete_participant
ON public.conversations
FOR DELETE TO authenticated
USING (auth.uid() = ANY(participant_ids));

-- No INSERT policy for authenticated; only SECURITY DEFINER creation RPC may create conversations.

-- Existing chat message inserts must go through the server RPC.
DROP POLICY IF EXISTS chat_messages_insert ON public.chat_messages;

CREATE POLICY chat_messages_insert_service_only
ON public.chat_messages
FOR INSERT TO service_role
WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.create_direct_chat_atomic(
  p_other_user_id uuid,
  p_context_type text,
  p_context_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_booking public.bookings%rowtype;
  v_champ public.championships%rowtype;
  v_existing public.conversations%rowtype;
  v_conv public.conversations%rowtype;
  v_type text := lower(trim(coalesce(p_context_type,'')));
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF p_other_user_id IS NULL OR p_other_user_id = v_uid THEN
    RAISE EXCEPTION 'INVALID_CHAT_PARTICIPANT';
  END IF;
  IF v_type NOT IN ('booking','match','challenge','tournament') OR p_context_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CHAT_CONTEXT';
  END IF;
  IF are_users_blocked(v_uid, p_other_user_id) THEN
    RAISE EXCEPTION 'CHAT_BLOCKED';
  END IF;

  IF v_type IN ('booking','match','challenge') THEN
    SELECT * INTO v_booking FROM public.bookings WHERE id=p_context_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;

    IF v_type='match' AND v_booking.booking_type NOT IN ('open_join','team','personal','matchup') THEN
      RAISE EXCEPTION 'INVALID_MATCH_CONTEXT';
    END IF;
    IF v_type='challenge' AND v_booking.booking_type <> 'challenge' THEN
      RAISE EXCEPTION 'INVALID_CHALLENGE_CONTEXT';
    END IF;

    IF NOT (
      public.vsp_user_is_booking_participant(p_context_id,v_uid)
      AND public.vsp_user_is_booking_participant(p_context_id,p_other_user_id)
    ) THEN
      RAISE EXCEPTION 'CHAT_RELATIONSHIP_REQUIRED';
    END IF;

    SELECT * INTO v_existing
    FROM public.conversations
    WHERE type='direct'
      AND booking_id=p_context_id
      AND context_type=v_type
      AND context_id=p_context_id
      AND cardinality(participant_ids)=2
      AND participant_ids @> ARRAY[v_uid,p_other_user_id]::uuid[]
    LIMIT 1;
  ELSE
    SELECT * INTO v_champ FROM public.championships WHERE id=p_context_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'TOURNAMENT_NOT_FOUND'; END IF;
    IF NOT (
      public.vsp_user_is_tournament_participant(p_context_id,v_uid)
      AND public.vsp_user_is_tournament_participant(p_context_id,p_other_user_id)
    ) THEN
      RAISE EXCEPTION 'CHAT_RELATIONSHIP_REQUIRED';
    END IF;

    SELECT * INTO v_existing
    FROM public.conversations
    WHERE type='direct'
      AND booking_id IS NULL
      AND context_type='tournament'
      AND context_id=p_context_id
      AND cardinality(participant_ids)=2
      AND participant_ids @> ARRAY[v_uid,p_other_user_id]::uuid[]
    LIMIT 1;
  END IF;

  IF v_existing.id IS NOT NULL THEN
    RETURN to_jsonb(v_existing);
  END IF;

  INSERT INTO public.conversations(
    type, booking_id, context_type, context_id, participant_ids,
    title, unread_counts, created_at, updated_at
  )
  VALUES(
    'direct',
    CASE WHEN v_type='tournament' THEN NULL ELSE p_context_id END,
    v_type,
    p_context_id,
    ARRAY[v_uid,p_other_user_id]::uuid[],
    'Direct Chat',
    jsonb_build_object(v_uid::text,0,p_other_user_id::text,0),
    v_now, v_now
  )
  RETURNING * INTO v_conv;

  RETURN to_jsonb(v_conv);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_direct_chat_atomic(uuid,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_direct_chat_atomic(uuid,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.send_chat_message_atomic(
  p_conversation_id uuid,
  p_text text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_text text := trim(coalesce(p_text,''));
  v_conv public.conversations%rowtype;
  v_user public.users%rowtype;
  v_msg public.chat_messages%rowtype;
  v_recipients uuid[] := ARRAY[]::uuid[];
  v_pid uuid;
  v_unread jsonb;
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF v_text='' THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;

  SELECT * INTO v_conv FROM public.conversations WHERE id=p_conversation_id FOR UPDATE;
  IF NOT FOUND OR NOT (v_uid = ANY(v_conv.participant_ids)) THEN
    RAISE EXCEPTION 'CONVERSATION_ACCESS_DENIED';
  END IF;
  IF NOT public.vsp_chat_write_allowed(p_conversation_id,v_uid) THEN
    RAISE EXCEPTION 'CHAT_READ_ONLY';
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id=v_uid;
  INSERT INTO public.chat_messages(
    conversation_id, booking_id, sender_id, sender_name, text, created_at, is_read, is_edited, deleted_for_users
  )
  VALUES(
    v_conv.id,
    v_conv.booking_id,
    v_uid,
    coalesce(v_user.name, 'VSP User'),
    v_text,
    timezone('utc',now()),
    false, false, ARRAY[]::uuid[]
  )
  RETURNING * INTO v_msg;

  v_unread := coalesce(v_conv.unread_counts,'{}'::jsonb);
  FOREACH v_pid IN ARRAY v_conv.participant_ids LOOP
    IF v_pid <> v_uid THEN
      v_unread := jsonb_set(v_unread, ARRAY[v_pid::text], to_jsonb(coalesce((v_unread->>v_pid::text)::int,0)+1), true);
      v_recipients := array_append(v_recipients,v_pid);
    END IF;
  END LOOP;

  UPDATE public.conversations
  SET last_message=v_text,
      last_message_time=timezone('utc',now()),
      unread_counts=v_unread,
      deleted_for_users=ARRAY[]::uuid[],
      updated_at=timezone('utc',now())
  WHERE id=v_conv.id;

  RETURN jsonb_build_object(
    'success',true,
    'message_id',v_msg.id,
    'booking_id',v_conv.booking_id,
    'recipients',to_jsonb(v_recipients),
    'sender_name',coalesce(v_user.name,'VSP User'),
    'message_text',v_text
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_chat_message_atomic(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_chat_message_atomic(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_support_ticket_atomic(
  p_subject text,
  p_category text,
  p_context_type text DEFAULT NULL,
  p_context_id uuid DEFAULT NULL,
  p_booking_id uuid DEFAULT NULL,
  p_priority text DEFAULT 'normal'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_category text := trim(coalesce(p_category,'general'));
  v_subject text := trim(coalesce(p_subject,'VSP Support'));
  v_priority text := lower(trim(coalesce(p_priority,'normal')));
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF length(v_subject)=0 THEN RAISE EXCEPTION 'SUBJECT_REQUIRED'; END IF;
  IF v_priority NOT IN ('low','normal','high','urgent') THEN v_priority := 'normal'; END IF;

  IF p_booking_id IS NOT NULL AND NOT public.vsp_user_is_booking_participant(p_booking_id,v_uid) THEN
    RAISE EXCEPTION 'SUPPORT_CONTEXT_ACCESS_DENIED';
  END IF;

  INSERT INTO public.support_tickets(
    requester_id, subject, category, status, priority,
    context_type, context_id, booking_id, source, created_at, updated_at, last_message_at
  )
  VALUES(
    v_uid, v_subject, v_category, 'open', v_priority,
    p_context_type, p_context_id, p_booking_id, 'in_app',
    timezone('utc',now()), timezone('utc',now()), timezone('utc',now())
  )
  RETURNING * INTO v_ticket;

  RETURN to_jsonb(v_ticket);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_support_ticket_atomic(text,text,text,uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_support_ticket_atomic(text,text,text,uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.send_support_ticket_message_atomic(
  p_ticket_id uuid,
  p_body text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_body text := trim(coalesce(p_body,''));
  v_ticket public.support_tickets%rowtype;
  v_msg public.support_ticket_messages%rowtype;
  v_admin boolean := public.vsp_is_admin_actor();
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF v_body='' THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id=p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;

  IF NOT v_admin AND v_ticket.requester_id <> v_uid THEN
    RAISE EXCEPTION 'TICKET_ACCESS_DENIED';
  END IF;
  IF v_ticket.status IN ('closed','resolved') AND NOT v_admin THEN
    RAISE EXCEPTION 'TICKET_CLOSED';
  END IF;

  INSERT INTO public.support_ticket_messages(ticket_id,sender_id,body,is_internal,created_at)
  VALUES(p_ticket_id,v_uid,v_body,false,timezone('utc',now()))
  RETURNING * INTO v_msg;

  UPDATE public.support_tickets
  SET updated_at=timezone('utc',now()),
      last_message_at=timezone('utc',now()),
      status=CASE
        WHEN v_admin THEN 'waiting_user'
        ELSE 'in_progress'
      END,
      resolved_at=CASE WHEN v_admin THEN NULL ELSE resolved_at END
  WHERE id=p_ticket_id;

  RETURN to_jsonb(v_msg);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_support_ticket_message_atomic(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_support_ticket_message_atomic(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_support_ticket_atomic(
  p_ticket_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_ticket public.support_tickets%rowtype;
  v_status text := lower(trim(coalesce(p_status,'')));
  v_priority text := lower(trim(coalesce(p_priority,'')));
BEGIN
  IF NOT public.vsp_is_admin_actor() THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id=p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;

  IF v_status='' THEN v_status:=v_ticket.status; END IF;
  IF v_priority='' THEN v_priority:=v_ticket.priority; END IF;
  IF v_status NOT IN ('open','in_progress','waiting_user','resolved','closed') THEN RAISE EXCEPTION 'INVALID_TICKET_STATUS'; END IF;
  IF v_priority NOT IN ('low','normal','high','urgent') THEN RAISE EXCEPTION 'INVALID_TICKET_PRIORITY'; END IF;

  UPDATE public.support_tickets
  SET status=v_status,
      priority=v_priority,
      assigned_to=coalesce(p_assigned_to,assigned_to),
      resolved_at=CASE WHEN v_status IN ('resolved','closed') THEN timezone('utc',now()) ELSE NULL END,
      updated_at=timezone('utc',now())
  WHERE id=p_ticket_id
  RETURNING * INTO v_ticket;

  RETURN to_jsonb(v_ticket);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_update_support_ticket_atomic(uuid,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_support_ticket_atomic(uuid,text,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_report_atomic(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_details text DEFAULT NULL,
  p_context_type text DEFAULT NULL,
  p_context_id uuid DEFAULT NULL,
  p_booking_id uuid DEFAULT NULL,
  p_conversation_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_target_type text := lower(trim(coalesce(p_target_type,'')));
  v_context_type text := nullif(lower(trim(coalesce(p_context_type,''))),'');
  v_report public.reports%rowtype;
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF v_target_type NOT IN ('user','booking','match') THEN
    RAISE EXCEPTION 'INVALID_REPORT_TARGET';
  END IF;
  IF p_target_id IS NULL OR nullif(trim(coalesce(p_reason,'')),'') IS NULL THEN
    RAISE EXCEPTION 'INVALID_REPORT';
  END IF;

  IF v_context_type IN ('booking','match','challenge') THEN
    IF p_context_id IS NULL THEN RAISE EXCEPTION 'REPORT_CONTEXT_REQUIRED'; END IF;
    IF NOT public.vsp_user_is_booking_participant(p_context_id,v_uid) THEN
      RAISE EXCEPTION 'REPORT_CONTEXT_ACCESS_DENIED';
    END IF;
    IF v_target_type='user' AND NOT EXISTS (
      SELECT 1 FROM public.users u WHERE u.id=p_target_id
    ) THEN
      RAISE EXCEPTION 'REPORT_TARGET_USER_NOT_FOUND';
    END IF;
  ELSIF v_context_type='tournament' THEN
    IF p_context_id IS NULL OR NOT public.vsp_user_is_tournament_participant(p_context_id,v_uid) THEN
      RAISE EXCEPTION 'REPORT_CONTEXT_ACCESS_DENIED';
    END IF;
  END IF;

  IF v_target_type IN ('booking','match') AND NOT EXISTS (
    SELECT 1 FROM public.bookings b WHERE b.id=p_target_id
  ) THEN
    RAISE EXCEPTION 'REPORT_TARGET_BOOKING_NOT_FOUND';
  END IF;

  INSERT INTO public.reports(
    reporter_id,target_id,target_type,reason,details,status,created_at,
    context_type,context_id,booking_id,conversation_id
  )
  VALUES(
    v_uid,p_target_id::text,v_target_type,trim(p_reason),nullif(trim(p_details),''),
    'pending',timezone('utc',now()),
    v_context_type,p_context_id,p_booking_id,p_conversation_id
  )
  RETURNING * INTO v_report;

  RETURN to_jsonb(v_report);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_report_atomic(text,uuid,text,text,text,uuid,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_report_atomic(text,uuid,text,text,text,uuid,uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_chat_for_user(p_conversation_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
BEGIN
  IF auth.role() <> 'service_role' AND (auth.uid() IS NULL OR auth.uid() <> p_user_id) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF auth.role() <> 'service_role' AND NOT EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id=p_conversation_id AND auth.uid()=ANY(c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'CONVERSATION_ACCESS_DENIED';
  END IF;

  UPDATE public.chat_messages
  SET deleted_for_users = array_append(coalesce(deleted_for_users,ARRAY[]::uuid[]),p_user_id)
  WHERE conversation_id=p_conversation_id
    AND NOT (coalesce(deleted_for_users,ARRAY[]::uuid[]) @> ARRAY[p_user_id]);

  UPDATE public.conversations
  SET deleted_for_users = array_append(coalesce(deleted_for_users,ARRAY[]::uuid[]),p_user_id)
  WHERE id=p_conversation_id
    AND NOT (coalesce(deleted_for_users,ARRAY[]::uuid[]) @> ARRAY[p_user_id]);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_chat_for_user(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_chat_for_user(uuid,uuid) TO authenticated;
