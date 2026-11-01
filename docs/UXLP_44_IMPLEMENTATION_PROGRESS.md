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
