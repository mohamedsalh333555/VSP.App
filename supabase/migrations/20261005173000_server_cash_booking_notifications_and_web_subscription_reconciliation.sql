-- Server-side cash booking notifications and background reconciliation for website subscriptions.
-- 1) Cash booking notifications must not rely on client-side INSERT privileges.
create or replace function public.notify_cash_booking_parties()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
  v_captain_id uuid;
  v_player_name text;
  v_body text;
begin
  if lower(coalesce(NEW.payment_method,'')) <> 'cash' or NEW.status <> 'confirmed' then
    return NEW;
  end if;

  v_owner_id := NEW.owner_id;
  v_player_name := coalesce(
    nullif(trim(NEW.host_name),''),
    nullif(trim(NEW.player_team_name),''),
    'لاعب'
  );
  v_body := v_player_name || ' قام بحجز ' ||
    coalesce(NEW.stadium_name,'الملعب') || ' في الموعد المحدد.';

  if v_owner_id is not null then
    insert into public.notifications(
      user_id,title,body,message,type,is_read,created_at,booking_id
    )
    values(
      v_owner_id,'حجز جديد مستلم!',v_body,v_body,
      'info',false,timezone('utc',now()),NEW.id
    );
  end if;

  if lower(coalesce(NEW.booking_type,'')) = 'challenge'
     and NEW.opponent_team_id is not null then
    select t.captain_id into v_captain_id
    from public.teams t
    where t.id = NEW.opponent_team_id;

    if v_captain_id is not null and v_captain_id <> NEW.created_by_user_id then
      v_body := coalesce(NEW.player_team_name,'فريق') || ' × ' ||
        coalesce(NEW.opponent_team_name,'فريقك') || ' في ' ||
        coalesce(NEW.stadium_name,'الملعب') || '.';

      insert into public.notifications(
        user_id,title,body,message,type,is_read,created_at,booking_id
      )
      values(
        v_captain_id,'تم تأكيد مباراة تحدي!',v_body,v_body,
        'challenge_confirmed',false,timezone('utc',now()),NEW.id
      );
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_notify_cash_booking_parties on public.bookings;
create trigger trg_notify_cash_booking_parties
after insert on public.bookings
for each row execute function public.notify_cash_booking_parties();

revoke execute on function public.notify_cash_booking_parties() from public, anon, authenticated;

-- 2) Reconcile pending website subscription payments in the background.
-- This delegates Paymob inquiry/confirmation to the existing server-only checkout-status function.
create or replace function public.reconcile_owner_web_subscription_orders()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order record;
  v_count integer := 0;
  v_request_id bigint;
begin
  for v_order in
    select id
    from public.owner_subscription_orders
    where status='pending'
      and payment_source='web'
      and paymob_order_id is not null
      and created_at >= timezone('utc',now()) - interval '48 hours'
    order by created_at asc
    limit 100
  loop
    begin
      select net.http_post(
        url := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/get_owner_web_checkout_status',
        headers := jsonb_build_object('Content-Type','application/json'),
        body := jsonb_build_object('order_id',v_order.id)
      ) into v_request_id;
      v_count := v_count + 1;
    exception when others then
      raise warning
        'owner web subscription reconciliation enqueue failed for %: %',
        v_order.id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object(
    'success',true,
    'queued',v_count,
    'server_time',timezone('utc',now())
  );
end;
$$;

revoke execute on function public.reconcile_owner_web_subscription_orders()
  from public, anon, authenticated;

select cron.unschedule('vsp_owner_web_subscription_reconciliation')
where exists (
  select 1 from cron.job
  where jobname='vsp_owner_web_subscription_reconciliation'
);

select cron.schedule(
  'vsp_owner_web_subscription_reconciliation',
  '*/5 * * * *',
  $$select public.reconcile_owner_web_subscription_orders();$$
);

-- 3) The pre-fee-policy web order was created against the old gross model.
-- Cancel it so an undercharged checkout can never be confirmed after the policy change.
update public.owner_subscription_orders
set status='cancelled'
where id='cecec0b7-63cd-43eb-8070-a0d8c3a8710d'
  and status='pending'
  and payment_source='web';
