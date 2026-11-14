# 26.07 — Evidence of booking overlap prevention

## Source-grounded control chain

1. The player confirmation handler (`lib/features/player/widgets/booking/booking_confirmation_handler.dart`) performs an optimistic availability recheck. This improves UX but **is not an authoritative lock**.
2. `BookingCreationCoordinator.createBooking` (`lib/core/repositories/booking/booking_creation_coordinator.dart`) validates draft times, finite nonnegative amounts, player capacity and identity before calling the atomic RPC. It forwards `p_idempotency_key` for both standard and challenge bookings; the confirmation handler creates a UUID for each draft. The server remains responsible for conflict enforcement.
3. The current checked-in SQL definition for `create_booking_atomic` is `supabase/migrations/20261106010000_recheck_booking_idempotency_after_lock.sql`. It acquires `pg_advisory_xact_lock(hashtextextended(p_stadium_id,0))` for the venue, then rechecks idempotency with user, venue and time matching **inside** the lock. This is transaction-scoped and serializes concurrent requests for the same stadium.
4. The SQL overlap predicate is `p_start_time < end_time AND p_end_time > start_time`. These strict inequalities allow adjacent half-open intervals ([start, end)) without counting them as overlaps. The query excludes cancellation and handles expired pending locks. When an active overlap exists, the RPC returns `SLOT_LOCKED_OR_TAKEN`.
5. The client translates `SLOT_LOCKED_OR_TAKEN`, PostgreSQL exclusion code `23P01`, unique violation `23505`, and other known overlap failures into a user-facing unavailable-slot error.
6. `supabase/migrations/20260824_atomic_slot_locking_5min.sql` documents an older advisory-lock design; later migrations supersede it. `20260925233606_booking_authority_and_concurrency_hardening.sql` is explicitly a **source-only marker** whose function body raises `SOURCE_ONLY_MIGRATION_MARKER`; it must not be executed against production as an authoritative function implementation.

## Proof boundaries

This document proves **the existence and intended behavior of the checked-in client and SQL source controls**, not their deployment status or runtime success. We have **not** run concurrent booking attempts against staging/production, checked current deployed function definitions, checked the exclusion constraint in the live database, or verified all other booking mutation RPCs use compatible locks. Therefore tasks 26.02, 26.03, 26.05, 26.06 and 26.08 remain open.

## Acceptance matrix for later verification

| Scenario | Expected result |
|---|---|
| Two different players, same stadium and overlapping times | Exactly one active booking succeeds; other receives conflict |
| Same authenticated user retries same key and same slot concurrently | Returns same booking ID, never creates a second booking |
| Same key with different user, stadium or times | Must not expose or reuse another booking |
| Adjacent slots (one ends exactly when next begins) | Both may succeed if operating hours permit |
| Two different stadium IDs at same time | Both may succeed independently |
| Cancelled booking and new reservation | New reservation succeeds only after cancellation commits and lock is released |
| Expired pending booking | Must not indefinitely block a new booking |
| UTC conversion, DST boundaries and local operational date | No accidental overlap or wrong-day booking |
| Manual owner, challenge and reschedule paths | Must follow the same invariant, not just player creation |

**26.07 documentation deliverable completed:** precise source evidence, overlap predicate, concurrency lock, idempotency scope, failure mapping, migration caveat and unverified scenarios.
