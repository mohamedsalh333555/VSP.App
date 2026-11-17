# VSP — Deferred deep-link navigation after logout, account switch or session expiry

**18 November 2026 · branch `uxlp-44-implementation` · client source/test acceptance only**

**Exact tested code SHA:** [a9d1bdc](https://github.com/mohamedsalh333555/VSP.App/commit/a9d1bdc88cceb45d383b9aefe9745684253590d2).

**Passing [VSP Navigation Role and Notification Security CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44203770410):** Flutter Analyze and Flutter tests including `test/core/navigation/pending_deep_link_account_guard_test.dart`, expired-session redirect scenarios in `test/deep_link_abuse_test.dart`, malicious OAuth/deep-link origins and notification account isolation.

## Narrow scope: 07.05 — Fix navigation after session expiry

- `PendingDeepLinkAccountGuard.canReplay` requires the same authenticated user ID and hydrated completed profile before navigating. A pending intent linked to a previous signed-in account cannot be played back for a different user.
- `lib/main.dart` stores the identity that received the link (or an empty binding for a genuine pre-login share), checks that the account has not changed while async SharedPreferences writes run, and never stores a link for a stale identity.
- Both `lib/main.dart` and `RootScreen` verify the active account **before and after** async preferences calls and revalidate the URL with `DeepLinkHelper.parse`. Both clear consumed/invalid pending links and their account metadata.
- A synchronous lease prevents the two startup consumers from pushing the same pending link twice. The lease always releases through `finally`.
- `AuthDraftCleaner.clearSessionDrafts` clears pending links and their original-account binding on sign-out, alongside existing per-user drafts.
- Automated tests cover matching user IDs, sign-out/unauthenticated state, account A becoming account B, incomplete profile, stale original-account binding, duplicate concurrent startup consumers, source-level async checks and logged-out private navigation redirects to `/welcome`.

## Explicit exclusions

- This is a **client navigation/state lifecycle** test, not proof of a real Supabase JWT's automatic expiry and refresh timing, notification delivery via Android/iOS OS, or backend RLS. Task **11.05** remains open for real expiry/invalidation tests.
- If a deep link was received while fully signed out, it intentionally has no account binding: the user still must authenticate, finish onboarding and pass the destination's client route/authoritative backend guards.
- Remote data authorization, real two-account device tests and production login are not covered. No external DB, Paymob, production app, APK publication or `main` merge changed.

**Counter after this narrowly accepted pre-existing ID:** 633 total / **304 accepted** / **329 open** (**48.03%**), zero new tasks.
