import { prepareInboxRetentionDryRun } from "../_shared/notification_retention_dry_run.ts";

const assert = (condition: unknown, message = "assertion failed") => {
  if (!condition) throw new Error(message);
};
const id = (num: number): string =>
  `00000000-0000-4000-8000-${num.toString(16).padStart(12, "0")}`;
const old = {
  type: "match_reminder", is_read: true,
  created_at: "2020-01-01T12:00:00Z",
  booking_id: null, metadata: {},
};
const gates = {
  foreignKeysInspected: true,
  deliveryQueueInspected: true,
  legalHoldsInspected: true,
  auditReferencesInspected: true,
  backupRestoreTested: true,
  privacyReviewApproved: true,
};
const input = () => ({
  rows: [
    { id: id(1), notification: old },
    { id: id(2), notification: { ...old, type: "payment" } },
    { id: id(3), notification: { ...old, booking_id: "booking-id" } },
    { id: id(4), notification: old },
    { id: id(5), notification: old },
    { id: id(6), notification: old },
    { id: id(7), notification: old },
  ],
  now: new Date("2026-11-17T00:00:00Z"),
  pendingDeliveryIds: new Set([id(4)]),
  legalHoldIds: new Set([id(5)]),
  auditReferenceIds: new Set([id(6)]),
  foreignKeyReferenceIds: new Set([id(7)]),
  checks: { ...gates },
});

Deno.test("dry-run retains payments and linked bookings and blocks all dependent reminders", () => {
  const result = prepareInboxRetentionDryRun(input());
  assert(result.status === "review_only");
  assert(result.autoDeleteAllowed === false);
  assert(result.inspected === 7);
  assert(result.candidateForHumanReview === 1);
  assert(result.retainedByPolicy === 2);
  assert(result.protectedByDependencies === 4);
  assert(JSON.stringify(result).includes("booking-id") === false);
  assert(JSON.stringify(result).includes(id(1)) === false);
});

Deno.test("missing independent verification blocks planning and reports no eligible rows", () => {
  const snapshot = input();
  const incomplete = prepareInboxRetentionDryRun({
    ...snapshot,
    checks: { ...snapshot.checks, backupRestoreTested: false },
  });
  assert(incomplete.status === "blocked");
  assert(incomplete.missingGates.includes("backupRestoreTested"));
  assert(incomplete.candidateForHumanReview === 0);
  assert(incomplete.inspected === 0);
});

Deno.test("missing queue/audit/hold/fk scopes fail closed, never infer empty", () => {
  const snapshot = input();
  const candidate = prepareInboxRetentionDryRun({
    ...snapshot, pendingDeliveryIds: undefined,
    auditReferenceIds: undefined, foreignKeyReferenceIds: undefined,
  });
  assert(candidate.status === "blocked");
  assert(candidate.missingGates.includes("pendingDeliveryIds"));
  assert(candidate.missingGates.includes("auditReferenceIds"));
  assert(candidate.missingGates.includes("foreignKeyReferenceIds"));
});

Deno.test("duplicate and malformed identifiers cannot bypass reference holds", () => {
  const snapshot = input();
  for (const bad of [
    { ...snapshot, rows: [...snapshot.rows, snapshot.rows[0]] },
    { ...snapshot, rows: [{ id: "not-a-uuid", notification: old }] },
    { ...snapshot, rows: [{ id: null, notification: old }] },
  ]) {
    const result = prepareInboxRetentionDryRun(bad);
    assert(result.status === "blocked");
    assert(result.candidateForHumanReview === 0);
  }
});

Deno.test("failed date or missing approval blocks even empty candidate snapshots", () => {
  const snapshot = input();
  const invalidClock = prepareInboxRetentionDryRun({
    ...snapshot, now: new Date(NaN),
  });
  assert(invalidClock.status === "blocked");
  assert(invalidClock.missingGates.includes("valid_snapshot"));
  const noPrivacyApproval = prepareInboxRetentionDryRun({
    ...snapshot, checks: { ...gates, privacyReviewApproved: false },
  });
  assert(noPrivacyApproval.status === "blocked");
  assert(noPrivacyApproval.missingGates.includes("privacyReviewApproved"));
});

Deno.test("every result is inspection-only, never a deletion command", () => {
  const prepared = prepareInboxRetentionDryRun(input());
  const encoded = JSON.stringify(prepared);
  assert(prepared.autoDeleteAllowed === false);
  assert(!/\\b(?:delete\\s+from|truncate\\s+table|drop\\s+table)\\b/i.test(encoded));
});
