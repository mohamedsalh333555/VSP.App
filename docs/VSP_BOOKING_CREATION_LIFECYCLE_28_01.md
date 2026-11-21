# 28.01 — Booking creation lifecycle

This document records the booking creation lifecycle contract visible in the Dart domain model. It is not a claim that production server transactions, payment webhooks, or notifications have been verified.

## Inputs and draft

The booking draft is modeled in `lib/data/models/booking_draft.dart`. The persisted booking model is `Booking` in `lib/data/models/booking_models.dart`. Required persisted identity and timing fields include booking ID, stadium ID, owner ID, creator ID, start/end timestamps, and creation timestamp. Booking type distinguishes personal, open join, challenge, team alias, matchup, and maintenance.

## State lifecycle

1. **Select venue, date and time.** Client availability selection is provisional and must not guarantee server-side availability.
2. **Prepare draft and pricing.** The server must independently validate slot, venue, authorized actor, price, and overlapping reservations; client totals are informational.
3. **Create reservation.** A new booking starts in `pending` where confirmation/payment is outstanding. Any server-specific direct confirmation must be documented before release.
4. **Confirm.** Valid successful confirmation moves `pending -> confirmed`; `upcoming` is a client alias serialized as `confirmed`.
5. **Fulfill.** A confirmed booking may move to `completed` or `noShow` after the scheduled event and applicable attendance policy.
6. **Exit before fulfillment.** A pending booking may become `cancelled` or `expired`; a confirmed booking may become `cancelled` only when its cancellation policy and actor permissions permit.
7. **Terminal states.** `completed`, `noShow`, `cancelled`, and `expired` cannot be reopened by a generic state transition. Rebooking is a new reservation, not a mutation of a terminal booking.

The permitted state graph is defined in [27.02](VSP_BOOKING_TRANSITIONS_27_02.md). Payment status and match result status are separate axes; a status change is not proof of payment.

## Data validation and error cases

`BookingMapper.fromFirestore` rejects missing `start_time` or `end_time` and time ranges where end is not after start. The mapping normalizes `upcoming` to `confirmed`, and reads historical booking types. Failed creation must not appear as a confirmed booking. Duplicate client submissions require a server idempotency mechanism, tracked separately.

## Follow-on acceptance tasks

- **28.02:** record actual cancellation cutoffs and policy source, not assumed times.
- **28.03–28.06:** implement and verify cancellation authorization, availability refresh, notifications, and permissions.
- **26.02–26.08:** atomic server overlap protection and concurrency tests.
- **27.03–27.08:** server-enforced transitions, audit history, retry and race tests.
- **29–31:** payment reconciliation, failure handling and refunds.

**28.01 deliverable:** a complete lifecycle definition tied to the existing domain model and status contract, without inventing server guarantees. This closes the documentation subtask only.
