# VSP — Required deposit quote preflight safety

**Date:** 2026-11-17. **Branch:** `uxlp-44-implementation`. **Code-only defensive fix, not a finished payment-security task.**

## Source change

`BookingPriceSnapshotGuard.matches` now calls a pure `isValidDepositQuote` check for the **latest server-provided venue quote**, after reconstructing the cost of the selected half-hour slots and optional ball.

- Reject non-finite or non-positive total amounts, negative/non-finite configured deposits, and required deposits of zero.
- Reject a required deposit exceeding the selected total. Tiny floating-point reconstruction error of up to one millionth of an EGP is tolerated, **not** a one-piaster mismatch.
- Do not reject nonzero optional deposit metadata when deposits are not required, provided it is finite and nonnegative; the field is not then charged.
- This preflight only improves the client refusal of inconsistent venue quotes. The booking RPC is the final price and authorization authority. No payment provider request was sent, and no hosted venue data was changed.

## Regression

`test/features/booking/booking_required_deposit_quote_guard_test.dart` covers valid partial/full deposit, over-collection, required-zero, invalid or negative totals, NaN/infinity and precision boundaries, and source integration in `BookingConfirmationHandler.run`.

`.github/workflows/financial-payment-regressions.yml` invokes this new test and Flutter Analyze alongside the existing financial and HMAC regressions. **Focused CI SUCCESS:** [Financial payment regressions run 44185646898](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44185646898) on code SHA [1729e778](https://github.com/mohamedsalh333555/VSP.App/commit/1729e7786b53a0e25bdd8a6be375b3be024232ea), with Flutter Analyze, the deposit/price/fee widget regression tests and the Paymob HMAC-negative suite. This is **source-level verification only**, not a real checkout or staging test.

## Outstanding safety constraints

- Real staging venue and booked-price verification, role/JWT authorization, cross-venue invalidity, Paymob amount binding, refund reconciliation and sandbox/production deployment are distinct work items.
- This adds **0 newly accepted task IDs** and **0 new unique IDs**. Latest authoritative checklist after the previous price-disclosure batch remains **633 / 285 accepted / 348 open**.
- No `main` merge, APK, production migration, payment, or database mutation.
