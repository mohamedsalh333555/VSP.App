# Team Skills leaderboard finality — 18 November 2026

## Source bug
Staging `public.team_skills_leaderboard.all_stages_approved` was derived from `approved_scores = 12`. Flutter's previously hardcoded 12 was removed, but the server still rejected valid cups with 10 or 13 configured stages.

## Fix
Migration `20261118150000_team_skills_dynamic_phase_finality.sql` preserves the original six view columns, their order and types, `security_invoker=true`, and authenticated-only grants. The completed flag now requires a **nonzero real phase count** and one approved stage score for every configured phase. `team_skills_scores` already enforces unique registration+stage and a foreign key to the phase list. Existing award-finality functions consume the boolean from this view.

## Regression and security
Run `supabase/tests/team_skills_dynamic_phase_completion_readonly_contract.sql` against staging. Includes phase scenarios 0, 10, 12 and 13 plus view security and grants. Staging has no Team Skills cup, score, registration or phase rows at the time of inspection. No user data or money affected by the migration.

Do **not** apply to production until full staging role-based and two-team acceptance; no production rollout or feature-flag change. The code change is not a formal task acceptance.
