# VSP Design System Adoption Audit

**Audit Date:** 2026-11-27  
**Branch:** `feat/unify-commission-paymob-fees`  
**Scope:** `k:\.gemini\antigravity\scratch\vsp_application\lib\`

## 1. Quantitative Baseline (Measured via ripgrep / PowerShell)
| Metric | Measured Count | Notes |
|---|---:|---|
| Total Dart files in `lib/` | 493 | Full Flutter app (`core`, `data`, `features`, `shared`, `l10n`) |
| Files importing V2 (`vsp_design_tokens.dart`) | 14 | Canonical Design System V2 |
| Files importing Legacy (`vsp_tokens.dart`) | 300 | Legacy Compatibility Layer |
| Files importing `vsp_ui.dart` | 66 | Shared V2 UI grammar (`VSPScaffold`, `VSPSectionHeader`, `VSPStatusPill`, `VSPStateView`) |
| Raw `Color(0x...)` literals | 89 | Concentrated in token files + legacy custom cards |
| Direct `Colors.*` usages | 4,283 | Mostly `Colors.white` / `Colors.black` / `Colors.transparent` |
| Direct `TextStyle(...)` usages | 1,224 | Inline styles instead of `VSPDSTypography` / `Theme.of(context).textTheme` |
| Direct `EdgeInsets.*(...)` usages | 925 | Inline spacing instead of `VSPDSSpacing` |
| Direct `BorderRadius.circular(...)` usages | 725 | Inline radii instead of `VSPDSRadius` |

## 2. Token Divergence (Legacy vs V2)
| Scale | Legacy (`VSPSpacing`) | V2 (`VSPDSSpacing`) | Mapping |
|---|---:|---:|---|
| 4dp | `xs = 4.0` | `xxs = 4.0` | `VSPSpacing.xs -> VSPDSSpacing.xxs` |
| 8dp | `sm = 8.0` | `xs = 8.0` | `VSPSpacing.sm -> VSPDSSpacing.xs` |
| 12dp | `md = 12.0` | `sm = 12.0` | `VSPSpacing.md -> VSPDSSpacing.sm` |
| 16dp | `lg = 16.0` | `md = 16.0` | `VSPSpacing.lg -> VSPDSSpacing.md` |
| 20dp | `xl = 20.0` | `inputHorizontal = 20.0` | `VSPSpacing.xl -> VSPDSSpacing.inputHorizontal` |
| 24dp | `xxl = 24.0` | `lg = 24.0` | `VSPSpacing.xxl -> VSPDSSpacing.lg` |
| 32dp | `xxxl = 32.0` | `xl = 32.0` | `VSPSpacing.xxxl -> VSPDSSpacing.xl` |

## 3. Critical Visual & Financial UX Gaps Identified
1. **Duplicate literal definitions in `vsp_tokens.dart`:** `VSPColors`, `VSPRadius`, `VSPSize`, `VSPSpacing` redefine raw hex/doubles instead of aliasing `VSPDSColors`, `VSPDSSemanticColors`, `VSPDSRadius`, `VSPDSizes`, `VSPDSSpacing`.
2. **Financial & Status Formatting Inconsistency:** `PlayerBookingDetailsScreen` and `BookingSuccessScreen` expose raw statuses (`confirmed`/`pending`), `'EGP'`, or English date formats in Arabic UI, and lack a shared `VSPPaymentSummaryCard`.
3. **Governance & Showcase:** No dev-only Design System Showcase screen and no automated token-duplication check in `test/architecture_guardrails_test.dart`.
