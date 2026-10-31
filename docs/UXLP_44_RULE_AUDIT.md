# UXLP-44 Rule Audit Matrix

**Branch:** `uxlp-44-implementation`  
**Standard:** `docs/UXLP_44_VSP_STANDARD.md`  
**Scope:** Shared foundations and 128 registered candidate Dart paths; embedded components are tracked separately in the screen register.  
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
| 9 | State visibility | source reviewed—runtime pending | Player and owner booking screens distinguish initial loading from authoritative empty results; both preserve loaded lists/schedules during refresh and expose stream failures with retry. Owner stadium realtime errors now preserve the last authoritative stadium snapshot instead of clearing the schedule. Verify other screens/states. |
| 10 | Bilingual visual integrity | source reviewed—runtime pending | Championship route and notification error states now have Arabic/English copy; full locale and RTL/LTR review remains. |
| 11 | Responsive legibility | source reviewed—runtime pending | Grouped safe-area/scroll fixes applied to several dialogs and sheets; keyboard, large-text, and compact-device checks remain. |
| 12 | Recognition over recall | not yet inspected | Verify required context and choices are visible at point of decision. |
| 13 | Plain language | source reviewed—runtime pending | Player booking details maps lifecycle statuses to explicit Arabic/English labels; refund-pending badge now uses channel-neutral copy instead of incorrectly implying every refund is bank-based. Full app copy audit remains. |
| 14 | One primary decision | not yet inspected | Identify competing primary actions on each decision surface. |
| 15 | Progressive disclosure | not yet inspected | Review advanced/optional details and disclosure timing. |
| 16 | Decision context | not yet inspected | Verify confirmation surfaces show all information needed before commitment. |
| 17 | Transparent cost | source reviewed—runtime pending | Payment fee display now uses the same local Paymob rate precedence and validation as the server; when policy is unavailable/invalid, the UI labels only the base amount, hides an unverified total, offers retry, and disables checkout. Remaining booking/cancellation totals still require review. |
| 18 | No misleading promises | source reviewed—runtime pending | Post-match result, booking-issue report, and owner reschedule flows show success only after repository success; alternate-result copy reflects the backend opponent-review flow. Payment-fee copy no longer promises 24/7 support or “100% secure” processing; unknown fees are not shown as zero. Audit remaining critical success surfaces. |
| 19 | Meaningful defaults | not yet inspected | Audit defaults against user role, location, and current booking/tournament context. |
| 20 | Choice economy | not yet inspected | Find duplicate, redundant, or low-value choices. |
| 21 | Chunk complex tasks | source reviewed—runtime pending | Owner onboarding/tournament/documentation wizards reviewed at source level; verify progress, back navigation, and draft preservation at runtime. |
| 22 | Explain constraints | not yet inspected | Verify eligibility, limits, required fields, and unavailable-action explanations. |
| 23 | Comparable information | not yet inspected | Audit alternatives for consistent units, labels, and criteria. |
| 24 | Contextual help | not yet inspected | Verify guidance appears next to the field/decision it explains. |
| 25 | Error prevention | not yet inspected | Review input validation and invalid state-transition prevention. |
| 26 | Decision reversibility | not yet inspected | Verify irreversible/costly actions and safe exits. |
| 27 | Affordance clarity | not yet inspected | Inspect whether each interactive control visually matches its behavior. |
| 28 | Immediate feedback | source reviewed—runtime pending | Post-match result entry/confirmation/dispute now distinguish backend success from failure; the result modal awaits submission, disables repeat taps, closes only after a successful submission, and preserves the form for retry after a failed submission. Loading/disabled states and feedback timing remain to be checked across all flows. |
| 29 | No duplicate submission | source reviewed—runtime pending | Shared primary button has duplicate-tap protection; private collective-match early return now resets processing flags. Verify every async action and backend idempotency path. |
| 30 | Predictable navigation | source reviewed—runtime pending | Root/router and both role shells reviewed; deep links, back stack, and restored tabs still need runtime verification. |
| 31 | State-driven actions | not yet inspected | Audit contradictory actions across booking/payment/team/tournament states. |
| 32 | Safe destructive actions | source reviewed—runtime pending | Pending-booking cancellation now requires explicit confirmation and explains that the slot will be released; other destructive actions still require review. |
| 33 | Touch ergonomics | source reviewed—runtime pending | Shared bottom navigation items are 58dp high; back button and pending-booking cancel icon have minimum 48dp targets. Verify all remaining controls and spacing. |
| 34 | Form resilience | not yet inspected | Audit keyboard types, focus order, validation, autofill, and submit behavior. |
| 35 | Scroll and modal safety | source reviewed—runtime pending | Scroll-safe dialogs/sheets and safe-area fixes applied in grouped batches; remaining surfaces and keyboard/device layouts need runtime validation. |
| 36 | Feedback recovery | source reviewed—runtime pending | Notification stream errors, championship route failures, team/profile and team-league read failures, and fee-policy lookup failures now have explicit recovery/retry states; post-match result failures show localized retry guidance. Verify all critical flows and draft preservation. |
| 37 | Consistent gestures | source reviewed—runtime pending | Notification swipe-to-dismiss is explicit and has Undo; verify discoverability and ensure critical actions have non-gesture alternatives. |
| 38 | Single source of truth | source reviewed—runtime pending | Player/owner booking views wait for authoritative snapshots; booking sync, stadium fetches, team/league reads, and notification actions reject stale callbacks after account/scope changes. Team profile and team dashboard distinguish missing data from failed reads. Verify all displayed booking/payment/refund values against server records. |
| 39 | Role-based relevance | source reviewed—runtime pending | Copilot remains owner-gated; result actions in both home and booking cards require captain identity for a participating team, suppress dual-side captain actions, and recalculate on account changes. Owner schedule is hidden outside owner role. Audit other role boundaries. |
| 40 | Lifecycle consistency | source reviewed—runtime pending | Player booking details/cards distinguish booking lifecycle states; challenge result prompts now compare team IDs to team IDs, and a mismatched result is described as waiting for the other captain (matching the atomic RPC) rather than an admin dispute. Full lifecycle consistency remains pending. |
| 41 | Persistent communication | source reviewed—runtime pending | Opening marks read, not delete; swipe-to-dismiss deletes and Undo restores the original payload/time. Delete/Undo callbacks are bound to the originating account. No notification DELETE trigger or retention cron was found in the active project. UI stream is capped at 50; product retention rule and historical disappearance still need confirmation. |
| 42 | Design-system governance | source reviewed—runtime pending | V2 tokens/shared components are canonical; all 128 candidate paths have source-review notes, but screen-level rule coverage is incomplete. |
| 43 | Operational observability | source reviewed—runtime pending | Booking screen/owner schedule/pending-cancel surfaces now use generic localized failure copy instead of raw backend exception strings; repository/provider diagnostics remain separate. Audit all critical failure surfaces. |
| 44 | Optimal cognitive load | not yet inspected | Review information density, urgency, animation, and feedback intensity for each task. |

