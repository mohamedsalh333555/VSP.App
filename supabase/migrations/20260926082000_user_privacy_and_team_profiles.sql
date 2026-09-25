-- VSP user privacy and team profile hardening -- 2026-09-26
revoke execute on function public.add_team_member_atomic(uuid, uuid) from public, anon;
revoke execute on function public.create_team_atomic(jsonb, uuid[]) from public, anon;
revoke execute on function public.delete_team_atomic(uuid) from public, anon;
revoke execute on function public.get_team_active_league(uuid) from public, anon;
revoke execute on function public.get_tournament_financial_summary(uuid) from public, anon;
revoke execute on function public.remove_team_member_atomic(uuid, uuid) from public, anon;
revoke execute on function public.update_team_atomic(uuid, jsonb) from public, anon;
revoke execute on function public.validate_challenge_rosters() from public, anon, authenticated;
revoke execute on function public.withdraw_team_from_championship_atomic(uuid, uuid, text) from public, anon;
grant execute on function public.add_team_member_atomic(uuid, uuid) to authenticated;
grant execute on function public.create_team_atomic(jsonb, uuid[]) to authenticated;
grant execute on function public.delete_team_atomic(uuid) to authenticated;
grant execute on function public.get_team_active_league(uuid) to authenticated;
grant execute on function public.remove_team_member_atomic(uuid, uuid) to authenticated;
grant execute on function public.update_team_atomic(uuid, jsonb) to authenticated;
grant execute on function public.withdraw_team_from_championship_atomic(uuid, uuid, text) to authenticated;

drop policy if exists users_select_policy on public.users;
create policy users_select_policy on public.users for select to authenticated using (
  id = auth.uid() or exists (
    select 1 from public.users admin_user
    where admin_user.id = auth.uid()
      and admin_user.role in ('admin','super_admin','cofounder','co_founder')
      and coalesce(admin_user.is_blocked,false) = false
  )
);

drop policy if exists users_insert_policy on public.users;
create policy users_insert_policy on public.users for insert to authenticated with check (id = auth.uid());

drop view if exists public.user_public_profiles;
create view public.user_public_profiles as
select id, name, profile_image_url, position
from public.users
where coalesce(is_blocked,false) = false;
revoke all on public.user_public_profiles from public, anon;
grant select on public.user_public_profiles to authenticated;

drop function if exists public.get_team_member_profiles(uuid);
create or replace function public.get_team_member_profiles(p_team_id uuid)
returns table(uid uuid, name text, phone text, p_position text)
language plpgsql security definer set search_path = public, pg_temp
as $function$
declare v_caller uuid := auth.uid(); v_role text; v_allowed boolean := false;
begin
  if v_caller is null then return; end if;
  select role into v_role from public.users where id = v_caller;
  if v_role in ('admin','super_admin','cofounder','co_founder') then
    v_allowed := true;
  elsif exists (select 1 from public.team_members tm where tm.team_id = p_team_id and tm.user_id = v_caller)
     or exists (select 1 from public.teams t where t.id = p_team_id and t.captain_id = v_caller) then
    v_allowed := true;
  end if;
  if not v_allowed then return; end if;
  return query
  select u.id, u.name, u.phone, u.position
  from public.team_members tm join public.users u on u.id = tm.user_id
  where tm.team_id = p_team_id order by tm.id;
end;
$function$;
revoke all on function public.get_team_member_profiles(uuid) from public, anon;
grant execute on function public.get_team_member_profiles(uuid) to authenticated;

create or replace function public.get_team_active_league(p_team_id uuid)
returns jsonb language plpgsql security definer set search_path to public, pg_temp
as $function$
declare v_caller uuid := auth.uid(); v_champ record; v_teams jsonb; v_matches jsonb; v_standings jsonb;
begin
  if v_caller is null then return jsonb_build_object('success',false,'error','Authentication required'); end if;
  select * into v_champ from public.championships
  where p_team_id::text = any(joined_teams) and template_type='team_league'
  order by created_at desc limit 1;
  if v_champ is null then return null; end if;
  select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'logo_url',t.logo_url,'captain_phone',null))
  into v_teams from unnest(v_champ.joined_teams) jt(team_id)
  join public.teams t on t.id = jt.team_id::uuid;
  select jsonb_agg(jsonb_build_object(
    'id',m.id,'championship_id',m.championship_id,'week_number',m.week_number,'match_index',m.match_index,
    'stage',m.stage,'home_team_id',m.home_team_id,'home_team_name',m.home_team_name,
    'away_team_id',m.away_team_id,'away_team_name',m.away_team_name,'home_score',m.home_score,
    'away_score',m.away_score,'winner_id',m.winner_id,'winner_name',m.winner_name,
    'scheduled_time',m.scheduled_time,'stadium_name',m.stadium_name,'booking_id',m.booking_id,
    'status',m.status,'is_completed',m.is_completed))
  into v_matches from public.tournament_matches m where m.championship_id=v_champ.id;
  select jsonb_agg(jsonb_build_object(
    'team_id',s.team_id,'team_name',s.team_name,'played',s.played,'won',s.won,'drawn',s.drawn,
    'lost',s.lost,'goals_for',s.goals_for,'goals_against',s.goals_against,
    'goal_difference',s.goal_difference,'points',s.points))
  into v_standings from public.get_championship_standings(v_champ.id) s;
  return jsonb_build_object(
    'id',v_champ.id,'name',v_champ.name,'status',v_champ.status,'entry_fee',v_champ.entry_fee,
    'max_teams',v_champ.max_teams,'owner_id',v_champ.owner_id,'champion_team_id',v_champ.champion_team_id,
    'champion_team_name',v_champ.champion_team_name,'joined_teams_count',coalesce(array_length(v_champ.joined_teams,1),0),
    'teams',coalesce(v_teams,'[]'::jsonb),'matches',coalesce(v_matches,'[]'::jsonb),
    'standings',coalesce(v_standings,'[]'::jsonb));
end;
$function$;
revoke all on function public.get_team_active_league(uuid) from public, anon;
grant execute on function public.get_team_active_league(uuid) to authenticated;