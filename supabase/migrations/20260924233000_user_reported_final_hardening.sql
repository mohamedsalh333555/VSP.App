-- Close the remaining user-reported business/UI gaps.
-- Team rule: one owned team + up to three additional memberships.
-- Challenge rule: both teams must have at least five members.
create or replace function public.check_team_and_member_limits()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_team_count int;
  v_owned_team_count int;
  v_joined_team_count int;
  v_new_team_captain uuid;
begin
  select count(*) into v_team_count from public.team_members where team_id = new.team_id;
  if v_team_count >= 12 then
    raise exception 'Team capacity reached: Maximum 12 players allowed per team.';
  end if;

  select captain_id into v_new_team_captain from public.teams where id = new.team_id;

  select count(*) into v_owned_team_count
  from public.teams
  where captain_id = new.user_id and id <> new.team_id;

  if new.user_id = v_new_team_captain then
    if v_owned_team_count >= 1 then
      raise exception 'Team ownership limit reached: A player can own only one team.';
    end if;
  else
    select count(*) into v_joined_team_count
    from public.team_members tm
    join public.teams t on t.id = tm.team_id
    where tm.user_id = new.user_id
      and tm.team_id <> new.team_id
      and t.captain_id is distinct from new.user_id;

    if v_joined_team_count >= 3 then
      raise exception 'Player team limit reached: A player can join up to 3 additional teams.';
    end if;
  end if;

  return new;
end;
$function$;

create or replace function public.validate_challenge_rosters()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_player_count int;
  v_opponent_count int;
begin
  if coalesce(new.booking_type, '') <> 'challenge' then
    return new;
  end if;

  if new.player_team_id is null or new.opponent_team_id is null then
    raise exception 'Challenge requires two teams.';
  end if;

  select count(*) into v_player_count from public.team_members where team_id = new.player_team_id;
  if v_player_count < 5 then
    raise exception 'Challenge requires at least 5 players in the host team.';
  end if;

  select count(*) into v_opponent_count from public.team_members where team_id = new.opponent_team_id;
  if v_opponent_count < 5 then
    raise exception 'Challenge requires at least 5 players in the opponent team.';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_validate_challenge_rosters on public.bookings;
create trigger trg_validate_challenge_rosters
before insert or update of booking_type, player_team_id, opponent_team_id
on public.bookings
for each row execute function public.validate_challenge_rosters();
