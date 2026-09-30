// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, message: "Method not allowed" }),
      { status: 405, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }

  try {
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const apiKey = Deno.env.get("PAYMOB_API_KEY") || Deno.env.get("PAYMOB_SECRET_KEY") || "";
    if (!serviceKey || !apiKey) {
      throw new Error("Server payment configuration is incomplete.");
    }

    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    const adminClient = createClient(supabaseUrl, serviceKey);
    const {
      data: { user: caller },
      error: authError,
    } = await adminClient.auth.getUser(token);
    if (authError || !caller) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const body = await req.json();
    const championshipId = String(body.championship_id || "");

    if (!championshipId) {
      return new Response(
        JSON.stringify({ success: false, message: "معرف البطولة مطلوب." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // ============================================================
    // MODE B: Bulk cancellation refunds for an entire cancelled championship
    // ============================================================
    if (body.action === "process_cancellation_refunds" || (!body.team_id && body.action !== "single_withdrawal")) {
      const { data: champ, error: champErr } = await adminClient
        .from("championships")
        .select("id, owner_id, status, name")
        .eq("id", championshipId)
        .single();

      if (champErr || !champ) {
        return new Response(
          JSON.stringify({ success: false, message: "البطولة غير موجودة." }),
          { status: 404, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // Check caller is owner or admin
      const { data: userRecord } = await adminClient
        .from("users")
        .select("role")
        .eq("id", caller.id)
        .single();
      const isAdmin = ["admin", "co_founder", "super_admin", "cofounder"].includes(userRecord?.role || "");
      if (caller.id !== champ.owner_id && !isAdmin) {
        return new Response(
          JSON.stringify({ success: false, message: "غير مصرح لك بمعالجة استردادات هذه البطولة." }),
          { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // Fetch all orders with refund_requested
      const { data: pendingOrders, error: ordersErr } = await adminClient
        .from("tournament_orders")
        .select("id, order_reference, paymob_transaction_id, amount, captain_user_id")
        .eq("championship_id", championshipId)
        .eq("payment_status", "refund_requested");

      if (ordersErr) throw ordersErr;

      if (!pendingOrders || pendingOrders.length === 0) {
        return new Response(
          JSON.stringify({
            success: true,
            message: "لا توجد التزامات استرداد معلقة لهذه البطولة.",
            processed_count: 0,
          }),
          { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // Authenticate with Paymob once
      let paymobToken = "";
      try {
        const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ api_key: apiKey }),
        });
        const authData = await authRes.json();
        if (!authRes.ok || !authData.token) throw new Error("Paymob authentication failed.");
        paymobToken = authData.token;
      } catch (authErr: any) {
        console.error("Paymob auth failed in bulk refund:", authErr);
        return new Response(
          JSON.stringify({
            success: false,
            message: "تعذر الاتصال ببوابة الدفع لتنفيذ الاسترداد المالي.",
            error: String(authErr?.message || authErr),
          }),
          { status: 502, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      const results = [];
      for (const order of pendingOrders) {
        const orderRef = String(order.order_reference || "");
        const txnId = String(order.paymob_transaction_id || "");
        const refundAmt = Math.round(Number(order.amount || 0) * 100) / 100;

        let refundSuccess = false;
        let refundId: string | null = null;
        let refundError: string | null = null;

        if (!txnId || refundAmt <= 0) {
          refundError = "Invalid transaction ID or zero amount";
        } else {
          try {
            const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                auth_token: paymobToken,
                transaction_id: Number(txnId.replace(/\D/g, "")),
                amount_cents: Math.round(refundAmt * 100),
              }),
            });
            const refundData = await refundRes.json();
            if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "");
            } else {
              refundError = refundData.message || refundData.detail || JSON.stringify(refundData);
            }
          } catch (e: any) {
            refundError = e?.message || String(e);
          }
        }

        // Finalize each order atomically in DB
        const { data: finalized, error: finalizeErr } = await adminClient.rpc(
          "finalize_championship_cancellation_refund_atomic",
          {
            p_championship_id: championshipId,
            p_order_reference: orderRef,
            p_refund_success: refundSuccess,
            p_refund_txn_id: refundId,
            p_error_message: refundError,
          }
        );

        results.push({
          order_reference: orderRef,
          refund_success: refundSuccess,
          refund_id: refundId,
          error: refundError,
          db_result: finalized,
        });
      }

      const successCount = results.filter((r) => r.refund_success).length;
      const failCount = results.filter((r) => !r.refund_success).length;

      return new Response(
        JSON.stringify({
          success: true,
          championship_id: championshipId,
          total_orders: pendingOrders.length,
          refunded_count: successCount,
          manual_review_count: failCount,
          details: results,
        }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // ============================================================
    // MODE A: Single Team Withdrawal Refund
    // ============================================================
    const teamId = String(body.team_id || "");
    if (!teamId) {
      return new Response(
        JSON.stringify({ success: false, message: "بيانات الانسحاب غير مكتملة." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const userClient = createClient(supabaseUrl, token, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: prep, error: prepError } = await userClient.rpc(
      "withdraw_team_from_championship_atomic",
      {
        p_championship_id: championshipId,
        p_team_id: teamId,
        p_reason: String(body.reason || "انسحاب الفريق"),
      }
    );
    if (prepError) throw prepError;
    if (!prep?.success) {
      return new Response(
        JSON.stringify(prep || { success: false, message: "تعذر تنفيذ الانسحاب." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    if (prep.refund_required !== true) {
      return new Response(JSON.stringify(prep), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const orderReference = String(prep.order_reference || "");
    const transactionId = String(prep.paymob_transaction_id || "");
    const refundAmount = Math.round(Number(prep.refund_amount || 0) * 100) / 100;
    if (!orderReference || !transactionId || refundAmount <= 0) {
      return new Response(
        JSON.stringify({
          success: false,
          refund_failed: true,
          message: "تعذر تجهيز بيانات الاسترداد. لم يتم إخراج الفريق من البطولة.",
        }),
        { status: 409, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    let refundSuccess = false;
    let refundId: string | null = null;
    let refundError: string | null = null;

    try {
      const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: apiKey }),
      });
      const authData = await authRes.json();
      if (!authRes.ok || !authData.token) throw new Error("Paymob authentication failed.");

      const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: authData.token,
          transaction_id: Number(transactionId.replace(/\D/g, "")),
          amount_cents: Math.round(refundAmount * 100),
        }),
      });
      const refundData = await refundRes.json();
      if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
        refundSuccess = true;
        refundId = String(refundData.id || refundData.transaction_id || "");
      } else {
        refundError = refundData.message || refundData.detail || JSON.stringify(refundData);
      }
    } catch (e: any) {
      refundError = e?.message || String(e);
    }

    const { data: finalized, error: finalizeError } = await adminClient.rpc(
      "finalize_team_withdrawal_refund_atomic",
      {
        p_championship_id: championshipId,
        p_team_id: teamId,
        p_order_reference: orderReference,
        p_refund_success: refundSuccess,
        p_refund_amount: refundAmount,
        p_refund_txn_id: refundId,
        p_error_message: refundError,
      }
    );
    if (finalizeError) throw finalizeError;

    return new Response(
      JSON.stringify({
        ...finalized,
        championship_id: championshipId,
        team_id: teamId,
        order_reference: orderReference,
        refund_amount: refundAmount,
        refund_success: refundSuccess,
      }),
      { status: refundSuccess ? 200 : 409, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (err: any) {
    console.error("process_tournament_refund error", err);
    return new Response(
      JSON.stringify({
        success: false,
        message: "تعذر إتمام استرداد اشتراك البطولة حالياً.",
        error: String(err?.message || err),
      }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});