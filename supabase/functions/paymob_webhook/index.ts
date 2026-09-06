import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

console.log("⚡ Paymob Webhook Edge Function Initialized (Hardened & Unified)!");

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
    obj.order?.id ?? obj.order,
    obj.owner,
    obj.pending,
    obj.source_data?.pan ?? "",
    obj.source_data?.sub_type ?? "",
    obj.source_data?.type ?? "",
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
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const payload = await req.json();
    const obj = payload.obj || payload;

    if (!obj || !obj.id) {
      return new Response(JSON.stringify({ error: "Invalid Paymob payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
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
    const specialReference = String(obj.special_reference || obj.order?.merchant_order_id || "");

    // Extract booking_id
    let bookingId: string | null = null;
    if (specialReference.includes("_")) {
      bookingId = specialReference.startsWith("VSP_BOOKING_")
        ? specialReference.replace("VSP_BOOKING_", "").split("_")[0]
        : specialReference.split("_")[0];
    } else if (specialReference.length > 0) {
      bookingId = specialReference;
    }

    console.log(`🔔 Webhook received for Booking: ${bookingId} | Success: ${isSuccess} | Tx: ${transactionId}`);

    // 3. Log into webhook_logs
    try {
      await supabase.from("webhook_logs").insert({
        provider: "paymob",
        event_type: "transaction_response",
        txn_id: transactionId,
        order_id: String(obj.order?.id ?? obj.order ?? ""),
        booking_id: bookingId && bookingId.length === 36 ? bookingId : null,
        payload: obj,
        signature_verified: true,
        status: isSuccess ? "success" : "failed",
      });
    } catch (logErr) {
      console.warn("⚠️ Non-blocking warning: failed to write to webhook_logs", logErr);
    }

    // 3.4 Handle 1v1 Tournament Orders (With Real Paymob Refund on Over-Capacity)
    if (specialReference.startsWith("TOURN_1V1_")) {
      console.log(`🥋 Processing 1v1 tournament webhook for order: ${specialReference}`);
      if (isSuccess) {
        // Step 1: Atomic confirmation & capacity check (with row lock)
        const { data: tournResult, error: tournErr } = await supabase.rpc(
          "confirm_1v1_payment_atomic",
          {
            p_order_reference: specialReference,
            p_paymob_transaction_id: transactionId,
          }
        );

        if (tournErr) {
          console.error("❌ Failed to confirm 1v1 tournament order via RPC:", tournErr);
        } else if (tournResult?.needs_refund === true) {
          // 🛡️ OVER-CAPACITY DETECTED: Real Paymob Refund API call FIRST
          console.warn(`🚨 Capacity exceeded for 1v1 order ${specialReference}. Initiating REAL Paymob Refund API call...`);
          
          let refundSuccess = false;
          let refundId = null;
          let refundErrorMsg = null;

          try {
            const paymobApiKey = Deno.env.get("PAYMOB_API_KEY") || Deno.env.get("PAYMOB_SECRET_KEY") || "";
            if (!paymobApiKey) {
              throw new Error("Missing PAYMOB_API_KEY / PAYMOB_SECRET_KEY on server environment");
            }

            // Step A: Authenticate with Paymob to obtain auth token
            const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ api_key: paymobApiKey }),
            });

            if (!authRes.ok) {
              const authErrText = await authRes.text();
              throw new Error(`Paymob auth token request failed: ${authErrText}`);
            }

            const authData = await authRes.json();
            const authToken = authData.token;

            // Step B: Call Paymob Void/Refund API with exact transaction and amount in cents
            const amountCents = Math.round(Number(tournResult.amount) * 100);
            const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                auth_token: authToken,
                transaction_id: Number(transactionId),
                amount_cents: amountCents,
              }),
            });

            const refundData = await refundRes.json();
            console.log("Paymob Refund API Response:", JSON.stringify(refundData));

            if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "REFUND_SUCCESS");
            } else {
              refundErrorMsg = refundData.message || refundData.detail || JSON.stringify(refundData);
            }
          } catch (refundEx: any) {
            console.error("❌ Exception during Paymob Refund API call:", refundEx);
            refundErrorMsg = refundEx.message || String(refundEx);
          }

          // Step C: Atomically record real refund status or flag for manual review
          await supabase.rpc("record_1v1_refund_status_atomic", {
            p_order_reference: specialReference,
            p_refund_success: refundSuccess,
            p_paymob_refund_id: refundId,
            p_error_message: refundErrorMsg,
          });

        } else {
          console.log("🎉 1v1 Tournament order confirmed successfully:", tournResult);
        }
      }

      return new Response(JSON.stringify({ status: "processed", type: "1v1_tournament", success: isSuccess }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3.5 Handle Team Tournament Orders
    if (specialReference.startsWith("TOURN_")) {
      console.log(`Processing tournament webhook for order: ${specialReference}`);
      if (isSuccess) {
        // Step 1: Atomic confirmation & capacity check (with row lock)
        const { data: tournResult, error: tournErr } = await supabase.rpc(
          "confirm_tournament_order_atomic",
          {
            p_order_reference: specialReference,
            p_paymob_transaction_id: transactionId,
          }
        );

        if (tournErr) {
          console.error("Failed to confirm tournament order via RPC:", tournErr);
        } else if (tournResult?.needs_refund === true || tournResult?.requires_refund === true) {
          // OVER-CAPACITY DETECTED: Real Paymob Refund API call FIRST
          console.warn(`Capacity exceeded for tournament order ${specialReference}. Initiating REAL Paymob Refund API call...`);
          
          let refundSuccess = false;
          let refundId = null;
          let refundErrorMsg = null;

          try {
            const paymobApiKey = Deno.env.get("PAYMOB_API_KEY") || Deno.env.get("PAYMOB_SECRET_KEY") || "";
            if (!paymobApiKey) {
              throw new Error("Missing PAYMOB_API_KEY / PAYMOB_SECRET_KEY on server environment");
            }

            // Step A: Authenticate with Paymob to obtain auth token
            const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ api_key: paymobApiKey }),
            });

            if (!authRes.ok) {
              const authErrText = await authRes.text();
              throw new Error(`Paymob auth token request failed: ${authErrText}`);
            }

            const authData = await authRes.json();
            const authToken = authData.token;

            // Step B: Call Paymob Void/Refund API with exact transaction and amount in cents
            const amountCents = Math.round(Number(tournResult.amount) * 100);
            const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                auth_token: authToken,
                transaction_id: Number(transactionId),
                amount_cents: amountCents,
              }),
            });

            const refundData = await refundRes.json();
            console.log("Paymob Refund API Response:", JSON.stringify(refundData));

            if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "REFUND_SUCCESS");
            } else {
              refundErrorMsg = refundData.message || refundData.detail || JSON.stringify(refundData);
            }
          } catch (refundEx: any) {
            console.error("Exception during Paymob Refund API call:", refundEx);
            refundErrorMsg = refundEx.message || String(refundEx);
          }

          // Step C: Atomically record real refund status or flag for manual review
          await supabase.rpc("record_tournament_refund_status_atomic", {
            p_order_reference: specialReference,
            p_refund_success: refundSuccess,
            p_paymob_refund_id: refundId,
            p_error_message: refundErrorMsg,
          });

        } else {
          console.log("Tournament order confirmed successfully:", tournResult);
        }
      }
      return new Response(JSON.stringify({ status: "processed", type: "tournament", success: isSuccess }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!bookingId) {
      return new Response(JSON.stringify({ message: "No booking ID in reference" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Fetch existing booking to verify expected amount
    const { data: existingBooking, error: fetchError } = await supabase
      .from("bookings")
      .select("id, total_price, deposit_amount, needs_deposit, owner_id, user_id, created_by_user_id, stadium_name")
      .eq("id", bookingId)
      .maybeSingle();

    if (fetchError || !existingBooking) {
      console.error(`❌ Booking ${bookingId} not found in database.`);
      return new Response(JSON.stringify({ error: "Booking not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Update Booking Status atomically if transaction succeeded
    if (isSuccess) {
      const paidAmountEgp = (obj.amount_cents || 0) / 100;
      const expectedAmount = (existingBooking.needs_deposit && Number(existingBooking.deposit_amount) > 0)
        ? Number(existingBooking.deposit_amount)
        : Number(existingBooking.total_price);

      // Verify that the paid amount satisfies the expected amount
      if (paidAmountEgp < (expectedAmount - 0.5)) {
        console.error(`🚨 Security Alert: Paid amount (${paidAmountEgp} EGP) is less than expected (${expectedAmount} EGP) for booking ${bookingId}`);
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "underpayment_fraud_alert",
          txn_id: transactionId,
          order_id: String(obj.order?.id ?? obj.order ?? ""),
          booking_id: bookingId,
          payload: obj,
          signature_verified: true,
          status: "fraud_detected",
          error_message: `Paid ${paidAmountEgp} EGP, expected ${expectedAmount} EGP`,
        });
        return new Response(JSON.stringify({ error: "Payment amount does not match booking price" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      const { data: booking, error: updateError } = await supabase
        .from("bookings")
        .update({
          status: "confirmed",
          is_paid: true,
          payment_status: "paid",
          is_deposit_paid: true,
          payment_transaction_id: `PAYMOB_${transactionId}`,
          paymob_txn_id: transactionId,
          payment_method: obj.source_data?.sub_type || "paymob",
          webhook_verified: true,
          webhook_processed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId)
        .select()
        .single();

      if (updateError) {
        console.error(`❌ Failed to update booking ${bookingId}:`, updateError);
      } else if (booking) {
        console.log(`🎉 Booking ${bookingId} confirmed successfully via Paymob payment!`);

        // Send notifications
        const amountEgp = paidAmountEgp.toFixed(0);
        await supabase.from("notifications").insert([
          {
            user_id: booking.owner_id,
            title: "تم استلام دفعة حجز مؤكدة 💰",
            body: `تم دفع مبلغ ${amountEgp} ج.م لحجز ${booking.stadium_name || "الملعب"}`,
            type: "payment_received",
            booking_id: bookingId,
            is_read: false,
          },
          {
            user_id: booking.user_id || booking.created_by_user_id,
            title: "تأكيد الحجز والدفع ⚽",
            body: `تم سداد حجزك بنجاح في ${booking.stadium_name || "الملعب"}`,
            type: "booking_confirmed",
            booking_id: bookingId,
            is_read: false,
          },
        ]);
      }
    } else {
      // Payment failed
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId);
    }

    return new Response(JSON.stringify({ status: "processed", success: isSuccess }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Paymob Webhook Error:", error);
    return new Response(JSON.stringify({ error: error?.message || String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
