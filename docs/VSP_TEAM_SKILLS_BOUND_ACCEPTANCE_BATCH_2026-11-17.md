# VSP.APP — Team Skills Cup: bounded acceptance of 11 original task IDs

**Date:** 2026-11-17 (Africa/Cairo). **Base counter:** 213/630 accepted;
417 open. **Result after acceptance:** **224/630 accepted, 406 open**.

**Evidence code snapshot (VSP.App):**
`8280fbd5ec9e9fc4c1ebdbddb92f6be3b8c63014` on
`uxlp-44-implementation`.
[Account SQL security contracts — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43990874817).

All new SQL tests executed against **fresh disposable localhost PostgreSQL**,
with actual extracted Team Skills RPCs/migrations. SQL changes to hosted
staging or production: **NONE**. This is transaction/role-claim verification,
**not independently signed-in JWT/browser/device E2E**.

## Newly accepted scoped IDs

| Original ID | Bounded accepted outcome (Team Skills Cup only) | Direct test and assertion |
| --- | --- | --- |
| **39.04** | Duplicate team registrations rejected; no extra roster/audit | `supabase/tests/team_skills_auto_waitlist_isolated_contract.sql`: second call from the same captain gets `already registered`; final 8 registrations / 40 active players / 8 register audits |
| **39.05** | Enrollment refused after kickoff or while cup is draft | Same disposable real `team_skills_register` fixture: `registration closed` for both clock and status; row/roster/audit counts unchanged |
| **39.06** | Admin accept/reject registration decision validated | `supabase/tests/team_skills_capacity_isolated_contract.sql`: free slot approval succeeds; unprivileged caller denied; short reject reason refused; valid reject persists author/time/reason, deactivates roster; repeated reject blocked; exactly one audit |
| **39.07** | Last registration slot is allocated once under concurrent captains | `scripts/test_team_skills_registration_concurrency.py`: two independent PostgreSQL connections running the **real registration RPC** simultaneously; 4 pending, 1 waitlisted, 25 active roster entries, 2 new audit events; seeded to disposable local DB |
| **40.03** | Generates seeded knockout rounds from complete stages | `supabase/tests/team_skills_final_seeding_isolated_contract.sql`: actual `team_skills_generate_knockout` requires 12 approved stages, creates rounds and reserved winner/byes; existing scores become immutable |
| **40.07** | Covers each allowed team count 4,5,6,7,8 | Same real SQL fixture: 4-team baseline plus loop 5–8; exact teams once, 4 first-round matches and 8−n byes for n=5–8, 7 total matches including future rounds |
| **40.08** | Repeated generation never creates a duplicate match | Same SQL fixture: second `team_skills_generate_knockout` call is denied for every tested size and original 7-match bracket does not change |
| **42.02** | Unauthorized nonadmin cannot approve a pending score | `supabase/tests/team_skills_score_approval_isolated_contract.sql`, injected actual `team_skills_approve_score` RPC; role-claim `authenticated` outsider denied, no mutations |
| **42.03** | Authorized admin approves the exact pending score | Same isolated SQL contract: server assigns `approved`, `approved_by` and timestamp; second score remains pending |
| **42.06** | Approval creates durable actor/time/points audit | Same contract: exactly one `approve_score` audit with correct score ID, admin actor and 8.75 points |
| **42.07** | Repeat/unknown approval cannot change status or duplicate audit | Same contract: repeated and nonexistent score IDs denied; only one approved row and audit remain |

## Machine-test receipts

- [SQL CI on `8280fbd5`](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43990874817), **completed success**.
  - `PASS: 4 pending + 4 waitlisted; 9th denied; duplicate rejected; closed/draft enrollment refused; roster and audit unchanged`.
  - `PASS: full cup denies promotion; nonadmin denied; freed slot approved; admin reject reason recorded once with inactive roster`.
  - `PASS: independent captain connections race last slot; 4 pending, 1 waitlisted, 25 roster slots, 2 audits`.
  - `PASS: incomplete stages cannot seed; 4-8 teams seed with correct byes; repeat cannot duplicate; scores frozen`.
  - `PASS: signed-in role simulation denies outsider, approves exact pending score, audits once, denies duplicate/unknown`.
- GitHub admin branch `feat/team-skills-cup` previously passed **122/122 tests and build** on
  [`f33d5f6`](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43986557256).
  These do not certify the new SQL fixture's browser E2E.
- Read-only inspection of `vsp-staging` confirms the deployed
  `public.team_skills_approve_score` and
  `public.team_skills_generate_knockout` remain `SECURITY DEFINER`,
  deny `anon` EXECUTE, and use `vsp_skills_private.is_admin()` authorization.
  This **does not establish that actual JWT roles cannot be spoofed**.

## Open gates not conflated with this acceptance

- **39.01** broad player/team sign-up flow, **39.02** governorate and eligibility,
  **40.06** a supported safe *re-generation* product flow (distinct from
  refusing duplicates), **40.04/40.05** live advancement/tie adjudication.
- **42.08** actual manager-versus-foreign-tournament account isolation and
  **59.01–59.06 / 77.06 / 78.04–78.05 / 79.01–79.08** separate
  authenticated accounts, signed JWT and device/browser acceptance.
- **47.01** actual end-user notification delivery (SQL notification rows pass,
  but no separate push/device delivery verified); do not count it.
- **84.01–84.12** challenge match-result scope intake remains separate and open.
- **40.06** stays OPEN: the current RPC refuses a second bracket; that proves
  no duplicate write, not an end-to-end safe regeneration workflow.
- No production migration, payment, merge into `main`, deployment or APK.

## Accounting

This batch adds **11 previously-open IDs**, **not** 11 commits or 11 tests.
`213 + 11 = 224`, `630 - 224 = 406`.
Detailed checklist, unified execution plan, live delivery ledger and current
counter must all agree via `scripts/verify_task_accounting.py`.
