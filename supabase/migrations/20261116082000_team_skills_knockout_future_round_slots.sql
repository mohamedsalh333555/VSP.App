-- A future-round knockout match starts with two unresolved participants.
-- Previous CHECK(first_registration_id IS DISTINCT FROM second_registration_id)
-- incorrectly rejects (NULL,NULL): unlike equal real UUIDs, it is a valid
-- placeholder. Preserve the prohibition on putting one team against itself.
alter table public.team_skills_knockout
  drop constraint if exists team_skills_knockout_check;
alter table public.team_skills_knockout
  drop constraint if exists team_skills_knockout_distinct_teams;
alter table public.team_skills_knockout
  add constraint team_skills_knockout_distinct_teams
  check (
    first_registration_id is null
    or second_registration_id is null
    or first_registration_id <> second_registration_id
  );