## Findings fixed in this batch (runtime pending)

- Rule 35: owner verification and forced-update dialogs made scrollable; grouped booking, payment, tournament, and location sheets/dialogs received viewport, scroll, or safe-area corrections.
- Rule 29: private collective-match early-return path now clears the processing/loading flags.
- Rule 36: notification stream errors are no longer swallowed by the repository; the screen displays a localized error state with retry. Championship deep links now distinguish loading, error, and unavailable results.
- Rule 10: the championship route's loading/error/unavailable copy is localized in Arabic and English.
- Rule 41: source/database inspection established that opening a notification marks it read; it does not delete it. Swipe-to-dismiss is the explicit client deletion action. Historical disappearance is not yet explained.
- Rule 38/39: the notifications screen now watches the active Supabase user ID and recreates its stream when the account changes, preventing a retained screen from continuing to display the previous account's notification feed.
- Rule 36/41: notification deletion and Undo now report repository success/failure to the screen. A failed delete reloads the stream and displays an error instead of claiming deletion; a failed restore displays an error. Undo recreates the notification payload with its original `created_at` timestamp (the database generates a new row ID); no retention or schema policy changed.
- Rule 42: V2 shared tokens/components remain the canonical foundation; the screen register is still an inventory/source-review aid, not a pass report.

- Rule 35: match-result dialog now disables dismissal and form edits while the submission callback is running, preventing a still-running request from being hidden behind a dismissed modal.

