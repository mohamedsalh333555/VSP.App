# VSP — Arabic/English copy review and semantic color contrast audit

**18 November 2026 (Cairo) · `uxlp-44-implementation` · scoped source/code acceptance**

**Exact tested SHA:** [6efcd632](https://github.com/mohamedsalh333555/VSP.App/commit/6efcd6322ea0e3dbe6d3162751959ab17f0795f0).

**Two successful CI workflows at that SHA:**
- [VSP Semantic Color Contrast Audit — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44198636272). Test coverage: WCAG relative luminance/contrast, alpha composition, semantic color alias resolution, fixture showing prior lower-contrast muted token fails, and twelve current semantic pairs. Markdown/JSON CI artifacts for 14 days.
- [VSP Arabic English Localization Source Audit — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44198628560). Test coverage: ARB parity and placeholder consistency, ICU plural-case exclusion, synthetic missing and blank translations, static UI copy candidate detection. Markdown/JSON CI artifacts for 14 days.

## 05.01 — Audit color contrast and correct a confirmed low-contrast semantic token

A read-only scanner resolves actual color definitions and aliases from `lib/core/ui/tokens/vsp_design_tokens.dart` and calculates color contrast for selected text/icon combinations on VSP's charcoal background, surface and raised surface.

**Initial proven issue:** `VSPDSSemanticColors.textMuted = VSPDSColors.gray500` contrasted at only **3.66:1** on `surface`, below a 4.5:1 reference threshold when this token is used for ordinary-size text. The token's actual use in every rendered widget remains a separate acceptance gate.

**Source correction:** `textMuted` now reuses the existing neutral charcoal `VSPDSColors.zinc400` token rather than adding neon green or a new theme. This produces **6.91:1** on `surface` and **5.81:1** on `surfaceRaised`. After the fix **12/12 sampled semantic token pairs meet their selected 4.5:1 (normal text) or 3:1 (non-text) threshold**. A regression test proves the previous token would fail.

This is a **semantic-token source contrast audit/fix**, not comprehensive WCAG 2.2 compliance: opacity, status badges, text scales, images, disabled controls, gradients, widgets and device screenshots still need a separate review. 05.02–05.07, 10.04 and general visual acceptance remain open.

## 04.01 — Review missing Arabic/English copy keys and literal UI text

The localization scanner checks both committed `lib/l10n/app_ar.arb` and `app_en.arb`, along with **556 non-generated Dart files**:

| Audit item | Measured |
| --- | ---: |
| Arabic ARB translation keys | 756 |
| English ARB translation keys | 756 |
| Keys missing from Arabic | 0 |
| Keys missing from English | 0 |
| ARB placeholder-name mismatches | 0 |
| Empty localized strings | 0 |
| Same-line hardcoded `Text('...')` review candidates | 33 |
| Candidates containing Latin letters | 9 |
| Candidates containing Arabic characters | 24 |

The complete Markdown/JSON report lists representative Dart source locations; 33 candidates require manual triage, **not all are defects**. Some may be intentional test playground copy or already wrapped in appropriate bilingual UI; the scanner does not fully parse multiline `Text`, `TextSpan`, `Tooltip`, conditional copy, dynamically generated strings or localized user-generated content. ICU placeholder comparison is heuristic and has a plural-choice regression test.

This accepts **04.01 as source copy review**, **not** 04.02 (implement missing UI strings), 04.03/04.06 (RTL/bilingual device tests) or a global statement that all visible text is translated.

## Accounting and boundaries

Two pre-existing audit task IDs newly accepted and no new IDs. **633 unique / 300 accepted / 333 open (47.39%)**. No payments, production database write, app store publication or `main` merge.
