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


## Latest implementation continuation — account scope and support interaction

- Player navigation preference is now keyed by authenticated user ID; account switching resets/restores the correct user's tab and clears the prior user's pending-result prompt suppression.
- Owner shell resets its selected tab to dashboard when the authenticated owner changes.
- Support ticket message send has a localized tooltip, a minimum 48dp target, and is disabled until a non-empty message is entered and while a send is active.
- FAQ question headings now use the shared theme typography role.
- The player no-team card uses explicit localized fallback text when the player's position is unset.

These are source-only changes. No CI, analyzer, tests, runtime checks, migrations, or APK build were run; all 44 rule statuses remain runtime pending.


## Continued source implementation — responsive sheets, recovery, and shared controls

Additional source commits on branch uxlp-44-implementation:

- create_team_sheet.dart: sheet height responds to keyboard and top safe-area insets; fixed action row remains within the visible viewport; removed duplicate keyboard inset from bottom padding; subtitle wraps within its header column.
- create_team_members_section.dart: roster empty state now uses a charcoal square icon container and readable secondary copy; remove-member action has localized tooltip and 48dp target.
- collective_match_invite_sheet.dart: failed initial invite reads now show a retryable load-error state rather than a false unavailable-invite state; failed refreshes preserve any supplied booking snapshot and label it as stale; destructive confirmation dialogs are scrollable.
- vsp_terms_and_privacy_modal.dart: dialog height accounts for keyboard insets and close action has a 48dp target.
- payment_cancel_dialog.dart: exit confirmation copy is scrollable.
- vsp_bottom_nav_bar.dart: avoids duplicate semantic announcements from nested navigation wrapper and InkWell.
- primary_button.dart / vsp_button.dart: debounce lock is released even if a synchronous callback throws; long button labels can wrap to two lines.

All changes are source-only. The 44 rules are not marked complete; screen-wide and runtime evidence is still pending. No CI, analyzer, automated tests, runtime checks, database migrations, or APK build were run.


## Support retry wiring follow-up

- Corrected all support-ticket detail retry affordances to rebind both ticket and message streams for the active account, including the top-level stale warning and message-stream empty/error recovery states.
- Corrected the support-ticket list stale-data banner to replace the stream subscription on retry instead of calling setState with the same failed stream.

Source-only. No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.


## Additional copy and interaction corrections

- FAQ/support page now shows readable localized fallback copy when the configured WhatsApp/phone contact is missing, rather than exposing the internal localization key.
- Collective match action failures (join, leave, manual-player count, remove participant, cancel) now display localized actionable copy and log the technical exception separately.
- Support ticket creation failures now preserve generic localized user copy while writing technical details to the app logger.
- Date picker year/month/day options and step chips use InkWell for keyboard/focus support.
- Add-player phone search forces LTR entry and submits from the keyboard Search action.

No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.


## Profile/support follow-up

- Profile governorate picker receives a viewport max-height to keep its list scrollable on compact displays; profile team card uses InkWell for focusable navigation.
- Support-ticket detail retry callbacks now create new ticket/message stream instances; list stale-data retry also reconnects.
- Support contact fallback copy is localized and no longer leaks an internal key.
- Technical exceptions for support ticket creation and collective match actions are logged separately from concise localized user messages.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Owner booking and collective-share follow-up

- Owner booking sheet now subtracts keyboard, top safe-area, and bottom safe-area insets from its maximum height; removed duplicate keyboard inset from inner padding so fixed bottom actions stay within the visible area.
- Collective invitation sharing catches errors and displays localized recovery guidance while logging the technical exception.
- Owner no-show report errors are logged and no longer expose raw exception text to the owner.

Source only. No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Latest owner booking and collective-match recovery batch

- Owner booking sheet now subtracts keyboard plus top/bottom safe areas from its viewport constraint; keyboard inset is not added again to internal bottom padding.
- Collective invite share now catches credential-fetch and platform-share failures; stadium map launch checks the returned launch status and displays localized feedback on failure.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Support message account-race correction

- Support composer send now captures account identity/generation; late responses from an old account cannot clear a new user's draft or alter a newer send's loading state. Error feedback is scoped to the originating active account, with technical details sent to the logger.

Source-only. No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.


## Authentication account-isolation follow-up

- Auth profile retry now invalidates older profile requests and ignores late responses after account switches; it accepts only a model whose UID matches the requested Supabase user.
- Realtime user-profile callbacks verify both the active auth identity and incoming profile UID before mutating AuthProvider state.

No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.


## Shared animated button cooldown correction

- VSPAnimatedButton now schedules cooldown release from finally, so a synchronous callback exception cannot leave its AbsorbPointer active indefinitely.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Date-picker accessibility follow-up

- Date-picker step chips expose localized step/value labels and current selected/enabled state through one semantic control.
- Year, month, and day options expose their displayed value and selected state as one semantic button while retaining focusable InkWell interaction.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Championship empty-state responsive pass

- 1v1 governorate banner return action now has a minimum 48dp touch target.
- Shared championship empty-state content and the 1v1 no-governorate state now use vertical scrolling to avoid compact-screen/large-text overflow.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Segmented-control and filter-chip implementation

- Owner Pro overview/insights tabs now use semantic, focusable controls and 48dp selection surfaces.
- Owner venue filters now expose the selected venue through semantics and meet 48dp minimum height.
- Championship detail pill tabs now expose selected state and meet 48dp minimum height.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Support ticket creation sheet safety

- New-ticket sheet now has a viewport constraint that accounts for keyboard and both safe-area edges; its content scrolls within that bound and the inner padding no longer duplicates keyboard inset.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Owner financial and upgrade modal safety

- Owner payout dialogs explicitly enable scrollable AlertDialog layout.
- Payout password re-auth sheet now subtracts keyboard and top/bottom safe areas from its height and retains its own scrollable form.
- Facility upgrade sheet now subtracts top/bottom safe areas from its viewport height and retains vertical scrolling.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Payout re-authentication feedback

- Owner payout password validation and incorrect-password feedback are now Arabic/English.
- Thrown re-authentication failures are logged, return the form to an actionable state, and show localized retry guidance instead of leaving the verification control loading.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Payout request action recovery

- Payout submission exceptions now restore the dialog to an actionable state, log the technical exception, and show localized retry copy rather than leaving the confirmation action stuck loading.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## RTL alignment corrections

- Owner booking form labels and owner venue filter chip spacing now use directional start padding.
- Shared bottom-navigation notification dot now uses directional end positioning so its placement mirrors in RTL.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Subscription benefit copy correction

- Removed the unsupported 24/7 owner support promise from the facility-upgrade sheet; replaced it with bilingual priority-support-access wording.

No plan entitlement, price, trial, backend rule, CI, analyzer, tests, runtime checks, migration, or APK build was changed/run.


## Subscription comparison consistency

- Removed the unsupported 24/7 service-level claim from the subscription-plan comparison and aligned its Arabic/English copy with the facility-upgrade sheet's priority-support-access description.

No subscription pricing, entitlements, plan data, CI, analyzer, tests, runtime checks, migrations, or APK build were changed/run.


## Payout rejection copy normalization

- Payout RPC rejection details now go to diagnostics and through the centralized localized error formatter; expired-session responses show explicit bilingual sign-in guidance.

No payout business rules, RPCs, database policy, CI, analyzer, tests, runtime checks, migrations, or APK build were changed/run.


## Shared control semantic de-duplication

- Shared back button and add-player search now expose one explicit semantic button label each without duplicate nested InkWell announcements.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Notification center safe-area and RTL correction

- Removed duplicate bottom system inset from notification list padding; its enclosing SafeArea already accounts for the device inset.
- Changed swipe-to-delete background alignment/padding to directional end so the gesture affordance mirrors correctly in RTL and LTR.
- No notification retention/deletion business rule or database behavior was changed.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Notification and cancellation dialog responsive corrections

- Notification center: removed duplicate bottom safe-area padding and changed swipe-to-delete background to directional end alignment/padding.
- Player booking cancellation confirmation: action buttons stack vertically and expand to full width when available dialog width is below 360dp; wider viewports retain the horizontal two-button layout. Both retain 48dp height.
- No notification retention, cancellation, or refund business rules were changed.

No CI, analyzer, tests, runtime checks, migrations, or APK build were run.


## Analyzer remediation and truthful plan-copy follow-up — 2026-10-31

- Existing PR CI run 41221229970 reached `flutter analyze` and reported three errors: async BuildContext use in the owner payout dialog, an invalid const localized Text in the add-player sheet, and a missing closing delimiter in the stadium filter sheet. It also reported a write-only auth state field and two style infos.
- Fixed the payout context guard, dynamic invite label, stadium filter sheet delimiter, challenge retry-guard braces, unused auth flag, and date-picker label interpolation.
- The next PR CI run 41222072722 reached Analyze and reported only one remaining informational `prefer_const_constructors` finding in the add-player sheet. Added the missing const to its static TextStyle in commit `1019b34c03e440ad28f365c04d07f1d11c40f70c`; not yet revalidated.
- Removed the hardcoded `1,000 EGP/month` from the owner dashboard Pro teaser. The subscription screen remains the source for prices loaded from the public plan catalog.
- Both CI runs stopped at Analyze; automated tests and the workflow debug APK step were skipped. No Release APK workflow was dispatched.

The source batch remains open. All 44 UXLP rule statuses are still runtime pending, and the final consolidated review has not started.


## Add-player sheet header resilience — 2026-10-31

- The add-player sheet title now uses the available header width beside the close action, wraps to at most two lines, and truncates only beyond that bound. The close action also exposes a localized tooltip.
- This is a source-level responsive/accessibility correction for Rules 11, 27, and 33. Runtime rendering remains pending; no CI, analyzer, tests, device checks, migration, or APK build was run.


## Add-player sheet keyboard viewport correction — 2026-10-31

- The add-player sheet now constrains its maximum height to the viewport remaining after keyboard and top/bottom system insets. Removed the separate outer keyboard padding so the keyboard inset is accounted for once, while the content remains vertically scrollable and the action/content stays reachable.
- Source-level correction for Rules 11 and 35. Runtime keyboard and device-inset verification remains pending; no CI, analyzer, tests, migrations, or APK build was run.


## Support ticket sheet action visibility correction — 2026-10-31

- The new-support-ticket sheet's maximum-height constraint now wraps the complete padded sheet, rather than only its scroll view. The bottom safe-area padding is therefore included inside the keyboard-safe viewport instead of increasing the sheet's total height beyond that bound; the form remains scrollable.
- This addresses the source-level cause of a bottom action potentially falling outside the visible sheet on compact/keyboard-open layouts (Rules 11 and 35). Device/runtime confirmation remains pending; no CI, analyzer, tests, migrations, or APK build was run.


## Match participant manager resilience — 2026-10-31

- `ManageParticipantsModal` now limits its height to the remaining viewport after keyboard and system insets, and no longer adds the keyboard inset a second time inside its bottom padding.
- A failed participant lookup now has an explicit localized error/retry state rather than appearing as a successful empty roster. Action failures no longer expose raw exception strings; accept/reject/remove and call feedback are localized.
- The title can wrap beside its close action. Close/call/accept/reject/remove controls now expose localized tooltips and 48dp minimum hit targets.
- These are source-level corrections for Rules 11, 17, 27, 33, 35, and 42. Runtime/device confirmation remains pending; no CI, analyzer, tests, migrations, or APK build was run.


## Shared-component and tournament lifecycle correction batch — 2026-10-31

- Expanded the screen/surface inventory from 139 to 181 unique Dart paths by reconciling shared widget/core component directories and nested championship detail components. The register now has 191 path records with 10 repeated entries; all 181 paths now have source-review notes, while rule-by-rule/state coverage and runtime validation remain pending.
- Exposed the full V2 size and typography roles through the compatibility facade (`VSPSize`, `VSPTypography`) and added canonical black/transparent/white-alpha color aliases. This is a token API change; it does not alter existing screens by itself.
- Increased the terms checkbox hit area to the 48dp design-system minimum and added explicit checked/button semantics.
- Public match card actions now check the boolean result of request cancellation, log technical details, show localized safe error messages for join/leave/share failures, and keep the share target at the standard 48dp.
- Owner notification unread-stream failures now render a warning indicator and localized tooltip instead of silently appearing as zero unread.
- Phone-number copy now has a semantic label and localized clipboard failure feedback.
- Countdown timers stop their periodic timer at zero, restart when the target date changes, and still cancel on disposal.
- Championship cards now distinguish `open`, `ongoing`, `cancelled`, `completed`, `full`, and unknown/closed states; only `open` cards present the registration CTA. The details bottom bar already enforces the same open-only registration gate. Share icon buttons no longer use compact visual density.
- The team member import action already uses the requested concise Arabic label `لصق` and English `Paste`; no copy change was needed.

No test or analyzer run was started for this batch. The last observed PR CI runs remain failed at Analyze; tests and the debug APK step were skipped. All changes remain source-reviewed/runtime-pending, and the final consolidated review gate remains closed.


## Shared upload widget accessibility and resilience — 2026-10-31

- The upload-selection card now exposes a labeled button semantic and Material ink interaction while remaining disabled during upload.
- The uploaded-file delete action now has a localized tooltip and a 48dp minimum target. Blank thumbnail URLs are treated as missing rather than being passed to `NetworkImage` or shown as a successful uploaded image.
- Source-level corrections for Rules 17, 27, and 33. Runtime screen-reader, touch, and upload-flow checks remain pending; no CI, analyzer, tests, migrations, or APK build was run.


## Join-request acceptance notification correction — 2026-10-31

- The host's accept action previously called the host-facing `notifyPlayerJoinedMatch` method with the requesting player's ID and an empty player name. That could send the player an incorrect “player joined your match” message.
- Added a dedicated localized `join_request_accepted` notification addressed to the requesting player and linked to the booking; the notification center now renders it with a success icon/color.
- Notification delivery is now best-effort after the server-side accept/reject action. A notification transport failure is logged separately and no longer falsely reports that the join decision itself failed. The booking RPC and authorization rules are unchanged.
- Source-level correction; notification delivery and tap-through runtime verification remain pending. No CI, analyzer, tests, migrations, or APK build was run.


## Championship detail data-state recovery — 2026-10-31

- The matches tab previously treated a stream with no data as an empty schedule, including while the stream was still loading or after an error. It now distinguishes initial loading, true empty results, initial stream failure, and stale data with paused live updates; the stale-data warning exposes Retry.
- The standings and top-scorers FutureBuilders now render the shared localized error/retry state instead of presenting a failed query as “no matches/goals”.
- The championship details screen now recreates the matches stream on retry and rebuilds the standings/top-scorers queries through the same refresh callback. No repository contract or database behavior changed.
- Source-reviewed the nested championship details header, pill tab bar, rules tab, governorate confirmation dialog, squad-builder bridge sheet, matches tab, standings table, and top-scorers tab. Their runtime status remains pending.
- The six newly tracked nested championship files are now source-reviewed; the 181-path register currently has no entries marked `not yet inspected`. This is inventory/source coverage only, not completion of the 44-rule screen/state audit.


## Championship live-stream resilience follow-up — 2026-10-31

- The championship header stream now has the same stale-data warning/retry affordance as the matches stream. Retry recreates both the single-championship and match streams.
- The matches tab remains in loading state until the first stream event arrives; an active subscription with no first event is no longer misreported as an empty schedule.
- Standings futures are cached per group so ordinary live match updates do not repeatedly issue standings queries. Retry clears the cache, rebuilds the standings queries, and refreshes the parent streams.
- Group iteration is bounded to the supported A–H labels to prevent an out-of-range UI crash from malformed group-count data.
- All changes are source-only; runtime and data-volume verification remain pending.


## Player profile avatar consistency — 2026-10-31

- The profile header and the no-team/free-agent card previously used `DecorationImage(CachedNetworkImageProvider(...))` with no image-load failure UI. A stale or inaccessible profile-image URL could therefore leave a blank circle even though the profile URL was present.
- Both surfaces now use one shared local avatar renderer with the same image source and explicit placeholder/error fallback. The profile image remains the source of truth; the fallback appears only when the URL is missing, blank, or fails to load. This does not substitute a team image for a player image.
- Source correction only; remote-image failure and visual consistency still require the consolidated runtime pass. No CI, analyzer, tests, migrations, or APK build was run.


- Follow-up: a monotonically increasing championship refresh version now invalidates cached standings futures whenever either the match or header stream is retried. This prevents a failed standings future from remaining cached after a different child error triggers the parent retry.


## Create-team member chip text bounds — 2026-10-31

- Team member chips previously rendered the full player name in an unconstrained `Text` inside a compact `Row`. Long names could consume the remove-action space or overflow the chip.
- The name now has a bounded width, one-line ellipsis, and a localized fallback for blank names. The remove action remains separately tappable.
- Source correction only; narrow-device and large-text rendering remain pending the consolidated runtime pass. No CI, analyzer, tests, migrations, or APK build was run.


## Public match card lifecycle state correction — 2026-10-31

- The card previously prioritized the host badge over cancelled/ended status, so a host could see “My Match” instead of the actual terminal state.
- Tapping an ended/cancelled open-join card also opened the active collective-invite sheet even though its action button was disabled. Terminal-state taps now open booking details; cancelled/ended badges take precedence for hosts and players alike.
- Source-level state correction; tap-through and lifecycle regression checks remain pending the one consolidated runtime pass. No CI, analyzer, tests, migrations, or APK build was run.


## Open-join booking capacity status — 2026-10-31

- The open-join booking card previously fell through to “Open to join” even when its computed remaining capacity was zero. The card now shows a localized “Full” state in that case.
- This is a presentation correction only; booking capacity enforcement and server-side join authorization are unchanged. Runtime state refresh and full-capacity regression checks remain pending. No CI, analyzer, tests, migrations, or APK build was run.


## Pending payment duplicate-charge guard — 2026-10-31

- Pending booking cards now distinguish an unpaid checkout from a payment already reported as paid/partially paid but not yet confirmed by the booking server.
- When payment confirmation is pending, the card no longer offers Resume Checkout; it shows a disabled verification state, warns the player not to pay again, and directs them to Check Status. The refreshed status response uses the same warning instead of incorrectly prompting another checkout.
- The server remains the source of truth: a paid payment status alone does not mark the booking confirmed. This is a client-side duplicate-payment prevention guard, not a payment-state transition. Runtime webhook delay/retry checks remain pending. No CI, analyzer, tests, migrations, or APK build was run.

## Additional small lifecycle fix — support ticket sheet
- `SupportTicketsScreen._newTicket()` now captures the submitted subject and disposes its locally-created `TextEditingController` after the bottom sheet closes, including dismissal without submission. The captured subject is passed to the ticket details route, so navigation does not read a disposed controller.
- Source-level change only; no tests, analyzer, CI, or APK build were run. Runtime validation remains part of the single final pass.
- Follow-up review caught and removed a duplicate `subjectController.dispose()` left at the end of the support-sheet method; the controller is now disposed exactly once after the sheet returns. No runtime checks were run.
### Focused lifecycle and inset review — 2026-10-31

- Re-reviewed the support-ticket creation and detail screens after the controller-lifecycle correction: the creation controller is now disposed once after the modal returns; the detail composer controller is disposed by the screen state; its composer uses a safe-area-aware bottom region. No additional source change was justified in those paths.
- Reviewed `CreateTeamSheet`: its name/bio controllers are disposed by the state, and its modal opts into `useSafeArea`.
- Reviewed `AddPlayerSheet`: its phone controller is disposed by the state; the sheet bounds its height against the viewport after keyboard/system insets and keeps its content scrollable. Compact-device/keyboard runtime checks remain pending; no runtime pass is claimed.
### Profile-photo persistence failure handling — 2026-10-31

- **Root cause:** the profile-photo coordinator uploaded the image, then attempted to persist the returned URL in the user profile record. It previously returned `success: true` even when that database update failed, and the edit-profile screen ignored the photo-update result and continued saving the other fields. This could show a newly uploaded image in the current in-memory profile while losing the URL after a profile reload, and could report the overall save as successful.
- **Correction:** the coordinator now reports failure when URL persistence fails; `AuthProvider.updateProfilePhoto` returns the actual success result; the edit-profile flow stops before saving the remaining fields and shows an error when the photo upload/persistence step fails. A successful photo save still updates the in-memory profile model.
- **Scope:** client-side result propagation only. No storage policy, database schema, RLS, or server-side behavior was changed. Runtime verification remains pending; no tests/CI/analyzer/APK were run.
### In-app support ticket sheet viewport — 2026-10-31

- **Root cause identified in source:** the ticket-creation bottom sheet opts into `useSafeArea: true`, but its explicit maximum-height calculation also subtracts both system-bar padding values. The sheet then separately adds bottom safe-area padding to its own content. This counts safe-area space twice and unnecessarily reduces the sheet's usable viewport; with the keyboard visible, that can leave the primary action outside the readily visible area.
- **Correction:** removed the duplicate top/bottom safe-area subtraction from the explicit height calculation while retaining keyboard-inset handling, the safe-area wrapper, and scrollable content. The form's primary action remains inside the scroll view.
- **Scope:** UI layout only. No support-ticket database or messaging behavior changed. Runtime verification remains pending; no tests/CI/analyzer/APK were run.


## Booking-card responsive layout correction — 2026-10-31

- Player booking card date/time/price metadata previously placed three intrinsic-width columns directly in a Row. Long localized time values or enlarged text could demand more width than a narrow card provides.
- Each metadata column is now constrained with Expanded, allowing its text to wrap within the available card width while retaining the existing three-column hierarchy and separators.
- Source-only correction. No booking/payment/refund behavior was changed. No analyzer, tests, CI, runtime checks, migrations, or APK build were run.


## Open-match action error copy correction — 2026-10-31

- Leaving an open match and cancelling a join request previously displayed raw caught exception text directly to the player. Both actions now show concise Arabic/English recovery guidance and keep technical details in diagnostic logs.
- No match membership or join-request business logic was changed. Source-only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run.


## Cancelled-booking action-state correction — 2026-10-31

- Active-list booking cards previously rendered the Cancel action for every non-history booking, including records already in `BookingStatus.cancelled`. The cancellation control is now omitted for cancelled records; existing chat/share actions are unchanged.
- This is a presentation/state-guard correction only. Cancellation eligibility, refund calculation, server RPCs, and financial rules were not modified. Source-only; no tests, analyzer, CI, runtime checks, migrations, or APK build were run.

## Booking-card compact-width text resilience

- Player booking metadata labels now truncate within their column, while date/time/price values are centered and limited to two lines with ellipsis. This complements the existing expanded-column layout and prevents long localized time/price strings from forcing horizontal overflow on narrow cards.
- Source implementation only; no analyzer, tests, CI, runtime checks, database changes, or APK build were run.

## Owner schedule slot compact-row resilience

