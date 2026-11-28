# VSP Design System Migration Plan

1. **Phase 1 — Token Unification (`vsp_tokens.dart` -> `vsp_design_tokens.dart`):**
   - Replace duplicate `Color(0x...)`, `double`, and `BoxShadow` literals in `vsp_tokens.dart` with direct aliases to `VSPDSColors`, `VSPDSSemanticColors`, `VSPDSRadius`, `VSPDSizes`, and `VSPDSSpacing` (preserving exact visual pixel values).
2. **Phase 2 — Shared Formatters & Financial UX (`VSPFinancialFormatter`, `VSPPaymentSummaryCard`):**
   - Centralize currency (`ج.م` / `EGP`), date/time (Arabic/English), and booking/payment status localization (`confirmed` -> `مؤكد`).
   - Apply shared `VSPPaymentSummaryCard` across checkout, success, and booking details.
3. **Phase 3 — Screen-by-Screen Remediation:**
   - Fix `PlayerBookingDetailsScreen`, `BookingSuccessScreen`, `BookingConfirmationScreen`, and empty/loading/error states.
4. **Phase 4 — Dev-Only Showcase & Governance:**
   - Add `DesignSystemShowcaseScreen` (`kDebugMode` only).
   - Add token & color governance tests to `test/architecture_guardrails_test.dart`.
5. **Phase 5 — Verification:**
   - Run `flutter analyze`, unit/widget/guardrail tests, and update `DESIGN_SYSTEM_FINAL_REPORT.md`.
