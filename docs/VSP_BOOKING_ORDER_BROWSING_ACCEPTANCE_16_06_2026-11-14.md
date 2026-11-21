# VSP — Booking order and history browsing (16.06)

Date: 2026-11-14. Branch: `uxlp-44-implementation`.

## Accepted scope

The player bookings screen displays upcoming bookings in chronological order even when the repository supplies them out of order. A completed booking remains reachable in the history section by scrolling. The categorization service keeps stable ordering when start times tie, orders history by the latest end first, and does not change its input list. Owner ties are deterministic as well.

## Evidence

- `test/features/player/bookings_screen_test.dart` renders the real screen with a fake booking repository. It asserts that “Soon Stadium” is above “Later Stadium”, then scrolls until “History Stadium” appears under History.
- `test/core/providers/booking/booking_categorization_service_test.dart` checks upcoming, pending and history tie order, newest-first history, unchanged input and owner tie order.
- [Flutter CI run 43598491150](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43598491150) completed successfully on commit `f3136c49e52b3fb2f3fb22da960e71cdfd1be289`, including analysis and the full Flutter test step.

## Boundaries

This is UI and categorization acceptance for **16.06**. The widget uses a fake repository and does not prove that every real booking is returned by the server, that pagination handles a very large account, or that a real two-account staging journey passes. **16.01** and server authorization remain open. Android onboarding/login smoke is not a booking-history journey.
