alter table public.copilot_messages
  add column if not exists message_sequence bigint;

with ranked as (
  select id,
         row_number() over (
           partition by conversation_id
           order by created_at asc,
                    case when role = 'user' then 0 else 1 end asc,
                    id asc
         ) as seq
  from public.copilot_messages
)
update public.copilot_messages m
set message_sequence = r.seq
from ranked r
where m.id = r.id
  and m.message_sequence is null;

alter table public.copilot_messages
  alter column message_sequence set default 0;

alter table public.copilot_messages
  alter column message_sequence set not null;

create unique index if not exists copilot_messages_conversation_sequence_uidx
  on public.copilot_messages(conversation_id, message_sequence);

create or replace function public.assign_copilot_message_sequence()
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
execute function public.assign_copilot_message_sequence();

alter table public.copilot_conversations
  add column if not exists is_initialized boolean not null default false;

update public.copilot_conversations c
set is_initialized = true
where exists (
  select 1 from public.copilot_messages m where m.conversation_id = c.id
);

delete from public.copilot_conversations c
where not exists (
  select 1 from public.copilot_messages m where m.conversation_id = c.id
);

revoke execute on function public.assign_copilot_message_sequence() from public;
grant execute on function public.assign_copilot_message_sequence() to service_role;