- Rule 36: the post-match result modal now receives the repository success boolean; a failed submission re-enables the form and keeps the selected outcome/review available for retry rather than closing the only result-entry surface.

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
- Player `BookingsScreen` now preserves already-loaded bookings during a refresh and displays a localized non-blocking sync warning with Retry if the realtime/direct refresh fails. Initial load failures show a generic localized recovery message rather than raw backend details.
- Identity API consistency: `AuthProvider.currentUser` is Supabase `User?`. Although the repository defines a Firebase-compatible `SupabaseUserExtension.uid` alias, the affected screens did not import that extension, so their `.uid` reads were unresolved. Replaced them with the native `.id` property in player booking, notifications, profile, team dashboard, team profile, challenge team-selection, booking-type modal, match details, and championship details flows.
- Critical source finding: the direct booking query methods previously caught Supabase errors and returned `[]`, making a network/query failure indistinguishable from a verified empty schedule. Added strict direct-fetch variants for player and owner sync that propagate errors to the coordinator while retaining compatibility fallbacks for non-critical query callers. Realtime booking streams now allow errors to reach the coordinator instead of swallowing them. Their timeout recovery fetches also use the strict variants, so a failed retry cannot emit a false empty snapshot. The player/owner screens can therefore preserve the last snapshot and show retry/error states rather than treating a failed request as no bookings. Runtime verification remains pending.

### Player bookings loading and refresh behavior

- `BookingProvider` now exposes a dedicated player-bookings loading counter so concurrent refreshes do not prematurely clear the loading state and unrelated booking mutations do not drive the bookings screen spinner.
- `BookingsScreen` now waits for the initial booking snapshot before completing its initial data load, uses the dedicated loading state, and awaits the actual refresh operation from pull-to-refresh. Removed the previous fixed one-second delay from the empty-state refresh path.
- Runtime checks for slow network, confirmed empty list, failed fetch, and concurrent refreshes remain pending.
- Player booking cards now branch on the actual lifecycle enum instead of treating every non-history item as confirmed. Pending (including inconsistent `isPaid=true`) remains visibly pending/under verification; expired and no-show states receive their own badges.

- Owner schedule initial-load errors and pending-booking cancellation failures now show generic localized recovery copy rather than exposing raw Supabase/exception text. Player booking list initial-load errors already use the same pattern; full error-surface audit remains pending.

### Player booking lifecycle copy

- `PlayerBookingDetailsScreen` previously rendered `booking.status.name` directly, exposing enum identifiers such as `noShow` in the UI and English-only status values in Arabic mode. Added explicit Arabic/English labels for pending, confirmed/upcoming, completed, no-show, cancelled, and expired.
- Cross-screen consistency of the same lifecycle states remains pending; this change is limited to the booking details surface.
- Refund-pending status on player booking cards now uses neutral Arabic/English wording (`Refund processing`) rather than `Bank refund processing`, because the same state can represent card or wallet channels.

### Pending-booking payment status verification

- `PendingBookingCard` previously showed a confirmed message when either the booking status was `confirmed` **or** the legacy boolean `isPaid` was true. This could misreport a pending booking with an inconsistent/stale payment flag. It now uses `PaymentCheckoutService.isPaymentConfirmed`, which requires a confirmed booking and a recognized paid/partially-paid status. It also handles query failures with localized error feedback and refreshes the booking list after confirmed status.
- This aligns the UI with the canonical payment rule in `PaymentCheckoutService`; runtime validation against webhook-confirmed and still-pending records remains pending.
### Pending-booking destructive action

- The pending-booking trash action previously cancelled immediately on a single tap. It now presents a localized confirmation dialog explaining that the pending booking is cancelled and the slot released; success/failure feedback is explicit, and the touch target is at least 48dp.
- Runtime verification of dialog layout, cancellation rejection, and refresh behavior remains pending.

- The second-captain result dialog now disables both response actions and Later while a submission is in progress, shows loading only on the selected action, blocks barrier dismissal, and stays open with retry enabled after a server rejection.

### Challenge-result captain eligibility and backend contract

- Root cause: the player-home popup previously compared `resultSubmittedByTeamId` (a team UUID) against `auth.currentUser.id` (a user UUID). This comparison is not a valid way to determine whether the current side submitted the result. The same code also hard-coded `playerTeamId` when opening the first-result modal, so an opponent captain could be prompted to submit as the wrong team.
- Read-only inspection of `public.submit_challenge_result_atomic` confirmed the server requires `auth.uid()` to be the `captain_id` of `p_team_id`, and that team must be one of the two teams in the booking. The client now resolves all teams captained by the user, requires captain identity, verifies one of those teams participates in the booking, passes that exact team ID to the submission/response dialog, and shows the response prompt only when the other team submitted.
- Additional read-only schema check: `team_members` has a composite primary key `(team_id, user_id)` and no uniqueness constraint on `user_id`, so one user may belong to multiple teams. The UI therefore does not rely on `getUserTeam()`'s first membership; it resolves all teams the user captains and matches the relevant booking team.

