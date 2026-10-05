alter publication supabase_realtime add table public.support_tickets, public.support_ticket_messages;

drop policy if exists conversations_update_participant on public.conversations;

drop policy if exists support_tickets_user_insert on public.support_tickets;
drop policy if exists support_ticket_messages_user_insert on public.support_ticket_messages;
drop policy if exists support_ticket_messages_staff_insert on public.support_ticket_messages;
drop policy if exists reports_insert_auth on public.reports;

create policy support_ticket_messages_staff_insert on public.support_ticket_messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.support_tickets t
    join public.users u on u.id=auth.uid()
    where t.id=support_ticket_messages.ticket_id
      and u.role in ('admin','super_admin','cofounder','co_founder')
      and coalesce(u.is_blocked,false)=false
  )
);
