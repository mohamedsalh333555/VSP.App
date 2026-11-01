# UXLP-44 Rule Audit Matrix

**Branch:** `uxlp-44-implementation`  
**Standard:** `docs/UXLP_44_VSP_STANDARD.md`  
**Scope:** Shared foundations and 338 unique registered Dart paths: 325 visual surfaces within the recursive screen/widget tree plus 13 cross-cutting core/shared foundations (366 table data rows, including 28 repeated paths documenting separate embedded-component findings), plus one shared navigation component and separately recorded embedded components.  
**Audit rule:** This matrix records source evidence only. `source reviewed—runtime pending` is not a pass. No rule is considered complete until the applicable player/owner screens, states, Arabic/English layouts, device conditions, and runtime evidence are recorded.

| # | Rule | Current source status | Evidence / remaining verification |
|---:|---|---|---|
| 1 | Clear hierarchy | source reviewed—runtime pending | Source-reviewed representative player/owner flows: booking confirmation, match details, create-team, owner dashboard, subscription plans. Screen-by-screen hierarchy and device rendering still pending. |
| 2 | Consistent grouping | source reviewed—runtime pending | Booking, team creation, subscription, and match-detail surfaces group related decision inputs/actions; full 128-surface grouping review remains pending. |
| 3 | Contrast first | source reviewed—runtime pending | V2 semantic foreground/surface palette exists; audit actual component pairings and contrast in every state. |
| 4 | Typography roles | source reviewed—runtime pending | V2 semantic typography roles exist; verify feature screens use the roles consistently and preserve Arabic/English legibility. |
| 5 | One icon language | source reviewed—runtime pending | Shared navigation uses distinct Iconsax active/inactive variants; inspect all feature icons, sizes, and containers. |
| 6 | Color semantics | source reviewed—runtime pending | V2 semantic success/warning/error/info/accent colors exist. Replaced raw black/white/transparent UI literals across 37 auth/owner/player surfaces and embedded widgets with canonical VSP aliases, adding black26/black45/black87/white70 opacity primitives where required. Verify contrast and state colors at runtime across all screens. |
| 7 | Stable alignment | source reviewed—runtime pending | Login forgot-password action now uses directional end alignment; auth forms no longer add the bottom system inset twice inside SafeArea; Add Stadium, Owner Documentation, Edit Profile, Set New Password, and Player Bookings bodies no longer add a second top safe inset beneath their app bars; Owner Dashboard now avoids reapplying the parent top inset while retaining bottom system protection for its scroll content; Edit Profile uses one bottom-inset strategy; Championship Checkout leaves bottom inset ownership to its sticky VSPBottomActionBar. Remaining screen-level alignment review is pending. Canonical spacing and geometry tokens exist; owner payout full-balance action and owner booking calendar, player booking date-strip, and home stadium, match, championship, and team-member badge spacing now use directional alignment/margins. Screen-level alignment review remains. |
| 8 | Scan-friendly density | source reviewed—runtime pending | Long booking, refund, plan, and owner documentation confirmation content now uses bounded/scrollable dialogs; representative dashboards/cards reviewed. Density and large-text rendering still require device validation. |
| 9 | State visibility | source reviewed—runtime pending | Player and owner booking screens distinguish initial loading from authoritative empty results; both preserve loaded lists/schedules during refresh and expose stream failures with retry. Owner stadium realtime errors preserve the last authoritative stadium snapshot; facility onboarding now distinguishes an initial stadium-load failure from a genuine empty stadium list and offers localized retry, while stale loaded stadiums remain visible after refresh failure. Owner inbox distinguishes initial conversation-stream failure from a true empty inbox and preserves loaded conversations with a stale-data warning on refresh failure. Owner financial ledger preserves loaded transactions during refresh and separates initial stream failure from an authoritative empty ledger. Global search separates request failure from no-results and ignores late results from superseded queries. Owner profile stadium count no longer displays zero while its stream is initially loading or when the initial read fails. Match details distinguish a failed initial fetch from a genuinely missing match and offer localized retry. Player home match and championship feeds preserve loaded cards on refresh failure and expose retry; initial errors no longer masquerade as empty content. The home notification badge now rebinds to the active user and signals unread-count stream failure instead of silently implying zero unread. Owner tournament brackets preserve loaded rounds/standings and expose localized stale-data retry after stream failure. Favorites now distinguish fetch failure from an empty favorite list and provide retry without recreating the request on unrelated rebuilds. Challenge H2H history now distinguishes a query failure from a genuine no-previous-matches result instead of fabricating zero statistics; the challenge-team champion badge now has localized Arabic/English copy. RootScreen now starts a 5-second profile-resolution timeout when authentication becomes active even after the root screen has mounted, and cancels it when the account/profile resolves; a late timeout is scoped to the same user ID. Verify other screens/states and runtime transitions. |
| 10 | Bilingual visual integrity | source reviewed—runtime pending | Auth location auto-detect actions now have localized tooltips and preserve direction-aware placement; the Copilot loading bubble and stadium navigation cue are also direction-aware and localized; broader locale and RTL/LTR review remains. Championship checkout roster validation, live matchup dashboard plus its result-entry/timeline/standings widgets, penalty-shootout labels, team-league onboarding/gathering/standings/fixtures, tournament bracket load errors, and owner payout actions now have bilingual or direction-aware handling; LanguageProvider now accepts only the app-supported `ar`/`en` locales, repairs invalid persisted locale values to English, and ignores stale asynchronous locale loads when a newer language choice wins; full locale and RTL/LTR review remains. |
| 11 | Responsive legibility | source reviewed—runtime pending | Login/signup keyboard-aware scroll layouts no longer double-count the bottom safe inset; player/owner onboarding location actions have 48dp targets. Compact-screen and large-text checks remain. Grouped fixes include scrollable player/owner onboarding exit dialogs, championship error and matchup closure dialogs, bounded matchup/league standings metadata, keyboard-safe league sheets, and bottom-inset-aware refund/manual-address sheets; keyboard, large-text, and compact-device checks remain. Owner setup wizards no longer double-count top system insets beneath app bars; the password-reset dialog is scrollable and its two actions meet 48dp touch height. Match detail realtime failures now retain readable loaded content with an explicit stale-data state and retry. |
| 12 | Recognition over recall | source reviewed—runtime pending | Booking confirmation keeps selected slots, financial summary, and team context visible; challenge selection shows verified opponent/team; subscription cards show current entitlements and prices. |
| 13 | Plain language | source reviewed—runtime pending | Player booking lifecycle labels remain explicit; ledger export, tournament creation, championship checkout, matchup closure, match-leave failures, and owner document-upload failures no longer expose raw exception strings. Full app copy audit remains. |
| 14 | One primary decision | source reviewed—runtime pending | Booking type cards, checkout CTA, challenge continuation, and roster save expose a distinct primary action; remaining screen-by-screen hierarchy review pending. |
| 15 | Progressive disclosure | source reviewed—runtime pending | Stadium detail tabs, payment fee explanation modal, and staged onboarding/tournament wizards defer secondary detail until requested. |
| 16 | Decision context | source reviewed—runtime pending | Checkout shows server-confirmed amount plus fee breakdown; cancellation and match-leave dialogs explain consequences; booking confirmation surfaces slot/team context before commit. |
| 17 | Transparent cost | source reviewed—runtime pending | Payment fee display matches server policy; team-league fee labels use the loaded configured fee instead of hardcoded 30 EGP. Refund dialogs distinguish confirmed from server-pending amounts; pending-booking actions no longer offer cancellation alongside unresolved payment/refund status. Owner ledger now hides an unconfirmed balance and marks the last confirmed summary as stale if refresh fails; remaining booking/cancellation totals still require review. |
| 18 | No misleading promises | source reviewed—runtime pending | Payment-fee and refund copy avoids unverified amounts/promises; team-league cancellation now says only policy-eligible amounts are reviewed and administrative fees are non-refundable. Cancellation success still requires persisted status; refund notification gaps remain approval-required. |
| 19 | Meaningful defaults | source reviewed—runtime pending | Create-team defaults to Football, consistent with VSP's football-only product; challenge and booking flows now bind defaults to current authenticated/team context. Broader default audit pending. |
| 20 | Choice economy | source reviewed—runtime pending | Booking-type choices are separated into personal, collective, and challenge paths; subscription now shows monthly/annual billing plus trial only when configured. |
| 21 | Chunk complex tasks | source reviewed—runtime pending | Owner onboarding/tournament/documentation wizards reviewed at source level; verify progress, back navigation, and draft preservation at runtime. |
| 22 | Explain constraints | source reviewed—runtime pending | Tournament roster min/max and lock states, team-required challenge booking, owner plan stadium limits, and trial eligibility are surfaced in the reviewed flows. |
| 23 | Comparable information | source reviewed—runtime pending | Pro monthly and annual prices are sourced from the same plan catalog; annual savings is calculated against 12 monthly payments. Broader alternative comparisons remain pending. |
| 24 | Contextual help | source reviewed—runtime pending | Fee detail tooltip/modal explains the fee composition at checkout; roster and challenge inputs provide adjacent constraints and guidance. |
| 25 | Error prevention | needs product decision | Booking availability is rechecked before confirmation; team/roster constraints are verified before actions; challenge continuation re-fetches strict membership and disables unverified states. Approval-required server gaps TL-01 and TL-02 remain: the result-submission RPC lacks booking/kickoff guards, and the active-league SECURITY DEFINER read lacks participant authorization. A live ACL recheck on 2026-11-01 confirms the former TL-03 authenticated fixture-generation grant is no longer present. Live function-source review confirms `submit_team_league_match_result` still lacks a scheduled-kickoff guard (and no matching server-side guard was found in the inspected definition); exact SQL remediation requires product approval. A live inspection of `public.get_team_active_league(uuid)` also confirms the TL-02 finding: authenticated callers can invoke the SECURITY DEFINER function with arbitrary team IDs; the function does not authorize the caller as a member/captain/creator and includes captain phone numbers in its JSON payload. This is a confirmed authorization/PII exposure in the RPC design, not merely an advisor warning; remediation must be approved and deployed server-side. |
| 26 | Decision reversibility | source reviewed—runtime pending | Match leave and booking/payment cancellation have confirmation copy; payment exit now distinguishes submitted payments awaiting server confirmation. More destructive flows remain pending. |
| 27 | Affordance clarity | source reviewed—runtime pending | Booking options use full-card InkWell; dashboard tabs have 48dp targets; fee details use a 48dp IconButton with tooltip; disabled actions use null callbacks. |
| 28 | Immediate feedback | source reviewed—runtime pending | Post-match result entry/confirmation/dispute now distinguish backend success from failure; the result modal awaits submission, disables repeat taps, closes only after a successful submission, and preserves the form for retry after a failed submission. Loading/disabled states and feedback timing remain to be checked across all flows. |
| 29 | No duplicate submission | source reviewed—runtime pending | Shared primary button has duplicate-tap protection; private collective-match early return now resets processing flags. Verify every async action and backend idempotency path. |
| 30 | Predictable navigation | source reviewed—runtime pending | Root/router and both role shells reviewed; deep links, back stack, and restored tabs still need runtime verification. |
| 31 | State-driven actions | needs product decision | Booking cards gate cancel/result/refund actions by lifecycle; pending-booking cancellation is hidden while payment confirmation or refund processing is unresolved, with confirmed bookings using the dedicated cancellation/refund flow. Team-league fixture UI exposes booking before result entry and waits until scheduled kickoff for result submission. The RPC still lacks a matching server-side time/booking guard; approval required for SQL enforcement. |
| 32 | Safe destructive actions | source reviewed—runtime pending | Pending-booking cancellation now requires explicit confirmation and explains that the slot will be released; other destructive actions still require review. |
| 33 | Touch ergonomics | source reviewed—runtime pending | Shared bottom navigation items are 58dp high; back button, pending-booking cancel icon, match-result dialog close control, owner payout full-balance action, tournament bracket dialog actions, and pending-booking check-status/resume-payment actions have minimum 48dp targets. Verify all remaining controls and spacing. |
| 34 | Form resilience | source reviewed—runtime pending | Create-team fields and challenge-code capitalization/keyboard actions remain; manual roster-import dialog now disposes its controller after close. Full focus/autofill and device keyboard pass pending. |
| 35 | Scroll and modal safety | source reviewed—runtime pending | Grouped fixes include scrollable player/owner onboarding exits, championship error and matchup closure dialogs, owner/player account deletion/sign-out dialogs, roster import, and tournament round reset. Match-details loading/error/not-found views are now system-safe-area protected; Additional source fixes: explicit `useSafeArea: true` on player championship-governorate, booking-calendar, payment-verification, payment-cancel, password-reset, chat, owner payout, owner stadium wizard, and owner booking-cancellation dialogs; payment-verification content now clamps to the viewport and scrolls. Four owner tournament dialogs and six player dialogs now explicitly set `useSafeArea: true`; remaining surfaces and keyboard/device layouts still need runtime validation. |
| 36 | Feedback recovery | source reviewed—runtime pending | Notification stream errors, team/profile/team-league reads, fee-policy lookup, live matchup team/results reads, owner tournament team-list reads, owner inbox, owner ledger, global search, match details, player home feeds, owner tournament brackets, and favorites distinguish initial failure from empty/missing states and/or preserve stale data with localized retry; the player home notification badge surfaces unread-stream errors; ledger summary failures are caught and cannot masquerade as a zero balance. Verify all critical flows and draft preservation. |
| 37 | Consistent gestures | source reviewed—runtime pending | Notification swipe-to-dismiss is explicit and has Undo; verify discoverability and ensure critical actions have non-gesture alternatives. |
| 38 | Single source of truth | needs product decision | Player/owner booking views wait for authoritative snapshots; booking sync, stadium fetches, team/league reads, and notification actions reject stale callbacks after account/scope changes. Team profile and team dashboard distinguish missing data from failed reads. Product decision remains open for explicit active-team selection/default when a user belongs to multiple teams; no arbitrary membership order was changed. Verify all displayed booking/payment/refund values against server records; runtime coverage remains pending. |
| 39 | Role-based relevance | needs product decision | Copilot remains owner-gated; result actions in both home and booking cards require captain identity for a participating team, suppress dual-side captain actions, and recalculate on account changes. Owner schedule is hidden outside owner role. Team League active-league reads remain an approval-required authorization finding (TL-02): live source inspection of `public.get_team_active_league(uuid)` shows SECURITY DEFINER, EXECUTE granted to authenticated, and no `auth.uid()` membership/creator authorization before returning the league payload, including team captain phone numbers. A caller can supply an arbitrary team UUID; the RPC must be redesigned to enforce membership/creator scope (and minimize returned PII) before it remains callable. Fixture generation is currently service-role-only in the live database. Audit other role boundaries. |
| 40 | Lifecycle consistency | source reviewed—runtime pending | Player booking details/cards distinguish booking lifecycle states; challenge result prompts now compare team IDs to team IDs, and a mismatched result is described as waiting for the other captain (matching the atomic RPC) rather than an admin dispute. Full lifecycle consistency remains pending. |
| 41 | Persistent communication | needs product decision | Opening marks read, not delete; swipe-to-dismiss deletes and Undo restores the original payload/time. Delete/Undo callbacks are bound to the originating account. UI stream is capped at 50; no DELETE trigger or retention cron was found. Refund notifications are emitted only after refund ledger recording succeeds; a durable reconciliation notification retry remains a server-side gap. Notification retention/archive policy also remains a product decision; no retention or schema behavior was changed. |
| 42 | Design-system governance | source reviewed—runtime pending | V2 tokens/shared components are canonical; the current register contains 338 unique Dart paths across 366 table data rows (28 repeated path rows), plus one shared navigation component. The historical 128-file heuristic scan has not been rerun against the current register; the full 44-rule × screen × state mapping remains incomplete. |
| 43 | Operational observability | source reviewed—runtime pending | Booking/owner actions, team-league create/join/cancel/outcomes, prize handover, GPS lookup, cash booking, score submission, and participant management separate technical diagnostics from localized user errors. Audit observability for trusted service-role fixture generation and all remaining critical failure surfaces; direct authenticated fixture-generation execution is absent in the live ACL. |
| 44 | Optimal cognitive load | source reviewed—runtime pending | Owner dashboard tabs/analytics feedback and checkout loading/error states reviewed; refund and plan surfaces are scroll-bounded. Motion intensity and real-device cognitive-load validation pending. |

