# VSP Design System V2

## Source of truth

VSP has no external visual design-system artifact. Design System V2 is therefore reconstructed from the visual language already present in the Flutter application and promoted into a single canonical token/component layer.

The baseline is intentionally conservative:
- Dark Zinc surfaces are preserved.
- Volt Green remains the primary accent.
- Poppins and Tajawal remain the product fonts.
- Existing geometry and interaction values are promoted to tokens before screen migration.
- New values inferred because the existing system was incomplete are marked **[PROPOSED]**.

## Architecture

`Primitive → Semantic → Component → Pattern → Screen`

Feature code should consume semantic/component tokens and reusable components. Raw visual values belong only in the token layer.

## 14-part inventory

| # | Area | Current baseline | V2 status |
|---|---|---|---|
| 1 | Identity & principles | Dark-first sports UI, matte Zinc surfaces, Volt Green accent | Defined from current app; written principles are now centralized here |
| 2 | Colors | Background, surfaces, text hierarchy, accent, status, glass, borders, medals | Centralized in `VSPDSColors` + `VSPDSSemanticColors` |
| 3 | Typography | Poppins + Tajawal, existing 11–30px visual scale | Centralized in `VSPDSTypography`; component styles added |
| 4 | Radius | 4 / 8 / 16 / 24 / 32 / full | Centralized in `VSPDSRadius` |
| 5 | Borders | Divider/subtle/accent/focus language | Centralized in `VSPDSBorders` |
| 6 | Spacing & grid | Existing 4/8/12/16/20/24/32 rhythm plus an 8px grid | Canonical semantic scale in `VSPDSSpacing`; old values remain available only for compatibility |
| 7 | Elevation | Three shadow depths + modal elevation | Centralized in `VSPDSElevation` and component effects |
| 8 | Icons & imagery | Iconsax, cached/shimmer image treatment | Sizes standardized; full icon family audit remains in screen migration |
| 9 | Motion | Fade route transition and shimmer | Timings/easing centralized in `VSPDSMotion`; existing behavior retained |
| 10 | Opacity | Disabled/pressed/selected/glass values | Centralized in `VSPDSOpacity` |
| 11 | Components | A small shared component layer plus many feature-specific duplicates | Core shared primitives migrated first; full library migration ongoing |
| 12 | Component states | Loading/empty/error/disabled exist inconsistently | Canonical state primitives established; state matrix audit ongoing |
| 13 | Accessibility | Some semantic labels and touch sizing exist | DS hooks added for touch targets/focus/reduced motion; full audit ongoing |
| 14 | Governance & tokens | `vsp_tokens.dart` accumulated tokens and unrelated product constants | V2 is canonical; legacy layer is migration-only |

## Proposed gaps

The following are intentionally marked **[PROPOSED]** because the current app did not contain a complete authoritative definition:
- responsive breakpoints
- centralized motion durations beyond existing animations
- some interaction opacities
- complete focus-ring system
- full component state matrix
- Light/High-Contrast themes
- complete icon-family/grid rules

No new brand color or font has been introduced.

## Migration rule

During migration:
1. Preserve business logic, data access, navigation, and user-facing behavior.
2. Replace matching raw values with V2 tokens.
3. Replace duplicated primitives with canonical components.
4. Add missing visual system elements here before using them in a feature.
5. Do not add new tokens to the legacy `vsp_tokens.dart` layer.

## Current implementation batch

Migrated to V2:
- `lib/core/theme/app_theme.dart`
- `lib/core/ui/vsp_ui.dart`
- `lib/core/ui/components/vsp_button.dart`
- `lib/core/ui/components/vsp_card.dart`
- `lib/core/ui/components/vsp_menu_item.dart`
- `lib/core/ui/components/vsp_section_title.dart`
- `lib/shared/widgets/primary_button.dart`
- `lib/shared/widgets/vsp_bottom_nav_bar.dart`
- `lib/shared/widgets/vsp_empty_state.dart`

Added:
- `lib/core/ui/tokens/vsp_design_tokens.dart`

Not yet migrated:
- feature screens and feature-specific component trees
- all dialogs/bottom sheets
- full iconography/accessibility audit
- final zero-hardcoded-value verification
