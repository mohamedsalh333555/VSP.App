-- Cash-only booking notification hardening. Confirmations may happen on a
-- later UPDATE (not only INSERT), and the original client-supplied booking
-- owner_id must never decide the notification recipient.
-- Only the server-side state change creates an in-app receipt. Does not
-- announce electronic payment success, send marketing or alter payments.
create or replace function public.notify_cash_booking_parties()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_owner_id uuid;
  v_captain_id uuid;
  v_venue_name text;
  v_player_name text;
  v_body text;
begin
  if lower(btrim(coalesce(new.payment_method,''))) <> 'cash'
     or new.status <> 'confirmed' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  -- The stadium row is authoritative even if a legacy booking has a stale
  -- or spoofed owner_id or stadium_name. No venue means no notification.
  select s.owner_id, s.name into v_owner_id, v_venue_name
    from public.stadiums s where s.id = new.stadium_id;
  if v_owner_id is null then return new; end if;
  v_venue_name := coalesce(nullif(btrim(v_venue_name),''),'الملعب');
  v_player_name := coalesce(
    nullif(left(btrim(new.host_name),80),''),
    nullif(left(btrim(new.player_team_name),80),''),
    'لاعب'
  );
  v_body := v_player_name || ' قام بحجز ' || v_venue_name || ' في الموعد المحدد.';

  -- Reusing the booking row after cancellation or a lost response must not
  -- send an extra logical confirmation. Also recognize old untagged receipts.
  insert into public.notifications(
    user_id,title,body,message,type,is_read,created_at,booking_id,metadata
  )
  select v_owner_id,'حجز جديد مستلم!',v_body,v_body,'info',false,now(),
    new.id,jsonb_build_object('source','booking',
      'event','cash_booking_confirmed','booking_id',new.id,
      'recipient_role','venue_owner')
  where not exists (
    select 1 from public.notifications n where n.booking_id=new.id
      and n.user_id=v_owner_id and (
        (n.metadata->>'source'='booking' and
         n.metadata->>'event'='cash_booking_confirmed')
        or n.title='حجز جديد مستلم!'
      )
  );

  if lower(coalesce(new.booking_type,''))='challenge'
      and new.opponent_team_id is not null then
    select t.captain_id into v_captain_id
      from public.teams t where t.id=new.opponent_team_id;
    if v_captain_id is not null
       and v_captain_id is distinct from new.created_by_user_id then
      v_body := coalesce(nullif(left(btrim(new.player_team_name),80),''),'فريق') ||
        ' × ' ||
        coalesce(nullif(left(btrim(new.opponent_team_name),80),''),'فريقك') ||
        ' في ' || v_venue_name || '.';
      insert into public.notifications(
        user_id,title,body,message,type,is_read,created_at,booking_id,metadata
      )
      select v_captain_id,'تم تأكيد مباراة تحدي!',v_body,v_body,
        'challenge_confirmed',false,now(),new.id,
        jsonb_build_object('source','booking','event','cash_challenge_confirmed',
          'booking_id',new.id,'recipient_role','opponent_captain')
      where not exists (
        select 1 from public.notifications n where n.booking_id=new.id
          and n.user_id=v_captain_id and (
            (n.metadata->>'source'='booking' and
             n.metadata->>'event'='cash_challenge_confirmed')
            or n.title='تم تأكيد مباراة تحدي!'
          )
      );
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.notify_cash_booking_parties()
 from public, anon, authenticated;
drop trigger if exists trg_notify_cash_booking_parties on public.bookings;
create trigger trg_notify_cash_booking_parties
after insert or update of status on public.bookings
for each row execute function public.notify_cash_booking_parties();
