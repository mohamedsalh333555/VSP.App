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
