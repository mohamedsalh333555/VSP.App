# PHASE 9 — System Integration, Reliability, Performance & Database Optimization

Status: **IN PROGRESS** · 2026-11-05 · Branch: `uxlp-44-implementation` · Never merge to main without explicit approval.

## Integration into existing execution

This is an additive execution register, not a restart. Preserve `docs/E2E_24_JOURNEYS_EXECUTION.md` (24 journeys: 4 passed, 3 failed, 14 blocked, 3 not run at last recorded staging checkpoint), `docs/PHASE8_SECURITY_COMPLIANCE.md`, UX work, and release tasks. Do not upgrade statuses without new test evidence. Existing Flutter CI and Android smoke workflows remain enabled.

## Verified architecture and initial integration map (INT-01)

Flutter mobile player/owner screens and admin-facing routes → Supabase Auth → Postgres tables/RLS/RPCs → booking, team, tournament and subscription records. Supabase Storage holds stadium media and private owner documents. Supabase Edge Functions implement owner checkout/status, Paymob webhook and other server actions. Firebase supports auxiliary messaging/crash reporting; `web_dist` contains public web pages. Exact admin routing, notification delivery, and deployed-function coverage require further verification. Payment model: **owner subscriptions, not a per-booking commission**.

Critical boundaries: player booking → atomic database slot lock → owner listing → notification; checkout initiation → provider callback → server verification → subscription entitlement; tournament result → authorization → standings → winner display. Notifications and cached UI are never the transaction's source of truth.

## Task register and priorities

| ID | Priority | Status | Required next evidence |
|---|---|---|---|
| INT-01 | P1 | PARTIAL | Trace actual RPCs, screens and error paths for each cross-component flow |
| INT-02 | P0 | PARTIAL | Existing staging booking duplicate-slot rejection passed journey 06; test concurrent different requests, repeated idempotency keys, owner/player consistency and notification failure |
| INT-03 | P0 | PARTIAL/BLOCKED | SEC-06 owner checkout authorization patched, staged and CI-tested; sandbox payment/webhook retries blocked without test provider |
| INT-04 | P1 | FAILED/PARTIAL | Journey 14 lacks invitation acceptance; journey 08 challenge acceptance differs from requested flow; preserve business rules pending decision |
| INT-05 | P0 | BLOCKED | Tournament payment and final result paths incomplete; exercise duplicate result submissions safely |
| INT-06 | P1 | BLOCKED | Journey 03/23 admin backend exercised but no verified in-app admin dashboard route |
| REL-01 | P1 | PARTIAL | Flutter CI and Android emulator smoke passed (2026-11-06); add API/concurrency/failure-recovery tests |
| REL-02 | P1 | NOT STARTED | Isolated staging failure injection: network loss, timeouts, duplicate requests, expired sessions |
| REL-03 | P0 | PARTIAL | Map state owners and reconcile after notification/payment failure |
| REL-04 | P0 | PARTIAL | Audit server-side idempotency and uniqueness constraints, test concurrent operations |
| PERF-01 | P2 | PARTIAL | Read-only staging statistics below; obtain representative query latency and EXPLAIN plans |
| PERF-02 | P2 | NOT STARTED | Trace actual queries for stadium search, availability, bookings, teams, tournaments and admin |
| PERF-03 | P2 | PARTIAL | Existing index inventory inspected; no speculative index changes |
| PERF-04 | P2 | NOT STARTED | Define TTL/invalidation for public-only data; never trust cache for booking/payment/auth |
| PERF-05 | P3 | PARTIAL | Bloom Filter deferred: no measured high-volume negative lookup problem |
| PERF-06 | P3 | NOT APPLICABLE YET | Only implement after measured win and safe invalidation design |
| LOAD-01 | P2 | NOT STARTED | Isolated staged 10→50→100→500→1000 virtual users, subject to resource limits; never load-test production |
| LOAD-02 | P2 | NOT STARTED | Correlate p50/p95/p99, error rate, throughput and database load before optimizing |
| CI-01 | P1 | PARTIAL | Existing analyze/test and Android smoke; add isolated migration/API contract checks without production secrets |
| OBS-01 | P2 | NOT STARTED | Safe correlation IDs, structured logs, failure rates; never log tokens or payment secrets |

## Database baseline: read-only staging inspection, not a load benchmark

