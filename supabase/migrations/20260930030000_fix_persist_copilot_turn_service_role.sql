-- Migration: Fix persist_copilot_turn to allow service_role execution
-- Root cause: Migration 20260925233454 strictly required auth.uid() = p_user_id,
-- which caused Edge Function invocations (running as service_role with auth.uid() IS NULL)
-- to fail with "Unauthorized", preventing conversation turns from being saved.

CREATE OR REPLACE FUNCTION public.persist_copilot_turn(
  p_conversation_id uuid,
  p_user_id uuid,
  p_user_content text,
  p_assistant_content text,
  p_stadium_results jsonb DEFAULT '[]'::jsonb,
  p_ui_metadata jsonb DEFAULT '{}'::jsonb,
  p_context_snapshot jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
declare
  v_current_snapshot jsonb;
  v_current_version int := 0;
  v_incoming_version int := 0;
  v_last_seq bigint := 0;
  v_final_snapshot jsonb;
begin
  -- 1. Validation: p_user_id and p_conversation_id are required
  if p_conversation_id is null or p_user_id is null then
    raise exception 'conversation_id and user_id are required';
  end if;

  -- 2. Authorization: Allow service_role (Edge Function), postgres superuser, OR authenticated user matching p_user_id
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role')
     and (auth.uid() is null or p_user_id is distinct from auth.uid()) then
    raise exception 'Unauthorized';
  end if;

  -- 3. Verify conversation exists and belongs to the specified user
  select context_snapshot into v_current_snapshot
  from public.copilot_conversations
  where id = p_conversation_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'conversation not found for user';
  end if;

  -- 4. Calculate sequence number
  select coalesce(max(message_sequence), 0) into v_last_seq
  from public.copilot_messages
  where conversation_id = p_conversation_id;

  -- 5. Insert user message
  insert into public.copilot_messages(
    conversation_id, user_id, role, content, stadium_results, ui_metadata, message_sequence
  ) values (
    p_conversation_id, p_user_id, 'user', p_user_content, '[]'::jsonb,
    jsonb_build_object('task_state', coalesce(p_ui_metadata->'task_state', '{}'::jsonb)),
    v_last_seq + 1
  );

  -- 6. Insert assistant message
  insert into public.copilot_messages(
    conversation_id, user_id, role, content, stadium_results, ui_metadata, message_sequence
  ) values (
    p_conversation_id, p_user_id, 'assistant', p_assistant_content,
    coalesce(p_stadium_results, '[]'::jsonb),
    coalesce(p_ui_metadata, '{}'::jsonb),
    v_last_seq + 2
  );

  -- 7. Snapshot version conflict resolution
  if v_current_snapshot is not null and v_current_snapshot ? 'conversation_state' then
    v_current_version := coalesce((v_current_snapshot->'conversation_state'->>'version')::int, 0);
  end if;

  if p_context_snapshot is not null and p_context_snapshot ? 'conversation_state' then
    v_incoming_version := coalesce((p_context_snapshot->'conversation_state'->>'version')::int, 0);
  end if;

  if v_current_version > v_incoming_version then
    v_final_snapshot := v_current_snapshot;
  else
    v_final_snapshot := coalesce(p_context_snapshot, '{}'::jsonb);
  end if;

  -- 8. Update conversation snapshot and mark initialized
  update public.copilot_conversations
  set updated_at = now(),
      context_snapshot = v_final_snapshot,
      is_initialized = true
  where id = p_conversation_id and user_id = p_user_id;

  return true;
end;
$$;

GRANT EXECUTE ON FUNCTION public.persist_copilot_turn(uuid, uuid, text, text, jsonb, jsonb, jsonb) TO authenticated, service_role;
