# VSP — Flutter design-token, typography, spacing and animation inventory

**18 November 2026 · `uxlp-44-implementation` · Inventory-only acceptance**

**Exact tested source SHA:** [834641bc](https://github.com/mohamedsalh333555/VSP.App/commit/834641bc2ff3ba817960c9576eca6571cd8682cb).

**Passing CI:** [VSP Source Design and Motion Inventory — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44196802382), including `node --test scripts/test_vsp_design_motion_inventory.cjs`, full non-generated `lib/` scan, and the downloadable `vsp-design-motion-source-inventory` artifact (Markdown + JSON; 14-day CI retention). The scanner is committed as `scripts/audit_vsp_design_tokens_motion.cjs` and can regenerate the inventory after future changes.

## 02.01 — Inventory of colors, typography and spacing

**556 non-generated Dart source files** traversed. The classifier inspects all `lib/` files that are not generated code and reports both occurrences and distinct files, plus source line samples.

| Source family | References | Files |
| --- | ---: | ---: |
| VSP / VSPDS named color tokens | 5,557 | 337 |
| Direct Flutter Material `Colors.*` references | 60 | 23 |
| Literal `Color(0x...)` occurrences | 60 | 2 |
| VSP / VSPDS spacing tokens | 957 | 171 |
| VSP / VSPDS radius tokens | 890 | 267 |
| Literal `fontSize:` numeric uses | 1,283 | 260 |
| Explicit `fontFamily:` literals | 7 | 3 |
| `EdgeInsets` constructor uses | 1,177 | 292 |
| `SizedBox` constructor uses | 2,046 | 305 |

Source is centered around `lib/core/ui/tokens/vsp_tokens.dart` and `lib/core/ui/tokens/vsp_design_tokens.dart`. A name such as `voltGreen` is not proof of a neon-green visual: the current canonical `voltGreen` alias points to charcoal-family `zinc400`; changing color semantics requires separate visual acceptance. Literal colors inside the design-system definition can be intentional, and literal spacing/font sizes are **review candidates, not automatically defects**.

This closes **02.01 as a source inventory**, not 02.02–02.07 (token unification, component migrations, testing and visual parity).

## 06.01 — Inventory of motion and transitions

| Source family | References | Files |
| --- | ---: | ---: |
| `VSPDSMotion.*` references | 61 | 48 |
| Explicit animation/transition widgets and controllers | 84 | 49 |
| Page / route transition constructors | 108 | 50 |
| Explicit `Duration(milliseconds/seconds/...)` constructors | 140 | 63 |
| `disableAnimationsOf` / accessible navigation source checks | 11 | 8 |

The inventory separates explicit animation widgets/controllers from navigation route review points; it does **not** assume every route creates a custom animation. The output includes representative file/line locations and a machine-readable JSON report to prioritize the future 06.02–06.05 tasks.

**Important limit:** these source patterns do not evaluate AST or runtime rendering; multiline comments, strings and indirect animation helpers can affect counts, and Android reduced-motion settings have not been tested. This closes **06.01 inventory only**, not 06.02/06.03/06.04/06.05.

## Accounting and safety

Two previously open inventory IDs accepted, zero new task IDs. **633 unique / 296 accepted / 337 open (46.76%)**. The audit is read-only and makes no UI, booking, payment, database, production or `main` change.
