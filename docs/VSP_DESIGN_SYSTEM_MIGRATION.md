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
