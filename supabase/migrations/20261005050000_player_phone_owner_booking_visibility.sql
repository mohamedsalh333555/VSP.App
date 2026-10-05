-- Preserve player contact availability for owners on app-created bookings.
-- Manual owner-created bookings are intentionally excluded.
create or replace function public.sync_player_phone_on_booking_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.created_by_user_id is not null
     and new.owner_id is not null
     and new.created_by_user_id <> new.owner_id
     and nullif(trim(coalesce(new.player_phone, '')), '') is null
  then
    select nullif(trim(u.phone), '')
      into new.player_phone
    from public.users u
    where u.id = new.created_by_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_player_phone_on_booking_insert on public.bookings;

create trigger trg_sync_player_phone_on_booking_insert
before insert on public.bookings
for each row
execute function public.sync_player_phone_on_booking_insert();

revoke all on function public.sync_player_phone_on_booking_insert() from public;
grant execute on function public.sync_player_phone_on_booking_insert() to authenticated;
