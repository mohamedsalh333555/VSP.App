-- Best goalkeeper must be based on completed, approved measurements.
-- Reject unresolved equal save-rate and save-count ties rather than awarding
-- by arbitrary goalkeeper UUID order. No direct score or prize writes.
create or replace function vsp_skills_private.guard_goalkeeper_award()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_leader uuid; v_rate numeric; v_saves bigint; v_ties bigint;
begin
 if new.award_type <> 'best_goalkeeper' then return new; end if;
 if exists (
   select 1 from public.team_skills_goalkeeper_trials t
   where t.cup_id=new.cup_id and t.status <> 'approved'
 ) then raise exception 'Goalkeeper trials await approval'; end if;
 with keeper_totals as (
   select t.goalkeeper_id,sum(t.shots_on_target)::bigint as shots,
     sum(t.saves)::bigint as saves,
     sum(t.saves)::numeric/nullif(sum(t.shots_on_target),0) as rate
   from public.team_skills_goalkeeper_trials t
   where t.cup_id=new.cup_id and t.status='approved'
   group by t.goalkeeper_id
   having sum(t.shots_on_target)>=5
 )
 select totals.goalkeeper_id,totals.rate,totals.saves
 into v_leader,v_rate,v_saves
 from keeper_totals totals order by totals.rate desc,totals.saves desc,
   totals.goalkeeper_id limit 1;
 if v_leader is null then raise exception 'No eligible approved goalkeeper'; end if;
 with keeper_totals as (
   select t.goalkeeper_id,sum(t.shots_on_target)::bigint as shots,
     sum(t.saves)::bigint as saves,
     sum(t.saves)::numeric/nullif(sum(t.shots_on_target),0) as rate
   from public.team_skills_goalkeeper_trials t
   where t.cup_id=new.cup_id and t.status='approved'
   group by t.goalkeeper_id
   having sum(t.shots_on_target)>=5
 )
 select count(*) into v_ties from keeper_totals totals
 where totals.rate=v_rate and totals.saves=v_saves;
 if v_ties>1 then raise exception 'Goalkeeper tie needs documented playoff'; end if;
 if new.player_id is distinct from v_leader then
   raise exception 'Awarded goalkeeper is not objective winner';
 end if;
 return new;
end $$;
revoke all on function vsp_skills_private.guard_goalkeeper_award() from public,anon;
drop trigger if exists team_skills_guard_goalkeeper_award on public.team_skills_awards;
create trigger team_skills_guard_goalkeeper_award
before insert on public.team_skills_awards
for each row execute function vsp_skills_private.guard_goalkeeper_award();