- Maintenance-slot secondary copy now uses the remaining flexible width and ellipsizes instead of forcing the row wider than its card.
- Available, break, and expired slot labels now share the row's remaining width with the state badge and truncate safely on narrow screens and long localized labels.
- Source implementation only; no CI, analyzer, tests, runtime checks, database changes, or APK build were run.

## Owner schedule time-column text bounds

- Start time, merged-slot end time, and night labels are now single-line ellipsized within the fixed time column. This prevents long localized/night labels from painting outside the 75dp column or pushing the adjacent slot card.
- Source-only; no tests, analyzer, CI, runtime validation, database changes, or APK build were run.

## Owner quick-booking and booking-form text resilience

- Quick-booking payment heading now allocates flexible width between the section title and total-price chip; both labels truncate safely instead of overflowing on compact layouts.
- Player counter label in the owner booking form now uses the available flexible width and ellipsizes, preserving the increment/decrement controls on narrow sheets.
- No payment amounts, calculations, collection rules, or booking behavior were changed.
- Source implementation only; no tests, analyzer, CI, runtime validation, database changes, or APK build were run.

## Tournament dashboard UX correction
- Kickoff is disabled when its activation callback is unavailable, avoiding an enabled no-op button.
- Champion name is limited to two lines with ellipsis in the bottom bar.
- No tournament state or data rules changed. Source-only; no tests, analyzer, CI, runtime checks, or APK build.


## Tournament and match modal compact-viewport corrections — 2026-10-31

- Tournament score-entry modal title now shares available width with the close control and wraps to at most two lines.
- Tournament format option title/badge now share flexible width; long subtitles are bounded to two lines.
- Automatic tournament scheduling sheet now has a viewport-based maximum height and scrollable content so its save action remains reachable on short screens.
- Manual team-registration sheet title now shares the header row with the close control without forcing horizontal overflow.
- Match-result modal details now use three equal flexible columns; long stadium/date/price values are limited to two lines with ellipsis.
- Booking-type modal heading and option title/subtitle are bounded to prevent long Arabic/English copy from overflowing compact layouts.
- These are source-level layout corrections only. No tournament, match-result, booking, payment, or database business rules were changed. No analyzer, tests, CI, runtime checks, migrations, or APK build were run.


## Stadium location and bracket dialog lifecycle/responsiveness — 2026-10-31

- **Stadium manual-address sheet:** its TextEditingController was created before opening the modal but had no disposal path. The method now awaits the modal result, disposes the controller after the sheet closes, and returns the unchanged result.
- **Tournament bracket preview:** removed an inline-created TransformationController that had no owner/disposal lifecycle; the viewer retains its default initial transform. The live-draw dialog title now uses flexible width and bounded two-line text beside its icon.
- No location data, tournament draw generation, booking, or payment rules were changed. Source-only corrections; no analyzer, tests, CI, runtime checks, migrations, or APK build were run.


## Owner financial and prize summary row resilience — 2026-10-31

- Payout request and tournament prize-handover dialogs now allocate flexible width between descriptive labels and monetary values. Long Arabic labels wrap to two lines, while amounts stay single-line and ellipsize when needed on narrow dialog widths.
- Display-only layout changes; payout amounts, prize-pool source values, settlement, and prize-delivery behavior are unchanged. No analyzer, tests, CI, runtime checks, migrations, or APK build were run.


## Owner booking action banner compact-width correction — 2026-10-31

- The ongoing-match banner previously placed an intrinsic-width status label and an extension action side by side without constraining the label. The label now receives only the remaining flexible width and is bounded to two lines with ellipsis, preserving the extension action on narrow screens.
- No extension duration, booking eligibility, or booking state behavior changed. Source-only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run.

## Continued dialog and sheet compact-viewport fixes — 2026-10-31

- Stadium deletion confirmation now uses a scrollable AlertDialog so its long bilingual explanation remains reachable on short displays.
- Owner manual-booking deposit cancellation title now shares the dialog header width with its warning icon and is bounded to two lines.
- Player stadium filter/sort header and the main filter-sheet heading now constrain long localized titles instead of allowing the title to compete with adjacent controls.
- Quick phone-booking stadium/date/time metadata now uses flexible, single-line ellipsized fields so long stadium names and localized dates cannot force horizontal overflow.
- Owner Copilot sheet height now subtracts keyboard and top safe-area insets before applying its preferred 78% height, preventing the keyboard from pushing the sheet beyond the available viewport.
- Owner no-show confirmation now uses a scrollable AlertDialog for compact-height and enlarged-text layouts.
- These are source-level presentation/lifecycle corrections only. No booking, cancellation, refund, payout, authorization, or database rules were changed. No CI, analyzer, tests, runtime checks, migrations, or APK build were run.

## League, refund, and compact-dialog follow-up — 2026-10-31

- Team-league match-result and dispute-resolution sheets now cap their height to the viewport remaining after keyboard/system insets and scroll their content, keeping the primary action reachable on short screens and with large text.
- Team-league result submission and dispute-resolution failures now show concise Arabic/English recovery messages; technical exceptions and stack traces are sent to debug diagnostics rather than exposed in the UI.
- Refund-tracking sheet bottom padding now includes the device bottom system inset so its close action and final details remain above gesture/navigation areas.
- No league scoring, dispute-resolution authorization, refund eligibility, refund amount, payout, booking, or database behavior was changed. Source-only changes; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.

## Additional owner modal safe-area corrections — 2026-10-31

- Tournament-format selection sheet now has a viewport-based maximum height and scrollable content, preserving access to all format choices on short displays and with enlarged text.
- Manual stadium-address entry now opts into the modal safe-area behavior and adds the remaining bottom system inset alongside keyboard spacing, keeping the address field and confirmation action clear of system UI.
- These are layout-only changes. Tournament format selection, stadium coordinates, geocoding, booking, and backend behavior were not changed. No CI, analyzer, tests, runtime checks, migrations, or APK build were run.

## Team-league and result-dialog accessibility/copy follow-up — 2026-10-31

- Team-league result entry and dispute review now provide Arabic/English labels, options, confirmations, and error guidance rather than Arabic-only visible copy.
- Long team names and submitted-result labels in dispute review now share available row width and truncate safely; resolution option labels are bounded to two lines.
- Match-result dialog close control now exposes a localized tooltip and a 48dp minimum hit target instead of a compact zero-constraint IconButton.
- No team-league scoring values, win/draw/loss mapping, dispute authority, match outcome rules, or backend behavior changed. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.

## Owner tournament and stadium-location error recovery — 2026-10-31

- Tournament prize-handover failures now keep technical exception/stack details in diagnostics and show concise Arabic/English retry guidance; the notes controller continues to be disposed after the dialog closes.
- Stadium current-location lookup now logs technical failure separately, shows localized permission/retry guidance, and avoids updating the sheet's loading state after its modal context has been disposed.
- No prize ledger entry, payout, GPS permission, stadium coordinate, geocoding, or booking business behavior was changed. Source-only; no CI, analyzer, tests, runtime checks, migrations, or APK build were run.

## Owner quick-booking and tournament action diagnostics — 2026-10-31

- Quick phone-booking no longer forwards an unrecognized raw exception string to the owner; known conflict/amount/time/authorization cases retain their specific localized guidance, while unknown failures use safe retry copy and diagnostic logging.
- Manual tournament-team registration, cash booking confirmation, and tournament score submission now log technical exception/stack details separately while retaining localized user-facing recovery messages. Dialog loading state is reset only while the sheet context remains mounted.
- No booking price, slot lock, payment, tournament registration, scoring, or prize policy was changed. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.

## Participant-management observability follow-up — 2026-10-31

- Accept, reject, and remove-participant failures now write technical exception and stack details to diagnostics while preserving the existing localized, actionable user messages (including the explicit match-full case).
- Notification delivery failures remain separately logged and do not reverse a successful join decision. No participant authorization, capacity, or match-membership rules were changed. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.

## Team-league end-to-end source refinement — 2026-10-31

- League creation and join flows now use bilingual labels and feedback; both modal-owned text controllers are disposed after their routes close.
- Creation, payment-options, join, and stadium-selection surfaces now account for safe-area insets; the stadium chooser and result/dispute sheets keep their content/actions reachable on constrained viewports.
- League payment option copy now derives the per-team fee from the loaded configured fee instead of displaying a hardcoded 30 EGP label. Where the join RPC omits the amount, the client uses the same already-loaded configured fee rather than a separate hardcoded value.
- Team-league cancellation confirmation no longer promises that every paid fee will be refunded. It now states that only policy-eligible amounts are reviewed and explicitly says administrative fees are non-refundable; the cancellation RPC and refund processing were not changed.
- Team-league join/cancel/create/payment setup failures now use localized recovery messages and diagnostic logging rather than exposing raw exception text. Empty-team guidance, tabs, and stadium selection copy now support Arabic and English.
- No league fee configuration, RPC, authorization, payment amount calculation, refund worker, administrative fee rule, or database behavior was changed. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.

## Team-league cards, standings, and fixtures refinement — 2026-10-31

- Team-league onboarding, gathering, standings, and fixture surfaces now render Arabic/English copy, including empty, pending, approved, disputed, booked, and result states.
- Onboarding and gathering fee explanations/share text now use the configured team-entry fee passed from the league screen; hardcoded 30 EGP presentation text was removed from these cards.
- Standings metadata rows and league title now constrain long text; the table uses compact English column labels so all statistics remain legible in the same row layout.
- Fixture dates now format using the active locale; long match names, status labels, and date/venue metadata are bounded. Result submission is no longer presented before a match is booked and its scheduled kickoff time has passed; the user sees localized guidance while waiting.
- Backend limitation retained for approval: source review of submit_team_league_match_result found no server-side booking/scheduled-time gate. The new restriction is client presentation only; no RPC or migration was changed. Server enforcement requires a separately approved SQL change.
- No league points/scoring formula, result reconciliation, captain/team authorization, entry-fee calculation, booking RPC, or refund policy was changed. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.

## Team-league embedded card and fixture follow-up — 2026-10-31

- The onboarding and gathering cards now display the loaded configured fee consistently, including share copy; when fee data is unavailable, the invite text directs users to check the app instead of showing a misleading dash.
- The standings screen is bilingual and its league title/info rows now share available width; the English table uses compact P/W/D/L/Pts headings to preserve the seven-column layout.
- Fixture cards now localize all match states/actions and use the active locale for dates. The result-entry action is shown only after a booking exists and the scheduled kickoff has passed; before then the card shows the appropriate next action or waiting guidance.
- The server-side submit-result RPC currently does not enforce the same booking/time gate. This is explicitly documented as an approval-required backend follow-up; no migration/RPC was changed.
- Source-only. No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.

## Authentication and owner-ledger refinements — 2026-10-31

- Owner financial-ledger export failures now use a localized, non-technical recovery message instead of interpolating the raw platform/filesystem exception into user-facing copy.
- Signup no longer writes raw authentication failure details to debug logs; the existing localized signup error mapping remains the user-facing recovery path.
- Player and owner onboarding exit-confirmation dialogs are now scrollable, preventing their title/content/actions from being clipped on compact-height devices or with larger text.
- Login, signup, create-account, email-verification, and both onboarding screens were source-reviewed for scroll/safe-area structure. No claim of runtime validation is made.
- Source-only. No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.

## Matchup, championship checkout, and player recovery follow-up — 2026-10-31

- The live matchup dashboard now distinguishes failed team/result/standings reads from a verified empty state and offers a localized retry action. Result submission and matchup closure feedback are bilingual; raw backend exception strings are no longer displayed, and the closure confirmation is scrollable.
- Championship roster validation and paste feedback now support Arabic and English. The paste flow checks that the screen is still mounted after the import dialog returns. Registration failures use localized recovery copy rather than raw exception details.
- Match leave failures now use localized recovery feedback rather than rendering the raw exception. Championship detail error dialogs are scrollable.
- These are source-level changes only. The server-side matchup result authorization/closure rules and tournament scoring logic were not modified. No CI, analyzer, automated tests, runtime checks, migrations, or APK build were run.

## Live matchup dashboard recovery state — 2026-10-31

- A failed matchup teams/results read previously only stopped the loading spinner, leaving empty lists that could be mistaken for a valid empty matchup. The screen now renders a distinct localized error state with Retry.
- Match result submission and matchup closure success/error messages now support Arabic and English. Raw repository exceptions are not shown to users, and the close-confirmation dialog is scrollable.
- The result calculation, points/scoring behavior, and repository write operations were not changed. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.

## Owner tournament dashboard and creation error feedback — 2026-10-31

- Tournament creation no longer interpolates raw exception details into the user-facing error; it presents localized retry guidance.
- Owner tournament dashboard now separates a failed participating-team lookup from a genuinely empty team list and offers a retry action, instead of rendering the failure as “No teams joined yet.”
- No tournament lifecycle, team membership, kickoff authorization, or scoring rule was changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.

## Owner tournament kickoff lifecycle follow-up — 2026-10-31

- The owner tournament dashboard now checks `mounted` before updating loading state after the team lookup completes, including the error path. This prevents a disposed dashboard from receiving `setState` after an asynchronous kickoff preparation request.
- The kickoff confirmation dialog is scrollable for compact-height/large-text layouts. Existing kickoff authorization and tournament state transitions are unchanged.
- Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.

## Player profile editing and account deletion refinement — 2026-10-31

- Profile photo-save, profile-update, and account-deletion failures now use localized generic recovery messages rather than exposing raw provider/backend exception details.
- The account deletion confirmation dialog is scrollable on compact-height/large-text devices. The existing confirmation requirement and account deletion operation are unchanged.
- Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.

## Owner account deletion modal lifecycle — 2026-10-31

- Owner account deletion confirmation is now scrollable for short screens and large text. Its password controller is disposed after the dialog closes, and failed deletion no longer exposes raw AuthProvider error details.
- Password reauthentication remains required before the existing delete-account operation; no account deletion, financial, or backend behavior was changed.
- Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.

## Owner emergency-closure dialog refinement — 2026-10-31

- The owner emergency-closure confirmation is now scrollable. Confirmation copy remains explicit that affected bookings enter administrative review/refund handling; the success message states the 24-hour closure duration without implying an immediate refund. Technical failure payloads are replaced with localized recovery guidance.
- The operation's 24-hour duration, booking selection, and server-side administrative review/refund behavior were not changed.
- Follow-up: owner deletion reauthentication/delete exceptions are caught in the dialog; loading is restored and localized retry feedback is shown instead of leaving the destructive-action modal stuck.

## Live matchup embedded widgets localization and density — 2026-10-31

- The matchup result-entry card, standings table, results timeline, and outcome/validation service now use the active Arabic/English locale, including empty states and fallback team names.
- The standings statistics and timeline team/outcome labels are width-bounded to avoid narrow-card overflow. Timeline results are reversed once per build rather than rebuilding the reversed list for every row.
- Matchup scoring values remain unchanged (win = 3, draw = 1, loss = 0); this is presentation and rendering only. Source-only; no analyzer, CI, tests, runtime checks, migrations, or APK build were run.
- Follow-up in the owner tournament dashboard: kickoff preparation, draw generation, competition activation, and related lifecycle failures now pass through the shared localized error handler instead of displaying raw exception text. Tournament state transitions are unchanged.
- Penalty shootout team labels now localize the “pens” suffix and fallback team names.

## Approval-required legal and policy copy findings — 2026-10-31

Source review found four material conflicts in `terms_and_privacy_screen.dart`, in both Arabic and English: owner/signatory age 21 (lines 72–73) vs the current 18+ registration rule; player age 16/guardian exception (147–148) vs 18+ for all roles; a 100% refund promise plus a 20-minute grace/90-day request window (157–158) vs non-refundable administrative/payment fees; and a 150m no-show GPS appeal radius (178–179) vs the current 200m/≤50m accuracy rule. Proposed corrections and exact source locations are recorded in `UXLP_44_RULE_AUDIT.md`. These legal/financial eligibility statements were deliberately not changed pending explicit approval; the existing 60-minute appeal window also needs confirmation before changing.
- Account-deletion recovery follow-up: failed deletion now leaves the confirmation dialog open with its password field available for a retry; the modal closes only when the existing delete operation succeeds or the user cancels.

## Tournament round schedule reset feedback — 2026-10-31

- The destructive round-schedule reset confirmation is now scrollable, its Arabic confirmation sentence is corrected, and success copy is concise and bilingual.
- A failed reset previously produced no user-facing feedback; it now shows a localized retry message. The reset RPC and schedule data rules are unchanged.
- The championship roster import action now says “لصق / Paste” rather than “لصق من واتساب / Paste from WhatsApp”; it reads clipboard text and is not tied to WhatsApp specifically.- Applied the same “لصق / Paste” wording to the team roster guest-player import action; the import parser still accepts clipboard text regardless of its source.
- Manual roster-import dialog now owns and disposes its `TextEditingController` after the dialog closes; the existing clipboard-first behavior and parsing rules are unchanged.
- Stadium fullscreen image-gallery page counter now offsets itself by the device's bottom system inset plus its existing visual spacing, avoiding the home/gesture indicator area.- Live matchup closure now verifies the parent screen is still mounted after the confirmation dialog returns before starting the async close operation.

## Support-ticket sheet token alignment — 2026-11-01

- Replaced the support-ticket creation sheet's hard-coded 24px viewport clearance with the canonical `VSPSpacing.xxl` token (24px), preserving the existing keyboard/safe-area sizing behavior while removing an orphan spacing literal.
- Commit: `8418f678ac268e5e33687a7048ef4b99b70eaf9a`.
- Source-only. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run. This does not close the support sheet's compact-device/keyboard runtime verification gate.


## Profile governorate update recovery — 2026-11-01

- The profile location picker now catches failed governorate updates and shows localized retry guidance instead of allowing an uncaught async error to escape the tap handler.
- The sheet closes and the in-memory stadium filter updates only after the profile update succeeds and both relevant contexts remain mounted. Technical exceptions are not exposed in user-facing copy.
- Source-only. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: b9823301be19a9cfc89dc4a50b22bb94df4166b5.


## Create-team flow dismissal guard — 2026-11-01

- The profile screen now disables barrier-tap and swipe dismissal for the create-team bottom sheet. This prevents accidental route dismissal while asynchronous logo upload/team creation is running and avoids leaving the user uncertain about whether the operation completed.
- Explicit Cancel and close controls inside the sheet remain available; the sheet already disables those controls while submission is active.
- Source-only. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: b3891f2cbfe29b131c97ab168022c822d6bc8663.


## Support-ticket escalation account-scope guard — 2026-11-01

- The WhatsApp escalation flow now captures the initiating account/session generation and revalidates it after loading support settings and after the optional escalation-tracking write. If the user switches accounts or the ticket screen is disposed during either await, the stale flow stops before opening WhatsApp for the previous account's ticket.
- No ticket permissions, support destination, escalation metadata contract, or backend behavior was changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 00375153271e9805b37d2b5caec30c95ac029d2e.


## Support-ticket account-scope and signed-out state follow-up — 2026-11-01

- WhatsApp escalation failure feedback is now suppressed if the initiating account/session changed while the asynchronous escalation flow was running, preventing a stale request from surfacing an unrelated error in the newly active account.
- The support-ticket detail screen now presents an explicit localized sign-in-required state when no authenticated user is active, rather than falling through to the generic “ticket unavailable” state.
- No ticket access policy, escalation destination, or backend behavior was changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: `4ab9ec22a2bdd86483d6f1dbd247bcfb431cfa2c`, `e39906e3140c7d3663adcd10abd6d98a2e295cfc`.


## Support-ticket creation modal dismissal guard — 2026-11-01

- The new-support-ticket sheet can no longer be dismissed by tapping outside or dragging while its asynchronous create request is in progress. An explicit Cancel action is available before submission and is disabled during submission; this avoids accidental dismissal and uncertainty about whether a ticket was created.
- Ticket fields, category mapping, priority mapping, and the create-ticket backend call are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `76765152aa85c8fed8a882798ce26f2d3cd6e4c5`.


## Support-ticket signed-out action visibility — 2026-11-01

- The floating “open ticket” action is now hidden when there is no authenticated user. Previously the screen showed a sign-in-required empty state but still exposed an action that launched the ticket-creation flow, creating a misleading and potentially failing path.
- Authenticated-user behavior is unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `6f045e18696fb71c1b685a05bd2bbc671ee6e439`.


## Team member governorate alias normalization — 2026-11-01

- Adding an existing VSP player to a team now compares governorates using the shared EgyptGovernorates canonical resolver before falling back to normalized text. Equivalent Arabic/English and supported Google Maps aliases (for example, Aswan / أسوان) no longer trigger a false “different governorate” block.
- The same-governorate eligibility rule remains unchanged; this only normalizes equivalent stored names. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `70bcb668aa853b1290aa458fbd5666ff90679774`.


## Support empty-state signed-out action consistency — 2026-11-01

- Completed the signed-out support-ticket correction: the empty state previously still displayed an “Open Ticket” action and copy telling the user to open a ticket, even though the floating action was hidden and the flow required authentication.
- Signed-out users now receive explicit bilingual sign-in guidance and no create-ticket button. Authenticated users retain the existing empty-state action. No authentication, ticket, or backend rules changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `c84d1893ec5672f9613ead796e209c4bc008aff2`.


## Support ticket list title bounds — 2026-11-01

- Support-ticket subjects in the ticket list are now limited to two lines with ellipsis. Long user-entered Arabic/English subjects can no longer expand a row without bound or crowd its status/navigation affordance on narrow screens.
- Ticket subject data is preserved and the full title remains available in the ticket detail screen. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `dbcb227f63213dbb42a57cc4f1d12575462168dc`.


## Add-player lookup stale-response protection — 2026-11-01

- The add-player phone lookup now captures the initiating account and normalized phone number. A late success is discarded if the user changes the phone field or switches accounts before the lookup returns, preventing an outdated player from appearing as the current search result.
- Lookup errors are also shown only when they still belong to the active phone/account request; stale failures no longer display misleading errors over a newer search or account. Governorate eligibility and the repository lookup contract are unchanged.
- Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: `0dcc02a29b8e0b1439a8072561bfab31dfcd1dda`, `1d128f5017efcade0d7e3a4dbd651201dbc9ea42`.


## Support-ticket WhatsApp escalation duplicate-action guard — 2026-11-01

- Added an in-flight state to the support-ticket WhatsApp escalation action. Repeated taps are blocked while settings are fetched, escalation metadata is updated, and the WhatsApp handoff is attempted; the app bar shows progress and disables the action during that interval.
- The in-flight state is reset when the authenticated account changes, and the request's existing account-generation guard prevents an old request from updating the new account's screen.
- No support policy, ticket ownership rule, database behavior, or WhatsApp destination was changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `3af127d34764783d3fedb4b9b0474f18df61e098`.


## Support-ticket creation account-scope guard — 2026-11-01

