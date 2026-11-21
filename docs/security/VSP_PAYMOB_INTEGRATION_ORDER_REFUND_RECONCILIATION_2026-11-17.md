# VSP Phase 8 — Paymob integration, order identity, stale failures and refunds

**Date:** 17 November 2026 (Africa/Cairo). **Branch:** `uxlp-44-implementation`.  
**Scope:** reviewed checked-in Paymob Edge Function, HMAC-authenticated transaction handling, isolated Deno/Flutter regressions, and read-only Supabase Storage/RLS metadata. No production/Staging deployment, live payment, real refund, data modification, secret exposure, or `main` merge.

## Source-confirmed risks remediated in the branch

| Finding | Remediation / evidence | Acceptance |
| --- | --- | --- |
| Over-capacity tournament refunds could reconstruct a historical amount from **current** mutable pricing, causing over/under-refund if fees changed | Reuse validated HMAC-signed transaction `amountCents` for outgoing refund and refund ledger, across both legacy 1v1 and team tournaments. [274639b0](https://github.com/mohamedsalh333555/VSP.App/commit/274639b0bae5c709a34fc3c903fa698ab55efff9) | Deno + focused Flutter financial CI passed; no provider refund |
| A correctly signed webhook was not checked against a **server-side integration ID allow-list** | Require configured `PAYMOB_INTEGRATION_ID_CARD` or `PAYMOB_INTEGRATION_ID_WALLET` after HMAC/EGP/amount check. Optional **server-only** `PAYMOB_WEBHOOK_ALLOWED_INTEGRATION_IDS` allows explicitly approved historical IDs; current config missing = fail closed; values never logged. [2afc8d87](https://github.com/mohamedsalh333555/VSP.App/commit/2afc8d87606a6e087458beb824ee2f55bafd03fe) | Offline synthetic acceptance/rejection suite passed; actual hosted env/historic IDs must be verified before deploy |
| Booking, league and tournament signed callbacks accepted absent persisted Paymob order IDs (only mismatching **nonempty** ones were rejected) | Require positive, exact persisted ID for all such confirmations, including tournament gross validator and booking refund route. Existing checkout now persists `paymob_order_id` before handing out client secret. [2dabff4a](https://github.com/mohamedsalh333555/VSP.App/commit/2dabff4a3a5d2b7143ce8092338d2c91ff85c945) | Deno synthetic ID matrix and source guards passed; real legacy in-flight missing IDs require reconciliation |
| After reading an existing pending booking, a delayed failed callback for an older order could cancel a replacement checkout order | Add `.eq("paymob_order_id", orderId)` to failure UPDATE, as well as existing status/id checks. [b3609fd6](https://github.com/mohamedsalh333555/VSP.App/commit/b3609fd69eac11103ef8a026e9f2649e8f1ed72f) | Deno source regression passed; cross-session webhook/checkout race test pending |
| Both over-capacity refund branches ignored `record_*_refund_status_atomic` RPC errors and could return `success:true` despite failed refund accounting | Require ledger RPC `success:true`; report `refund_recorded`, `refund_manual_review`, or `requires_reconciliation` separately, with minimized operator audit. After outbound gateway refund, return HTTP 200 with reconciliation status rather than provoking an automatic second refund through a 5xx retry. [9d32f6d0](https://github.com/mohamedsalh333555/VSP.App/commit/9d32f6d0603ec5a72036dae8bb578cb38aa6a4eb) | Deno regression passed; actual refund ledger and gateway idempotency checks pending |

These are **confirmed source-code weaknesses** addressed in the development branch, **not** proof of active exploit, user compromise, or vulnerability in Paymob itself.

## Verification

- [Financial CI at `274639b0` — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44105832697) (Deno + focused Flutter).
- [Financial CI at `2afc8d87` — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44106409594) (Deno + focused Flutter).
- [Financial CI at `2dabff4a` — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44106689595) (Deno + focused Flutter).
- [Financial CI at `b3609fd6` — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44107059958) (Deno + focused Flutter).
- [Financial CI at `9d32f6d0` — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44107568234): both Deno synthetic HMAC/refund-ledger tests and focused Flutter financial regressions passed.
- [Owner checkout security](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44107079564), [isolated SQL security](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44107078173), [ledger accounting](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44107078152): SUCCESS on prior `b3609fd6` SHA. Latest docs/security CI is separate.

## Storage / webhook log evidence (read-only)

- Storage `objects` policy count: **20 production**, **6 staging**. Production contains additional banner, deposit receipts, verification document, stadium-image update/delete and other storage policies; staging parity is **NOT** proven. Owner documents use owner-folder checks and admin-role exceptions. No independent player/owner JWT access test or actual object upload was performed; the 3 Supabase Storage advisory audits `85.01–85.03` stay **Needs Verification**.
- `public.webhook_logs` has RLS enabled in both environments. `anon`/ordinary `authenticated` retain table-level SELECT privilege but only admin-role RLS policies were found; direct unauthorized read has **not** been demonstrated. Raw signed transaction payload audit data retention and sensitive `source_data` fields still require privacy review before any transformation of historical data.
- **Release blockers:** check live Paymob integration ID values **without revealing them**, historical in-flight order IDs, transaction/order/amount/currency cross-check, refund gateway request-id idempotency and atomic claim, concurrent events, actual Sandbox callbacks, Supabase Storage hosted patch status, production-vs-staging RLS parity, correct callback response-contract acceptance.
- Avoid rotating production secrets, applying migrations or deploying Edge Functions without separately authorized rollout.

## Count integrity

All are within **existing** 30.*, 31.*, 63.*, SEC-06/10 and previously registered 85.* advisory audits. No unique new IDs and **no whole end-to-end task accepted** in this code-only batch. The confirmed **source improvements are not production acceptance**. Historical counter stays **633 total / 266 accepted / 367 remaining**, and 3 new P0 Storage applicability audits remain open. No commission-based business-model changes.
