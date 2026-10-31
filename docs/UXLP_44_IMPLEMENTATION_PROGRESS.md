# UXLP-44 — Phase 2 Implementation Progress

**Branch:** `uxlp-44-implementation`  
**Scope:** Phase 2 only — source implementation of UXLP-44.  
**Explicit exclusion:** CI, analyzer, automated tests, runtime checks, and APK build are not being run in this phase.

## Implemented source changes in this batch

1. **Canonical bottom navigation geometry access (Rules 5, 42)**
   - Re-exported `VSPBottomNavMetrics` through the legacy token facade.
   - The metric values remain defined only in `vsp_design_tokens.dart`; no second geometry source was introduced.
   - This resolves feature imports that consume the legacy facade while referencing the canonical metric.

2. **Owner tournament stream recovery (Rules 9, 36, 38)**
   - Initial stream failure now displays the shared localized error/retry state.
   - A successful empty list is not used to mask a stream failure.
   - A previously loaded non-empty tournament snapshot remains visible after a later stream refresh error.
   - The stale-data warning and retry affordance are bilingual.
   - Retry recreates the stream using the current owner/sport scope.

3. **Shared state-view compact-screen resilience (Rules 11, 35)**
   - Shared loading and terminal state presentations now use a bounded-width scrollable content region.
   - Long localized text and recovery actions remain reachable when viewport height is constrained.
   - Existing semantic colors and charcoal empty/disabled treatment are preserved.

## Rules touched by this implementation batch

| Rule | Source implementation | Status |
|---|---|---|
| 3 — Contrast first | Preserve semantic state colors and neutral empty/disabled treatment | Source updated/reused; runtime pending |
| 5 — One icon language | Canonical navigation geometry exposed through compatibility facade | Source updated; glyph appearance pending |
| 6 — Color semantics | Shared state component retains semantic error/offline and neutral empty colors | Source reused; screen-wide review pending |
| 9 — State visibility | Owner tournament loading/error/empty/stale states separated | Source updated; runtime pending |
| 11 — Responsive legibility | Shared state view scrolls within bounded width | Source updated; runtime pending |
| 35 — Scroll and modal safety | Shared state/action content remains scrollable | Source updated; runtime pending |
| 36 — Feedback recovery | Owner tournament error state includes retry and stale-data warning | Source updated; runtime pending |
| 38 — Single source of truth | Bottom navigation metrics remain canonical in V2 tokens | Source updated; usage migration pending |
| 42 — Design-system governance | Compatibility export points to canonical token only | Source updated; repository-wide migration pending |

## Remaining Phase 2 work

- Continue rule-by-rule source mapping and implementation for all 44 rules across applicable player/owner screens, shared widgets, embedded surfaces, dialogs, sheets, and lifecycle states.
- Consolidate repeated button, segmented-control, filter, and bottom-action patterns on canonical components where safe.
- Continue bilingual copy, RTL/LTR, typography, contrast, grouping, hierarchy, touch-target, keyboard, safe-area, and state-recovery corrections.
- Continue query/state truthfulness fixes without changing backend policy or applying migrations.
- Keep product-policy and backend authorization changes in the approval-required list until the product owner approves the exact change.

## Phase boundary

This progress file does not declare UXLP-44 complete. All 44 matrix entries remain runtime-pending until a later explicitly approved validation phase. No CI, analyzer, automated tests, runtime tests, database mutation, migration, or APK build was performed.


## Continued implementation batch — player/owner flows

Additional commits after the first Phase 2 batch extended implementation across player profile, team dashboard, notifications, support, filters, owner booking calendar, and owner dashboard:

- Profile: strict/cached team membership lookup; retryable failure state; account-scoped future; refresh after team-management/create return.
- Notifications: account-scoped stream reset; keep loaded notifications during refresh; error is not shown as an empty list; retry banner for stale data.
- Public match gathering: retain loaded match cards on stream failure; initial error has retry; tabs announce selected state.
- Support tickets: preserve loaded ticket/message content through realtime refresh failures; show bilingual retry warning; WhatsApp escalation failures are visible.
- Stadium filters: keyboard-aware sheets, 48dp category hit targets, accessible no-deposit control, and normalized persisted price ranges.
- Owner bookings calendar: 48dp selectors and localized date semantics for day items.
- Owner dashboard: invalidate stale withdrawal balance while refreshing, ignore late cross-account financial results, surface tournament stream errors, and make tabs accessible.
- Add-player lookup: strict phone query distinguishes "not registered" from "query failed".

The exact touched rule groups are 3, 5, 6, 9, 11, 17, 18, 25, 27, 28, 33, 35, 36, 38, 39, 42, and 43. These remain source-level implementation notes, not verification passes. Remaining rules and applicable surfaces still require continued source implementation/mapping in Phase 2.


## Latest implementation continuation

- Notification read-state mutations now return success/failure. Mark-all and mark-one errors are surfaced to the user; opening a notification does not delete it, and the UI explains when its read-state update fails.
- Owner dashboard now resets finance/analytics/championship snapshots, approval notices, filter selection and metric cache when the authenticated owner scope changes; it rebinds data requests and realtime subscription and ignores late results from the previous account.
- Add-player search now has an explicit semantic label, tooltip and focusable target.

**Notification issue caveat:** this improves client-side behavior and observability but does not claim the historical disappearing-notification issue is fully resolved without live database/realtime evidence. No tests, CI, analyzer, runtime validation, migration, or APK build were run.


## Latest source implementation batch — support and notifications

- Support ticket list: stable account-scoped stream lifecycle; explicit retry recreates the stream; initial read errors cannot appear as a no-ticket empty state; refresh errors preserve the last ticket list with a bilingual warning.
- Notification presentation: detail dialog now resolves Arabic/English metadata consistently with cards; title wrapping increased to two lines.
- Language selector: keyboard-focusable selection rows, selected semantics, 56dp minimum row height, and scroll-safe compact viewport layout.
- Shared controls: back button now uses focusable InkWell within its 48dp-or-larger target; animated button shows its disabled state while the existing debounce blocks repeat taps.
- FCM queue: failed push responses are no longer archived as if delivered; all-device send failures return a retryable HTTP response; notification IDs from the queue payload reach FCM data.

The FCM queue remains at-least-once, so a successful push followed by an archive failure can be delivered again on retry. No queue schema, retry policy, notification retention, RLS, migration, or business rule was changed.

These changes are source implementation only. All 44 rule statuses remain runtime pending. No CI, analyzer, automated tests, runtime validation, database migration, or APK build was run.
