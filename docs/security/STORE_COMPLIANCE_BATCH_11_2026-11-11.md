# Batch11 — legacy deletion and owner/admin reporting authorization

2026-11-11. Existing Phase8 SEC-01/02/03/04/09 and Phase9 tests. Core remains82 accepted/538 pending of620. No new task closure from this scoped patch.

## Confirmed scope

Additional metadata audit found75 definer routines containing admin-role checks outside the previously guarded paths.65 are client-callable,10 service-only. These are review candidates, not75 confirmed vulnerabilities. This batch reviews/fixes7: delete_user_permanently, both admin metrics, owner financial summary, owner operational AI insights, owner stadium comparison and tournament financial summary.

Production owner-report routines use CURRENT_USER inside SECURITY DEFINER guards, allowing caller checks to be bypassed. Staging synthetic-owner probe confirmed unauthorized financial/operational success; its comparison routine already had a partial auth fix and correctly returned failure for an unrelated owner. No real customer financial data or production exploit was queried. Exact staging comparison body is preserved as a separate known source variant.

Legacy deletion and tournament-finance predicates accepted blocked administrator role without checking current block state; two admin metric functions likewise need active-actor preconditions. Deletion is patched only in the cross-account branch, preserving a blocked user's own deletion right. Tournament reports preserve genuine ownership access. The three owner-report and two admin-report bodies receive private invoker preconditions; no financial calculations, pricing, subscription model or RPC result shapes for authorized callers changed.

A new private invoker helper permits same-user owner reports only while a live profile exists; otherwise it requires the existing active-admin/service/trusted-native check. Deleted-profile tokens, missing identities and user_metadata do not grant access. Direct helper execution is revoked from client/service roles. Helper source/mode/search-path/grants drift and7 parent source fingerprints abort on unknown changes.8 reviewed source-body variants cover7 signatures.

## Local executed evidence

PGlite0.3.14:8 suites,17 deliberately weakened guards detected, restored baselines, idempotency and inverse/forward replay. Tests cover anonymous/cross-owner/blocked admin/missing-profile/spoofed metadata, both admin metrics, preserved owner and authorized admin reports, blocked own privacy access, blocked own account deletion, authorized other-account deletion and deleted-token rejection. Both original production and existing staging comparison bodies are exercised. This is not native PostgreSQL/OAuth/provider or complete financial workflow proof; hosted rollout and native CI remain pending at this source commit.

Fixture-only corrections: the first draft incorrectly treated the deletion target itself as an unauthorized other user; a separate player actor fixes the fixture without denying self-deletion. Numeric aggregate assertion now compares numeric values rather than17 vs17.00 string formatting. No product guard was weakened to pass tests.

## Limits / policy alignment

No production customer rows, payouts, payments or balances changed. Unknown-source refusal/inverse live outside automatic production replay. No global65-routine security clearance is claimed. Store readiness remains HOLD under RELEASE_ACCEPTANCE_POLICY.md. Existing Apple1.6/5.1.1 and Google User Data access/deletion obligations apply; no new effective date asserted. Sources: https://developer.apple.com/app-store/review/guidelines/ and https://support.google.com/googleplay/android-developer/answer/10144311 .
