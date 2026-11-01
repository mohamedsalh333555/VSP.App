# VSP Design System V2 — Migration and Coverage

## Source of truth

- Canonical tokens: `lib/core/ui/tokens/vsp_design_tokens.dart`.
- Global Flutter defaults: `lib/core/theme/app_theme.dart`.
- Shared component grammar: `lib/core/ui/components/` and `lib/core/ui/vsp_ui.dart`.
- `lib/core/ui/tokens/vsp_tokens.dart` is now a compatibility layer only. Its public names resolve to V2 tokens; do not add new visual values there.

The compatibility layer preserves existing numeric geometry (including the legacy 4/8/12/16/20/24/32 spacing values) while redirecting colors, radii, sizes, states, shadows, glass, typography and scroll padding to V2. This avoids a risky app-wide spacing change during migration.

## Shared components updated in this batch

| Component | Change |
|---|---|
| `VSPPrimaryButton` | One canonical renderer; consistent disabled treatment for solid and gradient buttons; optional width, padding and leading icon; single-line text handling |
| `PrimaryButton` | Backward-compatible adapter to `VSPPrimaryButton`; retains existing public API, haptic feedback and 1.5s duplicate-tap guard |
| `CustomTextField` | Migrated from legacy visual constants to V2 semantic colors, border, radius, size, spacing and motion tokens |
| `VSPCard` | Glass blur is skipped on low-performance devices while preserving the glass surface treatment |
| `VSPBackButton` | Minimum 48dp hit area; uses semantic color and motion tokens |
| `SocialAuthButton` | Migrated to V2 radius, color, border, spacing and size tokens |
| `VSPNetworkBanner` | Migrated to semantic colors, typography, spacing, radius, border, shadow and motion tokens |
| `VSPPositionSelector` | Migrated to V2 tokens and enforces the 48dp minimum interactive height |
| `VSPNetworkBanner` | Migrated remaining semantic colors, typography, and spacing to V2 tokens |
| `SocialAuthButton` | Uses semantic button state and Material ink interaction with a 48dp minimum height |
| `VSPIconBadge` | Uses canonical badge background, dimensions and border-opacity tokens; remains circular because it is not an empty-state illustration |
| `VSPEmptyState`, `VSPStateView`, `VspBottomNavBar` | Existing V2-based patterns reviewed; their screen-specific usage still requires verification |
| `ChampionEmptyState` and `League1v1NoGovernorateState` | Aligned to the shared 56dp charcoal square state tile, semantic typography and canonical action button |
| `OfflineErrorScreen` and `MaintenanceScreen` | Content now respects safe-area insets; offline retry uses the canonical primary button |
| App startup and global error fallbacks (`lib/main.dart`) | Failure content now scrolls inside safe areas; retry uses the canonical primary button |

## Token consistency corrections

- The accessibility progress-stroke value now aliases the actual component progress-stroke token.
- Added an explicit 20dp compact spacing token so the compatibility alias does not misuse the input-padding token.
- Added the remaining legacy medium-border primitive to the V2 semantic palette.

## Coverage status — current checkpoint 2026-11-01

This document records the shared foundation migration. It is not, by itself, a completed UXLP-44 screen audit.

- Current `docs/UXLP_44_SCREEN_REGISTER.md`: **338 unique Dart screen/surface paths**, **366 table rows** (28 repeated paths record separate embedded-component findings), plus one shared navigation component entry.
- The recorded heuristic source scan is historical: it fetched 128 candidate files from an earlier 215-path inventory. It has **not** been rerun against the current 338-path register; complete current Design System scan coverage is therefore **not proven**.
- A separate current partial triage scanned PR diff additions across **356 changed Dart files (15,156 added lines)**; 304 of the 338 registered paths are now changed by the PR. The initial full-file sweep fetched/scanned 69 then-unchanged registered paths; 35 have since been changed by the resulting fixes and 34 remain unchanged. It found and corrected 28 raw-color files, six physical left/right geometry occurrences across five files, ten inline duration/delay values across seven files, and 19 additional changed-surface raw-color findings. This covers selected patterns, not every unchanged line in all changed files; it does **not** establish a complete full-file scan of all 338 paths.
- All 338 unique registered paths have source-review notes, but those notes are not runtime passes. Embedded caller behavior, Arabic/English direction, compact/large text, keyboard/system insets, contrast pairings, and loading/empty/error/success states still need direct verification.
- The current global UXLP-44 matrix records 39 rules as `source reviewed—runtime pending` and rules 25, 31, 38, 39, and 41 as `needs product decision`. No rule has a runtime pass. This global matrix is not a completed 44 × screen × state matrix.
- The next audit gate is a current-branch static scan across the full 338-path register, completion of the per-screen/per-state rule mapping, closure of objective source findings, and then one consolidated device/runtime validation.
- Do not mark a screen or rule as passing solely because it uses a shared V2 component. Verify the actual screen composition, role, locale, state, navigation, and runtime layout.

