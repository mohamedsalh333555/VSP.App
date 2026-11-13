# VSP — booking maintenance-until guard: proposed code repair (NOT DEPLOYED)

Date: 2026-11-13. Development branch `uxlp-44-implementation`. Scope: Issue #37 point 6 / operating-hours server guard.

## Confirmed behavior and defect

Read-only staging catalog inspection shows `request_emergency_stadium_closure(...)` assigns `stadiums.maintenance_until = now() + p_duration_hours` and immediately updates the stadium. The field therefore marks the **end** of an emergency closure beginning at request time. `create_championship_atomic` already treats maintenance as active only while `maintenance_until > now()`.

The previously deployed `vsp_validate_stadium_booking_window` used `p_end_time > p_maintenance_until`. Read-only staging reproduction in [operating-hours reproduction](VSP_STAGING_OPERATING_HOURS_GUARD_REPRO_2026-11-13.md) returned `true / false / true` for no marker / expired marker / future marker respectively. This demonstrates inverted maintenance logic under supplied inputs; no actual booking impact was proven because 0 of 17 staging stadiums had a non-null marker.

## Branch-only implementation

- Migration: [20261113143000_fix_expired_stadium_maintenance_booking_guard.sql](../../supabase/migrations/20261113143000_fix_expired_stadium_maintenance_booking_guard.sql). It now rejects when a closure is still active (`p_maintenance_until > now()`) and a booking begins before the closure ends (`p_start_time < p_maintenance_until`).
- The validator's volatility is now `STABLE`, because it calls `now()`; keeping `IMMUTABLE` would misrepresent behavior. `security invoker` and `search_path = public, pg_temp` remain explicit.
- Null/invalid booking endpoints now fail closed. Cairo operating-hours and split-shift logic are copied from the existing function without changing their decisions. Both `create_booking_atomic` and the booking trigger call the same validator; their definitions, financial logic and grants are not changed.
- Post-migration read-only SQL contract: [booking_operating_maintenance_guard_contract.sql](../../supabase/tests/booking_operating_maintenance_guard_contract.sql) — eleven scenarios including expired/active closure, exact end boundary, partial overlap, ordinary slot, split break, overnight, out-of-hours, zero-length and null start.
- Flutter architecture guard: [booking_maintenance_window_guard_contract_test.dart](../../test/architecture/booking_maintenance_window_guard_contract_test.dart) — checks the patch and fixture paths/contract content. This **does not** substitute for database execution.

## Acceptance / release gate

**NOT APPLIED to staging or production, NOT runtime-verified, NOT accepted as a completed task.** No affected bookings, stadiums, users or payment records modified. Existing accepted baseline remains **116 / 618**, with **502 open**, pending separate acceptance.

Before deploying: review exact PostgreSQL function dependencies and grants, migration history and rollback plan; apply only in an isolated test database with a clean migration history, then execute the SQL contract and isolated role-based booking insert/update tests (including a real closure RPC flow). Re-run booking/cancellation/payment regression, CI and Android E2E. Determine whether Flutter `features.workingHours`, backend stadium columns and `court_operating_hours` need an explicit harmonization change; do not conflate the sources. Item 66.07 remains open.

## Reversal

Prefer full transactional migration testing: on failure **ROLLBACK the entire isolated transaction** rather than leaving a half-applied function. If already applied and a production issue occurs, use the previously captured `pg_get_functiondef` plus reviewed change management to restore the previous function definition, with explicit acknowledgement that it reintroduces the original maintenance predicate defect. Do not silently restore the unsafe predicate or run an automatic destructive rollback. No changes to `main`, Supabase staging/production or release-ready status.
