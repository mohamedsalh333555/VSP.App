create schema if not exists private;

create or replace function private.assign_copilot_message_sequence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  next_seq bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended(NEW.conversation_id::text, 0));

  select coalesce(max(message_sequence), 0) + 1
    into next_seq
  from public.copilot_messages
  where conversation_id = NEW.conversation_id;

  NEW.message_sequence := next_seq;
  return NEW;
end;
$$;

drop trigger if exists trg_assign_copilot_message_sequence on public.copilot_messages;

create trigger trg_assign_copilot_message_sequence
before insert on public.copilot_messages
for each row
when (NEW.message_sequence is null or NEW.message_sequence = 0)
execute function private.assign_copilot_message_sequence();

drop function if exists public.assign_copilot_message_sequence();

revoke all on schema private from public;
revoke execute on function private.assign_copilot_message_sequence() from public;
grant usage on schema private to service_role;
grant execute on function private.assign_copilot_message_sequence() to service_role;
