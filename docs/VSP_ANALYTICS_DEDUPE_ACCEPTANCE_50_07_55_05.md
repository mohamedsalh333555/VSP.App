# Acceptance — 50.07 and 55.05: in-session funnel deduplication

Date: 2026-11-13. Branch: `uxlp-44-implementation`.

## 50.07 — One visit counted once
- The application calls `AnalyticsService.logVenueViewed(venueId: ...)` from the stadium details journey.
- `logVenueViewed` uses `logOncePerSession` with the keyed identity `venue_viewed:<venueId>`.
- Repeated calls from rebuilding or revisiting the same stadium in one process are suppressed; a different stadium still emits its own first visit.
- Direct unit assertions in `test/core/services/analytics_service_test.dart` exercise same-venue repeated calls, separate venues and a new registry/session.

## 55.05 — Analytics duplicate prevention
- `AnalyticsSessionDedupe.markFirst` now namespaces keys by event type, preventing unrelated funnel events that share a user-supplied dedupe key from suppressing one another.
- Unit tests verify same-type repeat suppression, event-type isolation and new-session behavior.
- `test/architecture/phase10_analytics_contract_test.dart` confirms funnel logging placements, event boundaries and no premature financial-completion event.

**CI evidence:** [Flutter CI run 43326492976](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43326492976), commit `b19f7d9e`, success. [Flutter CI run 43326483118](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43326483118) also success. [Android smoke run 43326493177](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43326493177) and iOS compliance build `43326493122` successful for this snapshot; smoke does not cover Firebase event delivery.

**Acceptance boundary:** Both tasks are accepted for local/session logic and automated regression tests, **not** proof of one-per-user across devices, persistence across process restarts, Firebase dashboard correctness, offline-event delivery, or backend exactly-once event ingestion. Those require separate instrumentation/device evidence. 50.04, 50.05, 51.07 and 55.06 remain open. No production event records were fetched or modified.
