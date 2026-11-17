# VSP Team Skills Cup — 38.02 / 38.04 / 38.08

**Date:** 17 November 2026. **Scope:** Team Skills Cup server-side and role-claim PostgreSQL tests, plus staging read-only checks. This is not real JWT/Android E2E acceptance.

## 38.02 — Creation of an open Team Skills cup
- Active admin uses the actual `public.team_skills_create_cup` RPC to create a draft with 12 skills stages totaling 100 points and one `create_cup` audit. The Admin branch `feat/team-skills-cup` has the creation form and validation.
- New source `supabase/migrations/20261117024000_team_skills_create_cup_stadium_governorate_guard.sql` validates stadium/governorate match on the server and stores the canonical stadium governorate, never the untrusted location field. It preserves 4–8 teams, pricing/prize fields and admin-only creation.
- The actual-function fixture `supabase/tests/team_skills_cup_creation_isolated_contract.sql`, runner `scripts/test_team_skills_cup_creation_isolated.py`, proves successful Aswan creation and denies a normal player, blocked admin, anonymous access, and an Aswan stadium labeled Cairo; failed requests create no cup, stage or audit.
- [SQL CI success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44006227132). Staging migration version `20261117025416` applied **only** to project `vtwgqyxglevcsxwdmhop`. Post-apply SELECT-only checks confirmed new guard, original admin/12-stage behavior and no anonymous EXECUTE. **Zero staging cup rows** were modified.

## 38.04 — Current role permissions defined
- **Player:** may read published cup details; cannot publish a draft or administer results.
- **Captain:** may request participation only for the team they captain with five eligible members; server checks age of registration, blocked accounts, roster, capacity and governorate.
- **Assigned judge:** may record measurements only for an assigned live cup while unblocked; cannot record in a different cup.
- **Organizer:** assigned organizer is not automatically a scoring judge.
- **Active platform admin:** may create/publish cups and approve protected scores. Blocked platform admin loses this authority.
- **Anonymous:** cannot execute the privileged cup-creation or publication methods.
- Staging catalog `pg_policies` confirmed existing scoped cup, registration, score, judge and goalkeeper read policies. Actual helper `vsp_skills_private.is_admin()` uses current database user role and block flag.

## 38.08 — Tested admin versus participant permissions
- `supabase/tests/team_skills_published_details_isolated_contract.sql` injects the **real** admin helper, `published_cups_or_admin` RLS, and `team_skills_set_status` RPC. Players cannot see an unpublished draft or publish it, blocked admins cannot preview/publish it, and active admins can publish it once with a timestamp and audit. A player then sees the published cup.
- `supabase/tests/team_skills_blocked_judge_isolated_contract.sql` verifies an assigned judge can record for their own cup, not a different cup; blocked/revoked judges and organizers are denied protected measurement writes. [PostgreSQL security run passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44006227132).

## Not closed
38.01 private cup mode, **38.05 full player publication UI** (code written but Flutter/device acceptance outstanding), 38.07 full competition journey, 42.08 event-scoped score approval, 59.* genuine JWT sessions, 79.* real cross-account scenarios. Global platform admins are not equivalent to a per-cup manager. No production deployment, APK, Paymob or `main` merge.

**Exactly three original IDs accepted with this bounded evidence: 38.02, 38.04, 38.08.**
