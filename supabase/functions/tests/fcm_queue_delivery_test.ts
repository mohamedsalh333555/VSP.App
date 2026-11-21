import {
  classifyFcmReply, isValidPgmqReadBatch, processFcmQueueMessages,
  FCM_QUEUE_MAX_PER_INVOCATION, FCM_QUEUE_MAX_PER_RECIPIENT,
} from "../_shared/fcm_queue_delivery.ts";
import { checkFcmWorkerAccess } from "../_shared/fcm_queue_auth.ts";

const eq = (a: unknown, b: unknown) => {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.test("FCM 200 alone is insufficient: malformed, empty or false payload stays queued", async () => {
  for (const response of [
    new Response("not-json", { status: 200 }),
    reply({}),
    reply({ success: false, sent_count: 0, failed_count: 2 }),
    reply({ success: true, sent_count: 0, failed_count: 0 }),
    reply({ success: true, sent_count: 1 }),
    reply({ status: "skipped", reason: "wrong_reason" }),
    reply({ success: true, sent_count: "1", failed_count: 0 }),
  ]) eq(await classifyFcmReply(response), "retry");
});

Deno.test("FCM 502 outage and 200 contradictory response do not archive; returned visibility permits retry", async () => {
  const archiveCalls: Array<string | number> = [];
  const events: string[] = [];
  let attempts = 0;
  const deps = {
    dispatch: async () => {
      attempts++;
      return attempts === 1 ? reply({ error: "provider unavailable" }, 502)
        : attempts === 2 ? reply({ success: false, sent_count: 0, failed_count: 3 })
        : reply({ success: true, sent_count: 2, failed_count: 0 });
    },
    archive: async (id: number | string) => { archiveCalls.push(id); return { data: true }; },
    log: (event: string) => events.push(event),
  };
  const message = [{ msg_id: 42, message: { user_id: "mock-only", title: "test" } }];
  const first = await processFcmQueueMessages(message, deps);
  const second = await processFcmQueueMessages(message, deps);
  const third = await processFcmQueueMessages(message, deps);
  eq([first.retry_pending, second.retry_pending, third.delivered], [1, 1, 1]);
  eq(archiveCalls, [42]);
  eq(events.filter(x => x === "retry_pending").length, 2);
});

Deno.test("FCM successful dispatch archives exactly once after delivery", async () => {
  const order: string[] = [];
  const result = await processFcmQueueMessages([{ msg_id: 1, message: { x: 1 } }], {
    dispatch: async () => { order.push("dispatch"); return reply({ success: true, sent_count: 1, failed_count: 0 }); },
    archive: async () => { order.push("archive"); return { data: true }; },
    log: () => {},
  });
  eq(order, ["dispatch", "archive"]);
  eq(result.delivered, 1);
  eq(result.retry_pending, 0);
});

Deno.test("no token is archived intentionally; unknown skipped state is retried", async () => {
  const calls: number[] = [];
  const result = await processFcmQueueMessages(
    [{ msg_id: 1, message: { kind: "no_token" } }, { msg_id: 2, message: { kind: "unexpected_skip" } }],
    {
    dispatch: async (payload) => (payload as { kind: string }).kind === "no_token"
      ? reply({ status: "skipped", reason: "no_fcm_token" })
      : reply({ status: "skipped", reason: "provider_unknown" }),
    archive: async (id) => { calls.push(Number(id)); return { data: true }; },
    log: () => {},
  });
  eq(result.skipped_no_token, 1);
  eq(result.retry_pending, 1);
  eq(calls, [1]);
});

Deno.test("archive errors leave message eligible for reprocessing", async () => {
  const stats = await processFcmQueueMessages([{ msg_id: 17, message: {} }], {
    dispatch: async () => reply({ success: true, sent_count: 1, failed_count: 0 }),
    archive: async () => ({ error: "mock archive failure" }),
    log: () => {},
  });
  eq(stats.archive_failed, 1);
  eq(stats.delivered, 0);
});

Deno.test("one message failure does not stop the remaining batch", async () => {
  const archived: number[] = [];
  const out = await processFcmQueueMessages([{ msg_id: 7, message: {} }, { msg_id: 8, message: {} }], {
    dispatch: async () => archived.length === 0
      ? reply({ success: true, sent_count: 1, failed_count: 0 })
      : reply({ status: "skipped", reason: "no_fcm_token" }),
    archive: async (id) => { archived.push(Number(id)); return { data: true }; },
    log: () => {},
  });
  eq(out.attempted, 2);
  eq(out.delivered, 1);
  eq(out.skipped_no_token, 1);
});

Deno.test("partial multi-device result records failures without re-sending successful tokens", async () => {
  let archived = 0;
  const s = await processFcmQueueMessages([{ msg_id: 9, message: {} }], {
    dispatch: async () => reply({ success: true, sent_count: 1, failed_count: 2 }),
    archive: async () => { archived++; return { data: true }; },
    log: () => {},
  });
  eq(s.partial_device_failures, 1);
  eq(archived, 1);
});

Deno.test("exceptions keep message for retry; logs contain only event and id", async () => {
  const logs: string[] = [];
  const s = await processFcmQueueMessages([{ msg_id: 9, message: { token: "secret-payload" } }], {
    dispatch: async () => { throw new Error("secret-payload"); },
    archive: async () => { throw new Error("archive should not run"); },
    log: (event, id) => logs.push(event + ":" + id),
  });
  eq(s.retry_pending, 1);
  if (JSON.stringify(logs).includes("secret-payload")) throw new Error("Sensitive error leaked");
});

Deno.test("FCM worker requires service-to-service bearer before queue access", () => {
  eq(checkFcmWorkerAccess("POST", "Bearer secret-for-test", "secret-for-test"), "allowed");
  eq(checkFcmWorkerAccess("POST", "bearer secret-for-test", "secret-for-test"), "allowed");
  for (const header of [
    null, "", "Bearer", "Bearer anon-key", "Basic secret-for-test",
    "Bearer secret-for-test extra", "Bearer secret-for-tes", "Bearer secret-for-testX",
  ]) eq(checkFcmWorkerAccess("POST", header, "secret-for-test"), "unauthorized");
  eq(checkFcmWorkerAccess("GET", "Bearer secret-for-test", "secret-for-test"), "method_not_allowed");
  eq(checkFcmWorkerAccess("POST", "Bearer secret-for-test", ""), "unconfigured");
});


Deno.test("pgmq_read may return empty [] but must not silently accept invalid RPC payload", () => {
  eq(isValidPgmqReadBatch([]), true);
  eq(isValidPgmqReadBatch([{ msg_id: 1, message: {} }]), true);
  eq(isValidPgmqReadBatch([{ msg_id: "9223372036854775807", message: {} }]), true);
  for (const input of [null, {}, "[]", { error: "database unavailable" },
    [{ msg_id: 0, message: {} }], [{ msg_id: 1 }],
    [{ msg_id: "1.5", message: {} }], [{ msg_id: Number.MAX_SAFE_INTEGER + 1, message: {} }]]) {
    eq(isValidPgmqReadBatch(input), false);
  }
});

Deno.test("pgmq_archive must return literal true before message counts as archived", async () => {
  for (const invalidResult of [
    { data: null }, {}, { data: false }, { data: 0 }, { data: "true" }, { error: "db down" },
  ]) {
    const stat = await processFcmQueueMessages([{ msg_id: 81, message: { kind: "test" } }], {
      dispatch: async () => reply({ success: true, sent_count: 1, failed_count: 0 }),
      archive: async () => invalidResult,
      log: () => {},
    });
    eq(stat.archive_failed, 1);
    eq(stat.delivered, 0);
  }
  const stat = await processFcmQueueMessages([{ msg_id: 82, message: {} }], {
    dispatch: async () => reply({ success: true, sent_count: 1, failed_count: 0 }),
    archive: async () => ({ data: true }),
    log: () => {},
  });
  eq(stat.archive_failed, 0);
  eq(stat.delivered, 1);
});


Deno.test("batch dispatch cap and per-recipient quota defer rather than discard overflow", async () => {
  const names: string[] = [];
  const archived: number[] = [];
  const events: string[] = [];
  const input = [
    ...[1, 2, 3, 4, 5].map(msg_id => ({ msg_id, message: { user_id: "player-a" } })),
    ...[6, 7].map(msg_id => ({ msg_id, message: { record: { user_id: "player-b" } } })),
    { msg_id: 8, message: { userId: "player-c" } },
    { msg_id: 9, message: { userId: "player-d" } },
  ];
  const stats = await processFcmQueueMessages(input, {
    dispatch: async (msg) => {
      names.push(JSON.stringify(msg));
      return reply({ success: true, sent_count: 1, failed_count: 0 });
    },
    archive: async (id) => { archived.push(Number(id)); return { data: true }; },
    log: (event, id) => events.push(event + ":" + id),
  });
  eq(FCM_QUEUE_MAX_PER_INVOCATION, 5);
  eq(FCM_QUEUE_MAX_PER_RECIPIENT, 2);
  eq(stats.attempted, 5);
  eq(stats.delivered, 5);
  eq(stats.rate_limited, 4);
  eq(archived, [1, 2, 6, 7, 8]);
  eq(events.filter(s => s.startsWith("rate_limited")).length, 4);
  if (JSON.stringify(events).includes("player-")) throw new Error("User identity leaked to queue logs");
});

Deno.test("failed sends count toward per-invocation quota and remain retriable", async () => {
  let dispatched = 0;
  const messages = Array.from({ length: 7 }, (_, i) => ({
    msg_id: i + 1, message: { user_id: "recipient-" + i },
  }));
  const stats = await processFcmQueueMessages(messages, {
    dispatch: async () => { dispatched++; return reply({ error: "offline" }, 503); },
    archive: async () => { throw new Error("must not archive failures"); },
    log: () => {},
  });
  eq(dispatched, FCM_QUEUE_MAX_PER_INVOCATION);
  eq(stats.attempted, 5);
  eq(stats.retry_pending, 5);
  eq(stats.rate_limited, 2);
  eq(stats.delivered, 0);
});

Deno.test("rate limitation is scoped to a single worker invocation, not claimed as durable", async () => {
  const msg = [
    { msg_id: 1, message: { user_id: "same" } },
    { msg_id: 2, message: { user_id: "same" } },
    { msg_id: 3, message: { user_id: "same" } },
  ];
  const sent: number[] = [];
  const deps = {
    dispatch: async () => reply({ success: true, sent_count: 1, failed_count: 0 }),
    archive: async (id: string | number) => { sent.push(Number(id)); return { data: true }; },
    log: () => {},
  };
  const first = await processFcmQueueMessages(msg, deps);
  eq([first.delivered, first.rate_limited], [2, 1]);
  // Re-processing a later visibility window uses a new in-memory quota,
  // showing why this does not prove a daily or global send cap.
  const second = await processFcmQueueMessages(msg.slice(2), deps);
  eq([second.delivered, second.rate_limited], [1, 0]);
  eq(sent, [1, 2, 3]);
});
