-- Read-only contract test for the emergency stadium maintenance guard.
-- Run ONLY after 20261113143000_fix_expired_stadium_maintenance_booking_guard
-- has been applied to an isolated local/test database.
-- No real users, bookings, prices or payment data are read or changed.
--
-- A failing assertion raises an exception and stops this script. In the old
-- implementation "expired marker accepted" fails, as reproduced on staging.

do $test$
declare
  v_local_day date := timezone('Africa/Cairo', now())::date + 1;
  v_start timestamptz;
  v_end timestamptz;
  v_night_start timestamptz;
  v_night_end timestamptz;
  v_active_until timestamptz := now() + interval '3 days';
  v_expired_until timestamptz := now() - interval '1 hour';
begin
  v_start := (v_local_day + time '18:00') at time zone 'Africa/Cairo';
  v_end := (v_local_day + time '18:30') at time zone 'Africa/Cairo';
  v_night_start := (v_local_day + time '23:30') at time zone 'Africa/Cairo';
  v_night_end := ((v_local_day + 1) + time '00:30') at time zone 'Africa/Cairo';

  -- Ordinary same-day slot.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,null,v_start,v_end
  ) is distinct from true then
    raise exception 'FAIL: normal in-hours booking must pass';
  end if;

  -- An expired emergency closure must not disable the venue forever.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,v_expired_until,v_start,v_end
  ) is distinct from true then
    raise exception 'FAIL: expired maintenance marker must allow future slot';
  end if;

  -- Closure starts on request and stays active until maintenance_until.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,v_active_until,v_start,v_end
  ) is distinct from false then
    raise exception 'FAIL: active closure must block slot before closure end';
  end if;

  -- The slot begins at closure end (allowed), not before it.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,v_start,v_start,v_end
  ) is distinct from true then
    raise exception 'FAIL: start exactly at closure end must be allowed';
  end if;

  -- A closure ending one hour before booking start must allow booking,
  -- even if the closure is still active at query time.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,v_start-interval '1 hour',v_start,v_end
  ) is distinct from true then
    raise exception 'FAIL: slot starting after closure end must pass';
  end if;

  -- Partial overlap remains blocked even when a slot ends after closure.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,v_start+interval '15 minutes',v_start,v_end
  ) is distinct from false then
    raise exception 'FAIL: partial overlap with closure must be blocked';
  end if;

  -- Break rules and Cairo overnight opening must remain unchanged.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00','18:15','18:45',true,null,v_start,v_end
  ) is distinct from false then
    raise exception 'FAIL: split-shift break overlap must be blocked';
  end if;

  if public.vsp_validate_stadium_booking_window(
    '22:00','02:00',null,null,false,null,v_night_start,v_night_end
  ) is distinct from true then
    raise exception 'FAIL: valid overnight opening must pass';
  end if;

  if public.vsp_validate_stadium_booking_window(
    '22:00','02:00',null,null,false,null,
    ((v_local_day+1)+time '03:00') at time zone 'Africa/Cairo',
    ((v_local_day+1)+time '03:30') at time zone 'Africa/Cairo'
  ) is distinct from false then
    raise exception 'FAIL: after-hours overnight slot must be blocked';
  end if;

  -- Invalid/null timestamps must never be accepted.
  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,null,v_start,v_start
  ) is distinct from false then
    raise exception 'FAIL: zero-length booking must be blocked';
  end if;

  if public.vsp_validate_stadium_booking_window(
    '16:00','23:00',null,null,false,null,null,v_end
  ) is distinct from false then
    raise exception 'FAIL: null booking start must be blocked';
  end if;
end;
$test$;