- The create-ticket sheet captures the account that opened it and verifies that the same account is still active immediately before submitting. If the account changed while the sheet was open, submission is blocked with clear Arabic/English guidance.
- After the create request returns, the ticket detail route is opened only if the initiating account is still active. Failure feedback is likewise suppressed when it belongs to an account that is no longer active.
- No ticket permissions, ownership policy, categories, priority rules, or backend behavior were changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: `1326be01e5c53fde8fffcbe32cd72a59583221ad`, `55681d98ba7692eec25cb5308de65d090184c6ff`.

- Follow-up hardening: the sheet now checks its own mounted state before showing account-change feedback, and verifies the parent screen is still mounted before reading its auth provider. Commit: `270334818da6203dadb452a48d0190e97334e133`.


## Match-details owner-report resilience — 2026-11-01

- The booking-linked owner-report dialog now uses scrollable AlertDialog content so the reason/details fields and actions remain reachable on compact or keyboard-constrained screens.
- Owner-report submission now catches repository exceptions, logs the technical error, and presents localized retry guidance instead of allowing an unhandled async failure. A submission guard prevents duplicate report requests while the request is in flight.
- Report target, booking linkage, repository contract, and moderation policy are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `35a2742a61a08f3420d8c560e57fd48787d5fde6`.


## Match-report dialog compact-viewport correction — 2026-11-01

- The match-report reason selector dialog now uses scrollable AlertDialog content so its explanatory text, reason selector, and actions remain accessible on compact screens and when the keyboard/insets reduce available height.
- Report submission behavior and moderation rules are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `8fa0d4e595881a198e2294f9f87f5f2363b9b893`.


## Owner financial ledger CSV export integrity — 2026-11-01

- CSV cells are now escaped according to CSV quoting rules (embedded double quotes are doubled), preventing transaction text containing quotes or delimiters from corrupting exported rows.
- Export failures now log the technical exception and stack trace while retaining concise localized user-facing recovery copy.
- Financial values, transaction selection, payout behavior, and ledger data are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `51599f0858f9cc25ccbcb176e2e92b2da06996bb`.


## Championship checkout roster bilingual labels — 2026-11-01

- Corrected the team-member list heading and required-captain subtitle, which were previously Arabic-only even when the app locale was English. Both now follow the active locale.
- Selection rules and captain-required behavior are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: `9d009469cd21290b3b649a9b7c0eeebb230a1832`, `eaf66799f4de56fc1d53d0a5177d16e1b0eeaf2b`.


## Championship checkout roster fallback localization and lifecycle guard — 2026-11-01

- Fallback roster labels now follow Arabic/English locale instead of always showing Arabic “Player” labels in English UI.
- Added a mounted-state guard immediately after the asynchronous roster lookup and before fallback-list mutation or context access, preventing the disposed checkout screen from continuing its post-request work.
- Captain selection and roster eligibility are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `d4daffc1c40aa6dfd139f8d466eaa2e4941aec92`.


## Championship checkout fee-card localization and accessibility — 2026-11-01

- Localized the fee-card heading, tournament entry-fee label, total-due label, and currency suffix for English and Arabic; the platform-fee label was already bilingual.
- Increased the fee-explanation info affordance to a 48dp IconButton with a localized tooltip, and made its bottom sheet scrollable within safe areas on compact screens.
- Displayed fee amounts and the existing fee explanation remain unchanged; no fee calculation, pricing, or payment behavior changed. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: `4306975177eebb97646641350304a58eb94708b6`.


## Booking calendar compact-viewport and keyboard-inset correction — 2026-11-01

- The booking date-picker dialog now caps its height to the available viewport after system insets and keyboard obstruction, and its content scrolls vertically when the calendar plus actions cannot fit. This prevents the fixed-height month grid and action row from being pushed outside short screens or keyboard-constrained layouts.
- Date eligibility, month navigation range, selected-date behavior, and booking callback are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: c31868dab68e683c1a668b81ad687a9ae76e3fb6.


## Payment verification modal short-screen accessibility — 2026-11-01

- The non-dismissible payment-verification modal now constrains its content to the available viewport after keyboard/system insets and permits vertical scrolling. The delayed-wait actions and progress content remain reachable on short displays instead of being clipped outside the visible dialog area.
- Payment verification timing, payment state, support destination, and navigation callbacks are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 60a768e2112a76d49c9512b7f5f587a49efa089d.


## Tournament location confirmation and squad-builder modal resilience — 2026-11-01

- The cross-governorate tournament confirmation now uses a scrollable AlertDialog so long Arabic/English commitment copy and its actions remain reachable on compact displays.
- The incomplete-squad bridge sheet now caps its height to the available viewport after keyboard/system insets and scrolls its content. The post-create team lookup no longer force-unwraps the authenticated user; if the session is absent, it exits safely instead of throwing.
- Tournament eligibility, minimum roster size, team creation, and registration rules are unchanged. Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: b3af961ef27795dd22f0d87460d47d9406fbac96, ab06266497b4f527f512fd4a43cd8db5c7de03ce.


## Stadium gallery action touch-target correction — 2026-11-01

- The stadium image carousel's share and favorite circular actions now have a 48dp hit area instead of 40dp, meeting the shared minimum touch-target requirement while retaining their existing icons, placement, and behavior.
- Source-only; no analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 886f6c22f72dc2e607f5d9566e00870bce420cc3.


## Tournament modal viewport fixes (2026-11-01)
- Tournament score editor, auto-schedule sheet, and manual team registration sheet now cap their height using the viewport after keyboard and safe-area insets.
- Existing score, scheduling, and team-registration behavior is unchanged. No tests, CI, analyzer, migrations, or APK build were run.
- Commits: adcd0e3de3ea1639ed1395eb19c8c3053a5e8812; 569e28aa289ec0bfaad773e2cf049d7e2f251107; 1a7f0a2917ee14f277aae1a88595f1c45e01f8a6.


## Additional modal viewport and dialog resilience — 2026-11-01
- Keyboard- and safe-area-aware height caps were added to tournament score entry, tournament auto-scheduling, and manual tournament team registration sheets. Their existing scrollable content remains intact.
- Four tournament dashboard confirmation dialogs, the home governorate confirmation dialog, and the stadium-wizard discard confirmation dialog now use scrollable AlertDialogs for compact screens and large text.
- No booking, tournament, payment, pricing, or registration business rules were changed. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: adcd0e3de3ea1639ed1395eb19c8c3053a5e8812; 569e28aa289ec0bfaad773e2cf049d7e2f251107; 1a7f0a2917ee14f277aae1a88595f1c45e01f8a6; b225122d05c9e471ace9fa39b77bb1d4d88e287c; 61f0bbeb1eea82c2618cd062b59a3ac448665fe4; 434ad88c021c32c0d2c893e24a0f2cb1a1590410.


## Location and quick-booking receipt reliability — 2026-11-01
- Manual governorate selection now awaits the profile save before applying the stadium filter and closing the picker. A failed save keeps the picker open and shows a localized retry message; it no longer applies a location filter while persistence may still be pending or fail.
- The governorate picker is capped to 85% of the safe viewport so its list remains usable on compact screens.
- The owner quick-booking receipt sheet is now height-constrained and scrollable, preserving both WhatsApp-send and close actions on compact screens or with larger text.
- No pricing, payment, booking, or eligibility rules changed. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commits: fc6c243d9102fc6e4a2cf0dc4d64b62a77fba405; 22df76dd446cc9dc8ef3a628ec26bdab416ec5d8; 1f9cfc975fe4ff5a4832562bbc45e0b0ef90bbcd; 9b3eb1caee26c0e768125e7bd591424fae37fd4e.


## Stadium filter viewport correction — 2026-11-01
- Corrected the stadium filter bottom sheet's available-height calculation to subtract the top system inset and the larger of the keyboard or bottom safe-area inset. The fixed action row is therefore included within the actual usable viewport rather than sizing the sheet against keyboard height alone.
- Existing category content remains independently scrollable and reset/apply actions remain fixed within the sheet.
- No filter semantics, booking rules, pricing, or backend behavior changed. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 0b0d9adaec15b9071132058b28b59142f4d889b5.


## Collective invitation title overflow guard — 2026-11-01
- The private collective booking invitation sheet title is now limited to two lines with ellipsis. This prevents long localized text or larger text scaling from pushing the close control out of the header row.
- No booking eligibility, participant, payment, or invitation behavior changed. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 1f9b198cf5e6050f7f28f55076f10082d812b755.


## Tournament round schedule reset recovery — 2026-11-01
- The round-schedule reset confirmation now catches repository exceptions and shows localized recovery feedback if the reset request throws. A disposed screen is checked before presenting feedback.
- The reset operation, target round, and scheduling rules are unchanged. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 924bf9537315f5f7d4934d0d55c44f27f39b49fa.

## Earlier modal viewport fixes recorded — 2026-11-01
- Added the previously omitted progress entries for the collective-match invitation sheet and booking-type modal keyboard/safe-area height constraints.
- Commits: 08a3bf1e6313830a749f20075df77890beefec9f; 6fb489053843cb4c09ebcd0fee55e87182931f55.


## Tournament automatic scheduling failure recovery — 2026-11-01
- The automatic round-scheduling action now catches repository exceptions and presents localized retry guidance instead of allowing an unhandled asynchronous failure. It checks that the parent screen remains mounted before showing feedback.
- Scheduling inputs, match ordering, date/time selection, and repository behavior are unchanged. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 59a162650d674ac9e78755e8727fbe09ea158da5.


## Tournament live-draw dialog lifecycle guard — 2026-11-01
- The live bracket reveal animation now checks that its dialog context remains mounted after each asynchronous delay and before its final state update. If the dialog is dismissed during the reveal, the animation exits without calling setState on a disposed dialog.
- Draw generation, randomized pairing, reveal timing, and tournament confirmation behavior are unchanged. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 34adeaebb02a6f38fd4f9a6590ead19e4c6de7ed.


## Tournament prize handover dialog resilience — 2026-11-01
- The prize handover dialog now uses a scrollable AlertDialog and constrains its bilingual title to two lines with ellipsis, preventing long localized text from overflowing the title row on compact screens or larger text settings.
- The success path now verifies both the dialog route context and parent screen context are mounted before popping the dialog and presenting success feedback.
- Prize amount selection, ledger recording call, notes, and delivery business rules are unchanged. No analyzer, CI, automated tests, runtime checks, migrations, or APK build were run.
- Commit: 6774cad4b1289fda7a396720c930002fc6087cd3.


## Stadium location picker GPS lifecycle guard — 2026-11-01
- Added a mounted-context check immediately after the asynchronous current-position lookup and before updating selected coordinates or moving the map controller. If the sheet has been dismissed while GPS is resolving, the callback now exits safely; the existing `finally` block remains responsible for resetting the loading state whenever the sheet is still mounted.
- Location permission behavior, GPS accuracy, timeout, and location-selection rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: de75f2e01b1feefa2902c25e77790042d44c22de.


## Team league dispute resolution lifecycle guard — 2026-11-01
- Added a `mounted` check after awaiting the dispute-confirmation dialog and before changing the sheet's loading state or starting the resolution callback. This prevents `setState` or continued work on a league sheet that was dismissed while its confirmation dialog was open.
- Dispute confirmation wording, resolution choices, and league result behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: 76b6c864cbf4c13bc2120d58e154b88343a411ec.


## Cash booking empty-result recovery — 2026-11-01
- Fixed the cash booking sheet's null-result branch: if `createBooking` returns `null` while the sheet is still mounted, the action now always clears its navigating/loading state and displays the existing localized failure message. Previously this recovery only ran when `BookingProvider.errorMessage` was non-null, which could leave the cash option permanently disabled with no feedback if the provider returned null without setting an error string.
- Booking creation, eligibility, payment values, and server-side rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: 3b7f99ba5b0c0bf3ec0fa7ca23ff08a888f90bf7.


## Booking calendar selected-date label overflow — 2026-11-01
- Fixed `lib/features/player/widgets/booking/booking_calendar_modal.dart`: the selected-date banner placed a full localized weekday/date string directly in a `Row`, with no width constraint. Long Arabic/English dates could overflow narrow dialog widths. The label now uses the remaining row width, wraps to at most two lines, and ellipsizes excess text while remaining centered.
- Date selection, allowed date range, and booking behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: cba47f826f08ee318704ec1933e38ace45fa326a.


## Booking cancellation feedback route guard — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart`: cancellation dismisses its dialog before awaiting the provider. If the owning screen was also removed during that request, the completion path previously attempted to show a SnackBar through a `ScaffoldMessenger` captured from a disposed route. It now checks the owning screen's `context.mounted` immediately after the await and exits before using the messenger when that route no longer exists.
- The cancellation request itself and refund calculation/policy are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: 702f076e22f78e82ea250a21ace57c0aec4d53de.


## Team creation success feedback after sheet dismissal — 2026-11-01
- Fixed `lib/features/player/widgets/create_team_sheet.dart`: the success path popped the creation sheet and then looked up both `ScaffoldMessenger` and `Theme` using the sheet's route context. That context may already be deactivated after the pop. The messenger and text style are now captured while the context is mounted, before dismissing the sheet; the success SnackBar is then shown through the captured messenger.
- Team creation data and repository behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: fccfaa0909a02b77b9008b3aea1d99066e71b97a.


## Owner account deletion dialog narrow-screen actions — 2026-11-01
- Fixed `lib/features/owner/widgets/account/owner_delete_account_card.dart`: the confirmation dialog always placed Cancel and Delete in one horizontal `Row` with equal-width buttons. On narrow devices, Arabic labels and the loading state could become cramped or overflow. Actions now stack vertically below 360 logical pixels and remain side-by-side on wider dialogs.
- Password reauthentication, deletion flow, and account rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: 5d8e1d554aa8557e138c727dd9574d4694c6144d.


## Owner payout dialog narrow-screen actions — 2026-11-01
- Fixed `lib/features/owner/widgets/ledger/owner_payout_dialog.dart`: the payout amount/destination dialog always forced Cancel and Confirm Request into a horizontal equal-width row. On narrow devices and in Arabic, the long confirmation label could be compressed. Actions now stack vertically below 360 logical pixels and remain horizontal on wider dialogs.
- Payout amount validation, destination selection, and settlement submission behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.
- Commit: 33b5a5bcf0deeff80477a96819a26daefef5ca15.


## Support ticket creation parent-context lifecycle guard — 2026-11-01
- Fixed `lib/features/player/screens/support_tickets_screen.dart`: after the asynchronous support-ticket creation request, the sheet context was checked but the owning screen context was not checked before reading `AuthProvider` from that parent context. If the screen was disposed while the sheet remained mounted, the success or error path could access a deactivated parent context.
- Both post-request success and error paths now require the parent screen to remain mounted before reading its provider. Ticket creation behavior and account-identity checks are unchanged.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: d1253058ff48d02bcf208ff2fc8f19a5d7da7e1c.


## Open-join booking chat recovery and account-scope guard — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/open_join_booking_card.dart`: opening the booking chat previously failed silently when no other participant existed, chat creation threw, or the repository returned no chat ID. The action now gives localized feedback for unavailable prerequisites and recoverable failures.
- After the asynchronous chat lookup, navigation now also verifies that the same authenticated user is still active. This prevents a late result started under one account from opening that booking chat after an account switch.
- Chat eligibility and repository behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: 24cf0feacc8b7124323534ffa9b85722094aa718; 3abe25c7059ee7272e178dfb78c25b4657e32baf.


## Owner quick phone booking failure feedback — 2026-11-01
- Fixed `lib/features/owner/widgets/bookings/owner_time_slot_row.dart`: long-press quick phone booking previously showed success only when creation returned a booking, but gave no feedback when the provider returned `null`. The owner could tap a free slot and receive no indication whether the booking was created.
- The completion path now exits if the screen was disposed, then shows localized success or explicit failure copy stating that no booking was created and inviting a retry. Booking payload, cash designation, price, and creation rules are unchanged.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: a8006abf69a88ecef6a78c87965b53a7f1e822b9.


## Booking confirmation guard deduplication — 2026-11-01
- Cleaned `lib/features/player/widgets/booking/booking_confirmation_handler.dart`: the pre-confirmation availability check repeated the exact same authenticated-user identity guard twice consecutively. Removed the redundant second check; the first guard and all subsequent identity/lifecycle checks remain intact.
- This is a behavior-preserving cleanup only. No booking eligibility, availability, payment, or database rules changed. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: f534acd2d509d1f670ebe379714580897a2d8175.


## Pending booking account-scope protection — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/pending_booking_card.dart`: the cancel and payment-status actions could finish after an account switch and then display results or refresh the booking list using the newly active account. The status check now captures the initiating user and discards stale results; cancellation likewise verifies the initiating account before presenting its outcome and refreshes only that captured user's list.
- Booking cancellation, payment-status interpretation, and checkout behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 96b87dc777257810fba418444654026f0ad7963b.


## Quick phone booking post-dismiss context safety — 2026-11-01
- Fixed `lib/features/owner/widgets/quick_phone_booking_modal.dart`: after saving a manual booking, the modal was popped and then its own `context` was reused to open the receipt sheet or show the success feedback. That context belongs to the dismissed route and can be deactivated during the transition.
- The flow now captures the host navigator context before dismissal, closes the modal, verifies the host context is still mounted, and presents the receipt/success feedback from the host route. Booking creation and receipt contents are unchanged.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 6bbed9316107eba4dc07cb92c20cb1ada13bab23.


## Collective invite account-scoped async actions — 2026-11-01
- Fixed `lib/features/player/widgets/collective_match_invite_sheet.dart`: join, leave, manual-player-count update, participant removal, invitation credential lookup/share, and collective cancellation now verify the initiating authenticated account after asynchronous work before refreshing state, navigating, or presenting feedback. Error feedback for join/leave/count/removal is also suppressed if the active account changed while the request was pending.
- The repository operations and product eligibility rules are unchanged; this only prevents stale async results from crossing account sessions. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: eb36c3c26203a5cd5147c281cb6701fb9da8802b; 84c2a6264c0948adab02faf4fe6d5f1f2f202a48.


## Public match action account-scope protection — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/open_join_booking_card.dart`: leaving a public match and cancelling a join request previously accepted the initiating user ID but only checked whether the widget remained mounted after the asynchronous repository call. They now verify that the same user is still authenticated before displaying either success/failure feedback; exception feedback is also suppressed after an account switch.
- Match repository calls and join/leave eligibility are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: ef65a835778dda957a28ec5db18fad25d6db6e57.


## Owner quick phone booking session guard — 2026-11-01
- Fixed `lib/features/owner/widgets/quick_phone_booking_modal.dart`: manual booking creation now captures the initiating owner identity before the request and verifies it after the request before refreshing owner bookings, dismissing the sheet, or showing the receipt/success UI. Error feedback and loading-state recovery are also scoped to that same account. The captured identity is kept in scope for both success and exception paths.
- Owner selection fallback and booking payload are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: 1996a32a64bf4581422bdb97c1feda03a8ea7f02; 62139a2aac1b139d10d97ead4297662915c258a8.


## Owner quick-slot booking session feedback guard — 2026-11-01
- Fixed `lib/features/owner/widgets/bookings/owner_time_slot_row.dart`: after the quick phone-booking `createBooking` request returned, the row previously checked only whether its context remained mounted. It now also verifies the initiating owner account is still active before displaying success/failure feedback or invoking the completion callback.
- Booking creation request and data are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 2d48214f079c063de3e686d7e11de611f52c7e3e.


## Collective invite share/cancel exception scoping — 2026-11-01
- Extended `lib/features/player/widgets/collective_match_invite_sheet.dart` account-scope protection to the invitation-sharing and collective-cancellation exception paths. The initiating user ID is now captured outside each `try` block so both success and error handling can reliably verify the same session; errors from an old session are not surfaced to a newly signed-in account.
- No invitation eligibility, cancellation policy, or repository behavior changed. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: c1ceb9fd16d7ee9bb7e1849f3cf07e47fc8b3230.


## Participant removal refresh serialization — 2026-11-01
- Fixed `lib/shared/widgets/match_card/manage_participants_modal.dart`: after removing a participant, the modal previously started `_fetchUsers()` without awaiting it. The `finally` block therefore released `_isProcessing` before the refreshed participant list completed, allowing another participant action while the previous refresh was still in flight.
- The refresh is now awaited, keeping the existing action lock active until the updated participant list finishes loading. Repository operation and participant eligibility are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 085104f0b6be71d9a9f6e3c1dcd53bcecd29fbfd.


## Team leave callback lifecycle guard — 2026-11-01
- Fixed `lib/features/player/widgets/my_team/team_dialogs.dart`: the leave-team async action invoked its parent `onSavingFinished` callback unconditionally from `finally`, even if the owning team screen had been disposed while the repository request was pending. The callback now runs only while the parent context remains mounted, preventing a disposed parent from receiving a late state update.
- Team membership operation and captaincy-transfer behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 40b3d91d4851354303a428c86b739e0fe6ec4c65.


## Team deletion false-result feedback — 2026-11-01
- Fixed `lib/features/player/widgets/my_team/team_dialogs.dart`: `TeamRepository.deleteTeam` could return `false` without throwing, but the dialog handled only the `true` result and silently left the user without an outcome. Added localized failure feedback for the false result; exception formatting remains unchanged.
- Team deletion authorization and repository behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: a6d21d6d4547e4b1e28b1fa125d9ce7a64c9921b.


## Public-match participant action false-result handling — 2026-11-01
- Fixed `lib/shared/widgets/match_card/manage_participants_modal.dart`: the repository methods `acceptJoinRequest`, `rejectJoinRequest`, and `removeParticipantFromPublicMatch` return `bool`, but the modal ignored `false`. A failed accept/reject could therefore still trigger a player notification, and a failed removal could silently refresh without telling the owner.
- The modal now treats each `false` result as a failed action and follows its existing localized error path. Acceptance/rejection notifications and participant refresh run only after a successful repository result. Repository/RPC behavior is unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: d1499daab90240eaac58a9aee5ec14c4a352e85e.


## Match result false-return feedback — 2026-11-01
- Fixed `lib/features/player/widgets/match_result_modal.dart`: when the result-submission callback returned `false` (without throwing), the modal only reset its loading state and gave no indication why submission had not completed. It now displays localized failure feedback and leaves the modal open for correction/retry.
- Result calculation, callback, and submission rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 90ff537342410603803c4f6602f22b57f292c3a3.


## Championship squad-to-team creation session guard — 2026-11-01
- Fixed `lib/features/player/widgets/championship_details/championship_squad_builder_sheet.dart`: after opening the create-team sheet, the bridge previously read whichever account was currently active and could fetch that account's team and route it into championship checkout if the user switched accounts during creation. It now captures the initiating user before dismissing the bridge and verifies that same user after team creation and again after fetching the team.
- Team creation and championship checkout rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 3cf50323faf160b56d2f891dff9d7024faafb5d0.


