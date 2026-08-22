// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

console.log("Paymob Webhook Edge Function Initialized!");

/**
 * Calculates Paymob SHA-512 HMAC signature
 */
async function computePaymobHMAC(obj: any, hmacSecret: string): Promise<string> {
  const concatenatedValues = [
    obj.amount_cents,
    obj.created_at,
    obj.currency,
    obj.error_occured,
    obj.has_parent_transaction,
    obj.id,
    obj.integration_id,
    obj.is_3d_secure,
    obj.is_auth,
    obj.is_capture,
    obj.is_refunded,
    obj.is_standalone_payment,
    obj.is_voided,
    obj.order?.id,
    obj.owner,
    obj.pending,
    obj.source_data?.pan,
    obj.source_data?.sub_type,
    obj.source_data?.type,
    obj.success,
  ].join("");

  const encoder = new TextEncoder();
  const keyData = encoder.encode(hmacSecret);
  const messageData = encoder.encode(concatenatedValues);

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"]
  );

  const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, messageData);
  const hashArray = Array.from(new Uint8Array(signatureBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const payload = await req.json();
    const obj = payload.obj || payload;

    if (!obj || !obj.id) {
      return new Response("Invalid Paymob payload", { status: 400 });
    }

    // 🔒 1. Verify HMAC Signature strictly (Fail-Closed)
    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET");
    if (!hmacSecret) {
      console.error("🚨 CRITICAL: PAYMOB_HMAC_SECRET environment variable is missing on server!");
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: Missing PAYMOB_HMAC_SECRET" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const url = new URL(req.url);
    const receivedHmac = url.searchParams.get("hmac");
    if (!receivedHmac) {
      console.error("❌ Rejected: Missing HMAC signature in webhook request parameters");
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing HMAC signature query parameter" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const calculatedHmac = await computePaymobHMAC(obj, hmacSecret);
    if (calculatedHmac.toLowerCase() !== receivedHmac.toLowerCase()) {
      console.error("❌ Paymob Webhook HMAC Verification Failed! Signatures do not match.");
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid HMAC signature" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }
    console.log("✅ HMAC Signature Verified Successfully!");

    // 2. Initialize Supabase Client with Service Role Key
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const transactionId = String(obj.id);
    const isSuccess = Boolean(obj.success) && !Boolean(obj.pending);
    const merchantOrderId = String(obj.order?.merchant_order_id || "");

    // Extract booking_id from merchant_order_id (e.g. "uuid_timestamp" or "VSP_BOOKING_uuid")
    let bookingId: string | null = null;
    if (merchantOrderId.includes("_")) {
      bookingId = merchantOrderId.startsWith("VSP_BOOKING_") 
          ? merchantOrderId.replace("VSP_BOOKING_", "").split("_")[0]
          : merchantOrderId.split("_")[0];
    } else if (merchantOrderId.length > 0) {
      bookingId = merchantOrderId;
    }

    // 3. Idempotency Check: Try inserting transaction ID into deduplication table
    const { error: insertTxError } = await supabase
      .from("paymob_transactions")
      .insert({
        transaction_id: transactionId,
        booking_id: bookingId,
        amount_cents: obj.amount_cents || 0,
        success: isSuccess,
        currency: obj.currency || "EGP",
        raw_payload: obj,
      });

    if (insertTxError && insertTxError.code === "23505") { // Unique violation
      console.log(`ℹ️ Transaction ${transactionId} already processed. Skipping duplicate webhook.`);
      return new Response(JSON.stringify({ status: "duplicate_ignored" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Update Booking Status atomically if transaction succeeded
    if (isSuccess && bookingId) {
      const { error: updateError } = await supabase
        .from("bookings")
        .update({
          status: "confirmed",
          payment_status: "paid",
          is_paid: true,
          is_deposit_paid: true,
          updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId);

      if (updateError) {
        console.error(`❌ Failed to update booking ${bookingId}:`, updateError);
      } else {
        console.log(`🎉 Booking ${bookingId} confirmed successfully via Paymob payment!`);
      }
    }

    return new Response(JSON.stringify({ status: "processed", success: isSuccess }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Paymob Webhook Error:", error);
    return new Response(String(error?.message || error), { status: 500 });
  }
});
