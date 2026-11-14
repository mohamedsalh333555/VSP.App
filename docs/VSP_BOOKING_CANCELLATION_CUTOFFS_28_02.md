# 28.02 — Cancellation rules, cutoff windows and authority

## Observed application contract

Source: `lib/core/repositories/booking/booking_cancellation_coordinator.dart`, `lib/core/repositories/booking/booking_domain_rules.dart`, and the booking state contract in `VSP_BOOKING_TRANSITIONS_27_02.md`.

The cancellation UI maps backend errors `cannot_cancel_within_6_hours` and historical `cannot_cancel_within_2_hours` to the **currently displayed** policy: cancellation is disallowed when the match begins in fewer than **6 hours**, **except within the first 20 minutes after the booking was created**. The historical two-hour code is a compatibility/error mapping, not proof that two hours is still the server policy.

**Critical limitation:** the actual server-side SQL/Edge Function cutoff implementation was not independently inspected for this document. Therefore 6 hours and 20 minutes are the client-visible policy; they are not certified server behavior. The server must determine the deadline from trusted server time and booking creation/start timestamps. No client clock should authorize cancellation.

## Cancellation paths

1. The caller must provide a booking record and matching nonempty booking ID; mismatch is rejected before any RPC.
2. Owner-created manual bookings (transaction ID contains `MANUAL`) use `owner_cancel_manual_booking_atomic` with `p_refund_deposit: false`.
3. Paid online bookings use the `process_paymob_refund` Edge Function. A response with `refund_pending` may be treated as cancellation success only after the client re-reads the persisted booking status and finds `cancelled`.
4. If the refund function cannot be invoked, the coordinator may fall back to `cancel_booking_with_refund_atomic`; unsuccessful responses are rejected.
5. Unpaid/non-online bookings use `cancel_booking_with_refund_atomic` directly.
6. Only after successful cancellation does the client attempt participant and owner notifications. Notification failures are logged separately and do not reverse a successful cancellation.

## Terminal states and repeated requests

A completed booking cannot be cancelled; a previously cancelled booking should return an idempotent, non-destructive outcome, rather than charging or refunding again. `completed`, `noShow`, `cancelled`, and `expired` are terminal states in the client transition contract. Server authorization and atomic status updates are required for actual enforcement.

## Deadline boundary acceptance criteria (28.08)

At exactly the six-hour threshold, test both sides and the equality instant against server time. At exactly 20 minutes after creation, test both sides and equality, including daylight saving/timezone conversion and stale client clocks. The policy's inclusive/exclusive comparison operators must be confirmed from server implementation before marking 28.03 or 28.08 complete. A refunded transaction must never be refunded twice.

## Follow-on tasks

- **28.03** confirm and enforce cutoff policy on server.
- **28.04** verify freed slot visibility after server cancellation.
- **28.05** verify notifications and retries.
- **28.06–28.08** verify permissions, full lifecycle and deadline boundaries.
- **31.xx** refund idempotency and reconciliation.

**28.02 deliverable:** documented cancellation entry points, currently displayed cutoff, backend authority, legacy error compatibility, and explicit boundary acceptance tests. No claim that server policy was modified.