## Reschedule phone-launch feedback and dismissal guard — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart`: after sending a reschedule proposal, the optional `tel:` launch was previously fire-and-forget. A device with no handler or a failed launch could silently do nothing or surface an unhandled asynchronous error, and an exception could prevent the booking sheet from closing. The launch is now awaited, a localized error is shown when it returns false or throws, and the sheet is dismissed only while its context remains mounted.
- Reschedule proposal behavior is unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: f1fd913284eb53db998e8ae04694b2a5ae435573.


## Quick-booking payment chip touch targets — 2026-11-01
- Fixed `lib/features/owner/widgets/quick_booking/quick_booking_payment_section.dart`: quick amount chips were implemented as bare `GestureDetector`s with only about 25–30 px vertical content height, below the 48×48 dp mobile accessibility/touch-target baseline. Replaced them with Material `InkWell` controls and minimum 48×48 dp constraints while preserving selection callbacks and styling.
- Amount options and payment calculations are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: c6b7dd0203d891fd7caf656fcbf602f85fa4f3a8.


## Cash-booking WhatsApp launch feedback — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/booking_sheet_action_panels.dart`: the cash-booking “Confirm via WhatsApp” action launched `wa.me` without awaiting the result or handling `false`/exceptions, so a failed handoff was silent. It now awaits external-app launch and shows localized failure feedback when WhatsApp cannot be opened. The no-phone support fallback remains unchanged.
- No booking or payment state changes. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 967a4a7399b5618027001d29a52f3da507272086.


## WhatsApp support launch feedback across booking panels — 2026-11-01
- Updated `lib/features/owner/widgets/booking_sheet/booking_sheet_whatsapp_utils.dart` and its booking-panel call sites: the no-show/support WhatsApp helper previously swallowed launch failures after logging, leaving users with no visible outcome. It now accepts an optional mounted `BuildContext` and displays localized feedback when the external launch returns false or throws. All booking-panel support actions now pass their context.
- Existing support message content and destination are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: 5d56e6e4bc49d1a167e2828190ca24f153332560; 0f043a75bed420612ad140701e8cad5407db97e3.


## Owner booking sheet session-bound actions — 2026-11-01
- Fixed `lib/features/owner/widgets/owner_booking_sheet.dart` in two related areas. Manual booking create/edit now captures the initiating owner and checks that identity after the write and booking-list refresh before showing completion or continuing UI work; stale-session errors are not shown to a different signed-in user. No-show reporting now captures the owner before the confirmation dialog (rather than reading whichever account is active after the write), verifies the same account before/after the repository action and refresh, and scopes error feedback accordingly. Maintenance slot locking now also verifies the initiating owner after the lock and refresh requests before navigation or feedback.
- Booking, no-show, and maintenance repository calls and business rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: 3c92823fe69af2258850c4848551c28241d477cb; de71f3ba85e17ebfdf4c8f203926b7aea46de417.


## Ongoing match extension session guard — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart`: extending an ongoing match previously refreshed whichever owner account was active after the RPC and could show success to a newly signed-in account. The coordinator now captures the initiating owner before the request, verifies the same session before refreshing and again before success/navigation, refreshes only that owner's bookings, and suppresses stale-session error feedback. Loading state is released if the widget remains mounted but the account changes.
- Extension RPC and +30-minute rule are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: b12f094b405cf848ddcb293c7871c5ad4d9095ac.


## Owner cash-confirmation session guard — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart`: cash confirmation previously looked up the active owner again after the atomic confirmation RPC and could refresh a different account's booking list or show stale success after an account switch. It now captures the initiating owner, uses that captured ID for the refresh, and verifies the same session before success/navigation and before showing errors. Loading state is reset when the sheet remains mounted but the account changes.
- Cash confirmation RPC, amount calculation, and notification behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 190f74b9db262ee6967de8c87af921acb7789dd8.


## Booking cancellation loading callback lifecycle guard — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart`: both manual-deposit and standard cancellation flows invoked the parent `setDeleting(false)` callback unconditionally in `finally`. If the booking sheet had been disposed while cancellation was pending, this could call `setState` on a disposed owner sheet. Both finalizers now invoke the callback only while the sheet context remains mounted.
- Cancellation decisions, refund/penalty options, and repository calls are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 7b7e3421ac547745ad202aac97ffbb7a626f0353.


## Owner and collective booking cancellation session guards — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart`: both manual-deposit and standard cancellation previously read the active owner only after confirmation, so switching accounts while the confirmation dialog was open could submit the cancellation under a different session. Both paths now capture the owner before the dialog, verify the same owner before submitting, after the repository/provider action, and after the booking-list refresh; stale-session feedback/navigation is suppressed. The loading callback is no longer set before checking the parent context.
- Fixed `lib/features/player/widgets/collective_match_invite_sheet.dart`: leave and cancel confirmation dialogs previously allowed the user to switch accounts before confirming, with leave submitting the old user ID and cancel capturing the new account only after confirmation. Both now retain the initiating user ID and abort if the session changes before the operation starts.
- Cancellation, refund, leave, and booking rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: 6b262b88e0c937f3ab6537ac06c4f4f67866d338; fa13721e34b6ca82749263e8e4f0dd4a77c45e6b; f4f72857e7a89fa2f049b46e9a14a9c21d61e69c.


## Pending-booking payment status session feedback guard — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/pending_booking_card.dart`: the Check Status action already captured the initiating player before the asynchronous booking lookup, but its exception path could still display a failure snackbar after that player had signed out and another account had become active. It now suppresses stale-session errors and verifies the same account again after refreshing the player's booking list.
- Payment-state interpretation and checkout actions are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: c38e6c1220706f6fd9b834f6331f257576106229.


## Pending booking cancellation confirmation session guard — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/pending_booking_card.dart`: the pending-booking cancellation action previously captured the current player only after the confirmation dialog. Switching accounts while the dialog was open could therefore submit the cancellation using the newly active account. The initiating player is now captured before the dialog and verified immediately after confirmation and again after the cancellation request.
- Cancellation behavior and booking rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 591b6a115864639f63a2e427f27e021e8e256c66.


## Owner booking sheet parent-context lifecycle guards — 2026-11-01
- Fixed `lib/features/owner/widgets/owner_booking_sheet.dart`: manual booking create/edit, no-show reporting, and maintenance-slot locking now verify both the sheet and its parent route contexts are still mounted before reading providers or starting work. This prevents actions from starting with a disposed parent context if the underlying owner screen was removed while the sheet remained visible.
- Booking, no-show, and maintenance business rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 16d6aa07ff00c1f30db9049ebf480abe5f8bf2d4.


## Public match participant modal server refresh — 2026-11-01
- Fixed `lib/shared/widgets/match_card/manage_participants_modal.dart`: after accepting/rejecting a join request or removing a participant, the modal re-fetched profile rows using the original immutable `widget.booking.joinedUserIds` and `pendingUserIds`. That meant the UI could continue showing the old participant/request lists even after the repository action succeeded. The modal now maintains current ID lists, refreshes the booking from `BookingProvider.getBookingById`, and then fetches profiles against the refreshed lists. A local list update is retained as a fallback if the booking refresh is unavailable; a refresh lookup failure no longer falsely reports that the already-completed participant action failed.
- Acceptance/rejection/removal RPCs and notification behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commits: 2a0dc91686b87e61c33f582db4e7ec9af3836c40; 61ee1029ea83cf5cb3c0aef049ccc22d5f7123fc; c4c43b8fe46334ffbe71d558cac5063f5f0d85b9.

- Follow-up source correction: aligned the refresh-fallback log call with the actual `VSPLogger.e(message, error, stackTrace)` signature (`VSPLogger.w` accepts only a message). Commit: 22bd7e569b33520998660300e805bd775f98d8bb.

- Additional participant-modal edge cases fixed: the refresh helper now exits before reading providers if the sheet was disposed, and the zero-participant branch clears both displayed lists instead of leaving removed players visible. Commit: fbb513044d77499729868ef44c3cf53a4183ec84.


## Player booking cancellation dialog account-session guard — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart`: the dialog previously dismissed itself and awaited `BookingProvider.cancelBooking`, then showed success/failure feedback based only on whether the parent screen remained mounted. If the user account changed while the cancellation was in flight, the old booking result could be surfaced in the new account's session. The dialog now captures the initiating player when opened, verifies that account before starting cancellation, and suppresses stale-session feedback after the request completes.
- Cancellation and refund calculation behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: d86aaf636e2cd1042ca9622e09213ff9fb087ee8.


## Open-join chat stale-session error guard — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/open_join_booking_card.dart`: `_openChat` already verified the initiating player before navigation, but its exception handler only checked whether the card remained mounted. A chat lookup failure after an account switch could therefore display an error in the new account's session. The catch path now also verifies the initiating player ID before showing feedback.
- Chat creation/navigation behavior is unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 3feeec54cdd116bb62f44965b610d69bb506bc87.


## Booking confirmation location-check session boundary — 2026-11-01
- Fixed `lib/features/player/widgets/booking/booking_confirmation_handler.dart`: if location verification threw after the player had changed accounts, the handler marked the booking as online-preferred but still proceeded to query stadium availability before checking the active account. It now checks that the screen is mounted and the initiating player is still signed in immediately after the location-check/fallback stage, before starting the availability lookup.
- Location fallback policy, booking eligibility, and payment routing are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: d4a454d47be990b4102f796f89580733670e0e36.


## Collective booking post-action refresh failure handling — 2026-11-01
- Fixed `lib/features/player/widgets/collective_match_invite_sheet.dart`: join, leave, manual-player-count update, and participant removal all perform their server mutation before `_reload()`. Previously, if the follow-up booking/profile refresh threw, the enclosing action catch could show a false message that the mutation itself failed, even though the server had already accepted it. `_reload()` now handles/logs refresh errors independently, preserving the successful mutation outcome and avoiding misleading failure feedback.
- Collective booking permissions, mutation calls, and booking rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 4c5d8f3564621d9c01e39bfd6bdb0bf68563ad08.


## Emergency stadium closure owner-session guard — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart`: emergency closure previously opened its confirmation dialog and submitted the 24-hour closure request using the booking's owner ID without verifying that the currently signed-in account was still that owner. The action now requires the initiating account to match the booking owner, rechecks after confirmation, and only displays the result in that same session.
- The emergency closure request, duration, and administrative review/refund routing are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 9b7249647c13ac782975a841f47a4214af00e5be.


## Quick phone booking receipt payment wording — 2026-11-01
- Fixed `lib/features/owner/widgets/quick_booking/quick_booking_receipt_sheet.dart`: the quick-phone-booking flow collects the amount received directly from the stadium owner, but the receipt formatter's `isCashConfirmed` flag was never passed. When the full booking total had been collected, the receipt could therefore label it as paid online. The receipt now marks cash as confirmed only when the positive total has been collected in full; partial collection remains correctly represented as a deposit with the balance due on arrival.
- No payment amounts, booking writes, or collection rules changed. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 71415521482a5ed30ee1b8c9312f7d2d749ce4c4.


## Collective invite details resilient loading — 2026-11-01
- Fixed `lib/features/player/widgets/collective_match_invite_sheet.dart`: the initial booking-details load previously treated a failure to fetch optional invite/share credentials as a failure of the entire sheet, hiding booking and participant details that had already loaded. Credential retrieval is now isolated and logged; the booking details remain available, while invite actions stay unavailable until valid credentials are obtained. Added mounted checks after stadium and participant loads before continuing asynchronous work.
- Invite authorization and credential-generation behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 8af23997a248232cce060105628a9d9ca0234828.


## Owner booking reschedule session guard — 2026-11-01
- Fixed `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart`: the reschedule action previously allowed the owner to select a new date and time and submit the proposal without confirming that the same owner account remained active across the date picker, time picker, and repository request. It now captures the initiating owner, requires it to match the booking owner, and verifies the same session after each asynchronous boundary before proceeding or showing the result.
- Reschedule proposal rules, selected times, and repository behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Commit: 2afc93df3681143a67af1874bc45002364692fb5.


## No-show action truthfulness correction — 2026-11-01

- Owner booking history no longer labels a WhatsApp support fallback as “Report Player No-Show”. The no-show action is rendered only when the actual no-show callback is supplied; this prevents a misleading control from opening an unrelated support chat.
- Code commit: `fcec5ac7f7472d0a24cfc17f59525b0091721a28`.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Pending refund state copy correction — 2026-11-01

- Player pending-booking card now distinguishes `refund_pending` from payment verification: the heading/body explicitly describe an in-progress refund, and the checkout action remains locked to prevent a new payment attempt against that booking. The check-status action remains available.
- Code commit: `1e3edbf34ad4b0d8567b5a8d2f4cd4c62ee5272f`.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Player booking-state and sharing recovery follow-up — 2026-11-01

- Pending player bookings now present `refund_pending` as a refund-in-progress state rather than incorrectly describing it as payment verification. Resume Checkout remains disabled while the refund is pending; Check Status remains available.
- Open Join match sharing now awaits the native share operation, logs platform errors, and presents localized failure feedback instead of allowing an unhandled asynchronous error.
- Code commits: `1e3edbf34ad4b0d8567b5a8d2f4cd4c62ee5272f`, `f58f822648acf10c22f8a3ef12e8af9b8044b376`.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Refund status refresh copy alignment — 2026-11-01

- The pending-booking Check Status response now preserves the distinction between a refund still processing and a payment awaiting server confirmation. It no longer tells a player to wait for payment confirmation when the actual state is `refund_pending`.
- Code commit: `02d3fcfeb8af4467ad98e7cd91dd4431dcfbc165`.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Prevent duplicate cancel during refund processing — 2026-11-01

- The pending-booking card no longer offers the trash/cancel action while `payment_status = refund_pending`. A refund already in progress is not presented as an ordinary unpaid pending booking with a second cancellation action.
- Code commit: `e2d2e4b38dc69f23309cf67fb8756bff835b5551`.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Booking confirmation empty-slot guard — 2026-11-01
- Fixed `lib/features/player/widgets/booking/booking_confirmation_handler.dart`: the confirmation handler sorted and accessed the first selected slot in both availability checking and draft construction. An empty or blank slot selection could therefore reach an invalid `first` access and fail without a useful message. The handler now rejects empty/blank selections before starting asynchronous booking work and shows localized feedback.
- Booking pricing, availability, and payment rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: e27f7a1bb7f49de7a023923acc46fe79c30430e2.


## Pending booking status refresh missing-record handling — 2026-11-01
- Fixed `lib/features/player/widgets/user_bookings/pending_booking_card.dart`: when Check Status could not retrieve the booking (`getBookingById` returned null), the card previously continued through the payment-state logic and could tell the player that payment was not confirmed and checkout could be completed using stale card data. It now stops, displays a localized refresh error, and does not present stale data as a verified current state.
- Payment confirmation, refund, and checkout business rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commits: `3da9dc30c58ddcc870164a04a32c07064635530e`, `394ec70a04267de7c1e631c5ff4cd84675f37de4`.


## Booking availability precheck fail-closed handling — 2026-11-01
- Fixed `lib/features/player/widgets/booking/booking_confirmation_handler.dart`: if both the booking-provider stream and direct repository fallback failed while checking the selected slot, the exception was logged but execution continued toward payment/booking confirmation. The flow now stops, resets its loading state, and tells the player that availability could not be verified. This avoids presenting an unverified slot as ready to book; the server-side booking authority remains unchanged.
- No pricing, slot reservation, or payment rules were changed. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `59423c42669c8787c0db8ed2d2547f990107199e`.


## Consolidated analyzer blocker corrections — 2026-11-01

The automatically triggered PR workflow run `41263244452` reached Flutter Analyze after dependency installation, localization generation, and Firebase client-options verification succeeded. Analyze reported compile/analyzer errors in the following source locations:

- `matchup_live_dashboard_screen.dart`: missing import for the shared `PrimaryButton`.
- `support_ticket_screen.dart`: BuildContext use after asynchronous gaps in the WhatsApp escalation path; explicit mounted guards now precede context access and launcher invocation.
- `booking_calendar_modal.dart`: one surplus closing parenthesis in the scroll-safe date dialog.
- `filter_bottom_sheet.dart`: the header's expanded title row was not closed before the trailing close button.
- `team_league_gathering_card.dart` and `team_league_match_dialog.dart`: dynamic locale-dependent text was incorrectly placed inside const widget subtrees.
- `payment_verification_modal.dart`: one missing closing parenthesis for the outer PopScope/Center composition.

These source corrections are committed on `uxlp-44-implementation`. They are not yet verified by a subsequent successful analyzer run. The original run stopped at Analyze; its Test and APK steps were skipped. The consolidated final validation gate remains open, and all UXLP-44 rule statuses remain runtime-pending.


### Filter header parser follow-up — 2026-11-01

The next automatic Analyze run reduced the previous blocker set to one remaining parser error in `filter_bottom_sheet.dart`: the nested title Row's child list had been closed as a widget call during the grouped correction. The child list and enclosing Expanded are now closed in the correct order. This follow-up is source-only and awaits the next Analyze result; the preceding run skipped tests and APK build.



## Consolidated CI and policy-copy follow-up — 2026-11-01

- Fixed the compile-time opt-in expression in `test/db_live_verification_test.dart` and `test/simulate_human_traffic_test.dart`. The previous use of `String.isNotEmpty` inside a const initializer caused `const_initialized_with_non_constant_value` analyzer errors. The compile-time gate now uses constant string comparisons. Both live-Supabase tests remain skipped unless `VSP_RUN_LIVE_TESTS=true` and both Supabase credentials are explicitly supplied; ordinary CI does not mutate or load-test the live database.
- Added a CI artifact upload for the debug APK and enabled the separate test-release APK workflow on the working branch. The test-release build uses the Gradle test-only debug signing path; it is installable for QA and is not a Play Store or production-signing artifact.
- Updated Arabic and English legal-facing copy in `terms_and_privacy_screen.dart`: owner/player eligibility now reflects 18+; cancellation/refund text no longer promises unconditional 100% refunds or unsupported grace/request/settlement windows; non-refundable administrative/payment-gateway fees are explicitly excluded; GPS no-show appeal radius is 200m with accuracy no worse than 50m. The existing 60-minute appeal period was retained. No database, RPC, RLS, payment calculation, refund engine, or GPS enforcement behavior was changed.
- The first CI run after the test-gate change failed at Analyze because of the two const-expression errors above; this was the exact root cause. A fresh CI run and test-release build are now triggered from the latest branch head.
- Final status is intentionally not marked complete until Analyze, the consolidated test suite, Debug APK build/upload, and test Release APK build/upload all finish successfully. The 44 UXLP rule rows and registered screen surfaces remain source-reviewed/runtime-pending until the required device, locale, state, accessibility, and visual checks are evidenced. No claim of runtime pass is made here.

### Source and audit documentation follow-up — 2026-11-01

- Corrected the UXLP rule audit so the numbered matrix contains exactly rules 1–44. The separate notification-retention concern is now recorded as an open product decision, not a duplicate rule 41. No retention/deletion backend behavior was added.
- Repaired four malformed screen-register rows that had multiple screen paths concatenated into a single Markdown row. The register now contains 216 table records across 190 unique Dart paths, including 26 repeated path entries for separate findings.
- Corrected the register's summary counts to match its actual table content. All registered paths remain source-reviewed/runtime-pending; this documentation repair does not claim runtime validation.

### Embedded UI coverage reconciliation — 2026-11-01

- Repository filename reconciliation identified nine additional embedded UI components omitted from the previous register: tournament dashboard/wizard steps and action bars, the player booking bottom bar, and championship/1v1 empty states.
- Added all nine as `not yet inspected`; no source-review status was inferred.
- The register now contains 225 table records across 199 unique Dart paths, including 26 repeated entries for separate findings. This supersedes the earlier 216-record / 190-path count.
- A filename-based candidate scan is triage only. It does not establish that every embedded widget or state variant has been discovered.

### Newly discovered UI components — source review and navigation fix (2026-11-01)

- Completed source review of the nine newly registered components: owner tournament dashboard action bar; tournament basics/system/scheduling steps; tournament step indicator and wizard footer; player booking footer; championship empty states; and 1v1 empty-state/banner components.
- Found a concrete navigation defect in `League1v1NoGovernorateState`: it called `Navigator.pushNamed('/edit-profile')`, but the app's GoRouter had no `/edit-profile` route. Added the authenticated app route and changed the action to `context.push('/edit-profile')`.
- Updated all nine register rows from `not yet inspected` to `source reviewed—runtime pending`, with specific source evidence and remaining runtime caveats.
- No booking/payment/tournament eligibility or server policy was changed. No tests or APK build were run; route behavior remains unverified at runtime.


## Owner inbox stream-state correction — 2026-11-01

- Fixed `lib/features/owner/screens/owner_inbox_screen.dart`: a conversation-stream failure with no current conversations—including an error after an empty snapshot—no longer appears as “No active chats”; it now shows a localized retryable error state.
- If a refresh fails after conversations were loaded, the last loaded conversations remain visible with a localized stale-data warning and retry action.
- No chat permissions, message behavior, database policy, or business rules changed. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `6deb79d17d3b40f1e8ecdc0eaeed7a973d9aaa02`.


## Owner ledger and tournament bracket recovery — 2026-11-01

- Fixed `lib/features/owner/screens/owner_ledger_screen.dart`: initial transaction-stream failure now shows a localized retryable error instead of an empty ledger; refresh no longer replaces loaded transactions with a loading screen, and stale transactions remain visible with a warning and a retry that rebinds the stream.
- Fixed `lib/features/owner/screens/tournament_brackets_screen.dart`: initial bracket-load failure guidance is now bilingual and no longer tells users to pull down when the screen provides an explicit retry button.
- Financial totals, payout behavior, tournament results, and all server-side rules remain unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commits: `c567f456026ccb5e3eb72fc7385df65a292ade4e`, `b537d3aa7fae2708e9eb481b8416d757c3364154`.


## Global search loading and stale-response recovery — 2026-11-01

- Fixed `lib/features/player/screens/global_search_screen.dart`: repository failures no longer leave the search spinner active indefinitely or appear as a valid no-results response; the screen now shows localized retry guidance.
- Each search request is generation-scoped. Editing the query invalidates the in-flight request immediately, so a slower earlier query cannot overwrite results for the newer query.
- Search scope and ranking are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commits: `ad7c6137ba301321c58efd54d1d159bfc238b85c`, `c0ca92c08f303ecf2a5998678f45919a7df1ceab`.


## Owner profile stadium-count state correction — 2026-11-01

- Fixed `lib/features/owner/screens/owner_profile_screen.dart`: the managed-stadium badge no longer presents a transient loading state or an initial stream failure as “0 stadiums”. It now shows localized loading/unavailable copy and a warning treatment when the count cannot be confirmed.
- Stadium ownership and count queries are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `0083175c4c04cd7eea33c7216a2a8df9d258b8d6`.