## Additional owner-flow review batch

- Reviewed owner booking modal/coordinator/cancellation dialog, tournament score and auto-schedule surfaces, stadium wizard dialogs, tournament dashboard/manual-team/prize-delivery surfaces, and documentation upload confirmation.
- Both manual-team controllers already dispose when the sheet completes; no duplicate disposal change was needed.
- Added scrollable AlertDialog content for the two manual-booking cancellation choices so long bilingual content remains reachable on short screens.
- Disposed the prize-handover notes controller after the dialog closes and the tournament score edit-reason controller after its bottom sheet completes.
- These source-level corrections do not constitute runtime verification; all affected surfaces remain runtime pending.


## Player booking and account-flow review batch

- Reviewed player bookings, match details, profile/edit profile, player team, stadium details, team dashboard, team creation, booking payment selection, chat dialogs, booking cancellation, and refund tracking.
- Fixed a private collective-match early-return path that previously left the join button/action state stuck in loading after showing the invitation-only message.
- Made the player booking-cancellation confirmation scrollable for compact screens and bilingual content.
- Constrained the payment-method sheet to the available viewport and made its options scrollable instead of allowing a fixed-height column to overflow on short devices.
- Chat report controllers already dispose on dialog completion; team creation controllers already dispose on sheet completion. These were verified and left unchanged.
- Runtime/device checks remain pending; this source review does not mark these surfaces as passed.


## Owner dashboard and onboarding review batch

- Reviewed owner add-stadium and tournament wizards, account management, dashboard, documentation wizard, profile, tournament dashboard, and subscription plans; also reviewed player champion and FAQ/support screens.
- Verified that stadium/documentation step pages use scrollable content where needed, the tournament wizard content scrolls, and the tournament wizard/dashboard fixed action bars explicitly account for the bottom system inset.
- The documentation wizard blocks accidental exit during active uploads and presents a confirmation before discarding progress.
- No business-policy, payment, subscription, or account-permission changes were made in this source-review batch. All surfaces remain runtime pending.


## Player tournament and booking-entry review batch

- Reviewed booking success, challenge-team selection, tournament roster management, language and notification preferences, tournament registration success, stadium filtering, booking-type selection, governorate confirmation, and the incomplete-squad bridge.
- Confirmed the roster editor's sticky save action includes the bottom system inset and the stadium filter sheet is scrollable and safe-area aware.
- Constrained the booking-type selection sheet to the viewport and made its option list scrollable; enabled safe-area handling for the nested create-team sheet and the challenge-code bottom sheet.
- These changes address layout resilience only and do not alter booking or tournament eligibility/payment rules. Runtime verification remains pending.


## Owner booking and location-picker review batch

- Reviewed the owner stadium location picker, booking action panels/actions, booking details and form fields, duration selector, header/time card, WhatsApp receipt utilities, booking domain service, owner booking sheet, and quick phone booking modal.
- The owner booking sheet already constrains its height, scrolls its form content, accounts for keyboard/system bottom insets, and disposes all four controllers; the quick-phone sheet similarly scrolls and disposes its controllers.
- Added safe-area handling to the stadium location picker, disposed its search controller after dismissal, and guarded the asynchronous search result from updating a dismissed sheet.
- No booking price, duration policy, cash collection, or WhatsApp receipt business logic was changed. Runtime checks remain pending.


## Tournament scoring, document upload, and invitation review batch

