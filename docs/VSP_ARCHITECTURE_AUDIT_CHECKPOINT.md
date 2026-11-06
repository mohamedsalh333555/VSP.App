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

## Critical domains trace — 2026-11-06

| Domain | Verified path | Finding | Status |
|---|---|---|---|
| Identity/roles | `lib/core/providers/auth_provider.dart` | Delegates authentication to `AuthService`; `isOwner`/`isAdmin` are client presentation getters, **not** evidence of server authorization | Server RLS and RPC grants pending |
| Payment checkout | `lib/features/player/screens/payment_gateway_screen.dart` → `payment_checkout_coordinator.dart` / `payment_checkout_service.dart` | Shared checkout orchestration and payment status verification; coordinator also calls an RPC for safe booking release | Verify webhook, idempotency and amount authority |
| Challenges | `lib/features/player/screens/challenge_select_team_screen.dart` → `TeamRepository` / `ChallengeTeamService` / `BookingProvider` | Shared eligibility helper and repository code lookup; client validation cannot replace server-side acceptance | Concurrent acceptance E2E pending |
| Tournament lifecycle | `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` → `lib/core/repositories/tournament_repository.dart` | Repository facade coordinates start, activation, cancel and standings | Verify lifecycle RPC authorization and state transitions |
| Tournament payment status | `lib/core/repositories/tournament_repository.dart` | **Confirmed inconsistency:** status RPC bypassed injected `_client` and used global Supabase singleton | **Fixed** in commit `71c3ab0ca005643bd4b378dcb2bbe494392eaa2e` using `(_client ?? Supabase.instance.client)`; runtime tests pending |

### Release boundary

The change above is a small dependency-injection consistency fix, not a payment-rule change. No current-head analyzer, test suite, live payment test or production release was run as part of this checkpoint. Do not treat the fix as a production acceptance pass.

## Automated architecture guard — 2026-11-06

Added `test/architecture/tournament_client_injection_test.dart` in commit `fa32aa7f8ae6a8bb7ae5a1b1629d4c9a2fe30c02`. This source-level regression test checks that tournament payment status RPC respects the repository's injected Supabase client and does not bypass it with a direct global client call. **Not yet executed**; it does not validate payment transactions, RLS, webhooks or live behavior.

Run with `flutter test test/architecture/tournament_client_injection_test.dart` and then full current-head CI before treating this guard as passing.

## Checkout cancellation SSOT follow-up — 2026-11-06

- `lib/features/player/services/payment_checkout_coordinator.dart` previously invoked `Supabase.instance.client.rpc('cancel_tournament_payment_order_atomic', ...)` directly, despite being a coordinator with an injectable booking repository. Added optional `SupabaseClient? client` constructor dependency and used the injected client when supplied, retaining the global client fallback for existing call sites. Commit `8cb2d92812847b06156af10fe67d32606a1a6b61`.
- Added source-level guard `test/architecture/checkout_client_injection_test.dart` in commit `66048a85ba37667213e501156c4a17019d708bec`.
- Existing `TournamentRegistrationCoordinator` and `TournamentLifecycleCoordinator` already expose `_supabase => _client ?? Supabase.instance.client` and use it for their RPCs. This targeted scan did not identify the same bypass there.
- CI for earlier commit `1dc41c71`: Flutter analyze-test was still in progress at last check; Android E2E smoke job was **cancelled**, not passed. The newer commits require fresh current-head CI; neither new architecture guard has been observed passing.

## CI and architecture guard follow-up

- GitHub Actions on commit `0b8c413ca0da406b9dbdf42b98059db1e3985e4f`: Flutter CI run `42270406177` was in progress and Android E2E run `42270406173` was queued at inspection. These are **not** passing results and predate the newest test edit.
- Strengthened `test/architecture/checkout_client_injection_test.dart` in commit `76802d5d98641044b093f17ce2563d2b458bdb33`: check injectable constructor, assigned client, and cancellation RPC within the method scope rather than searching the entire file. Source-level test only, not a simulated server cancellation.
- Release gate remains closed pending completed current-head CI, E2E, and server-side RLS/RPC permission verification.

## Canonical tournament client accessor

- `lib/core/repositories/tournament_repository.dart`: introduced `SupabaseClient get _supabase => _client ?? Supabase.instance.client;` and routed both direct RPC calls through it. Commit `066c45eb6a13ec5b533073e864fe1571038edf2a`.
- Updated `test/architecture/tournament_client_injection_test.dart` to guard the shared accessor and payment-status call. Commit `fe07a9d71a602312d7a21f3860a155759d04dd23`.
- The prior CI run for `ba0427ea` had both Flutter CI and Android E2E in progress when checked; it predates these changes. Current HEAD requires new CI evidence. No runtime test result claimed.
