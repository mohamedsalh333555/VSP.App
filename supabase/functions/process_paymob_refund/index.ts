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

    // Security Check: Caller must be the booking creator/user, stadium owner, or admin
    const isCallerPlayer = booking.created_by_user_id === callerUser.id || booking.user_id === callerUser.id;
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

    // Check 6-Hour Cancellation Policy for Players & 20-Minute Grace Window
    const now = new Date();
    const matchStartTime = new Date(booking.start_time);
    const bookingCreatedAt = new Date(booking.created_at || booking.created_at_utc || now);
    const minutesSinceCreation = (now.getTime() - bookingCreatedAt.getTime()) / (60 * 1000);
    const isWithin20MinGrace = minutesSinceCreation >= 0 && minutesSinceCreation <= 20;
    const sixHoursFromNow = new Date(now.getTime() + 6 * 60 * 60 * 1000);

    if (isCallerPlayer && matchStartTime <= sixHoursFromNow && !isWithin20MinGrace) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من إتمام الحجز وفقاً للائحة الاسترداد).",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 🔒 Idempotency Guard: Prevent double refund if already cancelled, refunded, or txn exists
    if (booking.status === "cancelled" || booking.payment_status === "refunded" || Boolean(booking.refund_transaction_id)) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "الحجز ملغى أو تم استرداد مبلغه بالفعل مسبقاً.",
          refund_amount: booking.refund_amount || 0,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const isPaid = booking.is_paid || booking.is_deposit_paid || booking.payment_status === "paid" || booking.payment_status === "confirmed";

    // If unpaid, perform immediate soft cancellation
    if (!isPaid) {
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

    // =========================================================================
    // 🔒 6. FINANCIAL LEDGER VERIFICATION (IMMUTABLE SOURCE OF TRUTH + FALLBACK)
    // =========================================================================
    const { data: paymentTx, error: txErr } = await supabase
      .from("transactions")
      .select("id, amount, paymob_transaction_id, reference_number, status, type")
      .eq("booking_id", bookingId)
      .eq("status", "completed")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    let verifiedRefundAmount = 0;
    let paymobTxnId: string | null = null;

    if (paymentTx && paymentTx.amount && Number(paymentTx.amount) > 0) {
      verifiedRefundAmount = Number(paymentTx.amount);
      paymobTxnId = paymentTx.paymob_transaction_id || paymentTx.reference_number || booking.paymob_transaction_id || booking.paymob_txn_id || booking.payment_transaction_id;
    } else if (booking.paymob_transaction_id || booking.paymob_txn_id || booking.payment_transaction_id) {
      // Resilient Fallback: If webhook transaction row is missing for previous bookings,
      // recover verified amount and txn ID safely from the booking record
      verifiedRefundAmount = Number(booking.deposit_paid || booking.deposit_amount || booking.total_price || 0);
      paymobTxnId = booking.paymob_transaction_id || booking.paymob_txn_id || booking.payment_transaction_id;
      console.log(`ℹ️ Recovered payment details from booking record: Amount=${verifiedRefundAmount} EGP, Txn=${paymobTxnId}`);
    }

    if (!verifiedRefundAmount || verifiedRefundAmount <= 0) {
      console.error(`🚨 Security Failure: No verified completed payment transaction found for booking ${bookingId}`);

      // Fail-Closed: Mark as refund_failed and alert Admins for manual review
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "refund_failed",
          cancellation_reason: "تعذر التحقق من المبلغ المدفوع الفعلي من سجل المعاملات المالية",
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      // Notify Admins
      const { data: admins } = await supabase
        .from("users")
        .select("id")
        .eq("role", "admin");

      if (admins && admins.length > 0) {
        const adminNotifications = admins.map((admin) => ({
          user_id: admin.id,
          title: "تنبيه أمني: تعذر التحقق من المبلغ المدفوع للاسترداد",
          body: `فشل التحقق المالي للحجز #${bookingId.substring(0, 8)}. لا يوجد قيد دفع مطابق ومكتمل في جدول المعاملات. يرجى المراجعة اليدوية.`,
          type: "admin_alert",
          created_at: now.toISOString(),
        }));
        await supabase.from("notifications").insert(adminNotifications);
      }

      return new Response(
        JSON.stringify({
          success: false,
          refund_failed: true,
          message: "تعذر التحقق من المبلغ المدفوع الفعلي لسجل المعاملة. تم إخطار الإدارة لمراجعة العملية يدوياً.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // If cancelled in the 20-minute grace window when match is less than 6 hours away:
    // Deduct non-refundable administrative and payment gateway expenses (Paymob 2.4% + 3 EGP + platform fee)
    let adminDeduction = 0;
    if (isWithin20MinGrace && matchStartTime <= sixHoursFromNow) {
      adminDeduction = Math.min(verifiedRefundAmount, Math.round((verifiedRefundAmount * 0.074 + 3.0) * 100) / 100);
      verifiedRefundAmount = Math.max(0, verifiedRefundAmount - adminDeduction);
      console.log(`ℹ️ Grace window cancellation: deducted admin fees ${adminDeduction} EGP. Net refund to Paymob: ${verifiedRefundAmount} EGP`);
    }

    // Strip non-numeric prefixes (e.g. "PAYMOB_12345" -> "12345")
    if (typeof paymobTxnId === "string") {
      const match = paymobTxnId.match(/\d+/);
      if (match) {
        paymobTxnId = match[0];
      }
    }

    if (!paymobTxnId) {
      console.error(`🚨 Missing Paymob Transaction ID for verified payment ${paymentTx.id}`);
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "refund_failed",
          cancellation_reason: "رقم معاملة Paymob غير متوفر في سجل المعاملات المالية",
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      return new Response(
        JSON.stringify({
          success: false,
          refund_failed: true,
          message: "تعذر العثور على رقم معاملة الدفع لدى بوابة Paymob. تم تحويل الطلب للدعم الفني.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`🔄 Initiating Paymob Refund for Booking ${bookingId}: TxnID=${paymobTxnId}, Verified Ledger Amount=${verifiedRefundAmount} EGP`);

    // =========================================================================
    // 7. CALL PAYMOB REFUND API WITH VERIFIED LEDGER AMOUNT
    // =========================================================================
    let refundSuccess = false;
    let refundTxnId: string | null = null;
    let paymobErrorMessage = "";
    let refundData: any = null;

    try {
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

      // Step B: Call Refund API with exact verified cents from ledger
      const amountCents = Math.round(verifiedRefundAmount * 100);
      const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: authToken,
          transaction_id: Number(paymobTxnId),
          amount_cents: amountCents,
        }),
      });

      refundData = await refundRes.json();
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

    // =========================================================================
    // 8. HANDLE REFUND RESULTS & WRITE AUDIT TRAIL
    // =========================================================================
    if (refundSuccess) {
      // SUCCESS: Detect refund channel & update booking & transaction ledger
      const detectedRefundMethod = (() => {
        const sub = (refundData?.source_data?.sub_type || refundData?.source_data?.type || booking.payment_method || "").toLowerCase();
        if (sub.includes("wallet") || sub.includes("vodafone") || sub.includes("orange") || sub.includes("etisalat") || sub.includes("instapay")) {
          return "wallet";
        }
        if (sub.includes("card") || sub.includes("paymob") || sub.includes("online")) {
          return "card";
        }
        return booking.payment_method || "card";
      })();

      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "refunded",
          refund_transaction_id: refundTxnId,
          refunded_at: now.toISOString(),
          refund_payment_method: detectedRefundMethod,
          refund_amount: verifiedRefundAmount,
          cancellation_reason: reason,
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      // Immutable Ledger entry for completed refund
      await supabase.from("transactions").insert({
        user_id: booking.created_by_user_id || booking.user_id,
        booking_id: bookingId,
        amount: verifiedRefundAmount,
        type: "refund",
        status: "completed",
        payment_method: booking.payment_method || "paymob",
        paymob_transaction_id: refundTxnId,
        reference_number: refundTxnId,
        description: `استرداد إلكتروني ناجح لقيمة حجز: ${booking.stadium_name}`,
        created_at: now.toISOString(),
      });

      // Send In-App Notification to User
      const playerUserId = booking.created_by_user_id || booking.user_id;
      if (playerUserId) {
        await supabase.from("notifications").insert({
          user_id: playerUserId,
          title: "تم استرداد المبلغ بنجاح",
          body: `تم إرجاع مبلغ (${verifiedRefundAmount} ج.م) الخاص بحجز ${booking.stadium_name} إلى بطاقتك / محفظتك الإلكترونية بنجاح.`,
          type: "refund_success",
          created_at: now.toISOString(),
        });
      }

      // Notify Owner
      if (booking.owner_id) {
        await supabase.from("notifications").insert({
          user_id: booking.owner_id,
          title: "إلغاء حجز في ملعبك",
          body: `قام اللاعب بإلغاء حجزه المقرر في ${booking.stadium_name} وتم إتاحة الموعد مجدداً.`,
          type: "booking_cancelled",
          created_at: now.toISOString(),
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          refund_amount: verifiedRefundAmount,
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
          refund_amount: verifiedRefundAmount,
          cancellation_reason: `Paymob Gateway Error: ${paymobErrorMessage}`,
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);

      // Ledger entry for failed refund
      await supabase.from("transactions").insert({
        user_id: booking.created_by_user_id || booking.user_id,
        booking_id: bookingId,
        amount: verifiedRefundAmount,
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
          title: "تنبيه: فشل استرداد آلي عبر Paymob",
          body: `تعذر الاسترداد الآلي للحجز #${bookingId.substring(0, 8)} بمبلغ ${verifiedRefundAmount} ج.م. يرجى مراجعة لوحة Paymob لتنفيذ الاسترداد يدوياً.`,
          type: "admin_alert",
          created_at: now.toISOString(),
        }));
        await supabase.from("notifications").insert(adminNotifications);
      }

      return new Response(
        JSON.stringify({
          success: false,
          refund_failed: true,
          refund_amount: verifiedRefundAmount,
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
