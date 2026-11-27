# VSP Shared Component Library Inventory

| Component | File | Purpose |
|---|---|---|
| `VSPScaffold` / `VSPSectionHeader` / `VSPStatusPill` / `VSPStateView` | `lib/core/ui/vsp_ui.dart` | Canonical V2 page shell, headers, status badges, and loading/empty/error/offline states |
| `PrimaryButton` | `lib/shared/widgets/primary_button.dart` | Standard 56px pill action button with loading & disabled states |
| `VSPPaymentSummaryCard` | `lib/shared/widgets/vsp_payment_summary_card.dart` | Unified server-driven financial breakdown (Base + 5% VSP + Paymob Fee = Total) |
| `VSPFinancialFormatter` | `lib/core/utils/vsp_financial_formatter.dart` | Centralized currency, date/time, and localized booking/payment status formatter |
| `DesignSystemShowcaseScreen` | `lib/features/dev/design_system_showcase_screen.dart` | Dev-only (`kDebugMode`) interactive gallery of tokens & components |
