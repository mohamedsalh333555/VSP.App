// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

console.log("FCM Queue Worker Started!");

serve(async (_req: Request) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Read batch of messages from pgmq notifications_queue
    const { data: messages, error: readError } = await supabase.rpc("pgmq_read", {
      queue_name: "notifications_queue",
      vt: 30, // visibility timeout in seconds
      qty: 10,
    });

    if (readError) {
      console.error("Error reading from pgmq:", readError);
      return new Response(JSON.stringify({ error: readError.message }), { status: 500 });
    }

    if (!messages || messages.length === 0) {
      return new Response(JSON.stringify({ message: "No queued notifications" }), { status: 200 });
    }

    console.log(`Processing ${messages.length} queued notification(s)...`);

    for (const msg of messages) {
      const payload = msg.message;
      try {
        // Forward message to FCM push Edge Function
        const pushResponse = await fetch(`${supabaseUrl}/functions/v1/fcm_push`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${supabaseKey}`,
          },
          body: JSON.stringify(payload),
        });

        const pushResult = await pushResponse.json().catch(() => ({}));
        if (!pushResponse.ok) {
          // Leave failed messages unarchived. PGMQ makes them visible again
          // after the visibility timeout so transient FCM failures can retry.
          console.error(
            `FCM dispatch failed for msg_id ${msg.msg_id} (HTTP ${pushResponse.status}):`,
            pushResult,
          );
          continue;
        }

        // A 200 response is considered dispatched or intentionally skipped
        // (for example, no device token). Archive only after that response.
        const archiveResult = await supabase.rpc("pgmq_archive", {
          queue_name: "notifications_queue",
          msg_id: msg.msg_id,
        });
        if (archiveResult.error) {
          console.error(`Failed to archive msg_id ${msg.msg_id}:`, archiveResult.error);
        }
      } catch (err) {
        console.error(`Failed to process msg_id ${msg.msg_id}:`, err);
      }
    }

    return new Response(JSON.stringify({ processed: messages.length }), { status: 200 });
  } catch (error: any) {
    console.error("Queue Worker Error:", error);
    return new Response(String(error?.message || error), { status: 500 });
  }
});
