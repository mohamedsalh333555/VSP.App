// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  // 1. Handle CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ success: false, message: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Read Secrets and Initialize Supabase Client
    const paymobApiKey = Deno.env.get("PAYMOB_API_KEY") || Deno.env.get("PAYMOB_SECRET_KEY") || "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!paymobApiKey) {
      console.error("🚨 Missing PAYMOB_API_KEY / PAYMOB_SECRET_KEY on Supabase server environment!");
      return new Response(
        JSON.stringify({ success: false, message: "Server Configuration Error: PAYMOB_API_KEY missing" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 3. User Authentication Check (JWT)
    const authHeader = req.headers.get("Authorization") || req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "").trim();
    const { data: { user: callerUser }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized: Invalid or expired token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Parse Request Body
    const body = await req.json().catch(() => ({}));
    const bookingId = body.booking_id;
    const reason = body.reason || "Cancelled by user";

    if (!bookingId) {
      return new Response(
        JSON.stringify({ success: false, message: "Missing required field: booking_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Fetch Booking Record
    const { data: booking, error: bookingErr } = await supabase
      .from("bookings")
      .select("*")
      .eq("id", bookingId)
      .maybeSingle();

    if (bookingErr || !booking) {
      return new Response(
        JSON.stringify({ success: false, message: "الحجز غير موجود." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Security Check: Caller must be the booking owner, stadium owner, or admin
    const isCallerPlayer = booking.created_by_user_id === callerUser.id || booking.player_id === callerUser.id;
    const isCallerOwner = booking.owner_id === callerUser.id;
    
    // Check if caller is admin
    let isAdmin = false;
    const { data: userProfile } = await supabase
      .from("users")
      .select("role")
      .eq("id", callerUser.id)
      .maybeSingle();
    if (userProfile?.role === "admin") {
      isAdmin = true;
    }

    if (!isCallerPlayer && !isCallerOwner && !isAdmin) {
      return new Response(
        JSON.stringify({ success: false, message: "غير مصرح لك بإلغاء هذا الحجز." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check 2-Hour Cancellation Policy for Players
    const now = new Date();
    const matchStartTime = new Date(booking.start_time);
    const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);

    if (isCallerPlayer && matchStartTime <= twoHoursFromNow) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة الاسترداد.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if already cancelled
    if (booking.status === "cancelled") {
      return new Response(
        JSON.stringify({
          success: true,
          message: "الحجز ملغى بالفعل مسبقاً.",
          refund_amount: booking.refund_amount || 0,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const isPaid = booking.is_paid || booking.is_deposit_paid || booking.payment_status === "paid" || booking.payment_status === "confirmed";
    const refundAmount = Number(booking.deposit_paid || booking.total_price || booking.deposit_amount || 0);

    // If unpaid, perform immediate soft cancellation
    if (!isPaid || refundAmount <= 0) {
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          cancellation_reason: reason,
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      return new Response(
        JSON.stringify({
          success: true,
          message: "تم إلغاء الحجز غير المدفوع بنجاح.",
          refund_amount: 0,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Find Paymob Transaction ID
    let paymobTxnId = booking.paymob_txn_id || booking.paymob_transaction_id || booking.payment_transaction_id;

    if (!paymobTxnId) {
      // Look up in transactions table
      const { data: txRecord } = await supabase
        .from("transactions")
        .select("paymob_transaction_id, id")
        .eq("booking_id", bookingId)
        .not("paymob_transaction_id", "is", null)
        .maybeSingle();

      if (txRecord?.paymob_transaction_id) {
        paymobTxnId = txRecord.paymob_transaction_id;
      }
    }

    // Strip non-numeric prefixes (e.g. "PAYMOB_12345" -> "12345")
    if (typeof paymobTxnId === "string") {
      const match = paymobTxnId.match(/\d+/);
      if (match) {
        paymobTxnId = match[0];
      }
    }

    console.log(`🔄 Initiating Paymob Refund for Booking ${bookingId}: TxnID=${paymobTxnId}, Amount=${refundAmount} EGP`);

    // 7. Call Paymob Refund API
    let refundSuccess = false;
    let refundTxnId: string | null = null;
    let paymobErrorMessage = "";

    try {
      if (!paymobTxnId) {
        throw new Error("No valid Paymob transaction ID found for this booking.");
      }

      // Step A: Authenticate with Paymob to get Auth Token
      const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: paymobApiKey }),
      });

      if (!authRes.ok) {
        const authErrBody = await authRes.text();
        throw new Error(`Paymob Auth Token generation failed: ${authErrBody}`);
      }

      const authData = await authRes.json();
      const authToken = authData.token;

      if (!authToken) {
        throw new Error("Paymob returned empty auth token.");
      }

      // Step B: Call Refund API
      const amountCents = Math.round(refundAmount * 100);
      const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: authToken,
          transaction_id: Number(paymobTxnId),
          amount_cents: amountCents,
        }),
      });

      const refundData = await refundRes.json();
      console.log("Paymob Refund API Response:", JSON.stringify(refundData));

      if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
        refundSuccess = true;
        refundTxnId = String(refundData.id || refundData.transaction_id || "REFUND_SUCCESS");
      } else {
        paymobErrorMessage = refundData.message || refundData.detail || JSON.stringify(refundData);
      }
    } catch (paymobErr: any) {
      console.error("🚨 Paymob Refund API Error:", paymobErr.message || paymobErr);
      paymobErrorMessage = paymobErr.message || String(paymobErr);
    }

    // 8. Handle Refund Results
    if (refundSuccess) {
      // SUCCESS: Update booking & transaction ledger
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "refunded",
          refund_amount: refundAmount,
          refund_txn_id: refundTxnId,
          cancellation_reason: reason,
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      // Ledger entry
      await supabase.from("transactions").insert({
        user_id: booking.created_by_user_id || booking.player_id,
        booking_id: bookingId,
        amount: refundAmount,
        type: "refund",
        status: "completed",
        payment_method: booking.payment_method || "paymob",
        paymob_transaction_id: refundTxnId,
        description: `استرداد إلكتروني ناجح لقيمة حجز: ${booking.stadium_name}`,
        created_at: now.toISOString(),
      });

      // Send In-App Notification to User
      const playerUserId = booking.created_by_user_id || booking.player_id;
      if (playerUserId) {
        await supabase.from("notifications").insert({
          user_id: playerUserId,
          title: "تم استرداد المبلغ بنجاح! 💸",
          body: `تم إرجاع مبلغ (${refundAmount} ج.م) الخاص بحجز ${booking.stadium_name} إلى بطاقتك / محفظتك الإلكترونية بنجاح.`,
          type: "refund_success",
          created_at: now.toISOString(),
        });
      }

      // Notify Owner
      if (booking.owner_id) {
        await supabase.from("notifications").insert({
          user_id: booking.owner_id,
          title: "إلغاء حجز في ملعبك ⚠️",
          body: `قام اللاعب بإلغاء حجزه المقرر في ${booking.stadium_name} وتم إتاحة الموعد مجدداً.`,
          type: "booking_cancelled",
          created_at: now.toISOString(),
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          refund_amount: refundAmount,
          refund_txn_id: refundTxnId,
          message: "تم استرداد المبلغ بنجاح عبر Paymob وسيظهر في حسابك خلال 3 - 5 أيام عمل.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      // FAILED GATEWAY REFUND: Mark booking as cancelled with refund_failed status & notify Admin
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "refund_failed",
          cancellation_reason: `Paymob Gateway Error: ${paymobErrorMessage}`,
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      // Ledger entry for failed refund
      await supabase.from("transactions").insert({
        user_id: booking.created_by_user_id || booking.player_id,
        booking_id: bookingId,
        amount: refundAmount,
        type: "refund",
        status: "failed",
        payment_method: booking.payment_method || "paymob",
        description: `فشل استرداد إلكتروني عبر Paymob: ${paymobErrorMessage}`,
        created_at: now.toISOString(),
      });

      // Notify Admins to process manually
      const { data: admins } = await supabase
        .from("users")
        .select("id")
        .eq("role", "admin");

      if (admins && admins.length > 0) {
        const adminNotifications = admins.map((admin) => ({
          user_id: admin.id,
          title: "تنبيه: فشل استرداد آلي عبر Paymob 🚨",
          body: `تعذر الاسترداد الآلي للحجز #${bookingId.substring(0, 8)} بمبلغ ${refundAmount} ج.م. يرجى مراجعة لوحة Paymob لتنفيذ الاسترداد يدوياً.`,
          type: "admin_alert",
          created_at: now.toISOString(),
        }));
        await supabase.from("notifications").insert(adminNotifications);
      }

      return new Response(
        JSON.stringify({
          success: false,
          refund_failed: true,
          refund_amount: refundAmount,
          message: "تم إلغاء الحجز، ولكن تعذر إتمام الاسترداد التلقائي عبر بوابة الدفع. تم إخطار فريق الدعم الفني لمراجعة العملية وتحويل المبلغ لك يدوياً.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (err: any) {
    console.error("Unhandled Error in process_paymob_refund:", err);
    return new Response(
      JSON.stringify({ success: false, message: `حدث خطأ غير متوقع: ${err.message || err}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
