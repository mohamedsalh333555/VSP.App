# Phase 8 — Paymob refund single ownership and Team League state consistency

**Date:** 2026-11-17. **Branch:** `uxlp-44-implementation`.  
**Method:** repository source review, read-only inspection of Supabase production and Staging function definitions and CHECK constraints, CI-only synthetic PostgreSQL 17 sessions, Deno/Flutter financial contracts.

**Zero hosted writes:** No migrations applied to production or Staging; no Paymob charges/refunds; no release, secret rotation or merge to `main`.

## Confirmed findings and code fixes

### 1. Team tournament over-capacity refunds had TWO dispatch owners

The existing **production and Staging** `public.confirm_tournament_order_atomic(text,text)` function detects cancellation/capacity failures and, inside the confirmation transaction, inserts `cancellation_refund_queue` with `ON CONFLICT (order_id) DO NOTHING` and returns `needs_refund=true`. Before this batch, the signed Paymob Webhook **also** directly called `/api/acceptance/void_refund/refund` when it received `needs_refund`. This could cause the queue worker and webhook to issue separate external refunds for the same transaction.

**Remediation:** [2a32fdf6](https://github.com/mohamedsalh333555/VSP.App/commit/2a32fdf67ec3f0cd170127bc98a392096bf2e7a0) removes the duplicate external call and direct refund-status RPC for team tournament `TOURN_` references. The webhook acknowledges `refund_queued`, and only the existing SQL queue's worker can attempt the refund with its persisted dispatch claim. Replayed/failed RPC responses no longer falsely report payment confirmation as successful. Historical 1v1 remains a **separate direct refund path requiring its own audit**, not silently removed.

**Tests:** [Financial payment regressions SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44113325380) at test-fix SHA `c635b701`: Deno's negative tests assert the team branch has no Paymob refund endpoint and that queue worker owns the refund; focused Flutter financial contracts also passed.

### 2. Team League payment-status CHECK disagreed with deployed RPCs

Read-only inspection of **production and Staging** `public.team_league_payments` found `team_league_payments_status_ck` permitting only `pending`, `paid`, `failed`, `refunded`. Existing functions, including `cancel_team_league`, `cancel_tournament_payment_order_atomic`, `withdraw_team_from_championship_atomic`, and `finalize_team_withdrawal_refund_atomic`, write other legitimate states: `refund_requested`, `refund_failed_manual_review`, `cancelled`, `cancelled_withdrawal`, and `refund_pending`. Those UPDATEs can fail with CHECK violations.

**Remediation:** [3e85ef83](https://github.com/mohamedsalh333555/VSP.App/commit/3e85ef83aaf8f75d6d26e99dd95dcbc58ef8ef2e) adds a transactional, validated CHECK migration `20261117173000_align_team_league_payment_refund_states.sql`. It preserves the four original states, adds only the five source-confirmed states, continues rejecting arbitrary values, and sets a bounded lock/statement timeout. It **does not loosen RLS or grant new privileges**.

**Tests:** [Disposable PostgreSQL 17 CI SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44114070373), including running the actual migration, validating all nine states, rejecting an unknown state, and verifying migration rerun.

### 3. Direct paid team withdrawal lacked a pre-dispatch order claim

`withdraw_team_from_championship_atomic` checks caller/team permissions but only SELECTs a `paid` order; previously two concurrent callers could both receive `refund_required=true` and each POST Paymob's external refund. Furthermore, a malformed `paymob_transaction_id` was silently stripped of non-digits, and an unverified finalization could be returned with the provider success flag.

**Remediation:** [880ae86d](https://github.com/mohamedsalh333555/VSP.App/commit/880ae86d5e982e35c4c7b40c90a19313001d9dca) requires a single compare-and-set update of the matching championship/team/order/transaction from `paid` to `refund_pending` **before the provider call**. Another call seeing 0 updated rows cannot dispatch. The provider ID must be a positive safe integer without character stripping; an unconfirmed ledger result requires manual review, and sensitive provider errors are not echoed to the client. **Deployment dependency:** the CHECK migration above must be applied/tested before enabling this updated Edge Function against Team League orders.

**Tests:** [Deno + Flutter financial CI SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44114439885). [Two independent PostgreSQL-session CAS test SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44114766244) in disposable CI, proving only one of two concurrent `paid` → `refund_pending` claims wins. This is **not** a real two-user Supabase/RLS or Paymob Sandbox transaction test.

## Release blockers and explicit next verification

1. **Migration not deployed.** Staging and production still had the original four-state CHECK at read-only verification. Do not deploy new direct withdrawal Edge Function ahead of the schema change. Apply migration only through an authorized rollout, Staging first, then verify the actual constraint.
2. Direct 1v1 over-capacity and cancelled-booking auto-refunds still have distinct paths outside the team queue. They require their own at-most-once dispatch review, particularly under repeated signed webhook delivery.
3. Test real Paymob **Sandbox** duplicate/late callbacks, refund idempotency and ambiguous gateway responses, and independent Staging SQL sessions with actual RLS and account roles.
4. Validate fee/principal/gross refund policy and operational reconciliation/notification flow; no refund amount change was authorized by this patch.
5. Supabase Storage advisory applicability tasks 85.01–85.03 and original SEC-06/SEC-10 remain open. Do not mark payment system production-ready.

## Task accounting

These are source changes and scoped isolated CI proofs within existing financial/SEC-06/SEC-10 and phase 8 tasks, **not new unique IDs**. The separately accepted 80.08 release-gate task made the current base **633 total / 267 accepted / 366 remaining (42.18%)**. **This batch adds 0 accepted / 0 new unique tasks.** No production-verified fix or merge.
