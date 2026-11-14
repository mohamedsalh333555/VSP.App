# VSP design contract

This is a navigation and decision document, not a replacement design system.

## Existing authority

- [Design System V2](docs/DESIGN_SYSTEM_V2.md): established identity, architecture and component guidance.
- [Canonical tokens](lib/core/ui/tokens/vsp_design_tokens.dart): executable values.
- [Compatibility facade](lib/core/ui/tokens/vsp_tokens.dart): existing screens may keep importing it.
- [UXLP-44](docs/UXLP_44_VSP_STANDARD.md), [screen register](docs/UXLP_44_SCREEN_REGISTER.md) and [rule audit](docs/UXLP_44_RULE_AUDIT.md): acceptance scope and unresolved evidence.

Keep Dark Zinc / Volt Green, Poppins / Tajawal and the established spacing, radii and typography hierarchy. Do not introduce a second palette, replace fonts, or redesign a healthy screen to satisfy this document. Reference tokens instead of copying their numeric values here. Preserve financial amounts, booking state, roles and competition rules.

## Decisions added on 2026-11-04

- Shared primary actions and segmented labels grow vertically and wrap with system text scaling. Do not use `FittedBox` to shrink essential action text. Existing tight parent constraints still require device review.
- `VSPSegmentedControl` is the common implementation for owner dashboard tabs, owner cup tabs, champion tabs and team dashboard tabs. Preserve each caller's callbacks and haptics. Use logical direction for the selected pill, explicit selected semantics and a minimum 48dp target. `IntrinsicHeight` is deliberately restricted to these small two/three-item headers; do not copy it into long lists.
- Logical start/end is appropriate for chat bubbles, copy actions, avatar overlays and text decoration. Physical gradient axes remain intentional visual lighting, not reading-direction defects.
- Press animation rests at scale 1. Reduced-motion settings suppress decorative press, fade and skeleton motion. New named duration tokens preserve existing timings, rather than change the motion language.
- Status copy must describe observed facts: the countdown describes scheduled start time, not a server-confirmed tournament transition; a bounded availability search cannot assert that all pitches are booked.
- Keep editing text until the asynchronous save succeeds. Disable duplicate save/cancel while saving and show a localized retryable error. Copy confirmation follows successful clipboard completion.
- Exact existing palette aliases can replace Flutter literals. Semantic error/gold tokens are used for actual error/award contexts. Non-equivalent alpha values must not be substituted automatically.

## Evidence gate

[Design and performance review](docs/VSP_DESIGN_PERFORMANCE_REVIEW.md) distinguishes implemented source changes from deferred runtime validation. No visual approval, accessibility conformance, performance speedup or final release readiness is implied by token adoption or a static scan.
