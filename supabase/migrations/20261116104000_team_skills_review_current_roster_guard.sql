-- Revalidate captain and five-person roster at the moment of approval.
-- Captain enrollment can sit on a waiting list for days; a once-valid
-- submission must not be approved after players leave or get suspended.
-- This trigger is a defense-in-depth guard for any future admin RPC as well.
create or replace function vsp_skills_private.guard_team_approval_roster()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_total integer;
  v_keepers integer;
begin
  if new.status<>'approved' or old.status='approved' then return new;end if;
  if not exists(
    select 1 from public.teams t
      join public.users captain on captain.id=t.captain_id
    where t.id=new.team_id and t.captain_id=new.captain_id
      and coalesce(captain.is_blocked,false)=false
  ) then
    raise exception 'Captain changed or is blocked; review cannot approve team';
  end if;
  select count(*),
         count(*) filter (where roster.position='goalkeeper')
    into v_total,v_keepers
  from public.team_skills_roster roster
  where roster.registration_id=new.id and roster.cup_id=new.cup_id
    and roster.active;
  if v_total<>5 or v_keepers<>1 then
    raise exception 'Team roster must have exactly five active players and one goalkeeper';
  end if;
  if not exists (
    select 1 from public.team_skills_roster roster
    where roster.registration_id=new.id and roster.cup_id=new.cup_id
      and roster.player_id=new.goalkeeper_id and roster.active
      and roster.position='goalkeeper'
  ) or not exists (
    select 1 from public.team_skills_roster roster
    where roster.registration_id=new.id and roster.cup_id=new.cup_id
      and roster.player_id=new.representative_id and roster.active
  ) then
    raise exception 'Goalkeeper and 1v1 representative must be active on the team';
  end if;
  if exists (
    select 1
    from public.team_skills_roster roster
    join public.users person on person.id=roster.player_id
    where roster.registration_id=new.id and roster.cup_id=new.cup_id
      and roster.active and coalesce(person.is_blocked,false)
  ) then
    raise exception 'Blocked player cannot be approved for the team cup';
  end if;
  if exists (
    select 1
    from public.team_skills_roster roster
    where roster.registration_id=new.id and roster.cup_id=new.cup_id
      and roster.active
      and not exists (
        select 1 from public.team_members member
        where member.team_id=new.team_id and member.user_id=roster.player_id
      )
      and not exists (
        select 1 from public.teams t
        where t.id=new.team_id and t.captain_id=roster.player_id
      )
  ) then
    raise exception 'All five players must still belong to the team at approval';
  end if;
  return new;
end $$;

revoke all on function vsp_skills_private.guard_team_approval_roster()
 from public,anon,authenticated;

drop trigger if exists team_skills_approval_roster_guard
 on public.team_skills_registrations;
create trigger team_skills_approval_roster_guard
before update of status on public.team_skills_registrations
for each row when (new.status='approved' and old.status is distinct from new.status)
execute function vsp_skills_private.guard_team_approval_roster();
