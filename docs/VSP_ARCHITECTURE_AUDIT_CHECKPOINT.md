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

## Source tracing checkpoint — 2026-11-06

| Domain | Entry point | Shared authority found | Remaining verification |
|---|---|---|---|
| Booking create/cancel | `lib/core/providers/booking_provider.dart` | `SupabaseBookingRepository` via injected repository; `createBooking`, `cancelBooking` | Trace RPC/transaction and server-side occupancy/idempotency; compare all alternate call sites |
| Booking sync | `lib/core/providers/booking/booking_sync_coordinator.dart` | Shared `BookingSyncCoordinator` for user/owner refresh and subscription handling | Verify scope changes, stale events and confirmed state precedence in runtime tests |
| Team creation/invites | `lib/core/repositories/team_repository.dart` | `create_team_with_consent`, `invite_team_member`, invitation response RPC and `team_membership_invitations` | Verify server policies, RLS, invitation replay, all screens use canonical repository |
| Team results | `lib/core/repositories/team_repository.dart` | RPC invoked by `updateMatchResult` | Verify captain confirmation and authoritative standings recalculation before any refactor |

**Classification:** These are established shared entry points, not proof that every call site uses them. No duplicate or unsafe-client-authority finding is yet confirmed by this targeted trace. Do not change financial, booking or competition semantics based only on these observations.