## Owner payout RTL and touch-target correction — 2026-11-01

- Fixed `lib/features/owner/widgets/ledger/owner_payout_dialog.dart`: the “Withdraw full balance” action previously aligned to the physical left in Arabic and physical right in English. It now uses directional start alignment and a focusable 48dp InkWell target with a semantic action label.
- Payout amount and request behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `851e699c19b51c1f5d9adfca13b34480e69bab3d`.


## Owner booking calendar RTL spacing — 2026-11-01

- Fixed `lib/features/owner/widgets/bookings/owner_bookings_filter_bar.dart`: horizontal day-strip spacing used a physical right margin, which did not mirror with the active text direction. It now uses a directional end margin so spacing remains consistent in Arabic and English.
- Day selection, date ordering, and booking behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `7d5009b855f619c7be83a15855e0fb2cb1adbd30`.


## Match details initial-load recovery — 2026-11-01

- Fixed `lib/features/player/screens/match_details_screen.dart`: an initial repository/network failure no longer falls through to the “match not found” screen. It now presents a localized, safe-area-protected error state with retry; a successful lookup returning no match still uses the not-found state.
- Both the initial loading and error views are now protected from system insets. Match eligibility, join, payment, and booking behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commits: `9077f2d85ad6bc41e2b78da1a4c7505afaa16429`, `9c4cd3fe13cfb36f9134f8a3ea9734bb132d01f4`.


## Player booking date-strip RTL spacing — 2026-11-01

- Fixed `lib/features/player/widgets/booking/booking_date_selector.dart`: the date-strip's left-only outer padding and right-only item margin did not mirror in RTL. Both now use directional start/end insets.
- Date order, selectable dates, and booking rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `fb55e51df77c075d5bad9a585a0b88a0ec6c56ac`.


## Owner ledger financial-summary failure handling — 2026-11-01

- Fixed `lib/features/owner/screens/owner_ledger_screen.dart`: financial-summary fetch exceptions are now caught and logged; the screen presents localized retry guidance when no summary is available, and it hides the payout-balance card instead of rendering an unverified zero balance. If transactions are present, they remain visible while a warning and retry action explain the unavailable summary.
- If a previously confirmed summary becomes unavailable during refresh, the last confirmed balance remains visible only with an explicit stale-data warning and retry; an unconfirmed balance stays hidden. Payout eligibility and server-side balance calculations are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commits: `7518de714ee47eba23e6f83e6e1aae6d94d9bc28`, `514e6f559ac8e6953e9d942034c8fb07d18de8bd`.


## Player home stadium carousel RTL spacing — 2026-11-01

- Fixed `lib/features/player/widgets/home/home_stadiums_section.dart`: the horizontal stadium carousel used a physical right margin, so card spacing did not mirror with Arabic direction. It now uses a directional end margin.
- Stadium ordering and discovery behavior are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `8f4ec24465196ea015207f48f562940defdb9a99`.


## Home feed and team-member RTL spacing — 2026-11-01

- Fixed `lib/features/player/widgets/home/home_feed_sections.dart`: public-match and championship horizontal carousels now use directional end spacing instead of a physical right margin.
- Fixed `lib/features/player/widgets/my_team/team_members_section.dart`: captain/member trophy-badge spacing and the captain remove-member action now use directional insets so they mirror with RTL/LTR.
- Match/championship ordering, team roster, and removal permissions are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commits: `d3860809397a96238b0ea875144781cd59e1ab8e`, `1f9917a827b389c6bb49f09356c5ad2fad722ddd`.


## Player home feed stream recovery — 2026-11-01

- Fixed `lib/features/player/widgets/home/home_feed_sections.dart`: initial public-match and championship feed errors now show localized retryable error states. If a realtime refresh fails after cards were loaded, the last loaded cards remain visible with a bilingual stale-data warning and retry action instead of replacing the section with a full error state.
- Stream scope and match/championship eligibility are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `cef9bdfa47ff40c385b9d16ca1bc12602152e575`.


## Owner tournament bracket stale-data recovery — 2026-11-01

- Fixed `lib/features/owner/screens/tournament_brackets_screen.dart`: when the realtime match stream fails after loading, existing rounds remain visible with a localized stale-data warning and retry action. The warning appears in both standings and round tabs; an initial error retains the dedicated bilingual retry state.
- Tournament progression and result-entry rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `e229a8acde8e4f7744268cd18606a29e112d6de7`.


## Player home notification badge account/error handling — 2026-11-01

- Fixed `HomeNotificationBadge` in `lib/features/player/widgets/home/home_feed_sections.dart`: the unread-count stream now rebinds when the authenticated user changes; an unread-count stream failure displays an amber warning indicator and localized tooltip rather than silently appearing as zero unread. Indicator placement is directional for RTL/LTR.
- Notification read/delete behavior and repository queries are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `8b8a070e903722c1193cac749489a19feb845b72`.


## Championship checkout fee modal responsiveness — 2026-11-01

- Fixed `lib/features/player/widgets/championship_checkout/checkout_financial_card.dart`: the long Arabic/English fee-transparency title now wraps within the modal width instead of competing with the leading icon; the acknowledgement action has a 48dp minimum height. Existing SafeArea and scrollable sheet behavior are retained.
- Fee text and calculations are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `f48bfbf4f179da8a994d3b2e7775dc5293ef46fd`.


## Tournament bracket preview dialog compact-screen correction — 2026-11-01

- Fixed `lib/features/owner/widgets/tournament/tournament_bracket_preview_dialog.dart`: both the bracket preview and live-draw room now bound their content height to the available viewport instead of fixed proportions/heights that could crowd dialog actions on short screens. Primary dialog actions now meet a 48dp height.
- Draw order and tournament operations are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `89e87ad474d37d5dbde1d395ae3f1c8bb085d25a`.


## Player favorites fetch and empty-state distinction — 2026-11-01

- Fixed `lib/features/player/screens/profile_subscreens/favorites_screen.dart`: favorite stadium fetch failures now display a localized retryable error instead of “Stadiums Not Found”. The future is retained for the same favorite-ID set, avoiding needless refetches on unrelated rebuilds; a retry explicitly reissues the request.
- Favorite membership and stadium queries are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `72225b48fb7f699d509c8327b2cd7bb93accbe19`.


## Pending booking action-state correction — 2026-11-01

- Fixed `lib/features/player/widgets/user_bookings/pending_booking_card.dart`: the cancel/delete action is no longer shown while payment is awaiting server confirmation or a refund is being processed. During those states the user sees status checking and the locked payment/refund state; once the booking is confirmed, cancellation remains available through the dedicated cancellation/refund flow.
- No payment, cancellation, refund, or server eligibility rules were changed. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `0c2ac37a580fa92efcf9cbbaa156c5b8c29015fd`.


## Pending booking action touch targets — 2026-11-01

- Updated `lib/features/player/widgets/user_bookings/pending_booking_card.dart`: Check Status, locked payment/refund status, and Resume Checkout actions now have 48dp minimum heights. The cancel icon already had a 48×48dp minimum target.
- Action state and payment rules are unchanged. No tests, analyzer, CI, runtime checks, migrations, or APK build were run. Code commit: `5d7ded90676ab95c7c5a80238a23ae6f56785fc4`.


## Approval-required Team League server guard finding — 2026-11-01

- Source review confirms the Team League fixture UI requires a booking and waits until the scheduled match time before showing result entry, but the active `submit_team_league_match_result` RPC definition does not enforce either condition before writing a submission.
- Evidence and proposed fix are recorded under `TL-01` in `docs/UXLP_44_RULE_AUDIT.md`.
- This is a server/business-rule enforcement change. No migration SQL was drafted or applied; it is held for explicit approval. No tests, analyzer, CI, runtime checks, or APK build were run.


## Critical approval-required Team League read authorization finding — 2026-11-01

- Source review found `get_team_active_league(p_team_id)` is `SECURITY DEFINER`, accepts a client-supplied team ID, returns league teams/matches/submissions and captain contact fields, but does not check `auth.uid()`, participant membership, captain identity, or league-creator identity before returning data. Its EXECUTE grant to `authenticated` is not a membership check.
- Evidence and a proposed authorization gate are recorded as `TL-02` in `docs/UXLP_44_RULE_AUDIT.md`.
- This is a critical server-side access-control change. No SQL was drafted or applied; it is held for explicit approval. No tests, analyzer, CI, runtime checks, or APK build were run.


## Critical approval-required Team League fixture RPC exposure — 2026-11-01

- Source review found `generate_team_league_fixtures(p_championship_id)` is `SECURITY DEFINER`, is granted to `authenticated`, accepts a caller-supplied championship ID, and can delete/recreate scheduled fixtures and move the league to `ongoing` without checking caller identity or full payment completion. The Flutter repository does not call this RPC directly; it is invoked internally by the service-role payment-confirmation flow.
- Evidence and proposed permission/invariant fix are recorded as `TL-03` in `docs/UXLP_44_RULE_AUDIT.md`.
- This is a critical access-control/business-integrity change. No SQL was drafted or applied; it is held for explicit approval. No tests, analyzer, CI, runtime checks, or APK build were run.


## Authentication safe-area, RTL and location touch-target batch — 2026-11-01

- `login_screen.dart`: removed duplicate bottom system inset inside `SafeArea`; forgot-password action uses directional end alignment for Arabic/English.
- `signup_screen.dart`: removed duplicate bottom system inset; GPS auto-detect is a localized 48×48dp `IconButton`.
- `player_onboarding_screen.dart` and `owner_onboarding_location_section.dart`: GPS auto-detect controls now use localized tooltips and 48×48dp targets.
- Code commits: `4d6bd7cfa9726f3d6ecff1992f5de842fa8ea15a`, `b4eef846e7614448575f81b6bcfad21c6a9add82`, `3d08f560651a8619efd93acf46fdf9bbdff045a5`, `b0b47a09e993add33200b2ac7665be0edad0814d`.
- No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Match details realtime failure recovery — 2026-11-01

- `lib/features/player/screens/match_details_screen.dart` previously relied on the initial fetch error flag but did not surface errors from the live `StreamBuilder` once a booking had loaded. The screen now keeps the last loaded booking visible, shows a localized stale-data warning, and recreates the realtime stream when the user retries.
- Initial loading/error/not-found states remain distinct; no booking eligibility or join/cancel rules changed.
- Code commit: `d0980d16fd9b020a10283babbb154e94adc68662`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner facility onboarding stream-state correction — 2026-11-01

- `lib/features/owner/screens/facility_onboarding_screen.dart` previously logged stream errors but then treated a missing/empty snapshot as proof the owner had no stadiums, which could misleadingly prompt a first-stadium flow during a network failure. It now shows a localized retryable error when the initial load fails; if previously loaded stadiums exist, it preserves them and displays a stale-data warning with retry.
- Code commit: `a62a5e08aaacf27fa5736b026a04b6c7bfbf224f`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner document upload error-copy correction — 2026-11-01

- `lib/features/owner/screens/owner_documentation_wizard.dart` had two upload catch paths that interpolated `e.toString()` into the localized user-facing message. Both now show localized generic retry guidance through the existing upload-failed localization, avoiding raw backend/filesystem exception details.
- Code commit: `9df785b4cc7720f12a5bd4eba8090071b45e3ea7`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner documentation dialog responsiveness — 2026-11-01

- `doc_wizard_dialogs.dart`: cancel-upload confirmation now uses a scrollable AlertDialog.
- `doc_under_review_dialog.dart`: the longer bilingual verification-status explanation now uses a scrollable AlertDialog, preserving the 48dp primary action.
- Code commits: `4aea3905ff98fb8f0b3f31c6c57838a097668586`, `49fc6c81aa6eba99f22b15e535795faf76568898`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner setup wizard top-inset correction — 2026-11-01

- `add_stadium_wizard.dart` and `owner_documentation_wizard.dart` both placed a default top SafeArea inside a Scaffold body that already begins below an AppBar, adding the status-bar inset a second time. Their body SafeAreas now use `top: false`; bottom/system navigation protection remains enabled.
- Code commits: `f2a741b3b412ca5a9e06c001732057326d41c43f`, `c383c574ef022db4ab112c6d768f1299c8eb3f08`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Edit Profile and Set New Password safe-area correction — 2026-11-01

- `edit_profile_screen.dart` and `set_new_password_screen.dart` both had default top SafeArea padding beneath an AppBar. Both now suppress the duplicate top inset; Edit Profile also avoids applying bottom safe padding twice because its scroll padding already includes the system bottom inset.
- Code commits: `dca334764a8d6f23c1fecac3dfe7426ff03d060b`, `4fe91fa6b55baef5b8590a8a2b44db560a64dc71`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Player Bookings top-inset correction — 2026-11-01

- `bookings_screen.dart` has its own AppBar, which already handles the top system inset. Its body SafeArea no longer adds the status-bar inset a second time.
- Code commit: `dab989b7e51bc7891300aa49d882df7ae31cf1c4`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Copilot sheet RTL and bilingual loading state — 2026-11-01

- `vsp_copilot_sheet.dart`: assistant loading bubble now aligns to `AlignmentDirectional.centerStart` instead of physical left, so it mirrors in Arabic; its loading message now has an English equivalent rather than remaining Arabic in both locales.
- Code commit: `fe6f2e3c45295958492c660013d049ffde5d535e`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Championship Checkout safe-area ownership — 2026-11-01

- `championship_checkout_screen.dart` now wraps the scroll body in `SafeArea(top: false, bottom: false)`: the AppBar owns the top inset and the existing `VSPBottomActionBar` already adds the bottom system inset. This prevents content spacing from double-counting either edge while keeping the sticky payment/registration action protected.
- Code commits: `c586a40b8bbf7b50c2e574b89bbe9735756dc0da`, `1bb0f1364e696e105a6e965cbc3d5ce77bad0dae`, `871854150764c1bea43c55c620b3c5b251536c40`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Copilot stadium card directional cue — 2026-11-01

- `vsp_copilot_sheet.dart`: the stadium-card forward chevron now mirrors in Arabic RTL while retaining its LTR orientation in English.
- Code commit: `90d93d88b48722742cc33d91d78e9363e6dca7f9`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Password reset dialog compact-layout and touch-target correction — 2026-11-01

- `forgot_password_dialog.dart`: AlertDialog is now scrollable; Cancel and Submit controls both have 48dp minimum heights, keeping the modal usable on short screens and improving touch accessibility.
- Code commits: `197b64fa48d08301df79505fb026b32a8ec9c3ff`, `175b8c9eefb6b5b8813e1972c061691f3a602aa1`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner Dashboard nested safe-area correction — 2026-11-01

- `owner_dashboard_screen.dart` is rendered inside `OwnerMainScreen`, which already applies the top safe inset and uses a bottom navigation bar that protects the system bottom inset. The dashboard's nested SafeArea now sets `top: false, bottom: false` to avoid duplicate spacing above and below its content.
- Code commit: `a554d6028441804afc8e8bf87c69100a678c14f3`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner Dashboard bottom safe-area preservation — 2026-11-01

- Follow-up source review retained the dashboard's bottom SafeArea because the dashboard scroll content still needs system-navigation protection while the parent OwnerMain shell deliberately sets `bottom: false` for its bottom navigation bar. Only the already-applied parent top inset is suppressed in the nested dashboard body.
- Corrective code commit: `7d8aa46757d1116fb7547d1e9b4d9fcf1aee6f99`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Challenge H2H loading/error/empty distinction — 2026-11-01

- `TeamRepository.getHeadToHeadStats` previously converted any Supabase query failure into a fabricated all-zero result, causing the challenge opponent card to say this was the teams' first match. It now returns `null` on query failure.
- `challenge_select_team_screen.dart` tracks H2H failure separately; `challenge_team_card.dart` now distinguishes loading, failed/unavailable history, genuine zero prior matches, and populated statistics with localized copy.
- Code commits: `f580fcb26469a825bdba692c5de569158fcfc0a9`, `d11219722c9084275454ada24ac873ec64b0f98f`, `4c68bb50a462667508b8a21a1899019ee401f110`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Challenge team champion badge localization — 2026-11-01

- `challenge_team_card.dart`: the champion badge no longer renders Arabic text in English mode; it now uses localized Arabic and English labels.
- Code commit: `b0b59cb80841d674dd7bbc0070d830bb182de3d5`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Additional auth, stadium, booking, and challenge surface fixes — 2026-11-01

- Auth: signup GPS hit target corrected to 48dp; welcome Skip target corrected to 48dp; owner/player onboarding exit dialog actions corrected to 48dp; login/signup safe-area keyboard padding and RTL alignment updated.
- Player booking/discovery: booking-success reference copy and all-stadium sort actions now have 48dp targets; challenge-code sheet is viewport-bounded, scrollable, bottom-safe, and its copy/share actions are 48dp; stadium details tabs now fill a 48dp row with InkWell semantics.
- Updated screen register and rule audit alongside the source changes. Team League findings TL-01, TL-02, and TL-03 remain approval-required; no Supabase SQL was changed.
- No tests, analyzer, CI, runtime checks, or APK build were run. This is not a final UXLP-44 completion claim.


## Championship governorate banner localization — 2026-11-01

- Fixed `lib/features/player/widgets/champion/championships_list_tab.dart`: the Arabic championship browsing banner previously interpolated canonical governorate identifiers directly, which could leave English governorate names inside Arabic copy. Both the selected-governorate label and the return-to-home-governorate label now use the existing `championTranslateItem` helper, matching the 1v1 banner's localization behavior.
- Filter values, stream scope, navigation, and tournament eligibility are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `66e05af0a2c483f4a3e21128d9c7b651e2375b9c`.


## Directional bottom action-bar inset preservation — 2026-11-01

- Fixed `lib/core/ui/vsp_ui.dart` (`VSPBottomActionBar`): the component accepts `EdgeInsetsGeometry`, but previously only preserved values when the runtime type was `EdgeInsets`; a supplied `EdgeInsetsDirectional` silently fell back to hardcoded physical padding. The component now applies the caller's padding unchanged and adds the device bottom safe inset in a separate nested `Padding`, preserving directional geometry.
- This changes layout composition only; no action behavior or booking policy changed. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `025643a19457b5d21568958e531b7126cc465fe1`.


## Booking calendar viewport and Add Player sheet caller review — 2026-11-01

- Fixed `lib/features/player/widgets/booking/booking_calendar_modal.dart`: the scrollable calendar dialog previously forced a 240dp minimum maximum-height when the remaining viewport was smaller, which could exceed the actual keyboard/short-screen space. Its maximum height now clamps to the available viewport instead of forcing that minimum.
- Verified the `AddPlayerSheet` call site in `lib/features/player/widgets/create_team_sheet.dart`: it is opened with both `isScrollControlled: true` and `useSafeArea: true`, resolving the previously open caller-configuration check.
- No calendar selection, booking, roster, or eligibility behavior changed. Source review only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Calendar code commit: `c2f57c7317b9ef4bfd04f409227a8295179fbaea`.


## Booking calendar RTL navigation and accessibility — 2026-11-01

- Fixed `lib/features/player/widgets/booking/booking_calendar_modal.dart`: previous/next month arrows now swap direction in RTL instead of retaining LTR-facing Iconsax glyphs. Both icon buttons also expose localized Arabic/English tooltips for their month-navigation action.
- Date selection and month-boundary rules are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `2a3a66cfe239a2924bb03c9ac68131e95ac656f1`.


## Live Supabase data/authorization source reconciliation — 2026-11-01

Read-only inspection was performed against the connected production VSP project `mktqkddbcddrxjxabdua` (Postgres 17.6.1.127):

- Confirmed `generate_team_league_fixtures(uuid)` and `confirm_team_league_payment(...)` are SECURITY DEFINER but executable only by `postgres` and `service_role`; authenticated client execution is not present. Historical TL-03 direct-client exposure is therefore closed in the live ACL.
- Confirmed `get_team_active_league(uuid)` is still executable by `authenticated` and still lacks participant/creator authorization in its active SECURITY DEFINER body. TL-02 remains approval-required.
- Confirmed `submit_team_league_match_result(uuid,uuid,text)` is still executable by `authenticated` and its active definition still lacks the booking/kickoff guard. TL-01 remains approval-required.
- Rechecked the six previously flagged queue/security tables: RLS is enabled and each now has explicit policies (2, 2, 1, 2, 2, and 2 respectively). The old zero-policy inventory is no longer current.
- No SQL, RLS, grants, migrations, or production data were changed. No tests, analyzer, CI, runtime checks, or APK build were run.


## Release APK trigger deferred to final phase — 2026-11-01

- The release workflow previously had a push trigger for `uxlp-44-implementation`, which conflicted with the current instruction to defer APK generation until all 11 workstreams are complete. Removed the automatic push trigger; `.github/workflows/build-release-apk.yml` is now `workflow_dispatch` only.
- Workflow commit: `76e27f24ac4173685197f24cb5e42892ba706356`. No manual workflow dispatch was started. The connector exposed no workflow-run cancellation/list action, so any run already triggered by earlier commits could not be confirmed or cancelled from this session. Future branch pushes will not trigger release APK builds.


## CI validation trigger deferred to final phase — 2026-11-01

- The CI workflow also had automatic `pull_request` and `push` triggers. Because the current instruction is to defer the single consolidated validation pass until all source work is complete, these triggers have been removed; `.github/workflows/ci.yml` is now `workflow_dispatch` only.
- Workflow commit: `97e09403e198c25ecab0acd1b927eb190424af66`. No manual CI run was started. Previously triggered CI run status could not be inspected/cancelled with the available GitHub Actions controls in this session. Future branch commits and PR updates will not start CI automatically.


## Add Player sheet action target correction — 2026-11-01

- Fixed `lib/features/player/widgets/add_player_sheet.dart`: the Add action in the found-player card was 40dp high. It now uses a 48dp hit area, matching the VSP touch-target standard.
- Player lookup, governorate eligibility, roster insertion, and invitation behavior are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `d15526e2233ede46bd2f7fa527c00dfb7f2062ee`.


## Shared loading-state accessibility — 2026-11-01

- Fixed `lib/core/ui/vsp_ui.dart`: the canonical VSP loading indicator now exposes a localized semantics label (`جارٍ التحميل` / `Loading`) so assistive technology can identify the in-progress state.
- Visual appearance and loading lifecycle are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `749a144d77da65abffbf90536886c90f6f627a3b`.


## Reactive connectivity error-state correction — 2026-11-01

- Fixed `lib/shared/widgets/vsp_error_state.dart`: it previously read `ConnectivityService.instance.isCurrentOnline` once during `build`, so an error screen already on display could keep showing stale offline/server copy after connectivity changed until an unrelated parent rebuild. It now listens to `isOnlineNotifier` via `ValueListenableBuilder`, switches the title/message/icon/state immediately, and marks the changing state as a live region for assistive technology.
- Retry callback, custom online-server message, and button behavior remain unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commits: `d6f20e446b907636add2cfb0c46046fa4da48e87`, `88a89f23515752def1cf2350bd063e37ab344ca1`.


