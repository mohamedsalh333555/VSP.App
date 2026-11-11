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
