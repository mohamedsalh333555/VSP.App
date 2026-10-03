// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const adminRoles = ["admin", "co_founder", "cofounder", "super_admin"];

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const out = (body: any, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    if (req.method !== "POST") return out({ success: false, message: "Method not allowed" }, 405);

    const apiKey =
      Deno.env.get("PAYMOB_API_KEY") ||
      Deno.env.get("PAYMOB_SECRET_KEY") ||
      "";
    const url = Deno.env.get("SUPABASE_URL") || "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    if (!apiKey || !serviceKey) {
      return out({ success: false, message: "Server configuration error" }, 500);
    }

    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) return out({ success: false, message: "Unauthorized" }, 401);

    const admin = createClient(url, serviceKey);
    const { data: authData, error: authError } = await admin.auth.getUser(authHeader.slice(7).trim());
    if (authError || !authData?.user) return out({ success: false, message: "Unauthorized" }, 401);

    const caller = authData.user;
    const body = await req.json().catch(() => ({}));
    const bookingId = String(body.booking_id || "").trim();
    const reason = String(body.reason || "Cancelled by user").trim();
    if (!bookingId) return out({ success: false, message: "Missing booking_id" }, 400);

    const { data: booking, error: bookingError } = await admin
      .from("bookings")
      .select(
        "id, created_by_user_id, user_id, owner_id, stadium_name, status, payment_method, payment_status, payment_reconcile_state, total_price, deposit_paid, created_at, start_time"
      )
      .eq("id", bookingId)
      .maybeSingle();

    if (bookingError || !booking) return out({ success: false, message: "الحجز غير موجود." }, 404);

    const { data: profile } = await admin
      .from("users")
      .select("role")
      .eq("id", caller.id)
      .maybeSingle();

    const isAdmin = adminRoles.includes(String(profile?.role || "").toLowerCase());
    const isPlayer = booking.created_by_user_id === caller.id || booking.user_id === caller.id;
    const isOwner = booking.owner_id === caller.id;

    if (!isPlayer && !isOwner && !isAdmin) {
      return out({ success: false, message: "غير مصرح لك بإلغاء هذا الحجز." }, 403);
    }

    if (booking.status === "cancelled") {
      // A cancelled booking can still be awaiting its Paymob refund; allow the controlled
      // refund processor to finish that state instead of silently returning.
      if (
        !["paymob", "card", "wallet", "online", "visa", "mastercard", "meeza"].includes(
          String(booking.payment_method || "").toLowerCase()
        ) ||
        !["refund_pending"].includes(String(booking.payment_status || ""))
      ) {
        return out({ success: true, message: "الحجز ملغى بالفعل مسبقاً." });
      }
    }

    const now = new Date();
    const created = new Date(booking.created_at);
    const withinGrace =
      now.getTime() - created.getTime() >= 0 &&
      now.getTime() - created.getTime() <= 20 * 60 * 1000;

    if (isPlayer && booking.status === "completed") {
      return out({ success: false, message: "لا يمكن إلغاء حجز مكتمل." }, 400);
    }

    if (
      isPlayer &&
      booking.status !== "cancelled" &&
      new Date(booking.start_time).getTime() <= now.getTime() + 6 * 60 * 60 * 1000 &&
      !withinGrace
    ) {
      return out(
        {
          success: false,
          message: "لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة).",
        },
        400
      );
    }

    if (String(booking.payment_method || "").toLowerCase() === "cash") {
      const { data: cashResult, error: cashError } = await admin.rpc("cancel_booking_with_refund_atomic", {
        p_booking_id: bookingId,
        p_user_id: caller.id,
        p_reason: reason,
      });
      if (cashError) return out({ success: false, message: "تعذر إلغاء الحجز النقدي." }, 409);
      return out(cashResult || { success: true });
    }

    // Claim the refund atomically before calling Paymob. The booking row is locked and
    // the refund transaction is leased, so concurrent requests cannot dispatch two refunds.
    const { data: claim, error: claimError } = await admin.rpc("claim_booking_gateway_refund_atomic", {
      p_booking_id: bookingId,
      p_reason: reason,
    });

    if (claimError) {
      console.error("Refund claim RPC failed:", claimError);
      return out({ success: false, message: "تعذر تجهيز الاسترداد بأمان." }, 409);
    }

    if (claim?.already_refunded === true) {
      return out({ success: true, already_refunded: true, message: "تم استرداد المبلغ بالفعل." });
    }

    if (claim?.error === "refund_in_progress") {
      return out(
        {
          success: false,
          refund_pending: true,
          message: "طلب الاسترداد قيد المعالجة بالفعل. لن يتم إرسال طلب مكرر لبوابة الدفع.",
        },
        200
      );
    }

    if (claim?.error === "multiple_paymob_payments_require_manual_refund") {
      return out(
        {
          success: false,
          refund_pending: true,
          manual_review: true,
          payment_count: claim.payment_count,
          message: "هذا الحجز يحتوي على أكثر من دفعة إلكترونية، وتم إيقاف الاسترداد التلقائي لحمايته من استرداد خاطئ. يحتاج مراجعة مالية.",
        },
        200
      );
    }

    if (claim?.error === "no_refundable_paymob_payment") {
      await admin
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "refund_pending",
          payment_reconcile_state: "refund_pending",
          cancellation_reason: reason,
          cancelled_at: now.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq("id", bookingId);
      return out(
        {
          success: false,
          refund_failed: true,
          refund_pending: true,
          message: "تم إلغاء الحجز وتحويل الاسترداد للمراجعة اليدوية لعدم وجود دفعة Paymob قابلة للاسترداد.",
        },
        200
      );
    }

    if (claim?.error || claim?.success !== true || claim?.claimed !== true) {
      return out({ success: false, message: "تعذر تجهيز الاسترداد." }, 409);
    }

    const paymobTxnId = String(claim.paymob_transaction_id || "").replace(/D/g, "");
    const refundAmount = Math.round(Number(claim.refund_amount || 0) * 100) / 100;
    const refundGrossAmount = Math.round(Number(claim.refund_gross_amount || refundAmount) * 100) / 100;

    if (!paymobTxnId || refundAmount <= 0 || refundGrossAmount <= 0) {
      return out({ success: false, message: "بيانات دفعة Paymob القابلة للاسترداد غير صالحة." }, 409);
    }

    const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: apiKey }),
    });

    if (!authRes.ok) {
      const errorText = await authRes.text();
      await admin
        .from("transactions")
        .update({
          metadata: {
            ...(claim || {}),
            gateway_error: "Paymob authentication failed",
            gateway_error_detail: errorText,
            refund_lease_expires_at: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("id", claim.refund_transaction_id);
      return out(
        {
          success: false,
          refund_pending: true,
          message: "تم حفظ الاسترداد كقيد انتظار لأن بوابة الدفع لم تستجب بالمصادقة.",
        },
        200
      );
    }

    const authData = await authRes.json();
    if (!authData.token) {
      return out({ success: false, refund_pending: true, message: "Paymob لم يرجع رمز مصادقة صالح." }, 200);
    }

    let refundResponse: any = {};
    let refundHttpOk = false;
    try {
      const rr = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: authData.token,
          transaction_id: Number(paymobTxnId),
          amount_cents: Math.round(refundGrossAmount * 100),
        }),
      });
      refundHttpOk = rr.ok;
      refundResponse = await rr.json().catch(() => ({}));
    } catch (gatewayError: any) {
      await admin
        .from("transactions")
        .update({
          metadata: {
            ...(claim || {}),
            gateway_error: gatewayError?.message || String(gatewayError),
            refund_lease_expires_at: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("id", claim.refund_transaction_id);
      return out(
        {
          success: false,
          refund_pending: true,
          message: "تعذر تأكيد نتيجة الاسترداد من Paymob، وتم الاحتفاظ بالطلب للمراجعة/إعادة المحاولة.",
        },
        200
      );
    }

    const refundSuccess =
      refundHttpOk &&
      (refundResponse.success === true || refundResponse.is_refund === true || Boolean(refundResponse.id));

    if (!refundSuccess) {
      await admin
        .from("transactions")
        .update({
          metadata: {
            ...(claim || {}),
            gateway_error: refundResponse?.message || refundResponse?.detail || "refund_failed",
            refund_response: refundResponse,
            refund_lease_expires_at: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("id", claim.refund_transaction_id);

      return out(
        {
          success: false,
          refund_failed: true,
          refund_pending: true,
          refund_amount: refundAmount,
          message: "تم حفظ طلب الاسترداد للمراجعة لأن Paymob لم يؤكده.",
        },
        200
      );
    }

    const refundTxnId = String(refundResponse.id || refundResponse.transaction_id || paymobTxnId);
    const { data: recorded, error: recordError } = await admin.rpc("record_booking_gateway_refund_atomic", {
      p_booking_id: bookingId,
      p_refund_amount: refundAmount,
      p_refund_txn_id: refundTxnId,
      p_refund_payment_method: String(booking.payment_method || "card").toLowerCase().includes("wallet")
        ? "wallet"
        : "card",
      p_refund_gross_amount: refundGrossAmount,
    });

    if (recordError || !recorded?.success) {
      console.error("Failed to reconcile successful refund:", recordError || recorded);
      return out(
        {
          success: false,
          refund_pending: true,
          message: "تم تأكيد الاسترداد من Paymob لكن تعذر تسجيله محاسبياً؛ الحالة محفوظة للمراجعة.",
        },
        200
      );
    }

    await admin
      .from("bookings")
      .update({ cancellation_reason: reason })
      .eq("id", bookingId);

    return out({
      success: true,
      refund_amount: refundAmount,
      refund_gross_amount: refundGrossAmount,
      refund_txn_id: refundTxnId,
      message: "تم استرداد المبلغ بنجاح عبر Paymob.",
    });
  } catch (e) {
    console.error("process_paymob_refund:", e);
    return out(
      {
        success: false,
        message: "تعذر إتمام الاسترداد حالياً. تم حفظ الحالة للمراجعة.",
      },
      500
    );
  }
});
