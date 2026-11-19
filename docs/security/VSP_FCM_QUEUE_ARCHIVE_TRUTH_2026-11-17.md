# VSP FCM queue read / archive truth hardening

Date: 2026-11-17. Branch: `uxlp-44-implementation`.

## Verified basis
A read-only `pg_proc` inspection on both Supabase Staging and Production confirms:
- `public.pgmq_read(queue_name text, vt integer, qty integer)` returns `jsonb`.
- `public.pgmq_archive(queue_name text, msg_id bigint)` returns **boolean**.
No messages, tokens, personal data, or queue records were fetched or modified.

## Confirmed source weakness and fix
The worker previously treated invalid `pgmq_read` results as an empty queue (HTTP 200). The batch processor treated archive responses such as `{data:null}`, missing `data`, or `{data:0}` as successful archiving, even though the actual RPC returns a boolean.

A malformed queue read now returns a retriable server failure rather than reporting zero work. Only `archive.data === true` is treated as a confirmed archive; any other response records `archive_failed` and leaves the job available for visibility-timeout replay. Successful sends followed by failed archive are **at-least-once**, not exactly-once.

The isolated Deno test additions exercise malformed/empty batch distinctions, realistic bigint message IDs, rejection of null/false/wrong-type archive responses, and correct true-only acceptance. Existing FCM delivery tests are preserved.

## Evidence and release limits
Current code-only correction on branch; GitHub Actions CI must pass for exact SHA before citing validated tests. No Edge Function deployed, no Firebase live push sent, no production or Staging data mutation, no migration and no `main` merge.

This is not an additional accepted task: the existing notification retry IDs 48.03/48.05/48.07 remain narrowly accepted. Other notification delivery work (48.02/48.04, real-device testing and durable idempotency) remains open. 633 total / 272 accepted / 361 open.
