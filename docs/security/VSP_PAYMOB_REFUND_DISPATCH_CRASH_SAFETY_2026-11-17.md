# VSP Phase 8 — Refund dispatch crash/lease replay guard

**Date:** 2026-11-17. **Branch:** `uxlp-44-implementation`. **Scope:** source implementation and offline CI, plus read-only Supabase SQL metadata. No actual refunds, production SQL, secret rotation or `main` merge.

## Verified source problems and changes

- **Tournament and league refunds:** `claim_next_cancellation_refund_atomic`, `claim_next_1v1_cancellation_refund_atomic` and `claim_next_team_league_cancellation_refund_atomic` grant **15-minute** leases. Worker crashes after Paymob dispatch could let those claims expire and be picked up again. The earlier [44b07d18](https://github.com/mohamedsalh333555/VSP.App/commit/44b07d186b977534b54d2d2f2ffcec5fe87354fe) in-memory retry guard was insufficient across restarts. [68e76686](https://github.com/mohamedsalh333555/VSP.App/commit/68e76686a5eea1a10f62edc2e35380389b7f8bf0) now writes a compare-and-set `processing` queue dispatch marker with a held lease **before** Paymob POST. If the write errors or matches zero rows, it does not dispatch. Marker changes are deliberately held for operator reconciliation if a worker crashes mid-refund.
- **Booking refunds:** read-only inspection of `claim_booking_gateway_refund_atomic` in Staging/production showed a **5-minute** lease on pending refund transactions, which could permit a second attempt after an ambiguous gateway result. [a9ea11cd](https://github.com/mohamedsalh333555/VSP.App/commit/a9ea11cd2e34ea482765f83f6a50bce4c7900746) marks `gateway_refund_dispatched_at` durably using optimistic matching and preserves it after unknown gateway outcomes. It also rejects malformed Paymob transaction IDs instead of stripping arbitrary characters.
- **Payment proof:** [e25c26ed](https://github.com/mohamedsalh333555/VSP.App/commit/e25c26ede601aa3600bbcf66fc286ad4e2429794) and [44b07d18](https://github.com/mohamedsalh333555/VSP.App/commit/44b07d186b977534b54d2d2f2ffcec5fe87354fe) require explicit positive refund responses, not merely a provider ID or text saying "already refunded". Provider error bodies are not stored as raw diagnostic text. Previously separate security fixes remain intact.
- **Audit privacy:** [9129d652](https://github.com/mohamedsalh333555/VSP.App/commit/9129d652d30a868c82c1519a2f5d5db349b6086a) limits signed webhook payload retention for new audit records without removing required reconciliation fields.

## Tests

- [Tournament Deno + Flutter financial CI — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44109232647) on `44b07d18`.
- [Booking-specific financial CI at `a9ea11cd`](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44110166202) was **CANCELLED** by a subsequent branch push; it is **not** proof of success. The later [financial CI at `9129d652` passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44110257615), including the booking refund Deno guard test. Actual hosted claim CAS still requires Staging verification.
- [Three durable queue dispatch guards Deno + Flutter financial CI — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44110931520) on `68e76686`.
- [Webhook audit minimization CI — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44110257615).
- Added synthetic CAS/zero-row and disallowed-table tests. These are not two-worker live race tests.

## Remaining release gates

1. Validate PostgREST `locked_until` and JSON metadata compare-and-set conditions against isolated **Staging test rows**, with crash-after-dispatch, stale-worker, duplicate delivery and reconciliation scenarios. Never use real user refunds for testing.
2. Direct over-capacity webhook refunds and direct team-withdrawal refunds have separate dispatch paths; they do **not** inherit the three queue protections and require a separate at-most-once audit. Global refund idempotency remains **Needs Verification**.
3. Confirm queue state transitions and administrative reconciliation controls; the long manual hold intentionally prevents automatic repeated movement of money. Add monitoring so held items are not forgotten.
4. Verify actual Paymob Sandbox response and end-to-end refund/accounting status. Production rollout and real credentials require separate authorization. Storage advisory checks 85.01–85.03 remain open.

## Counter

All work is part of existing 30.*, 31.*, 63.*, SEC-06/10 and ongoing Phase 8 tasks. **No new unique task IDs and no broad task can be marked accepted by source CI alone.**

| Metric | Count |
| --- | ---: |
| Total unique tasks | **633** |
| Previously accepted | **266** |
| Newly accepted this batch | **0** |
| New unique IDs | **0** |
| Remaining | **367** |
| Source fixes deployed and verified on production | **0** |

The owner subscription business model has not been changed.
