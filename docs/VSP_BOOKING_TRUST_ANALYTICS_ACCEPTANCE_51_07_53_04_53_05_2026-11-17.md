# VSP — Booking trust and offline analytics interruption acceptance

**Date:** 2026-11-17. **Branch:** `uxlp-44-implementation`. **Evidence code SHA:** [295b109](https://github.com/mohamedsalh333555/VSP.App/commit/295b1095626e11fc5cbaa49e5be29c214c8e58b8). **Focused CI:** [SUCCESS — Flutter source analyze, booking/analytics regression tests and offline Node dashboard](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44183845285).

## Three existing checklist IDs accepted within their tested scope

### 51.07 — Network outage impact on counting a confirmed booking

- `test/core/services/booking_completion_network_analytics_test.dart` models an unsuccessful analytics transport, a pending concurrent delivery, an exception/retry, and a successfully delivered event. Only a confirmed booking may trigger `booking_completed`; unsent events can retry, and the event is counted once within the same in-process session.
- The pre-payment booking selection/confirmation screen and the handler **do not** emit `booking_completed`. The receipt emits only when the actual booking lifecycle state is confirmed via `BookingStatusPresentation.isConfirmed`. The analytics send is non-blocking relative to the successful booking route.
- **Acceptance:** deterministic offline/network-error simulation and placement regression. **Not proof:** actual airplane-mode Android/iOS tests, Firebase Analytics delivery after process termination, cross-device deduplication or live counts. Firebase transport errors are treated as auxiliary failures, never booking failure.

### 53.04 — Confirmation state clearly shown

- `BookingStatusPresentation` maps pending, cancelled, expired, no-show, confirmed/upcoming and completed states to explicit Arabic/English headings. A pending booking does not say it is confirmed. `booking_success_screen.dart` now applies the real `confirmationColor` to the status text, avoiding the positive visual accent for pending/cancelled state.
- `test/features/booking/booking_confirmation_status_contract_test.dart` validates the lifecycle state map, bilingual copy, status color source and pending online payment label.
- **Acceptance:** source-level presentation and localized status contract, not real paid webhook confirmation or a full Android/iOS screenshot/manual accessibility test.

### 53.05 — Remove artificial scarcity copy

- `test/architecture/no_fabricated_scarcity_copy_contract_test.dart` scans Flutter Dart, localization ARB and selected web entry/source files for hard-coded numbered availability/countdown or 'last chance' urgency claims in Arabic and English. It also asserts the UI's 'all slots booked' state is based on booking-slot data after handling errors.
- **Acceptance:** automated, repository-scoped prohibition of these literal patterns. **Not proof:** user-provided dynamic text, external campaign copy or every variant of misleading marketing message. Actual booking availability still requires source-of-truth server verification.

## Accounting and release boundaries

These are **3 accepted existing IDs, 0 new unique IDs**. The source acceptance baseline is **633 total / 280 accepted / 353 open**; after acceptance **633 / 283 accepted / 350 open (44.71%)**. The full app CI/Android E2E, live telemetry accuracy, complete privacy review, hosted Supabase and Paymob Sandbox are separate unresolved release checks. There was no database write, live FCM, Paymob payment, APK creation, production deployment or `main` merge. Evidence is the focused CI at the exact code SHA, not the later documentation-only commits.
