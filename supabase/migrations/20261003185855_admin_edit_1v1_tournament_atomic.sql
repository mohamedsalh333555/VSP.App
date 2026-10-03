-- Atomic admin edit for 1v1 tournaments.
-- Applied in Supabase as migration 20261003185855_admin_edit_1v1_tournament_atomic.

create or replace function public.admin_update_1v1_tournament_atomic(
  p_tournament_id uuid,
  p_name text default null,
  p_target_player_count integer default null,
  p_entry_fee numeric default null,
  p_scheduled_at timestamptz default null,
  p_governorate text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_role text;
  v_status text;
  v_players_count integer;
  v_paid_players integer;
  v_now timestamptz := timezone('utc', now());
  v_name text;
  v_target integer;
  v_fee numeric;
  v_governorate text;
begin
  select role into v_role from public.users where id = auth.uid();

  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;

  select status into v_status
  from public.vsp_1v1_tournaments
  where id = p_tournament_id
  for update;

  if not found then
    return jsonb_build_object('success',false,'error','Tournament not found');
  end if;

  if v_status in ('completed','published','archived','cancelled') then
    return jsonb_build_object('success',false,'error','لا يمكن تعديل بطولة نهائية أو ملغاة.');
  end if;

  select count(*), count(*) filter (where coalesce(payment_status,'') = 'paid')
    into v_players_count, v_paid_players
  from public.vsp_1v1_tournament_players
  where tournament_id = p_tournament_id;

  v_name := nullif(trim(coalesce(p_name,'')), '');
  if v_name is null then
    return jsonb_build_object('success',false,'error','اسم البطولة مطلوب.');
  end if;

  v_target := coalesce(p_target_player_count, (select target_player_count from public.vsp_1v1_tournaments where id=p_tournament_id));
  v_fee := coalesce(p_entry_fee, (select entry_fee from public.vsp_1v1_tournaments where id=p_tournament_id));
  v_governorate := nullif(trim(coalesce(p_governorate,'')), '');

  if v_target < 2 then
    return jsonb_build_object('success',false,'error','عدد اللاعبين يجب أن يكون 2 على الأقل.');
  end if;

  if v_fee < 0 then
    return jsonb_build_object('success',false,'error','رسوم الاشتراك لا يمكن أن تكون سالبة.');
  end if;

  if v_target < v_paid_players then
    return jsonb_build_object('success',false,'error','لا يمكن تقليل عدد المقاعد عن عدد اللاعبين المسددين بالفعل.');
  end if;

  if v_players_count > 0 and (
    p_target_player_count is not null
    or p_entry_fee is not null
    or p_governorate is not null
  ) then
    return jsonb_build_object(
      'success',false,
      'error','بعد تسجيل لاعبين في البطولة، يمكن تعديل الاسم والموعد فقط لحماية التسجيلات والمدفوعات.'
    );
  end if;

  update public.vsp_1v1_tournaments
  set
    name = v_name,
    target_player_count = v_target,
    entry_fee = v_fee,
    scheduled_at = p_scheduled_at,
    governorate = coalesce(v_governorate, governorate),
    updated_at = v_now
  where id = p_tournament_id;

  return jsonb_build_object(
    'success',true,
    'tournament_id',p_tournament_id,
    'server_time',v_now
  );
end;
$function$;

revoke execute on function public.admin_update_1v1_tournament_atomic(uuid,text,integer,numeric,timestamptz,text) from public, anon;
grant execute on function public.admin_update_1v1_tournament_atomic(uuid,text,integer,numeric,timestamptz,text) to authenticated, service_role;
