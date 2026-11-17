import { evaluateInboxRetention } from "../_shared/notification_retention_policy.ts";

const eq = (got: unknown, wanted: unknown) => {
  if (JSON.stringify(got) !== JSON.stringify(wanted)) {
    throw new Error(`got ${JSON.stringify(got)}, expected ${JSON.stringify(wanted)}`);
  }
};
const now = new Date("2026-11-17T12:00:00Z");
const reminder = (created_at: string, is_read: boolean) => ({
  type: "match_reminder", created_at, is_read,
  booking_id: null, metadata: {},
});

Deno.test("read reminders expire after exactly 90 elapsed UTC days, not before", () => {
  const cutoff = new Date(now.getTime() - 90 * 86400000);
  const oneMsNewer = new Date(cutoff.getTime() + 1);
  eq(evaluateInboxRetention(reminder(cutoff.toISOString(), true), now),
    { eligible: true, reason: "expired_reminder", retention_days: 90 });
  eq(evaluateInboxRetention(reminder(oneMsNewer.toISOString(), true), now),
    { eligible: false, reason: "active_or_unread_grace", retention_days: 90 });
});

Deno.test("unread reminder gets 180 days; any unverified state is retained", () => {
  const old = new Date(now.getTime() - 120 * 86400000).toISOString();
  eq(evaluateInboxRetention(reminder(old, false), now).eligible, false);
  eq(evaluateInboxRetention(reminder(old, true), now).eligible, true);
  eq(evaluateInboxRetention({ ...reminder(old, true), is_read: "true" }, now).eligible, false);
  eq(evaluateInboxRetention({ ...reminder(old, true), is_read: null }, now).eligible, false);
});

Deno.test("financial, booking, chat, unknown or audit-linked entries are never candidates", () => {
  const old = "2020-01-01T12:00:00Z";
  for (const type of ["payment", "refund", "booking_new", "booking_confirmed",
    "chat", "info", "challenge_result", "owner_warning", "", null, "other"]) {
    eq(evaluateInboxRetention({ ...reminder(old, true), type }, now).eligible, false);
  }
  for (const row of [
    { ...reminder(old, true), booking_id: "booking-123" },
    { ...reminder(old, true), metadata: { transaction_id: "not-for-output" } },
    { ...reminder(old, true), metadata: ["untrusted"] },
    { ...reminder(old, true), metadata: "unknown" },
  ]) {
    eq(evaluateInboxRetention(row, now).eligible, false);
  }
});

Deno.test("malformed timestamps, timezone-less values and future notifications stay protected", () => {
  for (const created_at of [
    null, 42, "", "invalid", "2026-11-17", "2026-11-17T00:00:00",
    "2026-11-20T00:00:00Z", "2024-13-12T00:00:00Z",
  ]) {
    eq(evaluateInboxRetention({ ...reminder("2020-01-01T00:00:00Z", true), created_at }, now).eligible, false);
  }
  eq(evaluateInboxRetention(reminder("2020-01-01T00:00:00Z", true),
    new Date(NaN)).eligible, false);
});

Deno.test("only explicit allowlisted reminder names qualify", () => {
  for (const type of ["match_reminder", "match_start_reminder", "daily_schedule"]) {
    eq(evaluateInboxRetention({ ...reminder("2020-01-01T00:00:00Z", true), type }, now).eligible, true);
  }
  eq(evaluateInboxRetention({ ...reminder("2020-01-01T00:00:00Z", true),
    type: "PAYMOB_REFUND" }, now).eligible, false);
});

Deno.test("UTC timestamps with Cairo offsets are evaluated using absolute elapsed time", () => {
  const cutoff = new Date(now.getTime() - 90 * 86400000);
  const cairo = new Date(cutoff.getTime()).toISOString().replace("Z", "+00:00");
  eq(evaluateInboxRetention(reminder(cairo, true), now).eligible, true);
});
