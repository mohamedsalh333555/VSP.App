import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

declare const Deno: any;

const HMAC_SECRET = Deno.env.get("PAYMOB_HMAC_SECRET");

serve(async (req: Request) => {
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
    // 🔒 1. التحقق الصارم من وجود المتغير السري في بيئة السيرفر (Fail-Closed)
    if (!HMAC_SECRET) {
      console.error("🚨 CRITICAL: PAYMOB_HMAC_SECRET environment variable is missing on server!");
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: Missing PAYMOB_HMAC_SECRET" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const url = new URL(req.url);
    const body = await req.json();
    const obj = body.obj;

    if (!obj) {
      return new Response(JSON.stringify({ error: "Missing transaction object" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 🔒 2. فحص توقيع الـ HMAC الإلزامي عبر query parameter "hmac" (Fail-Closed)
    const receivedHmac = url.searchParams.get("hmac");
    if (!receivedHmac) {
      console.error("❌ Rejected: Missing HMAC signature in webhook request parameters");
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing HMAC signature query parameter" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const hmacString = [
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

    const keyBuf = new TextEncoder().encode(HMAC_SECRET);
    const msgBuf = new TextEncoder().encode(hmacString);
    const key = await crypto.subtle.importKey(
      "raw",
      keyBuf,
      { name: "HMAC", hash: "SHA-512" },
      false,
      ["sign"]
    );
    const signature = await crypto.subtle.sign("HMAC", key, msgBuf);
    const calculatedHmac = Array.from(new Uint8Array(signature))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (calculatedHmac.toLowerCase() !== receivedHmac.toLowerCase()) {
      console.error("❌ HMAC signature mismatch! Webhook rejected.");
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid HMAC signature" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. التحقق من نجاح العملية
    const isSuccess = obj.success === true && obj.pending === false;
    const specialReference = obj.special_reference || obj.order?.merchant_order_id || "";
    const bookingId = specialReference.split("_")[0];

    console.log(`🔔 Webhook received for Booking: ${bookingId} | Success: ${isSuccess} | Tx: ${obj.id}`);

    if (!bookingId) {
      return new Response(JSON.stringify({ message: "No booking ID in reference" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. الاتصال بقاعدة البيانات بصلاحية السيرفر (Service Role)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    if (isSuccess) {
      // 4. تأكيد الحجز ونقله لـ confirmed و is_paid = true
      const { data: booking, error: updateError } = await supabaseAdmin
        .from("bookings")
        .update({
          status: "confirmed",
          is_paid: true,
          payment_status: "paid",
          payment_transaction_id: `PAYMOB_${obj.id}`,
          payment_method: obj.source_data?.sub_type || "paymob",
          updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId)
        .select()
        .single();

      if (updateError) {
        console.error("❌ Error updating booking:", updateError);
      } else if (booking) {
        console.log("✅ Booking confirmed successfully:", booking.id);

        // 5. إرسال الإشعار الحقيقي للمالك واللاعب
        await supabaseAdmin.from("notifications").insert([
          {
            user_id: booking.owner_id,
            title: "تم استلام دفعة حجز مؤكدة 💰",
            body: `تم دفع مبلغ ${(obj.amount_cents / 100).toFixed(0)} ج.م لحجز ${booking.stadium_name}`,
            type: "payment_received",
            booking_id: bookingId,
            is_read: false,
          },
          {
            user_id: booking.user_id,
            title: "تأكيد الحجز والدفع ⚽",
            body: `تم سداد حجزك بنجاح في ${booking.stadium_name}`,
            type: "booking_confirmed",
            booking_id: bookingId,
            is_read: false,
          },
        ]);
      }
    } else {
      // إذا فشل الدفع، يتم إلغاء الحجز المعلق
      await supabaseAdmin
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("❌ Webhook error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
