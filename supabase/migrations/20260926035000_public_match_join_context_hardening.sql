create or replace function public.request_join_public_match(p_booking_id text,p_user_id text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_booking record; v_user_conflict int; v_user_blocked boolean; v_capacity int; v_booking_uuid uuid; v_user_uuid uuid; v_now timestamptz:=timezone('utc',now());
begin
 begin v_booking_uuid:=p_booking_id::uuid; v_user_uuid:=p_user_id::uuid;
 exception when others then raise exception 'INVALID_UUID_FORMAT: Invalid booking or user identifier' using errcode='22P02'; end;
 if coalesce(auth.role(),'')<>'service_role' and not(auth.uid() is null and session_user in ('postgres','supabase_admin')) then
   if auth.uid() is null or auth.uid()<>v_user_uuid then raise exception 'PERMISSION_DENIED: You can only join public matches for your own account.' using errcode='42501'; end if;
 end if;
 select * into v_booking from public.bookings where id=v_booking_uuid for update;
 if not found then raise exception 'match_not_found'; end if;
 if v_booking.is_private is true then raise exception 'match_not_public'; end if;
 if v_booking.status='cancelled' then raise exception 'match_cancelled'; end if;
 if v_booking.status='completed' then raise exception 'match_already_completed'; end if;
 select is_blocked into v_user_blocked from public.users where id=v_user_uuid;
 if v_user_blocked is true then raise exception 'user_blocked'; end if;
 v_capacity:=coalesce(v_booking.total_field_capacity,v_booking.max_players,10);
 if coalesce(v_booking.current_players,0)>=v_capacity then raise exception 'match_is_full'; end if;
 if v_user_uuid=any(coalesce(v_booking.joined_user_ids,array[]::uuid[])) or v_booking.created_by_user_id=v_user_uuid then raise exception 'already_joined'; end if;
 select count(*) into v_user_conflict from public.bookings where status<>'cancelled' and id<>v_booking_uuid
   and (created_by_user_id=v_user_uuid or v_user_uuid=any(coalesce(joined_user_ids,array[]::uuid[])))
   and start_time<v_booking.end_time and end_time>v_booking.start_time;
 if v_user_conflict>0 then raise exception 'time_conflict'; end if;
 update public.bookings set joined_user_ids=array_append(coalesce(joined_user_ids,array[]::uuid[]),v_user_uuid),current_players=coalesce(current_players,0)+1,updated_at=v_now where id=v_booking_uuid;
 return jsonb_build_object('success',true,'booking_id',p_booking_id,'current_players',coalesce(v_booking.current_players,0)+1,'host_user_id',v_booking.created_by_user_id);
end; $$;
revoke all on function public.request_join_public_match(text,text) from public,anon;
grant execute on function public.request_join_public_match(text,text) to authenticated;