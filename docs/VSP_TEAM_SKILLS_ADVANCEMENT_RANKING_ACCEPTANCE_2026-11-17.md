# Team Skills Cup — Bounded acceptance: 40.04 + 42.05

Date: 2026-11-17 (Africa/Cairo).

## Original ID 40.04 — تطبيق التأهل

**ACCEPTED (Team Skills Cup only):** The current server-side
`team_skills_generate_knockout` and `team_skills_approve_knockout_match`
migrations are exercised together in a fresh disposable PostgreSQL database.
The test generates a four-team bracket, rejects an attempt to approve a
not-yet-ready final, rejects nonadmin mutation, negative/tied goals, moves
both semifinal winners into their correct final slots and approves the
actual winner of the final. Repeat semifinal/final submissions leave a
single audit record per original match. Cancelled tournament matches are
not approved.

- Real-function fixture:
  `supabase/tests/team_skills_knockout_advancement_isolated_contract.sql`.
- Runner: `scripts/test_team_skills_knockout_advancement_isolated.py`.
- Exact CI output: `PASS: actual knockout RPC promotes both semifinals, selects final champion, denies ties, repeat, outsider and cancelled cup`.

**Open:** 40.05 genuine tie adjudication/penalty resolution, 40.06 safe
re-generation of a bracket (different from denial of repeats), actual
signed-in user role separation and device journey.

## Original ID 42.05 — تحديث الجداول بعد الاعتماد

**ACCEPTED (Team Skills Cup only):** The actual
`public.team_skills_leaderboard` security-invoker view from the foundation
migration is loaded alongside the actual `team_skills_approve_score` RPC.
Two submitted scores initially remain `pending`; neither contributes to
the leaderboard. Admin approval of one score changes precisely that
registration's points from zero to 8.75 and completed stages from zero
to one; the other team's pending 10-point score stays at zero.
Duplicate/unknown approvals remain denied; approved points do not
double count.

- Real-view/RPC fixture:
  `supabase/tests/team_skills_score_approval_isolated_contract.sql`.
- Runner: `scripts/test_team_skills_score_approval_isolated.py`.
- Exact CI output: `PASS: pending result excluded from leaderboard; admin approves exact score; standings update once; outsider and duplicate denied; audit once`.

**Open:** delivery of refreshed standings to a real Flutter session,
multi-account JWT/E2E, competition notifications and production release.

## Evidence and counting

- [Account SQL security contracts — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43991954868)
  on commit `82e6988096a9146711999590248b60e97b257604`.
- Both scripts use `reject_nonlocal_targets` and a newly created disposable
  local database. No staging/production SQL migrations were applied.
- Earlier accepted baseline: **224/630 accepted, 406 open**.
- Exactly two newly accepted, distinct original IDs: **40.04** and **42.05**.
- New intended ledger: **226/630 accepted, 404 open**.
- Independent staging signed-in JWT account tests, notification delivery,
  Android/iOS manual acceptance, Store approval and any main merge are NOT
  implied by the two bounded acceptances.

Update the detailed checklist, unified plan, delivery ledger and progress
summary together and enforce their reconciliation with
`scripts/verify_task_accounting.py`.
