# VSP — Technical retention classification for notification inbox (49.01)

2026-11-17, `uxlp-44-implementation`. Draft engineering policy **implemented as a pure classifier**, with automatic deletion expressly disabled.

## Verified live schema (read-only)
Staging and Production `public.notifications` have identical columns: `id` UUID, `user_id` UUID, `title`/ `body`, `type`, `is_read`, `booking_id`, `metadata`, `created_at` timestamptz and `message`. No notification row was fetched or modified.

## Proposed candidate criteria
- Only allowlisted, **unlinked** reminder types (`match_reminder`, `match_start_reminder`, `daily_schedule`) may become candidates for deletion from the *user-facing notification inbox*.
- A read reminder is eligible after **90 elapsed UTC days**; unread after **180 elapsed UTC days**. Durations are **engineering defaults**, subject to product and legal review before any real purge.
- Any booking association, nonempty or unrecognized metadata, invalid timestamp/read state, future date, financial/refund/transaction item, unrecognized type or legal/audit linkage means **retain**.
- Never apply this candidate policy to `bookings`, Paymob records, regulatory or incident audit trails, provider receipts, security logs, user accounts or financial ledgers.
- **No deletion job** is enabled. Later 49.02/49.05/49.07 require inventory of foreign keys/triggers, PGMQ pending messages, legal holds, backups, consent/deletion requests, and isolated staging restore/rehearsal before deployment. Privacy counsel must approve durations.

## Code and tests
`supabase/functions/_shared/notification_retention_policy.ts` returns a typed decision without fetching, logging or modifying row data. The offline Deno CI exercises day boundaries, unread grace, transaction/booking/audit exclusions, malformed timestamps and Cairo offset comparison. No cron, migration or production access.

**49.01 narrowly eligible for documentation/decision-contract acceptance only after exact commit CI**; 49.02/03/05/06/07 remain open. In isolation this source cannot fulfill legal compliance or user deletion requests.
