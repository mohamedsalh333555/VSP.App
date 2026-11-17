# VSP — FCM queue retry and provider failure source contracts

**Date:** 17 November 2026. **Scope:** `48.03`, `48.05`, `48.07` — bounded FCM queue worker behavior, no real external FCM sends, no hosted migration, no new queue table, no production deployment.

## Confirmed issue
The existing worker treated any HTTP 2xx from the `fcm_push` function as a successful dispatch and archived the PGMQ message. A syntactically malformed 200 or `success:false` could be lost. Its logs could also include full provider result and internal error text.

## Change
- Introduce a pure typed response classifier and batch processor; only `success:true` with positive sent count or explicit `skipped/no_fcm_token` allows archive. Every malformed or failed reply leaves the message unarchived for PGMQ visibility timeout retry.
- Observe attempted, delivered, skipped, pending retries, archive errors and partial-device failures without user data, provider body, exception or token logging.
- Record and preserve at-least-once semantics: a send succeeded but archive failed can be sent again later; per-device exact-once delivery needs a durable idempotent delivery ledger (NOT in this batch). A partial-device failure archives after at least one success to avoid re-sending the whole message to devices already reached; residual failures need independent per-device queue tracking.
- Deny missing service configuration and DB queue errors without leaking detailed internal error strings.
- Add isolated Deno tests for FCM 502 outage, contradictory 200, recovery on third attempt, duplicate-archive avoidance in clean run, no-token skip, archive error, batch continuation, and safe log abstraction; GitHub CI path trigger.

## Acceptance
**After CI:** 48.03 / 48.05 / 48.07 ACCEPTED NARROWLY for worker-level modeled outage/retry: [FCM Deno CI SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44133120292) on [27814f](https://github.com/mohamedsalh333555/VSP.App/commit/27814f65bd097259ecb5ebaacea1f8e81543518a). Does not prove actual FCM, cron invocation identity, production delivery, real PGMQ visibility, or external network recovery.

**Unchanged:** 48.02 durable attempt log and 48.04 send-rate limits remain open. Count now 633 total / 272 accepted / 361 remaining; +3 accepted IDs, no additional unique task IDs.
