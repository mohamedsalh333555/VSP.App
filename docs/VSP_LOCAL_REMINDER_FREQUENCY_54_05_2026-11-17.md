# 54.05 — Local reminder frequency cap

17 November 2026, branch uxlp-44-implementation.

- The native match reminder scheduler permits at most 3 distinct reminders for an account on the same UTC scheduled-alert date.
- Duplicate scheduling for the same booking is idempotent. Changing the booking date replaces its old day marker.
- Existing numeric reminder records remain compatible with user-scoped cancellation on opt-out and sign-out.
- After the asynchronous native schedule call, quota is checked again; an over-limit reminder is canceled.
- Unit tests cover daily quota, rescheduling, UTC day separation, and legacy cancellation.

Boundaries: this is an app-local best-effort cap, not an atomic cross-isolate or multi-device quota, not an FCM/server limit, and not marketing opt-in enforcement. No live notification sent, no production data writes, and no main merge. CI must pass before narrowly counting 54.05.
