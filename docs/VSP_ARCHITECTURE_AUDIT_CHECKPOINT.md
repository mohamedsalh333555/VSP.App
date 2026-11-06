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

## Two-entry-point regression coverage

- Extended `test/architecture/tournament_client_injection_test.dart` to cover both direct repository RPC entry points (`claimOwnerChampionshipApprovalHomeNotice` and `getTournamentPaymentOrderStatus`) in commit `b604d6daea9bc58527b9ed72d8491da66a0dec8e`.
- This is static source-level guard coverage, **not** a mock client execution test or a server-side permission audit.
- CI on earlier commit `64d0d916`: Flutter analyze-test and Android public/auth smoke were still running at last inspection. New head has no verified passing test result yet. Production and main remain untouched.

## Staging Supabase read-only security audit — 2026-11-06

Project: staging `vtwgqyxglevcsxwdmhop` (NOT production). Security advisor returned **4** `security_definer_view` ERROR findings (`public.courts`, `public.tournament_clean_sheets`, `public.owner_subscription_status`, `public.public_subscription_plans`), **4** `extension_in_public` warnings and **198** `authenticated_security_definer_function_executable` warning findings. Counts are advisor notices, **not** confirmed exploit counts. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view and https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable.

A read-only `pg_proc` privilege/definition-pattern check for `activate_vsp_pro`, `admin_approve_championship_atomic`, `cancel_tournament_payment_order_atomic`, `confirm_tournament_order_atomic`, `create_team_with_consent`, `get_tournament_payment_order_status` found all six are `SECURITY DEFINER`, executable by `authenticated` but not by `anon`, and contain the literal `auth.uid()` in their definitions. **This does not prove correct ownership, admin checks, transaction validation, or authorization**, and must not be treated as an access-control pass. Next: inspect each sensitive function's conditions and dependencies and run role-separated negative tests in staging before considering policy changes.

No SQL mutation or production access was performed.

## Expanded source-level RPC guard — 2026-11-06

- `test/architecture/tournament_client_injection_test.dart` now asserts the entire tournament repository has no direct `await Supabase.instance.client.rpc(` bypass; commit `da6978c8e6fb9c060184240599bc78eeaf25662f`.
- `test/architecture/checkout_client_injection_test.dart` adds the equivalent coordinator-wide guard; commit `73be39cf16153a82a8edafe5e997ddf29b8bfaad`.
- These are source-level tests, not execution of RPCs or security proof. Current-head CI and E2E results still need verification.

## Booking and team client guard

- Reviewed `BookingRepository` and `TeamRepository`: both already centralize the Supabase client in `_supabase => _client ?? Supabase.instance.client` and use `_supabase.rpc` for direct RPCs.
- Added `test/architecture/booking_team_client_injection_test.dart` to detect future direct global-client RPC bypasses in either repository. Commit `d6dbc95ea775e1d1a64037415dea565cc2f89995`.
- This is a source-level architecture regression test only; no booking, team, or database transaction was executed. CI for earlier head `51d9852b` was pending/queued when checked. Latest commit still needs green CI.

## Verified CI milestone — 2026-11-06

GitHub Actions for commit `fef5c4e36a2e403b4add34e4b56851ca624828dc` completed successfully:

- Flutter CI run `42271597741`: `analyze-test` job `128077267743` completed **success**.
- Android E2E Smoke run `42271597713`: `Android public/auth journey smoke` job `128077285138` completed **success**.

These results verify the CI workflows as configured on that commit; they do **not** prove full payment, booking, competition, RLS or cross-role security coverage. A documentation-only follow-up commit will need its own head status if strict current-HEAD verification is required. No production deploy or main merge is authorized.
