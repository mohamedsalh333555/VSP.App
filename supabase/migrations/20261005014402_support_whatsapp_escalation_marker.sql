create or replace function public.mark_support_ticket_whatsapp_escalation(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_uid uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
begin
  if v_uid is null or coalesce(auth.role(),'') <> 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_ticket from public.support_tickets where id=p_ticket_id for update;
  if not found or v_ticket.requester_id<>v_uid then raise exception 'TICKET_ACCESS_DENIED'; end if;
  update public.support_tickets
  set source='whatsapp_escalation',
      updated_at=timezone('utc',now())
  where id=p_ticket_id;
  return jsonb_build_object('success',true,'ticket_id',p_ticket_id);
end;
$$;
revoke execute on function public.mark_support_ticket_whatsapp_escalation(uuid) from public;
grant execute on function public.mark_support_ticket_whatsapp_escalation(uuid) to authenticated;
