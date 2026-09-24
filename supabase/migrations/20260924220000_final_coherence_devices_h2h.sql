-- Final coherence hardening: multi-device push tokens and one matchup result per booking.

create table if not exists public.user_device_tokens (
  token text primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  platform text not null default 'android'
    check (platform in ('android','ios')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_user_device_tokens_user_id
  on public.user_device_tokens(user_id);

alter table public.user_device_tokens enable row level security;

drop policy if exists "Users can view own device tokens" on public.user_device_tokens;
create policy "Users can view own device tokens"
  on public.user_device_tokens
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can register own device token" on public.user_device_tokens;
create policy "Users can register own device token"
  on public.user_device_tokens
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own device token" on public.user_device_tokens;
create policy "Users can update own device token"
  on public.user_device_tokens
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can remove own device token" on public.user_device_tokens;
create policy "Users can remove own device token"
  on public.user_device_tokens
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create unique index if not exists uq_matchup_results_booking_id
  on public.matchup_results(booking_id);

create or replace function public.record_matchup_result_atomic(
  p_booking_id uuid,
  p_team_a_id uuid,
  p_team_b_id uuid,
  p_outcome text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_new_result_id uuid;
  v_existing_result_id uuid;
begin
  if v_caller_id is null then
    raise exception 'Unauthorized: User not authenticated';
  end if;

  select id, created_by_user_id, user_id, status, matchup_closed_at
    into v_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'Booking not found with ID: %', p_booking_id;
  end if;

  if coalesce(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id then
    raise exception 'Forbidden: Only the booking creator (host captain) has permission to record match results';
  end if;

  if v_booking.matchup_closed_at is not null then
    raise exception 'Matchup is closed: Cannot record new results for this booking';
  end if;

  if p_outcome not in ('team_a_win', 'team_b_win', 'draw') then
    raise exception 'Invalid outcome "%". Allowed: team_a_win, team_b_win, draw', p_outcome;
  end if;

  if p_team_a_id = p_team_b_id then
    raise exception 'Cannot record match result between the same team';
  end if;

  if not exists (
    select 1 from public.matchup_teams
    where booking_id = p_booking_id and team_id = p_team_a_id
  ) or not exists (
    select 1 from public.matchup_teams
    where booking_id = p_booking_id and team_id = p_team_b_id
  ) then
    raise exception 'Both participating teams must be registered in this matchup';
  end if;

  insert into public.matchup_results (
    booking_id, team_a_id, team_b_id, outcome, recorded_by, created_at
  )
  values (
    p_booking_id, p_team_a_id, p_team_b_id, p_outcome, v_caller_id, timezone('utc', now())
  )
  on conflict (booking_id) do nothing
  returning id into v_new_result_id;

  if v_new_result_id is null then
    select id into v_existing_result_id
    from public.matchup_results
    where booking_id = p_booking_id;

    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'already_recorded', true,
      'result_id', v_existing_result_id,
      'booking_id', p_booking_id
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'idempotent', false,
    'already_recorded', false,
    'result_id', v_new_result_id,
    'booking_id', p_booking_id,
    'team_a_id', p_team_a_id,
    'team_b_id', p_team_b_id,
    'outcome', p_outcome
  );
end;
$function$;