- Product/backend decision required: the deployed `submit_challenge_result_atomic` RPC currently rejects cancelled bookings and future matches but does not explicitly require booking status `confirmed` or `completed`. The client now suppresses post-match result prompts for pending/expired/no-show/cancelled statuses. Proposed server hardening is to require `status IN ('confirmed','completed')` inside the atomic RPC; no SQL change was made because this changes the backend eligibility contract and requires approval.

- Backend mismatch behavior: when the second captain submits a different outcome, the RPC updates the pending outcome and submitter team and leaves the match in `waitingOpponent`; it does not create an administrative dispute. The UI action and warning copy now say that a different result is sent to the other captain for review, not that an admin dispute was filed.
- The challenge result-response dialog now guards against a missing `pendingOutcome` and shows a localized recovery message rather than force-unwrapping null and crashing.

- Additional server-side policy gap: the `teams` table has no unique constraint on `captain_id`, so the same user can captain both teams in a challenge. The UI now suppresses second-captain review when the signed-in user is captain of both sides, preventing self-confirmation through the normal flow. The atomic RPC itself does not verify that the second submission comes from a different user than the first submitter. Proposed server guard: require the existing submitter team's captain to be distinct from `auth.uid()` before finalizing a result. This changes result-approval policy and remains approval-required; no SQL change was made.

- Read-only inspection also confirmed `trg_calculate_elo` processes league points once when a challenge reaches `match_result_status='confirmed'` with a final outcome. The existing 'rankings updated' confirmation is therefore supported by the database trigger.
- No SQL, RPC, trigger, scoring, captain permission, or league rule was changed. Runtime verification across both captains and matching/mismatching outcomes remains pending.
- `BookingProvider` now scopes player/owner booking state to the active user/owner ID. Switching account or role clears the previous scope's cached bookings, and late direct-fetch/realtime callbacks from a previous scope are ignored instead of overwriting the active account's list.

- Owner booking schedule also now distinguishes an empty stadium list from stadium data still loading or a failed stadium stream; retry restarts the owner-stadium subscription instead of showing the no-stadium empty state prematurely.

- After the owner schedule has loaded, realtime refresh errors now show a localized non-blocking warning with Retry while preserving the last loaded slots; the screen no longer silently hides a stream failure or blanks the schedule.

### Owner schedule initial booking data state

- `OwnerBookingsScreen` previously rendered its generated time slots before the owner booking fetch had completed. During the initial network window, booked slots could therefore appear visually free. The screen now shows a loading state until the authoritative owner booking snapshot is received and an error/retry state if the initial fetch fails.
- The owner sync now treats an authoritative empty list as a completed load (rather than ignoring it), reports direct-fetch errors, and cancels the prior owner/user stream before changing scope. Force refreshes after quick booking preserve the already-loaded schedule instead of blanking it.
- No availability, booking, or server-side conflict policy was changed. Runtime validation with existing bookings, empty schedule, network failure, and account switching remains pending.


- Owner stadium realtime stream failures no longer clear `_stadiums` and `_filteredStadiums`; a refresh error now preserves the last authoritative schedule while surfacing the sync error. Initial failures still show the existing retry state because no snapshot exists.
- Stadium data is now isolated across account/role scopes: switching to a different owner clears the previous owner's cached stadiums before subscribing, while a same-owner forced refresh preserves the last good snapshot. Switching from owner scope back to player discovery cancels the owner stream and clears the owner-only list before fetching public stadiums. Late data/error callbacks from a cancelled owner stream are ignored unless that owner is still the active subscription scope. Player-only quick filters are also reset when crossing between player and owner scopes, so an old discovery filter cannot hide an owner's stadiums.
- Post-match result prompt suppression is now scoped to the player-home screen state rather than a process-wide static flag, so a prompt shown for one signed-in account cannot suppress another account's prompt in the same app process.

### Follow-up source review: asynchronous account-scope isolation

