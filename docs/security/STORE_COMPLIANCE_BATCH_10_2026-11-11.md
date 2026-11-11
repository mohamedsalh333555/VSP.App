# Batch 10 — blocked administrator RLS/storage and self-unblock

Date: 2026-11-11. Existing Phase8 SEC-02/SEC-09 and Phase9 acceptance. Code-patch baseline:81 accepted/539 pending of620. Final acceptance below adds documentation80.07 only, reaching82/538; no duplicate runtime closures.

## Confirmed P0 defects

1. A blocked administrator can update their own users.is_blocked to false: the sensitive-field trigger accepts admin role without checking actor block state. Reproduced on staging using one fresh synthetic account, inside a transaction followed by rollback. No production exploit or customer-row test.
2. Of42 reviewed admin-role public/storage policies,37 omit the active-actor condition (28 public policies plus9 storage policies;21 tables total). These enable blocked admin privileges in application settings, moderation, documents, sports data or storage. This is a scoped42-policy audit, not every policy in the database.

## Implementation

- Add is_blocked=false to the existing sensitive-field trigger's administrator predicate. Preserve authorized server override/service paths and ordinary profile editing. No trigger deletion or new definer API.
- Narrowly add active-actor checks inside the reviewed administrative policy branches. Preserve original role lists, ownership/public/service branches, policy role lists, commands and permissiveness. Mixed owner/admin membership keeps the ordinary-owner branch; scalar role subqueries return no privileged role for blocked actors.
- Compare current source and metadata against known before/after definitions, fail closed on drift, and alter policies in place. Function SHA-256 protects the trigger body; OID/ACL/configuration remain unchanged. Missing policies are not invented: staging has29 of37 targets, production has37;8 storage policies are absent from staging. One staging policy already uses the active-admin helper and is preserved exactly.
- Canonical PostgreSQL deparser output was captured with PGlite: all37 original definitions exactly match observed production sources;28 shared staging definitions are identical.65 environment observations reduce to37 unique policy definitions.
- Add a source-checked emergency inverse outside forward migrations. No pricing, subscription policy, business-rule value, customer account, storage object or financial data changed by this migration.

## Executed local verification

6 policy-planner tests pass. Seven SQL suites pass on PGlite0.3.14;11 deliberately weakened guards are rejected; restored baselines, idempotent replay, unknown-policy drift refusal and inverse/forward round trip pass. Positive tests preserve active admin/cofounder configuration and scalar-role access, owner document/storage access and owner championship creation, plus public paid-participant visibility. Negative tests cover self-unblock, application/business configuration writes, private document/storage access, banner upload, unpaid-participant access and missing profiles.

The fixture includes37 actual policy definitions and metadata-based dependencies with limited constraints. It is not a complete Supabase schema, OAuth/concurrency test or all37 business flows. PGlite is preflight; native PG17.6 CI and hosted rollout/readback are pending at this source commit. No task is accepted or production deployment claimed before that evidence.

Policies: [Apple1.6 data security](https://developer.apple.com/app-store/review/guidelines/#data-security), [Google User Data](https://support.google.com/googleplay/android-developer/answer/10144311). Existing obligations; no new policy effective date asserted. Review/execution date2026-11-11.

## Staging drift guard correction before rollout

First native CI43012328103/job130494780894 succeeded with7 suites,11 mutants,24 Python tests, exact37-policy catalog, inverse/replay/drift gates. The first staging apply then refused an unexpected storage policy and rolled back the entire DO block. Follow-up inventory by target names (rather than admin-role text search) found one existing secured policy using is_admin_or_cofounder; it had been omitted by the initial text-filtered inventory. Staging therefore has29 targets, not28:28 need changes,1 already guarded,8 absent. No first-attempt migration or partial policy update is claimed.

Added an exact approved alternate policy definition and helper SHA-256/definer/search-path checks, preserving its ownership behavior. Unknown alternate sources/helper drift still abort. PGlite alternate-policy behavior and weakened-helper refusal both pass. Follow-up native CI must pass before retrying hosted rollout.

## Final verification/deployment receipt — 2026-11-11

Runtime source: f26bd2923d08e702fe72c02805ba63f54dca322e. Native PostgreSQL17.6 [run43012907874](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43012907874), job130496691542 SUCCESS:7 SQL suites,11 weakened guards rejected,24 Python tests, all37 policy definitions/metadata, idempotency, both inverse/forward round trips, unknown source refusal, reviewed existing variant preservation, changed-helper refusal, fresh DB protection and zero account fixtures.

Staging migration20261111113436 succeeded after reviewing the initial refused variant. Readback:28 primary definitions corrected,1 exact pre-existing guarded storage policy preserved,8 policies absent. Trigger hash matches the reviewed new body. A transaction-only real staging probe rejects self-unblock and another owner's object metadata, preserves own profile/file access and ordinary-owner file access, and permits authorized founder moderation. Zero fixture Auth accounts remain. No actual file upload/download or GoTrue session was tested. An initial metadata DELETE probe was not executed because tool confirmation expired; the executed replacement uses storage reads. An initial moderation fixture used ordinary admin against an admin target and correctly hit the existing founder-only restriction; the corrected fixture uses co_founder without changing that product restriction.

Production migration20261111115824 succeeded. Read-only checks confirm37/37 exact primary policy definitions and expected sensitive-trigger SHA-256. Original policy OIDs, roles, commands, permissiveness and table ACLs are preserved. Trigger function OID, owner, ACL, search path and definer mode are preserved. Three sensitive bucket flags (owner_documents, deposit-receipts, verification-documents) are private. No production account/customer/storage/business-row test or mutation was performed.

Advisors unchanged before/after: production197 callable-definer findings +1 deferred leaked-password warning; staging200 callable-definer +4 public-extension +1 deferred password warning. These warnings are not declared resolved.

All runtime-source checks green:
- Flutter [43012907821](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43012907821):1142 passed/10 skipped,54 focused privacy cases, analyzer/architecture gates.
- Android [43012907900](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43012907900):2 smoke cases,6 permission-gate tests and actual compiled APK inspection.
- iOS [43012907858](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43012907858):Xcode26.3, SDK26.2,43.9MB unsigned Runner.app, correct bundle/minimumOS,38 SDK privacy manifests and8 gate tests.
- Checkout [43012907769](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43012907769):39 Deno cases.

Website delivery additionally verified live: production deletion page exposes new bounded/labeled fields, and its served JavaScript contains timeout, duplicate-state and safe receipt logic. No customer deletion request submitted.

[Machine-readable evidence](STORE_COMPLIANCE_BATCH_10_EVIDENCE_2026-11-11.json). [Documented release acceptance policy](RELEASE_ACCEPTANCE_POLICY.md) completes80.07 as a documentation deliverable only. Corrected stale commission/deletion claims in LAUNCH_CHECKLIST without changing model/prices or marking its tests done. Task accounting: **82 accepted/538 pending/620**,82 parent items,0 consistency errors. No other parent/runtime task auto-closed.

**Store readiness remains HOLD:** real-session/multi-account journeys, actual provider delivery/payment evidence, signed store artifacts, console disclosures and unresolved full-scope audits remain open. The final documentation receipt changes documentation and the manually executed staging probe only; runtime evidence refers to the exact tested code SHA above. App main was not merged.