## Findings fixed in this batch (runtime pending)
### Analyzer remediation follow-up — 2026-10-31

The CI run on commit `35b50e4286a6aaf17d56188cc5efac64c3182288` reached `flutter analyze` and failed with 14 analyzer findings. Dependency installation, localization generation, and the Firebase options presence check succeeded. The 14 findings were:
- 2 unused fields in `booking_confirmation_screen.dart`
- 1 deprecated bottom-navigation metrics alias use in `owner_cup_screen.dart`
- 1 missing-braces style finding in `owner_dashboard_screen.dart`
- 2 missing-braces style findings in `challenge_select_team_screen.dart`
- 5 missing-braces style findings in `payment_gateway_screen.dart`
- 1 missing `const` in `team_league_tab.dart`
- 1 missing `const` in `payment_countdown_header.dart`
- 1 missing-braces style finding in `payment_gateway_screen.dart` checkout account guard (identified while reconciling the log)

Source cleanup was committed in `f0b04981bbe3862dec277d018f1db16cb6e1517b` and `d18f224f5cb934dae30cb6c086d67e0be9ab8402`: removed the unused fields, switched the owner cup FAB offset to the canonical metrics source, added braces to the flagged control-flow statements, and applied the missing const constructors. **These changes are not analyzer-verified yet** because the available workflow run belongs to the earlier commit; the branch's next consolidated CI/analyzer run must verify them.

The CI run stopped at Analyze; automated tests and APK build were skipped. No test pass or APK artifact was produced.


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

1. Complete screen-by-screen rule mapping for all 208 registered unique paths, the 26 separately tracked repeated embedded-component findings, and applicable state variants.
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
- Team profile now distinguishes a genuinely empty member-ID list from a non-empty membership list whose public profile query returns no rows; the latter shows roster-unavailable/retry instead of the false “no players” empty state.
- StadiumProvider.dispose now invalidates both scope and discovery request generations and clears the owner scope before canceling the stream, so late in-flight fetch/Realtime callbacks cannot notify or mutate a disposed provider.
- Booking confirmation team context now watches AuthProvider and invalidates in-flight/post-frame lookups on account changes, so a team ID from the previous signed-in user cannot be attached to a new user's booking draft.
- BookingConfirmationHandler now verifies the authenticated Supabase user still matches the user model before starting and after each asynchronous location/availability/active-booking lookup. A mid-flow account switch aborts before the draft is routed to payment or cash booking.
- Payment gateway now binds pending-booking creation, Paymob checkout, booking Realtime/polling, tournament-order polling, and webhook completion to the account that opened the screen. On account change it cancels timers/subscriptions, closes only the verification modal (without accidentally popping the payment route), and replaces checkout details with a paused/recovery state.
- Payment source-of-truth review found the `Booking` model did not map the server's `needs_deposit` or `deposit_amount` columns; it only mapped `deposit_paid` (the amount already collected). Checkout therefore displayed the client draft total/deposit even after the server had recalculated and created the booking. Added distinct `needsDeposit`/`depositAmount` model fields and mapper support; normal checkout now waits for the server-created booking and uses its total/deposit for the fee breakdown and Paymob request. Tournament orders continue to use their order draft path. No DB schema change was made.
- Refund cancellation UI previously guessed the refund as `total_price` whenever `refund_amount` was null, even when no payment had been collected; the server actually calculates the refundable amount from completed transaction rows during cancellation. RefundInfo now distinguishes no payment, a server-confirmed amount, and an amount not yet known. The pre-cancel dialog and tracking sheet no longer show a guessed total/zero transfer; they state that the server will confirm the amount after processing. No cancellation RPC or refund policy was changed.
- Read-only inspection of `process_paymob_refund` showed some `success:false, refund_pending:true` responses occur after the Edge Function has already persisted `bookings.status='cancelled'` (e.g. refund queued or no refundable Paymob transaction routed to review). The client previously reported cancellation failure and skipped participant/owner cancellation notifications. It now verifies persisted booking status for non-manual-review pending responses and reports success only when cancellation is actually persisted; manual-review cases that did not cancel remain failures.
- Owner manual-booking cancellation now also inspects the RPC's returned `success:false` payload before notifying participants/owner; a non-throwing business rejection is no longer treated as a successful cancellation.
- BookingProvider no longer drops every successfully cancelled booking from the player's list. It reloads the server-confirmed cancelled row and keeps it in history, where `refund_pending`/confirmed refund state can remain visible; only a missing/unreadable row falls back to removal.

- **Refund notification gap — source verified, server fix pending:** `process_paymob_refund` inserts the in-app refund notification only after `record_booking_gateway_refund_atomic` succeeds. If Paymob confirms but that accounting RPC fails, the Edge Function returns `refund_pending` before inserting a notification; if the notification insert itself fails, it only logs the error and does not enqueue a retry. The booking now remains visible in history with its refund state, but proactive notification is not guaranteed in these branches. Proposed fix: an idempotent refund-notification outbox/retry tied to refund reconciliation, plus a truthful “refund under reconciliation” notification when Paymob has confirmed but ledger recording is pending. This requires server/DB workflow changes; no SQL or Edge Function changes were applied in this pass.

- A second targeted scan across the 128 registered Dart screen/surface candidates found 22 additional currentUser.uid reads in 14 files where the Supabase compatibility extension was not imported. All were corrected to native User.id. The scan is limited to the registered candidates; it is not represented as a repository-wide scan.
- Create-team sheet had mixed-language helper/error copy and showed a success message before the backend had created the team. Copy is now Arabic/English, premature success feedback is removed, text input behavior is explicit, and async callbacks check widget lifetime.
- Owner dashboard analytics previously showed Arabic-only error copy regardless of locale and had no local retry action; it now shows localized retry guidance and ignores stale responses from superseded filters/account scopes. Its dashboard segment switcher was 42dp high and is now 48dp.
- Stadium details previously swallowed Realtime errors and JSON parsing failures while silently presenting cached stadium data as current. It now identifies stream/empty/parse failures, labels cached content as last available information, and allows a localized retry.
- Match report submission previously dereferenced auth.currentUser after the dialog had opened and allowed repeated taps. It now captures the authenticated reporter ID before opening, disables duplicate submission/cancel while submitting, and reports the result through the parent screen context after closing.
- Payment fee parsing now treats missing VSP/gateway/fixed fee fields as invalid instead of silently converting them to zero; retry requests use a generation guard so an older fee-policy response cannot overwrite a newer retry. The countdown unit is localized in English as well as Arabic.

- Subscription plans were previously rendered with hardcoded prices, trial duration, stadium limits, descriptions, and feature lists. The deployed public_subscription_plans view was inspected read-only and the current catalog confirmed Basic=0 EGP/1 stadium and Pro=1,000 EGP monthly/11,000 EGP annual/3 stadiums/7 trial days. The app now fetches that public catalog, derives feature labels and entitlements from its feature JSON, fails to a localized retry state instead of showing stale prices, and exposes the supported annual billing period ('annual') alongside monthly with the calculated savings. No DB change was made.
- Tournament roster loading previously converted read failures into an ordinary editable-looking roster state. It now exposes a distinct localized load-error/retry state, prevents saving while the roster is unverified, and sanitizes save failures. WhatsApp import checks widget lifetime after its async dialog.
- Booking payment-method and manual tournament-team flows no longer display raw exception strings to end users; failures use localized, actionable generic copy while diagnostics remain in logs.

- Booking type selection previously used a catch-and-return-null team lookup, so a temporary Supabase failure could be misread as 'no team' and open team creation. Challenge selection now requires an authenticated user and uses the strict lookup; lookup errors surface a localized recovery message and do not mutate the booking draft.
- Player booking refund badge previously fell back from a missing server refund amount to deposit_paid or total_price. It now treats the server's refunded payment status as authoritative while leaving a missing amount unconfirmed; no client-estimated refund value is displayed.
- Refund tracking sheet is now height-bounded and scrollable so the close action remains reachable on compact devices and with large text.
- Payment fee information now has a 48dp touch target and tooltip. Payment-exit copy no longer guarantees a refund/charge outcome when a payment attempt may still be awaiting server confirmation.
- Tournament roster read errors no longer fall through to an editable-looking empty roster; they have a distinct retry state, save is disabled until verified, and raw backend error text is not shown.

- Challenge selection now distinguishes team lookup loading, verified no-team, and lookup failure. It follows the signed-in account, retries stale/error lookups, offers team creation only for a verified no-team result, and re-verifies the user's team before continuing; the Continue action is disabled until a team and opponent are both verified. Challenge success/error copy is bilingual.
- Championship registration now uses strict team lookup. A query failure no longer masquerades as a missing/incomplete team and no raw exception is rendered to the player.
- Payment gateway booking initialization and match joining now use localized generic failure copy rather than exposing repository/provider error strings to the user; diagnostic detail remains in logs.

- The remaining 18 rules were source-reviewed against representative high-risk player/owner flows and moved from 'not yet inspected' to 'source reviewed—runtime pending'. This is not a pass: every registered screen/surface still needs its own applicable-rule review, and no rule is marked pass until device/runtime validation is complete.
## Source remediation continuation — 2026-10-31

The following additional source-level corrections were made on `uxlp-44-implementation`. These are not runtime passes; all 44 rule statuses remain **source reviewed — runtime pending** until the consolidated validation gate.

- **Rules 9, 36, 38, 43 — discovery and recovery:** paginated stadium queries now propagate repository failures instead of returning a false empty list; the provider records a generic recovery state, and the all-stadiums surface displays a localized retry state or a non-blocking refresh warning while retaining the last loaded results.
- **Rules 20, 25, 38 — filtering and data integrity:** sport, team-size, price, governorate, floor-type, search, amenities, and quick-filter predicates are applied in the Supabase query before pagination. Sport and size filters now use the actual `description`/`notes` sport tag and `players_per_team` columns. Amenity predicates use the `features` JSONB field; no-deposit uses `needs_deposit`/`deposit_amount`; night-shift uses the PostgreSQL `closing_time` TIME column with legacy working-hours fallback. The available sport list no longer depends on the first page.
- **Rule 38 — refresh truthfulness:** all-stadiums refresh and retry re-run the active server query without clearing the last authoritative page first; pagination uses the same server-side filter set.
- **Rule 17, 18, 38, 43 — finance accuracy:** the owner withdrawal balance is shown only when the financial-summary response is successful and contains a parseable numeric balance; otherwise the UI explicitly says the balance is unavailable instead of presenting an unverified zero.
- **Rule 42 — design-system governance:** `VSPBottomNavMetrics` is the canonical bottom-navigation geometry source. Previous names remain deprecated value-only compatibility aliases during migration. `OwnerOperationalFinanceCard` is the canonical owner finance surface; parallel legacy finance cards are deprecated.
- **Rules 7, 11, 33, 44 — responsive behavior:** the team hero card no longer imposes a maximum height that can clip enlarged text; its stat columns and footer now flex within the available width.
- **Rules 29, 35, 36 — interaction correctness:** malformed duplicate source appended to the booking query coordinator was removed; booking slot handlers were restored; location-picker cleanup was returned to the owning sheet method; async notification context guards were corrected; result submission now returns its real success value and avoids double-pop; missing payment checkout import and league team arguments were restored.

**Still pending:** complete screen-by-screen rule mapping for every registered surface and embedded widget; Arabic/English and RTL/LTR review; compact-device, keyboard, large-text, safe-area and modal runtime checks; final consolidated validation. No final test or APK build is authorized at this checkpoint.


## Phase 2 implementation batch — shared tokens and owner tournament recovery

- **Rule 5 / Rule 42 — one icon language and design-system governance:** the legacy `vsp_tokens.dart` facade now explicitly re-exports the canonical `VSPBottomNavMetrics` declaration from `vsp_design_tokens.dart`. This preserves one geometry source while allowing existing feature files that import the compatibility facade to resolve the canonical symbol. It does not introduce a second value or duplicate geometry definition.
- **Rule 9 / Rule 36 — state visibility and feedback recovery:** the owner tournament list now distinguishes an initial stream failure from a successful empty result. It presents the shared localized `VSPErrorState` with retry, and it does not replace a previously delivered snapshot with an empty list when a later stream refresh is still pending or fails.
- **Rule 11 / Rule 35 — responsive and modal-safe state recovery:** the owner tournament error surface reuses the shared scroll-safe state component instead of a bespoke fixed-height error dialog. Runtime sizing remains part of the later approved validation phase.

These are source changes only. They do not change tournament eligibility, status mapping, database behavior, or business policy. No CI, analyzer, automated tests, runtime tests, or APK build were run.


## Phase 2 implementation continuation — compact state views

- **Rule 11 — Responsive legibility:** the shared `VSPStateView` loading, error, offline, empty, pending, processing, success, and disabled presentations now use a bounded-width scroll container. Long bilingual copy and enlarged text can scroll instead of forcing the state column to fit a short viewport.
- **Rule 35 — Scroll and modal safety:** the same shared state component now preserves access to retry/action controls when the available height is constrained. This is a source-level layout correction; no runtime pass is claimed.
- **Rule 3 / Rule 6 — Contrast and color semantics:** existing neutral empty/disabled charcoal treatment and semantic error/offline tint remain centralized and unchanged; the responsive wrapper does not introduce feature-level colors.

The owner tournament screen also now keeps its last non-empty tournament snapshot visible after a realtime refresh error and shows a localized retry warning; an initial failure or an empty snapshot followed by failure uses the shared error state instead of presenting a false empty result.

No automated checks, CI, runtime tests, or APK build were run.


