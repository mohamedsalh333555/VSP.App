import {
  classifyFcmReply, processFcmQueueMessages,
} from "../_shared/fcm_queue_delivery.ts";

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
  const result = await processFcmQueueMessages([{ msg_id: 1, message: {} }, { msg_id: 2, message: {} }], {
    dispatch: async (payload) => Object.keys(payload as object).length === 0
      ? reply({ status: "skipped", reason: "no_fcm_token" })
      : reply({ status: "skipped", reason: "provider_unknown" }),
    archive: async (id) => { calls.push(Number(id)); return { data: true }; },
    log: () => {},
  });
  eq(result.skipped_no_token, 2);
  eq(calls, [1, 2]);
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
