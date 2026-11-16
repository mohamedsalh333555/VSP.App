# VSP — Challenge Results Staging Preflight (2026-11-15)

**Status:** CODE_CANDIDATE; never treat these SQL tests as a release approval. Branch `uxlp-44-implementation`, draft PR #35. Canonical count remains 209 accepted / 421 open / 630 total.

## Staging observations (read-only)

- Project `vtwgqyxglevcsxwdmhop` had 21 challenge bookings: 20 with finalized outcomes, 0 legacy pending single submissions requiring migration and 0 confirmed bookings retaining a pending outcome value. Recheck the same aggregate immediately before rollout.
- `authenticated` currently has column SELECT permission on `public.bookings.pending_outcome`; hiding UI data is insufficient while legacy writers can put outcomes there. New submissions must be private at the database level.
- Existing triggers include `trg_calculate_elo`, `trg_normalize_booking_pending_fees`, `trg_sync_booking_public_feed` and booking security guards. Do not assume the local synthetic test models every real trigger.
- The installed `normalize_booking_pending_fees` function can zero commission/platform/gateway fields for unpaid bookings on an otherwise unrelated booking update. Preflight and staging E2E must compare unchanged finance fields before/after results.
- `sync_booking_public_feed` copies finalized results. The non-played candidate writes a private report and team counters but does not automatically remove a previously confirmed result from the public feed. **Block the rollout** until every public feed, team history and standings consumer filters excluded records; an opt-in player status banner alone is not enough.
- New private audit and appeal tables use cascade FKs so bookings can be removed without dangling private rows, but a separate retention/deletion policy is still necessary.

## Run metadata-only preflight

Execute `supabase/tests/read_only_challenge_result_rollout_preflight.sql` on staging with read-only privileges. It emits only column metadata, aggregate counts, function/trigger signatures and table/grant flags; no names, IDs or user records. The same SQL is also syntax-checked in the disposable PostgreSQL CI fixture, **not** executed on hosted staging by CI.

## Blocking acceptance gates

1. Preserve all historic confirmed outcomes and current team totals; migrate any one-sided pending votes without fabricating a second captain's choice.
2. Install the independent submissions schema and replace the old RPC atomically; no simultaneous legacy writers and no direct vote SELECT for players/owners.
3. Real JWT tests with two captains, unauthorized third person, owner, admin and anonymous role; test PostgREST, Realtime and logs as well as UI.
4. Report exclusion, appeal, review and restoration must instantly agree across home and owner views, team rankings and public feed, without extra wins or matches.
5. Recheck all payment/deposit/fee/refund/fair-play and subscription fields before and after every operation, including unpaid challenges, and preserve monetary no-show behavior separately.
6. Verify account deletion and audit retention, 24-hour approval schedulers, actual app integrations, network retries, Arabic/English layouts, independent concurrency and rollback rehearsal.

## Abort/rollback policy

Record a reliable point-in-time database snapshot and old SQL/permissions first. If a gate fails, stop the new feature and restrict its RPC write permissions rather than blindly restoring the single-pending-result implementation over independent votes. Audit and reconcile the original outcomes, rankings and report events in an isolated transaction before reopening. No automatic production rollout or `main` merge.

## Verified public-feed function defect (read-only staging inspection)

The installed `trg_sync_booking_public_feed` runs `public.sync_booking_public_feed()` after **every** booking INSERT/UPDATE/DELETE. Its `ON CONFLICT ... DO UPDATE` contains `opponent_team_logo_url=excluded.opponent_team_logo`, while the table and INSERT target have only `opponent_team_logo_url`. This is a confirmed **source/schema mismatch**, not yet a reproduced hosted mutation failure. It can block public-booking writes when the upsert executes. See [minimal one-reference correction candidate](sql/booking_public_feed_logo_sync_fix_candidate.sql) and [isolated SQL lifecycle contract](../../supabase/tests/booking_public_feed_logo_sync_contract.sql). **Neither was applied to Staging or Production.** Deployment needs explicit schema fingerprint recheck, a real staging dry-run, RLS/privilege review, financial invariance tests and rollback plan.

## Dormant incompatible Elo function (read-only staging; 2026-11-16)

Staging retains the old `public.reconcile_daily_elo_ratings()` SECURITY DEFINER routine,
which awards an Elo-like score to confirmed challenges with `elo_processed=false`.
The deployed trigger uses **3/1/0 competition points**, so invoking the old
function on such rows could corrupt ranking totals. Read-only counts showed **zero**
confirmed unprocessed challenges and **zero** cron jobs referencing the old function
at inspection: this is dormant risk, not a verified customer incident.

The optional [no-op compatibility SQL](sql/challenge_legacy_elo_reconciliation_guard_candidate.sql)
preserves the callable signature and trusted service role without reprocessing any row.
The [disposable PostgreSQL fixture](../../supabase/tests/challenge_captain_private_result_contract.sql)
calls it twice on a synthetic unprocessed confirmed challenge and asserts the full team
and booking snapshots (including paid/deposit/fair-play fields) remain unchanged.
It has **not** been deployed on staging or production; historical reconciliation
and a migration/rollback approval remain separate gates.
