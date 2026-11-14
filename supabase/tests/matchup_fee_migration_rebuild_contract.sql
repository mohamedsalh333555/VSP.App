-- Run only inside the disposable local database created by the guarded runner.
create schema auth;
create function auth.uid() returns uuid language sql stable as $uid$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$uid$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
end $$;
create table public.bookings (
  id uuid primary key, created_by_user_id uuid, user_id uuid,
  status text, matchup_closed_at timestamptz, end_time timestamptz
);
create table public.teams (
  id uuid primary key, name text, logo_url text, captain_id uuid,
  active_invite_code text unique, invite_code_expires_at timestamptz
);
create table public.team_members (team_id uuid, user_id uuid);
create table public.matchup_teams (
  booking_id uuid, team_id uuid, added_by_user_id uuid, joined_at timestamptz,
  unique (booking_id, team_id)
);
create table public.transactions (booking_id uuid, type text, status text);

insert into public.bookings(id, created_by_user_id, status, end_time) values
('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'confirmed', now() + interval '1 day');
insert into public.teams(id, name, active_invite_code) values
('30000000-0000-4000-8000-000000000001', 'Fifth', 'FIFTH'),
('30000000-0000-4000-8000-000000000002', 'Sixth', 'SIXTH');
insert into public.team_members(team_id, user_id)
select t.id, ('40000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
from public.teams t cross join generate_series(1,5) n;
insert into public.matchup_teams(booking_id, team_id)
select '10000000-0000-4000-8000-000000000001'::uuid,
       ('50000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
from generate_series(1,4) n;
insert into public.transactions values
('10000000-0000-4000-8000-000000000001', 'matchup_extra_teams_fee', 'paid');
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000001', true);

-- An already applied legacy version must be recoverable within a transaction.
-- LEGACY_MIGRATION_HERE
do $$ begin
  if position('matchup_extra_teams_fee' in pg_get_functiondef(
      'public.add_team_to_matchup_by_code(uuid,text)'::regprocedure)) = 0 then
    raise exception 'legacy fee source was not installed';
  end if;
end $$;
savepoint before_fee_free_upgrade;
-- CURRENT_MIGRATION_HERE
do $$ begin
  if position('MATCHUP_TEAM_LIMIT_REACHED' in pg_get_functiondef(
      'public.add_team_to_matchup_by_code(uuid,text)'::regprocedure)) = 0 then
    raise exception 'five-team function was not installed';
  end if;
end $$;
rollback to savepoint before_fee_free_upgrade;
do $$ begin
  if position('matchup_extra_teams_fee' in pg_get_functiondef(
      'public.add_team_to_matchup_by_code(uuid,text)'::regprocedure)) = 0 then
    raise exception 'transaction rollback did not restore previous definition';
  end if;
end $$;

-- Apply in the intended order; a second apply must leave the same behavior.
-- CURRENT_REPLAY_HERE
-- CURRENT_REPLAY_AGAIN_HERE
do $$ begin
  if position('matchup_extra_teams_fee' in pg_get_functiondef(
      'public.add_team_to_matchup_by_code(uuid,text)'::regprocedure)) > 0 then
    raise exception 'fee dependency survived the correction';
  end if;
  if position('MATCHUP_TEAM_LIMIT_REACHED' in pg_get_functiondef(
      'public.add_team_to_matchup_by_code(uuid,text)'::regprocedure)) = 0 then
    raise exception 'five-team cap is absent';
  end if;
  if not has_function_privilege('authenticated',
      'public.add_team_to_matchup_by_code(uuid,text)', 'EXECUTE')
     or has_function_privilege('anon',
      'public.add_team_to_matchup_by_code(uuid,text)', 'EXECUTE') then
    raise exception 'incorrect RPC execution grants';
  end if;
end $$;

do $contract$ declare
  booking constant uuid := '10000000-0000-4000-8000-000000000001';
  fifth constant uuid := '30000000-0000-4000-8000-000000000001';
  sixth constant uuid := '30000000-0000-4000-8000-000000000002';
  result jsonb;
begin
  result := public.add_team_to_matchup_by_code(booking, 'FIFTH');
  if result->>'total_teams_now' <> '5'
     or (select active_invite_code from public.teams where id=fifth) is not null then
    raise exception 'fifth team did not join and consume invite';
  end if;
  begin
    perform public.add_team_to_matchup_by_code(booking, 'SIXTH');
    raise exception 'sixth team joined despite the cap';
  exception when others then
    if sqlerrm not like 'MATCHUP_TEAM_LIMIT_REACHED:%' then
      raise;
    end if;
  end;
  if (select count(*) from public.matchup_teams where booking_id=booking) <> 5
     or (select active_invite_code from public.teams where id=sixth) <> 'SIXTH' then
    raise exception 'rejected sixth team mutated membership or invite';
  end if;
end $contract$;
