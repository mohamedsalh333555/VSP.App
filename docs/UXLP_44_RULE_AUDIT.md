# UXLP-44 Rule Audit Matrix

**Branch:** `uxlp-44-implementation`  
**Standard:** `docs/UXLP_44_VSP_STANDARD.md`  
**Scope:** Shared foundations and 128 registered candidate Dart paths.  
**Audit rule:** This matrix records source evidence only. `source reviewed—runtime pending` is not a pass. No rule is considered complete until the applicable player/owner screens, states, Arabic/English layouts, device conditions, and runtime evidence are recorded.

| # | Rule | Current source status | Evidence / remaining verification |
|---:|---|---|---|
| 1 | Clear hierarchy | not yet inspected | Inspect each screen's primary task and visual hierarchy. |
| 2 | Consistent grouping | not yet inspected | Verify related fields/actions and separation on each screen. |
| 3 | Contrast first | source reviewed—runtime pending | V2 semantic foreground/surface palette exists; audit actual component pairings and contrast in every state. |
| 4 | Typography roles | source reviewed—runtime pending | V2 semantic typography roles exist; verify feature screens use the roles consistently and preserve Arabic/English legibility. |
| 5 | One icon language | source reviewed—runtime pending | Shared navigation uses distinct Iconsax active/inactive variants; inspect all feature icons, sizes, and containers. |
| 6 | Color semantics | source reviewed—runtime pending | V2 semantic success/warning/error/info/accent colors exist; verify no feature-level misuse. |
| 7 | Stable alignment | source reviewed—runtime pending | Canonical spacing and geometry tokens exist; screen-level alignment review remains. |
| 8 | Scan-friendly density | not yet inspected | Review information density and paragraph/card readability screen by screen. |
| 9 | State visibility | source reviewed—runtime pending | Shared `VSPStateView` distinguishes loading/empty/error/offline/pending/success/disabled; player bookings now has a dedicated loading state tied to the awaited server refresh, preventing a premature empty state. Verify actual state usage. |
| 10 | Bilingual visual integrity | source reviewed—runtime pending | Championship route and notification error states now have Arabic/English copy; full locale and RTL/LTR review remains. |
| 11 | Responsive legibility | source reviewed—runtime pending | Grouped safe-area/scroll fixes applied to several dialogs and sheets; keyboard, large-text, and compact-device checks remain. |
| 12 | Recognition over recall | not yet inspected | Verify required context and choices are visible at point of decision. |
| 13 | Plain language | source reviewed—runtime pending | Player booking details maps lifecycle statuses to explicit Arabic/English labels; refund-pending badge now uses channel-neutral copy instead of incorrectly implying every refund is bank-based. Full app copy audit remains. |
| 14 | One primary decision | not yet inspected | Identify competing primary actions on each decision surface. |
| 15 | Progressive disclosure | not yet inspected | Review advanced/optional details and disclosure timing. |
| 16 | Decision context | not yet inspected | Verify confirmation surfaces show all information needed before commitment. |
| 17 | Transparent cost | not yet inspected | Audit total price, fees, payment timing, cancellation, and refund conditions before commitment. |
| 18 | No misleading promises | source reviewed—runtime pending | Post-match result, booking-issue report, and owner reschedule flows now show success only when their repository operation succeeds; pending-booking status check uses the canonical server-confirmed payment predicate, not `isPaid` alone. Audit remaining payment/booking/refund/tournament success surfaces. |
| 19 | Meaningful defaults | not yet inspected | Audit defaults against user role, location, and current booking/tournament context. |
| 20 | Choice economy | not yet inspected | Find duplicate, redundant, or low-value choices. |
| 21 | Chunk complex tasks | source reviewed—runtime pending | Owner onboarding/tournament/documentation wizards reviewed at source level; verify progress, back navigation, and draft preservation at runtime. |
| 22 | Explain constraints | not yet inspected | Verify eligibility, limits, required fields, and unavailable-action explanations. |
| 23 | Comparable information | not yet inspected | Audit alternatives for consistent units, labels, and criteria. |
| 24 | Contextual help | not yet inspected | Verify guidance appears next to the field/decision it explains. |
| 25 | Error prevention | not yet inspected | Review input validation and invalid state-transition prevention. |
| 26 | Decision reversibility | not yet inspected | Verify irreversible/costly actions and safe exits. |
| 27 | Affordance clarity | not yet inspected | Inspect whether each interactive control visually matches its behavior. |
| 28 | Immediate feedback | source reviewed—runtime pending | Post-match result entry/confirmation/dispute now distinguish backend success from failure; the result modal awaits submission, disables repeat taps, and closes after the callback completes. Loading/disabled states and feedback timing remain to be checked across all flows. |
| 29 | No duplicate submission | source reviewed—runtime pending | Shared primary button has duplicate-tap protection; private collective-match early return now resets processing flags. Verify every async action and backend idempotency path. |
| 30 | Predictable navigation | source reviewed—runtime pending | Root/router and both role shells reviewed; deep links, back stack, and restored tabs still need runtime verification. |
| 31 | State-driven actions | not yet inspected | Audit contradictory actions across booking/payment/team/tournament states. |
| 32 | Safe destructive actions | not yet inspected | Review confirmations, consequences, and recovery/undo behavior. |
| 33 | Touch ergonomics | source reviewed—runtime pending | Shared bottom navigation items are 58dp high and back-button minimum target is 48dp; verify all controls and spacing. |
| 34 | Form resilience | not yet inspected | Audit keyboard types, focus order, validation, autofill, and submit behavior. |
| 35 | Scroll and modal safety | source reviewed—runtime pending | Scroll-safe dialogs/sheets and safe-area fixes applied in grouped batches; remaining surfaces and keyboard/device layouts need runtime validation. |
| 36 | Feedback recovery | source reviewed—runtime pending | Notification stream errors and championship route failures now have explicit recovery states; post-match result failures now show localized retry guidance instead of false success. Verify all critical flows and draft preservation. |
| 37 | Consistent gestures | source reviewed—runtime pending | Notification swipe-to-dismiss is explicit and has Undo; verify discoverability and ensure critical actions have non-gesture alternatives. |
| 38 | Single source of truth | not yet inspected | Verify displayed booking, payment, refund, team, and tournament values against authoritative Supabase records. |
| 39 | Role-based relevance | source reviewed—runtime pending | Copilot route is owner-gated and root selects role shell; audit every owner/player action and deep-link boundary. |
| 40 | Lifecycle consistency | source reviewed—runtime pending | Player booking details now localizes pending/confirmed/completed/no-show/cancelled/expired statuses; cross-screen lifecycle label mapping and backend transition consistency remain to be verified. |
| 41 | Persistent communication | source reviewed—runtime pending | Opening marks read, not delete; swipe-to-dismiss deletes. No notification DELETE trigger or retention cron was found in the active project. UI stream is capped at 50; product retention rule and historical disappearance still need confirmation. |
| 42 | Design-system governance | source reviewed—runtime pending | V2 tokens/shared components are canonical; all 128 candidate paths have source-review notes, but screen-level rule coverage is incomplete. |
| 43 | Operational observability | not yet inspected | Verify critical failures are traceable without exposing secrets or sensitive details. |
| 44 | Optimal cognitive load | not yet inspected | Review information density, urgency, animation, and feedback intensity for each task. |