- Notifications: swipe-delete now captures the user ID that owned the dismissed row. The completion callback exits if the active account changed while the delete request was in flight. Undo also verifies the same account is still active before restoring the notification, preventing a delayed SnackBar action from attempting to restore an old account's row under a different signed-in account.
- Stadium discovery/owner streams: added a scope generation token. Player discovery requests (including filtered requests) are ignored if an owner subscription starts or the scope changes before the request completes. Owner subscriptions also receive a generation token on every resubscription, so late data/error callbacks from a cancelled subscription cannot overwrite the current snapshot, even when the owner ID is unchanged.
- Booking synchronization: added a generation token shared by player and owner sync operations. Starting a newer sync or disposing/cancelling the coordinator invalidates all older direct-fetch results and Realtime callbacks/errors. The last-known player booking baseline is reset when the signed-in user changes, so a failed first fetch for a new account cannot retain the previous account's booking baseline.
- These are source-level race-condition protections. Account-switch timing, delayed network responses, cancellation races, and notification Undo behavior still require the single consolidated runtime validation pass.


- Follow-up source review of the embedded booking components confirmed the pending-booking card checks server-confirmed payment state before reporting confirmation, and the player booking card renders lifecycle/refund states from the booking record. The captain-team lookup now has a strict variant used by the post-match prompt: a failed Supabase lookup is surfaced as a localized verification error instead of being silently interpreted as “user is not a captain.” The compatibility method retains its historical empty-set fallback for other callers.
- Player home post-match prompt suppression is now keyed by the active user ID rather than one screen-wide boolean, so a prompt shown for one account cannot suppress the other account's prompt when the same home-screen state is retained during account switching.
- Team profile loading previously called `TeamRepository.getTeam`, which caught all Supabase failures and returned `null`; the screen then rendered “Team not found” for both a genuinely missing team and a failed request. Added `getTeamStrict` and changed the screen to distinguish unavailable from load failure, with localized retry for the latter. The compatibility `getTeam` wrapper retains its old fallback for other callers. Runtime verification remains pending.

- Rule 36/38: team-profile loading previously converted a Supabase query failure into a null result and displayed “Team not found.” A strict lookup now preserves the distinction and exposes a localized retry state.
- Rule 38/39: asynchronous booking and stadium syncs now use generation checks so late data and errors from prior account/role scopes cannot overwrite current state. Player-home post-match result prompts are scoped to the active user.
- Rule 39: captain-team lookup failures now propagate through a strict method and show localized recovery feedback; a verified empty result remains the only state interpreted as “not a captain.”
- Rule 41: notification deletion and Undo capture the original user ID; if the active account changes before completion or Undo, the stale action is abandoned.
- Team profile roster previously treated the first row returned from `team_members` as the captain. The query has no ordering contract, so this could omit an arbitrary player from the roster and incorrectly expose captain-only UI to that player. The screen now filters the captain by `captain_id`, gates captain actions only on that field, and counts unique member IDs. Profile fetch failures now have a separate localized roster error/retry state instead of appearing as an empty roster.
- Team dashboard previously called `getUserTeam`, which swallowed membership-query failures as `null`; the league tab then rendered “ليس لديك فريق حالياً” and offered team creation. Added a strict membership lookup and explicit loading/error/retry states so only a successful empty membership query means “no team.”
- Product decision still open: `getUserTeamStrict` retains the existing `membership.first` selection when a user belongs to multiple teams. The `team_members` query has no explicit ordering, so the active team may be arbitrary. No team-selection policy was invented; a deliberate active-team selector/default rule is required before changing this behavior.
- Team dashboard membership refresh now follows the active Supabase user ID and uses a generation guard. If an account switch occurs while the membership or active-league request is in flight, the stale result is ignored instead of repopulating the previous account's team context.
- Stadium discovery and filter requests now have their own request generation in addition to account/role scope generation. A newer filter/refresh invalidates older in-flight results, including the governorate fallback query; a stale request cannot repopulate results for a filter the user has already replaced or leave its loading flag stuck.
- Team profile invite-code generation previously opened the invite modal even when the RPC returned `success: false` or an empty code, and its exception feedback was Arabic-only/raw. The screen now validates the RPC result before opening the modal and uses localized generic failure feedback while keeping diagnostic detail in logs.
- Team league tab previously converted a failed active-league read into the same `null` state used for “no league,” which could expose create/join actions. It now renders a localized retry state for failed league reads. A failed team-fee status lookup is no longer treated as unpaid: the pay action is disabled until the status can be verified, with a retry message. Payment-start failures now use localized generic copy; backend details remain in logs.
- Team league fetches and payment actions now carry the active team ID and a request generation. If the selected team changes while league/payment data is loading or a payment flow is returning, stale results cannot overwrite the new team's league state or launch a payment using mixed team context.
- Read-only inspection of the deployed `join_team_league` RPC showed a successful `already_paid: true` response distinct from `prepaid_by_creator: true`. The client previously treated that valid already-paid response as a missing payment reference and displayed an error. It now handles both successful paid outcomes as success and refreshes the league state; no RPC or SQL was changed.
- The team-league tab now calls strict repository methods for both active-league and configured-fee reads. The prior repository methods swallowed Supabase exceptions (`null`/30 EGP), so the earlier UI retry state could not distinguish a real no-league response from a failed query. Compatibility wrappers remain unchanged for other callers; the tab uses strict methods and the configured 30 EGP fallback only when the setting row/value is genuinely absent.
- Team profile now listens to AuthProvider in its build so captain-only actions are recalculated immediately when the signed-in account changes; it no longer retains a stale captain decision from a prior account.
- Extended the Supabase `User.id` call-site scan to the payment gateway: three `currentUser?.uid` reads had no imported compatibility extension and were unresolved. Replaced them with native `currentUser?.id`; the broader register-wide scan remains source review, not a completed repository-wide compile check.
- Owner bookings screen now watches the authenticated owner scope and restarts the owner booking/stadium subscriptions when the signed-in owner changes. Late post-frame initialization from a previous owner is invalidated by a generation guard.
- Bookings screen previously loaded only the first team membership and passed it to every challenge card; result actions then fell back to the booking's home team when no team ID was available. This could show result submission to a non-captain or on the wrong side. The screen now loads all membership IDs and captain IDs, resolves the user's side per booking, and passes a separate captain team ID for result actions. If the user captains both sides, the action is suppressed. Challenge status badges no longer invent a home-side identity when membership is unknown.
- Player bookings and team context now reload when the signed-in user changes; stale team/captain lookups are ignored. A team-context lookup failure disables result actions and exposes a localized warning with pull-to-refresh recovery.
- Owner bookings screen now checks the active account's owner role during build and hides the owner schedule when the session is missing or no longer has owner role, preventing retained owner data from remaining visible after a role/account transition.

