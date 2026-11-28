# VSP Design System Guidelines

## Architecture
`Primitive Tokens (VSPDSColors)` -> `Semantic Tokens (VSPDSSemanticColors)` -> `Component Tokens (VSPDSRadius, VSPDSizes, VSPDSSpacing)` -> `Shared Components (vsp_ui.dart, lib/shared/widgets/)` -> `Screens`

## Mandatory Rules
1. **No raw `Color(0x...)` in feature/shared widgets:** Always use `VSPDSSemanticColors` (or `VSPColors` alias during migration).
2. **No raw backend strings in UI:** Always format booking/payment statuses through `VSPFinancialFormatter.localizeBookingStatus` / `localizePaymentStatus`.
3. **Currency & Numbers:** Use `VSPFinancialFormatter.formatCurrency(...)` (`ج.م` in Arabic, `EGP` in English) with `VSPTypography.numericStyle` / `Directionality(textDirection: TextDirection.ltr)` where needed.
4. **RTL & Accessibility:** Use `EdgeInsetsDirectional` / `AlignmentDirectional`, minimum touch target `48dp` (`VSPDSizes.touchTarget`), and avoid low-contrast muted text on dark surfaces.