Project `vtwgqyxglevcsxwdmhop`. `pg_stat_user_tables` snapshot: bookings estimated live 4, dead 32, seq scans 66,613, index scans 33; stadiums live 2, dead 10, seq scans 220, index scans 2; teams live 2, dead 11, seq scans 169, index scans 16; championships live 2, dead 4, seq scans 37, index scans 269; users live 7, dead 13, seq scans 405, index scans 106. These are cumulative planner statistics, **not** latency, production load or proof of a missing index. Tiny staging tables can rationally favor sequential scans. Existing bookings indexes include a GiST range index `exclude_overlapping_stadium_bookings`, `idx_bookings_conflict_check`, `idx_bookings_idempotency`, and multiple owner/user/status composites. **Follow-up verification:** a separate existing **unique partial** index `uq_booking_idempotency` enforces unique non-null keys for non-cancelled bookings. The ordinary `idx_bookings_idempotency` is not the only index; no new uniqueness migration is justified. `create_booking_atomic` also uses a per-stadium transaction advisory lock, but its early idempotency lookup runs **before** that lock and returns an existing booking ID without visibly scoping the lookup to the caller. Audit the complete authorization and retry semantics before calling this safe. No database migration applied. No database writes or index modifications performed in this baseline.

**Bloom Filter decision:** do not implement now. There is no measured negative-lookup bottleneck, and probabilistic results must never authorize/deny bookings, payments or ownership. Revisit only after real latency and query-profile evidence. Compare conventional indexing, query reduction and negative caching first.

## Existing journey linkage

01/05 authentication → SEC-01, REL-02; 02/04 stadium creation/visibility → INT-01, PERF-02; 03/23 admin → INT-06; 06/07/10/11/12/13/19 booking/payment → INT-02, REL-03/04; 08/14 challenges/teams → INT-04; 09/17/21 subscription/payment → INT-03; 15/16/18 tournaments/results → INT-05; 20 notifications → REL-02/03; 22 privacy/settings → SEC-04; 24 release → CI-01 and all P0 gates. Preserve each journey's previous status; append new failure/concurrency evidence in its own record rather than duplicating successful tests.

## Current verification and blockers

- Flutter CI `42037380088` passed on `3e61640a`. Android E2E `42037380176` was in progress when inspected; no pass claimed.
- SEC-06 status Edge Function deployed to **staging** v3 with JWT enabled; source inspection confirmed owner-id authorization; live cross-account negative test still pending.
- Payment sandbox credentials/functions, real email delivery, admin UI route, team invitation acceptance and completed tournament remain blockers in existing E2E log.
- No latency benchmarks, before/after optimization percentages, load-test success, or full Phase 9 completion claimed.
- No production mutation, financial transaction, new paid service, or main merge.

## Next execution batch

1. Audit booking idempotency lookup authorization and the pre-lock retry race; add regression tests and fix only after a verified safe migration plan. Existing unique partial index is confirmed.
2. Complete Android smoke diagnosis using new run logs; preserve failing checks.
3. Record representative staging query plans/timings and compare indexes before proposing optimization.
4. Add isolated duplicate-request and failure-recovery tests, then tie evidence back to journey IDs.
5. Continue Phase 8 and 24 journeys in parallel; update this checkpoint after each verified commit.

## Verification checkpoint — 2026-11-06

- Flutter CI run **42081295300**: SUCCESS, commit `6a55cb07`.
- Android E2E Smoke run **42081295267**: SUCCESS, commit `6a55cb07`. This verifies only the Android cold-start/language/onboarding/login smoke path, **not** all 24 journeys.
- Booking replay privacy: migration `20261105014000_harden_booking_idempotency_lookup.sql` is deployed to **Staging only**. Read-only inspection of the live staging function confirmed the user-scoped lookup and `IDEMPOTENCY_KEY_CONFLICT` rejection. Source regression test added at `test/booking_idempotency_authorization_contract_test.dart`; Flutter CI run **42120695011** passed at commit `353a23eb`; this remains a source contract, not a live replay test.
- Still outstanding: live two-account replay/authorization and concurrent duplicate-request tests; do not promote INT-02 or SEC-06 to DONE based on SQL inspection or static assertions.
- Production and `main` remain untouched by this checkpoint.

## INT-04 / REL-04 audit — 2026-11-06 (source inspection)

The 24-journey baseline remains **4 Passed / 3 Failed / 14 Blocked / 3 Not Run**; no new complete journey was exercised in this checkpoint. Flutter CI and Android E2E Smoke both **passed** on commit `b78af8df` (runs `42162807026` and `42162806948`). Those checks do not cover all 24 journeys. Newer UI commit `06ff1b46` was still running when inspected.

