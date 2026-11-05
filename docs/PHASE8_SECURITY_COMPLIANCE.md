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
