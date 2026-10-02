create or replace function public.get_owner_dashboard_analytics(
  p_owner_id uuid,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone,
  p_court_id uuid default null
)
returns json
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_result json;
  v_total_op_hours numeric := 0;
  v_booked_hours numeric := 0;
  v_total_revenue numeric := 0;
  v_cash_revenue numeric := 0;
  v_online_revenue numeric := 0;
  v_realized_revenue numeric := 0;
  v_realized_cash numeric := 0;
  v_realized_online numeric := 0;
  v_cash_collected numeric := 0;
  v_cash_uncollected numeric := 0;
  v_online_collected numeric := 0;
  v_online_unavailable numeric := 0;
  v_upcoming_value numeric := 0;
  v_upcoming_cash numeric := 0;
  v_upcoming_online numeric := 0;
  v_total_bookings integer := 0;
  v_cash_bookings integer := 0;
  v_online_bookings integer := 0;
  v_period_days integer;
  v_avg_hourly_rate numeric := 0;
begin
  if auth.uid() is null and current_user not in ('postgres', 'service_role') then
    raise exception 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للوصول إلى تحليلات لوحة التحكم.'
      using errcode = '42501';
  end if;

  if auth.uid() is not null and auth.uid() <> p_owner_id and current_user not in ('postgres', 'service_role') then
    if not public.is_admin_or_cofounder(auth.uid()) then
      raise exception 'UNAUTHORIZED: غير مصرح بالوصول إلى بيانات هذا المالك.'
        using errcode = '42501';
    end if;
  end if;

  v_period_days := greatest(1, date_part('day', p_end_date - p_start_date)::integer);

  select coalesce(avg(price_per_hour), 0) into v_avg_hourly_rate
  from public.stadiums
  where owner_id = p_owner_id and (p_court_id is null or id = p_court_id) and price_per_hour > 0;

  if v_avg_hourly_rate is null or v_avg_hourly_rate < 0 then v_avg_hourly_rate := 0; end if;

  select coalesce(sum(
    case
      when s.closing_time is not null and s.opening_time is not null then
        (case when s.closing_time > s.opening_time
          then extract(epoch from (s.closing_time - s.opening_time)) / 3600.0
          else extract(epoch from ('24:00:00'::time - s.opening_time + s.closing_time)) / 3600.0
        end)
        - (case
            when s.is_split_shift is true and s.break_start_time is not null and s.break_end_time is not null then
              case when s.break_end_time > s.break_start_time
                then extract(epoch from (s.break_end_time - s.break_start_time)) / 3600.0
                else extract(epoch from ('24:00:00'::time - s.break_start_time + s.break_end_time)) / 3600.0
              end
            else 0.0
          end)
      else 0.0
    end
  ) * v_period_days, 0)
  into v_total_op_hours
  from public.stadiums s
  where s.owner_id = p_owner_id and (p_court_id is null or s.id = p_court_id)
    and coalesce(s.is_deleted_by_owner, false) = false;

  select
    count(b.id),
    count(b.id) filter (where b.payment_source = 'cash' or b.payment_method = 'cash'),
    count(b.id) filter (where b.payment_source <> 'cash' and b.payment_method <> 'cash'),
    coalesce(sum(case when b.total_price > 0 then b.total_price else b.deposit_paid end), 0),
    coalesce(sum(case when (b.payment_source = 'cash' or b.payment_method = 'cash')
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(case when (b.payment_source <> 'cash' and b.payment_method <> 'cash')
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(greatest(0, extract(epoch from (b.end_time - b.start_time)) / 3600.0)), 0)
  into v_total_bookings, v_cash_bookings, v_online_bookings, v_total_revenue,
       v_cash_revenue, v_online_revenue, v_booked_hours
  from public.bookings b
  where b.owner_id = p_owner_id and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date and b.start_time < p_end_date
    and b.status in ('confirmed', 'completed', 'upcoming');

  select
    coalesce(sum(case when (b.payment_source = 'cash' or b.payment_method = 'cash')
      then case when (b.payment_status = 'paid' or b.is_paid = true)
        then b.total_price else greatest(b.deposit_paid, 0) end else 0 end), 0),
    coalesce(sum(case when (b.payment_source <> 'cash' and b.payment_method <> 'cash')
      and (b.payment_status = 'paid' or b.is_paid = true)
      then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
        then b.deposit_paid else b.total_price end else 0 end), 0)
  into v_cash_collected, v_online_collected
  from public.bookings b
  where b.owner_id = p_owner_id and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date and b.start_time < p_end_date
    and b.status <> 'cancelled';

  select
    coalesce(sum(case
      when (b.payment_source = 'cash' or b.payment_method = 'cash')
        then case when (b.payment_status = 'paid' or b.is_paid = true)
          then b.total_price else greatest(b.deposit_paid, 0) end
      else case when (b.payment_status = 'paid' or b.is_paid = true)
        then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
          then b.deposit_paid else b.total_price end else 0 end
    end), 0),
    coalesce(sum(case when (b.payment_source = 'cash' or b.payment_method = 'cash')
      then case when (b.payment_status = 'paid' or b.is_paid = true)
        then b.total_price else greatest(b.deposit_paid, 0) end else 0 end), 0),
    coalesce(sum(case when (b.payment_source <> 'cash' and b.payment_method <> 'cash')
      and (b.payment_status = 'paid' or b.is_paid = true)
      then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
        then b.deposit_paid else b.total_price end else 0 end), 0)
  into v_realized_revenue, v_realized_cash, v_realized_online
  from public.bookings b
  where b.owner_id = p_owner_id and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date and b.start_time < p_end_date
    and b.status in ('completed', 'no_show');

  select coalesce(sum(greatest(b.total_price - greatest(coalesce(b.deposit_paid, 0), 0), 0)), 0)
  into v_cash_uncollected
  from public.bookings b
  where b.owner_id = p_owner_id and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date and b.start_time < p_end_date
    and (b.payment_source = 'cash' or b.payment_method = 'cash')
    and b.status <> 'cancelled'
    and (b.payment_status <> 'paid' and coalesce(b.is_paid, false) = false);

  select coalesce(sum(case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
    then b.deposit_paid else b.total_price end), 0)
  into v_online_unavailable
  from public.bookings b
  where b.owner_id = p_owner_id and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date and b.start_time < p_end_date
    and b.payment_source <> 'cash' and b.payment_method <> 'cash'
    and (b.payment_status = 'paid' or b.is_paid = true)
    and b.status in ('confirmed', 'upcoming') and b.end_time > now();

  select
    coalesce(sum(case when b.total_price > 0 then b.total_price else b.deposit_paid end), 0),
    coalesce(sum(case when (b.payment_source = 'cash' or b.payment_method = 'cash')
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(case when (b.payment_source <> 'cash' and b.payment_method <> 'cash')
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0)
  into v_upcoming_value, v_upcoming_cash, v_upcoming_online
  from public.bookings b
  where b.owner_id = p_owner_id and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date and b.start_time < p_end_date
    and b.status in ('confirmed', 'upcoming') and b.end_time > now();

  if (v_total_revenue - (v_cash_revenue + v_online_revenue)) <> 0 then
    v_cash_revenue := v_total_revenue - v_online_revenue;
  end if;

  select json_build_object(
    'meta', json_build_object('start_date', p_start_date, 'end_date', p_end_date, 'period_days', v_period_days),
    'revenue', json_build_object(
      'total', round(v_total_revenue, 2),
      'cash', round(v_cash_revenue, 2),
      'online', round(v_online_revenue, 2),
      'cash_percentage', case when v_total_revenue > 0 then round((v_cash_revenue / v_total_revenue) * 100, 1) else 0 end,
      'online_percentage', case when v_total_revenue > 0 then round((v_online_revenue / v_total_revenue) * 100, 1) else 0 end,
      'realized_revenue', round(v_realized_revenue, 2),
      'realized_cash', round(v_realized_cash, 2),
      'realized_online', round(v_realized_online, 2),
      'cash_collected', round(v_cash_collected, 2),
      'cash_uncollected', round(v_cash_uncollected, 2),
      'online_collected', round(v_online_collected, 2),
      'online_unavailable', round(v_online_unavailable, 2),
      'upcoming_confirmed_value', round(v_upcoming_value, 2),
      'upcoming_cash_value', round(v_upcoming_cash, 2),
      'upcoming_online_value', round(v_upcoming_online, 2),
      'unrealized', case when v_avg_hourly_rate > 0
        then round(greatest(v_total_op_hours - v_booked_hours, 0) * v_avg_hourly_rate, 2) else 0 end
    ),
    'bookings', json_build_object(
      'total_count', v_total_bookings,
      'cash_count', v_cash_bookings,
      'online_count', v_online_bookings,
      'average_price', case when v_total_bookings > 0 then round(v_total_revenue / v_total_bookings, 2) else 0 end
    ),
    'capacity', json_build_object(
      'total_operating_hours', round(v_total_op_hours, 1),
      'booked_hours', round(v_booked_hours, 1),
      'unbooked_hours', round(greatest(v_total_op_hours - v_booked_hours, 0), 1),
      'occupancy_rate', case when v_total_op_hours > 0 then round((v_booked_hours / v_total_op_hours) * 100, 1) else 0 end
    )
  ) into v_result;

  return v_result;
end;
$function$;