**New P0 security finding to verify before rollout:** in the checked-in definition of `create_challenge_booking_atomic` in `supabase/migrations/20261001140000_challenge_lifecycle_ssot_and_expiration.sql`, the early `p_idempotency_key` replay lookup selects an existing non-cancelled booking by key alone, **before captain authorization** and without scoping the lookup to `auth.uid()`. This is a source-level potential cross-user booking-ID disclosure / replay ambiguity, **not a verified live vulnerability**: later migrations or the deployed function may supersede this definition. Do not deploy an old function body to fix it. Next: inspect the **effective staging** function definition and latest migrations, run two-account replay negative tests, then make a narrowly scoped, concurrency-safe migration only if the deployed function is affected. Recheck the lookup after the relevant slot/advisory lock and the existing unique-key constraint. Preserve challenge business rules and payment state.

Journey 08 remains Failed because the current code-based challenge path does not establish opponent accept/reject. Journey 14 remains Failed because team membership lacks an invitation acceptance lifecycle. No fabricated acceptance, payment, or notification test passes are recorded.

### Effective staging challenge RPC verified — 2026-11-06

Read-only `pg_get_functiondef` inspection of Staging `public.create_challenge_booking_atomic` confirms the deployed body **differs from the old migration**: it selects `user_id` with the idempotency key and returns `IDEMPOTENCY_KEY_COLLISION` when the existing booking belongs to another authenticated user. Thus the specific unscoped cross-user replay finding in the earlier migration is **mitigated in the deployed staging body**; do not redeploy the historical SQL. However, the early replay occurs before captain validation, and the body does **not recheck the idempotency key after the stadium advisory lock**. A same-user replay is not proven to revalidate all current permissions; concurrent identical-key requests still need isolated live tests. Status: **PARTIAL, not DONE**. Next: identify the newest authoritative migration/function source, verify replay authorization semantics and concurrent request behavior, then add a safe post-lock replay check if needed. No staging or production mutations were made during this inspection.

### Challenge idempotency staging deployment verification — 2026-11-06

- Migration `20261106093000_recheck_challenge_idempotency_after_lock.sql` was applied successfully to **Staging** (`vtwgqyxglevcsxwdmhop`), not Production.
- Post-deploy read-only `pg_get_functiondef` verification returned `post_lock_recheck=true`, `cross_user_guard=true`, and `correct_order=true` for `public.create_challenge_booking_atomic`.
- Staging index inspection confirms `uq_booking_idempotency` is a **unique partial index** on non-null `idempotency_key` where `status <> 'cancelled'`; `idx_bookings_idempotency` is a separate nonunique index. This supports database-level duplicate-key prevention even for requests locking different stadiums; the latter case can still produce a generic unique-violation response instead of an idempotent replay and needs explicit live verification.
- Commits: migration `d2e7e1b6`, initial contract test `cac1a5f4`, strengthened regression assertions `196cc916`. Flutter CI at `196cc916` was pending when inspected; prior run `cac1a5f4` remained in Test. **No claim of CI pass or real concurrent two-account test.**
- Next: run isolated two-account replay, same-stadium concurrent replay, and cross-stadium same-key collision scenarios on Staging using disposable accounts and bookings; verify no cross-user booking-ID disclosure, no duplicate active booking, and clear error semantics. Do not change Production or count Journey 08 as Passed.

### Staging replay security regression — 2026-11-06

- Flutter CI **SUCCESS** on `2614eacb`, workflow run `42182795631` (earlier superseded runs were cancelled; not failures).
- Executed a read/write-free PL/pgSQL assertion block on Staging using one existing active challenge booking with a non-null idempotency key. Simulated `auth.uid()` via transaction-local `request.jwt.claim.sub` for a different UUID and for the booking owner. Assertions passed: cross-user replay returned `IDEMPOTENCY_KEY_COLLISION` without `booking_id`; same-user replay returned original `booking_id` and `idempotent=true`.
- Repeatable test committed at `supabase/tests/challenge_idempotency_replay_staging.sql` (`f470365f`). The SQL test **simulates claims under a privileged SQL session**, so it does not establish real two-account JWT/RLS behavior. No concurrent client requests were executed; concurrent behavior remains **BLOCKED / NOT VERIFIED**. No application rows were modified.

### Release CI gate check — 2026-11-06

- PR #35 is still **Draft**. After adding `pull_request: branches: [main]` to branch Flutter CI (`c99118ab`), GitHub recomputed mergeability as `mergeable=true`; the current `mergeable_state=unstable` reflects pending checks, not an approved release.
- Current-head `c99118ab` checks started: Flutter CI runs `42222486802` and `42222478726`, Android staging onboarding/login smoke `42222486956`. At inspection all were **in progress**. Do not report them passed.
- Remaining hard release blockers: 24 journey E2E failures/blocks, real authenticated concurrent booking checks, payment/refund sandbox and production rollback verification. Owner has approved release in principle; keep production untouched until gates pass.
