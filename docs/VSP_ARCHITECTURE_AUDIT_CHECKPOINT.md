# VSP architecture audit — initial inventory

Branch: uxlp-44-implementation. Scope: audit only; no production deployment.

## Confirmed

- `lib/core/ui/tokens/vsp_design_tokens.dart` is the canonical visual token foundation.
- `lib/core/ui/tokens/vsp_tokens.dart` provides legacy compatibility aliases.
- `DESIGN.md` records reuse of `VSPSegmentedControl` across owner dashboard, owner cup, champion and team dashboard tabs.
- `lib/core/config/app_env.dart` centralizes compile-time configuration.
- `docs/UXLP_44_RULE_AUDIT.md` reports 338 registered Dart paths, with runtime verification still pending.
- `docs/VSP_DESIGN_PERFORMANCE_REVIEW.md` documents repeated stream and future creation and fixes; runtime validation remains pending.

## Next checks

1. Trace booking, payments, permissions, teams, challenges and tournament write paths from UI to server authority.
2. Record each shared responsibility's canonical implementation and any duplicate call sites.
3. Separate valid feature-specific behavior from actual duplication.
4. Refactor one low-risk duplicated concern at a time with regression tests.
5. Keep PR #35 and release gates blocked until current-head CI, critical E2E and rollback evidence pass.

This file is an audit checkpoint, not evidence of complete architectural compliance.
