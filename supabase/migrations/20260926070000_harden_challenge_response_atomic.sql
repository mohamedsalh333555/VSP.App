create or replace function public.respond_to_challenge_atomic(p_booking_id uuid, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_caller uuid := auth.uid();
  v_booking record;
  v_team record;
begin
  if v_caller is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;

  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
  if v_booking.booking_type <> 'challenge' then return jsonb_build_object('success',false,'error','NOT_A_CHALLENGE'); end if;
  if v_booking.status <> 'pending' then return jsonb_build_object('success',false,'error','CHALLENGE_NOT_PENDING'); end if;
  if v_booking.opponent_team_id is null then return jsonb_build_object('success',false,'error','OPPONENT_TEAM_MISSING'); end if;

  select id,captain_id into v_team from public.teams where id=v_booking.opponent_team_id;
  if not found or v_team.captain_id is distinct from v_caller then
    return jsonb_build_object('success',false,'error','FORBIDDEN');
  end if;

  perform set_config('vsp.system_override','true',true);

  if p_accept then
    update public.bookings
      set status='confirmed', challenge_status='accepted', updated_at=timezone('utc',now())
      where id=p_booking_id;
    return jsonb_build_object('success',true,'status','confirmed');
  else
    update public.bookings
      set status='cancelled', challenge_status='declined',
          cancelled_at=timezone('utc',now()),
          cancellation_reason='challenge_declined',
          updated_at=timezone('utc',now())
      where id=p_booking_id;
    return jsonb_build_object('success',true,'status','cancelled');
  end if;
end
$function$;

revoke all on function public.respond_to_challenge_atomic(uuid,boolean) from public, anon;
grant execute on function public.respond_to_challenge_atomic(uuid,boolean) to authenticated;
