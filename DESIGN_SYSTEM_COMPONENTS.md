# VSP Shared Component Library Inventory

| Component | File | Purpose |
|---|---|---|
| `VSPScaffold` / `VSPSectionHeader` / `VSPStatusPill` / `VSPStateView` | `lib/core/ui/vsp_ui.dart` | Canonical V2 page shell, headers, status badges, and all 8 UI states (`loading`/`empty`/`error`/`offline`/`pending`/`processing`/`success`/`disabled`) |
| `PrimaryButton` / `VSPAnimatedButton` | `lib/shared/widgets/primary_button.dart`, `vsp_animated_button.dart` | Standard 56dp pill CTA with loading, disabled, and debounce protection |
| `VSPPaymentSummaryCard` | `lib/shared/widgets/vsp_payment_summary_card.dart` | Unified server-driven financial breakdown (Base + 5% VSP + Paymob Fee = Total), overflow-safe at 320px–800px |
| `VSPEmptyState` / `VSPErrorState` | `lib/shared/widgets/vsp_empty_state.dart`, `vsp_error_state.dart` | Actionable empty and offline/server error states backed by `VSPStateView` & `VSPDesignTokens` |
| `StadiumCard` | `lib/shared/widgets/stadium_card.dart` | Unified stadium card using `VSPColors` semantic tokens & `VSPRadius` |
| `OwnerDigitalBalanceCard` | `lib/features/owner/widgets/ledger/owner_ledger_balance_cards.dart` | Owner net digital balance card with `Expanded` overflow protection |
| `VSPFinancialFormatter` | `lib/core/utils/vsp_financial_formatter.dart` | Centralized currency, date/time, and localized booking/payment status formatter |
| `DesignSystemShowcaseScreen` | `lib/features/dev/design_system_showcase_screen.dart` | Dev-only (`kDebugMode`) interactive playground (AR/EN, RTL/LTR, text scaling, UI states) |
| `VSPDSTypography` (`priceHero`, `priceCompact`, `numeric`) | `lib/core/ui/tokens/vsp_design_tokens.dart` | Tabular-figure typography styles for prices, totals, and counters |
