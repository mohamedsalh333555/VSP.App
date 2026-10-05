create or replace function public.get_player_match_details(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings%rowtype;
  v_stadium public.stadiums%rowtype;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  select * into v_booking from public.bookings where id=p_booking_id limit 1;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;

  if v_booking.booking_type='open_join' and coalesce(v_booking.is_private,false)=false then
    if v_booking.status in ('cancelled','expired') then raise exception 'PUBLIC_MATCH_NOT_AVAILABLE'; end if;
    return jsonb_build_object(
      'id',v_booking.id,'stadium_id',v_booking.stadium_id,'start_time',v_booking.start_time,'end_time',v_booking.end_time,
      'operational_date',v_booking.operational_date,'booking_type',v_booking.booking_type,
      'player_team_id',v_booking.player_team_id,'player_team_name',v_booking.player_team_name,'player_team_logo_url',v_booking.player_team_logo_url,
      'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,'is_private',false,'rent_ball',v_booking.rent_ball,
      'total_price',v_booking.total_price,'currency',v_booking.currency,'status',v_booking.status,
      'match_result_status',v_booking.match_result_status,'home_score',v_booking.home_score,'away_score',v_booking.away_score,
      'final_outcome',v_booking.final_outcome,'current_players',coalesce(v_booking.current_players,0),'players_per_team',5,
      'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
      'created_by_user_id',v_booking.created_by_user_id,'owner_id',v_booking.owner_id,'created_at',v_booking.created_at,
      'updated_at',v_booking.updated_at,'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[])
    );
  end if;

  if v_booking.booking_type='open_join' and coalesce(v_booking.is_private,false)=true then
    if v_uid<>v_booking.created_by_user_id
       and v_uid<>v_booking.owner_id
       and not (v_uid=any(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) then
      raise exception 'COLLECTIVE_MATCH_ACCESS_DENIED';
    end if;
    select * into v_stadium from public.stadiums where id=v_booking.stadium_id;
    return jsonb_build_object(
      'id',v_booking.id,'stadium_id',v_booking.stadium_id,'stadium_name',v_booking.stadium_name,'stadium_image_url',v_booking.stadium_image_url,
      'stadium_location',v_stadium.location,'stadium_city',v_stadium.city,'stadium_governorate',v_stadium.governorate,
      'start_time',v_booking.start_time,'end_time',v_booking.end_time,'operational_date',v_booking.operational_date,
      'booking_type',v_booking.booking_type,'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,'is_private',true,
      'rent_ball',v_booking.rent_ball,'total_price',v_booking.total_price,'currency',v_booking.currency,'payment_method',v_booking.payment_method,
      'payment_status',v_booking.payment_status,'status',v_booking.status,'current_players',coalesce(v_booking.current_players,0),
      'manual_player_count',coalesce(v_booking.manual_player_count,0),'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
      'created_by_user_id',v_booking.created_by_user_id,'owner_id',v_booking.owner_id,'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
      'collective_invite_active',coalesce(v_booking.collective_invite_active,false)
    );
  end if;

  -- Non-open-join booking details are private to actual booking participants.
  if not public.vsp_user_is_booking_participant(p_booking_id,v_uid) then
    raise exception 'BOOKING_ACCESS_DENIED';
  end if;

  select * into v_stadium from public.stadiums where id=v_booking.stadium_id;
  return jsonb_build_object(
    'id',v_booking.id,'stadium_id',v_booking.stadium_id,'stadium_name',v_booking.stadium_name,'stadium_image_url',v_booking.stadium_image_url,
    'stadium_location',v_stadium.location,'stadium_city',v_stadium.city,'stadium_governorate',v_stadium.governorate,
    'start_time',v_booking.start_time,'end_time',v_booking.end_time,'operational_date',v_booking.operational_date,
    'booking_type',v_booking.booking_type,'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,'is_private',coalesce(v_booking.is_private,false),
    'rent_ball',v_booking.rent_ball,'total_price',v_booking.total_price,'currency',v_booking.currency,'payment_method',v_booking.payment_method,
    'payment_status',v_booking.payment_status,'status',v_booking.status,'current_players',coalesce(v_booking.current_players,0),
    'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
    'created_by_user_id',v_booking.created_by_user_id,'owner_id',v_booking.owner_id,'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
    'player_team_id',v_booking.player_team_id,'player_team_name',v_booking.player_team_name,'player_team_logo_url',v_booking.player_team_logo_url,
    'match_result_status',v_booking.match_result_status,'home_score',v_booking.home_score,'away_score',v_booking.away_score,'final_outcome',v_booking.final_outcome,
    'created_at',v_booking.created_at,'updated_at',v_booking.updated_at
  );
end;
$$;

revoke execute on function public.get_player_match_details(uuid) from public;
grant execute on function public.get_player_match_details(uuid) to authenticated;