## Findings fixed in this batch (runtime pending)

- Rule 35: owner verification and forced-update dialogs made scrollable; grouped booking, payment, tournament, and location sheets/dialogs received viewport, scroll, or safe-area corrections.
- Rule 29: private collective-match early-return path now clears the processing/loading flags.
- Rule 36: notification stream errors are no longer swallowed by the repository; the screen displays a localized error state with retry. Championship deep links now distinguish loading, error, and unavailable results.
- Rule 10: the championship route's loading/error/unavailable copy is localized in Arabic and English.
- Rule 41: source/database inspection established that opening a notification marks it read; it does not delete it. Swipe-to-dismiss is the explicit client deletion action. Historical disappearance is not yet explained.
- Rule 42: V2 shared tokens/components remain the canonical foundation; the screen register is still an inventory/source-review aid, not a pass report.

- Rule 35: match-result dialog now disables dismissal and form edits while the submission callback is running, preventing a still-running request from being hidden behind a dismissed modal.

## Gates still open

1. Complete screen-by-screen rule mapping for all 128 candidate paths plus embedded widgets and state variants.
2. Finish Arabic/English copy and RTL/LTR review.
3. Resolve findings that require product decisions (including notification retention policy) before changing business/data behavior.
4. Complete one consolidated validation pass after all grouped source changes.
5. Only after the audit and consolidated validation pass, build and verify one test APK.

