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
        await fetch(`${supabaseUrl}/functions/v1/fcm_push`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${supabaseKey}`,
          },
          body: JSON.stringify(payload),
        });

        // Archive / archive message from queue upon successful dispatch
        await supabase.rpc("pgmq_archive", {
          queue_name: "notifications_queue",
          msg_id: msg.msg_id,
        });
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
