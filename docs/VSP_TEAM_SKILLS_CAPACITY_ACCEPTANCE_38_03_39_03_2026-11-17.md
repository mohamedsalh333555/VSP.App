# VSP — bounded task acceptance: 38.03 + 39.03 (Team Skills Cup)

Date: 2026-11-17 (Egypt). Scope: **Team Skills Cup only**, not a claim that
every VSP league/tournament or the production deployment has passed.

## 38.03 — ضبط عدد المشاركين (ACCEPTED in Team Skills scope)

**Acceptance claim:** Team Skills admin creation offers 4–8 teams and rejects
out-of-range caps before RPC. The actual staging database CHECK constraint
`team_skills_cups_max_teams_check` enforces `max_teams >= 4 AND <= 8`.
The privileged cup-creation RPC and a dedicated client draft validator keep
the same rule.

Evidence:
- `vsp-admin-panel/src/services/teamSkillsCupValidation.js` and
  `test/teamSkillsCupValidation.test.js`, branch `feat/team-skills-cup`;
  invalid team counts are rejected.
- Staging **SELECT-only** inspection of `pg_constraint` on
  `public.team_skills_cups` confirmed the 4–8 rule on 2026-11-17.
- Admin CI at SHA `f33d5f6588c5969450a9e7932167b8b2b81796c1`:
  [122/122 Node tests and Vite production build pass](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43986557256).

Exclusions: player/captain sign-in E2E, all other competition types,
production schema, and store/device release remain separate open gates.

## 39.03 — التحقق من السعة (ACCEPTED in Team Skills scope)

**Acceptance claim:** Team Skills registration and admin review enforce the
cup's capacity. PostgreSQL serializes competing writes using a cup row lock;
the bounded waiting list cannot be incorrectly promoted above approved slots.
A freed slot permits the intended waiting registration.

Evidence:
- The live staging function definitions for `team_skills_register` and
  `team_skills_review_registration` contained both `max_teams` capacity
  logic and `FOR UPDATE` locks (2026-11-17, **read-only** query).
- `scripts/test_team_skills_capacity_isolated.py` executes the exact
  checked-in waitlist capacity migration on disposable PostgreSQL. CI output:
  `PASS: full cup rejects waitlist promotion, nonadmin rejected, freed slot succeeds`.
- `scripts/test_team_skills_capacity_concurrency.py` runs two independent
  local PostgreSQL sessions racing for the final slot. CI output:
  `PASS: 2 independent SQL sessions, one waitlist approval and one capacity denial`.
- Both executed successfully in
  [Account SQL security contracts CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43979196055)
  at SHA `3e3e16dc8a010f0cf85ee8c9d5a09356f672e81d`.
- Flutter CI, Android smoke, iOS build and owner security jobs succeeded on
  the same app SHA. These do not replace the specific SQL checks above.

Exclusions: login-separated real-device/browser E2E is NOT proven; Team Skills
staging rollout and production deployment are NOT authorized.
`39.06`, `39.07`, `59.01`–`59.06`, security acceptance and integration gates
remain open for their wider scenarios. In particular, this bounded acceptance
does NOT close the separate 39.07 final-slot acceptance for every required
registration pathway.

## Accounting and safety

- Baseline: **211 accepted / 419 open**, total **630**.
- Exactly **two distinct existing core IDs** promoted here: **38.03, 39.03**.
- New total: **213 accepted / 417 open**, still **630**; no new IDs and no
  double counting based on commits or unit test count.
- Both are bounded, implementation/isolated-contract accepted criteria.
  Real-role, production, payments, notifications, and full tournament journey
  acceptance remain explicitly separate.
- GitHub branches only; no `main` merge, production change, or APK release.

This document is linked by the detailed active task inventory and the unified
execution plan; `scripts/verify_task_accounting.py` must agree with the live
delivery ledger before the new count is reported as synchronized.
