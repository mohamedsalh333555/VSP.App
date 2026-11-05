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
| REL-01 | P1 | PARTIAL | Flutter CI tests passed; Android device smoke remains unproven; add API/concurrency/failure-recovery tests |
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

Project `vtwgqyxglevcsxwdmhop`. `pg_stat_user_tables` snapshot: bookings estimated live 4, dead 32, seq scans 66,613, index scans 33; stadiums live 2, dead 10, seq scans 220, index scans 2; teams live 2, dead 11, seq scans 169, index scans 16; championships live 2, dead 4, seq scans 37, index scans 269; users live 7, dead 13, seq scans 405, index scans 106. These are cumulative planner statistics, **not** latency, production load or proof of a missing index. Tiny staging tables can rationally favor sequential scans. Existing bookings indexes include a GiST range index `exclude_overlapping_stadium_bookings`, `idx_bookings_conflict_check`, `idx_bookings_idempotency`, and multiple owner/user/status composites. **Important:** index name alone does not prove uniqueness or concurrency safety: the observed idempotency index is `CREATE INDEX`, not `CREATE UNIQUE INDEX`; verify RPC and transaction behavior before any migration. No database writes or index modifications performed in this baseline.

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

1. Inspect booking idempotency key enforcement, atomic RPC and index uniqueness; add regression tests and a targeted migration only if proven necessary.
2. Complete Android smoke diagnosis using new run logs; preserve failing checks.
3. Record representative staging query plans/timings and compare indexes before proposing optimization.
4. Add isolated duplicate-request and failure-recovery tests, then tie evidence back to journey IDs.
5. Continue Phase 8 and 24 journeys in parallel; update this checkpoint after each verified commit.
