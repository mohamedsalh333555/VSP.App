# VSP — narrowly scoped client checks accepted after automated CI

**Date:** 2026-11-13. **Scope:** 21.04, 25.04, 25.06, 29.02 **client experience and parsing only**. All release/security/payment end-to-end gates stay open until verified with isolated real roles and authoritative server enforcement.

## Verification basis

- [Flutter CI run 43501718030](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43501718030) for commit `772d32232f2f2b9c1f1778126fdf1a4567ba10d0`: **1288 Flutter tests passed, 11 skipped**, analyzer, privacy/deletion checks, architecture regression, and Cairo DST/calendar guards successful.
- [Account SQL CI 43501717921](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43501717921) passed synthetic local PostgreSQL guards; [Owner checkout security 43501717922](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43501717922) passed. iOS compliance build on the same commit passed; Android smoke was not completed at the time of this acceptance note.
- The stricter owner time formatter and payment-screen source-contract tests added in the **same ledger acceptance commit as this document** require a *new* Flutter CI pass and are **not yet counted as passed** on run 43501718030. The four tasks below are accepted based on existing tested implementation at the previous commit, independent of those new additions.

## Per-task acceptance boundary

| Task | Implemented and verified scope | Explicit remaining work |
|---|---|---|
| **21.04 — currency and input validation** | The stadium creation wizard validates finite nonnegative hourly price and positive bounded deposits; `StadiumPayloadBuilder` checks EGP-only `currency` input and parses/validates finite nonnegative hourly, base and deposit amounts in create and update payloads, with dedicated unit tests. | Direct PostgREST writes are independent of Flutter and may still bypass checks; pricing-policy tampering and server rate reconciliation under **21.07** are open. This is client-boundary acceptance, not a guaranteed server-price integrity review. |
| **25.04 — expiry states** | Owner subscription plans UI distinguishes **expired Pro trial** from **expired paid Pro**, shows localized Arabic/English notices and leaves free-plan CTA access. Isolated tests verify past/future expiration, active trial override, free owner/player role, and localized copy. | No server subscription downgrade, payment renewal, grandfathering or live authorization was accepted. Issues #42, tasks **25.03, 25.05, 25.07, 25.08** remain open. |
| **25.06 — prevent bypass from client** | Owner `StadiumRepository.addStadium` requires an authoritative `check_owner_stadium_limit` RPC before insert and fails closed on malformed/denied/offline result; two dedicated tests exercise guard logic and mock-HTTP integration. | **Server bypass remains possible via direct Data API** until an atomic authoritative write-time guard is deployed/verified. [Issue #41](https://github.com/mohamedsalh333555/VSP.App/issues/41) remains release-blocking, **25.03 OPEN**. |
| **29.02 — show payment failure** | Payment failure classifier produces safe Arabic/English messages for cancellation, timeout/network uncertainty, decline, authentication, duplicate, invalid request, provider down and unknown. PaymentGatewayScreen calls these messages on initialization failure, webview error and uncertain states, and keeps result unresolved pending server verification. | The refund/charge state and real Paymob sandbox are not proven. Retry/idempotency and sandbox tasks **29.03–29.08**, **30.02–30.08** remain open. |

## Security and release caveats

- Do **not** infer a subscription per-booking commission. Venue monetization remains subscription-based.
- [Issue #43](https://github.com/mohamedsalh333555/VSP.App/issues/43) found that staging stadium owners can potentially self-approve/moderate or forge ratings via direct REST: staging table grants and RLS have no field-level guard. An isolated source-controlled trigger candidate exists and passed PostgreSQL synthetic tests; **not deployed**.
- [Issue #42](https://github.com/mohamedsalh333555/VSP.App/issues/42) covers a historic one-year trial default inconsistent with advertised seven days; no existing owner entitlements were changed.
- **No main merge, production/staging mutations, subscription price changes, real charges, or destructive customer-data tests** occurred in this acceptance.
