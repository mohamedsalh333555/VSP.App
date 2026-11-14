# Batch 07 — active-admin RPC preconditions

Date: 2026-11-11. Phase 8 SEC-02/SEC-06/SEC-09 and existing Phase 9 acceptance; no duplicate task closures.

## Confirmed defect / P0

32 reviewed SECURITY DEFINER PL/pgSQL admin routines lack a uniform active-actor check. Examples: owner subscription and 1v1 administration use CURRENT_USER, which reflects the definer; other routines accept a blocked administrator or a missing profile through incomplete checks. No production business mutation was attempted to demonstrate this.

The migration adds one private invoker-helper precondition to each known existing body. SHA-256 before/after fingerprints reject unreviewed concurrent changes. Function OIDs, ACLs, signatures, defaults and the business body remain intact. The helper checks signed JWT service role or an existing unblocked admin/cofounder profile; only genuine trusted native DB maintenance without a client role has a separate exception. User metadata and system_override are ignored. No subscription duration, price or model changes.

40 source variants cover 32 signatures in production/staging, including CRLF-preserving variants. Missing routines are not invented. Deployment readback must confirm all 32 targets in each hosted environment; the isolated fixture deliberately has only three real admin RPC bodies.

## Executed local evidence

- 9 planner unit tests pass (comments/strings, Unicode offsets, CRLF, hash/inventory drift and source omission).
- PGlite 0.3.14: six SQL suites pass, seven deliberately weakened security variants are detected, restored baseline and idempotent replay pass.
- Synthetic positive cases cover subscription assignment, blocking plus audit row, and no-show reset. Negative cases cover anonymous, player, owner, blocked admin, missing profile and missing subject, including spoofed user metadata. Direct helper checks cover four admin role aliases, service JWT and trusted maintenance.
- PGlite is single-connection preflight, not native PostgreSQL/concurrency/OAuth evidence. Native PG17.6 CI and hosted deployment results must be added before accepting rollout.

## Separate dashboard delivery (batch 06)

Private dashboard PR #9 was merged after owner standing authorization. Validated head 76e3dfad230d7076babdd637c957ac6818360702; merge 91964ad9d6ea38ee156c91a0a0df55d910d3b82d. CI run 42963826004 succeeded: 53 Node tests, npm audit zero findings and Vite build on Node 22. Fixes cover session/profile races, OAuth hash preservation, confirmed mutation responses, avatar identity/persistence and safe auth failures. Hosted deployment and real Google OAuth remain separately unverified.

## Acceptance

Core ledger remains 81 accepted / 539 pending of 620. These are scoped fixes, not 32 complete parent requirements or overall store readiness. No iOS build, signed release, Data Safety/App Privacy submission, or real multi-account journey is claimed here.

## Hosted rollout and native CI receipt

- Source commit: 379adb4c50aaee40c74221ff054bca5f9fc3fdb2.
- Native PostgreSQL 17.6 [run 42965386816](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42965386816), job 130341288584: SUCCESS. Six suites, seven weakened guards detected, restored baselines, idempotency, unknown-source refusal, clean accounts and existing-database refusal. 9 target-guard and 9 planner Python tests pass.
- Staging migration applied; exact after-fingerprints verified on all 32 routines before probes. **192 negative calls / 32 RPCs / six actor contexts rejected**. The initial probe expected every denial to throw; two existing exception handlers instead returned explicit success:false with ADMIN_ACCESS_REQUIRED. The corrected probe accepts only those two exact response contracts. No security condition was weakened.
- Staging positive contract succeeds for subscription assignment, block plus audit log, no-show reset, all admin aliases/service/native contexts. All fixture rows and temporary grants rolled back; zero matching fixture Auth accounts remain.
- Production migration applied after staging/native verification. Read-only checks verify **32/32 known after-fingerprints**, original OIDs, owners, ACLs, proconfig and definer flags preserved. The new helper is invoker and not executable directly by anon/authenticated/service_role. No production business operation or customer-row test was run.
- Advisors unchanged: production 197 callable-definer findings + 1 deferred password-protection warning; staging 200 callable-definer + 4 public-extension + 1 deferred password warning. The extra invoker helper adds no definer finding. This patch does not resolve all historical warnings.
- Emergency inverse is outside forward migrations and refuses unknown source. Its local PGlite inverse/forward round trip passes; native CI round-trip coverage is added in the follow-up commit.
- Dashboard merge 91964ad deployed: GitHub Vercel commit status SUCCESS. Live production page rendered the Google-only sign-in button and authorized-admin notice, no password form. The deployed JS includes new identity-mismatch and safe-failure markers. Real Google sign-in and post-login navigation remain unverified.
- Machine-readable metadata: [batch evidence](STORE_COMPLIANCE_BATCH_07_EVIDENCE_2026-11-11.json). Staging-only all-RPC denial script is not part of the three-RPC native fixture.
- Core remains **81 accepted / 539 not fully accepted /620**. Full Flutter/Android checks were still running at this receipt's creation; later results must be recorded separately. App main not merged; private dashboard main merged under standing owner approval.

Policy alignment: [Apple App Review Guidelines 1.6](https://developer.apple.com/app-store/review/guidelines/#data-security), [Google Play User Data](https://support.google.com/googleplay/android-developer/answer/10144311). These are existing access/data-security obligations, not a newly announced policy effective date. Execution/observation date is 2026-11-11; this narrow fix does not prove complete store compliance.
