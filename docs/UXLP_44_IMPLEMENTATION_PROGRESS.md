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
