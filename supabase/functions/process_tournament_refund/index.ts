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

    // Verify if caller is internal worker or service_role
    let isServiceRole = (token === serviceKey);
    if (!isServiceRole) {
      // Check against internal_function_secrets for DB trigger / cron callers
      const { data: secretRows } = await adminClient
        .from("internal_function_secrets")
        .select("secret")
        .in("name", ["fcm_push", "service_role", "refund_worker"]);
      if (secretRows && secretRows.some((r: any) => r.secret === token)) {
        isServiceRole = true;
      }
    }

    let callerUser: any = null;
    if (!isServiceRole) {
      const { data: { user: caller }, error: authError } = await adminClient.auth.getUser(token);
      if (authError || !caller) {
        return new Response(
          JSON.stringify({ success: false, message: "Unauthorized" }),
          { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
      callerUser = caller;
    }

    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      body = {};
    }

    // ============================================================
    // MODE 1: Autonomous Cancellation Refund Queue Processing (Worker SSOT)
    // Strictly restricted to Internal Worker / Server Secret Callers
    // ============================================================
    if (body.action === "process_queue" || (!body.team_id && !body.championship_id)) {
      if (!isServiceRole) {
        return new Response(
          JSON.stringify({ success: false, message: "Forbidden: process_queue is restricted to server internal workers." }),
          { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // Helper function to get Paymob auth token
      const getPaymobToken = async (): Promise<string> => {
        const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ api_key: apiKey }),
        });
        const authData = await authRes.json();
        if (!authRes.ok || !authData.token) {
          throw new Error("Paymob authentication failed: " + JSON.stringify(authData));
        }
        return authData.token;
      };

      let paymobToken = "";
      try {
        paymobToken = await getPaymobToken();
      } catch (authErr: any) {
        console.error("Paymob token generation failed:", authErr);
        return new Response(
          JSON.stringify({ success: false, message: "Paymob authentication failed", error: String(authErr?.message || authErr) }),
          { status: 502, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      const results = [];
      let processedCount = 0;

      while (true) {
        const { data: claim, error: claimErr } = await adminClient.rpc("claim_next_cancellation_refund_atomic");
        if (claimErr) {
          console.error("Error claiming refund item:", claimErr);
          break;
        }

        if (!claim || !claim.found || !claim.refund) {
          break; // Queue is empty or no claimable items
        }

        const item = claim.refund;
        processedCount++;

        // 1. Data Integrity Assertion: gross_amount in order matches queue amount
        const { data: order, error: orderErr } = await adminClient
          .from("tournament_orders")
          .select("id, order_reference, amount, gross_amount, payment_status")
          .eq("id", item.order_id)
          .single();

        const orderGross = Number(order?.gross_amount ?? order?.amount ?? 0);
        const queueAmount = Number(item.amount);

        if (orderErr || !order || Math.abs(orderGross - queueAmount) > 0.01) {
          const reason = `Amount integrity mismatch: order=${orderGross} vs queue=${queueAmount}`;
          console.error(`Item ${item.id} failed integrity check:`, reason);
          const nowIso = new Date().toISOString();

          await adminClient.from("cancellation_refund_queue").update({
            status: "failed_manual_review",
            failure_reason: reason,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await adminClient.from("tournament_orders").update({
            payment_status: "refund_failed_manual_review",
            updated_at: nowIso,
          }).eq("id", item.order_id);

          await adminClient.from("championship_registrations").update({
            payment_status: "refund_failed_manual_review",
            updated_at: nowIso,
          }).eq("id", item.registration_id);

          results.push({ id: item.id, order_id: item.order_id, success: false, error: reason });
          continue;
        }

        // 2. Prevent Double Refund: If already marked refunded, complete immediately
        if (order.payment_status === "refunded") {
          const nowIso = new Date().toISOString();
          await adminClient.from("cancellation_refund_queue").update({
            status: "completed",
            processed_at: nowIso,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          results.push({ id: item.id, order_id: item.order_id, success: true, note: "already_refunded" });
          continue;
        }

        // 3. Call Paymob Refund API
        const txnId = String(item.paymob_transaction_id || "").replace(/\D/g, "");
        const refundAmtCents = Math.round(queueAmount * 100);

        let refundSuccess = false;
        let refundError: string | null = null;
        let refundId: string | null = null;

        if (!txnId || refundAmtCents <= 0) {
          refundError = "Invalid transaction ID or zero amount";
        } else {
          try {
            const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                auth_token: paymobToken,
                transaction_id: Number(txnId),
                amount_cents: refundAmtCents,
              }),
            });
            const refundData = await refundRes.json();
            const msgLower = JSON.stringify(refundData).toLowerCase();

            if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "");
            } else if (msgLower.includes("already refunded") || msgLower.includes("already voided")) {
              // Double refund prevention: Paymob indicates already refunded
              refundSuccess = true;
              refundId = "ALREADY_REFUNDED_AT_GATEWAY";
            } else {
              refundError = String(refundData.message || refundData.detail || JSON.stringify(refundData));
            }
          } catch (e: any) {
            refundError = e?.message || String(e);
          }
        }

        const nowIso = new Date().toISOString();

        if (refundSuccess) {
          await adminClient.from("cancellation_refund_queue").update({
            status: "completed",
            processed_at: nowIso,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await adminClient.from("tournament_orders").update({
            payment_status: "refunded",
            updated_at: nowIso,
          }).eq("id", item.order_id);

          await adminClient.from("championship_registrations").update({
            payment_status: "refunded",
            updated_at: nowIso,
          }).eq("id", item.registration_id);

          results.push({ id: item.id, order_id: item.order_id, success: true, refund_id: refundId });
        } else {
          console.error(`Refund failed for queue item ${item.id}:`, refundError);
          if (item.retry_count >= 3) {
            await adminClient.from("cancellation_refund_queue").update({
              status: "failed_manual_review",
              failure_reason: refundError,
              locked_until: null,
              updated_at: nowIso,
            }).eq("id", item.id);

            await adminClient.from("tournament_orders").update({
              payment_status: "refund_failed_manual_review",
              updated_at: nowIso,
            }).eq("id", item.order_id);

            await adminClient.from("championship_registrations").update({
              payment_status: "refund_failed_manual_review",
              updated_at: nowIso,
            }).eq("id", item.registration_id);
          } else {
            // Transient failure: return to pending state for lease recovery or next cron cycle
            await adminClient.from("cancellation_refund_queue").update({
              status: "pending",
              failure_reason: refundError,
              locked_until: null,
              updated_at: nowIso,
            }).eq("id", item.id);
          }

          results.push({ id: item.id, order_id: item.order_id, success: false, error: refundError });
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          action: "process_queue",
          processed_count: processedCount,
          results,
        }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // ============================================================
    // MODE 2: Single Team Withdrawal Refund (Dedicated Pipeline)
    // ============================================================
    const championshipId = String(body.championship_id || "");
    const teamId = String(body.team_id || "");

    if (!championshipId || !teamId) {
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
      const msgLower = JSON.stringify(refundData).toLowerCase();

      if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
        refundSuccess = true;
        refundId = String(refundData.id || refundData.transaction_id || "");
      } else if (msgLower.includes("already refunded") || msgLower.includes("already voided")) {
        refundSuccess = true;
        refundId = "ALREADY_REFUNDED_AT_GATEWAY";
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