**No final test pass or APK build is authorized by this checkpoint.**

### Player post-match result flow findings

- The player home previously started booking synchronization without awaiting its first direct Supabase snapshot, then immediately scanned the provider's current list for completed challenge matches. On first launch this could scan an empty or stale list and skip the pending result dialog. The coordinator now awaits the direct snapshot, reports whether it loaded successfully, and treats a confirmed empty server response as a completed load. The home screen checks pending results only after a successful snapshot and no longer starts a duplicate load inside the popup checker.
- The post-match add-result, confirm-result, and dispute callbacks previously displayed success/warning feedback regardless of the boolean returned by `submitMatchResult`. They now show success only after a successful repository result and display localized error feedback on failure.
- The team identity/eligibility logic that determines which side may submit or confirm a challenge result has not been changed. It requires a separate domain-level review against the booking/team membership model before modifying any business rule.
- Runtime checks for first-launch delayed network, empty bookings, stream reconnect, duplicate taps, success, and server rejection remain pending.
### Booking details and owner reschedule feedback

- `PlayerBookingDetailsScreen._reportOwnerIssue` previously routed both success and failure copy through the success feedback style. It now uses success styling only when `reportEntity` returns true and an error state otherwise; its report dialog is scrollable.
- `UpcomingOnlinePaidActions` previously gave no feedback when `requestReschedule` returned false. It now presents a localized failure message and only offers the optional phone call/close action after the request succeeds.
- These are source-level findings; failure/success behavior and compact-screen dialog layout remain runtime pending.
### Player bookings loading and refresh behavior

- `BookingProvider` now exposes a dedicated player-bookings loading counter so concurrent refreshes do not prematurely clear the loading state and unrelated booking mutations do not drive the bookings screen spinner.
- `BookingsScreen` now waits for the initial booking snapshot before completing its initial data load, uses the dedicated loading state, and awaits the actual refresh operation from pull-to-refresh. Removed the previous fixed one-second delay from the empty-state refresh path.
- Runtime checks for slow network, confirmed empty list, failed fetch, and concurrent refreshes remain pending.
### Player booking lifecycle copy

- `PlayerBookingDetailsScreen` previously rendered `booking.status.name` directly, exposing enum identifiers such as `noShow` in the UI and English-only status values in Arabic mode. Added explicit Arabic/English labels for pending, confirmed/upcoming, completed, no-show, cancelled, and expired.
- Cross-screen consistency of the same lifecycle states remains pending; this change is limited to the booking details surface.
- Refund-pending status on player booking cards now uses neutral Arabic/English wording (`Refund processing`) rather than `Bank refund processing`, because the same state can represent card or wallet channels.

### Pending-booking payment status verification

- `PendingBookingCard` previously showed a confirmed message when either the booking status was `confirmed` **or** the legacy boolean `isPaid` was true. This could misreport a pending booking with an inconsistent/stale payment flag. It now uses `PaymentCheckoutService.isPaymentConfirmed`, which requires a confirmed booking and a recognized paid/partially-paid status. It also handles query failures with localized error feedback and refreshes the booking list after confirmed status.
- This aligns the UI with the canonical payment rule in `PaymentCheckoutService`; runtime validation against webhook-confirmed and still-pending records remains pending.
