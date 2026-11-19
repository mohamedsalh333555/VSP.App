-- VSP Team Skills Cup: an "أقوى فريق" title is final only after
-- every approved team finishes all 12 verified stages.
--
-- Lock the same cup-specific transaction key used by the score-write trigger.
-- This prevents a score correction racing with title announcement and freezes
-- the final ranking even if the 1v1 knockout was not generated yet.
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
  select count(*),min(l.team_id) into v_ties,v_top_team
  from public.team_skills_leaderboard l
  where l.cup_id=new.cup_id and l.all_stages_approved
    and l.points=v_max_points;
  if v_ties<>1 or new.team_id is distinct from v_top_team then
    raise exception 'Skills champion has unresolved points tie or wrong team';
  end if;
  return new;
end $$;
revoke all on function vsp_skills_private.guard_team_champion_finality()
  from public,anon,authenticated;

drop trigger if exists team_skills_guard_champion_finality
 on public.team_skills_awards;
create trigger team_skills_guard_champion_finality
before insert on public.team_skills_awards
for each row execute function vsp_skills_private.guard_team_champion_finality();

create or replace function vsp_skills_private.guard_score_after_seeding()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_cup uuid;
begin
 v_cup:=case when tg_op='DELETE' then old.cup_id else new.cup_id end;
 perform pg_advisory_xact_lock(hashtextextended('skills-final:'||v_cup::text,0));
 if exists(select 1 from public.team_skills_knockout k where k.cup_id=v_cup)
 then raise exception 'Knockout already seeded; skills scores are frozen'; end if;
 if exists(select 1 from public.team_skills_awards a
   where a.cup_id=v_cup and a.award_type='team_champion')
 then raise exception 'Skills champion announced; team scores are frozen'; end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
revoke all on function vsp_skills_private.guard_score_after_seeding()
  from public,anon,authenticated;
