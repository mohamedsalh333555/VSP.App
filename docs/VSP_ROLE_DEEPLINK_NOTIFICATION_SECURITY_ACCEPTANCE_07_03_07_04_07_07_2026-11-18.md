# VSP — Verified role routing, trustworthy deep links and notification destinations

**18 November 2026 · Branch `uxlp-44-implementation` · No production changes**

**Exact tested source:** [1a935a1](https://github.com/mohamedsalh333555/VSP.App/commit/1a935a1c03e5a62f2bc9a099e4c4c6a12e8a215a).
**Passing [VSP Navigation Role and Notification Security CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44202088013)**: Flutter Analyze and dedicated Dart/Flutter tests for direct owner/player routes, blocked accounts, admin override, notification routing, signed-in recipient account checks, permitted/forged OAuth origins, bounded URL identifiers and pending-link storage.

## 07.04 — Protect navigation according to verified player/owner role

Previously, the post-login player redirect logic did not explicitly reject `/owner`, `/documentation` or `/facility-onboarding`. These paths could be reached via a direct URL despite not appearing in the player menu.

- `AppRouteRoleGuard` now centralizes owner-only and player-only routes.
- `AppRouter.redirectLogic` invokes the guard after loading and checking the authenticated profile, including verification and suspended-account state. It does not trust a deep-link-supplied role.
- A verified player cannot navigate directly to owner shell, facility onboarding, documentation, Copilot, owner ledger or owner subscription plans. An owner cannot reach player match, team, pickup invitation, notifications or edit-profile screens via these GoRouter paths.
- Tests check both roles' permitted screens, blocked-account precedence, mismatched role deep links, query strings, admin bypass and exact-path matching.
- **Acceptance scope:** Flutter global router and client UI only. This does **not** prove Supabase RLS, auth tokens, cross-account profile reads or imperative navigation everywhere. Existing SEC-02 / P0 role isolation staging tasks remain open.

## 07.07 — Verify notification navigation to privileged destinations

- Owner notification destination paths `/subscription-plans` and `/owner-ledger` were referenced by FCM click handling but absent from the registered GoRouter routes. Both are now registered and included in the owner-only role guard.
- In-app notification taps now require the authenticated account's owner role, currently active account and not-blocked profile before using imperative `Navigator.push` to open subscription or ledger screens.
- Tests assert route registration, guard order, call sites in both FCM and in-app notification flows, and rejection of owner billing URLs by a verified player.
- **Acceptance scope:** code-level route and synthetic notification destination tests. Real OS notification taps on Android/iOS, changed-account timing and two-account live RLS verification are not proven; subscription balance/payment authority remains server-side.

## 07.03 — Audit and harden deep-link parsing

- `DeepLinkHelper.isOAuthCallback` no longer accepts any external URL simply because its query contains `code`, its fragment mentions `access_token`, or its path resembles `login-callback`. It requires the registered custom-scheme callback host or an explicitly approved HTTPS origin and callback path.
- `DeepLinkHelper.parse` only accepts registered custom schemes or the known HTTPS website hosts. It rejects HTTP, embedded credentials, unusual ports, extra route segments, duplicated IDs, fragments, whitespace or non-route characters in IDs, and IDs longer than 128 characters. Deep links requiring an ID cannot be routed with an empty ID.
- The app validates links **before** caching a pending deep link for later authentication. Its OAuth callback handler no longer persists or applies an untrusted `role` query. The initiating `AuthOAuthCoordinator` already persists the locally selected role before starting OAuth; the Supabase SDK owns auth-token/PKCE verification.
- Tests cover legitimate Google/Apple mobile callback shapes, HTTPS web callback shapes, malicious lookalike origins, token-fragment impersonation, route ID abuse and normal team/match/collective routes.
- **Acceptance scope:** parser and app entrypoint source/Dart tests only; not an Android App Links verification, full hosted OAuth end-to-end test, notification delivery test or validation of every legacy `booking`/`stadium` return route. Backend resource authorization remains separate.

## Accounting / safety

Three **existing** task IDs accepted within the above narrow contracts, no new unique IDs. **633 total / 303 accepted / 330 open (47.87%)**. No `main` merge, production deploy, DB mutation, Paymob transaction, new APK or live two-account access checks.
