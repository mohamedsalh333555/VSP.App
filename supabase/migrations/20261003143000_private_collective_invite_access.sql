-- Private collective-match invitation read surface.
-- Public feed remains private-match blind; this RPC is reachable only by authenticated
-- users who already possess the invitation link/code.
create or replace function public.get_private_match_invite_details(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  select *
    into v_booking
  from public.bookings
  where id = p_booking_id
    and booking_type = 'open_join'
    and is_private is true
  limit 1;

  if not found then
    raise exception 'PRIVATE_MATCH_INVITE_NOT_FOUND';
  end if;

  if v_booking.status in ('cancelled', 'expired') then
    raise exception 'PRIVATE_MATCH_INVITE_NOT_AVAILABLE';
  end if;

  return jsonb_build_object(
    'id', v_booking.id,
    'stadium_id', v_booking.stadium_id,
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'operational_date', v_booking.operational_date,
    'booking_type', v_booking.booking_type,
    'player_team_id', v_booking.player_team_id,
    'player_team_name', v_booking.player_team_name,
    'player_team_logo_url', v_booking.player_team_logo_url,
    'host_name', v_booking.host_name,
    'host_avatar_url', v_booking.host_avatar_url,
    'is_private', v_booking.is_private,
    'rent_ball', v_booking.rent_ball,
    'total_price', v_booking.total_price,
    'currency', v_booking.currency,
    'payment_method', v_booking.payment_method,
    'status', v_booking.status,
    'match_result_status', v_booking.match_result_status,
    'home_score', v_booking.home_score,
    'away_score', v_booking.away_score,
    'final_outcome', v_booking.final_outcome,
    'current_players', coalesce(v_booking.current_players, 0),
    'players_per_team', 5,
    'total_field_capacity', coalesce(v_booking.total_field_capacity, v_booking.max_players, 10),
    'created_by_user_id', v_booking.created_by_user_id,
    'owner_id', v_booking.owner_id,
    'created_at', v_booking.created_at,
    'updated_at', v_booking.updated_at,
    'joined_user_ids', coalesce(v_booking.joined_user_ids, array[]::uuid[])
  );
end;
$$;

revoke all on function public.get_private_match_invite_details(uuid) from public, anon;
grant execute on function public.get_private_match_invite_details(uuid) to authenticated;
