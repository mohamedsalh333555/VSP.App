-- Harden owner manual booking updates behind a server-authoritative RPC.
-- The live function was applied during the audit; this migration records the same change.
create or replace function public.owner_update_manual_booking_atomic(
  p_booking_id uuid,
  p_end_time timestamptz,
  p_customer_name text,
  p_customer_phone text default null,
  p_notes text default null,
  p_current_players integer default 1,
  p_collected_amount numeric default 0
) returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_booking record;
  v_stadium record;
  v_role text;
  v_duration numeric;
  v_total numeric;
  v_collected numeric;
  v_now timestamptz := timezone('utc',now());
  v_conflict boolean;
begin
  if auth.uid() is null and auth.role() <> 'service_role' and current_user not in ('postgres','service_role') then
    return jsonb_build_object('success',false,'error','UNAUTHORIZED');
  end if;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'') <> 'service_role'
     and current_user not in ('postgres','service_role')
     and v_booking.owner_id is distinct from auth.uid()
     and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','UNAUTHORIZED');
  end if;
  if v_booking.status='cancelled' then return jsonb_build_object('success',false,'error','BOOKING_CANCELLED'); end if;
  if v_booking.payment_method <> 'cash' or not (
      coalesce(v_booking.payment_transaction_id,'') like 'MANUAL%'
      or v_booking.created_by_user_id = v_booking.owner_id
    ) then
    return jsonb_build_object('success',false,'error','MANUAL_BOOKING_ONLY');
  end if;
  if p_end_time <= v_booking.start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
  if v_now >= v_booking.start_time then return jsonb_build_object('success',false,'error','BOOKING_ALREADY_STARTED'); end if;
  select * into v_stadium from public.stadiums where id=v_booking.stadium_id for update;
  if not found or v_stadium.is_deleted_by_owner is true or coalesce(v_stadium.is_blocked,false) then
    return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE');
  end if;
  v_duration := extract(epoch from (p_end_time-v_booking.start_time))/3600.0;
  if v_duration <= 0 or v_duration > (select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then
    return jsonb_build_object('success',false,'error','INVALID_DURATION');
  end if;
  v_total := round(coalesce(v_stadium.price_per_hour,v_stadium.base_price,0) * v_duration,2);
  if v_total <= 0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
  v_collected := round(coalesce(p_collected_amount,0),2);
  if v_collected < 0 or v_collected > v_total then
    return jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT','expected_total_price',v_total);
  end if;
  select exists(
    select 1 from public.bookings b
    where b.stadium_id=v_booking.stadium_id and b.id<>p_booking_id and b.status<>'cancelled'
      and b.start_time < p_end_time and b.end_time > v_booking.start_time
  ) into v_conflict;
  if v_conflict then return jsonb_build_object('success',false,'error','CONFLICT'); end if;
  update public.bookings
  set end_time=p_end_time,
      player_team_name=coalesce(nullif(trim(p_customer_name),''),player_team_name),
      host_name=coalesce(nullif(trim(p_customer_name),''),host_name),
      player_phone=nullif(trim(p_customer_phone),''),
      notes=p_notes,
      current_players=greatest(0,coalesce(p_current_players,1)),
      total_price=v_total,
      deposit_paid=v_collected,
      is_deposit_paid=(v_collected>0),
      is_paid=(v_collected>=v_total),
      payment_status=case when v_collected>=v_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
      updated_at=v_now
  where id=p_booking_id;
  return jsonb_build_object('success',true,'booking_id',p_booking_id,'total_price',v_total,'collected_amount',v_collected);
exception when others then
  return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end;
$$;
revoke all on function public.owner_update_manual_booking_atomic(uuid,timestamptz,text,text,text,integer,numeric) from public,anon;
grant execute on function public.owner_update_manual_booking_atomic(uuid,timestamptz,text,text,text,integer,numeric) to authenticated,service_role;