- Reviewed the four score-entry subcomponents, document source selection and under-review dialog, documentation step pager, facility upgrade sheet, quick-booking receipt, cup format selector, bracket preview dialogs, and collective-match invitation surfaces.
- Goal-scorer custom-name input already disposes its controller when the dialog closes. Facility-upgrade and cup-format sheets already enable safe-area handling; collective invite sheets already use safe-area-aware modal routes.
- Enabled safe-area handling for the document source picker and scrollable content for tournament bracket preview dialogs so their bilingual confirmation/content remains reachable on compact screens.
- Source review only; runtime layout and end-to-end booking/tournament behavior remain pending.


## Player home, team, payment, and shared modal review batch

- Reviewed player filtering, book-tonight, governorate selection, post-match outcome prompts, team-league result dialog, match result entry, team leave/delete dialogs, Paymob waiting prompt, team matchup invite, terms/privacy modal, and match participant management.
- The book-tonight, governorate, team-invite, and participant-management sheets already use safe-area/scroll protection; the legal modal uses an internally scrollable content region.
- Made the post-match, team-league, team lifecycle, and Paymob waiting AlertDialogs scrollable to keep content/actions reachable on compact screens.
- No match scoring, team membership, payment verification, or notification-retention business rules were changed. Runtime/device verification remains outstanding.


## Source inventory checkpoint

- The original 128 candidate paths have source-review notes. Fifty-three paths added to the current 181-path register are not yet proven to be covered by the original static scan; this is not full per-rule/state coverage.
- This is a source-review checkpoint only. It is not a 44-rule pass result: runtime states, locale/device combinations, embedded widgets not represented as candidate files, keyboard behavior, and visual overflow still require consolidated device validation and targeted screen-by-screen evidence.
- No APK build or manual test suite was intentionally started as part of this checkpoint. Do not build the release artifact until the remaining UXLP implementation and grouped source fixes are complete.

## Shared root and owner confirmation dialog review

- Rechecked the canonical player and owner application shells, shared bottom-navigation renderer, shared state/scaffold components, global network banner, router/root screen, and global theme/token layer.
- Confirmed both player and owner shells delegate bottom navigation to the shared safe-area-aware renderer; selected and unselected glyphs are supplied as separate Iconsax variants and use the shared semantic color/typography states.
- Found two root-level confirmation surfaces whose AlertDialog content/actions were not configured as scrollable: the owner account-verification celebration dialog and the forced-update dialog. Enabled scrollable dialog layout for both so the action remains reachable on compact viewports and with larger localized text.
- The global offline banner is intentionally an overlay; its possible interaction with page headers requires runtime verification while offline and is not marked as passed from source inspection.
- These are source-level changes only. No UXLP-44 rule is marked passed and no final test or APK build has been started.

## Route-level asynchronous state review

- Reviewed the championship deep-link route in `lib/core/navigation/app_router.dart`.
- Fixed a terminal-state defect: a failed repository request or a completed request returning no championship previously fell through to the same loading spinner, leaving users with an indefinite loading screen.
- The route now distinguishes loading, repository error, and unavailable/empty results, uses the shared `VSPStateView` component, localizes all user-facing state copy in Arabic and English, and provides a clear return-home action. Error guidance now matches the available action rather than promising an unavailable inline retry.
- This is source-level behavior; route deep-link, network-failure, missing-record, and both-locale runtime checks remain pending.

## Notifications center and realtime failure-state review

- Reviewed the notification-center screen, its Supabase repository stream, and the app notification service.
- Confirmed from the client flow that opening a notification marks it as read; it does not delete the row. The only explicit client-side delete in the reviewed screen is the swipe-to-dismiss action, with an Undo action that reinserts the notification. This source review does not yet establish whether a database trigger, scheduled job, or another backend path removes older notifications.
- Found that `getUserNotifications` attached a `handleError` callback that logged and consumed realtime stream errors. As a result, the screen could receive no notification data and render the empty state rather than an error state. Removed the swallowing handler so the UI can distinguish an actual empty list from a failed stream.
- Added a localized error state with a retry action to the notifications screen and made its informational dialog scrollable.
- Refund delivery and notification retention still require backend trigger/cron and runtime verification; no claim is made that the historical disappearance or missing-refund-notification issue is fully resolved by these client changes.

