# VSP — Exact booking price and final Paymob amount disclosure

**Date:** 17 November 2026. **Branch:** `uxlp-44-implementation`. **Tested code SHA:** [c41b1d1](https://github.com/mohamedsalh333555/VSP.App/commit/c41b1d1f2661de862d6dc1b4b977bc69d0b96822). **Financial regression workflow:** [SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44185016978), including Flutter Analyze, exact-cent fee and booking widget tests, existing receipt/finance tests, and isolated HMAC/Paymob-negative tests.

## Source fix: 0.1 EGP display rounding was unsafe

The `PaymentBreakdownCard` fee row and payment total, and the Arabic/English `PaymentSecurityFooter` checkout CTA, formerly applied `toStringAsFixed(1)`. For example, a legitimate 100.00 EGP base plus 7.75 EGP fees **could be displayed as 107.8 EGP instead of the calculated 107.75 EGP**. The booking totals and fee computation use cents.

Both surfaces now render the **same already-available** `VSPMoneyFormatter.amount(...)` that preserves two-decimal EGP precision (without gratuitous trailing zeros). The source does **not** change payment fee rates, payment intent amount, fee-config table, payment routing, settlement or Paymob API calls.

## 53.02 — Price shown clearly (narrow acceptance)

- Widget tests `booking_price_clarity_widget_test.dart` verify selected booking total **107.75** in English and Arabic, optional ball fee, displayed upfront deposit, and no stale total when the selected time slot is cleared.
- Source guards assert that base slot calculation adds ball rental **once** and that the quote is validated against the latest venue row before payment-method routing; real server RPC remains authoritative.
- This accepts *price disclosure on the inspected Flutter booking view*. It does **not** prove all live venues have valid price configuration or all booking journeys across devices.

## 53.07 — Total including fees before final checkout (narrow acceptance)

- Runtime UI uses the server-fetched `PaymobFeePolicy` for fee and total, not the deprecated hard-coded legacy fee helpers. When the fee policy is missing/unverified, the final total is marked unavailable and the checkout CTA is disabled.
- `payment_fee_cent_precision_test.dart` validates a runtime policy with 100.00 base + 2.00 platform + 5.75 gateway = **107.75 EGP**, then asserts the Arabic and English checkout buttons show the exact cents. Additional source tests cover total/fee rows and the shared `totalWithFees` passed to the amount header and payment CTA.
- This accepts **pre-Paymob Flutter display and fail-closed policy gating only**, not provider-supplied final checkout equality, live provider authorization/settlement, fee-policy audit, or transaction verification. Financial and security release tasks remain open until Sandbox and staging verification.

## Accounting and deployment

Two pre-existing open IDs **53.02 and 53.07** are narrowly accepted, **0 new unique IDs**. Baseline after previous batch **633 total / 283 accepted / 350 open**; revised **633 / 285 accepted / 348 open (45.02%)**.

No schema or database mutation, Paymob transaction, payment webhook, production config, APK, or `main` merge. Full Flutter/Android and hosted payment verification remain separate release blockers.
