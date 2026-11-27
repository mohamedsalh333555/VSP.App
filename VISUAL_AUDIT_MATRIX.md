# VSP Visual Audit Matrix (Full Cross-Platform UI Quality)

**Date:** 2026-11-27  
**Branch:** `feat/unify-commission-paymob-fees`  
**Canonical Token Source:** `VSP.App/design-tokens.json` (synced via `scripts/sync_design_tokens.mjs`)

## 1. Shared Component Visual & State Matrix
| Component | Typography & Tokens | States (`Loading`/`Error`/`Empty`/`Disabled`) | RTL & LTR | Responsive (`320px–800px` @ `1.5x`) | Verification Evidence |
|---|---|---|---|---|---|
| `VSPPaymentSummaryCard` | `VSPDSSemanticColors`, `VSPDSSpacing`, `VSPDSRadius` | Ready / Paid / Pending | Verified | Verified (`Expanded` + `Flexible` + `FittedBox`) | Golden (`Linux CI 715/715`) + Widget tests |
| `PrimaryButton` | `VSPDSSemanticColors.accent`, `VSPDSizes.buttonHeight` (`56dp >= 48dp`) | Normal / Loading / Disabled / Debouncing | Verified | Verified | Golden (`Linux CI 715/715`) + Touch target test |
| `VSPStateView` | `VSPDSTypography`, `VSPDSSemanticColors` | `loading` / `empty` / `error` / `offline` / `pending` / `processing` / `success` / `disabled` | Verified | Verified | Golden + AR/EN widget tests |
| `PaymentBreakdownCard` | `VSPColors` (aliased to V2) | Explicit Loading + Error + Retry (no `0` fee fallback) | Verified | Verified | Widget & checkout flow guard |
| `OwnerDigitalBalanceCard` | `VSPColors`, `VSPRadius.card` | Available balance + upcoming revenue hint | Verified | Fixed `RenderFlex` overflow via `Expanded` | AR/EN widget tests (`360px` @ `1.3x`) |
| `StadiumCard` | `VSPColors.textSecondary`, `VSPColors.textMuted`, `VSPColors.surfaceAlt`, `VSPRadius.xs` | Pending approval / Active / Amenities | Verified | Verified | Code audit & full test suite |
| `DesignSystemShowcaseScreen` | `VSPDSSemanticColors`, `VSPDSSpacing`, `VSPDSRadius` | `ready` + all `VSPUiState` + `Long Text` + `1.0x/1.3x/1.6x` | Verified | Verified (`SafeArea` + `ListView`) | Interactive widget test (`1.6x` scale) |

## 2. Screen Group Audit (`58` `*_screen.dart` Files + Web + Admin)
| Surface / Area | Count / Files | Typography / Spacing / Color | Safe Areas & RTL | Live Device Screenshots |
|---|---:|---|---|---|
| Core Navigation (`VSP.App`) | 3 screens | `VSPDSSemanticColors` / `VSPColors` | Verified | `Not Tested` (no Android/iOS emulator attached) |
| Auth & Onboarding (`VSP.App`) | 10 screens | `VSPColors` + `AppRouter` recovery guard | Verified | `Not Tested` (no emulator attached) |
| Player Flow (`VSP.App`) | 33 screens | `VSPPaymentSummaryCard`, `VSPFinancialFormatter`, `NotificationsCenterScreen` RTL fix | 33/33 SafeArea protected | `Not Tested` (no emulator attached) |
| Owner Flow (`VSP.App`) | 11 screens | `OwnerLedgerScreen` tokens, `OwnerDigitalBalanceCard` overflow fix | 11/11 SafeArea protected | `Not Tested` (no emulator attached) |
| Dev Playground (`VSP.App`) | 1 screen (`kDebugMode`) | Full V2 tokens | `SafeArea` + AR/EN toggle | Verified via widget test |
| Website (`vsp_website`) | 17 Next.js routes | `VSP_GENERATED_TOKENS` (`src/styles/generated_tokens.ts`) | RTL/LTR CSS | `next build` + `27/27` tests |
| Admin Panel (`vsp_admin_panel`) | React + Vite + Tailwind | `generated_tokens.json` -> `tailwind.config.js` | Tailwind RTL | `vite build` + `54/54` tests |