## Shared empty-state visual normalization — 2026-11-01

- Fixed `lib/shared/widgets/vsp_empty_state.dart`: the general-purpose empty-state icon previously used the brighter `zinc100`, while the championship empty-state family uses the muted `zinc400` tone. It now uses the same charcoal-system icon tone.
- Fixed `lib/core/ui/vsp_ui.dart`: shared `VSPStateView` empty/disabled states now use the same 28dp empty-state icon token as `VSPEmptyState` and `ChampionEmptyState`, while error/success states retain the larger status icon.
- Empty-state tile geometry, action behavior, and state copy are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commits: `20b07e2bb584426de7a86b625a0b80b2bb81fe6d`, `869014683a6328af5283ba2f74a023baf56df8b7`.


## Support ticket sheet keyboard inset correction — 2026-11-01

- Fixed `lib/features/player/screens/support_tickets_screen.dart`: the new-ticket modal route already applies the keyboard view inset, but the sheet's own `maxHeight` calculation subtracted `MediaQuery.viewInsets.bottom` a second time. Removed the duplicate subtraction while retaining the viewport cap, scrollable form, route `useSafeArea`, and bottom system padding. This prevents the available sheet height from collapsing by counting the keyboard twice.
- Ticket creation, account-generation guard, and submit behavior are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `a098bb1c594a1eba3c5a807498884102f6ab3e85`.


## Add Player modal viewport inset correction — 2026-11-01

- Fixed `lib/features/player/widgets/add_player_sheet.dart`: the caller opens the sheet with `isScrollControlled: true` and `useSafeArea: true`, so the modal route already constrains content to the keyboard-safe viewport. The sheet previously subtracted keyboard and top/bottom system insets again from the full screen height, risking a collapsed content area on compact devices or when the keyboard was open. Removed the duplicate height calculation and now rely on the route's actual parent constraints; retained the sheet's bottom system padding and scrollable body.
- Player search, eligibility, and add/invite behavior are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `cb8327b5f52d019a58f9ce071fa94c2afae1107c`.


## Owner modal keyboard/system inset corrections — 2026-11-01

- Fixed `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart`: the scroll-controlled `useSafeArea` route already applies keyboard/system viewport constraints, but the sheet also subtracted `viewInsets.bottom` and system padding from full screen height. It now uses only an 88% preferred content-height cap; the route's parent constraints enforce the actual available viewport. Bottom safe padding and scrollable password form remain.
- Fixed `lib/features/owner/widgets/brackets/tournament_auto_schedule_modal_sheet.dart`: removed the same duplicate keyboard/system inset subtraction and the unsafe 240dp minimum clamp that could exceed a compact viewport. It now uses an 88% preferred cap while respecting the modal route's actual constraints.
- Password verification, schedule calculation, and persistence behavior are unchanged. Source-level corrections only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commits: `33dc6d1b5c43a4fc25ce3811273f0fa926453171`, `947cee3bf2d21f785914ee12114f1bbf568c89dc`.


## Manual stadium-location sheet keyboard inset correction — 2026-11-01

- Fixed `lib/features/owner/widgets/add_stadium/add_stadium_location_picker_sheet.dart`: the scroll-controlled, SafeArea modal route already applies the keyboard view inset, while the manual-address sheet also added `viewInsets.bottom` to its own bottom padding. Removed the duplicate keyboard inset and retained the system bottom padding plus content spacing so the address field and actions remain reachable without double-counting keyboard height.
- Address entry, governorate selection, and location resolution are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `ac329b8bdf6ca1790b5e11e14d2a74ed06917528`.


## Owner Copilot sheet keyboard viewport correction — 2026-11-01

- Fixed `lib/features/copilot/screens/vsp_copilot_sheet.dart`: its scroll-controlled, SafeArea modal route already handles keyboard insets, while the sheet also reduced its own height by `viewInsets.bottom` and added a matching bottom margin. Removed that duplicate keyboard offset/shrink; the sheet now uses its preferred 78% height and lets the route's parent constraints provide the actual keyboard-safe viewport. Internal bottom SafeArea and chat composer remain.
- Copilot role gate, messages, tool access, and navigation behavior are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `9e01276e39b1a7b80e05d8a5517a45497c9cde48`.


## Tournament score-entry modal keyboard inset correction — 2026-11-01

- Fixed `lib/features/owner/widgets/brackets/tournament_score_modal.dart`: the scroll-controlled SafeArea route already applies keyboard insets, but the sheet also subtracted `viewInsets.bottom` from its maximum height and added the same inset again below the footer actions. Removed both duplicate applications and the unsafe 240dp minimum clamp. The sheet now uses a preferred 92% content-height cap and the route's actual parent constraints; the footer retains the system bottom inset.
- Score entry, goal details, penalties, edit reason, and submit behavior are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `7ea2f5a740d42b5ed7bd732fc99b6a1f66c600c6`.


## Additional owner sheet keyboard inset corrections — 2026-11-01

- Fixed `lib/features/owner/widgets/owner_booking_sheet.dart`: removed the manual keyboard/top/bottom inset subtraction from its max-height calculation. Its scroll-controlled, SafeArea route now owns the actual keyboard-safe viewport; the sheet retains a 92% preferred height cap and system bottom padding.
- Fixed `lib/features/owner/widgets/quick_phone_booking_modal.dart`: removed the extra keyboard-bottom `Padding` around the sheet and stopped switching bottom padding based on keyboard visibility. The modal route already moves/resizes the sheet; system bottom padding remains.
- Fixed `lib/features/owner/widgets/tournament/tournament_manual_team_sheet.dart`: removed duplicate keyboard/system inset subtraction from both the height calculation and footer padding, and removed the unsafe 240dp minimum. The route owns viewport constraints; footer retains the system bottom inset.
- Booking, payment, manual team registration, and customer input behavior are unchanged. Source-level corrections only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commits: `068d381b19a96f935560c9a8b69ca558a088ba2f`, `d96527b83cd298ae44d32edd414950a3d1e9f0e2`, `981951eebe65b85d4953b60a8806b1aea97d18b7`.


## Player booking and collective-invite modal viewport corrections — 2026-11-01

- Fixed `lib/features/player/widgets/booking_type_modal.dart`: removed the manual keyboard/system inset subtraction and unsafe 240dp minimum from its height calculation. The scroll-controlled SafeArea route now owns the actual viewport; the sheet retains its preferred 82% content-height cap and bottom padding.
- Fixed `lib/features/player/widgets/collective_match_invite_sheet.dart`: removed duplicate keyboard/system inset subtraction and the 240dp minimum from its maximum-height calculation. Added the device bottom system inset to the scrollable list's bottom padding so final content/actions remain reachable above system navigation.
- Booking type selection, team lookup, collective invite, join/leave, and host actions are unchanged. Source-level corrections only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commits: `422c4f223ce9e6edf62f17dbb44b0eead1cd33a5`, `a75c17dbe3344905955eb4a50d372c7750855824`.


## Create Team sheet keyboard viewport correction — 2026-11-01

- Fixed `lib/features/player/widgets/create_team_sheet.dart`: both known callers open it as a scroll-controlled `useSafeArea: true` modal route. The sheet previously subtracted keyboard and system insets again from full screen height. It now relies on the route's actual viewport constraints while retaining its bottom system padding, scrollable form content, and sticky action controls.
- Team creation, logo upload, roster entry, and membership behavior are unchanged. Source-level correction only; no analyzer, tests, CI, runtime checks, migrations, or APK build were run. Code commit: `ca4778a2bed9827aa9dccb4f2655d9468884d904`.


## Owner schedule and dashboard interaction refinement — 2026-11-01

- `lib/features/owner/widgets/bookings/owner_time_slot_row.dart`: replaced the opaque `GestureDetector` wrapper with a transparent `Material` + `InkWell`. Tap and long-press behavior are unchanged, while the primary tap is now keyboard-focusable, exposes button semantics, and provides standard interaction feedback.
- `lib/features/owner/widgets/bookings/owner_slot_card.dart`: the trailing booking-detail chevron now mirrors in RTL instead of always pointing right.
- `lib/features/owner/widgets/dashboard/owner_dashboard_header.dart`: the profile-photo action now has a localized tooltip and an InkWell focus/semantic target; the verified-account tooltip is now localized in Arabic and English.
- These are presentation/accessibility-only changes; booking, profile upload, and identity-verification logic are unchanged. Source commits: `c853ea69ab5634790fc167021aa2a08b19e120da`, `0555e1a17c1cfce2a6ca0f80fcf0dbb3ccfc4a6e`, `f880179e87a87ccc2a4db8781254e02fa9830e3d`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Challenge selection and owner schedule interaction follow-up — 2026-11-01

- `lib/features/player/widgets/challenge/challenge_team_card.dart`: replaced the non-focusable `GestureDetector` selection surface with `Material` + `InkWell`, preserving the selected-state animation and tap callback; long team names are now bounded to two lines with ellipsis so the champion badge and selection affordance remain readable.
- `lib/features/owner/widgets/bookings/owner_time_slot_row.dart`: long-press expiry checks now use `VSPTimeService.now`, matching tap handling and the app's centralized time source instead of reading the device clock directly.
- Source commits: `fa061708ed0c944b6306e4408ac32b3f15b5717a`, `bd4ac74abe24a113967bfe37bbc551c578231985`. Source-only; no tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Tournament scheduling and pending-cash date consistency — 2026-11-01

- `lib/features/owner/widgets/brackets/tournament_match_card.dart`: replaced the 16dp GestureDetector calendar glyph with a 48dp IconButton and localized scheduling tooltip; schedule text is now bounded to two lines. Date-picker defaults and limits now use `VSPTimeService.now`, including the default time, instead of mixing device-clock reads.
- `lib/features/owner/widgets/dashboard/owner_pending_actions_bar.dart`: today's pending cash-booking count now uses `VSPTimeService.now`, matching the app's centralized time source used by other booking flows.
- Scheduling persistence, pending-cash eligibility, and booking/payment rules are unchanged. Source commits: `bf9728854a4fd82ac517a0c5a9965fbf1afb3163`, `986d4ac9d8c8be36e10c8caaeee001f2a85a1bdf`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Player home, chat composer, and payment copy refinement — 2026-11-01

- `lib/features/player/widgets/home/home_top_bar.dart`: profile and search surfaces now use focusable InkWell actions with localized tooltips; filter action now has a localized tooltip. Player avatar uses cached image loading and an explicit initial/icon fallback when the URL is blank or the image fails, rather than leaving a blank avatar after a network failure.
- `lib/features/player/widgets/chat/chat_input_bar.dart`: send action now uses a focusable 48dp InkWell with a localized tooltip while preserving the sending lock and RTL send-arrow direction.
- `lib/features/player/widgets/payment/payment_method_selector.dart`: replaced the absolute “100% Secure” claim with the factual “Paymob Gateway / بوابة Paymob” label; the accompanying copy continues to state that payment selection occurs on Paymob's official gateway.
- No navigation, messaging, payment routing, or pricing behavior changed. Source commits: `7358e28a0103eaa6fd76ba3a8272cc826f2ab1e9`, `29867442c66dab84ce359672d104df9e261b4de8`, `50ffd573c2efc1026b487ac1a322a545373ce265`, `50893601929d447510918b1099ff9a0bb604c279`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Player booking slot selection and challenge-result time consistency — 2026-11-01

- `lib/features/player/widgets/booking/booking_slot_card.dart`: available slot cards now use a Material/InkWell selection surface, exposing keyboard focus, button semantics, and standard feedback while booked/past slots remain disabled and all visual states stay unchanged.
- `lib/features/player/widgets/booking/booking_slot_stream_section.dart`: current-day, next-available, ongoing, and past-slot calculations now use `VSPTimeService.now` rather than a separate device-clock read.
- `lib/features/player/widgets/user_bookings/challenge_result_actions.dart`: the result-submission prompt now evaluates booking end time against the same centralized VSP clock used by booking screens.
- No booking eligibility, time-window policy, result-submission, or scoring rules changed. Source commits: `d5badce48843ca21bfe6249dd57a0db9530ff768`, `fcca24c89c7ce717b4b55e5b3c5eaefca136ea25`, `04875c4918530f3da9759fb0b33717fa4202d2c6`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Championship checkout compact-width resilience — 2026-11-01

- `lib/features/player/widgets/championship_checkout/checkout_championship_header.dart`: championship title is bounded to two lines; governorate and team labels now flex within the metadata row and ellipsize instead of forcing horizontal overflow on compact widths or with long names.
- `lib/features/player/widgets/championship_checkout/checkout_squad_requirement_card.dart`: roster heading now yields space to the count badge and truncates cleanly rather than overflowing when localized text or large text scaling is used.
- Checkout values and roster min/max validation are unchanged. Source commits: `345275ef60b2ddf4c6fe7d70cac0314a0563935b`, `b9ffda958156bf540e14b76b46ef855421982836`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Stadium location action accessibility and recovery — 2026-11-01

- `lib/features/player/widgets/stadium_details/stadium_information_tab.dart`: the location badge is now a focusable InkWell with a localized map-action tooltip; long addresses are bounded to one line within the available screen width. The map launcher now checks the returned launch result and shows localized recovery feedback when the external maps app cannot open, while keeping technical exceptions in diagnostics.
- Coordinates/address selection and map URL behavior are unchanged. Source commits: `aed4b1aab8511b80493aeb6daed0133a5e8875b8`, `6231c0f438cd5e5ce73d3f24c404323383f279ec`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Stadium image gallery action accessibility — 2026-11-01

- `lib/features/player/widgets/stadium_details/stadium_image_carousel.dart`: share and favorite controls now use focusable 48dp InkWell targets with localized tooltips; favorite tooltip changes between add/remove state. Image taps and the gallery indicator now expose a localized, focusable gallery-opening action while preserving swipe paging, Hero transition, and full-screen gallery behavior.
- Favorite state, sharing payload, and image loading/fallback behavior are unchanged. Source commit: `c308b47cca78448cf7eb3aa8f6b19f16f43d505f`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner quick-cash clock consistency — 2026-11-01

- `lib/features/owner/widgets/dashboard/owner_quick_cash_card.dart`: when no explicit `currentTime` is injected, the quick-cash card now defaults to `VSPTimeService.now`, matching the owner pending-cash bar, booking slots, and other date-sensitive UI. Explicit caller-supplied time remains supported.
- Cash confirmation and payment-status mutation are unchanged. Source commit: `8a3a2007566590cb90779b0d31d774dbdb99f89d`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Chat message accessibility and localized timestamp — 2026-11-01

- `lib/features/player/widgets/chat/chat_message_bubble.dart`: the owner-authored message edit action remains available by long press and is now also exposed as a localized screen-reader custom action; sender names are constrained to one line with ellipsis, and message timestamps use the active locale's `DateFormat.jm` rather than a fixed English AM/PM format.
- Message edit authorization, repository mutation, read state, and message content are unchanged. Source commit: `2f48a9caa58f078ffc48b29a5566238403db96b2`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Signup and email-verification interaction corrections — 2026-11-01

- `lib/features/auth/widgets/verify_email/otp_box.dart`: removed the transient `FocusNode()` allocation from `build` in the keyboard-listener wrapper. The parent `Focus` now handles key events while the externally owned TextField focus node remains the single input focus owner, avoiding a new undisposed node on every rebuild.
- `lib/features/auth/widgets/verify_email/otp_resend_section.dart`: resend is now a real TextButton with a 48dp minimum target and remains disabled during countdown/resend.
- `lib/features/auth/widgets/signup/signup_date_of_birth_field.dart`: date-of-birth picker surface now uses a focusable InkWell and localized label tooltip while retaining its existing field height and callback.
- OTP value distribution, resend timing, age validation, and signup policy are unchanged. Source commits: `d03b89bbc9c303c1e74d95bfb6a722c58fe335af`, `cf7f225de5405ce3fce507e2a64b1777972c1c0e`, `5b283415b6ed5028ed3e36a48188f1b880a2c039`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Password strength and verification-email presentation — 2026-11-01

- `lib/features/auth/widgets/signup/signup_password_strength_bar.dart`: the password-strength progress indicator now exposes its strength label and percentage through accessibility semantics, in addition to the visible label/bar.
- `lib/features/auth/widgets/verify_email/verify_email_header.dart`: masked email is now explicitly LTR, centered, and bounded to one line so mixed Arabic/English verification screens do not reorder or overflow the address.
- Password scoring and email masking are unchanged. Source commits: `f08220df0d53e821f714d877028c71b7aca32b22`, `854d157d9b04296a3fbcbaa44faeb60df7eb93ad`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Approval-required business-rule finding — owner manual cash bookings — 2026-11-01

- **Observed source conflict:** `lib/features/owner/widgets/dashboard/owner_pending_actions_bar.dart` explicitly excludes bookings where `createdByUserId == ownerId`, with the comment that manual owner-created bookings are accounting records, not app cash-collection actions. `lib/features/owner/widgets/dashboard/owner_quick_cash_card.dart` does not apply that exclusion: it includes any same-day cash booking that is not cancelled/fully-paid/refunded/refund-pending and exposes the cash-confirmation action. The same owner-created manual cash booking can therefore be excluded from the pending-action count but still appear as a cash-collection task in the quick-cash card.
- **Root cause:** the two owner dashboard surfaces independently implement the same cash-eligibility predicate and disagree on whether owner-created manual bookings belong to cash-collection actions.
- **Proposed resolution (not applied):** if the existing comment is the authoritative product rule, apply the same `createdByUserId == ownerId` exclusion to `OwnerQuickCashCard` pending and settled summaries; alternatively, if owners must confirm cash received for their manual bookings, remove the exclusion from `OwnerPendingActionsBar` and make both surfaces share one eligibility predicate. This changes which bookings are actionable/accounted in the dashboard, so it remains a product decision; no code or payment behavior was changed.


## Owner PRO upgrade CTA target — 2026-11-01

- `lib/features/owner/widgets/dashboard/owner_pro_upgrade_teaser.dart`: replaced the non-focusable gesture target with a Material/InkWell action, raised its minimum target height to 48dp, and bounded the localized upgrade label to two lines for compact widths.
- Upgrade callback, displayed plan price, and plan entitlement remain unchanged. Source commit: `e824ab825bcc5f501c7d267a93370191a57a6205`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


### Date-of-birth field structure follow-up — 2026-11-01

- Rewrote the `SignupDateOfBirthField` wrapper with balanced Tooltip/Material/InkWell/Container nesting and bounded the selected date to one line. The accessible tap target and original date display/callback are preserved.
- Follow-up source commit: `524148fc4ee6925b06b422ad600d0f2deb8b7c22`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Login signup-role sheet accessibility and localization — 2026-11-01

- `lib/features/auth/widgets/login_footer.dart`: the sign-up entry is now a wrapping, 48dp-minimum `TextButton` instead of a bare gesture; the role-selection bottom sheet now respects bottom safe area and scrolls on short screens; role title, subtitle, and both role descriptions now have Arabic and English copy; the trailing role arrow mirrors in RTL; role cards use focusable `InkWell` targets with an 80dp minimum height.
- Existing routes and player/owner role destinations are unchanged. Source commit: `b3cd4f1cf2dcd43283037aa92e6820230b1d0f98`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


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


## Social sign-in exception recovery — 2026-11-01

- `lib/features/auth/widgets/login_social_auth_row.dart`: Apple and Google sign-in now catch thrown provider/platform exceptions, always release the loading state while the screen is mounted, and show a localized retry message. Previously an exception escaping either awaited provider call could leave the login screen permanently showing a loading state. Successful sign-in routing and provider error-message handling are unchanged.
- Source commit: `3cd017d817738b4c6569f0651e94c1def6b01b6f`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Authentication and owner onboarding component review — 2026-11-01

- Reviewed the social sign-in row, owner payout information card, and responsive signup name fields. The social buttons already use the shared `SocialAuthButton` semantic Material target at 56dp and the owner payout fields use localized labels from generated app localizations. Signup name fields already switch to a vertical layout below 360dp and use localized labels/hints. No source change was made where the existing implementation already met the inspected criterion; device/large-text verification remains pending.


## Empty/loading/error state consistency pass — 2026-11-01

- `lib/shared/widgets/vsp_empty_state.dart`: removed its separate hand-built layout and delegated rendering to the canonical `VSPStateView(state: VSPUiState.empty)`. The shared empty state now inherits the same bounded-width, scroll-safe layout, charcoal square icon treatment, typography, and spacing as the design-system state renderer. Optional primary action remains 48dp-or-greater through the canonical button.
- `lib/features/player/widgets/champion/champion_empty_state.dart`: championship, teams, and 1v1 empty states now use `VSPEmptyState` rather than maintaining a second copy of the visual structure. Arabic/English selection, explicit locale override, text, and optional return action are preserved.
- `lib/features/player/widgets/champion/league_1v1/league_1v1_empty_states.dart`: the missing-governorate state now uses the same shared empty-state component; its profile navigation action and localized copy are preserved.
- Reviewed shared loading and error presentation in `VSPStateView` and `VSPErrorState`: loading/processing content is bounded and scrollable, has a localized progress semantic label, and error/offline states distinguish connectivity from server failures, announce the state through a live region, and provide retry.
- Source commits: `d62fbf3cd79e307b98168e15739c8f95768e9320`, `579addbd0da8e7d00c39be5aafe473a72d9a8da1`, `13690300262d064c25a47c7f78de5caee1fff00c`, `8f2a0799e9a0e7f67d1d6fb8c216e7f061fae8e9`.
- Scope of this pass: 3 Dart source files consolidated; shared loading/error components source-reviewed, not changed. This is not proof that every caller uses the shared components correctly. Caller-by-caller coverage and runtime checks remain pending. No tests, analyzer, CI, runtime checks, or APK build were run.


## Dialog action target and Supabase observability review — 2026-11-01

- `payment_cancel_dialog.dart`: both checkout exit/continue actions now have a minimum 48×48dp hit target while preserving the existing localized copy and cancellation callback contract.
- `booking_sheet_cancel_dialog.dart`: the standard cancellation dialog actions and manual-deposit abort action now have minimum 48×48dp hit targets; refund/penalty decisions and ledger wording were not changed.
- Supabase read-only inspection for project `mktqkddbcddrxjxabdua`:
  - Unified logs sources currently available: `edge_logs`, `postgres_logs`, `postgrest_logs`.
  - Last-24-hour error-pattern query surfaced 121 PostgREST entries matching the Warp server timeout message; the sample message is dated 2026-10-31 09:11 UTC. This is a log-pattern count, not 121 unique user incidents.
  - Security advisors report 1 SECURITY DEFINER view (`public.teams_public`), 198 authenticated-executable SECURITY DEFINER function findings, and leaked-password protection disabled.
  - Direct ACL query confirms `get_team_active_league`, `submit_team_league_match_result`, and `vsp_user_is_tournament_participant` are SECURITY DEFINER and executable by authenticated.
