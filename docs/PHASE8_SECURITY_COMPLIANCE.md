# PHASE 8 — Security, Privacy, Compliance & Store Approval Readiness

Last checkpoint: 2026-11-05. Branch: `uxlp-44-implementation`. **Do not merge into main without owner approval.**

## Scope and evidence standard

This phase augments, and does not replace, the existing 24 journeys tracked in [E2E_24_JOURNEYS_EXECUTION.md](E2E_24_JOURNEYS_EXECUTION.md). DONE means the relevant fix **and its test** actually passed; code inspection alone is not DONE. No production mutation or real payment is authorized. Follow the pre-existing `SECURITY_TASKS.md` constraints, including explicit owner approval before production SQL changes and its deferred leaked-password-protection task.

## Baseline (observed)

- Flutter mobile application; Supabase Auth/Postgres/RLS/Storage/Edge Functions; Firebase Android integration; static `web_dist` pages; Paymob integration source.
- Existing public `web_dist/privacy.html` and `web_dist/terms.html` and owner in-app deletion UI were found; **existence does not establish legal adequacy or a complete deletion workflow**.
- Payment-related Edge Function source exists in `supabase/functions/{create_paymob_intention,paymob_webhook,process_paymob_refund}`; deployment and secrets must be verified separately.
- Prior journey evidence: 4 passed, 3 failed, 14 blocked, 3 not run (last recorded E2E report; not a new test run).
- Latest observed Flutter CI: success (run 42024932555). Android E2E: failure (run 42024932640). A subsequent Android run 42028838602 was in progress at inspection.
- Earlier security task inventory is in `SECURITY_TASKS.md`. Its staging status may be stale; reverify live environment before taking action.
- No store approval, production security certification, or verified legal opinion is claimed.

## Phase 8 task register

| ID | Priority | Status | Scope / immediate evidence and next action |
|---|---|---|---|
| SEC-01 | P0 | IN PROGRESS | Inspect Supabase auth/session lifecycle, reset and email verification; test cross-account operations |
| SEC-02 | P0 | IN PROGRESS | Audit RLS, Storage, security-definer RPCs and Edge Function authentication on staging; use isolated accounts |
| SEC-03 | P1 | NOT STARTED | Build data inventory, retention/access/processor mapping and log minimization |
| SEC-04 | P1 | IN PROGRESS | Owner deletion UI exists; verify player and web request flows, safe retention and end-to-end deletion |
| SEC-05 | P1 | NOT STARTED | Separate transactional from marketing consent, opt-out, send authorization and throttling |
| SEC-06 | P0 | IN PROGRESS | Booking atomicity and payment/webhook/idempotency audit; payment E2E blocked on sandbox |
| SEC-07 | P1 | IN PROGRESS | Team invitations, challenge acceptance and result permissions have documented gaps in 24-journey report |
| SEC-08 | P1 | BLOCKED | Official Apple/Google policy verification, developer account metadata and store submission pending; do not assert approval |
| SEC-09 | P1 | NOT STARTED | Audit static web pages, admin routes, authorization and security headers at hosting layer |
| SEC-10 | P0 | IN PROGRESS | Audit secrets and CI permissions; never rotate production keys without approval |
| SEC-11 | P1 | IN PROGRESS | Existing privacy/terms pages require accurate service mapping and legal review; no invented legal identity |

## Journey integration

For each original journey 01–24, preserve its ID and functional acceptance criteria. Add: malformed input, unauthorized role, other-user access, network failure, duplicate request, private-data exposure, and resulting database state. Mark each dimension as PASSED / FAILED / BLOCKED / NOT RUN with evidence. Do not promote the journey to Passed until the required real staging flow succeeds.

## Specific high-priority pre-existing security tasks

Read `SECURITY_TASKS.md` before acting. It identifies `process_tournament_refund`, `create_owner_web_checkout`, `get_owner_web_checkout_status`, `fcm_push`, `paymob_webhook`, and `teams` sensitive fields for targeted review. These are **reported risks pending current verification**, not newly confirmed vulnerabilities. Keep webhooks callable without user JWT only where server-side signature validation is authoritative. No production configuration changes without approval.

## Next executable checkpoint

1. Inspect current deployed Edge Function settings and code against the repository; prioritize refund and owner-checkout authorization.
2. Run read-only RLS / function privilege checks on staging and cross-account negative tests.
3. Patch confirmed defects on this branch, add regression tests, and record exact CI run results.
4. Recheck Android smoke and 24-journey baseline; continue independent tasks when payment or device checks are blocked.
5. Verify Apple/Google requirements against official current documentation before filling store metadata.

## Release blockers

Paymob sandbox credentials and deployed payment functions; real email inbox confirmation; device push verification; unfinished team/challenge lifecycle; app-admin navigation; official store account actions and legal review. These remain BLOCKED/NOT RUN until independently proven otherwise.

## Commit and test evidence