### Notification retention and refund-path evidence (read-only backend inspection)

- Inspected the active VSP Supabase project `mktqkddbcddrxjxabdua` without changing database state.
- `public.notifications` has two non-internal triggers: `trg_sync_notification_message_body` (BEFORE INSERT/UPDATE) and `trigger_notification_fcm` (AFTER INSERT). No DELETE trigger exists on the table.
- The active `pg_cron` jobs contain no notification-retention/delete job. The five-minute `auto_expire_stale_records()` worker updates expired bookings and team-challenge codes; it does not delete notifications. The notification query itself is capped at the latest 50 rows.
- In the reviewed client flow, tapping a notification only calls `markNotificationAsRead`; swipe-to-dismiss is the explicit delete path. Therefore, source and database inspection do not support a claim that opening a notification deletes it or that a scheduled cleanup removes it. The historical disappearance report still needs runtime/log correlation; it is not marked resolved.
- The deployed `process_paymob_refund` Edge Function v20 and `paymob_webhook` v45 both contain an in-app notification insert after the refund reconciliation succeeds. The booking refund RPC itself does not insert a notification, so the edge-function insert is essential. Whether a particular missing refund notification failed at that insert or at downstream delivery remains unproven without the corresponding execution log/row evidence.
- No SQL, migration, function, trigger, cron job, payment rule, or database data was changed during this inspection.

## UXLP-44 rule-by-rule audit checkpoint

- The exact adopted standard is `docs/UXLP_44_VSP_STANDARD.md` (44 rules across perception, decision processing, interaction, system coherence, and cognitive load).
- Added `docs/UXLP_44_RULE_AUDIT.md` as the rule-level evidence matrix. It records the shared-foundation source evidence, findings fixed in this batch, and what remains unverified for each rule.
- Current matrix is deliberately conservative: `source reviewed—runtime pending` is not a pass, and most rules still require mapping against each applicable screen/state. The 181-path register was an earlier historical checkpoint; the current 338-path register is maintained in docs/UXLP_44_SCREEN_REGISTER.md and still does not prove per-rule coverage.
- No final validation or APK build has been run. Continue grouped implementation first, then perform one consolidated validation pass.

## Player post-match result flow source fixes

- `BookingSyncCoordinator.syncUserBookings` now awaits the initial direct server snapshot and returns whether it loaded successfully. A confirmed empty response is delivered as an empty loaded state rather than leaving old data or appearing perpetually uninitialized. The previous user's realtime subscription is cancelled before starting the next user's refresh.
- `BookingProvider.loadUserBookings` now exposes that completion result and clears a stale error after successful data arrives.
- `PlayerHomeScreen` now waits for the authoritative snapshot before scanning for post-match challenge actions and avoids issuing a second booking load inside the popup checker.
- Post-match result entry, confirmation, and dispute dialogs no longer display success messages when the repository returns `false`; they show localized error feedback instead.
- This source fix does not alter match-result eligibility, team identity, scoring, or league rules. Those require domain-level verification before any policy change.
- No final test pass or APK build was run.
- `MatchResultModal` now accepts an awaited async callback, disables the close/cancel/edit controls while submitting, prevents duplicate taps, and closes only when the callback returns success. A false result re-enables the form and preserves the user's selection/review for retry; thrown errors also keep the modal available with localized error feedback. The caller's repository-result handling already shows success only when the server operation returns true.

## Booking detail and owner reschedule recovery feedback

- Player booking issue reports now display success styling only when the report repository returns true; failed submissions display an error state. The report dialog is scrollable.
- Owner reschedule requests now provide explicit localized failure feedback when the repository rejects the request. The follow-up phone action and sheet close occur only after a successful request.
- No booking policy, payment rule, or backend state transition was changed.

## Player bookings initial/refresh loading state

