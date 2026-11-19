# 31.01 — Refund eligibility, cutoff and gateway handling rules

Source reviewed: `supabase/functions/process_paymob_refund/index.ts` and `lib/core/repositories/booking/booking_cancellation_coordinator.dart`.

## Eligibility and authority

- Caller must have a valid bearer token and must be the booking player/creator, the stadium owner, or an authorized administrator. Unauthorized cancellation is rejected.
- A player cannot cancel a completed booking.
- For player cancellations, the gateway function refuses cancellation when the match starts **at or before six hours from server time**, unless the booking was created **within the last 20 minutes**, inclusive of the 20-minute boundary. Owners/admins may have different authorization/policy constraints in other RPCs; do not generalize this exception.
- Cash bookings go through `cancel_booking_with_refund_atomic`; they do not call the Paymob refund endpoint.
- A previously cancelled booking is idempotently acknowledged unless its electronic refund remains `refund_pending`, in which case the controlled refund processor may continue it.

## Electronic refund workflow

1. The server calls `claim_booking_gateway_refund_atomic` before contacting Paymob. The claim RPC owns row locking and refund lease; the client must not bypass it.
2. `already_refunded` returns success without another gateway refund.
3. `refund_in_progress` returns `refund_pending` without resubmitting.
4. Multiple Paymob payments require **manual financial review** instead of automatic refund.
5. Missing refundable Paymob transaction moves the booking into cancelled/refund-pending state for manual review; cancellation is not proof that money has returned.
6. Invalid gateway transaction or refund amounts are rejected.
7. Paymob authentication failure and other uncertain gateway outcomes remain pending for reconciliation; never blindly dispatch a second refund.
8. A confirmed refund and its notification are separate operations. Notification insertion failure must not reverse or misreport a confirmed financial refund.

## State semantics

`cancelled` describes booking availability; `refund_pending` describes unresolved money movement; `already_refunded` means a confirmed prior refund. These are distinct dimensions and must not be collapsed into one boolean.

## Remaining acceptance

31.02–31.08 require inspection/verification of the live claim/queue implementation, refund transaction uniqueness, retry lease expiry, notifications, gateway settlement, failure reprocessing and double-refund concurrent tests. This document defines the checked-in rules only, **not proof of live deployment**.
