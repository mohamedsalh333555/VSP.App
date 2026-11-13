# VSP — operating-hours source, exception audit and maintenance guard reproduction

Date: 2026-11-13 UTC. **Read-only staging** `vtwgqyxglevcsxwdmhop`. Issue #37 point 6. No player/owner identities or booking rows read. No bookings created or updated, no SQL migrations applied.

## 66.02 — Source precedence by active consumer

- **Flutter picker**: `lib/features/player/widgets/booking/booking_slot_calculator.dart` reads `stadium.features['workingHours']` first, then `stadium.openingTime/closingTime`. If both absent, it currently falls back to a **default 4:00 PM–3:00 AM**; this is a potential unconfigured-hours UX risk that must not be presented as a backend guarantee. Flutter uses `features['breakTimes']` or the legacy `features['breakTime']` for break exclusions.
- **Database**: an enabled booking trigger `trg_bookings_operating_window` calls `public.vsp_enforce_booking_operating_window()`. It loads `stadiums.opening_time`, `closing_time`, `break_start_time`, `break_end_time`, `is_split_shift`, `maintenance_until` and delegates to `vsp_validate_stadium_booking_window(...)`; it does **not** consult `court_operating_hours` or Flutter `features.workingHours` for authoritative booking writes.
- `public.court_operating_hours` exists and references `stadiums(id)`, but has **0 records** in staging and is not used by the inspected guard function.

## 66.03 — Exception and real data inspection

Aggregate staging facts: **17 stadiums**, none missing `opening_time`/`closing_time`; **1** JSON `features.workingHours` override with the **same normalized HH:MM values** as the respective base columns; **0** JSON break overrides; **0** base-column breaks; **0** split shifts; **0** stadiums with non-null `maintenance_until`. Therefore the following edge-case flaw is not shown to affect an existing staging stadium, and the screenshot root cause is **unproven**.

The server validator computes local timestamps using `timezone('Africa/Cairo', ...)` and handles overnight windows and split-shift breaks. **Its current maintenance clause is**:

`IF p_maintenance_until IS NOT NULL AND p_end_time > p_maintenance_until THEN RETURN FALSE;`

That check rejects bookings **after** maintenance ends instead of ensuring the booking cannot overlap an active maintenance interval. It can also allow a booking **before** the future maintenance end, depending on other conditions.

## 66.04 — Deterministic read-only reproduction

Using literal test times only (not stored stadium or customer data), execute:

```sql
SELECT
  public.vsp_validate_stadium_booking_window(
    '16:00', '23:00', NULL, NULL, false, NULL,
    '2026-11-15 18:00:00+00', '2026-11-15 18:30:00+00'
  ) AS no_maintenance_valid,
  public.vsp_validate_stadium_booking_window(
    '16:00', '23:00', NULL, NULL, false, '2026-11-01 00:00:00+00',
    '2026-11-15 18:00:00+00', '2026-11-15 18:30:00+00'
  ) AS expired_maintenance_valid,
  public.vsp_validate_stadium_booking_window(
    '16:00', '23:00', NULL, NULL, false, '2026-11-15 19:00:00+00',
    '2026-11-15 18:00:00+00', '2026-11-15 18:30:00+00'
  ) AS before_maintenance_end_valid;
```

Observed staging result: `true / false / true`. The same in-hours booking is rejected when only a **past** maintenance-until marker is supplied. A slot ending **before** a future maintenance-until marker can be accepted. This **reproduces a guard-logic defect**, not an actual charged booking or exploitation.

## 66.05–66.06 — Source-of-truth decision and safe fix requirement

**Decision:** the server-side booking operating-hours trigger is the authoritative safety gate, not Flutter-derived availability or `court_operating_hours` until explicitly integrated. Preserve this rule, but do **not** treat its present maintenance predicate as valid; its semantics are defective for non-null `maintenance_until`. The client schedule and server guard must be reconciled before claiming that configured breaks, overrides or closures are consistently protected.

Before a proposed repair:
1. Define intended semantics of `maintenance_until` (start of closure, beginning of maintenance, or end of temporary closure) and check existing closure RPCs/owner flows; do not guess or rewrite financial rules.
2. Build SQL regression tests for active/past maintenance, overnight/daylight-saving crossings, breaks and direct forged booking attempts; test on isolated staging fixtures and plan rollback.
3. Review all stored function and trigger consumers, then prepare a reviewed migration; **do not apply to production** or merge `main` without approval.
4. Retest with real staging stadium data and role-isolated booking attempts. `66.07` cross-unit conflict test and runtime remediation remain OPEN.

Acceptance here covers **66.02–66.06** as audit, deterministic function testing and documented safe source-of-truth decision **only**. It does **not** fix the discovered guard logic, close the P1 booking risk, or certify real booking eligibility.