- Added a dedicated concurrent-safe `isLoadingUserBookings` state to `BookingProvider`, separate from the generic mutation loading flag.
- `BookingsScreen` now awaits the initial server snapshot before completing its load sequence and binds its loading indicator to the dedicated state. Pull-to-refresh awaits the actual booking refresh instead of returning immediately; removed a fixed one-second delay previously used to mask refresh timing in the empty state.
- This avoids briefly presenting the empty-state message before the authoritative query completes and gives real feedback during slow requests.
- Player booking details no longer exposes raw enum identifiers for booking status. Added localized Arabic/English labels for pending, confirmed/upcoming, completed, no-show, cancelled, and expired states. Other screens still need the same lifecycle vocabulary audit.
- Player booking cards now use channel-neutral refund-pending copy (`جاري معالجة الاسترداد...` / `Refund processing...`) rather than implying all refunds are bank transfers; the state can cover card and wallet refund channels.
- Player booking cards now render badges from the actual booking lifecycle enum: pending/awaiting payment verification, confirmed/upcoming, expired, no-show, cancelled, in-progress, and completed. A stale `isPaid` flag no longer makes a pending booking appear confirmed.
- Pending-booking cancellation is no longer an immediate trash-icon action. It now requires a localized confirmation that explains the slot will be released, provides success/failure feedback, and uses a 48dp minimum hit target.
## Challenge-result captain eligibility and truthful mismatch feedback

- Player-home challenge result prompts now load the current user's team and require that the signed-in user is that team's captain and the team is one of the two teams in the booking.
- First-result submission now sends the current captain's team ID rather than always sending `playerTeamId`. The second-captain response prompt compares `resultSubmittedByTeamId` with the current team ID (team-to-team), not with the user ID.
- Read-only Supabase function inspection confirmed `submit_challenge_result_atomic` enforces both team membership in the booking and `teams.captain_id = auth.uid()`.
- The different-result action no longer claims an administrative dispute was created. The deployed RPC explicitly keeps a mismatch in `waitingOpponent` and makes the other captain the next reviewer. No backend policy or scoring behavior was changed.
- Read-only trigger inspection confirmed Elo/league points are processed once when the result is confirmed, supporting the existing rankings-updated confirmation.
- Runtime verification across both captains, matching outcomes, and mismatching outcomes remains pending.
- Because `team_members` permits multiple memberships per user (composite primary key only), the captain resolver returns all team IDs where the authenticated user is captain. The player-home prompt selects the participating team for each booking instead of assuming the first team membership is the relevant one.
- The challenge response dialog now handles a missing `pendingOutcome` with localized error feedback rather than force-unwrapping null.

## Owner schedule loading and authoritative availability display

- Added dedicated owner-booking loading, loaded, and error state to `BookingProvider`, separate from generic player/booking mutation loading.
- Owner direct booking sync now emits an empty list as a valid completed snapshot and forwards fetch errors to the provider. Previous user/owner realtime subscriptions are cancelled before changing booking scope.
- `OwnerBookingsScreen` starts its initial owner data loads before the first build and does not render generated time slots as available until the authoritative booking snapshot is loaded. Initial load failure shows a retry state. Subsequent force refreshes preserve the already-loaded schedule.
- This is a client presentation/state correction only. Server-side availability, atomic booking, and conflict rules were not changed.
- `BookingProvider` now tracks the active player/owner identity for booking data. On account/role scope changes it clears the previous list, resets owner-load state, and ignores late callbacks from a prior direct fetch or realtime stream. This prevents stale booking rows from appearing after an account switch.
- The owner schedule now also distinguishes the owner-stadium stream's loading and error states from a genuinely empty stadium list. A retry action restarts the owner-stadium subscription rather than presenting a false no-stadium empty state.
- If the owner booking realtime stream fails after an initial successful load, the schedule keeps its last known slots and displays a localized, non-blocking warning with a Retry action instead of silently hiding the refresh failure.
- Player `BookingsScreen` now keeps the last loaded booking list visible while a refresh is running, and shows a localized non-blocking warning with Retry if synchronization fails. Initial load errors use generic localized copy instead of exposing raw backend error text.
- The player-home result prompt now only considers challenge bookings in `confirmed`, `completed`, or legacy `upcoming` states. Read-only inspection found the deployed `submit_challenge_result_atomic` RPC checks that the match has ended and is not cancelled, but does not explicitly require the booking status to be confirmed/completed. Proposed server-side guard: require `status IN ('confirmed','completed')` before accepting a result. This is recorded for product approval; no SQL or RPC change was made.
- The post-match result callback now returns the repository's boolean result to `MatchResultModal`; failed submissions keep the form open for retry rather than closing after an error message.
- The second-captain result dialog now has a submission lock, action-specific loading indicator, disabled dismissal while the request is active, and retryable error behavior. A failed server response no longer closes the only confirmation surface.
- Owner schedule and pending-booking cancellation failures now show generic localized user-facing messages; raw Supabase/exception strings are not rendered in those surfaces.
- Read-only schema inspection showed `teams` does not enforce unique `captain_id`; the same account can captain both sides. The client suppresses second-captain result review for a booking when the current account captains both participating teams. The RPC still lacks a server-side distinct-captain check; proposed guard requires the first submitter's captain to differ from the responding `auth.uid()`. This is a policy/security decision and remains approval-required; no database change was made.
## Additional governance updates — 2026-10-31

