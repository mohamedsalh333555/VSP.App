-- Team membership has (team_id, user_id, joined_at), not an id column.
-- Preserve member/admin authorization and private phone visibility while
-- making the roster readable with deterministic join-time ordering.
create or replace function public.get_team_member_profiles(p_team_id uuid)
returns table(uid uuid, name text, phone text, p_position text)
language plpgsql security definer set search_path = public, pg_temp
as $function$
declare
  v_caller uuid := auth.uid();
  v_role text;
  v_allowed boolean := false;
begin
  if v_caller is null then return; end if;

  select role into v_role from public.users where id = v_caller;
  if v_role in ('admin', 'super_admin', 'cofounder', 'co_founder') then
    v_allowed := true;
  elsif exists (
    select 1 from public.team_members tm
    where tm.team_id = p_team_id and tm.user_id = v_caller
  ) or exists (
    select 1 from public.teams t
    where t.id = p_team_id and t.captain_id = v_caller
  ) then
    v_allowed := true;
  end if;

  if not v_allowed then return; end if;

  return query
  select u.id, u.name, u.phone, u.position
  from public.team_members tm
  join public.users u on u.id = tm.user_id
  where tm.team_id = p_team_id
  order by tm.joined_at nulls last, tm.user_id;
end;
$function$;

revoke all on function public.get_team_member_profiles(uuid) from public, anon;
grant execute on function public.get_team_member_profiles(uuid) to authenticated;
