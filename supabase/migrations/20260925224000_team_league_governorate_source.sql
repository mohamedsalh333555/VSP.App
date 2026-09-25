create or replace function public.create_team_league(
  p_league_name text,
  p_team_id uuid,
  p_governorate text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_captain uuid;
  v_existing uuid;
  v_id uuid;
  v_payment jsonb;
  v_governorate text;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;

  select captain_id, coalesce(nullif(trim(governorate), ''), 'Cairo')
    into v_captain, v_governorate
  from public.teams
  where id = p_team_id;

  if v_captain is null or v_captain <> v_uid then
    raise exception 'فقط قائد الفريق يستطيع إنشاء الدوري';
  end if;

  v_governorate := coalesce(nullif(trim(p_governorate), ''), v_governorate, 'Cairo');

  select c.id into v_existing
  from public.championships c
  where c.template_type = 'team_league'
    and c.owner_id = v_uid
    and c.status in ('open', 'ongoing')
  limit 1;

  if v_existing is not null then raise exception 'لديك دوري قائم بالفعل'; end if;

  insert into public.championships(
    name, type, sport_type, start_date, entry_fee, grand_prize, max_teams,
    owner_id, governorate, rules, payment_methods, max_players_per_team,
    min_players_per_team, winning_points, draw_points, loss_points,
    match_duration, is_back_and_forth, trophy_medals, red_card_suspension,
    fair_play_scoring, status, paid_teams, joined_teams, is_approved,
    number_of_groups, qualifying_per_group, is_two_legs, creation_fee_paid,
    prize_pool, prize_delivered, template_type
  )
  values(
    nullif(trim(p_league_name), ''), 'league', 'football', now(), 30, 0, 4,
    v_uid, v_governorate,
    '4 فرق، كل فريق يواجه الثلاثة الآخرين مرة واحدة، 3 جولات، بدون جوائز مالية.',
    array['online'], 0, 0, 3, 1, 0, 90, false, true, false, false,
    'open', '{}'::text[], array[p_team_id::text], true, 1, 1, false,
    false, 0, false, 'team_league'
  )
  returning id into v_id;

  v_payment := public.prepare_team_league_payment(v_id, p_team_id);

  return jsonb_build_object(
    'success', true,
    'championship_id', v_id,
    'payment_required', true,
    'payment_reference', v_payment->>'payment_reference',
    'amount', 30
  );
end;
$function$;

revoke execute on function public.create_team_league(text, uuid, text) from public, anon;
grant execute on function public.create_team_league(text, uuid, text) to authenticated;
