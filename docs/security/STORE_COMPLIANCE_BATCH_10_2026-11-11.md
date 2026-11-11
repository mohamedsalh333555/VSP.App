# Batch 10 — blocked administrator RLS/storage and self-unblock

Date: 2026-11-11. Existing Phase8 SEC-02/SEC-09 and Phase9 acceptance. Core remains81 accepted/539 pending of620; no duplicate task closures.

## Confirmed P0 defects

1. A blocked administrator can update their own users.is_blocked to false: the sensitive-field trigger accepts admin role without checking actor block state. Reproduced on staging using one fresh synthetic account, inside a transaction followed by rollback. No production exploit or customer-row test.
2. Of42 reviewed admin-role public/storage policies,37 omit the active-actor condition (28 public policies plus9 storage policies;21 tables total). These enable blocked admin privileges in application settings, moderation, documents, sports data or storage. This is a scoped42-policy audit, not every policy in the database.

## Implementation

- Add is_blocked=false to the existing sensitive-field trigger's administrator predicate. Preserve authorized server override/service paths and ordinary profile editing. No trigger deletion or new definer API.
- Narrowly add active-actor checks inside the reviewed administrative policy branches. Preserve original role lists, ownership/public/service branches, policy role lists, commands and permissiveness. Mixed owner/admin membership keeps the ordinary-owner branch; scalar role subqueries return no privileged role for blocked actors.
- Compare current source and metadata against known before/after definitions, fail closed on drift, and alter policies in place. Function SHA-256 protects the trigger body; OID/ACL/configuration remain unchanged. Missing policies are not invented: staging has28 of37, production has37;9 storage policies are production-only.
- Canonical PostgreSQL deparser output was captured with PGlite: all37 original definitions exactly match observed production sources;28 shared staging definitions are identical.65 environment observations reduce to37 unique policy definitions.
- Add a source-checked emergency inverse outside forward migrations. No pricing, subscription policy, business-rule value, customer account, storage object or financial data changed by this migration.

## Executed local verification

6 policy-planner tests pass. Seven SQL suites pass on PGlite0.3.14;11 deliberately weakened guards are rejected; restored baselines, idempotent replay, unknown-policy drift refusal and inverse/forward round trip pass. Positive tests preserve active admin/cofounder configuration and scalar-role access, owner document/storage access and owner championship creation, plus public paid-participant visibility. Negative tests cover self-unblock, application/business configuration writes, private document/storage access, banner upload, unpaid-participant access and missing profiles.

The fixture includes37 actual policy definitions and metadata-based dependencies with limited constraints. It is not a complete Supabase schema, OAuth/concurrency test or all37 business flows. PGlite is preflight; native PG17.6 CI and hosted rollout/readback are pending at this source commit. No task is accepted or production deployment claimed before that evidence.

Policies: [Apple1.6 data security](https://developer.apple.com/app-store/review/guidelines/#data-security), [Google User Data](https://support.google.com/googleplay/android-developer/answer/10144311). Existing obligations; no new policy effective date asserted. Review/execution date2026-11-11.
