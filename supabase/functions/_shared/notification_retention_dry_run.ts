import {
  evaluateInboxRetention,
  type InboxRetentionRow,
} from "./notification_retention_policy.ts";

/**
 * Non-destructive rehearsal only. This is NOT a deletion scheduler, migration,
 * archive API, or approval to purge user data. It returns aggregate counts,
 * never notification IDs, user IDs, payloads or financial/audit records.
 */
export type RetentionDryRunInput = {
  rows: ReadonlyArray<{ id: unknown; notification: InboxRetentionRow }>;
  now: Date;
  // Externally audited dependencies must be supplied; absence is a blocker.
  pendingDeliveryIds?: ReadonlySet<string>;
  legalHoldIds?: ReadonlySet<string>;
  auditReferenceIds?: ReadonlySet<string>;
  foreignKeyReferenceIds?: ReadonlySet<string>;
  checks: {
    foreignKeysInspected: boolean;
    deliveryQueueInspected: boolean;
    legalHoldsInspected: boolean;
    auditReferencesInspected: boolean;
    backupRestoreTested: boolean;
    privacyReviewApproved: boolean;
  };
};

export type RetentionDryRunResult = {
  status: "blocked" | "review_only";
  autoDeleteAllowed: false;
  missingGates: string[];
  inspected: number;
  candidateForHumanReview: number;
  retainedByPolicy: number;
  protectedByDependencies: number;
};

const validId = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const gates = [
  "foreignKeysInspected", "deliveryQueueInspected",
  "legalHoldsInspected", "auditReferencesInspected",
  "backupRestoreTested", "privacyReviewApproved",
] as const;

export function prepareInboxRetentionDryRun(input: RetentionDryRunInput): RetentionDryRunResult {
  const missingGates: string[] = [];
  for (const gate of gates) {
    if (input.checks?.[gate] !== true) missingGates.push(gate);
  }
  for (const [field, refs] of Object.entries({
    pendingDeliveryIds: input.pendingDeliveryIds,
    legalHoldIds: input.legalHoldIds,
    auditReferenceIds: input.auditReferenceIds,
    foreignKeyReferenceIds: input.foreignKeyReferenceIds,
  })) {
    if (!(refs instanceof Set)) missingGates.push(field);
  }
  if (!Array.isArray(input.rows) || !Number.isFinite(input.now?.getTime())) {
    missingGates.push("valid_snapshot");
  }
  // Without a complete, unique list of stable notification IDs, a purported
  // cleanup plan could accidentally omit protected notifications.
  const seen = new Set<string>();
  if (Array.isArray(input.rows)) {
    for (const entry of input.rows) {
      const id = entry?.id;
      if (typeof id !== "string" || !validId.test(id) || seen.has(id)) {
        missingGates.push("valid_unique_ids");
        break;
      }
      seen.add(id);
    }
  }
  if (missingGates.length) {
    return {
      status: "blocked", autoDeleteAllowed: false,
      missingGates, inspected: 0, candidateForHumanReview: 0,
      retainedByPolicy: 0, protectedByDependencies: 0,
    };
  }

  let candidateForHumanReview = 0;
  let retainedByPolicy = 0;
  let protectedByDependencies = 0;
  for (const entry of input.rows) {
    const id = entry.id as string;
    if (input.pendingDeliveryIds!.has(id) ||
        input.legalHoldIds!.has(id) ||
        input.auditReferenceIds!.has(id) ||
        input.foreignKeyReferenceIds!.has(id)) {
      protectedByDependencies++;
      continue;
    }
    const decision = evaluateInboxRetention(entry.notification, input.now);
    if (decision.eligible) candidateForHumanReview++;
    else retainedByPolicy++;
  }
  return {
    status: "review_only",
    autoDeleteAllowed: false,
    missingGates: [],
    inspected: input.rows.length,
    candidateForHumanReview,
    retainedByPolicy,
    protectedByDependencies,
  };
}
