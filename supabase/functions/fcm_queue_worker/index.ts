// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { isValidPgmqReadBatch, processFcmQueueMessages } from "../_shared/fcm_queue_delivery.ts";
import { checkFcmWorkerAccess } from "../_shared/fcm_queue_auth.ts";

declare const Deno: any;

serve(async (req: Request) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    // Validate before creating a database client or reading the queue.
    // This function is internal-only. No deployed pg_cron caller was found
    // in staging or production as of 2026-11-17; review any external
    // scheduler's bearer auth before first deploying this worker.
    const access = checkFcmWorkerAccess(
      req.method, req.headers.get("authorization"), supabaseKey,
    );
    if (access !== "allowed") {
      const status = access === "method_not_allowed" ? 405
        : access === "unconfigured" ? 503 : 401;
      return new Response(JSON.stringify({ error: status === 405
        ? "Method not allowed" : status === 503
        ? "FCM service is not configured" : "Unauthorized" }), {
        status, headers: { "Cache-Control": "no-store" },
      });
    }
    if (!supabaseUrl) {
      return new Response(JSON.stringify({ error: "FCM service is not configured" }), { status: 503 });
    }
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data: messages, error: readError } = await supabase.rpc("pgmq_read", {
      queue_name: "notifications_queue",
      // Five sequential calls with a 25s per-call deadline require a
      // visibility lease larger than the dispatch window to reduce duplicate
      // in-flight deliveries. This is still at-least-once, not exactly-once.
      vt: 180,
      qty: 10,
    });
    if (readError) {
      // Do not expose internal DB exception detail to the caller or logs.
      console.error("FCM queue read failed");
      return new Response(JSON.stringify({ error: "Queue temporarily unavailable" }), { status: 503 });
    }
    if (!isValidPgmqReadBatch(messages)) {
      // A broken or version-drifted RPC response is not an empty queue.
      console.error("FCM queue read returned invalid batch");
      return new Response(JSON.stringify({ error: "Queue temporarily unavailable" }), {
        status: 503,
      });
    }
    if (messages.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }), { status: 200 });
    }
    const stats = await processFcmQueueMessages(messages, {
      dispatch: async (payload) => fetch(`${supabaseUrl}/functions/v1/fcm_push`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${supabaseKey}`,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(25_000),
      }),
      archive: (msgId) => supabase.rpc("pgmq_archive", {
        queue_name: "notifications_queue",
        msg_id: msgId,
      }),
      log: (event, msgId) => console.log(JSON.stringify({
        operation: "fcm_queue_delivery",
        event,
        msg_id: String(msgId),
      })),
    });
    // 200 means worker ran; retry_pending stays in PGMQ (at-least-once),
    // not that notifications were all sent. No raw payloads or provider bodies.
    return new Response(JSON.stringify(stats), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    console.error("FCM queue worker failed");
    return new Response(JSON.stringify({ error: "Notification service unavailable" }), { status: 503 });
  }
});
