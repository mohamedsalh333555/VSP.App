-- Apply the same operating-window rule to every booking insert/time mutation.
create or replace function public.vsp_enforce_booking_operating_window()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare s record;
begin
 if coalesce(new.booking_type,'')='maintenance' then return new; end if;
 if tg_op='UPDATE' and new.start_time is not distinct from old.start_time and new.end_time is not distinct from old.end_time then return new; end if;
 select opening_time,closing_time,break_start_time,break_end_time,is_split_shift,maintenance_until into s
 from public.stadiums where id=new.stadium_id for update;
 if not found then raise exception 'STADIUM_NOT_FOUND'; end if;
 if not public.vsp_validate_stadium_booking_window(s.opening_time,s.closing_time,s.break_start_time,s.break_end_time,s.is_split_shift,s.maintenance_until,new.start_time,new.end_time) then
   raise exception 'OUTSIDE_OPERATING_HOURS: موعد الحجز خارج ساعات تشغيل الملعب أو يتعارض مع فترة التوقف أو الصيانة.' using errcode='22023';
 end if;
 return new;
end; $$;
drop trigger if exists trg_bookings_operating_window on public.bookings;
create trigger trg_bookings_operating_window before insert or update of start_time,end_time on public.bookings for each row execute function public.vsp_enforce_booking_operating_window();
revoke execute on function public.vsp_enforce_booking_operating_window() from public,anon;
grant execute on function public.vsp_enforce_booking_operating_window() to authenticated,service_role;