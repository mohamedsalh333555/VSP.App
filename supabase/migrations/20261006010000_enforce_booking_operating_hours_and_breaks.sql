-- Enforce server-authoritative stadium operating hours, split-shift breaks, and maintenance windows.
-- This closes the gap where Flutter hides unavailable times but create_booking_atomic could still accept them.

create or replace function public.vsp_validate_stadium_booking_window(
  p_opening_time time,
  p_closing_time time,
  p_break_start_time time,
  p_break_end_time time,
  p_is_split_shift boolean,
  p_maintenance_until timestamptz,
  p_start_time timestamptz,
  p_end_time timestamptz
) returns boolean
language plpgsql
immutable
as $$
declare
  v_local_start timestamp;
  v_local_end timestamp;
  v_day date;
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_break_start_ts timestamp;
  v_break_end_ts timestamp;
begin
  if p_end_time <= p_start_time then return false; end if;
  if p_maintenance_until is not null and p_end_time > p_maintenance_until then return false; end if;

  v_local_start := timezone('Africa/Cairo', p_start_time);
  v_local_end := timezone('Africa/Cairo', p_end_time);
  v_day := v_local_start::date;

  if p_opening_time is null or p_closing_time is null then return false; end if;

  v_open_ts := v_day + p_opening_time;
  v_close_ts := v_day + p_closing_time;

  if p_closing_time <= p_opening_time then
    v_close_ts := v_close_ts + interval '1 day';
    if v_local_start < v_open_ts then
      v_open_ts := v_open_ts - interval '1 day';
      v_close_ts := v_close_ts - interval '1 day';
    end if;
  end if;

  if v_local_start < v_open_ts or v_local_end > v_close_ts then return false; end if;

  if coalesce(p_is_split_shift,false)
     and p_break_start_time is not null
     and p_break_end_time is not null
     and p_break_start_time <> p_break_end_time then
    v_break_start_ts := v_day + p_break_start_time;
    v_break_end_ts := v_day + p_break_end_time;

    if p_break_end_time <= p_break_start_time then
      v_break_end_ts := v_break_end_ts + interval '1 day';
      if v_local_start < v_break_start_ts then
        v_break_start_ts := v_break_start_ts - interval '1 day';
        v_break_end_ts := v_break_end_ts - interval '1 day';
      end if;
    end if;

    if v_local_start < v_break_end_ts and v_local_end > v_break_start_ts then
      return false;
    end if;
  end if;

  return true;
end;
$$;

do $$
declare
  v_sql text;
  v_pos integer;
  v_end_rel integer;
  v_insert_at integer;
  v_insert text := $patch$
  IF NOT public.vsp_validate_stadium_booking_window(
    v_stadium.opening_time,
    v_stadium.closing_time,
    v_stadium.break_start_time,
    v_stadium.break_end_time,
    v_stadium.is_split_shift,
    v_stadium.maintenance_until,
    p_start_time,
    p_end_time
  ) THEN
    RETURN jsonb_build_object(
      'success',false,
      'code','OUTSIDE_OPERATING_HOURS',
      'message','موعد الحجز خارج ساعات تشغيل الملعب أو يتعارض مع فترة التوقف أو الصيانة.'
    );
  END IF;

$patch$;
begin
  select pg_get_functiondef('public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)'::regprocedure)
  into v_sql;

  v_pos := position('IF v_stadium.is_verified' in v_sql);
  if v_pos = 0 then raise exception 'create_booking_atomic verification anchor not found'; end if;

  v_end_rel := position('END IF;' in substring(v_sql from v_pos));
  if v_end_rel = 0 then raise exception 'create_booking_atomic verification END IF anchor not found'; end if;

  v_insert_at := v_pos + v_end_rel + length('END IF;') - 2;
  v_sql := left(v_sql, v_insert_at) || E'\\n\\n' || v_insert || substring(v_sql from v_insert_at + 1);
  execute v_sql;
end $$;