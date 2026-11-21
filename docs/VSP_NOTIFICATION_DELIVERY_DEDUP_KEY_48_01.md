# 48.01 — Logical notification delivery deduplication key

**Decision:** use the persisted `public.notifications.id` as the logical delivery identity for a notification. For each delivery channel and target device, the recommended idempotency identity is **`(notification_id, channel, destination_token_hash)`**; for a user-level inbox entry, use **`notification_id`** alone. Never deduplicate solely by message text, title, recipient or booking ID: legitimate repeated reminders may have identical content.

**Source evidence:** `supabase/migrations/202608110005_pgmq_notifications_queue.sql` enqueues a message containing `notification_id: NEW.id` on insertion into `public.notifications`. The queue payload also contains `user_id`, `type`, `booking_id`, `created_at`, title and body. `lib/core/repositories/notification_repository.dart` maps and streams notifications by `id`. This means the identifier needed for deduplication already exists in the source contract.

**Implementation boundary:** the migration passes `notification_id` into the queue but does **not**, by itself, prove a unique delivery-attempt constraint or exactly-once FCM delivery. Task 48.02 must persist attempts, 48.03 implement safe retries, 48.04 enforce limits, and 48.05–48.07 test provider failure, redelivery and logical once-only semantics. Use a durable server-side unique constraint or atomic claim keyed by the delivery identity; an in-memory mobile cache is insufficient. The destination token hash must not expose a raw FCM token in logs.

**48.01 complete:** deduplication identity is specified with source evidence and explicit delivery-channel scope. No queue/schema/FCM change was applied.
