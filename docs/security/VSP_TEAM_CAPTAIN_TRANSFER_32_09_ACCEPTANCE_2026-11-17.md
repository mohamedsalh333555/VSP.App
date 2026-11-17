# VSP 32.09 — اختبار نقل شارة كابتن الفريق مع مسؤول واحد

**Date:** 17 November 2026. **Branch:** `uxlp-44-implementation`. **Acceptance:** narrow source-equivalent **isolated PostgreSQL** functional and two-session concurrency tests. No hosted DB changes or real player/team mutations.

## Source parity

Read-only PostgreSQL introspection returned **identical SHA-256** of `public.transfer_team_captaincy_atomic(uuid,uuid)` in both production and Staging:

`10666ad8336552ec294e02d937226d67d2232e5e8a8689ca11277b994915e5ac`.

[Source fixture snapshot](../../supabase/tests/team_captain_transfer_isolated_contract.sql) includes the exact `pg_get_functiondef` body, not a mock implementation. The authoritative captain state lives in `teams.captain_id` (there is no separate captain-role column in `team_members`). The function locks the team row `FOR UPDATE` before authorizing transfer and updating the sole field.

## Acceptance scenarios tested

- No logged-in user; outsider trying to act as captain; recipient not on the team; blocked recipient; recipient from a different governorate — **all rejected**.
- Future confirmed booking and active ongoing championship — **both block transfer**.
- Authorized captain transfers to a verified member; exactly one team `captain_id` changes, with a single recipient notification.
- Old captain, still a member, **cannot** transfer again. New captain can transfer onward.
- Two independent PostgreSQL clients start transfers from the **same old captain** while session A holds the team-row lock. Exactly one transfer succeeds; the stale old-captain request fails, exactly one final captain and one notification persist.

CI used a disposable `postgres:17.6-alpine` service on `127.0.0.1`, database `vsp_captain_transfer_isolated`. Both the test fixture and bash concurrency driver refuse arbitrary production database targets.

**Evidence:** [Commit 8ebb2693](https://github.com/mohamedsalh333555/VSP.App/commit/8ebb2693ade926ee93079aadf50c814bf77b6379) — [GitHub Actions isolated transfer CI **SUCCESS**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44122001956).

## Limitations and accounting

- The test runs the exact captured database function in a **separate ephemeral DB**, not against a live production/staging JWT session. Live row-level policy and Flutter UI behavior are **not** established; they remain part of other 32.* / SEC-02 / SEC-07 tasks.
- The captured function might drift after a deployment; re-check production/staging hash before promoting an app release.
- **32.09 acceptance narrowly covers the specified captain-transfer invariant test**, not universal permissions certification or live release readiness.
- **Counter:** 633 unique / **268 accepted** (+1 in this batch) / **365 open**, **42.34%**. No new unique task IDs. No `main` merge.