- Canonical bottom-navigation geometry is now `VSPBottomNavMetrics`. The former `VSPDSBottomNavMetrics` and `VSPBottomNavBarMetrics` names are deprecated compatibility aliases that reference the canonical values; new code must not define geometry independently.
- `OwnerOperationalFinanceCard` is the canonical owner finance component used by the dashboard. `OwnerBasicFinancialGlance` and `OwnerProOverviewCard` are deprecated and must not be extended for new surfaces.
- `TeamCardHero` uses a minimum height rather than a hard maximum and flexible stat/footer rows to reduce clipping at narrow widths and larger text scales.
- Runtime visual verification remains pending. Do not mark these changes as visually passed before the consolidated device validation.


## Phase 2 implementation note — canonical bottom navigation token access

The legacy `vsp_tokens.dart` facade re-exports `VSPBottomNavMetrics` from the canonical `vsp_design_tokens.dart` file. This is a compatibility export only: the values remain defined once in the V2 token source. Feature files may migrate to direct V2 imports independently without creating duplicate geometry.


## Phase 2 implementation — state surfaces

The shared `VSPStateView` now uses a bounded-width, scrollable content region for loading and terminal states so localized text and recovery actions remain reachable on compact viewports. The owner tournament stream now distinguishes initial failure from a successful empty list and preserves the last non-empty snapshot on refresh failure with a bilingual retry affordance. These are implementation changes, not runtime validation results.


## Phase 2 implementation continuation

The canonical shared bottom navigation now uses focusable InkWell interaction while retaining the selected/unselected icon contract. Filter and calendar components were updated to expose selected state and minimum touch dimensions, and the shared state presentation is scrollable under compact viewport constraints. Owner finance and notification/support surfaces now distinguish stale snapshots from failed initial loads. See `docs/UXLP_44_IMPLEMENTATION_PROGRESS.md` for the current source change inventory.


## Latest grouped source corrections — 2026-10-31

- Fixed the analyzer findings reported by PR CI run 41221229970 in the payout dialog, add-player invitation sheet, stadium filter sheet, challenge team-selection retry guard, auth provider, and date-picker semantics.
- PR CI run 41222072722 then reported only one remaining informational const-constructor lint in the add-player sheet. The style was corrected in commit `1019b34c03e440ad28f365c04d07f1d11c40f70c`; this commit has not been analyzer-verified.
- Removed a hardcoded Pro monthly amount from the owner dashboard teaser so it cannot diverge from the current public subscription-plan catalog.
- These are source changes only. The CI run stopped at Analyze; no test or APK step completed. At that earlier 181-path checkpoint, the screen/state rule audit and device/runtime review remained incomplete; current coverage is recorded in the status section above.


## Nested championship detail discovery — 2026-10-31

Reconciled the nine Dart components under `lib/features/player/widgets/championship_details`. Two were already registered; seven were newly tracked. The bottom action bar has source evidence for the open/ongoing/completed/cancelled/full state gates; six newly tracked components remain `not yet inspected`. At that historical checkpoint, this raised the inventory to 181 unique Dart screen/surface paths; the current inventory has since grown to 338 unique paths. The original 128-path static scan does not cover 53 added paths until a complete rescan is recorded.


