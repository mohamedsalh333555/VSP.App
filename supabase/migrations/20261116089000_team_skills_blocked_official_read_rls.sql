-- Close a read-only authorization gap: blocking a judge must immediately
-- hide their private assignment, pending scores and goalkeeper measurements.
-- Published/approved public scores retain their normal visibility.
--
-- The users policy permits a signed-in user to read their own is_blocked flag.
-- Organizers may still read their assigned (non-public) event measurements.
drop policy if exists official_own_or_admin on public.team_skills_officials;
create policy official_own_or_admin
on public.team_skills_officials for select to authenticated
using (
  vsp_skills_private.is_admin()
  or (
    user_id = (select auth.uid())
    and exists(
      select 1 from public.users u
      where u.id = (select auth.uid())
        and coalesce(u.is_blocked,false) = false
    )
  )
);

drop policy if exists score_approved_or_official on public.team_skills_scores;
create policy score_approved_or_official
on public.team_skills_scores for select to authenticated
using (
  (status='approved' and exists(
    select 1 from public.team_skills_cups c
    where c.id=team_skills_scores.cup_id and c.status <> 'draft'
  ))
  or vsp_skills_private.is_admin()
  or exists(
    select 1 from public.team_skills_officials o
    join public.users u on u.id=o.user_id
    where o.cup_id=team_skills_scores.cup_id
      and o.user_id=(select auth.uid())
      and coalesce(u.is_blocked,false)=false
  )
);

drop policy if exists goalkeeper_trial_official on public.team_skills_goalkeeper_trials;
create policy goalkeeper_trial_official
on public.team_skills_goalkeeper_trials for select to authenticated
using (
  vsp_skills_private.is_admin()
  or exists(
    select 1 from public.team_skills_officials o
    join public.users u on u.id=o.user_id
    where o.cup_id=team_skills_goalkeeper_trials.cup_id
      and o.user_id=(select auth.uid())
      and coalesce(u.is_blocked,false)=false
  )
);
