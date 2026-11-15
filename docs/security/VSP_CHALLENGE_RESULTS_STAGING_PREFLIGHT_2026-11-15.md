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
