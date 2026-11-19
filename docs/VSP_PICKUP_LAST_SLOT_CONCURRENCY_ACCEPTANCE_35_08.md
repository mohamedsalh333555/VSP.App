# 35.08 — Two independent SQL sessions, one final pickup-match slot

Date: 2026-11-13. **Isolated function-contract acceptance only.** This is **not** a live Supabase, two real-account, Flutter or physical-device journey.

## Executed test

- Source: `scripts/test_accept_join_request_concurrency.py`, `supabase/migrations/20261113171000_guard_open_join_acceptance_consent.sql`; smoke guard: `test/tooling/test_accept_join_request_concurrency.py`.
- Two independent native PostgreSQL processes/transactions authenticate as the same synthetic booking host; each attempts to accept a different synthetic pending player into a booking with **one place left**.
- The competing attempts race through a locking UPDATE, with an isolated test-only `pg_sleep(0.3)` trigger encouraging overlap.
- Required outcome: **exactly one** acceptance, **exactly one** `BOOKING_FULL` response, final `current_players=2`, one joined user and one pending user, with no duplicate admission.
- The SQL command is pinned to the explicit loopback host/port/fixture database and ephemeral `postgres` test owner. Environment overrides such as PGHOSTADDR, PGSERVICE, PGSERVICEFILE, PGOPTIONS and alternative PGHOST/PGDATABASE/PGPORT/PGUSER are stripped.
- The test **creates a new disposable database** named `vsp_join_race_contracts` and drops it; it refuses an existing database. No live users, Paymob calls, staging/production mutations or account secrets.

## Verified CI

[Account SQL security contracts run 43473270739](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43473270739), source commit `b5029c8f43314fc64090a897bab7e854a2391889`:

- Step **Verify concurrency runner cannot target remote PostgreSQL**: success.
- Step **Verify two independent SQL clients cannot join the same final pickup slot**: success. Decoded job output reports `PASS: independent SQL clients cannot take the same final slot`.
- Related isolated join consent/rejection and native PostgreSQL authorization steps passed in the same run.

## Acceptance boundary

Task **35.08** is accepted for the **isolated concurrency SQL contract**: it exercises last-seat simultaneous approval without overfilling one booking. The related patch remains a **branch-only proposed RPC** and was not deployed to staging or production. This is not proof that every live pickup-join entry point or `request_join_public_match` path uses this exact function; flow mapping, server migration, two real staging accounts, role permissions and retry/failure tests remain open under 35.04–35.07, 59.*, 77.*, and 79.*. No payment or reservation was created.

No `main` merge, signed build or production database change is inferred.
