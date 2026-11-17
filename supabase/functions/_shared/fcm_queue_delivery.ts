/**
 * Pure queue-delivery contract. A successful HTTP response alone is NOT proof
 * of FCM dispatch. A notification remains in pgmq until a recognized outcome
 * has been archived. This intentionally preserves at-least-once semantics.
 */
export type QueueMessage = { msg_id: number | string; message: unknown };
export type QueueStats = {
  attempted: number;
  delivered: number;
  skipped_no_token: number;
  retry_pending: number;
  archive_failed: number;
  partial_device_failures: number;
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

/** Never log notification payload, error response body, device token or user ID. */
export async function processFcmQueueMessages(
  messages: QueueMessage[], deps: QueueDeps
): Promise<QueueStats> {
  const stats: QueueStats = {
    attempted: 0, delivered: 0, skipped_no_token: 0,
    retry_pending: 0, archive_failed: 0, partial_device_failures: 0,
  };
  for (const msg of messages) {
    stats.attempted++;
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
      if (archived?.error || archived?.data === false) {
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
