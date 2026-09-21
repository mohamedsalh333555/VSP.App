create or replace function public.get_owner_copilot_financial_facts(
  p_owner_id uuid,
  p_period_start date,
  p_period_end date,
  p_stadium_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_completed_booking_value numeric := 0;
  v_completed_booking_count integer := 0;
  v_completed_online_gross numeric := 0;
  v_completed_online_gateway_fees numeric := 0;
  v_completed_online_vsp_commission numeric := 0;
  v_completed_cash_collected numeric := 0;
  v_stadium_name text := null;
begin
  if v_caller_id is null and current_user not in ('postgres', 'service_role') then
    return jsonb_build_object(
      'success', false,
      'code', 'AUTH_REQUIRED',
      'message', 'Authentication required'
    );
  end if;

  if p_owner_id is null or p_period_start is null or p_period_end is null or p_period_end < p_period_start then
    return jsonb_build_object(
      'success', false,
      'code', 'INVALID_PERIOD',
      'message', 'Invalid financial period'
    );
  end if;

  if v_caller_id is not null then
    select role into v_caller_role
    from public.users
    where id = v_caller_id;

    if v_caller_id <> p_owner_id
       and coalesce(v_caller_role, '') not in ('admin', 'co_founder')
       and current_user not in ('postgres', 'service_role') then
      return jsonb_build_object(
        'success', false,
        'code', 'UNAUTHORIZED',
        'message', 'Unauthorized access to financial records'
      );
    end if;
  end if;

  if p_stadium_id is not null then
    select name into v_stadium_name
    from public.stadiums
    where id = p_stadium_id
      and owner_id = p_owner_id
      and coalesce(is_deleted_by_owner, false) = false;

    if v_stadium_name is null then
      return jsonb_build_object(
        'success', false,
        'code', 'STADIUM_NOT_FOUND',
        'message', 'The requested stadium does not belong to this owner'
      );
    end if;
  end if;

  select
    coalesce(sum(b.total_price), 0),
    count(*)::integer,
    coalesce(sum(
      case
        when lower(coalesce(b.payment_method, '')) <> 'cash'
        then b.total_price
        else 0
      end
    ), 0),
    coalesce(sum(
      case
        when lower(coalesce(b.payment_method, '')) <> 'cash'
        then coalesce(b.gateway_fee, 0)
        else 0
      end
    ), 0),
    coalesce(sum(
      case
        when lower(coalesce(b.payment_method, '')) <> 'cash'
        then coalesce(b.vsp_commission, round(b.total_price * 0.02, 2))
        else 0
      end
    ), 0),
    coalesce(sum(
      case
        when lower(coalesce(b.payment_method, '')) = 'cash'
        then b.total_price
        else 0
      end
    ), 0)
  into
    v_completed_booking_value,
    v_completed_booking_count,
    v_completed_online_gross,
    v_completed_online_gateway_fees,
    v_completed_online_vsp_commission,
    v_completed_cash_collected
  from public.bookings b
  where b.owner_id = p_owner_id
    and b.status = 'completed'
    and (b.payment_status = 'paid' or b.is_paid = true)
    and b.operational_date >= p_period_start
    and b.operational_date <= p_period_end
    and (p_stadium_id is null or b.stadium_id = p_stadium_id);

  return jsonb_build_object(
    'success', true,
    'owner_id', p_owner_id,
    'stadium_id', p_stadium_id,
    'stadium_name', v_stadium_name,
    'period_start', p_period_start,
    'period_end', p_period_end,
    'completed_booking_value', round(v_completed_booking_value, 2),
    'completed_booking_count', v_completed_booking_count,
    'completed_online_gross', round(v_completed_online_gross, 2),
    'completed_online_gateway_fees', round(v_completed_online_gateway_fees, 2),
    'completed_online_vsp_commission', round(v_completed_online_vsp_commission, 2),
    'completed_online_net', round(v_completed_online_gross - v_completed_online_gateway_fees - v_completed_online_vsp_commission, 2),
    'completed_cash_collected', round(v_completed_cash_collected, 2)
  );
end;
$function$;

revoke all on function public.get_owner_copilot_financial_facts(uuid, date, date, uuid) from public, anon, authenticated;
grant execute on function public.get_owner_copilot_financial_facts(uuid, date, date, uuid) to service_role;