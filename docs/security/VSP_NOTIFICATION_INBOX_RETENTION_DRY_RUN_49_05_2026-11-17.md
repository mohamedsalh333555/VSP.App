# VSP — Notification inbox cleanup rehearsal, no deletion

**2026-11-17 · Branch `uxlp-44-implementation` · PR #35 draft**

## Scope

A **pure, non-destructive engineering rehearsal** for open tasks 49.02, 49.03, 49.05 and 49.07. Only 49.01 (retention *classification*) is already accepted. No timer, cron, SQL migration, API handler, database write, Storage deletion, production invocation, archive operation or permanent cleanup is introduced.

`supabase/functions/_shared/notification_retention_dry_run.ts` calls the already accepted 90/180-day conservative **candidate classifier** but never calls the database. It returns only aggregate totals: inspected, eligible for **human review**, retained by policy, and protected by external dependencies. It never returns any user ID, notification ID, title, body, device token or financial payload.

## Fail-closed gates

Before the reviewer can obtain a `review_only` count, the caller must affirm all six checks:

1. Foreign keys inspected; references supplied in a separate set
2. PGMQ/delivery backlog inspected; pending message IDs supplied
3. Legal holds inspected; held notification IDs supplied
4. Audit references inspected; protected IDs supplied
5. Backup **restore rehearsal** completed and independently evidenced
6. Privacy/legal review approved

All four dependency sets must be present (not assumed empty); input notification IDs must be valid, unique UUIDs. IDs are compared case-insensitively, matching PostgreSQL UUID semantics. Missing checks, missing references, invalid/duplicate IDs, or invalid date produce a **blocked report and zero candidates**. Individual booking-linked, financial, unknown-type and metadata-linked notifications are excluded by the underlying classifier. Any reference from PGMQ, foreign keys, legal holds or audit blocks review candidacy.

**Important:** the six booleans and four sets are caller-supplied assertions, **not verified evidence from hosted Supabase**. The current tool does not independently validate them and cannot authorize deletion. Even a `review_only` result explicitly returns `autoDeleteAllowed: false`. Do not connect it to production cleanup on the basis of these tests.

## Tests

- `supabase/functions/tests/notification_retention_dry_run_test.ts`: eligible versus protected counts; blocked missing gates and missing sets; invalid and mixed-case duplicate UUIDs; hold lookup with uppercase/lowercase UUID; rejection of malformed audit references; invalid observation time; mandatory privacy approval; no generated delete command.
- Existing `notification_retention_policy_test.ts`: 90/180-day UTC boundaries, unknown/financial/booking content retention, malformed timestamps and Cairo offsets.
- The GitHub workflow `.github/workflows/notification-inbox-retention-contract.yml` executes both with pinned Deno 2.2.12; check the actual run conclusion before accepting any task.

## Still required

A full foreign-key/trigger/PGMQ/schema inventory, permissioned staging data snapshot, isolated restore, legal basis and retention schedule approval, verified deletion scope and rollback plan, real role-based tests, and proof that financial/audit records survive an actual staged purge. **49.02/49.03/49.05/49.07 remain open**; this is source preparation and safe mock verification, not operational retention compliance.

## Accounting

Do not count source files, tests, or successful isolated CI as automatically completing the full hosted-cleanup tasks. The latest confirmed counter at the start of the batch was **633 total / 280 accepted / 353 open**. No main merge, APK or production operation.
