# VSP Team Skills Cup — 39.02 scoped governorate eligibility acceptance

Date: 17 November 2026 (Africa/Cairo).
Branch: `uxlp-44-implementation`. This report accepts **one existing core ID, 39.02**, for Team Skills Cup server-side governorate and current roster eligibility only.

## What changed

- Source migration: `supabase/migrations/20261117023000_team_skills_registration_governorate_guard.sql`.
- `public.team_skills_register` now compares the actual captain-owned team's non-empty `teams.governorate` to the cup's `team_skills_cups.governorate` after trimming whitespace and normalizing case.
- A mismatch or missing team governorate fails before inserting registration, roster, waitlist or audit rows. The original captain-only authentication, blocked captain/player, five unique team-member players with a goalkeeper, duplicate-team/player, registration window and capped waitlist protections remain.
- The new guard is authoritative on the server, not just a Flutter form check. Anonymous EXECUTE remains denied.

## Real SQL contract and staging evidence

- Executable fixture: `supabase/tests/team_skills_registration_lifecycle_isolated_contract.sql`; runner: `scripts/test_team_skills_registration_lifecycle_isolated.py`. It loads the **actual latest guarded registration function**, not a fabricated client-side imitation.
- Positive: an Aswan team with mixed-case/extra-space governorate registers five legitimate players in an Aswan cup; publication and registration closure still work.
- Negative: a real Giza captain and valid Giza five-person roster attempt the Aswan cup, receive the governorate rejection, and create no registration, roster or audit records.
- [Account SQL security contracts CI — success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44003953709) on source commit `2aab3ffe3afb1d0ec9c79475303d63aa80f581a6`. Its 61-step PostgreSQL contract job completed successfully, including the registration lifecycle fixture and source lineage audit.
- Applied to **`vsp-staging` only**, project ref `vtwgqyxglevcsxwdmhop`, using the reviewed new migration name `team_skills_registration_governorate_guard_20261117`, actual staging migration version **`20261117023518`**.
- Post-apply SELECT-only catalog verification confirmed: `SECURITY DEFINER` and governorate guard present; blocked-account and bounded-waitlist guards retained; anonymous EXECUTE denied, authenticated EXECUTE granted; staging had **zero cup rows** at verification time.
- Source-to-staging manifest: `docs/team_skills_staging_migration_lineage.json`, now 38 named entries. Source timestamps are not the staging-generated migration IDs.

## Limits / not yet accepted

- This is **Team Skills Cup only**. No evidence that other leagues, invitation-only competitions, 1v1 registrations, or general user location rules now enforce the same business policy.
- The SQL fixture simulates role claims rather than a truly signed-in captain and opponent account. Do not close **59.***, **79.***, or the real browser/Android competition journeys on this basis.
- No actual staging cup/player signup was performed, nor Flutter/UI error-copy verification or real notification delivery. These require separate acceptance.
- No production migration, money/subscriptions change, release APK, store approval or `main` merge.

## Accounting

Previous: **232 accepted / 398 open / 630 total**.
One distinct original ID accepted: **39.02**.
Updated: **233 accepted / 397 open / 630 total (36.98%)**.
The retired E2E group 56 stays excluded, and group 84 stays independent.
