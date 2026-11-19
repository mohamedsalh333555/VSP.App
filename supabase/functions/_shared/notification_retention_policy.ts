/**
 * Conservative user-inbox retention decision (49.01).
 * This code never deletes records: an explicit opt-in cleaner would be a
 * separate, audited operation. Transactional/audit-linked events are kept.
 */
export type InboxRetentionRow = {
  type?: unknown;
  is_read?: unknown;
  created_at?: unknown;
  booking_id?: unknown;
  metadata?: unknown;
};

export type RetentionDecision = {
  eligible: boolean;
  reason: "expired_reminder" | "active_or_unread_grace" |
    "protected_or_unknown_type" | "linked_to_booking_or_audit" |
    "unverified_timestamp_or_read_state";
  retention_days?: number;
};

const eligibleReminderTypes = new Set([
  "match_reminder", "match_start_reminder", "daily_schedule",
]);

/**
 * Engineering defaults, not a legal retention determination:
 * - Read, unlinked reminders: 90 elapsed UTC days.
 * - Unread, unlinked reminders: 180 elapsed UTC days.
 * - All unknown/transactional/audit-linked content: retained for review.
 *
 * Financial/bookings/audit records are NEVER in this candidate set.
 * A real cleanup must also verify no PGMQ delivery is pending and obey
 * deletion holds and data-subject requests.
 */
export function evaluateInboxRetention(
  row: InboxRetentionRow,
  now: Date,
): RetentionDecision {
  const keep = (reason: RetentionDecision["reason"]): RetentionDecision =>
    ({ eligible: false, reason });

  if (!row || typeof row !== "object" || Array.isArray(row)) {
    return keep("protected_or_unknown_type");
  }
  if (typeof row.type !== "string" ||
      !eligibleReminderTypes.has(row.type.trim().toLowerCase())) {
    return keep("protected_or_unknown_type");
  }
  // A booking ID, nonempty metadata, or malformed linkage must fail closed.
  if (row.booking_id !== null && row.booking_id !== undefined &&
      row.booking_id !== "") {
    return keep("linked_to_booking_or_audit");
  }
  if (row.metadata !== null && row.metadata !== undefined &&
      (typeof row.metadata !== "object" ||
       Array.isArray(row.metadata) ||
       Object.keys(row.metadata as Record<string, unknown>).length > 0)) {
    return keep("linked_to_booking_or_audit");
  }
  if (typeof row.is_read !== "boolean" ||
      typeof row.created_at !== "string" ||
      !/T\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$/i.test(row.created_at)) {
    return keep("unverified_timestamp_or_read_state");
  }
  const created = new Date(row.created_at);
  if (!Number.isFinite(now.getTime()) ||
      !Number.isFinite(created.getTime()) ||
      created.getTime() > now.getTime()) {
    return keep("unverified_timestamp_or_read_state");
  }
  const retentionDays = row.is_read ? 90 : 180;
  const elapsedMs = now.getTime() - created.getTime();
  if (elapsedMs < retentionDays * 24 * 60 * 60 * 1000) {
    return { eligible: false, reason: "active_or_unread_grace", retention_days: retentionDays };
  }
  return { eligible: true, reason: "expired_reminder", retention_days: retentionDays };
}
