# Performance Optimization & Loading Experience — additive workstream

Status: **IN PROGRESS** · Branch: `uxlp-44-implementation` · No merge to `main` without explicit owner approval.

This is a sub-workstream of the existing VSP execution plan, not a replacement for Phase 8, Phase 9, UX work, or the 24 acceptance journeys. Owner subscriptions remain the revenue model. Do not mark any journey passed without actual acceptance evidence.

## Verified code inventory (2026-11-06)

- Flutter/Supabase architecture: `StadiumRepository` uses PostgREST queries and Realtime streams. Stadium discovery has a server-filtered `getStadiumsPaginated` path; a separate `getStadiums` stream caps rows and filters verification on the client. Measure both before changing filtering semantics.
- `ShimmerImage` already uses `CachedNetworkImage`, placeholder shimmer, error fallback, and display-size-aware memory decode dimensions. No blanket replacement or speculative image conversion.
- Stadium details carousel uses `PageView.builder` and cached images; full-screen gallery has separate image sizing. Verify actual network transfer and visual quality on representative devices.
- `FastCacheService` persists stadium lists in SharedPreferences and memory, with no explicit TTL in the inspected implementation. Cached stadium details must not be treated as confirmed live availability, pricing, payment or subscription entitlement.
- Owner stadium list fetches initial REST data then Realtime; confirm whether both paths duplicate data transfer in real sessions before altering.
- Team roster image lookup is one batched `user_public_profiles` request, not N+1. `579b4159` removes repeated IDs from its filter; prior fixes aligned image output to member IDs.

## Prioritized execution tasks

| ID | Priority | Status | Validation / safe implementation gate |
|---|---|---|---|
| PLOAD-01 | P1 | PARTIAL | Inventory major screen network calls and record baseline request count, bytes, first meaningful content and error rates on low-end Android / weak network |
| PLOAD-02 | P1 | NOT STARTED | Measure stadium discovery queries, returned columns and pagination; optimize only proven excess payload; retain RLS and live availability correctness |
| PLOAD-03 | P1 | NOT STARTED | Profile home, stadium details, booking, collective matches, challenges, tournaments and owner dashboard loading/error/retry states |
| PLOAD-04 | P2 | PARTIAL | Image component already has caching and decode sizing; measure compressed image transfer, image dimensions and carousel memory before WebP/AVIF conversion |
| PLOAD-05 | P1 | NOT STARTED | Define TTL and explicit invalidation for **public, nontransactional** stadium metadata; never cache live slots, bookings, payments or entitlements as authoritative |
| PLOAD-06 | P2 | NOT STARTED | Read-only EXPLAIN (ANALYZE only on safe staging SELECTs) and pg_stat inspection for measured slow query patterns; index changes require evidence |
| PLOAD-07 | P2 | NOT STARTED | Validate pagination and skeleton/error/empty/retry states on representative slow connections; no misleading stale confirmation |
| PLOAD-08 | P2 | PARTIAL | Deduplicate roster profile lookup filter IDs (`579b4159`); awaiting CI and representative payload measurements |
| PLOAD-09 | P1 | NOT STARTED | Repeat measured before/after device and database benchmarks; report p50/p95/p99 where sufficient samples exist |
| PLOAD-10 | P1 | NOT STARTED | Run affected Flutter/Android tests and preserve 24-journey acceptance gate; document blockers |

## Measurement rules

Use Flutter DevTools network/performance/memory profiling on real or emulator Android under controlled network conditions; capture baseline and post-change screenshots/exports. For web builds only, record LCP/INP/CLS with browser tooling. LCP/INP/CLS are not native Flutter mobile performance metrics. For Supabase use read-only query plans and aggregated statistics, avoid customer PII. Record device, build SHA, connection, sample size, request bytes, render timing, query latency and observed variance. **No before/after performance improvement is claimed yet**: no controlled device baseline has been collected in this workstream.

## Release safety

No RLS changes, destructive database operations, production load tests, booking/payment cache authority or changes to subscription rules. Keep existing 24 acceptance journeys at their last evidenced status (4 passed, 3 failed, 14 blocked, 3 not run) until rerun. Changes stay on the working branch; CI success alone does not certify end-to-end acceptance.