- Payment pricing source review found a concrete mismatch: the server uses `booking_paymob_local_rate ?? booking_paymob_rate`, while the client displayed only `booking_paymob_rate`. The client now reads the local rate with the same fallback and validates the same online-payment conditions/rate bounds as the Edge Function.
- Payment fee policy was fetched twice and a null policy was rendered as zero administrative fees and the base amount labeled “Total Amount Due Now.” The checkout now shares one fee-policy result between the header and breakdown; missing/invalid policy shows a localized retry state, the header labels the number as a base amount (not a final total), and the Paymob CTA remains disabled until the policy is verified. No backend or SQL change was made.
- Payment fee transparency copy no longer promises instant confirmation, certified bank processing, or 24/7 support; it accurately describes the VSP platform fee plus Paymob processing fee and their current policy-based calculation.
- Payment security footer no longer claims “100% secure” or makes an unsupported licensing assertion; it now directs users to enter payment details only in Paymob's official checkout page.
- The payment/booking entry path also contained one `AuthProvider.currentUser?.uid` read in `BookingConfirmationScreen` without the compatibility extension imported. It now reads native Supabase `User.id`; the targeted call-site audit continues beyond the earlier nine-screen batch.
- Booking confirmation now uses strict team lookup and blocks Team/Challenge confirmation until the user's team context is verified. A verified no-team result gets a clear join-team message; a failed lookup gets a retry path instead of silently building a team booking with a null team ID. Personal bookings are not blocked by the optional team lookup. Multiple-team default selection remains the previously documented product decision.

- **Server-side approval required — team booking authorization:** read-only inspection of deployed `create_booking_atomic` shows that it validates the caller/user relationship but accepts `p_player_team_id` as any UUID and inserts it without checking membership in `team_members` or captain ownership. The client currently supplies the first team membership, whose order is unspecified. Proposed fix: decide whether any team member or only the captain may create a team booking, then enforce that exact rule inside `create_booking_atomic` and provide an explicit active-team selection when multiple memberships exist. No SQL/RPC change was applied because this changes authorization/business rules and requires your approval.
- Team dashboard now uses the strict active-league lookup for its initial tab decision; if that lookup fails, it opens the league tab so the tab's localized retry state is visible instead of silently implying there is no active league.