## V2 token facade and shared interaction corrections — 2026-10-31

- Expanded the compatibility facade to expose the complete V2 size scale and typography roles, plus canonical black/transparent/white-alpha color primitives. Existing feature code can now reference the same source-of-truth values without adding local token definitions.
- Applied the 48dp target to the terms checkbox and removed compact visual density from the public-match and championship share actions.
- Hardened public-match action feedback, owner notification stream-error visibility, phone clipboard feedback, and countdown timer lifecycle.
- Corrected championship card lifecycle labels/CTA state so ongoing, cancelled, completed, full, and unknown statuses do not appear as open registration.
- These are source changes only. At that historical checkpoint, the 181-path inventory had no entries marked `not yet inspected`; the original 128-path static scan did not prove coverage of the then-current register. All 44 UXLP rules remain runtime-pending.


## Championship detail state/retry implementation — 2026-10-31

- Matches, standings, and top-scorers surfaces now distinguish loading, empty, error, and stale/live-update states. Retry recreates the matches stream and rebuilds the standings/scorer futures from the parent details screen.
- The new error surfaces reuse the shared `VSPErrorState`; table overflow remains horizontally scrollable and the main details content remains vertically scrollable.
- All nine components in the nested championship details directory are now represented by source-review notes (two were already in the inventory). The 181-path register has no `not yet inspected` entries at this checkpoint.
- The original 128-path static scan is historical and cannot be used to infer current 338-path coverage. Source review/runtime verification and the 44-rule per-screen/state matrix remain incomplete.


## Championship stream resilience follow-up — 2026-10-31

- Added stale-data warning/retry UI for the championship header and match stream; retry recreates both streams.
- Kept the matches tab loading until the first stream event, separating “not emitted yet” from a true empty list.
- Cached standings futures per group across live match updates, with cache invalidation on Retry; bounded group indexes to A–H.
- These changes reuse the shared error state and V2 tokens. They do not change database or tournament business rules; runtime validation remains pending.


- Championship refresh now carries a version from the parent details screen into the standings component. A retry from any child invalidates the cached per-group Future results, avoiding a stale cached error after a different stream failure.

## Current coverage reconciliation — 2026-11-01

- Current `docs/UXLP_44_SCREEN_REGISTER.md`: 338 unique Dart paths, 366 table data rows, and 28 repeated path rows documenting separate embedded-component findings, plus one shared navigation component entry.
- The only evidenced heuristic/static token-and-layout scan covers 128 candidate files from an earlier 215-path inventory. It has not been rerun against the current 338-path inventory; current complete Design System scan coverage is therefore **not proven**.
- Current global UXLP-44 matrix: 39 rules remain `source reviewed—runtime pending`; 5 rules (25, 31, 38, 39, 41) are `needs product decision`. No rule has a runtime pass. The matrix is global, not a completed 44 × screen × state runtime matrix.
- The screen register contains source-review notes for its registered entries, but that does not establish every embedded component, state variant, locale, keyboard condition, safe-area interaction, or device size has passed.

## Monitored compiler diagnostics — 2026-11-01

