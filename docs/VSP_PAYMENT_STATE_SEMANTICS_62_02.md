# 62.02 — Booking payment-state semantics and precedence

**Evidence:** `supabase/migrations/20261001230000_booking_payment_ssot_state_machine_and_matrix.sql` (`sync_payment_reconcile_state`) and `lib/data/models/booking_models.dart` (`effectivePaymentState`). This defines existing checked-in behavior; it does not change payment state or declare the deployed database verified.

| Representation | Meaning | Limitations |
|---|---|---|
| `is_paid` (bool) | Historical yes/no full-payment indicator | Cannot represent partial payment, refunds or pending reconciliation |
| `payment_status` (text) | Payment lifecycle status, including `paid`, `fully_paid`, `partially_paid`, `refund_pending`, `refunded`, `refund_failed` | May be legacy or conflict with boolean |
| `payment_reconcile_state` (text) | Server-derived reconciliation state: `unpaid`, `partially_paid`, `fully_paid`, `refund_pending`, `refunded`, `refund_failed` | Must not be treated as gateway settlement proof without verified server write |

## Current server precedence

1. Explicit `payment_status` refund outcomes take precedence and set the corresponding reconciliation state.
2. An existing reconciliation refund outcome is preserved.
3. `is_paid=true`, `payment_status=paid/fully_paid` or prior `fully_paid` reconciliation produces `fully_paid`.
4. Partial deposit or explicit partial state produces `partially_paid`.
5. Otherwise `unpaid`.

The trigger additionally validates combinations of booking status and payment reconciliation state; a confirmed online booking cannot be unpaid. Cash bookings may be confirmed before collection. This is a **booking/payment matrix**, not permission for the client to mark a charge successful.

## Current client read precedence

`Booking.effectivePaymentState` prefers nonempty `paymentReconcileState`; otherwise it derives a fallback from refund `paymentStatus`, `isPaid`, `paymentStatus`, and deposit amounts. The client should render the server reconciliation state, not independently mutate a financial ledger.

## Explicit unresolved conflict

If historical `is_paid=true` conflicts with a `refund_pending` or `refunded` state, the refund status wins in the SQL trigger. If legacy `payment_status=paid` conflicts with a lower-level state, further server reconciliation and live-data audit are required. Tasks 62.03–62.07 remain open; no data cleanup or payment migration is implied.
