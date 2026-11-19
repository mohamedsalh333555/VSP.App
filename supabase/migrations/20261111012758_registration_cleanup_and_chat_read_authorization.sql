-- Phase 8 SEC-01/02/04/07; Phase 9 account and conversation consistency.
-- Keep the existing permanent deletion implementation and its financial guards.
CREATE OR REPLACE FUNCTION public.cancel_incomplete_registration_atomic(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_complete boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
  END IF;
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- The lock is held through deletion. A concurrent completion UPDATE waits;
  -- if completion won first, this reads its committed state and refuses deletion.
  SELECT is_registration_complete INTO v_complete
  FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;
  IF v_complete IS DISTINCT FROM false THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_NOT_INCOMPLETE');
  END IF;
  RETURN public.delete_user_permanently(p_user_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_incomplete_registration_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_incomplete_registration_atomic(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(
  p_conversation_id uuid, p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_service boolean := COALESCE(auth.jwt()->>'role', '') = 'service_role';
  v_participants uuid[];
BEGIN
  IF p_conversation_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_ARGUMENT' USING ERRCODE = '22023';
  END IF;
  IF NOT v_service AND (auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = '42501';
  END IF;

  -- Lock first, authorize before touching any messages, and serialize counters.
  SELECT participant_ids INTO v_participants
  FROM public.conversations WHERE id = p_conversation_id FOR UPDATE;
  IF NOT FOUND OR NOT COALESCE(p_user_id = ANY(v_participants), false) THEN
    RAISE EXCEPTION 'CONVERSATION_ACCESS_DENIED' USING ERRCODE = '42501';
  END IF;

  UPDATE public.chat_messages SET is_read = true
  WHERE conversation_id = p_conversation_id
    AND sender_id <> p_user_id AND is_read = false;

  UPDATE public.conversations
  SET unread_counts = jsonb_set(COALESCE(unread_counts, '{}'::jsonb),
                               ARRAY[p_user_id::text], '0'::jsonb, true),
      updated_at = now()
  WHERE id = p_conversation_id;
END;
$$;
REVOKE ALL ON FUNCTION public.mark_chat_messages_as_read(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_chat_messages_as_read(uuid, uuid) TO authenticated, service_role;