- Existing workflow run [41286819423](https://github.com/mohamedsalh333555/VSP.App/actions/runs/41286819423) failed in the Flutter Release compile step on older commit `6eb50fdd2c4e6879a4c8a95a5a0de1415af4a5aa` because of an unmatched widget-tree delimiter in `stadium_details_screen.dart` and a missing import for the shared `VSPErrorState` in `facility_onboarding_screen.dart`.
- Both source causes were corrected on this branch in commits `82f5e687f019adf986455a4eb56126f3f08902a1` and `8e76fea76083ca6eb3900f37690958cf1eddfffc`. The old run does not validate the new commits; runtime and consolidated verification remain pending.
- No build was triggered during this review and no APK artifact exists from this run.


## Semantic color alias cleanup — 2026-11-01

- Replaced raw black/white/transparent UI literals with existing VSP design-system aliases in 115 auth/owner/player surfaces and embedded widgets: welcome, forgot-password dialog, create-tournament wizard, owner dashboard, owner tournament dashboard, subscription plans, tournament brackets, owner bookings, owner booking filter bar, owner profile, and owner payout OTP sheet.
- Added canonical alpha primitives `black26`, `black45`, `black54`, `black87`, and `white70` to `VSPDSColors` and exposed compatibility aliases in `VSPColors`; remaining raw opacity literals in the reviewed surfaces now use those tokens.
- The changes reuse existing semantic/primitive colors and cover auth, owner, and player booking/tournament surfaces, including challenge selection, checkout financial summary, championship details, match details, live matchup, and notifications. Five owner tournament dialogs, the owner emergency-closure confirmation, and twenty player dialogs plus five additional player sheets (including team-league and fee-transparency flows) now explicitly opt into route safe-area protection. No business, payment, authorization, or data behavior changed.
- Runtime contrast and state verification remain pending.


- Additional owner coverage: quick-booking customer/duration/payment sections, draw-room matchup tile, and manual-team options/roster components now use canonical semantic colors for interface chrome. The manual-team jersey swatch palette remains explicit feature data (white/red/blue/amber/black) and was intentionally not mapped to semantic status colors.

## Additional VSP Design System V2 cleanup — 2026-11-01

- Added exact alpha primitives `white02`, `white04`, `white06`, `white50`, `white54`, `black15`, `black55`, and `black60` to `VSPDSColors`, with compatibility aliases in `VSPColors`. These preserve existing rendered alpha values while centralizing them.
- Replaced raw Flutter black/white/transparent color constants in 19 registered auth, owner, player, and shared UI surfaces with canonical `VSPColors` aliases. A follow-up source scan confirmed no remaining raw `Colors.black`, `Colors.white`, or `Colors.transparent` references in the 19 targeted files.
- Added `VSPDSMotion.microInteraction` (160ms) and exposed `VSPDSMotion` through the compatibility facade. Replaced inline 160ms/180ms durations in quick-booking payment, all-stadium filter, filter-category sidebar, and terms-checkbox interactions without changing their timing.
- `CopyablePhoneText` now uses locale-directional start alignment and explicitly renders the phone-number text LTR.
- These corrections are source-level evidence only. Runtime contrast, Arabic/English alignment, device insets, and motion behavior remain pending; no UXLP-44 pass is claimed from this batch.

## Expanded token and interaction cleanup — 2026-11-01

- Added alpha primitives `white03`, `white20`, `white25`, `black10`, `black25`, `black30`, and `black85`; added semantic `warningSoft` and `warningBorder`. Exact legacy alpha values were preserved.
- Extended `VSPDSMotion` with `press` (120ms), `selection` (200ms), `microInteraction` (160ms), `indicatorTransition` (300ms), `fadeIn` (400ms), `bannerTransition` (600ms), and a 50ms stagger-step constant. Existing 250ms/1500ms timings now reference canonical tokens where reviewed.
- Migrated the remaining raw palette references found in the 69 full-file scanned register paths, including owner bracket scoring, Copilot, owner insights/verification, ledger, player filters, booking cards, refund badge, banner, tournament wizard, and champion surfaces.
- Replaced physical left/right spacing in the inspected tournament wizard and Add Stadium hours components with directional geometry. The Copilot loading bubble now uses directional alignment and Arabic/English status copy.
- Removed the arbitrary 800ms wait from the player-home refresh indicator; it now awaits the actual stadium refresh future.
- Post-fix checks re-fetched all 28 files with raw-color findings and confirmed no remaining `Colors.black`, `Colors.white`, `Colors.transparent`, or `Colors.amber` references in those files. This remains static source evidence, not a runtime pass.

## Explicit input-direction support — 2026-11-01

- Added an optional `textDirection` override to shared `CustomTextField`; existing automatic LTR handling for email, phone, URL, and numeric fields remains unchanged.
- Owner payout Instapay now requests the email keyboard, and IBAN is explicitly LTR in Arabic and English contexts.
- Literal-copy triage of the 35 then-unchanged registered paths found only three payout-format examples, not untranslated user-facing labels. One of those paths has since been changed by this correction; 34 remain unchanged.
- Runtime keyboard, caret, paste, and bidi behavior still require consolidated device validation.
