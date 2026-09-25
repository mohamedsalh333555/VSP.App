-- VSP production coherence/security hardening batch -- 2026-09-26

revoke execute on function public.add_team_member_atomic(uuid, uuid) from anon;
revoke execute on function public.create_team_atomic(jsonb, uuid[]) from anon;
revoke execute on function public.delete_team_atomic(uuid) from anon;
revoke execute on function public.get_team_active_league(uuid) from anon;
revoke execute on function public.get_tournament_financial_summary(uuid) from anon;
revoke execute on function public.remove_team_member_atomic(uuid, uuid) from anon;
revoke execute on function public.update_team_atomic(uuid, jsonb) from anon;
revoke execute on function public.validate_challenge_rosters() from anon, authenticated;
revoke execute on function public.withdraw_team_from_championship_atomic(uuid, uuid, text) from anon;

grant execute on function public.add_team_member_atomic(uuid, uuid) to authenticated;
grant execute on function public.create_team_atomic(jsonb, uuid[]) to authenticated;
grant execute on function public.delete_team_atomic(uuid) to authenticated;
grant execute on function public.get_team_active_league(uuid) to authenticated;
grant execute on function public.remove_team_member_atomic(uuid, uuid) to authenticated;
grant execute on function public.update_team_atomic(uuid, jsonb) to authenticated;
grant execute on function public.withdraw_team_from_championship_atomic(uuid, uuid, text) to authenticated;

drop policy if exists "Public Access for Owner Documents" on storage.objects;

create table if not exists public.internal_function_secrets (
  name text primary key,
  secret text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.internal_function_secrets enable row level security;
revoke all on public.internal_function_secrets from anon, authenticated;
revoke all on public.internal_function_secrets from public;

insert into public.internal_function_secrets(name, secret)
values ('fcm_push', encode(gen_random_bytes(32), 'hex'))
on conflict (name) do nothing;

create or replace function public.handle_new_notification_fcm()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $$
declare
  v_url text := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/fcm_push';
  v_secret text;
begin
  select secret into v_secret
  from public.internal_function_secrets
  where name = 'fcm_push';

  if coalesce(v_secret, '') = '' then
    raise warning 'FCM internal secret is missing; push skipped safely.';
    return new;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('record', row_to_json(new))
  );

  return new;
exception when others then
  raise warning 'FCM push trigger exception (safe-bypass): %', sqlerrm;
  return new;
end;
$$;

create or replace function public.get_tournament_financial_summary(p_championship_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_champ record;
  v_caller uuid := auth.uid();
  v_role text;
  v_is_admin boolean := false;
  v_paid_teams_count int := 0;
  v_total_collected numeric := 0;
  v_net_profit numeric := 0;
begin
  if v_caller is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required');
  end if;

  select * into v_champ from public.championships where id = p_championship_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'البطولة غير موجودة');
  end if;

  select role into v_role from public.users where id = v_caller;
  v_is_admin := coalesce(v_role in ('admin','co_founder','cofounder','super_admin'), false);

  if not v_is_admin and v_champ.owner_id is distinct from v_caller then
    return jsonb_build_object('success', false, 'error', 'غير مصرح لك بعرض البيانات المالية لهذه البطولة');
  end if;

  if coalesce(v_champ.template_type, '') = 'team_league' then
    select count(distinct team_id)::int, coalesce(sum(amount),0)
    into v_paid_teams_count, v_total_collected
    from public.team_league_payments
    where championship_id = p_championship_id and payment_status = 'completed';
  else
    select count(distinct team_id)::int, coalesce(sum(amount),0)
    into v_paid_teams_count, v_total_collected
    from public.tournament_orders
    where championship_id = p_championship_id and payment_status = 'completed';
  end if;

  v_net_profit := v_total_collected - coalesce(v_champ.grand_prize, 0);

  return jsonb_build_object(
    'success', true,
    'paid_teams_count', v_paid_teams_count,
    'entry_fee', v_champ.entry_fee,
    'total_collected', round(v_total_collected, 2),
    'grand_prize', v_champ.grand_prize,
    'net_profit', round(v_net_profit, 2),
    'is_registration_locked', v_champ.registration_locked_at is not null
  );
end;
$function$;

revoke execute on function public.get_tournament_financial_summary(uuid) from anon;
grant execute on function public.get_tournament_financial_summary(uuid) to authenticated;

