# VSP — Responsive device and visual acceptance matrix

Status: engineering acceptance criteria. This document defines **target device sizes** (09.01) and **objective visual-difference acceptance rules** (10.08). It does not claim screenshots or Android tests have passed.

## Target viewport matrix (logical pixels / dp)

| ID | Viewport | Text scale | Locale | Purpose |
|---|---|---|---|---|
| S1 | 320 × 568 | 1.0 | ar-EG RTL | Minimum supported compact phone, overflow and tap targets |
| S2 | 360 × 640 | 1.0 | ar-EG RTL | Compact mainstream Android |
| S3 | 393 × 852 | 1.0 | ar-EG RTL | Baseline Android |
| S4 | 412 × 915 | 1.0 | en-US LTR | Large Android, long English labels |
| S5 | 600 × 960 | 1.0 | ar-EG RTL | Narrow tablet / split-screen layout |
| S6 | 800 × 1280 | 1.0 | en-US LTR | Tablet layout |
| A1 | 320 × 568 | 1.3 | ar-EG RTL | Larger text on minimum viewport |
| A2 | 360 × 640 | 2.0 | ar-EG RTL | Accessibility text scaling |
| A3 | 393 × 852 | 1.0 | ar-EG RTL | Android reduced motion enabled |
| K1 | 360 × 640 | 1.0 | ar-EG RTL | Keyboard open on each form |

These are **test targets**, not a claim that every viewport is currently supported. Verify physical Android screen density/safe insets separately; do not equate screenshot pixel dimensions with dp.

## Reference screens (to capture after staging test accounts exist)

Player: sign-in, onboarding, discovery/search, venue details, booking checkout, booking history, team profile, team challenge confirmation, championship standings, empty/error/offline states.

Venue owner: onboarding, venue profile editor, hours/closures, booking management, subscription entitlement/paywall.

Admin and web have independent baselines and are not substituted for Android screenshots.

## Visual acceptance rules

1. **Zero layout exceptions:** no RenderFlex overflow, clipped primary CTA, horizontal scroll on non-scrollable content, or inaccessible controls at S1–S6/A1–A2/K1.
2. **Critical information invariant:** price, date/time, venue, opponent, booking/payment status, consent and destructive-action wording must be fully readable. Never hide these behind ellipsis.
3. **Tap target minimum:** interactive controls have at least 48 × 48 dp usable hit area on Android; adjacent controls must not overlap.
4. **Text and locale:** labels remain semantically correct in Arabic RTL and English LTR; numeric/date display matches locale; text scaling up to 2.0 does not obscure required actions.
5. **Contrast:** normal text >= 4.5:1, large text >= 3:1, essential non-text controls >= 3:1 unless exempt under WCAG; check against actual background.
6. **Animation:** reduced-motion mode suppresses nonessential scaling, pulsing and transitions; no rapidly flashing visual content.
7. **Golden comparisons:** capture references at the same viewport, scale, locale, theme, font and platform; mask timestamps, random IDs, network images and other nondeterministic areas only when explicitly justified.
8. **Tolerance:** require pixel-exact comparison for deterministic icons, spacing and component geometry; allow a documented <= 1% changed-pixel tolerance for antialiasing-only changes, provided there are no semantic/layout failures. A visual diff above tolerance is **review required**, not automatically a bug or a pass.
9. **Severity:** P0 if payment/booking/security/consent controls are hidden or misleading; P1 if any required action is unreachable or screen-reader navigation is blocked; P2 for nonblocking alignment/color regressions.
10. **Evidence per screen:** attach before/after screenshots, viewport ID, test build SHA, diff result, reviewer, issue link and explicit pass/fail. A screenshot alone is not acceptance.

## Execution commands and gate

Run `flutter analyze` and `flutter test` on a clean checkout. Run widget/golden tests for the matrix and Android integration tests for keyboard, screen reader and reduced motion. Do not mark 09.02–09.07 or 10.02–10.07 complete without recorded evidence. No production database changes are needed for this matrix.
