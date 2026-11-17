/**
 * Pure queue-delivery contract. A successful HTTP response alone is NOT proof
 * of FCM dispatch. A notification remains in pgmq until a recognized outcome
 * has been archived. This intentionally preserves at-least-once semantics.
 */
export type QueueMessage = { msg_id: number | string; message: unknown };

/** An invalid RPC response must never be treated as an empty queue.
 * pgmq_read returns a JSON array of messages (including [] when empty).
 */
export function isValidPgmqReadBatch(value: unknown): value is QueueMessage[] {
  if (!Array.isArray(value)) return false;
  return value.every((row) => {
    if (!row || typeof row !== "object" || Array.isArray(row) || !("message" in row)) {
      return false;
    }
    const id = (row as { msg_id?: unknown }).msg_id;
    return (typeof id === "number" && Number.isSafeInteger(id) && id > 0) ||
      (typeof id === "string" && /^[1-9][0-9]*$/.test(id));
  });
}
export type QueueStats = {
  attempted: number;
  delivered: number;
  skipped_no_token: number;
  retry_pending: number;
  archive_failed: number;
  partial_device_failures: number;
  rate_limited: number;
};

export type QueueDeps = {
  dispatch: (message: unknown) => Promise<Response>;
  archive: (msgId: number | string) => Promise<{ data?: unknown; error?: unknown }>;
  log: (event: string, msgId: number | string) => void;
};

export async function classifyFcmReply(response: Response): Promise<"delivered" | "partial" | "no_token" | "retry"> {
  if (!response.ok) return "retry";
  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return "retry";
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) return "retry";
  const result = body as Record<string, unknown>;
  if (result.status === "skipped" && result.reason === "no_fcm_token") {
    return "no_token";
  }
  if (result.success !== true) return "retry";
  const sent = result.sent_count, failed = result.failed_count;
  if (!Number.isSafeInteger(sent) || !(typeof sent === "number" && sent > 0)) return "retry";
  if (!Number.isSafeInteger(failed) || !(typeof failed === "number" && failed >= 0)) return "retry";
  return failed > 0 ? "partial" : "delivered";
}

/** Extract an owner only to apply in-memory fairness, never for logs. */
function recipientOf(message: unknown): string | null {
  if (!message || typeof message !== "object" || Array.isArray(message)) return null;
  const root = message as Record<string, unknown>;
  const record = root.record && typeof root.record === "object" && !Array.isArray(root.record)
    ? root.record as Record<string, unknown>
    : root;
  const id = record.user_id ?? record.userId;
  return typeof id === "string" && id.length > 0 ? id : null;
}

/** A conservative per-invocation bound. Cross-invocation limits require a
 * persistent, atomic recipient delivery ledger and stay out of this scope.
 */
export const FCM_QUEUE_MAX_PER_INVOCATION = 5;
export const FCM_QUEUE_MAX_PER_RECIPIENT = 2;

/** Never log notification payload, error response body, device token or user ID. */
export async function processFcmQueueMessages(
  messages: QueueMessage[], deps: QueueDeps
): Promise<QueueStats> {
  const stats: QueueStats = {
    attempted: 0, delivered: 0, skipped_no_token: 0,
    retry_pending: 0, archive_failed: 0, partial_device_failures: 0,
    rate_limited: 0,
  };
  const attemptedByRecipient = new Map<string, number>();
  for (const msg of messages) {
    const recipient = recipientOf(msg.message);
    // Keep the message unarchived. PGMQ visibility timeout permits fair
    // replay on the next invocation; never silently discard overflow.
    if (stats.attempted >= FCM_QUEUE_MAX_PER_INVOCATION ||
        (recipient !== null &&
         (attemptedByRecipient.get(recipient) ?? 0) >= FCM_QUEUE_MAX_PER_RECIPIENT)) {
      stats.rate_limited++;
      deps.log("rate_limited", msg.msg_id);
      continue;
    }
    stats.attempted++;
    if (recipient !== null) {
      attemptedByRecipient.set(recipient, (attemptedByRecipient.get(recipient) ?? 0) + 1);
    }
    try {
      deps.log("attempt", msg.msg_id);
      const response = await deps.dispatch(msg.message);
      const outcome = await classifyFcmReply(response);
      if (outcome === "retry") {
        stats.retry_pending++;
        deps.log("retry_pending", msg.msg_id);
        continue;
      }
      if (outcome === "partial") {
        // Some tokens received the message. Retrying the entire message would
        // duplicate those successful deliveries. Track residual failure for
        // manual review until per-device durable delivery exists.
        stats.partial_device_failures++;
        deps.log("partial_device_failure", msg.msg_id);
      }
      const archived = await deps.archive(msg.msg_id);
      // The actual hosted public.pgmq_archive RPC returns boolean.
      // Only an explicit true confirms the message was archived.
      // null/undefined/0/"true" must not count as delivery.
      if (archived?.error || archived?.data !== true) {
        stats.archive_failed++;
        deps.log("archive_failed", msg.msg_id);
        continue;
      }
      if (outcome === "no_token") stats.skipped_no_token++;
      else stats.delivered++;
      deps.log(outcome === "no_token" ? "skipped_no_token" : "archived_after_dispatch", msg.msg_id);
    } catch {
      stats.retry_pending++;
      deps.log("retry_after_exception", msg.msg_id);
    }
  }
  return stats;
}