- No Supabase grants, RLS policies, views, functions, auth settings, migrations, or production data were changed. The broad 198-function advisor result must be triaged by intended client entry points and internal wrapper dependencies; blanket revocation would risk breaking app workflows.
- No tests, analyzer, CI, runtime validation, or APK build were run.



## Follow-up batch — dialogs and owner/player sheet targets (2026-11-01)

- `lib/features/player/widgets/collective_match_invite_sheet.dart`: close control now has a localized tooltip and 48×48dp constraints; manual participant increment/decrement controls use 48×48dp.
- `lib/features/player/widgets/championship_details/championship_governorate_dialog.dart`: primary confirmation action increased from 44dp to 48dp.
- `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart`: cancel action now has a 48dp minimum height and padded tap target. Existing scroll-controlled route, SafeArea, keyboard-dismiss behavior, and password verification flow preserved.
- `lib/features/player/widgets/payment/payment_cancel_dialog.dart` and `lib/features/owner/widgets/booking_sheet/booking_sheet_cancel_dialog.dart`: both received 48dp action targets in the preceding batch.
- `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart`: already used 48dp PrimaryButton actions and a narrow-screen stacked layout; no behavioral change needed.
- `lib/features/owner/widgets/quick_phone_booking_modal.dart`, `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart`, and `lib/features/player/widgets/payment/payment_verification_modal.dart` use scrollable content or bounded modal layouts; this source pass did not establish complete device/runtime SafeArea coverage.
- Supabase log drill-down shows repeated Warp timeout entries at root path `/` with no method/status/request identifier fields populated. They recur in time clusters (for example 08:54, 08:44, 08:16 UTC on 2026-11-01); the available log payload does not identify a concrete app RPC or table. No SQL/function/index change is justified from these entries alone.
- No tests, analyzer, CI, runtime validation, or APK build were run.


## Root loading, owner lifecycle, and final grouped source review — 2026-11-01

- Root authenticated-profile resolution now renders the canonical bilingual loading state inside SafeArea rather than a bare spinner. Existing timeout-to-offline recovery is retained.
- Owner celebration listener setup now checks widget lifecycle before deferred Provider access and before responding to stream events; this closes a post-frame disposal race.
- Three additional compact-layout/accessibility corrections were committed: tournament step labels are width-bounded, collective-booking player-count labels cannot push controls off-screen, and the ongoing-match extension action now has a 48dp minimum target.
- Supabase production review completed read-only: 66 public tables report RLS enabled; six previously sensitive tables have explicit policies; current Edge Function versions/JWT flags were recorded. Advisor findings are not blindly changed: one SECURITY DEFINER view, 198 authenticated-callable SECURITY DEFINER functions, leaked-password protection disabled, 44 RLS initplan, 50 multiple-permissive-policy, and 79 unused-index findings remain for controlled remediation.
- The teams_public view's current definer behavior may be intentional for team discovery, while the base teams RLS SELECT policy limits rows to captain/member/admin. Switching it to invoker semantics without a reviewed public discovery policy could hide teams from players. This requires an explicit product/security decision and a migration plan; no production database mutation was made.
- This remains source implementation only. No analyzer, tests, CI, device validation, database DDL, Edge Function deployment, or APK build was run. All 44 rules remain runtime-pending.


## Auth compact-layout and lifecycle follow-up — 2026-11-01

- RootScreen's initState post-frame callback now checks mounted before reading AuthProvider, closing a second deferred-context lifecycle edge.
- Signup auto-location now checks mounted before its initial setState/Provider access, not only in finally.
- Verify-email OTP digit boxes now calculate width from the available viewport; the previous fixed 46dp boxes plus margins exceeded the 312dp content width on a 360dp device before any text scaling. The new width is responsive (32–46dp) and preserves the default 46dp on wider screens.
- No analyzer, tests, CI, runtime/device validation, or APK build was run.

- Follow-up: VerifyEmailScreen now guards `_verify()` against duplicate submissions while a previous OTP verification request is in flight; this covers repeated final-digit/paste callbacks. Source-only, not runtime-tested.


## Player and owner booking loading-state consolidation — 2026-11-01

- Player bookings: replaced the raw initial circular spinner with `VSPStateView(state: loading)` and concise Arabic/English title/message. Existing error and empty branches are preserved.
- Owner bookings: replaced all three raw loading spinners (owner-scope initialization, stadium fetch, and booking fetch) with the same shared bilingual state component. Existing retry/error and no-stadium empty branches are preserved.
- No database behavior or booking business rules were changed. No tests, analyzer, CI, device validation, or APK build was run.


## Owner payout and tournament confirmation refinements — 2026-11-01

- Owner payout password verification now guards the handler itself against concurrent submissions, including keyboard `onSubmitted` events that can fire independently of the disabled button.
- Tournament governorate confirmation no longer displays literal square brackets around the interpolated governorate name in Arabic or English.
- These are source-level fixes only; no analyzer, tests, CI, device validation, or APK build was run.

- Private collective-invite bottom sheet: replaced the unlabeled fixed-height spinner with the shared Arabic/English loading state while retaining the scroll-controlled, `useSafeArea` modal route and existing retry/error behavior.

- Global search: replaced the raw progress spinner with the shared Arabic/English loading state. Search repository calls, request-generation stale-result protection, and existing retry/error handling were not changed.

- Email verification: added explicit exception recovery for both OTP verification and resend. Previously an unexpected thrown error could leave `_isVerifying` or `_isResending` true indefinitely; now controls recover with localized retry guidance. A local secure-storage cleanup failure after server verification is logged without converting successful verification into a false failure.

- Profile team card: replaced its remaining page-level bare spinner with the shared Arabic/English loading state. The existing FutureBuilder error branch continues to expose a retry action and avoids presenting an unverified empty-team state.

- Challenge code lookup: added a handler-level duplicate-request guard (in addition to the disabled button state) and raised the lookup action from 46dp to the 48dp minimum. Code validation and repository behavior are unchanged.

- Profile team-card sharing: validate that the card still has a render boundary and that PNG encoding returns data; always dispose the temporary `ui.Image` after encoding, including the encoding-failure path. Share payload and user-facing success/failure behavior are unchanged.


## Consolidated player/owner loading-state pass — 2026-11-01

- Owner facility onboarding and championship list now use the shared Arabic/English loading state instead of an unlabeled full-page spinner.
- Owner inbox and subscription-plan retrieval now show localized loading title and context while preserving existing retry/error branches.
- Tournament bracket loading, match details, and live matchup loading now use the shared state component inside their existing safe-area layouts.
- Support ticket details and message streams, the support-ticket list, team profile, My Team, and notification preferences now use localized shared loading states rather than raw page-level spinners.
- This pass changes presentation only: repository queries, booking/tournament permissions, payment behavior, stream lifecycles, and retry handlers are unchanged. Inline action/image progress indicators remain intentionally compact.
- Source-level changes only. No analyzer, tests, CI, device validation, or APK build was run.

- Owner tournament dashboard dialogs: raised all eight explicitly 44dp `PrimaryButton` action targets to 48dp across unpaid-team confirmation, force-start, cancel, and destructive tournament dialogs. Dialogs remain scrollable; business decisions and action callbacks are unchanged.


## Public-match join request result handling and live Supabase review — 2026-11-01

- `MatchRepository.acceptJoinRequest` and `rejectJoinRequest` previously returned `true` whenever the RPC transport completed, even when the JSONB response explicitly contained `success: false`. Both now inspect the server result and return success only when `response['success'] == true`; unexpected exceptions are logged with stack traces and return false. This prevents false UI success and false participant-list updates.
- Live database read-only inspection confirms both RPCs return JSONB. `accept_join_request` authorizes only the booking creator/owner but does not currently verify that the target user is in `pending_user_ids` or absent from `joined_user_ids` before incrementing `current_players`. A second issue: the public-match card's “Cancel Request” action calls `reject_join_request`, but that RPC authorizes only the host/owner, not the requesting player; no self-cancel RPC currently exists. The button will now correctly surface failure instead of reporting a false cancellation.
- Required server remediation (not applied): add a caller-owned `cancel_public_match_join_request` RPC that checks `auth.uid() = p_user_id`, locks the booking, verifies an open-join booking and pending membership, removes only that caller from `pending_user_ids`, and leaves `current_players`/`joined_user_ids` unchanged; harden `accept_join_request` to require pending membership, reject already-joined IDs, and re-check capacity under the existing row lock. Exact SQL must be approved before any production migration.
- Current Supabase advisors still report one `SECURITY DEFINER` view error (`public.teams_public`), 198 authenticated-executable `SECURITY DEFINER` function warnings, 44 RLS initplan warnings, and 50 multiple-permissive-policy warnings. Read-only classification found 186 of the 198 exposed functions reference `auth.uid()`; the remaining 12 are helper/public/read-only/trigger paths or delegate to the admin guard and need call-site review, not blanket revocation. `team_members` SELECT is currently public by policy; this is consistent with public roster discovery but should be explicitly retained or narrowed as a product decision. No database DDL, grants, view options, or Edge Function deployments were changed.

- Player championship discovery: the collective-invite route, 1v1 league tournament/player streams, and championship list now use shared bilingual loading states with contextual messages; existing error/empty/retry branches are preserved.

- `teams_public` security-advisor context: migration review confirms the view was intentionally created as the authenticated team-discovery surface after raw `public.teams` SELECT was restricted to captain/member/admin. The view excludes `captain_phone` and `active_invite_code`; invite codes are exposed through a separate captain/admin-checked RPC. A blanket `security_invoker` change would make discovery obey the restrictive raw-table RLS and hide other teams. The advisor ERROR remains tracked, but a safe redesign must preserve public-safe directory discovery without reopening raw-table columns. No view or policy changes were applied.

- Player league/ranking surfaces: team-league membership and league loading, team rankings, and 1v1 standings now use shared bilingual loading states. Existing retry/error/empty branches and join/payment actions remain unchanged; compact submit-button spinners remain local.

- My Team screen: replaced the raw English-only `Not authenticated` fallback with a safe-area-protected, localized error state and clear sign-in recovery guidance.

- Dialog ergonomics: owner document-upload cancellation, add-stadium discard/delete, and Paymob still-waiting dialogs now give every explicit action a 48dp minimum height and padded tap target; scrollable content and action semantics remain unchanged.

- Chat report/delete dialogs: report form is now scrollable when the keyboard is open, and all four dialog actions use 48dp minimum height with padded tap targets. Report submission and conversation deletion behavior are unchanged.

- Owner tournament prize-delivery dialog: both cancel and confirm actions now have explicit 48dp minimum height and padded tap targets; its scrollable form and submission guard remain unchanged.


## RTL modal audit correction — 2026-11-01

- Reviewed the owner manual tournament-team sheet and found one physical-direction spacing value in its shared section-label helper: `EdgeInsets.only(left: 4)`. Replaced it with `EdgeInsetsDirectional.only(start: 4)` so the label inset mirrors correctly in Arabic RTL while preserving the same spacing in English LTR.
- No roster, team creation, registration, or tournament business logic changed. Source-only; visual RTL rendering remains pending the consolidated device pass. No tests, analyzer, CI, runtime checks, or APK build were run. Code commit: `4b16222200c65656b31664a127ec2a827376400e`.


## Additional RTL geometry corrections — 2026-11-01

- `lib/shared/widgets/vsp_date_picker_dialog.dart`: changed the asymmetric header inset from physical `EdgeInsets.fromLTRB(20, 18, 16, 14)` to `EdgeInsetsDirectional.fromSTEB(20, 18, 16, 14)`, preserving the intended leading/trailing spacing while mirroring it in Arabic.
- `lib/features/owner/widgets/tournament/tournament_manual_team_sheet.dart`: changed the manual-team section-label inset from physical `left: 4` to directional `start: 4`.
- These are layout-only corrections. Date selection and tournament roster behavior are unchanged. Runtime RTL/device verification remains pending; no tests, analyzer, CI, or APK build were run. Code commits: `5a2ebddf816be23f4bebb8e9041910471e8863a6`, `4b16222200c65656b31664a127ec2a827376400e`.


## Team League result-sheet single-flight guard — 2026-11-01

- `lib/features/player/widgets/league/team_league_match_dialog.dart`: `_submit()` now returns immediately when a save is already in flight; result-choice controls are disabled during submission so the selected outcome cannot be changed while the request is pending. The existing loading feedback, repository callback, and localized error recovery are preserved.
- No match eligibility, scoring, result authority, or persistence rules changed. Source-only; final device interaction validation remains pending. No tests, analyzer, CI, runtime checks, or APK build were run. Code commit: `65f2b72a6a97ec164fdab89873030c9fc05586cb`.


## Tournament score submission guard — 2026-11-01

- `lib/features/owner/widgets/brackets/tournament_score_modal.dart`: added a handler-level `isSubmitting` guard before starting the score-save operation. This complements the existing loading button state and prevents repeated callback entry from issuing duplicate score/result writes.
- Score calculations, winner selection, goal details, audit logging, and repository calls are unchanged. Source-only; runtime validation remains pending. No tests, analyzer, CI, or APK build were run. Code commit: `4afbab98c7a1119e2525fa3ee2d98727cf349720`.


## Live ACL recheck — Team League fixture generator — 2026-11-01

- A fresh read-only Supabase ACL query now confirms `generate_team_league_fixtures(uuid)` has EXECUTE only for `postgres` and `service_role`; both `anon` and `authenticated` return false. `confirm_team_league_payment(...)` is likewise service-role-only. The helper is invoked internally by the SECURITY DEFINER payment-confirmation path and by `join_team_league(...)`; the latter checks captain identity and an open registration before adding a team, while fixture generation occurs only when the paid-team count reaches the league maximum.
- Therefore the historical TL-03 direct authenticated fixture-regeneration exposure is closed in the live ACL and should not be treated as an outstanding client RPC exposure. This recheck did not alter SQL, grants, migrations, or data. Residual helper invariants remain defense-in-depth; TL-01 (booking/kickoff checks in result submission) and TL-02 (participant authorization on active-league reads) remain open and approval-required. The separate tournament-participation helper exposure remains under review.


## Shared skeleton RTL correction and component inventory expansion — 2026-11-01

- `lib/core/widgets/skeleton_loader.dart`: `CardSkeleton` now uses `EdgeInsetsDirectional.only(end: 16)` instead of a physical right margin, so horizontal card spacing follows the active reading direction.
- Expanded `docs/UXLP_44_SCREEN_REGISTER.md` with ten previously unregistered shared/auth embedded UI components: shimmer image, skeleton loader, login/social-auth rows, owner payout info card, signup name/governorate controls, welcome button/language control, and onboarding slide. Their integration/runtime behavior remains pending; this does not imply full embedded-widget coverage.
- Code commit: `daf2ee216966e7fb3ebea28858c5a1058370c128`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Owner embedded-component RTL cleanup — 2026-11-01

- `owner_payout_settings_card.dart` and `owner_profile_form.dart`: label/help-text insets now use directional `start` rather than physical `left`.
- `owner_stadiums_carousel.dart`: both horizontal card gaps now use directional `end` rather than physical `right`.
- `add_stadium_step1_details.dart`: note-template chip spacing now uses directional `end` rather than physical `right`.
- Registered these owner components plus owner avatar/delete/payout cards, add-stadium hours/location sections, and the two Copilot conversation/message widgets for explicit caller-level review. No payout, profile, stadium, geolocation, Copilot permission, or data behavior changed.
- Code commits: `0a5d7a360eab02616241d4be756710d7a82712ec`, `e3ba1d2d331741b4c25fd3c9761c5dfca8b7d386`, `4c88bb9e4dfb18933e5f81f343f9b8b1b1f46e79`, `1df1e3239ad5fad3912f5f666e782a25b53e7891`. Source-only; no tests, analyzer, CI, runtime checks, or APK build were run.


## Owner dashboard and stadium-wizard RTL pass — 2026-11-01

- `lib/features/owner/widgets/dashboard/insights/insights_top_filters_row.dart`: both selected-value dropdown alignments now use `AlignmentDirectional.centerEnd` instead of physical `Alignment.centerRight`, so the displayed filter value follows RTL/LTR reading direction.
- Added ten previously unregistered owner embedded components to the coverage register: stadium feature/image/step-indicator widgets, tournament champion banner, booking/revenue/KPI insight cards and grid, top filters, and basic financial glance. Their underlying Supabase data, caller integration, and runtime behavior remain pending individual review.
- Code commit: `e54b53d957dbc27fb894eed8007de70879867f7e`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Owner dashboard timeline/filter RTL pass and component coverage — 2026-11-01

- `owner_glanceable_timeline.dart`: ongoing-status marker now uses directional end margin so the dot-to-time gap follows reading direction.
- `owner_time_period_dropdown.dart`: selected period label now uses `AlignmentDirectional.centerEnd` rather than physical right alignment.
- Added ten more embedded owner components to the register: timeline, operational finance, PRO insights/overview/segmented tabs, period dropdown, today's pitch schedule, venue filters, verification/subscription banners, and document explanation card. Their real-data mapping, entitlement states, and runtime behavior remain pending caller-level review.
- Code commits: `23c400d1b5e20981df5e6d921f700a5a9e43e672`, `55118920b49738ef0c3fce29ab0edd6fbc3f2384`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Owner quick-booking duration RTL correction and embedded inventory — 2026-11-01

- `lib/features/owner/widgets/quick_booking/quick_booking_duration_section.dart`: compact duration chips now use a directional start inset for the gap between options, replacing locale-branching physical left/right padding; the horizontally scrollable duration list also uses directional start spacing.
- Added ten visible owner components to the register: three document-upload steps and their step indicator, ledger balance cards, quick-booking customer/duration/payment sections, and owner cup card/empty state. Their actual data, upload recovery, payment-state mapping, and runtime behavior remain pending caller-level verification.
- Code commit: `bae0250fadc563e53baf9096889f266dc7086147`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Manual tournament team options RTL and embedded surfaces — 2026-11-01

- `lib/features/owner/widgets/tournament/tournament_manual_team_options_section.dart`: section-label inset now uses directional `start`; color-option chip spacing now uses directional `end`. This mirrors the labels and palette gaps in Arabic RTL without changing team creation or color selection.
- Added nine embedded UI components to the register: draw-room matchup tile, manual team options/roster, tournament overview/team cards, booking financial summary, guest-player checkout section, and chat title/system banner. Their server-data mapping, eligibility and runtime states remain pending caller-level review.
- Code commit: `80a542547d524d9a534ed1fa441d2fe7a9f2bbcc`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Player filter/home/team embedded component coverage — 2026-11-01

- Added ten player UI components to the explicit register: six filter panels/sidebar, home booking CTA and feed composition, matchup result card, and team achievements section. The source review identified no confirmed physical left/right padding or alignment defect in this group; filter/query mapping, live data, empty/error behavior, and runtime Arabic/English layout remain pending caller-level review.
- No application source changes were needed in this group. No tests, analyzer, CI, runtime checks, or APK build were run.


## Stadium review-stream recovery and player embedded-component coverage — 2026-11-01

- `lib/features/player/widgets/stadium_details/stadium_ratings_tab.dart`: the initial review stream no longer shows an unlabeled spinner; it uses the shared bilingual loading state. A first-load stream error now has a distinct localized error state and retry action that recreates the stream instead of incorrectly presenting “no reviews.” Existing reviews remain visible when a later stream event fails after data has loaded.
- Added ten player embedded components to the register: team actions/profile/stats, Paymob web fallback, tournament roster capacity/members/header, and stadium booking bar/conditions/ratings. Their caller eligibility, payment reconciliation, real data, and device behavior remain pending.
- Code commit: `25c7df59fb04bc785f49b45a08784e417a55b5a7`. No tests, analyzer, CI, runtime checks, or APK build were run.


## Player team-profile and reschedule component coverage — 2026-11-01

- Registered eight player embedded components: team achievements, action bar, captain card, head-to-head, hero header, roster section, stats grid, and reschedule action banner. Source review confirmed that the roster section distinguishes loading/error/empty and accepts a retry callback; the action-bar and reschedule progress indicators are compact in-action feedback rather than page-level loading states. Role/data/eligibility and device behavior remain pending.
- No application source change was required in this subset. No tests, analyzer, CI, runtime checks, or APK build were run.


## Owner inbox/ledger/tournament and shared date-picker component inventory — 2026-11-01

- Added nine visible embedded components to the register: owner chat row/search, ledger transaction row, tournament bracket canvas, cup filters/tabs, checkout team-member list, payment background decoration, and shared date-picker step chip. Their data/interaction/runtime behavior remains pending explicit caller-level verification. `tournament_bracket_builder.dart` was reviewed as a builder/helper without a Widget subclass and was not misclassified as a standalone UI surface.
- No application source change was required in this subset. No tests, analyzer, CI, runtime checks, or APK build were run.


## Shared refund-status component inventory — 2026-11-01

- Added the canonical `RefundBadgeWidget` and `RefundNoticeWidget` in `lib/widgets/` to the embedded-component register. The player feature-path files are compatibility exports, not separate UI implementations. Source review confirms localized status/ETA/amount copy; actual refund lifecycle and runtime amount consistency remain pending.
- No application source change was required. No tests, analyzer, CI, runtime checks, or APK build were run.


## Stadium reviews stale-data recovery — 2026-11-01

- Follow-up to `stadium_ratings_tab.dart`: when a review stream refresh fails after reviews have loaded, the list now retains the last loaded reviews and shows a localized stale-data warning with a 48dp Retry action. Retry recreates the stream; it does not clear the visible review snapshot first.
- No review submission, rating calculation, or database query behavior changed. Source-only; runtime/device verification remains pending. No tests, analyzer, CI, or APK build were run. Code commit: `bbb50fe27acf70b0e87f11fb0614616105a30e3a`.


## Stadium feature form directional alignment — 2026-11-01

- `lib/features/owner/widgets/add_stadium/add_stadium_step2_features.dart`: amenities section heading now uses `AlignmentDirectional.centerStart` rather than a locale-specific physical left/right ternary, keeping alignment tied to reading direction.
- No feature selection or stadium persistence behavior changed. Source-only; no tests, analyzer, CI, runtime checks, or APK build were run. Code commit: `4a03894df24e97a65ad20399778a0ba941d45d01`.


## Owner stadium save recovery and payment callback hardening — 2026-11-01

