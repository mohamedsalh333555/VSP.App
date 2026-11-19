-- In-app cancellation notices follow the authoritative booking state.
-- No statement about refund success, money settlement or payout. The
-- recipient is the stadium's real owner plus the booking's real user_id;
-- never trust legacy bookings.owner_id or created_by_user_id for privacy.
create schema if not exists vsp_notifications_private;
revoke all on schema vsp_notifications_private from public,anon,authenticated;
create or replace function vsp_notifications_private.notify_booking_cancelled()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_owner_id uuid;
  v_venue_name text;
  v_body text;
begin
  if new.status<>'cancelled'
      or old.status is not distinct from new.status then
    return new;
  end if;
  select s.owner_id,s.name into v_owner_id,v_venue_name
    from public.stadiums s where s.id=new.stadium_id;
  if v_owner_id is null then return new;end if;
  v_venue_name:=coalesce(nullif(btrim(v_venue_name),''),'الملعب');

  v_body:='تم إلغاء حجز في '||v_venue_name||
    '. راجع تفاصيل الحجز لمعرفة حالته الحالية.';
  insert into public.notifications(
    user_id,title,body,message,type,is_read,created_at,booking_id,metadata)
  select v_owner_id,'تم إلغاء حجز في ملعبك',
    v_body,v_body,'info',false,now(),new.id,
    jsonb_build_object('source','booking','event','booking_cancelled',
      'booking_id',new.id,'recipient_role','venue_owner')
  where not exists(
    select 1 from public.notifications n
    where n.booking_id=new.id and n.user_id=v_owner_id
      and ((n.metadata->>'source'='booking' and
            n.metadata->>'event'='booking_cancelled')
           or n.title='تم إلغاء حجز في ملعبك')
  );

  if new.user_id is not null
      and new.user_id is distinct from v_owner_id then
    v_body:='تم إلغاء حجزك في '||v_venue_name||
      '. راجع تفاصيل الحجز لمعرفة حالة المدفوعات إن وجدت.';
    insert into public.notifications(
      user_id,title,body,message,type,is_read,created_at,booking_id,metadata)
    select new.user_id,'تم إلغاء حجزك',
      v_body,v_body,'info',false,now(),new.id,
      jsonb_build_object('source','booking','event','booking_cancelled',
        'booking_id',new.id,'recipient_role','booker')
    where not exists(
      select 1 from public.notifications n
      where n.booking_id=new.id and n.user_id=new.user_id
        and ((n.metadata->>'source'='booking' and
              n.metadata->>'event'='booking_cancelled')
             or n.title='تم إلغاء حجزك')
    );
  end if;
  return new;
end $$;
revoke all on function vsp_notifications_private.notify_booking_cancelled()
 from public,anon,authenticated;
drop trigger if exists trg_booking_cancelled_notify on public.bookings;
create trigger trg_booking_cancelled_notify
after update of status on public.bookings
for each row execute function vsp_notifications_private.notify_booking_cancelled();
