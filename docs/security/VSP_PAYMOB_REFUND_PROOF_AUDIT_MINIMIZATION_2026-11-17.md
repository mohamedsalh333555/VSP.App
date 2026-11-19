# VSP Phase 8 — Booking refund proof and Paymob webhook audit data minimization

**Date:** 17 November 2026 (Africa/Cairo). **Development branch:** `uxlp-44-implementation`. No live payment/refund, no Staging/production write, no production secrets exposed or rotated, no `main` merge.

## Source-confirmed problems and tested changes

| Scope | Previously observed source problem | Development fix | Status |
| --- | --- | --- | --- |
| `process_paymob_refund` | An HTTP 2xx refund with only a nonempty `refundResponse.id` could be marked successful even without an explicit successful provider flag | Uses existing, separately tested `isConfirmedPaymobRefund(refundHttpOk, refundResponse)`; rejection includes ID-only, failed, pending, void or inconsistent responses | **Fixed in branch; Deno/Flutter CI PASS; not deployed** |
| `process_paymob_refund` | Paymob auth error body, raw refund response and raw exception messages could be stored in transactions metadata | Replaced with bounded error codes, no raw gateway body/details persisted; top-level error logs now report only a generic exception kind | **Fixed in branch; Deno regression PASS; not deployed** |
| `paymob_webhook` | Signed callback `obj` including potentially sensitive card PAN, billing and novel provider fields was stored verbatim in `webhook_logs` at two locations, and in the expired-booking refund log | `sanitizePaymobAuditPayload` keeps order ID, transaction ID, amount, currency, integration ID, signed success/pending/refund flags and method `type/sub_type`, but discards billing details, PAN, token and new unexpected provider fields; verified original remains untouched for financial checks | **Fixed for future branch-written logs; Deno/Flutter CI PASS; not deployed** |
| `paymob_webhook` | The verified payment-accounting rejection log stored unbounded RPC error/response text | Replaced with stable non-sensitive error message, preserving event/status and transaction/order identifiers for review | **Fixed in branch; CI PASS; not deployed** |

**Commits:**
- [e25c26ed — booking refund explicit provider acceptance and diagnostics redaction](https://github.com/mohamedsalh333555/VSP.App/commit/e25c26ede601aa3600bbcf66fc286ad4e2429794)
- [9129d652 — minimal signed Paymob webhook audit fields](https://github.com/mohamedsalh333555/VSP.App/commit/9129d652d30a868c82c1519a2f5d5db349b6086a)

**Related concurrent work already on the same branch (not double-counted):** [a9ea11cd](https://github.com/mohamedsalh333555/VSP.App/commit/a9ea11cd2e34) introduced a durable booking refund dispatch marker/compare-and-set to prevent ambiguous retry. [44b07d18](https://github.com/mohamedsalh333555/VSP.App/commit/44b07d186b977534b54d2d2f2ffcec5fe87354fe) hardened tournament refund retries using a shared refund proof helper. The new booking refund fix reuses that helper instead of duplicating it.

## Verification

- [Financial CI run 44109650071 — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44109650071) at `e25c26ed`: offline Deno refund proof/source guards and focused Flutter finance jobs.
- [Financial CI run 44110257615 — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44110257615) at `9129d652`: offline Deno HMAC/refund proof/sanitizer and focused Flutter finance jobs.
- [Task counter CI run 44110274887 — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44110274887) at `9129d652`.
- Read-only inspection of Staging `vsp_notifications_private.notify_verified_paymob_payment` verified that its existing receipt trigger reads `payload.success`, `payload.pending`, `payload.amount_cents`, plus separate `order_id`, transaction and signature status. The sanitized record **retains all those fields**, so the inspected receipt predicate remains structurally compatible. A full live receipt integration test was **not** conducted.
- No actual payment, network interruption, concurrent gateway refund, device switching, user-account JWT attempt, production deployment, or historical data scrub was performed. Financial CI is not a real provider certification.

## Release blockers / further review

1. Validate Paymob Sandbox actual refund outcomes and parallel requests in an isolated test environment; compare with the claim/lease and durable dispatch marker; inspect long-lived manual reconciliation behavior.
2. Review retention, access and redaction of **historical** `webhook_logs.payload`; this code patch does not remove existing data or change production records.
3. Verify strict audit-reader compatibility (admin, analytics, reconciliation views), including legacy merchant-order reference reads, outside the inspected Staging receipt function.
4. Check full Flutter, Android/iOS build/E2E and role-based negative tests on the final SHA separately; do not infer completion from the focused payment suite.
5. Deployment to Staging, production rollout and credential rotation require separate authorization. Supabase Storage advisories `85.01–85.03` remain **Needs Verification**.

## Task count (no duplicate IDs)

These changes belong to existing `30.02–30.08`, `30.06` audit data, `31.*` refund safety, `63.*` Paymob identity, `SEC-03` personal-data minimization, `SEC-06` payments and `SEC-10` secrets. Broad acceptance requires external/negative tests and deployed checks; no existing task was closed solely by source CI.

| Metric | Number |
| --- | ---: |
| Unique tasks | 633 |
| Accepted before batch | 266 |
| Newly accepted | **0** |
| Newly added unique IDs | **0** |
| Remaining | **367** |
| Source behavior categories repaired in this batch | **3** (ID-only refund proof, provider diagnostics, signed audit PII minimization/accounting logs) |
| Production-deployed and verified fixes in this batch | **0** |

No changes to venue subscription business model or booking commission.
