# UXLP-44 — Phase 2 Implementation Progress

**Branch:** `uxlp-44-implementation`  
**Scope:** Phase 2 only — source implementation of UXLP-44.  
**Explicit exclusion:** CI, analyzer, automated tests, runtime checks, and APK build are not being run in this phase.

## Implemented source changes in this batch

1. **Canonical bottom navigation geometry access (Rules 5, 42)**
   - Re-exported `VSPBottomNavMetrics` through the legacy token facade.
   - The metric values remain defined only in `vsp_design_tokens.dart`; no second geometry source was introduced.
   - This resolves feature imports that consume the legacy facade while referencing the canonical metric.

2. **Owner tournament stream recovery (Rules 9, 36, 38)**
   - Initial stream failure now displays the shared localized error/retry state.
   - A successful empty list is not used to mask a stream failure.
   - A previously loaded non-empty tournament snapshot remains visible after a later stream refresh error.
   - The stale-data warning and retry affordance are bilingual.
   - Retry recreates the stream using the current owner/sport scope.

3. **Shared state-view compact-screen resilience (Rules 11, 35)**
   - Shared loading and terminal state presentations now use a bounded-width scrollable content region.
   - Long localized text and recovery actions remain reachable when viewport height is constrained.
   - Existing semantic colors and charcoal empty/disabled treatment are preserved.

## Rules touched by this implementation batch

| Rule | Source implementation | Status |
|---|---|---|
| 3 — Contrast first | Preserve semantic state colors and neutral empty/disabled treatment | Source updated/reused; runtime pending |
| 5 — One icon language | Canonical navigation geometry exposed through compatibility facade | Source updated; glyph appearance pending |
| 6 — Color semantics | Shared state component retains semantic error/offline and neutral empty colors | Source reused; screen-wide review pending |
| 9 — State visibility | Owner tournament loading/error/empty/stale states separated | Source updated; runtime pending |
| 11 — Responsive legibility | Shared state view scrolls within bounded width | Source updated; runtime pending |
| 35 — Scroll and modal safety | Shared state/action content remains scrollable | Source updated; runtime pending |
| 36 — Feedback recovery | Owner tournament error state includes retry and stale-data warning | Source updated; runtime pending |
| 38 — Single source of truth | Bottom navigation metrics remain canonical in V2 tokens | Source updated; usage migration pending |
| 42 — Design-system governance | Compatibility export points to canonical token only | Source updated; repository-wide migration pending |

## Remaining Phase 2 work

- Continue rule-by-rule source mapping and implementation for all 44 rules across applicable player/owner screens, shared widgets, embedded surfaces, dialogs, sheets, and lifecycle states.
- Consolidate repeated button, segmented-control, filter, and bottom-action patterns on canonical components where safe.
- Continue bilingual copy, RTL/LTR, typography, contrast, grouping, hierarchy, touch-target, keyboard, safe-area, and state-recovery corrections.
- Continue query/state truthfulness fixes without changing backend policy or applying migrations.
- Keep product-policy and backend authorization changes in the approval-required list until the product owner approves the exact change.

## Phase boundary

This progress file does not declare UXLP-44 complete. All 44 matrix entries remain runtime-pending until a later explicitly approved validation phase. No CI, analyzer, automated tests, runtime tests, database mutation, migration, or APK build was performed.