- `stadium_wizard_submit_service.dart` previously placed the stadium database write and subsequent owner-profile synchronization in one catch boundary. If `createStadium`/`updateStadium` succeeded but `updateOnboardingConfirmed`, `updateProfile`, or `refreshProfile` failed, the user was shown a generic stadium-save failure even though the stadium had already persisted. This could prompt a duplicate retry. The post-save synchronization now has its own recovery boundary; the wizard reports the persisted stadium and a localized profile-sync warning instead of falsely reporting a failed save. The default stadium usage note and blocked/auth-expired messages are also bilingual. Code commit: `12fd50c0c2796eaf9a1d04c8f7203c4092baa0f2`.
- `paymob_callback_url_parser.dart` previously trusted URL substring matches and treated `/payment-status` or `standalone` anywhere in the URL as success. A non-Paymob host/path could therefore trigger a client-side success return without an explicit approved status. Parsing now validates HTTP(S), exact trusted payment host boundaries (including legitimate subdomains), recognized callback paths, and explicit status query values; 3DS/bank redirects remain pending for DB polling. Code commits: `9a892d2802749b40fe9caae6c8c552b27811e420`, `ab16b37788019229271e6533112fd8f56866e038`.
- These are source-level recovery/security corrections only. No payment/refund business rules, provider credentials, database grants, or server-side settlement logic were changed. No tests, analyzer, CI, device checks, or APK build were run; payment-provider redirect variants still require the consolidated final validation pass.


## Booking break intervals and manual tournament captain identity — 2026-11-01

- `booking_slot_calculator.dart` previously read only the legacy singular `features.breakTime` shape although the current stadium wizard persists multiple breaks in `features.breakTimes`. Slots overlapping secondary breaks could therefore still be offered. It now parses all valid configured break intervals and excludes any overlapping 30-minute slot; the legacy single-break shape remains supported when no valid list is present. Code commit: `ad63bcde1d8adb0dd2b2341dbc0a00c995015fc9`.
- `tournament_manual_team_service.dart` previously substituted a hard-coded UUID when `currentUserId` was empty, creating a manual tournament team with a fictitious captain/member identity. It now rejects missing captain identity and blank team names before creating a team, and uses only the authenticated caller ID. Code commit: `f71ab319a8406b1204f1f8a914037212aaca89ab`.
- No booking pricing, payment, tournament eligibility, or roster-count rules changed. Manual registration still relies on repository/server authorization and its multi-write consistency remains subject to separate review. No tests/analyzer/CI/device/APK run was performed.


## Stadium image edit safety and upload lifecycle — 2026-11-01

- Existing stadium images loaded for edit are now tagged `isNewUpload: false`; images restored from an unsaved local draft and images uploaded during the current wizard are tagged `isNewUpload: true`. `deleteImage` only deletes Storage objects tagged as new uploads. This prevents cancelling an edit after removing an existing photo from leaving the still-persisted stadium record pointing at a deleted object. Removed existing images may remain orphaned in Storage after a successful save; post-save orphan cleanup is still a separate follow-up, intentionally preferring an unused object over a broken persisted image.
- Upload progress callbacks now check `context.mounted` before invoking the screen's state callback, preventing a periodic upload-progress tick from calling `setState` after the wizard has been disposed.
- Code commits: `a000c8bef250d657f2666fecabc9ec223e9d7174`, `ce6cd9b64d420dae418affff601c0cfcea23f671`, `a6aa869f79ad6044c5dd88df75761ff2a09b5430`, `72611e0f585c604faa1a26b9af5a7c6633947826`, `ca0b166a88c3b54d020bdaa514065e80ef38d467`. No tests, analyzer, CI, device checks, or APK build were run.


## Owner schedule parity and team account guard — 2026-11-01

- `owner_schedule_slots_builder.dart` previously displayed only the model's legacy single break range and tested only the slot start minute. It now reads all `features.breakTimes` intervals, normalizes overnight intervals against the operational opening time, and marks any 30-minute slot overlapping a break as unavailable. The legacy `breakStartTime`/`breakEndTime` model fields remain the fallback for older records. This brings owner schedule display in line with player slot generation. Code commit: `e2b9d89fe88832916687891d65c1cc582e29c14e`.
- `my_team_controller.dart` no longer uses the synthetic storage owner ID `unknown` when a team update is attempted without a loaded user. It stops with localized authentication feedback before uploading or persisting. Manual tournament team names are trimmed before insertion. Code commits: `fd471aa4d34811736db5cce75e92fadf8ec89d94`, `17f726489e79fe485b9476f5aa97fae8da69c4ca`.
- No server authorization or roster policies were modified. Source-only; final device/flow validation remains pending. No tests, analyzer, CI, or APK build were run.


## Tournament wizard numeric validation — 2026-11-01

- `tournament_wizard_coordinator.dart` previously checked only that fee/prize fields were non-empty, while payload construction converted invalid numeric text to `0.0`. It now validates both values as finite, non-negative numbers and returns localized field-specific guidance before submission. Zero remains allowed for free entry/no-prize configurations; no commercial pricing policy was changed. Code commit: `322bebf5f2ee1a8ba4c5b2a00d0ef755245db8cb`. No tests/analyzer/CI/device/APK run.


## Active cash-booking policy fail-closed correction — 2026-11-01

- `booking_confirmation_handler.dart` previously used `getUserBookingsDirectly`, whose documented compatibility behavior catches query failures and returns an empty list. That read gates the rule requiring full online payment when the player already has an active unpaid cash booking. A transient Supabase read failure could therefore be mistaken for no active cash booking and incorrectly expose cash payment. The handler now uses `getUserBookingsDirectlyStrict`; on read failure it logs the diagnostic, clears the loading state, shows localized retry guidance, and stops before payment routing. Code commit: `e720c7f239ea2e0d0b36ed2dc583345babd92375`. No payment rule changed; this enforces the existing rule fail-closed. No tests/analyzer/CI/device/APK run.


## Tournament rescheduling lock boundary — 2026-11-01

- `TournamentRoundScheduleCalculator.isRoundLocked` documented that a round becomes immutable once a match starts, but previously only checked `winnerId` and `homeScore`. A scheduled match could therefore be auto-rescheduled after kickoff if no score had yet been entered; an away-only partial score was also missed. The guard now checks both score fields, winner, and `scheduledTime <= referenceTime`; optional `now` supports deterministic boundary checks. Code commit: `5b5da6ff87b08d9e686fdb0dfb0a40b861b65d39`. Existing unit tests were inspected but not executed, per the agreed final-only validation policy.


## Player tournament roster loading state — 2026-11-01

- `manage_tournament_roster_screen.dart` replaced its unlabelled full-screen spinner with the shared bilingual loading state and a concise explanation that team/tournament data is being loaded before editing controls appear. The existing explicit load-error message and retry action remain unchanged. Code commit: `bf9f553b2a6e9cbe928d4449afe998be80b630bf`. Source-only; no tests/analyzer/CI/device/APK run.


- Additional booking boundary correction: `BookingSlotCalculator.generateDynamicTimeSlots` now requires `slotStart + 30 <= closingMinutes`; when operating hours end between half-hour boundaries, the incomplete tail is not offered as a 30-minute booking. Code commit: `bc3ec06696bdad970a39435becd1a093f3b00d3c`.


- Follow-up to owner/player schedule parity: `OwnerScheduleSlotsBuilder.generateRawSlots` previously reduced opening/closing times to whole hours, starting every schedule at `HH:00` and allowing the final displayed slot to extend past a closing time with non-zero minutes. It now builds an operational-minute timeline from the exact stored times, supports overnight/24-hour windows, and emits only complete 30-minute intervals ending at or before closing. Break intervals use the same operational-minute basis. Code commit: `2056a51b46002abbc40130ffaf819e5c3062de35`.


## Shared modal and sheet RTL pass — 2026-11-01

- Converted owner booking-duration chip spacing from physical `right` to directional `end`; converted the collective-invite header inset and terms/privacy modal header inset to directional start/end geometry; converted both participant-modal section headings from `Alignment.centerLeft` to `AlignmentDirectional.centerStart`. The changes preserve the authored LTR geometry while mirroring the leading edge in Arabic. Code commits: `8eeb2fba641d66867b111809e0f056877cd39383`, `050c4a9a073cfbf755fc61ed7a52f1e63474ff90`, `331d1f3bc78d67dbb7d94948e743d4b7b71f87a2`, `b6eb92608de0873b1cf1b24cbef39850fd653e4c`.
- Reviewed the 64 Dart paths named for dialogs/sheets/modals in the current tree. Modal entry points found in this pass use `useSafeArea: true` or an explicit `SafeArea` at the sheet root; several files are content builders invoked by those entry points. This is a source-level pattern check, not proof of every runtime inset/keyboard combination.


- Safe-area audit found the Add Player sheet was opened scroll-controlled without `useSafeArea`, and the sheet root itself had no top SafeArea. The caller now sets `useSafeArea: true`; its existing keyboard-aware scroll and bottom inset remain unchanged. Code commit: `c8d23b63b58feec37065412e496187c021e5e909`. No device/keyboard validation run.


## Stadium wizard numeric and bilingual validation — 2026-11-01

- `StadiumWizardValidator.validateStep0` previously checked only that the hourly price was non-empty; malformed text could later be converted to `0.0` in the payload. It now requires a finite non-negative numeric value. Step 1 similarly rejects non-finite/invalid ball-rental values when ball rental is enabled and rejects non-finite or non-positive deposits. Existing deposit cap behavior (50% of hourly price when price is positive) remains unchanged.
- `validateStep2` now receives the current locale and displays a bilingual message while images are uploading instead of always showing English. Updated caller in `add_stadium_wizard.dart`. Code commits: `101c7ddb214485930be7ef65e84d95171a6af534`, `4d37c62faef5b6648c82cf81b8c01880ac2f3659`. No tests/analyzer/CI/device/APK run.


## Team create/update post-write recovery — 2026-11-01

- `MyTeamController.handleCreateTeam` previously awaited `reloadTeam()` inside the same try block as `createTeam`; a refresh failure after a successful DB insert fell into the generic error path and could prompt a duplicate team creation. Refresh now has a separate recovery boundary and the user receives a truthful localized message that the team exists but the view needs reopening. Create/update also stop before database writes when the user selected a logo but its upload returned no URL, avoiding silent success with a missing requested logo. Code commit: `36fbb8c1aab659a0ac93afb36a4488ecac53b02e`. No tests/analyzer/CI/device/APK run.


## Password-strength scoring and owner-dashboard request ordering — 2026-11-01

- `SignupValidationService.calculatePasswordStrength` previously awarded the same 0.2 points twice for `password.length >= 8`, while lowercase letters had no independent contribution. The duplicate condition is now a lowercase-letter check, so the five criteria are distinct and the score remains bounded by 1.0. Code commit: `df07c01dca6597173cef41bf26fecb1eea1fe395`.
- `OwnerDashboardController.loadDashboardData` now discards stale success/error completions when a newer filter request has started. Disposal invalidates pending requests and prevents late asynchronous completions from notifying listeners. Code commit: `d0272b1fe31f2dc09633d229b502e75148b4e1f6`.
- No analyzer, tests, CI, runtime/device checks, or APK build were run.


## Payment status polling single-flight protection — 2026-11-01

- The periodic booking and tournament-order pollers used `Timer.periodic` with asynchronous callbacks. If a network read took longer than the interval, later ticks could overlap and multiple callbacks could observe the same successful payment. Both pollers now skip ticks while a read is in flight and latch the first confirmed result before invoking the completion callback. Code commit: `7abc2ff0d1d31af67aa74c65b8017771a7890fd0`. No tests/analyzer/CI/device/APK run.


## Book Tonight load failure recovery — 2026-11-01

- `BookTonightSheet._loadTonightSlots` previously allowed a repository/network exception to escape the async callback, leaving `_isLoading` true with no visible recovery action. It now catches and logs the failure, presents a bilingual shared error state with retry, and uses an in-flight guard to prevent duplicate reload requests. The loading branch also uses the shared `VSPStateView`. Code commits: `428c90f846a6874672893fe8a7a6e993683d78cc`, `289e68e7557290533d95f0f415571ef0eb3b901d`. No analyzer/tests/CI/device/APK run.


## Signup password-strength localization — 2026-11-01

- The signup password-strength meter previously displayed English-only labels in Arabic mode. `calculatePasswordStrength` now accepts the active locale and returns localized Weak/Medium/Strong labels; the widget supplies the current locale. Code commits: `3ff184467582f733dad5a2e1753621e20f407d34`, `008346d1aa2636a1809612558ed49cda97ba046e`. No tests/analyzer/CI/device/APK run.


## Signup asynchronous failure recovery — 2026-11-01

- `SignupScreen._handleSignup` previously allowed an unexpected `AuthProvider.signUp` exception or a secure-storage write failure after successful account creation to escape before `_isLoading` was reset. Auth exceptions now receive localized retry guidance; post-signup storage failures are logged and explicitly reported as an account that was created, avoiding a misleading invitation to register again. The loading state is released on both paths. Code commit: `9ae0f80395b00ac32c51fc27e281d64a14a6f2d5`. No tests/analyzer/CI/device/APK run.


- Follow-up hardening: both payment pollers now carry a generation token checked after each awaited status read. Replacing/cancelling a poll or releasing checkout invalidates outstanding reads, preventing a late response from a previous checkout from firing its success callback. Code commit: `2ab5ead3671871e3e12a80a513209749fd7fc7ff`. Runtime cancellation/race validation remains pending.


## Owner championship refresh ordering — 2026-11-01

- The owner dashboard could receive overlapping championship refreshes from initial scope setup, pull-to-refresh, home visibility, and retry. A request-generation guard now prevents an older fetch/error from overwriting the latest result, and owner-scope changes invalidate outstanding requests. Code commit: `56dc2ef543c7991539a77c6b47f8742b939c42f2`. No tests/analyzer/CI/device/APK run.


## Owner approval notice account-switch race — 2026-11-01

- `owner_dashboard_screen.dart`: approval-notice claim responses are now scoped to the authenticated owner and the active owner-scope generation. If the account changes while a claim request is in flight, its late response is ignored and cannot repopulate the next owner's local notice state. The owner ID is passed explicitly into the claim routine; request errors remain diagnostic-only because the dashboard already has the championship refresh recovery path.
- Source-only correction. No RPC signature, database policy, notification retention, business rule, analyzer, tests, CI, runtime checks, or APK build was changed/run.


## Supabase read-only runtime review — 2026-11-01

- Added `docs/UXLP_44_SUPABASE_RUNTIME_REVIEW.md` with live advisor/catalog/log evidence. Confirmed `public.teams_public` is still a SECURITY DEFINER view (`reloptions IS NULL`) with authenticated SELECT while base `teams` RLS is captain/member/admin scoped. Visibility semantics must be confirmed before changing it.
- Security advisors: 198 authenticated-executable SECURITY DEFINER functions (requires function-by-function authorization review), one leaked-password-protection warning; performance advisors: 44 RLS initplan, 79 unused-index, and 50 multiple-permissive-policy findings.
- Last 24h: 79 explicit PostgREST Warp timeout messages among 136 error-like PostgREST events; Postgres and Edge log scans returned no error-like events. Warp entries expose only generic path `/`, so caller/RPC root cause is not attributable from current logs.
- No SQL, RLS, migration, or Edge Function deployment was performed; exact remediation is approval-gated.

## Add-player lookup concurrency and lifecycle follow-up — 2026-11-01

- `add_player_sheet.dart`: added a monotonically increasing search generation so an older phone lookup cannot overwrite a newer search or the current account's result.
- A stale completion caused by a changed phone/account now releases only its own loading state when it is still the active request; stale errors cannot clear a newer request's spinner or display misleading feedback.
- The phone controller is disposed and pending generations are invalidated when the sheet is disposed.
- Source commits: `b796c2502c973d260954b5a802df462faef67625`, `093b36be40ba3c74dae5787effe81f0fa0cd02a5`.
- No analyzer, tests, CI, runtime/device checks, database changes, or APK build were run.

## Owner Copilot send failure recovery — 2026-11-01

- `vsp_copilot_sheet.dart`: a failed Edge Function/network request previously escaped the send handler and could leave the composer permanently in its loading state. The UI now catches the failure, appends a localized retry message, restores the composer, and keeps the conversation visible.
- Source commit: `aef552d6ef07fd99f07abe8b5b31ea65e764c333`.
- No analyzer, tests, CI, runtime/device checks, backend changes, or APK build were run.

## Team directory RLS remediation — 2026-11-01

- Confirmed from repository usage that `teams_public` is the authenticated team-discovery directory used by `TeamRepository`; team discovery must remain available to all signed-in players, while raw team rows were previously restricted to captains/members/admins.
- Replaced the SECURITY DEFINER view path with a SECURITY INVOKER view and an authenticated directory SELECT policy on `teams`.
- Removed table-level SELECT from `authenticated` and granted SELECT only on the public team profile/statistics columns. Explicitly revoked access to `captain_phone`, `active_invite_code`, and `invite_code_expires_at`.
- Changed the computed `team_members(public.teams_public)` relationship to SECURITY INVOKER and retained authenticated-only execution.
- Enabled `security_barrier` on the directory view and documented the public-column contract.
- Applied Supabase migrations: `harden_teams_public_directory_view`, `make_teams_public_view_security_invoker`, `limit_team_select_to_public_columns`.
- Verified live catalog: `teams_public` has `security_invoker=true` and `security_barrier=true`; sensitive-column SELECT privileges are false for all three fields; authenticated no longer has table-level SELECT on `teams`; the `security_definer_view` advisor finding is gone. The remaining 197 SECURITY DEFINER function warnings are a separate review queue and were not mass-modified.
- No app tests, analyzer, CI, or APK build were run.


## Booking confirmation and payment error recovery — 2026-11-01

- `booking_confirmation_handler.dart`: the pre-confirmation availability recheck previously checked only the first selected half-hour. Multi-slot bookings could therefore proceed when a later selected slot had become occupied. The recheck now validates every selected slot against the latest booking snapshot and blocks the submission if any one conflicts. The server-side atomic booking rule remains authoritative.
- `booking_provider.dart`: payment-status repository exceptions previously escaped from the provider. They are now logged for diagnostics, mapped to a safe failure result, and notify listeners so owner cash-confirmation UI can exit its loading state and show its existing localized retry feedback.
- Source commits: `c7469c7291df82d43a12ec57bb14ea9345395dc1`, `d246323b829ed59c81053b731b04056a3f49f86f`.
- No tests, analyzer, CI, device checks, or APK build were run.

- `owner_quick_cash_card.dart`: replaced the single in-flight booking ID with a per-booking set. Confirming one cash booking no longer overwrites another row's loading indicator or allows duplicate taps on the same booking; each row releases only its own in-flight state. Source commit: `c5e339451d8e5e8672e651c3f168fe386c60cb1b`.


## Booking payment-policy and bilingual fallback follow-up — 2026-11-01

- `booking_confirmation_handler.dart`: location-verification exceptions now produce a localized explanation when cash booking is restricted, rather than silently passing a null reason to the payment sheet. The active-unpaid-cash-booking notice is now localized in both Arabic and English.
- `booking_payment_method_sheet.dart`: when a stadium requires an online deposit but the online-payment feature is disabled, the sheet previously fell through to the cash-payment branch. It now blocks confirmation with a localized explanation; a required deposit can no longer be bypassed through the client UI.
- Source commits: `a3ad428826aa1f03e120fffff163f3401ef99cb8`, `3f35b105b4d14f5fa6154fb8bd05e6d81d48eda8`.
- No tests, analyzer, CI, device checks, or APK build were run.


## Checkout feature-flag enforcement — 2026-11-01

- `payment_gateway_screen.dart`: the online-payment Remote Config flag is now enforced inside the checkout screen itself, not only in the payment-method sheet. This closes direct-route paths (such as forced online payment) that could otherwise bypass the flag. The checkout CTA is disabled with a localized explanation while online payment is off, and the action rechecks the flag before requesting a Paymob intention.
- Source commit: `ba2e08b20e661b15b7d4b2cdb28dccb3484f8f39`.
- No tests, analyzer, CI, device checks, or APK build were run.

- Follow-up: checkout initialization now checks the same flag before starting timers, loading fee data, or creating a pending booking. When online payment is disabled, the screen explains that no temporary booking/slot was created and offers a safe return path. Source commit: `8e7e0928745182928e3f04e6e6c317d105bef541`.

- Account-lifecycle follow-up: if the authenticated account changes (or the checkout screen is disposed) while the initial pending-booking request is in flight, the returned pending lock is now released instead of being orphaned outside the active screen. Source commit: `4c3e3169290864b83091f0fb0def8f3f0a42d3fd`.


## Overnight slot date consistency — 2026-11-01

- `booking_slot_calculator.dart`: slot generation already defaulted missing stadium hours to 4:00 PM–3:00 AM, but date resolution parsed missing hours as zero. After-midnight slots could therefore be attached to the wrong calendar day. Date resolution now uses the same fallback hours as slot generation.
- Source commit: `b660a3f9ae1dfe012a56c3d623c1a88ae6cec4b7`.
- No tests, analyzer, CI, device checks, or APK build were run.

- Follow-up: the same calculator now rejects malformed working-hour strings instead of silently parsing them as midnight. Invalid schedules produce no selectable slots, and direct date resolution fails explicitly rather than assigning a fabricated time. Source commit: `d802dd922e773e0c9fdc93830a2b757ad8dc9163` (helper section corrected in `31b6eb61b3e4c92d9f7b603e99e776bae99c0398`).


## Remote feature-flag snapshot consistency — 2026-11-01

- `remote_config_service.dart`: realtime config parsing previously merged each incoming feature map into the existing map without clearing removed keys. A flag deleted from Supabase could therefore retain its previous value indefinitely on connected clients. Parsing now replaces the dynamic feature snapshot before applying the latest row; built-in 1v1/Copilot flags are then re-derived from their canonical columns as before.
- Source commit: `20f33b46ed238e17236320b03303d67c882a36e8`.
- No tests, analyzer, CI, device checks, or APK build were run.

- Break-time validation follow-up: both the current multi-break schema and legacy single-break shape now validate start/end strings before parsing. Malformed break schedules fail closed to an empty slot list instead of being interpreted as midnight intervals. Source commits: `c99f1a3fc924d6e5ba7f00b81f6c0e84e6373dbe`, `414ce82870b27fc15410074802e9809aacb74848`.


## Booking draft restore race — 2026-11-01

- `booking_provider.dart`: an asynchronous SharedPreferences restore could complete after a newer draft had already been selected or edited, overwriting the current in-memory draft with stale persisted data. A generation guard now invalidates pending restores whenever a draft is set, updated, or cleared; a restore also refuses to replace an already-populated draft.
- Source commit: `f92e9735bd2b8dcf0adfc832295b1d3984708b28`.
- No tests, analyzer, CI, device checks, or APK build were run.

- Account-scope follow-up: player-to-player and player/owner scope transitions now invalidate pending draft restores, clear the prior in-memory draft, and await removal of the previous session's persisted draft before continuing. Source commits: `9da854d11bffb9ff3b032b6297307b8f1ca64415`, `c9bc98d8f0c00bf6cad5d1c3fd21776ddf66e384`, `4fd9cdf4fc851231ee210c965eaac72de3f8726e`.