## Phase 2 implementation continuation — multi-surface source changes

The following additional changes were committed to the working branch. They are source implementation evidence only; they do not mark any rule as a pass.

- **Rules 9, 36, 38, 43 — authoritative data and recovery**
  - Player profile team lookup now uses the strict membership query. A Supabase failure is no longer silently converted into a no-team/free-agent card; it displays a localized retry state. The lookup is cached per authenticated user and refreshed after team management/create flows.
  - Player notifications now retain the last non-empty list during realtime refresh failure, display a localized stale-data warning/retry, and avoid showing a false empty state on an initial failure.
  - Notification streams reset when the authenticated account changes, preventing a previous account's notification snapshot from being carried into the next account's view.
  - Public match gathering now retains the last loaded list during stream refresh failure and exposes a retry action; an initial failure no longer appears as a no-matches empty state.
  - Support-ticket metadata and message streams now distinguish initial load failure from refresh failure, preserve previously loaded messages, and expose bilingual retry guidance.
  - Owner dashboard financial summary invalidates its previous withdrawal-balance snapshot during refresh and rejects late responses from a different request/account. Owner championship stream errors now preserve last loaded data and show a retry banner.

- **Rules 11, 27, 33, 35 — responsive and accessible interactions**
  - Stadium filter category tabs expose selected semantics and have a minimum 48dp row height.
  - Owner booking calendar controls have minimum 48dp targets; day choices expose their full localized date and selected state and use focusable InkWell interaction.
  - Stadium filter sheets account for keyboard insets and bounded height; the price filter uses an accessible CheckboxListTile.
  - Saved price ranges are normalized before slider construction so malformed/reversed persisted ranges cannot create invalid slider state.
  - Shared bottom navigation now uses InkWell interaction inside its existing selected-state semantics.
  - Owner dashboard and team dashboard segmented tabs expose selected semantics and focusable interactions.

- **Rules 17, 18, 25, 38, 43 — data and transaction clarity**
  - Add-player phone search now uses a strict repository lookup. Invalid phone input is rejected, and a failed query no longer masquerades as an unregistered number and incorrectly offers an external invite.
  - Support escalation now reports when the WhatsApp support channel is unavailable or cannot be opened rather than silently swallowing the failure.

All 44 UXLP rule statuses remain **source reviewed—runtime pending**. No CI, analyzer, automated tests, runtime tests, database migrations, or APK builds were run.


## Phase 2 implementation continuation — notification actions and owner scope

- **Rules 28, 36, 41, 43 — notification persistence and feedback:** notification read-state repository methods now return explicit success/failure. Mark-all and mark-one failures are surfaced with localized feedback; opening a notification does not invoke deletion, and a failed read-state update explicitly tells the user the notification remains in the list. The challenge action waits for the read-state operation before navigating.
- **Rules 38, 39, 40 — owner account isolation:** owner dashboard requests and realtime subscriptions now rebind to the authenticated owner scope. Finance, analytics, championships, approval notices, selected filters and metric cache are cleared when the owner scope changes; delayed responses from an earlier owner are ignored.
- **Rules 27, 33 — accessible controls:** add-player search now has a localized semantic label, tooltip and focusable InkWell target.

**Important boundary:** these client changes improve persistence visibility and error feedback. They do not prove the root cause of the previously reported notification disappearance has been eliminated; that requires evidence from the actual database/realtime session, which is not being run in this implementation phase.


## Phase 2 continuation — support, notification delivery, and shared interaction polish

Additional source changes committed after the prior batch:

- **Rules 9, 36, 38, 43 — support ticket stream truthfulness:** support-ticket list stream is now retained between widget rebuilds, rebound on account changes, and recreated only on explicit retry. An initial empty error is no longer presented as a verified empty list. A refresh error preserves previously loaded tickets and shows a localized warning/retry.
- **Rules 10, 13, 41 — notification bilingual integrity:** notification detail dialogs now use the same locale-specific metadata as notification cards; long titles can wrap to two lines instead of being truncated after one.
- **Rules 27, 33 — shared touch and keyboard affordance:** language rows now use focusable InkWell, selected semantics and 56dp minimum height; the shared back button uses InkWell while retaining a 48dp-or-larger hit area, localized semantics and haptics. The shared animated button now visibly enters its disabled appearance during the existing debounce window rather than appearing active while rejecting taps.
- **Rules 18, 36, 41, 43 — push dispatch reliability:** the FCM queue worker now checks the push function's HTTP result and leaves failed dispatch messages unarchived for PGMQ visibility-timeout retry. The sender returns HTTP 502 when every device send fails. Queue notification identifiers are preserved in FCM data using the trigger's `notification_id` field when no row `id` is present.

**Delivery semantics note:** the queue remains at-least-once; if a push succeeds but archiving fails, a later retry can duplicate the push. This batch does not alter queue schema, retry limits, notification retention, or user-facing notification deletion policy.

All 44 rule entries remain source reviewed/runtime pending. No CI, analyzer, tests, runtime checks, migration, or APK build were run.


## Phase 2 continuation — account-scoped navigation and support form affordance

- **Rules 4, 13 — typography and copy consistency:** FAQ question titles now use the shared theme title role; the no-team player profile uses the same explicit localized missing-position copy as the player header.
- **Rules 27, 28, 33 — message composer affordance:** support-ticket send action now has a localized tooltip, a 48dp minimum target, and remains visibly disabled until non-whitespace text is entered or while a send is in progress.
- **Rules 38, 39, 40 — account and role isolation:** player tab restoration is now stored per authenticated Supabase user; switching player accounts resets the tab and loads only that account's saved selection. Deep-link tab navigation persists under the active account. Owner shell navigation resets to its dashboard when the owner identity changes.

All changes are source-level. Rule statuses remain runtime pending; no CI, analyzer, automated tests, runtime validation, migrations, or APK build were run.


## Phase 2 implementation additions — 2026-10-31 (source only)

- **Rules 3, 6, 27, 33 — team roster affordances:** the create-team member empty state now uses a charcoal square icon container and readable secondary text rather than near-transparent foregrounds. Member removal now has a localized tooltip and 48dp target.
- **Rules 9, 10, 11, 35, 36 — invitation and modal recovery:** private collective invitation loading now distinguishes a failed backend read from a genuinely unavailable invitation. Failed refreshes preserve an initial booking snapshot with a localized stale-data banner and retry; a failed initial read has a dedicated localized retry state. Leave/remove/cancel confirmation dialogs are scrollable. Terms/privacy dialog height now accounts for keyboard insets, and payment-exit copy is scrollable.
- **Rules 11, 27, 30, 33, 42 — shared navigation and action components:** bottom navigation exposes one selected/button semantic node instead of duplicate wrapper/InkWell announcements. Terms/privacy close action now has a 48dp hit target. Canonical primary-button labels can wrap to two lines. Shared PrimaryButton always releases its debounce state even if a synchronous callback throws.
- **Rules 11, 34, 35 — create-team sheet:** the available sheet height now subtracts keyboard and top safe-area insets before laying out the scrollable form and fixed actions; bottom padding no longer adds the keyboard inset twice. Subtitle wrapping is explicit.

All entries in the 44-rule matrix remain source reviewed—runtime pending; these touchpoints do not constitute whole-app rule completion. No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.


### Support retry lifecycle follow-up — 2026-10-31

- **Rules 9, 36, 38 — support recovery:** retry controls in support-ticket detail now recreate the retained account-scoped ticket and message streams rather than rebuilding against the same failed stream instances. The support-ticket list's stale-data retry also creates a new stream subscription. This closes a source-level retry wiring gap found while tracing the reported support flow; runtime reconnection remains pending.


### Support and date-picker interaction follow-up — 2026-10-31

- **Rules 10, 13, 36, 43 — support escalation and collective match feedback:** support contact fallback no longer exposes an internal localization key; it now gives a clear Arabic/English message. Collective match join/leave/manual-player update/remove/cancel failures now show localized recovery copy while logging technical exceptions separately. Support ticket creation exceptions are logged separately from its user-facing error message.
- **Rules 27, 33, 34 — date picker and phone lookup:** date-picker year/month/day rows and step chips now use focusable Material InkWell interactions. Add-player phone lookup uses LTR input direction and the keyboard Search action invokes the same guarded lookup.

These are additional source touchpoints only; no rule is promoted to whole-app complete and runtime evidence remains pending.


### Profile and support surface follow-up — 2026-10-31

- **Rules 11, 27, 33, 35 — profile interaction/sheet:** profile team-card navigation now uses focusable Material interaction; the governorate picker is bounded to the visible viewport so its internal list can scroll.
- **Rules 9, 36, 43 — support retry and diagnostics:** support-ticket detail/list retries now recreate the failed stream subscriptions rather than rebuilding around the same stream; ticket creation and collective-match action failures log technical details separately from localized user copy.
- **Rules 10, 13 — support copy:** missing support contact configuration now produces explicit Arabic/English user-facing text instead of an internal localization key.

Source touchpoints only; no whole-app rule is marked complete and runtime validation remains pending.


### Owner booking and collective-share follow-up — 2026-10-31

- **Rules 9, 11, 35 — owner booking sheet:** the owner manual-booking/edit sheet now sizes against the viewport after keyboard and both safe-area insets; keyboard height is no longer added again to its internal bottom padding.
- **Rules 18, 36, 43 — action failure feedback:** collective invitation share failures and owner no-show report failures now keep technical details in logs and show concise localized recovery copy.


### Booking and collective navigation feedback follow-up — 2026-10-31

- **Rules 11, 35 — owner booking viewport:** owner manual-booking sheet now accounts for keyboard and both safe-area edges in its maximum height and avoids double-counting keyboard inset in bottom padding.
- **Rules 18, 36, 43 — collective action recovery:** invite share credential lookup, external share launch, and stadium-map launch now have guarded failure handling, technical logs, and localized user-facing recovery copy.


### Support send account-race correction — 2026-10-31

- **Rules 38, 39, 41, 43 — support message ownership:** support message submission now captures the originating account generation. A response from an earlier account cannot clear a newly active account's draft, surface stale errors in that account, or reset a newer send's loading state. Technical send failures are logged separately.


### Authentication retry/realtime account isolation — 2026-10-31

- **Rules 38, 39, 41 — auth profile ownership:** profile retry responses now carry a request generation and are discarded if the authenticated account changes before completion. Returned profile UID must match the requested Supabase user ID. Realtime profile callbacks also verify the active auth ID and payload UID before updating the shared user model.


### Shared action cooldown reliability — 2026-10-31

- **Rules 28, 29, 36 — shared animated action:** VSPAnimatedButton now releases its cooldown in a finally block even if its synchronous action callback throws, matching the hardened PrimaryButton behavior and avoiding a permanently absorbed control.


### Date-picker selection semantics — 2026-10-31

- **Rules 27, 33, 34 — date selection accessibility:** date-picker step chips and year/month/day choices now expose one semantic button each, including the selected state, value, and disabled state for unavailable steps; their InkWell surfaces remain keyboard/focus interactive.


### Championship empty-state viewport and touch sizing — 2026-10-31

- **Rules 11, 27, 33, 35 — championship states:** the 1v1 governorate banner's return action now has a 48dp minimum target. Championship, tournament, team, and 1v1 no-governorate empty-state content can scroll vertically on compact viewports and large text settings rather than overflowing its centered layout.


### Segmented-control and venue-filter interaction pass — 2026-10-31

- **Rules 5, 27, 30, 33, 42 — owner/player tab controls:** Owner Pro segmented tabs, owner venue filter chips, and championship pill tabs now use focusable InkWell interactions with one semantic button per option and selected-state announcements. Their interactive surfaces meet a 48dp minimum height; Owner Pro track geometry was increased to preserve the selected pill's touch area.


### Support ticket creation sheet viewport — 2026-10-31

- **Rules 11, 35, 36 — support modal safety:** the new-ticket sheet now constrains itself to the remaining viewport after keyboard and safe-area insets; its subject/category/action content remains scrollable and the keyboard inset is not duplicated in inner bottom padding.


### Owner payout and upgrade modal viewport pass — 2026-10-31

- **Rules 11, 16, 17, 35 — financial dialogs/sheets:** owner payout dialogs now explicitly scroll long copy and form content. Password re-authentication sheet constrains its height after keyboard and safe-area insets. Facility-upgrade sheet respects both safe-area edges and remains scrollable within the visible viewport.


### Payout re-authentication recovery — 2026-10-31

- **Rules 10, 18, 28, 36, 43 — financial security form:** payout password empty/incorrect/network feedback is now bilingual. A thrown re-authentication error is logged and restores the form's retryable state rather than leaving the verification button stuck loading; incorrect-password copy explicitly states that no financial change was saved.


### Payout submission exception recovery — 2026-10-31

- **Rules 28, 29, 36, 43 — payout request action:** if the payout repository call throws, the payout dialog now restores the submit control, logs the technical exception, and displays localized retry guidance instead of remaining indefinitely in a loading state.


### RTL alignment corrections — 2026-10-31

- **Rules 7, 10, 30, 42 — directional layout:** owner booking form labels and owner venue-chip spacing now use directional start insets. Shared bottom-navigation unread badge now anchors to logical end, mirroring correctly in Arabic RTL and English LTR.


### Upgrade benefit promise correction — 2026-10-31

- **Rules 13, 18 — truthful subscription copy:** facility-upgrade benefits no longer promise 24/7 owner support; the Arabic and English descriptions now state priority access without asserting an unsupported service-level guarantee.


### Subscription comparison promise consistency — 2026-10-31

- **Rules 13, 18, 23 — plan comparison truthfulness:** the subscription-plan comparison also no longer promises 24/7 technical support; its Arabic/English benefit text now matches the non-guaranteed priority-access wording used in the upgrade sheet.


### Payout rejection copy normalization — 2026-10-31

- **Rules 13, 18, 36, 43 — payout RPC feedback:** rejected payout responses are logged and normalized through the centralized error formatter; expired-session errors receive bilingual re-authentication guidance instead of exposing raw technical payloads.


### Shared control semantic de-duplication — 2026-10-31

- **Rules 27, 33, 42 — accessibility semantics:** shared back navigation and add-player search now expose one explicit localized semantic control each; nested InkWell semantics are excluded to avoid duplicate announcements.


### Notification list safe-area and RTL swipe correction — 2026-10-31

- **Rules 7, 10, 11, 32, 42 — notification center:** removed duplicate bottom safe-area spacing because the list is already inside SafeArea; retained intentional list breathing room. Swipe-to-delete background now uses directional alignment and padding so its affordance mirrors correctly between Arabic RTL and English LTR. This does not alter notification retention or deletion policy.


### Notification and cancellation dialog responsiveness — 2026-10-31

- **Rules 7, 10, 11, 26, 33, 35, 42 — player notification/cancellation surfaces:** notification list no longer double-counts the device bottom inset and its swipe-delete affordance mirrors in RTL/LTR. Booking cancellation dialog actions stack into full-width 48dp controls below 360dp available width; wider layouts retain the side-by-side arrangement. No cancellation/refund business logic was changed.


