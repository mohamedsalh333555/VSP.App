create or replace function public.create_direct_chat_atomic(
  p_other_user_id uuid,
  p_context_type text,
  p_context_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_booking public.bookings%rowtype;
  v_champ public.championships%rowtype;
  v_existing public.conversations%rowtype;
  v_conv public.conversations%rowtype;
  v_end timestamptz;
  v_type text := lower(trim(coalesce(p_context_type,'')));
begin
  if v_uid is null or coalesce(auth.role(),'') <> 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if p_other_user_id is null or p_other_user_id=v_uid then raise exception 'INVALID_CHAT_PARTICIPANT'; end if;
  if v_type not in ('booking','match','challenge','tournament') or p_context_id is null then raise exception 'INVALID_CHAT_CONTEXT'; end if;
  if are_users_blocked(v_uid,p_other_user_id) then raise exception 'CHAT_BLOCKED'; end if;

  if v_type in ('booking','match','challenge') then
    select * into v_booking from public.bookings where id=p_context_id;
    if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
    if v_type='match' and not (v_booking.booking_type='open_join') then raise exception 'INVALID_MATCH_CONTEXT'; end if;
    if v_type='challenge' and v_booking.booking_type<>'challenge' then raise exception 'INVALID_CHALLENGE_CONTEXT'; end if;

    if not (
      public.vsp_user_is_booking_participant(p_context_id,v_uid)
      and public.vsp_user_is_booking_participant(p_context_id,p_other_user_id)
    ) then raise exception 'CHAT_RELATIONSHIP_REQUIRED'; end if;

    v_end:=v_booking.end_time;

    select * into v_existing
    from public.conversations
    where type='direct'
      and booking_id=p_context_id
      and context_type=v_type
      and context_id=p_context_id
      and cardinality(participant_ids)=2
      and participant_ids @> array[v_uid,p_other_user_id]::uuid[]
    limit 1;
  else
    select * into v_champ from public.championships where id=p_context_id;
    if not found then raise exception 'TOURNAMENT_NOT_FOUND'; end if;
    if not (
      public.vsp_user_is_tournament_participant(p_context_id,v_uid)
      and public.vsp_user_is_tournament_participant(p_context_id,p_other_user_id)
    ) then raise exception 'CHAT_RELATIONSHIP_REQUIRED'; end if;

    v_end:=v_champ.end_date;

    select * into v_existing
    from public.conversations
    where type='direct'
      and booking_id is null
      and context_type='tournament'
      and context_id=p_context_id
      and cardinality(participant_ids)=2
      and participant_ids @> array[v_uid,p_other_user_id]::uuid[]
    limit 1;
  end if;

  if v_existing.id is not null then return to_jsonb(v_existing); end if;

  if v_end is null or v_now > v_end + interval '7 days' then
    raise exception 'CHAT_READ_ONLY';
  end if;

  insert into public.conversations(
    type,booking_id,context_type,context_id,participant_ids,title,unread_counts,created_at,updated_at
  )
  values(
    'direct',
    case when v_type='tournament' then null else p_context_id end,
    v_type,p_context_id,array[v_uid,p_other_user_id]::uuid[],'Direct Chat',
    jsonb_build_object(v_uid::text,0,p_other_user_id::text,0),v_now,v_now
  )
  returning * into v_conv;

  return to_jsonb(v_conv);
end;
$$;

revoke execute on function public.create_direct_chat_atomic(uuid,text,uuid) from public;
grant execute on function public.create_direct_chat_atomic(uuid,text,uuid) to authenticated;