create or replace function public.withdraw_team_from_championship_atomic(
  p_championship_id uuid,
  p_team_id uuid,
  p_reason text default 'انسحاب الفريق'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_champ record;
  v_caller_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_is_team_captain boolean := false;
  v_order_amount numeric := 0;
  v_order_created_at timestamptz;
  v_refund_amount numeric := 0;
  v_gateway_fee numeric := 0;
  v_within_grace boolean := false;
  v_after_lock boolean := false;
begin
  if v_caller_id is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required');
  end if;

  select * into v_champ from public.championships
  where id = p_championship_id for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'البطولة غير موجودة');
  end if;

  select coalesce(role in ('admin','co_founder','cofounder','super_admin'), false)
  into v_is_admin from public.users where id = v_caller_id;

  select exists(
    select 1 from public.teams where id = p_team_id and captain_id = v_caller_id
  ) into v_is_team_captain;

  if not (v_is_admin or v_is_team_captain or v_champ.owner_id = v_caller_id) then
    return jsonb_build_object('success', false, 'error', 'غير مصرح لك بسحب هذا الفريق');
  end if;

  if not (
    p_team_id = any(coalesce(v_champ.paid_teams, array[]::uuid[]))
    or p_team_id::text = any(coalesce(v_champ.joined_teams, array[]::text[]))
  ) then
    return jsonb_build_object('success', false, 'error', 'الفريق غير مشترك في هذه البطولة');
  end if;

  v_after_lock := v_champ.registration_locked_at is not null;

  if v_after_lock then
    update public.championships
    set paid_teams = array_remove(coalesce(paid_teams, array[]::uuid[]), p_team_id),
        joined_teams = array_remove(coalesce(joined_teams, array[]::text[]), p_team_id::text),
        updated_at = now()
    where id = p_championship_id;

    return jsonb_build_object(
      'success', true, 'refunded', false, 'refund_amount', 0,
      'message', 'تم سحب الفريق. لا يوجد استرداد لأن القرعة قُفلت بالفعل.'
    );
  end if;

  if coalesce(v_champ.entry_fee, 0) > 0 then
    if coalesce(v_champ.template_type, '') = 'team_league' then
      select amount, created_at into v_order_amount, v_order_created_at
      from public.team_league_payments
      where championship_id = p_championship_id
        and team_id = p_team_id
        and payment_status = 'completed'
      order by created_at desc limit 1;
    else
      select amount, created_at into v_order_amount, v_order_created_at
      from public.tournament_orders
      where championship_id = p_championship_id
        and team_id = p_team_id
        and payment_status = 'completed'
      order by created_at desc limit 1;
    end if;

    if coalesce(v_order_amount, 0) > 0 then
      v_within_grace := extract(epoch from (now() - v_order_created_at)) / 60 <= 20;
      if v_within_grace then
        v_refund_amount := v_order_amount;
      else
        v_gateway_fee := least(v_order_amount, round((v_order_amount * 0.0275 + 3.0)::numeric, 2));
        v_refund_amount := greatest(0, v_order_amount - v_gateway_fee);
      end if;
    end if;
  end if;

  update public.championships
  set paid_teams = array_remove(coalesce(paid_teams, array[]::uuid[]), p_team_id),
      joined_teams = array_remove(coalesce(joined_teams, array[]::text[]), p_team_id::text),
      updated_at = now()
  where id = p_championship_id;

  if v_refund_amount > 0 then
    insert into public.transactions (
      user_id, amount, type, status, description, created_at, updated_at
    )
    select t.captain_id, v_refund_amount, 'refund_tournament', 'completed',
      'استرداد اشتراك بطولة (انسحاب): ' || v_champ.name, now(), now()
    from public.teams t where t.id = p_team_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'refunded', v_refund_amount > 0,
    'refund_amount', round(v_refund_amount, 2),
    'gateway_fee_deducted', round(v_gateway_fee, 2),
    'within_grace_period', v_within_grace,
    'message',
      case
        when v_refund_amount = 0 and coalesce(v_champ.entry_fee, 0) = 0 then 'تم سحب الفريق (بطولة مجانية)'
        when v_within_grace then 'تم سحب الفريق واسترداد المبلغ بالكامل (فترة السماح)'
        when v_refund_amount > 0 then 'تم سحب الفريق واسترداد المبلغ ناقص مصاريف البوابة'
        else 'تم سحب الفريق'
      end
  );
end;
$function$;

revoke execute on function public.withdraw_team_from_championship_atomic(uuid, uuid, text) from anon;
grant execute on function public.withdraw_team_from_championship_atomic(uuid, uuid, text) to authenticated;
