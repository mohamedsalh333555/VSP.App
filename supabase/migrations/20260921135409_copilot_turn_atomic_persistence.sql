create or replace function public.persist_copilot_turn(
  p_conversation_id uuid,
  p_user_id uuid,
  p_user_content text,
  p_assistant_content text,
  p_stadium_results jsonb,
  p_ui_metadata jsonb,
  p_context_snapshot jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_conversation_id is null or p_user_id is null then
    raise exception 'conversation_id and user_id are required';
  end if;

  perform 1
  from public.copilot_conversations
  where id = p_conversation_id
    and user_id = p_user_id
  for update;

  if not found then
    raise exception 'conversation not found for user';
  end if;

  insert into public.copilot_messages (
    conversation_id, user_id, role, content, stadium_results, ui_metadata
  ) values (
    p_conversation_id, p_user_id, 'user', p_user_content, '[]'::jsonb,
    jsonb_build_object('task_state', coalesce(p_ui_metadata->'task_state', '{}'::jsonb))
  );

  insert into public.copilot_messages (
    conversation_id, user_id, role, content, stadium_results, ui_metadata
  ) values (
    p_conversation_id, p_user_id, 'assistant', p_assistant_content,
    coalesce(p_stadium_results, '[]'::jsonb),
    coalesce(p_ui_metadata, '{}'::jsonb)
  );

  update public.copilot_conversations
  set
    updated_at = now(),
    context_snapshot = coalesce(p_context_snapshot, '{}'::jsonb),
    is_initialized = true
  where id = p_conversation_id
    and user_id = p_user_id;

  return true;
end;
$$;

revoke execute on function public.persist_copilot_turn(uuid, uuid, text, text, jsonb, jsonb, jsonb) from public;
revoke execute on function public.persist_copilot_turn(uuid, uuid, text, text, jsonb, jsonb, jsonb) from anon;
revoke execute on function public.persist_copilot_turn(uuid, uuid, text, text, jsonb, jsonb, jsonb) from authenticated;
grant execute on function public.persist_copilot_turn(uuid, uuid, text, text, jsonb, jsonb, jsonb) to service_role;
