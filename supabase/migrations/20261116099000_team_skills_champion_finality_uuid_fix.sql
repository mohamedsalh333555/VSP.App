-- Follow-up corrective migration: min(uuid) is unavailable on PostgreSQL.
-- Keep the already applied original migration immutable in migration history.
-- Selecting one UUID from ordered array is deterministic and used only
-- after verifying exactly ONE highest-scoring eligible team.
create or replace function vsp_skills_private.guard_team_champion_finality()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_teams integer;
  v_max_points numeric;
  v_top_team uuid;
  v_ties integer;
begin
  if new.award_type <> 'team_champion' then return new; end if;
  perform pg_advisory_xact_lock(
    hashtextextended('skills-final:'||new.cup_id::text,0));

  select count(*) into v_teams
  from public.team_skills_registrations r
  where r.cup_id=new.cup_id and r.status='approved';
  if v_teams < 4 or v_teams > 8 then
    raise exception 'Team champion requires 4 to 8 approved teams';
  end if;

  if exists (
    select 1
    from public.team_skills_registrations r
    left join public.team_skills_leaderboard l on l.registration_id=r.id
    where r.cup_id=new.cup_id and r.status='approved'
      and (coalesce(l.all_stages_approved,false)=false
           or coalesce(l.completed_stages,0)<>12)
  ) then
    raise exception 'Cannot crown skills champion until all teams have 12 approved stages';
  end if;

  select max(l.points) into v_max_points
  from public.team_skills_leaderboard l
  where l.cup_id=new.cup_id and l.all_stages_approved;
  select count(*),(array_agg(l.team_id order by l.team_id))[1] into v_ties,v_top_team
  from public.team_skills_leaderboard l
  where l.cup_id=new.cup_id and l.all_stages_approved
    and l.points=v_max_points;
  if v_ties<>1 or new.team_id is distinct from v_top_team then
    raise exception 'Skills champion has unresolved points tie or wrong team';
  end if;
  return new;
end $$;