- Phase 8 register created: commit is the GitHub history entry adding this file.
- No Phase 8-specific runtime security test has passed yet. This document is a persistent checkpoint, **not completion evidence**.

## SEC-02 / SEC-06 — staging read-only verification, 2026-11-05

**Actually checked:** Staging Edge Function inventory reports `process_tournament_refund` (v1), `create_owner_web_checkout` (v2), and `get_owner_web_checkout_status` (v2) ACTIVE with `verify_jwt=true`. The deployed refund function additionally checks a bearer token against service-role / internal-worker secret or verifies a user and privileged role; its `process_queue` branch rejects non-internal callers. **This is code/config inspection, not a passed live 401/403 test or idempotency test.** The staging inventory returned only these three functions; payment webhook and FCM availability remain unverified/incomplete.

Staging read-only SQL privilege inspection:
| Function | anon EXECUTE | authenticated EXECUTE |
|---|---|---|
| `admin_approve_owner_atomic` | false | true |
| `get_admin_metrics` | false | true |
| `claim_next_cancellation_refund_atomic` | false | false |

An authenticated grant alone is **not** proof that admin-only authorization is enforced; the function body and cross-role behavior still require validation. No SQL permissions were modified. No refunds were triggered.

**Next:** inspect `admin_approve_owner_atomic` and `get_admin_metrics` body authorization; verify owner checkout ownership and server-side price; then run staging negative tests without creating charges.

## SEC-06 finding: checkout status authorization (2026-11-05)

**Severity: P1 pending exploit verification; status: BLOCKED for patch.** Source: `supabase/functions/get_owner_web_checkout_status/index.ts`. The status endpoint currently treats either matching `owner_id` or matching `checkout_email` as sufficient ownership. The latter is contact information, not an authorization principal. A verified user whose email matches contact information supplied for a different owner's checkout may pass the authorization branch. The service-role database read happens before that branch, making the server-side check essential.

**Proposed minimal correction:** restrict non-admin access to `order.owner_id === callerUser.id`; retain the separately verified administrator role check. Do not use `checkout_email` as an authorization factor. Preserve existing payment amount and subscription behavior.

**Test matrix (NOT RUN):** owner reads own order; unrelated authenticated user denied even when order contact email matches their verified email; unrelated user denied with different email; admin allowed; unauthenticated 401; malformed order ID 400; no payment inquiry or subscription mutation for unauthorized users. Confirm deployed staging function matches patched source before declaring DONE.

A direct GitHub source update was attempted but the execution tool blocked the write; **no source fix was committed or deployed**. Do not describe this finding as resolved.

## SEC-06 implementation checkpoint (2026-11-05)

- **PATCH COMMITTED** `3fbb2f58`: `supabase/functions/get_owner_web_checkout_status/index.ts` now checks non-admin ownership exclusively by `order.owner_id === callerUser.id`, removing the contact-email fallback.
- **REGRESSION CONTRACT COMMITTED** `8b6f65d0`: `test/owner_checkout_authorization_contract_test.dart` asserts the server-side owner-id guard, absence of the email fallback, and explicit denial branch. This is a static source regression test, **not** a live cross-account authorization test.
- **Status:** IN PROGRESS. Await Flutter CI execution of the new test and deploy/reverify the updated function on Staging. No deployment or live 401/403/owner-vs-other-account test has occurred; production remains unchanged.
- The prior entry noting a blocked write is historical; the subsequent write succeeded.

## Verification checkpoint — 2026-11-05

- GitHub Actions Flutter CI run **42030240411**, commit `0dbe13fa`: **SUCCESS**; both `Analyze` and `Test` steps succeeded. This includes the initial SEC-06 static source regression test at commit `8b6f65d0`. This does **not** establish live deployed authorization correctness.
- Android E2E Smoke run **42028838602**, commit `497acf4b`: **FAILED**, Android onboarding/login smoke step; logs show the emulator/application started but the driver did not complete within its allotted time. Do not mark the Android journey passed.
- SEC-03/06 additional code patch `f2c38de6`: checkout status function no longer selects unused `checkout_email`; corresponding regression update `26bcb2d5`. CI result for these newer commits **not yet verified**.
- Outstanding: deploy to Staging only when deployment process and required settings are verified; run real two-account negative tests and repeat CI. Production not modified.

## SEC-06 verified checkpoint (2026-11-05)

- Staging Edge Function `get_owner_web_checkout_status` deployed ACTIVE v3 with JWT verification enabled. Post-deploy inspection confirmed strict owner-id authorization and removal of checkout-email fallback.
- Flutter CI run `42033265264` for commit `a83987f1` passed both Analyze and Test. The earlier failing run `42032520519` was corrected by fixing a malformed newline in the static security test.
- Still required: live two-account and admin authorization tests on staging; static tests and deployed-source inspection are not equivalent to live authorization verification.
- Android emulator E2E remains failed from run `42028838602`. Production and main were not changed.
