-- P0 privacy fix: replace accidentally uncorrelated RLS subqueries.
-- Each check binds the foreign row to the current policy table's cup/team.
-- Avoid leaking pending score, private enrollment, or keeper activity across cups.
drop policy if exists team_skills_member_registration_status
  on public.team_skills_registrations;
create policy team_skills_member_registration_status
on public.team_skills_registrations for select to authenticated
using (
  exists (
    select 1 from public.team_members m
    where m.team_id = team_skills_registrations.team_id
      and m.user_id = (select auth.uid())
  )
);

drop policy if exists score_approved_or_official
  on public.team_skills_scores;
create policy score_approved_or_official
on public.team_skills_scores for select to authenticated
using (
  (status = 'approved' and exists (
    select 1 from public.team_skills_cups c
    where c.id = team_skills_scores.cup_id
      and c.status <> 'draft'
  ))
  or vsp_skills_private.is_admin()
  or exists (
    select 1 from public.team_skills_officials o
    where o.cup_id = team_skills_scores.cup_id
      and o.user_id = (select auth.uid())
  )
);

drop policy if exists goalkeeper_trial_official
  on public.team_skills_goalkeeper_trials;
create policy goalkeeper_trial_official
on public.team_skills_goalkeeper_trials for select to authenticated
using (
  vsp_skills_private.is_admin()
  or exists (
    select 1 from public.team_skills_officials o
    where o.cup_id = team_skills_goalkeeper_trials.cup_id
      and o.user_id = (select auth.uid())
  )
);
