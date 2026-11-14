# VSP — Booking, discovery and owner KPI acceptance contract

Status: product/engineering decisions for 14.01, 14.02, 24.01 and 26.01. This is **not** evidence of deployed filters, reports, atomic locking or successful tests. Any mismatch with existing code/schema must be reconciled before implementation; do not migrate production implicitly.

## 14.01 — Venue discovery filter contract

Player-facing venue search supports: governorate (all 27, with Aswan as a staging fixture), city/district where known, 5-a-side/7-a-side venue type, date, requested start time and duration, price band in EGP, and available services (e.g. lighting/parking when provided by venue).

- Default to **published, approved, bookable** venues only; omit suspended/unpublished entries, including direct-link attempts.
- Unknown price/service/location is **unknown**, never silently treated as matching a positive filter.
- Date/time availability is server-derived; filter results cannot promise an unreserved slot without final atomic booking validation.
- Price filters use the effective slot price inclusive of mandatory fees; show the same amount at checkout or require explicit reconfirmation.
- Combine active filters with AND; multiple selected services use AND; provide clear-all, empty-state and paginated results.
- Persist filter state on back navigation, not across accounts. Arabic RTL labels and screen-reader labels are required.

## 14.02 — Pickup/open match discovery filter contract

Match search supports governorate/city, date/time window, 5v5/7v7, open slots, eligibility (age/skill only if configured), participation fee in EGP, and match type (pickup, team challenge, open league where applicable).

- Show only matches the viewer is authorized to discover; private/invite-only matches must never leak participant lists.
- Exclude cancelled/completed/expired or full matches from the **joinable** filter, while keeping historical matches visible in the proper history view.
- A join button must recheck eligibility, capacity, payment state and duplicate participation on the server.
- Distinguish **match participation** from **venue booking**; joining a match does not automatically authorize venue payment.
- Support pagination, empty/error/loading and network retry; sort deterministically by start time then ID.

## 24.01 — Owner dashboard KPI definitions

All metrics must be scoped server-side to the authenticated owner's authorized venue IDs, with selected timezone `Africa/Cairo` and a user-visible date interval `[start, end)`. No cross-owner aggregates or client-only permission checks.

| KPI | Definition | Notes |
|---|---|---|
| Confirmed bookings | Distinct booking IDs whose authoritative status is confirmed and slot start falls in interval | Exclude cancelled/rejected; do not count retries twice |
| Completed bookings | Distinct completed booking IDs with slot start in interval | Keep separate from confirmed |
| Gross booking value | Sum of authoritative booking slot prices for eligible confirmed/completed bookings | EGP; not VSP commission |
| Collected venue payments | Sum of reconciled successful venue payment transactions | Separate from gross value; refund/chargeback separately |
| Refunds | Sum of verified refunded amounts | Avoid double counting partial refunds |
| Occupancy | Reserved bookable minutes / total bookable minutes for selected venues and interval | Exclude closures and unavailable inventory from denominator |
| Cancellation rate | Cancelled booking IDs / (confirmed + cancelled booking IDs) for same cohort | Show N/A for zero denominator |
| Upcoming bookings | Future confirmed booking IDs as of request time | Time-sensitive and not a period revenue measure |
| Subscription status | Authoritative free/paid/expired/grace entitlement and next renewal date | Owner subscription, **no per-booking platform commission** |

- Explicitly label booking value versus money collected; refunds, chargebacks, pending payments and reconciliation states cannot be silently merged.
- Use server-side source of truth; avoid relying on duplicate legacy payment fields without an agreed precedence rule.
- For owners of multiple venues provide per-venue and aggregated views without double counting; include last-updated timestamp and empty-data behavior.

## 26.01 — Booking collision rule

Two active reservations conflict if and only if they address the **same independently bookable physical unit** and their half-open time intervals overlap: `existing.start < proposed.end && proposed.start < existing.end`.

- Store and compare timestamps as instants (UTC), display in `Africa/Cairo`; require `start < end`. Adjacent intervals `[10:00,11:00)` and `[11:00,12:00)` do **not** conflict.
- Treat pending holds as blocking only while an explicit server-defined hold TTL is valid. Confirmed/paid reservations block. Cancelled, rejected and expired holds do not block; refunds do not automatically free an occupied slot.
- One physical unit cannot be double-booked through separate 5v5/7v7 listings. Define parent/child resource mapping before enforcing uniqueness.
- A closure blocks the same interval even without a booking. Owner manual reservations must use the same collision path.
- Check conflicts **inside the server-side atomic transaction** that creates/confirms the booking; a client availability query is advisory only.
- Use idempotency keys for retries; concurrent requests for the same resource/interval result in at most one accepted booking. Prevent duplicate payment authorization.
- Cross-midnight slots, DST/timezone offsets, edits, reschedules and simultaneous cancellation/new booking must follow the same rule.
- Do not implement a production DB constraint until existing booking state transitions and schema are inspected, a staging migration is tested, and rollback/backup are approved.

## Implementation and verification gates

- Filters: verify exact AND semantics, pagination, private venue/match denial, no-result state, price consistency, and 27-governorate handling.
- KPI: compare dashboard to authoritative SQL aggregates for two owners, two venues and a period with cancellations, refunds and expired subscription.
- Collision: test exact overlap, nested overlap, adjacent intervals, cross-midnight, separate units, shared physical unit, expired hold, closure, 20 parallel requests and replayed idempotency keys.
- Do not mark 14.03–14.08, 24.02–24.06 or 26.02–26.08 complete until staging/Android evidence exists.
