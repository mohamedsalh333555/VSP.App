-- Fix the booking guard for the emergency-closure "maintenance_until" field.
-- request_emergency_stadium_closure() sets this to now() + duration: it is
-- the END of a closure that starts immediately, not a start date for maintenance.
-- This updates only the validator called by create_booking_atomic() and
-- trg_bookings_operating_window; no booking or payment rows are changed.
--
-- The function must be STABLE (not IMMUTABLE) because its decision uses now().
create or replace function public.vsp_validate_stadium_booking_window(
  p_opening_time time,
  p_closing_time time,
  p_break_start_time time,
  p_break_end_time time,
  p_is_split_shift boolean,
  p_maintenance_until timestamptz,
  p_start_time timestamptz,
  p_end_time timestamptz
)
returns boolean
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_local_start timestamp;
  v_local_end timestamp;
  v_day date;
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_break_start_ts timestamp;
  v_break_end_ts timestamp;
begin
  if p_start_time is null or p_end_time is null
     or p_end_time <= p_start_time then
    return false;
  end if;

  -- A current emergency closure blocks slots beginning before its end.
  -- A past maintenance_until must NOT block new bookings. A slot starting
  -- at or after the closure end can be booked if operating hours permit.
  if p_maintenance_until is not null
     and p_maintenance_until > now()
     and p_start_time < p_maintenance_until then
    return false;
  end if;

  v_local_start := timezone('Africa/Cairo', p_start_time);
  v_local_end := timezone('Africa/Cairo', p_end_time);
  v_day := v_local_start::date;

  if p_opening_time is null or p_closing_time is null then
    return false;
  end if;

  v_open_ts := v_day + p_opening_time;
  v_close_ts := v_day + p_closing_time;
  if p_closing_time <= p_opening_time then
    v_close_ts := v_close_ts + interval '1 day';
    if v_local_start < v_open_ts then
      v_open_ts := v_open_ts - interval '1 day';
      v_close_ts := v_close_ts - interval '1 day';
    end if;
  end if;

  if v_local_start < v_open_ts or v_local_end > v_close_ts then
    return false;
  end if;

  if coalesce(p_is_split_shift, false)
     and p_break_start_time is not null
     and p_break_end_time is not null
     and p_break_start_time <> p_break_end_time then
    -- Anchor the closure break to the OPERATING DAY, not the booking's
    -- local start date. A 22:00–02:00 shift with a 00:00–01:00 break
    -- must reject a booking spanning 23:30–00:30 on the previous day.
    v_break_start_ts := v_open_ts::date + p_break_start_time;
    if v_break_start_ts < v_open_ts then
      v_break_start_ts := v_break_start_ts + interval '1 day';
    end if;
    v_break_end_ts := v_break_start_ts::date + p_break_end_time;
    if v_break_end_ts <= v_break_start_ts then
      v_break_end_ts := v_break_end_ts + interval '1 day';
    end if;
    if v_local_start < v_break_end_ts
       and v_local_end > v_break_start_ts then
      return false;
    end if;
  end if;
  return true;
end;
$function$;
