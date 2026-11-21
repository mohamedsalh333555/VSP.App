# Server consistency: Team Skills configurable finality

`team_skills_leaderboard` now derives completion from the actual number of published phases. Three existing privileged RPCs still checked `<>12` after consulting the view, producing contradictory results.

This branch migration retains all signatures, `SECURITY DEFINER`, explicit empty `search_path`, admin checks, advisory locks, tournament status/played-match/tie guards and audit records. It replaces only the hardcoded score-count comparisons with `all_stages_approved` from the established security-invoker leaderboard view.

The **admin phase configuration RPC still intentionally requires 12 phase templates**. Supporting an optional 10/13-stage event requires separate safe design for phase types, weighting, scoring, bracket, eligibility and role tests; this migration does not claim that feature is released. No production deployment or player data modification. Staging has zero Team Skills cups at time of review.

Read-only test: `supabase/tests/team_skills_server_finality_gates_readonly_contract.sql`.
