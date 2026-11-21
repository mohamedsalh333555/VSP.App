-- Team Skills views are read-only API surfaces. PostgreSQL 15
-- security_invoker views already honor underlying table RLS; restrict the
-- authenticated API role to SELECT instead of inherited full DML privileges.
-- Never revoke service-role or migration-owner privileges.
alter view public.team_skills_leaderboard set (security_invoker = true);
alter view public.team_skills_team_history set (security_invoker = true);
alter view public.team_skills_player_history set (security_invoker = true);

revoke insert, update, delete, truncate, references, trigger
  on table public.team_skills_leaderboard,
           public.team_skills_team_history,
           public.team_skills_player_history
  from authenticated, anon, public;

grant select
  on table public.team_skills_leaderboard,
           public.team_skills_team_history,
           public.team_skills_player_history
  to authenticated;
