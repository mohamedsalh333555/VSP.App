create or replace function public.create_report_atomic(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_details text default null,
  p_context_type text default null,
  p_context_id uuid default null,
  p_booking_id uuid default null,
  p_conversation_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_uid uuid := auth.uid();
  v_target_type text := lower(trim(coalesce(p_target_type,'')));
  v_context_type text := nullif(lower(trim(coalesce(p_context_type,''))),'');
  v_report public.reports%rowtype;
  v_booking_id uuid;
begin
  if v_uid is null or coalesce(auth.role(),'') <> 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if v_target_type not in ('user','booking','match') then raise exception 'INVALID_REPORT_TARGET'; end if;
  if p_target_id is null or nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'INVALID_REPORT'; end if;
  if p_booking_id is not null then
    v_booking_id := p_booking_id;
  elsif v_context_type in ('booking','match','challenge') then
    v_booking_id := p_context_id;
  end if;

  if v_booking_id is null or not public.vsp_user_is_booking_participant(v_booking_id,v_uid) then
    raise exception 'REPORT_BOOKING_CONTEXT_REQUIRED';
  end if;

  if v_context_type is not null and v_context_type not in ('booking','match','challenge','tournament','refund','report') then
    raise exception 'INVALID_REPORT_CONTEXT';
  end if;

  if v_target_type='user' then
    if not exists(select 1 from public.users u where u.id=p_target_id) then raise exception 'REPORT_TARGET_USER_NOT_FOUND'; end if;
    if p_target_id=v_uid then raise exception 'INVALID_REPORT_TARGET'; end if;
    if not public.vsp_user_is_booking_participant(v_booking_id,p_target_id) then
      raise exception 'REPORT_TARGET_NOT_IN_BOOKING';
    end if;
  elsif v_target_type in ('booking','match') then
    if not exists(select 1 from public.bookings b where b.id=p_target_id) then raise exception 'REPORT_TARGET_BOOKING_NOT_FOUND'; end if;
    if p_target_id<>v_booking_id then raise exception 'REPORT_TARGET_CONTEXT_MISMATCH'; end if;
  end if;

  if p_conversation_id is not null and not exists(
    select 1 from public.conversations c
    where c.id=p_conversation_id and v_uid=any(c.participant_ids)
  ) then raise exception 'REPORT_CONVERSATION_ACCESS_DENIED'; end if;

  insert into public.reports(
    reporter_id,target_id,target_type,reason,details,status,created_at,
    context_type,context_id,booking_id,conversation_id
  )
  values(
    v_uid,p_target_id::text,v_target_type,trim(p_reason),nullif(trim(p_details),''),
    'pending',timezone('utc',now()),v_context_type,coalesce(p_context_id,v_booking_id),v_booking_id,p_conversation_id
  )
  returning * into v_report;

  return to_jsonb(v_report);
end;
$$;

revoke execute on function public.create_report_atomic(text,uuid,text,text,text,uuid,uuid,uuid) from public;
grant execute on function public.create_report_atomic(text,uuid,text,text,text,uuid,uuid,uuid) to authenticated;
