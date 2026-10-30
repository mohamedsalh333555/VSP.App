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

## Coverage status

This is a shared-foundation migration, not a completed screen audit.

- UXLP-44 standard: written.
- Candidate screen register: 128 Dart paths.
- Shared component audit: initial pass and the changes above applied.
- Static source scan of all 128 registered candidates: completed for legacy/V2 token imports, raw color/text-style declarations, hard-coded motion durations, safe-area markers, and modal entry points.
- Source review has now covered the shared navigation bars and the startup/auth selection plus player/owner root shells listed above; runtime checks remain pending.
- Route-level body safe-area wrappers were added to the screens recorded in the latest register updates; screens with dedicated bottom action/navigation bars retain their own inset handling.
- Rule-by-rule screen review across player and owner roles: still in progress; static scan does not establish a pass.
- Arabic/English runtime comparison, large-text checks, keyboard/safe-area checks, and device screenshots: not yet verified for every surface.
- Added regression tests for token alias equivalence, primary-button interaction, and back-button touch-target size.
- Flutter analyze, automated tests, and release APK: intentionally deferred until the grouped implementation batch is complete.

Do not mark a screen as passing UXLP-44 solely because it uses one of these shared components. Check the actual screen composition, role, locale, state, navigation, and runtime layout.


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

- The 128-path candidate register now has source-review notes for all 128 entries; there are no entries left marked `not yet inspected`.
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
- Current matrix is deliberately conservative: `source reviewed—runtime pending` is not a pass, and most rules still require mapping against each applicable screen/state. The 128-path register remains the screen inventory; it does not prove per-rule coverage.
- No final validation or APK build has been run. Continue grouped implementation first, then perform one consolidated validation pass.

## Player post-match result flow source fixes

- `BookingSyncCoordinator.syncUserBookings` now awaits the initial direct server snapshot and returns whether it loaded successfully. A confirmed empty response is delivered as an empty loaded state rather than leaving old data or appearing perpetually uninitialized. The previous user's realtime subscription is cancelled before starting the next user's refresh.
- `BookingProvider.loadUserBookings` now exposes that completion result and clears a stale error after successful data arrives.
- `PlayerHomeScreen` now waits for the authoritative snapshot before scanning for post-match challenge actions and avoids issuing a second booking load inside the popup checker.
- Post-match result entry, confirmation, and dispute dialogs no longer display success messages when the repository returns `false`; they show localized error feedback instead.
- This source fix does not alter match-result eligibility, team identity, scoring, or league rules. Those require domain-level verification before any policy change.
- No final test pass or APK build was run.
- `MatchResultModal` now accepts an awaited async callback, disables the close/cancel/edit controls while submitting, prevents duplicate taps, and closes after the callback completes. If the callback throws, the modal remains available and shows localized error feedback. The caller's repository-result handling already shows success only when the server operation returns true.

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