## Grouped source remediation and CI evidence — 2026-10-31

The following source defects were found in existing PR-triggered CI run [41221229970](https://github.com/mohamedsalh333555/VSP.App/actions/runs/41221229970). The job reached `flutter analyze` after dependency installation, localization generation, and Firebase-options presence checks succeeded. Analyze reported three errors plus a warning and two informational lints; tests and APK build were skipped.

- `owner_payout_dialog.dart`: replaced the unrelated State `mounted` guard with `context.mounted` before using the dialog context after the awaited payout callback.
- `add_player_sheet.dart`: removed the invalid `const` from a localized dynamic Text label.
- `all_stadiums_filter_sheet.dart`: restored the missing closing delimiter in the nested safe-area/scroll layout.
- `challenge_select_team_screen.dart`: added braces around the retry guard.
- `auth_provider.dart`: removed the write-only `_isFetchingUser` field and its assignments.
- `vsp_date_picker_step_views.dart`: removed unnecessary interpolation from the day semantic label.

The next already-started PR CI run, [41222072722](https://github.com/mohamedsalh333555/VSP.App/actions/runs/41222072722), completed dependency/localization/Firebase checks and reached Analyze. It failed only on one informational `prefer_const_constructors` finding at `add_player_sheet.dart:355`; tests and the workflow's debug APK step were skipped. The remaining const style issue was corrected in commit `1019b34c03e440ad28f365c04d07f1d11c40f70c`. That final one-line cleanup has not yet been analyzer-verified.

A further source-only truthfulness fix removed the hardcoded `1,000 EGP/month` claim from the owner dashboard Pro teaser. Current prices remain displayed by the subscription screen from the public plan catalog; the teaser now only says “Upgrade to Pro”. This does not change plan pricing or entitlements.

These findings are implementation evidence only. No rule has been promoted to `pass`; all 44 rule rows remain runtime-pending and the final consolidated validation gate is still closed.


### Tournament action-state and 1v1 locale follow-up — 2026-11-01

- **Rules 10 and 42 — 1v1 empty state:** the component accepted an explicit `isArabic` value but previously delegated to a renderer that independently read the device locale. The shared empty-state renderer now supports an explicit locale override, and the 1v1 caller passes its supplied locale through. This keeps the displayed copy consistent with the parent-selected locale.
- **Rules 27, 29, and 31 — owner tournament dashboard action bar:** fixture-navigation actions are now disabled while the tournament mutation is loading, matching the loading/disabled behavior of the primary state-changing action and preventing navigation away during an in-flight operation.
- These are source corrections only. Locale switching, loading interaction, and navigation behavior remain runtime pending; no tournament lifecycle or backend rule was changed.

### Championship filters and owner navigation feedback — 2026-11-01

- **Rules 27 and 33 — championship filters:** governorate and sport dropdown containers were constrained to 44dp. Their minimum height is now 48dp, matching the touch-target baseline.
- **Rules 9, 28, 36, and 42 — owner bottom navigation:** unread-count stream failures previously collapsed to `snapshot.data ?? 0`, making unavailable data look like a verified zero. The shared navigation item now supports an amber warning indicator and accessible warning label; the owner chat item uses it when the unread stream reports an error. Any last delivered unread count remains visible if the stream errors after data.
- These are source-level corrections. Compact-device hit testing, RTL rendering, assistive-technology announcements, and live stream failure/recovery remain runtime pending. No chat or notification data policy changed.

### Championship/1v1 embedded component reconciliation — 2026-11-01

Recursive inspection of `lib/features/player/widgets/champion` found nine additional embedded surfaces absent from the screen register: the podium/filter component, championship list tab, team ranking tab, 1v1 league tab, and five 1v1 hero/prize/action/roster/standings components. They have been added as source-reviewed/runtime-pending rows. The current register now contains **208 unique Dart paths and 234 rows**, including the existing 26 repeated-path findings.

Source corrections in this group:
- Championship and team-ranking tabs now retain non-empty last-known data when their streams fail and show an explicit localized retry warning. The championship error state no longer tells users to pull-to-refresh when no pull-to-refresh control is present.
- Selecting the “All governorates” filter no longer triggers the misleading “viewing another governorate” banner or return action.
- The 1v1 tournament, roster, and standings streams now distinguish unavailable data from a confirmed empty state. Failed streams with prior data preserve it and show a retry warning; standings retry now invokes the parent stream-recreation callback and no longer exposes raw backend exception text.
- 1v1 registration cancellation and governorate-switch controls now meet the 48dp minimum; the join action uses a null disabled callback and displays the shared loading state while payment is processing.
- The 1v1 roster now normalizes missing player names and displays an initial while avatar images load or fail, rather than leaving an empty image circle.
- The 1v1 hero card now displays the tournament governorate using the shared Arabic/English governorate translation, so the location value passed by the parent is no longer unused.
- These changes do not alter tournament registration, payment, refund, or scoring rules. Runtime validation remains pending.

## Product decisions and backend approvals still open

These findings are explicitly classified as **needs product decision**. They are not implementation defects that may be silently “fixed” in the client, and no SQL, Edge Function, permission, or business-rule change is authorized by this audit.

| Affected UXLP rules | Surface / contract | Decision required | Current safe behavior |
|---|---|---|---|
| 25, 39 | Team booking authorization in `create_booking_atomic` | Decide whether any team member or only the captain may create a team booking; also define which team is active when a user belongs to multiple teams. | Client verifies membership and does not invent a team-selection policy; server contract remains unchanged. |
| 19, 39 | Multi-team default selection | Decide whether users need an explicit active-team selector or a deterministic product-defined default. | Existing first-membership behavior is preserved and documented; no unordered selection policy is claimed correct. |
| 25, 31, 39, 40 | Challenge result eligibility in `submit_challenge_result_atomic` | Approve whether only confirmed/completed bookings may accept results and whether the second result must come from a different authenticated captain. | Client suppresses ineligible prompts and dual-side self-review; deployed RPC is unchanged. |
### Open product decision — notification retention

Define the intended retention/archive policy and explain historical disappearance before changing deletion or retention behavior. Opening marks read; explicit swipe deletion and Undo remain the client behavior. No retention trigger/cron was added. This remains a server-side product decision; no deletion or retention behavior was introduced.
| 18, 36, 41, 43 | Refund notification reconciliation | Decide the required durable notification/reconciliation behavior when Paymob confirms a refund but ledger recording or notification insertion fails. | Existing refund/ledger flow remains unchanged; no outbox table or migration was applied. |

Until each decision is supplied, affected rule/screen pairs must retain the `needs product decision` status rather than being marked `pass` or changed by assumption.


### Add-player sheet header resilience — 2026-10-31

- **Rules 11, 27, 33 — add-player sheet:** the title now flexes within the available header width, wraps to two lines, and cannot push the close action outside the row. The close action has a localized tooltip. Compact-width and enlarged-text runtime checks remain pending.


### Add-player sheet keyboard viewport correction — 2026-10-31

- **Rules 11, 35 — add-player sheet:** its maximum height now uses the available viewport after keyboard and system insets; the duplicate outer keyboard padding was removed and the content remains scrollable. Keyboard-open and device-inset runtime checks remain pending.


## Newly discovered shared and embedded surfaces — 2026-10-31

A top-level directory reconciliation initially found 35 shared/embedded Dart surfaces that were not represented as individual rows in the previous register. They were added to the inventory and reviewed in subsequent batches. The current register contains 181 unique Dart paths, with no rows currently marked `not yet inspected`. This inventory update does not satisfy the per-rule/state coverage gate and does not promote any rule to pass.


### Support ticket sheet action visibility correction — 2026-10-31

- **Rules 11, 35 — support ticket creation modal:** the maximum-height constraint now contains the outer padding and bottom safe-area inset, preventing those insets from being added beyond the available keyboard-safe viewport. The content remains scrollable. Compact-device and keyboard-open runtime checks remain pending.


## Nested championship detail surfaces — 2026-10-31

Recursive directory inspection of `lib/features/player/widgets/championship_details` found nine component files. Two were already represented in the register; seven were newly tracked. The bottom action bar source confirms that only `open` championships expose registration; `ongoing`, `completed`, `cancelled`, and full states route to view/disabled actions. All nine component paths are now represented as source-reviewed/runtime-pending in the register. The championship card was corrected to show ongoing/cancelled/unknown statuses without presenting them as joinable. These remain source-only changes; runtime and caller-state validation are pending.


### Match participant manager resilience — 2026-10-31

- **Rules 11, 17, 27, 33, 35, 42 — `ManageParticipantsModal`: keyboard-safe bounded height; explicit retryable lookup failure distinct from an empty list; localized action errors instead of raw exception text; wrapping header; localized tooltips and 48dp hit targets. Runtime validation remains pending.


## Shared component findings and corrections — 2026-10-31

The following source-level corrections were applied while expanding the component inventory. They are not runtime passes:

- **Touch target and semantics:** the terms checkbox now has a 48dp interactive box and checked/button semantics; compact visual density was removed from player match/championship share actions so their default hit targets remain 48dp.
- **Action feedback and error containment:** public match join, leave, request-cancel, and share paths now log technical exceptions and show localized user-safe feedback; the request-cancel boolean result is no longer ignored.
- **Notification state:** owner unread-count stream errors now have a warning indicator and localized tooltip, avoiding a false “zero unread” presentation.
- **Clipboard interaction:** phone copy has a semantic label and localized failure feedback.
- **Timer lifecycle:** tournament countdown stops ticking at zero and recalculates/restarts when its target changes.
- **Tournament lifecycle:** cards distinguish open, ongoing, cancelled, completed, full, and unknown/closed states; only the open state shows registration. The details bottom action bar independently confirms that gate.
- **Design-system API:** the compatibility facade now exposes V2 size and typography roles plus canonical black/transparent/white-alpha color aliases, so feature surfaces can consume shared tokens instead of defining duplicate values.

The team roster import control already displays `لصق` / `Paste`. The inventory is now 181 unique Dart paths and all registered paths have source-review notes. The 44-rule matrix remains runtime-pending; the final consolidated review has not started.


### Shared upload widget accessibility and resilience — 2026-10-31

- **Rules 17, 27, 33 — `VspUploadMainCard` / `VspUploadedItemRow`: semantic upload action with Material interaction; localized delete tooltip and 48dp hit target; empty thumbnail URLs treated as absent. Runtime assistive-technology and upload-flow validation remains pending.


### Join-request acceptance notification correction — 2026-10-31

- **Rules 18, 27, 41 — public-match join request:** acceptance now sends a dedicated localized notification to the requesting player with the related booking ID. The former host-oriented notification was being sent to the player with an empty player name. Notification delivery failure is logged separately from the already completed accept/reject action. Runtime delivery/tap-through checks remain pending.


## Championship detail loading and recovery states — 2026-10-31

The nested championship detail flow now has explicit source-level state handling:

- Match fixtures: initial loading is no longer shown as “no matches”; initial stream errors show the shared retry state; a stream failure after data preserves the last data and shows a stale/live-updates warning with Retry.
- Standings and top scorers: FutureBuilder errors now show localized shared error states with Retry rather than being interpreted as empty results.
- Retry is wired to recreate the matches stream and rebuild the standings/top-scorers futures from the parent screen.
- The nested header, pill tab bar, rules tab, governorate confirmation dialog, squad-builder sheet, matches tab, standings table, and top-scorers tab have source-review notes. Runtime, large-text, focus, and device layout evidence remain pending.

The 181-path inventory has no `not yet inspected` rows at this checkpoint, but this does not satisfy the per-rule/per-state coverage requirement. All 44 rule rows remain runtime-pending; no final consolidated review has started.


## Championship stream and standings cache follow-up — 2026-10-31

- Both championship and match streams can now be recreated through one retry callback; stale header/match data is preserved and visibly marked when live updates fail.
- A matches stream with no first event remains in loading state instead of showing the empty state prematurely.
- Standings futures are cached per group across match-stream emissions, avoiding repeated standings requests on every live update. A retry clears the cache and re-fetches.
- Group rendering is bounded to the supported A–H labels.
- These source changes do not alter tournament registration or scoring rules. Device/runtime verification is pending.


## Screen-level defect ledger — source correction complete, runtime pending

| Surface | UXLP rule | Source failure observed | Correction committed | Final status |
|---|---:|---|---|---|
| `ChampionshipCard` | 31, 40 | `ongoing`, `cancelled`, and unknown statuses could be presented as open/joinable. | Explicit lifecycle labels; only `open` shows registration CTA. | fail — corrected in source; runtime pending |
| `ChampionshipDetailsScreen` | 28, 36, 38, 40 | Live championship stream errors silently fell back to the original object. | Stale-data warning and retry recreate both championship and match streams. | fail — corrected in source; runtime pending |
| `ChampionshipMatchesTab` | 28, 36 | No first stream event and stream errors could appear as “no matches”. | Separate loading/empty/error/stale-data states; retry preserves last good matches. | fail — corrected in source; runtime pending |
| `ChampionshipStandingsSection` | 28, 36, 44 | Failed standings queries could appear as an empty table; live updates could repeatedly recreate the query. | Shared error/retry state; cached futures per group; bounded A–H indexes. | fail — corrected in source; runtime pending |
| `ChampionshipTopScorersTab` | 28, 36 | Failed scorer query could appear as “no goals recorded”. | Shared localized error/retry state. | fail — corrected in source; runtime pending |
| `PublicMatchCard` | 28, 36, 43 | Raw backend exceptions could reach users; request-cancel false result was ignored; share failure was unhandled. | Localized safe messages, diagnostic logging, boolean result handling, and share catch path. | fail — corrected in source; runtime pending |
| `OwnerNotificationButton` | 9, 36 | Unread-count stream failure could look like zero unread. | Warning indicator and localized tooltip on stream error. | fail — corrected in source; runtime pending |
| `VSPTermsCheckbox` | 27, 33 | The checkbox hit area was only 22dp. | 48dp interactive target with checked/button semantics. | fail — corrected in source; runtime pending |
| `CopyablePhoneText` | 27, 28, 36, 37 | Clipboard failure had no localized recovery feedback, explicit semantic label, or guaranteed minimum target. | Semantic label, localized failure feedback, and 48dp minimum hit area. | fail — corrected in source; runtime pending |
| `VSPCountdownTimer` | 44 | Timer continued rebuilding after reaching zero and did not reset its timer when targetDate changed. | Stops at zero, restarts for a changed target, and disposes the timer. | fail — corrected in source; runtime pending |
| Shared V2 token facade | 42 | Feature surfaces lacked direct compatibility aliases for the complete V2 size and typography roles. | Exposed V2 size, typography, and canonical color aliases. | fail — corrected in source; runtime pending |

“Corrected in source” is not a pass. These entries remain open until the consolidated runtime review records the actual result on representative devices, both locales, and all relevant states.


### Player profile avatar consistency — 2026-10-31

- **Player profile header and no-team card:** replaced duplicated network `DecorationImage` usage with one shared renderer that handles missing/blank URLs and network image failures. Both locations now render the same profile-image source and fallback behavior. Source-reviewed; runtime image-cache/network failure verification remains pending.


The championship refresh callback also increments a parent refresh version. The standings child invalidates its per-group Future cache when that version changes, so retrying a match/header stream error cannot leave a prior standings failure cached.


### Create-team member chip text bounds — 2026-10-31

- **Rules 11, 17 — `CreateTeamMembersSection`: member names now have a bounded one-line display with ellipsis so long names cannot displace the remove control; blank names use localized fallback text. Runtime narrow-width/large-text checks remain pending.


### Public match card lifecycle state correction — 2026-10-31

- **Rules 18, 27, 41 — `PublicMatchCard`:** cancelled/ended badges now override the host “My Match” badge, and terminal open-join cards route to booking details rather than the active invite sheet. Runtime terminal-state/tap-through validation remains pending.


### Open-join booking capacity status — 2026-10-31

- **Rules 18, 27 — `OpenJoinBookingCard`:** zero remaining places now renders a localized Full state instead of the inaccurate Open to join label. Runtime full-capacity and stale-data checks remain pending.


### Pending payment duplicate-charge guard — 2026-10-31

- **Rules 18, 27, 41 — `PendingBookingCard`:** when the payment row is already paid/partially paid but the booking is still awaiting server confirmation, the card disables Resume Checkout and directs the player to status refresh without repeating payment. The booking is still considered confirmed only by the existing server-backed `PaymentCheckoutService.isPaymentConfirmed` contract. Runtime webhook/retry validation remains pending.

## Terms and policy copy alignment — implemented on 2026-11-01

Following the product owner's explicit instruction to implement the previously listed corrections, `lib/features/player/screens/terms_and_privacy_screen.dart` was updated in Arabic and English:

- Owner/signatory minimum age: 21 → 18, aligned with the current registration gate.
- Player minimum age: 16 / guardian-supervised exception → 18, aligned with the current registration gate.
- Owner force-majeure cancellation: removed the unconditional promise to refund every amount without deductions; wording now refers to eligible refunds and excludes non-refundable administrative/payment-gateway fees.
- Player booking refunds: removed unsupported 100% automatic-refund, 20-minute grace, 90-day request-window, and fixed 3–7 business-day claims. Copy now describes policy-based eligibility, refundable principal, excluded non-refundable fees, and provider-dependent settlement timing.
- Tournament refunds: removed the unconditional full-refund promise; requests are subject to the terms shown before payment and the tournament state.
- No-show GPS appeal: radius 150m → 200m; accuracy is stated as no worse than 50m. The existing 60-minute appeal period was retained unchanged.

These are client-facing policy-copy changes only. No booking/refund RPC, database migration, RLS policy, payment calculation, refund eligibility logic, or GPS enforcement logic was changed. Runtime/legal review remains required before treating the terms as externally approved.

### Screen-register reconciliation — 2026-11-01

Nine additional embedded UI components were discovered by comparing the register with repository paths and were added as `not yet inspected`. The current register now contains 225 table records across 199 unique Dart paths (26 repeated entries). These nine components are not source-reviewed and must not be treated as passing any UXLP rule.

### Source remediation — 2026-11-01

A 1v1 empty-state action referenced `/edit-profile` through `Navigator.pushNamed`, while the application uses GoRouter and had no registered route at that path. The action now uses `context.push('/edit-profile')`, and the route is registered to `EditProfileScreen`. This is a source-level navigation correction only; runtime verification remains pending.


## Approval-required findings — no server changes applied

### TL-01 — Team League result submission is guarded in UI but not by the RPC

**Severity:** High — server-side business-rule enforcement gap  
**Affected rules:** 18, 22, 25, 31, 38

**Evidence**
- `lib/features/player/widgets/league/team_league_fixtures_view.dart` checks `match.bookingId` before exposing result entry (around lines 614–629), and only exposes submission after `scheduledTime` has passed (around lines 632–650).
- `supabase/migrations/20260930040000_vsp_team_league_master_architecture.sql` originally included a scheduled-time check in `submit_team_league_match_result` (around lines 715–717).
- `supabase/migrations/20260930050000_vsp_team_league_ssot_and_creator_authority.sql` explicitly drops and recreates that RPC. The later current definition in `supabase/migrations/20260930070000_vsp_team_league_fix_critical_bugs.sql` checks authentication, team membership, match participation, and the 15-minute result lock, but proceeds to the submission upsert without checking `booking_id` or `scheduled_time`.
- The later `20261001022000_vsp_team_league_runtime_linkage_fix.sql` updates the active-league read function and does not redefine the result-submission RPC.

**Root cause**
The booking and kickoff constraints exist only in the Flutter presentation path. The active `SECURITY DEFINER` submission RPC does not repeat those two checks, so a direct authenticated RPC call can bypass the UI-only gate.

**Proposed fix for approval**
Before the submission upsert, make the RPC reject a fixture with no `booking_id`, a null `scheduled_time`, or a `scheduled_time` later than `clock_timestamp()`. Keep the existing auth, team-membership, participation, and result-lock checks intact. Then add a focused SQL verification proving the RPC rejects both an unbooked fixture and a future fixture, and accepts an eligible booked fixture.

**Status:** Awaiting explicit approval of the exact migration SQL. No SQL has been drafted, applied, or deployed in this pass.


### TL-02 — Team League active-league RPC lacks participant authorization

**Severity:** Critical — authenticated cross-team data exposure  
**Affected rules:** 25, 38, 39, 43

**Evidence**
- `supabase/migrations/20261001022000_vsp_team_league_runtime_linkage_fix.sql` defines `public.get_team_active_league(p_team_id uuid)` as `SECURITY DEFINER`. It reads the requested team's league and returns the full teams/matches/submissions payload, including each team's `captain_phone`.
- In that function, `v_user_id := auth.uid()` is assigned and `v_is_creator` is calculated, but there is no rejection for a null user and no membership/captain/creator authorization check before returning the payload.
- `supabase/migrations/20260930050000_vsp_team_league_ssot_and_creator_authority.sql` grants execution to `authenticated` after revoking `PUBLIC` and `anon`. That role grant is authentication-only; it does not prove league participation.
- `lib/core/repositories/league/team_league_repository.dart` calls this RPC with a client-supplied `p_team_id`, so the database function must enforce the access boundary itself.

**Root cause**
The active `SECURITY DEFINER` function trusts the caller-supplied team ID and omits the authorization predicate that must protect privileged reads. Because it returns captain contact fields and team submissions, an authenticated user may be able to request another team's league data directly.

**Proposed fix for approval**
Add an in-function authorization gate before constructing the response: require a non-null `auth.uid()`, then allow only the league creator or a captain/member of a team participating in that league. Keep the existing data contract for authorized participants unless product approves reducing returned fields; consider whether `captain_phone` is necessary for every participant. Preserve the existing authenticated-only EXECUTE grant, and add SQL verification for unauthenticated, unrelated authenticated, participant, and league-creator callers.

**Status:** Critical approval-required security finding. No SQL was drafted, applied, or deployed in this pass.


### TL-03 — Authenticated users can directly regenerate Team League fixtures

**Severity:** Critical — unauthorized privileged mutation  
**Affected rules:** 25, 31, 38, 39, 43

**Evidence**
- `supabase/migrations/20260930050000_vsp_team_league_ssot_and_creator_authority.sql` explicitly revokes `PUBLIC`/`anon` and then grants `EXECUTE` on `generate_team_league_fixtures(UUID)` to `authenticated`.
- The current definition in `supabase/migrations/20261001022000_vsp_team_league_runtime_linkage_fix.sql` is `SECURITY DEFINER`. It accepts a caller-supplied championship ID, validates only that it is a Team League and that the joined team count is 4–8, deletes existing scheduled/unplayed fixtures, inserts regenerated fixtures, and changes an open championship to `ongoing`. It does not check `auth.uid()`, league ownership, payment completion, or whether the caller is the service role.
- The client repository `lib/core/repositories/league/team_league_repository.dart` does not call `generate_team_league_fixtures` directly. The payment-confirmation flow calls it internally from `confirm_team_league_payment`, which is granted to `service_role` in the earlier migration.

**Root cause**
A privileged fixture-generation function was exposed to every authenticated client even though the intended call path is server-side payment reconciliation. Because it is `SECURITY DEFINER`, the grant lets an authenticated caller bypass ordinary row-level permissions and trigger fixture deletion/regeneration for a league ID they supply.

**Proposed fix for approval**
Revoke direct execution from `authenticated`, `anon`, and `PUBLIC`; retain only the trusted internal/server-side invocation path. Add a defensive invariant inside the function that the league has reached its fully paid team threshold before fixture generation, and make repeat invocation safe so existing scheduled fixtures cannot be unexpectedly reset. Verify that authenticated direct RPC calls are denied and that the server-side payment-confirmation flow can still generate fixtures after the required payments complete.

**Status:** Critical approval-required security finding. No SQL was drafted, applied, or deployed in this pass.


## Auth safe-area, RTL, and location-target corrections — 2026-11-01

- `login_screen.dart`: removed duplicated bottom system inset inside `SafeArea`; forgot-password action now aligns to `AlignmentDirectional.centerEnd` so its placement mirrors correctly in Arabic and English.
- `signup_screen.dart`: removed duplicated bottom system inset inside `SafeArea`; GPS auto-detect is now a localized 48×48dp `IconButton` (verified against the updated source).
- `player_onboarding_screen.dart` and `owner_onboarding_location_section.dart`: GPS auto-detect controls now use localized tooltips and 48×48dp targets.
- These are source-level findings only. Dialog/device/keyboard runtime validation remains pending.


## Inventory reconciliation — 2026-11-01

- Current screen/surface register: **215 unique Dart paths**, **241 table rows**, including 26 repeated paths for separately documented embedded surfaces.
- Cross-checked all 21 screen imports declared by `lib/core/navigation/app_router.dart`; every routed screen file is represented in the register.
- Repository tree contains 647 Dart files total. The remaining 432 Dart files outside this register are not automatically missing screens: they include repositories, services, models, providers, helpers, and reusable UI building blocks. They require call-site discovery where they render visible surfaces; the register is a screen/surface inventory, not a complete Dart-file inventory.
- All 44 rule rows remain present. Their status is source-reviewed/runtime-pending, not a verified pass. Full state, modal, locale, and device coverage is still in progress.


## Welcome/auth touch-target follow-up — 2026-11-01

- `welcome_screen.dart`: the Skip action no longer opts out of the Material tap-target minimum; it now has a 48×48dp minimum target. The next-page FAB remains 54×54dp.
- `signup_screen.dart`: source rechecked after the auth batch; GPS auto-detect now uses a 48×48dp `IconButton` with Arabic/English tooltip.
- `forgot_password_dialog.dart` already uses a scrollable AlertDialog and 48dp action buttons. `verify_email_screen.dart` and both onboarding screens are inside SafeArea + scrollable content; keyboard/device runtime validation is still pending.


## Onboarding exit dialog target-size correction — 2026-11-01

- `owner_onboarding_exit_dialog.dart` and the player onboarding exit dialog now enforce 48dp minimum heights for both continue-registration and cancel/sign-out actions. Both dialogs are scrollable AlertDialogs and use the default safe-area behavior of `showDialog`.
- No registration or sign-out behavior changed. Device/keyboard layout verification remains pending.


## Player booking and stadium discovery touch-target corrections — 2026-11-01

- `booking_success_screen.dart`: booking-reference copy control changed from a 32dp padded InkWell to a 48×48dp IconButton with localized tooltip.
- `all_stadiums_screen.dart`: sort/filter action changed from a compact GestureDetector to a TextButton with a 48dp minimum target. Existing filter sheet uses `useSafeArea: true`, keyboard inset padding, a viewport height bound, and scrollable content.
- Booking confirmation bottom bar already applies the system bottom inset itself; its primary confirmation action is 52dp. Booking success main actions are 50–52dp or standard Material text actions.


## Challenge code sheet compact-viewport correction — 2026-11-01

- `challenge_select_team_screen.dart`: generated challenge-code bottom sheet now has a 90%-viewport maximum height, a scrollable body, explicit bottom SafeArea, and 48dp minimum copy/WhatsApp action heights. This prevents the lower actions from being pushed off-screen on short devices or with large text.
- Existing create-team sheet already uses `useSafeArea: true`; no challenge-code, team eligibility, or booking logic changed.
- Source structure was manually re-read after the edit. Runtime/keyboard/device verification remains pending.


## Stadium details tab interaction correction — 2026-11-01

- `stadium_details_screen.dart`: the three information/pitch/rating tabs previously had 4dp margins inside a 48dp parent, reducing the actual hit region below 48dp. Replaced the non-semantic GestureDetector with InkWell and set each tab surface to the full 48dp height.
- The bottom booking bar already wraps its controls in SafeArea. Stadium live-stream failure preserves the supplied last-known stadium and shows a retry warning.


### Championship governorate banner bilingual correction — 2026-11-01

- **Rules 10 and 13 — `ChampionshipsListTab`:** the Arabic browsing banner and its return-to-home action previously displayed raw canonical governorate names. Both now call the existing `championTranslateItem` helper so the selected and home governorates follow the active locale, consistent with the 1v1 banner.
- Source commit: `66e05af0a2c483f4a3e21128d9c7b651e2375b9c`. Runtime locale verification remains pending; no tests or build were run.


### Directional bottom action-bar padding correction — 2026-11-01

- **Rules 7, 10, 11, 35, and 42 — `VSPBottomActionBar`:** its public padding type is `EdgeInsetsGeometry`, but the previous implementation discarded any non-`EdgeInsets` value and substituted physical left/right defaults. The component now preserves the supplied directional or physical padding and adds the system bottom inset independently.
- Source commit: `025643a19457b5d21568958e531b7126cc465fe1`. Runtime device/RTL verification remains pending; no tests or build were run.


### Booking calendar short-viewport correction — 2026-11-01

- **Rules 11 and 35 — `booking_calendar_modal.dart`:** removed the 240dp minimum dialog maximum-height fallback that could exceed the remaining height after system/keyboard insets. The scrollable dialog now clamps to the actually available viewport.
- **Rule 35 — `AddPlayerSheet`:** inspected its caller in `create_team_sheet.dart`; the modal route sets `isScrollControlled: true` and `useSafeArea: true`, so the prior caller-configuration question is resolved at source level.
- Calendar source commit: `c2f57c7317b9ef4bfd04f409227a8295179fbaea`. Runtime/keyboard/device verification remains pending; no tests or build were run.


### Booking calendar directional navigation — 2026-11-01

- **Rules 10, 27, and 33 — `booking_calendar_modal.dart`:** month-navigation glyphs now mirror in RTL, and previous/next controls expose localized tooltips. Date range and selection behavior are unchanged.
- Source commit: `2a3a66cfe239a2924bb03c9ac68131e95ac656f1`. Runtime locale and focus verification remains pending; no tests or build were run.


## Live Supabase authorization and RLS recheck — 2026-11-01

Read-only inspection of the connected VSP project `mktqkddbcddrxjxabdua` (Postgres 17.6.1.127) confirms:

- `public.generate_team_league_fixtures(uuid)` remains SECURITY DEFINER, but its live EXECUTE ACL contains only `postgres` and `service_role`; `authenticated` is absent.
- `public.confirm_team_league_payment(...)` is also SECURITY DEFINER and its live EXECUTE ACL contains only `postgres` and `service_role`. This matches the intended trusted server-side payment-confirmation path.
- Therefore, the direct authenticated fixture-regeneration exposure described in historical finding TL-03 is **resolved in the live ACL**. The function still lacks an internal paid-team threshold invariant; that is defense-in-depth and must be treated separately from the now-closed client EXECUTE exposure.
- `public.get_team_active_league(uuid)` remains SECURITY DEFINER with EXECUTE granted to `authenticated`; its active definition still lacks a caller-membership/creator authorization gate before returning team and captain-contact data. TL-02 remains open and approval-required.
- `public.submit_team_league_match_result(uuid,uuid,text)` remains SECURITY DEFINER with EXECUTE granted to `authenticated`; its active definition validates membership but does not enforce that the fixture has a booking and that scheduled kickoff has passed. TL-01 remains open and approval-required.
- RLS is enabled and policies are present on all six previously flagged tables: `cancellation_refund_queue` (2), `challenge_results` (2), `internal_function_secrets` (1), `team_league_cancellation_refund_queue` (2), `team_league_payments` (2), and `vsp_1v1_cancellation_refund_queue` (2). The older zero-policy baseline is stale.

No SQL, grants, RLS policies, migrations, or production data were changed. This was a read-only live-state check.


### Final APK workflow gate — 2026-11-01

- Removed the release workflow's automatic push trigger for `main` and `uxlp-44-implementation`; the workflow now runs only through `workflow_dispatch`, preserving the agreed final-phase APK gate.
- Workflow commit: `76e27f24ac4173685197f24cb5e42892ba706356`. No manual release build was started. Previously triggered run status was not available through the connected GitHub actions controls in this session.


### Add Player sheet touch target — 2026-11-01

- **Rule 33 — `add_player_sheet.dart`:** the found-player Add action was 40dp high; its minimum hit area is now 48dp. Lookup and roster behavior are unchanged.
- Source commit: `d15526e2233ede46bd2f7fa527c00dfb7f2062ee`. Device/touch verification remains pending; no tests or build were run.


### Shared loading indicator semantics — 2026-11-01

- **Rules 28 and 33 — `VSPStateView`:** the shared loading spinner now has a localized Arabic/English semantics label for screen readers. Visual and request behavior are unchanged.
- Source commit: `749a144d77da65abffbf90536886c90f6f627a3b`. Assistive-technology verification remains pending; no tests or build were run.


### Reactive offline/online error-state update — 2026-11-01

- **Rules 28 and 33 — `VSPErrorState`:** the widget previously sampled connectivity once and did not subscribe to the service notifier, allowing stale offline messaging to remain visible after the device regained a connection. It now listens to connectivity changes, swaps state/copy/icon immediately, and exposes the updated error state as a live region.
- Source commits: `d6f20e446b907636add2cfb0c46046fa4da48e87`, `88a89f23515752def1cf2350bd063e37ab344ca1`. Runtime connectivity and screen-reader verification remains pending; no tests or build were run.


### Empty-state icon tone and geometry consistency — 2026-11-01

- **Rules 1, 2, 3, and 5 — `VSPEmptyState`, `ChampionEmptyState`, and `VSPStateView`:** the generic empty-state icon was brighter than the championship family, and the shared state view used a larger 32dp icon. Empty/disabled states now share the charcoal `zinc400` icon tone and 28dp icon-size token; error/success status icons remain unchanged.
- Source commits: `20b07e2bb584426de7a86b625a0b80b2bb81fe6d`, `869014683a6328af5283ba2f74a023baf56df8b7`. Visual/device verification remains pending; no tests or build were run.


### Support ticket modal double keyboard-inset correction — 2026-11-01

- **Rules 11 and 35 — `support_tickets_screen.dart`:** the `showModalBottomSheet` route already applies `viewInsets.bottom`; the sheet then subtracted the same inset again when computing `maxHeight`. Removed the second subtraction, retaining safe-area and scroll protections so keyboard-open compact layouts retain usable height.
- Source commit: `a098bb1c594a1eba3c5a807498884102f6ab3e85`. Keyboard/device verification remains pending; no tests or build were run.


### Add Player modal double-inset correction — 2026-11-01

- **Rules 11 and 35 — `AddPlayerSheet`:** its caller already enables a scroll-controlled, SafeArea modal route, but the sheet also subtracted keyboard and system insets from full screen height. Removed that duplicate viewport calculation, preserving bottom safe padding and scroll behavior.
- Source commit: `cb8327b5f52d019a58f9ce071fa94c2afae1107c`. Keyboard/device verification remains pending; no tests or build were run.


### Owner payout OTP and auto-schedule modal viewport corrections — 2026-11-01

- **Rules 11 and 35 — `OwnerPayoutOtpDialog` and `TournamentAutoScheduleModalSheet`:** both are opened through scroll-controlled, SafeArea modal routes but previously subtracted keyboard/system insets again from full screen height. The auto-schedule sheet also forced a 240dp minimum that could exceed short viewports. Both now use a preferred 88% content-height cap and rely on parent route constraints for the actual keyboard-safe viewport; bottom padding and scrollable content remain.
- Source commits: `33dc6d1b5c43a4fc25ce3811273f0fa926453171`, `947cee3bf2d21f785914ee12114f1bbf568c89dc`. Keyboard/device verification remains pending; no tests or build were run.


### Manual stadium-location sheet duplicate keyboard inset — 2026-11-01

- **Rules 11 and 35 — `add_stadium_location_picker_sheet.dart`:** the scroll-controlled modal route already applies keyboard insets, but the manual-address sheet also included `viewInsets.bottom` in its own padding. Removed the duplicate keyboard inset while retaining system bottom padding and scrollable content.
- Source commit: `ac329b8bdf6ca1790b5e11e14d2a74ed06917528`. Keyboard/device verification remains pending; no tests or build were run.


### Owner Copilot sheet duplicate keyboard inset — 2026-11-01

- **Rules 11 and 35 — `VspCopilotSheet`:** the scroll-controlled modal route already applies keyboard insets, but the sheet also subtracted the inset from its height and added a matching bottom margin. Removed the duplicate offset while retaining its internal bottom SafeArea and preferred height.
- Source commit: `9e01276e39b1a7b80e05d8a5517a45497c9cde48`. Keyboard/device verification remains pending; no tests or build were run.


### Tournament score-entry sheet double keyboard inset — 2026-11-01

- **Rules 11 and 35 — `tournament_score_modal.dart`:** removed duplicate keyboard inset subtraction from sheet height and duplicate keyboard inset padding below the footer. Also removed the 240dp minimum that could exceed a compact viewport. The modal route now owns keyboard constraints; footer keeps the system bottom inset.
- Source commit: `7ea2f5a740d42b5ed7bd732fc99b6a1f66c600c6`. Keyboard/device verification remains pending; no tests or build were run.


### Owner booking, quick-phone booking, and manual-team sheet viewport corrections — 2026-11-01

- **Rules 11 and 35 — `owner_booking_sheet.dart`, `quick_phone_booking_modal.dart`, and `tournament_manual_team_sheet.dart`:** these scroll-controlled SafeArea routes were manually subtracting/adding keyboard view insets in addition to the route's own keyboard handling. Removed duplicate keyboard/system inset calculations, retained system bottom padding, and removed the manual-team sheet's unsafe 240dp minimum. Parent route constraints now determine actual keyboard-safe height.
- Source commits: `068d381b19a96f935560c9a8b69ca558a088ba2f`, `d96527b83cd298ae44d32edd414950a3d1e9f0e2`, `981951eebe65b85d4953b60a8806b1aea97d18b7`. Keyboard/device verification remains pending; no tests or build were run.


### Booking-type and collective-invite sheet viewport corrections — 2026-11-01

- **Rules 11 and 35 — `booking_type_modal.dart` and `collective_match_invite_sheet.dart`:** both scroll-controlled SafeArea routes previously subtracted keyboard/system insets from their own max-height calculations, including a 240dp minimum that could exceed compact available space. Removed the duplicate calculations; collective-invite list now includes bottom system padding to keep final content/actions reachable.
- Source commits: `422c4f223ce9e6edf62f17dbb44b0eead1cd33a5`, `a75c17dbe3344905955eb4a50d372c7750855824`. Keyboard/device verification remains pending; no tests or build were run.


### Create Team sheet duplicate keyboard inset — 2026-11-01

- **Rules 11 and 35 — `CreateTeamSheet`:** its known callers use scroll-controlled SafeArea modal routes, but the sheet also subtracted keyboard/system insets from full screen height. Removed the duplicate calculation; route constraints own the keyboard-safe viewport and the sheet retains bottom system padding and scrollable form content.
- Source commit: `ca4778a2bed9827aa9dccb4f2655d9468884d904`. Keyboard/device verification remains pending; no tests or build were run.


### Owner schedule row and dashboard header accessibility/RTL refinements — 2026-11-01

- **Rules 5, 10, 27, 30, 33, and 37:** owner time-slot rows now use InkWell semantics/focus/feedback while preserving tap and long-press actions; the booking-detail chevron mirrors in RTL; owner profile-photo action has localized tooltip and keyboard/focus semantics; verified-account tooltip is bilingual.
- Source commits: `c853ea69ab5634790fc167021aa2a08b19e120da`, `0555e1a17c1cfce2a6ca0f80fcf0dbb3ccfc4a6e`, `f880179e87a87ccc2a4db8781254e02fa9830e3d`. Runtime and device verification remain pending; no tests or build were run.


### Challenge selection and owner schedule consistency — 2026-11-01

- **Rules 27, 30, 33, and 38:** challenge team cards now expose a keyboard/focus-accessible InkWell selection surface and bound long team names to two lines; owner slot tap and long-press expiry checks now share the centralized VSP time source, preventing the two gestures from evaluating the same slot against different clocks.
- Source commits: `fa061708ed0c944b6306e4408ac32b3f15b5717a`, `bd4ac74abe24a113967bfe37bbc551c578231985`. Runtime/device verification remains pending; no tests or build were run.


### Tournament schedule action and pending-cash time source — 2026-11-01

- **Rules 10, 27, 33, and 38:** tournament match scheduling now has a localized tooltip and 48dp IconButton target; schedule text is bounded on narrow widths; date/time defaults and owner pending-cash day filtering use the centralized VSP time service rather than independent device-clock reads.
- Source commits: `bf9728854a4fd82ac517a0c5a9965fbf1afb3163`, `986d4ac9d8c8be36e10c8caaeee001f2a85a1bdf`. Runtime/device verification remains pending; no tests or build were run.


### Player home/chat accessibility and payment wording — 2026-11-01

- **Rules 10, 18, 27, 33, and 36:** home profile/search/filter actions now have focusable InkWell surfaces and localized tooltips; home avatar image failures and empty URLs render a fallback; chat send has a localized tooltip and focusable 48dp target; payment-method selector no longer promises “100% secure” and instead names the Paymob gateway.
- Source commits: `7358e28a0103eaa6fd76ba3a8272cc826f2ab1e9`, `29867442c66dab84ce359672d104df9e261b4de8`, `50ffd573c2efc1026b487ac1a322a545373ce265`, `50893601929d447510918b1099ff9a0bb604c279`. Runtime/device and payment-flow verification remain pending; no tests or build were run.


### Player booking slot accessibility and centralized time source — 2026-11-01

- **Rules 27, 30, 33, and 38:** booking time-slot selection now uses InkWell semantics/focus/feedback while booked/past slots remain disabled; slot-state calculations and the challenge-result prompt use the centralized VSP time service to avoid conflicting clock sources.
- Source commits: `d5badce48843ca21bfe6249dd57a0db9530ff768`, `fcca24c89c7ce717b4b55e5b3c5eaefca136ea25`, `04875c4918530f3da9759fb0b33717fa4202d2c6`. Runtime/device verification remains pending; no tests or build were run.


### Championship checkout narrow-width text constraints — 2026-11-01

- **Rules 8, 11, 23, and 35:** checkout championship title, governorate/team metadata, and roster heading now have bounded line counts/flexible widths with ellipsis so long localized labels do not force row overflow; the roster count badge retains its visible space.
- Source commits: `345275ef60b2ddf4c6fe7d70cac0314a0563935b`, `b9ffda958156bf540e14b76b46ef855421982836`. Device/large-text verification remains pending; no tests or build were run.


### Stadium location action accessibility and launch recovery — 2026-11-01

- **Rules 11, 27, 33, and 36:** stadium location badge now exposes a localized, focusable map action; long address text is bounded on compact screens; a false/failed external-launch result produces localized recovery feedback instead of silently doing nothing.
- Source commits: `aed4b1aab8511b80493aeb6daed0133a5e8875b8`, `6231c0f438cd5e5ce73d3f24c404323383f279ec`. Device/launch verification remains pending; no tests or build were run.


### Stadium gallery controls accessibility — 2026-11-01

- **Rules 5, 27, 30, and 33:** share/favorite controls now expose focusable 48dp targets and localized state-aware tooltips; tapping the hero image or gallery indicator is now keyboard/focus accessible without changing swipe navigation or the full-screen gallery flow.
- Source commit: `c308b47cca78448cf7eb3aa8f6b19f16f43d505f`. Runtime/device verification remains pending; no tests or build were run.


### Owner quick-cash centralized clock — 2026-11-01

- **Rules 31, 38, and 40:** quick-cash day/status calculations now use the shared VSP clock by default while retaining explicit injected-time support, aligning the action card with owner booking schedule and pending-cash date semantics.
- Source commit: `8a3a2007566590cb90779b0d31d774dbdb99f89d`. Runtime verification remains pending; no tests or build were run.


### Chat message edit affordance and locale-aware time — 2026-11-01

- **Rules 10, 13, 27, and 33:** message edit remains long-press only for the sender but is now discoverable through a localized assistive-technology custom action; sender names are bounded; timestamps follow the active locale.
- Source commit: `2f48a9caa58f078ffc48b29a5566238403db96b2`. Runtime/accessibility verification remains pending; no tests or build were run.


### Signup/OTP focus, touch target, and lifecycle corrections — 2026-11-01

- **Rules 27, 33, 34, and 35:** OTP keyboard event handling no longer allocates an undisposed FocusNode during build; resend is a keyboard-focusable TextButton with a 48dp minimum target and correct disabled countdown state; date-of-birth field is now focusable with a localized tooltip.
- Source commits: `d03b89bbc9c303c1e74d95bfb6a722c58fe335af`, `cf7f225de5405ce3fce507e2a64b1777972c1c0e`, `5b283415b6ed5028ed3e36a48188f1b880a2c039`. Keyboard/device verification remains pending; no tests or build were run.


### Signup password and email verification semantics — 2026-11-01

- **Rules 10, 11, 33, and 34:** password-strength progress now exposes semantic label/value; masked verification email remains LTR and bounded on narrow screens, preventing mixed-direction rendering and overflow.
- Source commits: `f08220df0d53e821f714d877028c71b7aca32b22`, `854d157d9b04296a3fbcbaa44faeb60df7eb93ad`. Runtime/accessibility verification remains pending; no tests or build were run.


## Approval-required business-rule finding — owner manual cash bookings — 2026-11-01

- **Observed source conflict:** `lib/features/owner/widgets/dashboard/owner_pending_actions_bar.dart` explicitly excludes bookings where `createdByUserId == ownerId`, with the comment that manual owner-created bookings are accounting records, not app cash-collection actions. `lib/features/owner/widgets/dashboard/owner_quick_cash_card.dart` does not apply that exclusion: it includes any same-day cash booking that is not cancelled/fully-paid/refunded/refund-pending and exposes the cash-confirmation action. The same owner-created manual cash booking can therefore be excluded from the pending-action count but still appear as a cash-collection task in the quick-cash card.
- **Root cause:** the two owner dashboard surfaces independently implement the same cash-eligibility predicate and disagree on whether owner-created manual bookings belong to cash-collection actions.
- **Proposed resolution (not applied):** if the existing comment is the authoritative product rule, apply the same `createdByUserId == ownerId` exclusion to `OwnerQuickCashCard` pending and settled summaries; alternatively, if owners must confirm cash received for their manual bookings, remove the exclusion from `OwnerPendingActionsBar` and make both surfaces share one eligibility predicate. This changes which bookings are actionable/accounted in the dashboard, so it remains a product decision; no code or payment behavior was changed.


### Owner PRO upgrade CTA ergonomics — 2026-11-01

- **Rules 11, 27, and 33:** PRO upgrade CTA is now keyboard/focus accessible through InkWell, meets a 48dp minimum target, and constrains long localized labels.
- Source commit: `e824ab825bcc5f501c7d267a93370191a57a6205`. Device verification remains pending; no tests or build were run.


### Date-of-birth field structure follow-up — 2026-11-01

- Rewrote the `SignupDateOfBirthField` wrapper with balanced Tooltip/Material/InkWell/Container nesting and bounded the selected date to one line. The accessible tap target and original date display/callback are preserved.
- Follow-up source commit: `524148fc4ee6925b06b422ad600d0f2deb8b7c22`. No tests, analyzer, CI, runtime checks, or APK build were run.


### Login role-selection sheet — 2026-11-01

- **Rules 5, 11, 27, 30, 33, and 34:** sign-up action is keyboard accessible with a 48dp minimum target; role sheet is safe-area aware and scrollable; role copy is bilingual; role-card actions are focusable with larger targets; directional arrow mirrors in RTL.
- Source commit: `b3cd4f1cf2dcd43283037aa92e6820230b1d0f98`. Device/keyboard verification remains pending; no tests or build were run.


## Signup governorate display localization — 2026-11-01

- `lib/features/auth/widgets/signup_governorate_dropdown.dart`: dropdown values remain canonical English identifiers for AuthProvider/database consistency, while visible option labels now use `EgyptGovernorates.getLocalizedName` according to the active locale and are bounded to one line. This fixes English governorate names appearing in Arabic signup without changing stored values.
- Source commit: `f30af5466d6d7c1fe073cde0b7c43b72e8b7589e`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Team management action copy localization — 2026-11-01

- `lib/features/player/widgets/my_team/team_action_buttons.dart`: WhatsApp team-invitation message and leave-team/captaincy-transfer action now follow the active Arabic/English locale instead of displaying Arabic-only copy in English mode. Team name interpolation, WhatsApp launch, and captaincy handoff callback remain unchanged.
- Source commit: `84a0b126eec4f7c2e331cad1204b7463f42216b1`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner cash collection controls and receipt sheet — 2026-11-01

- `lib/features/owner/widgets/dashboard/owner_quick_cash_card.dart`: cash confirmation and phone-call controls now meet a 48dp minimum target (previously 36dp); the post-confirmation receipt bottom sheet is scrollable and respects the device safe area, including short-height screens and bottom system insets. Payment eligibility, `updatePaymentStatus` call, receipt content, and WhatsApp action are unchanged.
- Source commit: `55c3992dd9bf091fea1d29b55effc710a9212554`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Supabase function ACL review — tournament participation helper exposure — 2026-11-01

- **Live evidence (read-only):** `public.vsp_user_is_tournament_participant(uuid, uuid)` is `SECURITY DEFINER`, and `has_function_privilege('authenticated', ..., 'EXECUTE')` returns true. Its body accepts an arbitrary `p_user_id` and returns whether that user is the championship owner, captain, or team member in a pending/confirmed registration. The function itself does not compare `p_user_id` with `auth.uid()`.
- **Observed dependency:** `public.create_direct_chat_atomic(...)` calls this helper twice from its own `SECURITY DEFINER` body to verify both tournament chat participants. No direct client RPC call was found in the inspected repository source, but the helper is currently directly callable by authenticated clients at the database ACL level.
- **Risk:** an authenticated user can probe arbitrary user/championship pairs and infer tournament participation, outside the intended chat-creation flow. This is an information-disclosure surface; it is separate from the earlier TL-01/TL-02 team-league authorization findings.
- **Proposed fix (not applied):** revoke direct `EXECUTE` from `authenticated` (and explicitly from `anon` if granted) for this helper, while retaining owner/service execution needed by the definer wrapper. Before applying, confirm there is no direct RPC dependency in any external client. No SQL, grants, policies, migrations, or production data were changed.


- Follow-up to the owner cash-card controls: the 48dp phone-call icon action now exposes a localized tooltip (`Call player` / `الاتصال باللاعب`) so its purpose is announced and discoverable. Source commit: `f6f2679f84f941bc81ccc47e4064445a61fa8e32`.


## Stadium image gallery lifecycle and navigation target — 2026-11-01

- `lib/features/player/widgets/stadium_details/stadium_image_carousel.dart`: the full-screen gallery's temporary `PageController` is now disposed when the dialog closes (previously allocated for each opening and never disposed); the top back action hit area is raised from 40dp to 48dp. Image paging, zoom, hero transition, and navigation destination are unchanged.
- Source commit: `3d3a696719a7e939b5eee8ec8c7977747ed71618`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner inbox preview overflow protection — 2026-11-01

- `lib/features/owner/widgets/inbox/owner_chat_item_card.dart`: the conversation time label is constrained to a 76dp maximum width and one line; the latest-message preview is also one line with ellipsis. This prevents long localized timestamps/previews from pushing the unread badge or shrinking the conversation title on narrow devices.
- Source commit: `a5f8310c26dbd44238ced22b2c57e002fd40bd79`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner ledger locale-aware date/time — 2026-11-01

- `lib/features/owner/widgets/ledger/owner_ledger_transaction_item.dart`: transaction timestamps now use locale-aware `yMMMd + jm` formatting instead of a fixed numeric `yyyy/MM/dd — hh:mm a` pattern, so month/date order and time conventions follow Arabic or English locale.
- Source commit: `6190c0c85d55ef17aa3ed555752cbf84cbbc2157`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Signup name-field narrow-screen layout — 2026-11-01

- `lib/features/auth/widgets/signup/signup_name_fields.dart`: first/last-name inputs now stack vertically when the available field width is below 360dp, while retaining the two-column layout on wider screens. This avoids cramped text fields and label/input collisions on compact phones and under larger text scaling. Input controllers, labels, validation ownership, and submission order are unchanged.
- Source commit: `53dbbea2a3a5bea13615403e40041669433ebb8d`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Shared state presentation consolidation — 2026-11-01

- **Rules 3, 6, 9, 11, 13, 35, 36, 38, 42:** the shared empty-state adapter now delegates to the canonical `VSPStateView`, so empty-state visuals and layout no longer drift between the generic component and championship/1v1 variants. The canonical renderer provides bounded-width scrollable content and neutral charcoal empty-state treatment.
- **Loading review:** the shared loading/processing renderer is bounded and scrollable and exposes a localized progress semantic label.
- **Error review:** the shared error renderer distinguishes offline connectivity from server failure, uses a live-region announcement, and exposes a retry action. This is source-level review; caller-specific error messages and retry callbacks still need verification.
- Updated source: `vsp_empty_state.dart`, `champion_empty_state.dart`, and `league_1v1_empty_states.dart`. Shared loading/error source was reviewed but not modified in this pass.
- **Status remains source reviewed—runtime pending.** No rule is promoted to pass. Every registered caller still needs review for correct data-state mapping, Arabic/English copy, retry behavior, and device/viewport rendering. No tests, analyzer, CI, runtime checks, or APK build were run.


## Dialog target and current Supabase review — 2026-11-01

- Cancellation dialogs in player checkout and owner booking now expose 48×48dp minimum action targets. The business outcomes (cancel/keep/refund/penalty) are unchanged.
- Current Supabase advisor snapshot: `teams_public` SECURITY DEFINER view (1 ERROR); authenticated execution on SECURITY DEFINER functions (198 WARN findings); leaked password protection disabled (1 WARN).
- Current authenticated ACL confirmed on three previously flagged team-league/participation helpers: `get_team_active_league`, `submit_team_league_match_result`, `vsp_user_is_tournament_participant`.
- Last-24-hour PostgREST log scan returned 121 matches for a Warp timeout message; treat as repeated log entries, not unique failures. More targeted correlation by request/endpoint is required before proposing a code/database change.
- These database findings are read-only observations. No database policy/grant/function/view/auth setting was altered. Product-safe revocation list and wrapper call graph need review before any privilege change.
- UXLP statuses remain source-reviewed/runtime-pending; no test or runtime pass is claimed.



## Additional modal accessibility pass — 2026-11-01

- Collective match invite sheet: localized close tooltip; close and participant counter controls meet 48×48dp.
- Championship governorate confirmation: primary action increased to 48dp.
- Owner payout OTP sheet: cancel action minimum height/tap target 48dp; scroll and keyboard handling retained.
- Player booking cancellation already uses 48dp actions and stacks actions on narrow screens.
- Supabase Warp timeout log entries currently lack request method, status, or endpoint details (path only reports `/`); no reliable attribution to a VSP RPC can be made. Do not treat the repeated log rows as confirmed unique app failures.
- Runtime status remains pending; no test or full-screen coverage claim.


### 2026-11-01 grouped follow-up

- Rule 9/11/35/36: root account-resolution loading now uses the canonical bounded/scroll-safe VSPStateView, localized Arabic/English copy, and SafeArea; tournament stepper and collective-booking counter labels are constrained for compact viewports.
- Rule 27/35: owner ongoing-match extension action now preserves a 48dp minimum hit target.
- Rule 39/40: OwnerMainScreen deferred celebration subscription is guarded against post-frame disposal and late stream events.
- Supabase security/authorization: read-only live review confirms all 66 public tables have RLS enabled and the previously identified six sensitive tables now have explicit policies. One SECURITY DEFINER view and 198 authenticated-callable SECURITY DEFINER functions remain under function-by-function authorization review; no blanket revoke or view mode change was applied because those operations can change team discovery and atomic workflow behavior.
- All entries above are source/database observations only. Runtime and complete per-rule evidence remain pending.


### 2026-11-01 auth layout/lifecycle additions

- Rule 11/35: verify-email OTP row now sizes six digit boxes against the actual available width (32–46dp), removing the fixed-width overflow on narrow phones.
- Rule 39/40: RootScreen deferred post-frame auth lookup and SignupScreen deferred auto-location now exit safely when disposed.
- Source-only evidence. Device/large-text and Arabic/English runtime rendering remain pending.


### Auth and player state-recovery follow-up — 2026-11-01

- **Rules 9, 10, 11, and 36:** email OTP verification and resend now recover from unexpected thrown errors with localized retry guidance and restore their in-flight controls; local pending-email cleanup failure after a successful server verification no longer presents a false verification failure. Profile team-card loading and global search loading now use the shared bilingual state renderer instead of bare spinners. Existing explicit profile/search error and retry branches remain intact.
- These are source-level changes only. No rule is promoted to pass; Arabic/English rendering, keyboard behavior, and failure recovery still require the single consolidated runtime validation pass. No tests, analyzer, CI, device run, or APK build was run.


### Challenge code lookup ergonomics — 2026-11-01

- **Rules 27, 29, and 33:** challenge-code lookup now rejects duplicate handler invocations even if triggered outside the disabled button, and its action target is 48dp rather than 46dp. No challenge-code validation, team eligibility, or repository behavior changed. Source-only evidence; keyboard and device verification remain pending.

- **Rules 28, 36, and 43:** profile team-card capture now validates its render boundary and PNG encoding result, and releases the temporary image resource in a `finally` block to avoid leaking image memory on repeated share attempts. Source-only; device share-sheet and capture behavior remain runtime pending.


### Player/owner loading-state consolidation — 2026-11-01

- **Rules 9, 10, 28, 36, and 42:** full-page loading states in facility onboarding, owner championships/inbox/subscription plans, tournament brackets, match details/live matchup, support ticket detail/list streams, team profile, My Team, and notification preferences now use the shared bilingual state component with a localized title and contextual message. Existing retry/error/empty branches and data operations were preserved. Small inline progress indicators for button submissions and image loading remain intentionally local.
- No rule is marked pass from source edits alone. Locale rendering, narrow viewport behavior, keyboard interaction, and stream recovery remain part of the single final runtime validation pass.

- **Rule 33:** owner tournament dashboard confirmation, force-start, cancellation, and destructive dialog actions now use 48dp primary-action heights instead of 44dp. Source-only; tap-area verification remains part of final device validation.


### Public-match join request integrity and backend authorization — 2026-11-01

- **Rules 18, 25, 29, 31, 36, 38, 39, and 43:** the Flutter repository now honors the JSONB `success` field returned by `accept_join_request`/`reject_join_request`, so an RPC-level rejection cannot be reported as a successful action or mutate the local participant list. Diagnostics now retain stack traces without exposing them to users.
- **Approval-required database findings:** `accept_join_request` does not verify pending membership or reject an already-joined target before incrementing the booking player count. The public-match card's self-cancel action calls the host-only `reject_join_request`; there is no dedicated caller-owned cancellation RPC. A narrow server-side fix is specified in the implementation progress record but is not deployed because production SQL requires explicit approval. These findings remain open.
- Live Supabase security/performance advisor results were refreshed read-only. No schema, RLS, RPC grant, view, or Edge Function changes were applied.

- **Rules 9, 10, 28, 36, and 42:** collective invite route, 1v1 league tournament/player streams, and championship discovery now use the shared bilingual loading state. Existing retry/error/empty behavior and repository operations are unchanged; runtime verification remains pending.

- **Rules 9, 10, 28, 36, and 42:** player team-league membership/league loading, team rankings, and 1v1 standings now use the shared bilingual state renderer. Existing retry/error/empty paths remain intact. No rule is marked pass before runtime validation.

- **Rules 10, 13, and 36:** My Team's unauthenticated fallback no longer exposes a raw English-only diagnostic; it now presents a safe-area-protected Arabic/English account error with a clear sign-in recovery instruction.

- **Rule 33:** owner document-upload cancellation, add-stadium discard/delete, and Paymob still-waiting dialog actions now have explicit 48dp minimum height and padded hit targets. Source-only; final touch-area validation remains pending.

- **Rules 11, 33, and 35:** chat report dialog now scrolls under keyboard pressure; all report/delete dialog actions have explicit 48dp minimum hit targets.

- Prize handover dialog actions were also raised to the 48dp target. All source-only touch-target changes remain runtime pending.


- **Rule 10 — Bilingual visual integrity:** corrected a physical `left` inset in `tournament_manual_team_sheet.dart` to directional `start` padding. This removes one confirmed RTL asymmetry in the manual-team sheet. Device rendering and the rest of the 215 registered surfaces remain subject to final verification; no rule is marked pass from this source correction alone.


- **Rule 10 — Bilingual visual integrity:** the date-picker header's asymmetric inset now uses directional start/end geometry, and the owner manual-team section label uses directional start padding. Both previously encoded physical left/right positioning and now mirror consistently between Arabic RTL and English LTR. Runtime rendering and the remaining surfaces are still pending.


- **Rules 29, 31, and 36:** Team League match-result submission now has a handler-level single-flight guard, and result choices are disabled during the pending save. Existing localized failure recovery remains intact. Backend authorization and result-window enforcement remain separate approval-required server findings; this client guard does not replace them.


- **Rule 29 — No duplicate submission:** owner tournament score submission now checks `isSubmitting` inside the action handler before issuing the repository write, in addition to the existing loading button state. Team League result submission has the same handler-level guard and locks result selection during save. These are client-side safeguards only; authoritative server-side idempotency/authorization still requires separate review.


### TL-03 live ACL revalidation — 2026-11-01

- Re-ran read-only privilege checks against the active project: `generate_team_league_fixtures(uuid)` is executable by `postgres` and `service_role` only; `anon` and `authenticated` are denied. `confirm_team_league_payment(...)` is also service-role-only. The internal helper is called from the SECURITY DEFINER payment confirmation and captain-authorized `join_team_league(...)` paths.
- TL-03 is therefore closed as a direct authenticated RPC exposure in the current live ACL. This does not claim the helper is independently safe for arbitrary invocation by a trusted service-role caller; its payment/registration invariants remain defense-in-depth. No SQL or grants were changed.


- **Rule 10 — Bilingual visual integrity:** the shared `CardSkeleton` component now applies its horizontal trailing gap with `EdgeInsetsDirectional.end`, so skeleton cards mirror correctly in Arabic RTL. The register was expanded to include ten shared/auth embedded UI components; their caller-level and runtime verification remains pending.


- **Rule 10 — Bilingual visual integrity:** owner payout settings/profile helper labels now use directional start padding; the owner stadium carousel uses directional end spacing; add-stadium note chips use directional end spacing. The shared skeleton card and date picker/manual-team sheet fixes are also recorded above. All are source-level corrections; runtime Arabic/English mirroring remains pending.


- **Rule 10 — Bilingual visual integrity:** owner dashboard insight filter selected-value alignment now uses `AlignmentDirectional.centerEnd`, eliminating physical right alignment in the Arabic/English shared filter row. Stadium wizard step components and owner dashboard insight widgets were added to the explicit embedded-component register; caller/data/runtime verification remains pending.


- **Rule 10 — Bilingual visual integrity:** owner timeline status-marker spacing now uses directional end margin; owner time-period dropdown selected values use directional trailing alignment. Owner dashboard/PRO and documentation embedded components have been added to the register for caller-level review; runtime verification remains pending.


- **Rule 10 — Bilingual visual integrity:** quick-booking duration chips now use directional start spacing in both compact and horizontal-scroll layouts, removing locale-specific physical left/right branches. Document upload steps, ledger balances, quick-booking sections, and cup-card/empty-state components were added to the embedded register; runtime and data-state verification remains pending.


- **Rule 10 — Bilingual visual integrity:** the owner manual-team options section now uses directional start padding for labels and directional end spacing for color choices. Tournament/roster, booking-financial, guest-checkout and chat embedded components have been added to the register for caller-level verification.


- Player filter panels, home-feed composition/CTA, matchup result card and team achievements section have been added to the embedded-component register. No source-only visual defect was confirmed in this subset; selected-state/query mapping, real-data behavior, empty/error mapping and runtime locale verification remain pending.


- **Rules 9, 10, 28, and 36:** stadium review retrieval now distinguishes initial loading, initial stream failure with retry, and a genuinely empty review list. Retry recreates the review stream; stale loaded reviews remain visible if a later stream event fails. The corresponding player team/roster/payment/stadium widgets were added to the embedded register for caller-level data and runtime review.


- Player team-profile embedded components and the reschedule action banner are now explicitly registered. Source review confirmed the roster section exposes separate loading/error/empty branches and a retry callback; runtime role, data freshness, and action-eligibility verification remains pending.


- Owner inbox/ledger/tournament embedded surfaces, player checkout roster list, payment decoration, and shared date-picker step chip are now represented in the component register. The bracket builder helper was excluded from the UI inventory because it does not define a standalone Widget surface. Caller-level runtime checks remain pending.


- Shared refund badge and notice components are now explicitly registered. Their localized status/ETA/amount copy is source-reviewed; authoritative refund lifecycle, amount consistency and theme contrast remain pending verification against actual refund states.


- **Rules 9, 28, and 36:** stadium review streams now preserve the last loaded reviews after a refresh error and expose a localized stale-data warning plus 48dp retry action. The retry replaces the stream subscription without first clearing visible data. Runtime verification remains pending.


- **Rule 10 — Bilingual visual integrity:** the add-stadium amenities heading now uses `AlignmentDirectional.centerStart` rather than a locale-conditional physical alignment. Runtime RTL/LTR rendering remains pending.


- **Rules 9, 10, 29, and 36 — save feedback, bilingual copy, and duplicate-safe recovery:** owner stadium persistence and profile synchronization now have separate failure handling so a successful DB write is not misreported as a failed stadium save; default notes and blocked/auth-expired messages are bilingual.
- **Rules 29, 36, and 43 — payment callback integrity and failure handling:** callback URLs are parsed by HTTP(S) URI host/path/query rather than substring matching. Untrusted hosts, path-only status URLs, and `standalone` text no longer imply payment success; only explicit success/failure parameters on trusted payment hosts are acted upon. Provider compatibility and DB polling behavior remain to be validated on device; this source change alone does not establish end-to-end payment correctness.


- **Rules 10, 29, and 36 — schedule accuracy and identity integrity:** player slot generation now honors all `breakTimes` intervals saved by the stadium wizard (with legacy `breakTime` fallback), preventing slots from being offered during secondary stadium breaks. Manual tournament-team creation now rejects an empty captain ID instead of inserting a hard-coded placeholder UUID. Runtime and server-side validation remain pending.


- **Rules 28, 36, and 43 — media lifecycle and persisted data integrity:** edit-mode stadium photos are no longer deleted from Storage before the edited record is saved; upload progress callbacks are guarded against disposed screen contexts. Cleanup of Storage objects removed from a successfully saved edit remains pending; the current behavior prioritizes avoiding broken persisted image URLs.


- **Rules 10, 29, and 36 — schedule parity and authenticated actions:** owner schedule rendering now consumes the same multi-break configuration as player availability and excludes partial-overlap slots; team update actions no longer upload under a synthetic `unknown` user path when authentication context is absent. Runtime verification remains pending.


- **Rules 29 and 36 — input validation and error prevention:** tournament wizard fee and prize fields now reject invalid, infinite, or negative numeric values before payload construction; zero remains permitted. Runtime form behavior remains pending.


- **Rules 29, 36, and 43 — payment policy fail-closed:** the pre-payment active-cash-booking check now uses the strict Supabase query. A failed read can no longer masquerade as an empty booking history and permit the cash-payment route; it stops submission and asks the player to retry. Server-side enforcement remains authoritative.


- **Rules 29, 31, and 36 — protect in-progress tournament matches:** automatic round rescheduling is blocked after scheduled kickoff or any recorded home/away score/winner, rather than waiting for a winner/home score only. Runtime verification remains pending.


- **Rules 9, 10, and 36 — loading-state communication:** the player tournament roster now exposes a localized shared loading state while data is fetched; retryable error handling is preserved. Runtime verification remains pending.


- **Rules 29 and 31 — booking time-boundary accuracy:** player slot generation no longer offers a 30-minute slot whose end would exceed the configured stadium closing time. Runtime and backend boundary checks remain pending.


- **Rules 29 and 31 — owner/player schedule consistency:** owner schedule slots now respect exact opening and closing minutes and do not show partial final half-hours beyond closing; overnight/24-hour schedules are calculated on an operational-minute timeline. Device verification remains pending.


- **Rule 10 — RTL geometry:** shared terms/privacy and participant-management dialogs, collective invite sheet, and booking-duration chips now use directional insets/alignment instead of physical left/right assumptions. Modal source review found safe-area configuration on the inspected sheet entry points; runtime keyboard/system-bar verification remains pending.


- **Rule 10 — Safe Area:** the Add Player modal route now enables `useSafeArea` so its top edge respects system bars/cutouts. Keyboard and gesture-navigation rendering remain pending device verification.


- **Rules 29 and 36 — input validation and bilingual feedback:** stadium wizard price/deposit/ball-rental inputs now reject invalid or non-finite values before save, and the image-upload wait message is localized. Runtime validation remains pending.


- **Rules 29, 36, and 43 — team persistence feedback and media consistency:** a successful team insert is no longer misreported as a failed create solely because the follow-up list refresh failed; selected logo upload failure now blocks the team write and is surfaced to the user. Runtime verification remains pending.


- **Rules 29 and 36 — signup password feedback:** password-strength scoring now counts five distinct characteristics; minimum length is no longer counted twice in place of lowercase characters. Source-level correction only; UI/runtime feedback remains pending.
- **Rules 29, 36, and 43 — owner dashboard consistency:** stale analytics responses from older date/court filters are ignored, and disposed controllers invalidate outstanding requests before listener notification. Runtime filter-race validation remains pending.


- **Rules 29, 31, 36, and 43 — payment state idempotency:** booking and tournament fallback pollers now prevent overlapping asynchronous timer reads and latch confirmed status before the success callback. Runtime webhook-delay and slow-network validation remains pending.


- **Rules 9, 10, 29, and 36 — Book Tonight async state recovery:** slot discovery now has a shared bilingual loading state, a retryable error state, and single-flight reload protection. Runtime slow-network/offline retry behavior remains pending.


- **Rules 9 and 10 — bilingual signup feedback:** password-strength status labels now render in Arabic or English according to the active locale. Device/readability verification remains pending.


- **Rules 9, 29, 36, and 43 — signup recovery and truthful status:** unexpected auth failures no longer strand the submit button in loading; secure-storage failure after account creation is distinguished from auth failure to reduce duplicate-registration risk. Runtime verification remains pending.


- **Rules 29, 31, 36, and 43 — stale checkout response isolation:** payment polling generation tokens invalidate in-flight responses when a poll is replaced or checkout cleanup cancels polling; a late response cannot update a superseding checkout. Runtime race validation remains pending.


- **Rules 29, 36, and 43 — owner dashboard data freshness:** stale championship refresh responses/errors are ignored when a newer refresh starts or the active owner scope changes. Runtime refresh-race validation remains pending.


- **Rules 31, 38, 39, and 43 — owner-scope isolation:** championship approval-notice claim responses are now discarded if the authenticated owner or owner-scope generation changes while the request is in flight. This prevents an old account's asynchronous result from contaminating the next owner's local dashboard state. Source-level correction; runtime account-switch validation remains pending.


## Live Supabase review — 2026-11-01

Read-only advisor and function-source review was performed against project `mktqkddbcddrxjxabdua`. No database schema, policy, function, or Auth setting was changed in this pass.

- Security advisors: 197 `authenticated_security_definer_function_executable` findings and 1 `auth_leaked_password_protection` finding. The 197 count is not treated as 197 confirmed exploitable vulnerabilities: inspected examples include explicit caller-role/ownership checks, but every exposed SECURITY DEFINER function still requires individual authorization review before changing EXECUTE grants.
- Performance advisors: 44 `auth_rls_initplan` findings, 51 `multiple_permissive_policies` findings, and 79 informational unused-index findings. No blanket policy rewrite or index removal was performed.
- Edge Function inventory: `create_paymob_intention` v33 (JWT required), `process_paymob_refund` v20 (JWT required), `paymob_webhook` v45 (JWT not required, webhook entry point), `vsp_copilot` v123 (JWT required), `fcm_push` v20 (JWT not required), `process_tournament_refund` v16 (JWT required), `create_owner_web_checkout` v10 (JWT required), and `get_owner_web_checkout_status` v7 (JWT required). Non-JWT endpoints require their own request-signature/secret verification review; this inventory alone does not establish that verification.
- Team League result submission: live source for `public.submit_team_league_match_result(uuid,uuid,text)` verifies authentication, match/team membership, and the result lock, but the inspected definition does not enforce that kickoff has passed. This is a server-side lifecycle gap; exact SQL change must be reviewed and approved before deployment.
- Auth setting: leaked-password protection is disabled. No in-chat Auth configuration action is available; enable it manually in Supabase Dashboard → Authentication → Settings → Password Security → Leaked Password Protection.

These findings remain open; no runtime tests, SQL migrations, advisor cleanup, CI, build, or APK extraction were run.


## Monitored compile failure and source remediation — 2026-11-01

The already-existing GitHub Actions run [41286819423](https://github.com/mohamedsalh333555/VSP.App/actions/runs/41286819423) reached `Build installable test Release APK` and failed during Flutter compilation on commit `6eb50fdd2c4e6879a4c8a95a5a0de1415af4a5aa`. The first actionable Dart diagnostics were:

- `stadium_details_screen.dart:68`: unmatched `Expanded(` because the nested `Material` widget was not closed before the outer `Expanded`.
- `facility_onboarding_screen.dart:104`: `VSPErrorState` was unresolved because `lib/shared/widgets/vsp_error_state.dart` was not imported.

The current branch now contains the narrow source fixes in commits `82f5e687f019adf986455a4eb56126f3f08902a1` and `8e76fea76083ca6eb3900f37690958cf1eddfffc`. The failed workflow predates both fixes, so it cannot validate them. No build was re-triggered, no artifact was created, and all 44 rule statuses remain runtime-pending.
