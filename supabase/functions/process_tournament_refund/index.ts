// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { isConfirmedPaymobRefund, isAlreadyRefundedProviderMessage } from "../_shared/paymob_refund_safety.ts";
import { markTournamentRefundDispatched } from "../_shared/paymob_tournament_dispatch.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RefundNotificationInput = {
  userId: string | null | undefined;
  queueId: string;
  title: string;
  body: string;
  type?: "tournament_refund" | "tournament_refund_manual";
  metadata?: Record<string, unknown>;
};

// Best-effort, idempotent notification per refund queue row. It never calls Paymob.
async function ensureRefundNotification(adminClient: any, input: RefundNotificationInput): Promise<void> {
  const userId = String(input.userId || "").trim();
  const queueId = String(input.queueId || "").trim();
  if (!userId || !queueId) return;
  const type = input.type || "tournament_refund";
  try {
    const { data: existing, error: lookupError } = await adminClient
      .from("notifications").select("id").eq("user_id", userId).eq("type", type)
      .contains("metadata", { refund_queue_id: queueId }).limit(1);
    if (lookupError) {
      console.error("Refund notification idempotency check failed:", { queueId, error: lookupError.message });
      return;
    }
    if (existing && existing.length > 0) return;
    const { error: insertError } = await adminClient.from("notifications").insert({
      user_id: userId, title: input.title, body: input.body, type, is_read: false,
      metadata: { refund_queue_id: queueId, ...(input.metadata || {}) },
      created_at: new Date().toISOString(),
    });
    if (insertError) console.error("Refund customer notification insert failed:", { queueId, error: insertError.message });
  } catch (error: any) {
    // Notification failure must never retry an already-confirmed financial refund.
    console.error("Refund customer notification failed safely:", { queueId, error: error?.message || String(error) });
  }
}

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
    const apiKey = Deno.env.get("PAYMOB_API_KEY") || "";
    const missingConfig: string[] = [];
    if (!supabaseUrl) missingConfig.push("SUPABASE_URL");
    if (!serviceKey) missingConfig.push("SUPABASE_SERVICE_ROLE_KEY");
    if (!apiKey) missingConfig.push("PAYMOB_API_KEY");
    if (missingConfig.length > 0) {
      // Diagnostic reports names only. Never log or return secret values.
      console.error("Refund worker configuration missing variables:", missingConfig);
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

    // Verify if caller is internal worker using dedicated refund_worker secret
    let isServiceRole = (token === serviceKey);
    if (!isServiceRole) {
      // Check strictly against internal_function_secrets for refund_worker
      const { data: secretRows } = await adminClient
        .from("internal_function_secrets")
        .select("secret")
        .eq("name", "refund_worker");
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

      // Strictly verify caller has administrator privileges in users table
      const { data: userProfile } = await adminClient
        .from("users")
        .select("role")
        .eq("id", callerUser.id)
        .single();

      const isAdmin = userProfile && ["admin", "super_admin", "co_founder", "cofounder"].includes(userProfile.role);
      if (!isAdmin) {
        return new Response(
          JSON.stringify({ success: false, message: "Forbidden: Only administrators or authorized internal services can execute refunds." }),
          { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
    }

    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      body = {};
    }

    // Configuration-only diagnostic for the internal scheduler. Never calls Paymob or changes database rows.
    if (body.action === "diagnose_config") {
      if (!isServiceRole) {
        return new Response(
          JSON.stringify({ success: false, message: "Forbidden" }),
          { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
      return new Response(
        JSON.stringify({
          success: true,
          config_present: {
            SUPABASE_URL: Boolean(supabaseUrl),
            SUPABASE_SERVICE_ROLE_KEY: Boolean(serviceKey),
            PAYMOB_API_KEY: Boolean(apiKey),
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
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
          throw new Error("Paymob authentication failed");
        }
        return authData.token;
      };

      let paymobToken = "";
      try {
        paymobToken = await getPaymobToken();
      } catch (authErr: any) {
        console.error("Paymob token generation failed");
        return new Response(
          JSON.stringify({ success: false, message: "Paymob authentication failed" }),
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
          .select("id, order_reference, amount, base_amount, gross_amount, payment_status, captain_user_id")
          .eq("id", item.order_id)
          .single();

        const orderPrincipal = Number(order?.base_amount ?? 0);
        const orderGross = Number(order?.gross_amount ?? 0);
        const queueAmount = Number(item.amount);

        if (orderErr || !order || orderPrincipal <= 0 || Math.abs(orderPrincipal - queueAmount) > 0.01) {
          const reason = `Refund principal integrity mismatch: principal=${orderPrincipal}, originalGross=${orderGross}, queue=${queueAmount}`;
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

          await ensureRefundNotification(adminClient, { userId: order.captain_user_id, queueId: item.id, title: "تم استرداد رسوم البطولة بنجاح 💳", body: `تم تأكيد استرداد مبلغ ${queueAmount.toFixed(2)} ج.م عبر بوابة الدفع. قد يستغرق ظهوره حسب البنك أو المحفظة.`, metadata: { order_reference: order.order_reference, championship_id: item.championship_id, refund_amount: queueAmount } });
          results.push({ id: item.id, order_id: item.order_id, success: true, note: "already_refunded" });
          continue;
        }

        // 3. Call Paymob Refund API
        const txnId = String(item.paymob_transaction_id || "").replace(/\D/g, "");
        const refundAmtCents = Math.round(queueAmount * 100);

        let refundSuccess = false;
        let refundError: string | null = null;
        let refundId: string | null = null;
        let refundRequestSent = false;

        if (!txnId || refundAmtCents <= 0) {
          refundError = "Invalid transaction ID or zero amount";
        } else {
          try {
            // A dispatched call may have succeeded even when its response is lost.
            // Durably reserve this exact claim before any external refund.
            // Crashes after dispatch must not cause a second refund after 15m.
            const dispatchAllowed = await markTournamentRefundDispatched(adminClient, "cancellation_refund_queue", item);
            if (!dispatchAllowed) {
              results.push({ id: item.id, success: false, error: "REFUND_DISPATCH_GUARD_UNAVAILABLE" });
              continue;
            }
            refundRequestSent = true;
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
            if (isConfirmedPaymobRefund(refundRes.ok, refundData)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "");
            } else if (isAlreadyRefundedProviderMessage(refundData)) {
              // Text alone is not verified refund proof: manual reconciliation.
              refundError = "GATEWAY_ALREADY_REFUNDED_NEEDS_VERIFICATION";
            } else {
              refundError = "GATEWAY_REFUND_RESPONSE_UNCONFIRMED";
            }
          } catch (e: any) {
            // Never retain raw provider/network exception diagnostics.
            refundError = refundRequestSent
              ? "GATEWAY_OUTCOME_AMBIGUOUS_AFTER_DISPATCH" : "GATEWAY_REQUEST_NOT_SENT";
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

          // 🛡️ Ledger Coherence: Close transaction to completed
          await adminClient.from("transactions").update({
            status: "completed",
            metadata: {
              paymob_refund_id: refundId,
              refund_amount: queueAmount,
              original_gross_amount: orderGross,
              non_refundable_fee_amount: Number(Math.max(0, orderGross - queueAmount).toFixed(2)),
              completed_at: nowIso,
            },
            updated_at: nowIso,
          }).eq("championship_id", item.championship_id)
            .eq("type", "refund_request")
            .eq("paymob_transaction_id", item.paymob_transaction_id);

          await ensureRefundNotification(adminClient, { userId: order.captain_user_id, queueId: item.id, title: "تم استرداد رسوم البطولة بنجاح 💳", body: `تم تأكيد استرداد مبلغ ${queueAmount.toFixed(2)} ج.م عبر بوابة الدفع. قد يستغرق ظهوره حسب البنك أو المحفظة.`, metadata: { order_reference: order.order_reference, championship_id: item.championship_id, refund_amount: queueAmount, paymob_refund_id: refundId } });
          results.push({ id: item.id, order_id: item.order_id, success: true, refund_id: refundId });
        } else {
          console.error(`Refund failed for queue item ${item.id}:`, refundError);
          const isAmbiguousTimeout = refundError?.includes("GATEWAY_OUTCOME_AMBIGUOUS_AFTER_DISPATCH");

          if (item.retry_count >= 3 || isAmbiguousTimeout || refundRequestSent) {
            // Escalate to manual review immediately on ambiguous timeout or max retries
            // to strictly protect against double refund!
            await adminClient.from("cancellation_refund_queue").update({
              status: "failed_manual_review",
              failure_reason: refundRequestSent
                ? "GATEWAY_VERIFICATION_REQUIRED_BEFORE_RETRY" : refundError,
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

            // 🛡️ Ledger Coherence: Transition transaction to failed_manual_review
            await adminClient.from("transactions").update({
              status: "failed_manual_review",
              metadata: {
                failure_reason: refundError,
                failed_at: nowIso,
              },
              updated_at: nowIso,
            }).eq("championship_id", item.championship_id)
              .eq("type", "refund_request")
              .eq("paymob_transaction_id", item.paymob_transaction_id);
            await ensureRefundNotification(adminClient, { userId: order.captain_user_id, queueId: item.id, type: "tournament_refund_manual", title: "استرداد رسوم البطولة يحتاج متابعة", body: "تعذر تأكيد الاسترداد تلقائيًا حتى الآن. تم إيقاف إعادة المحاولة الآلية لحماية المبلغ، ويجري التحقق من حالة الدفع.", metadata: { order_reference: order.order_reference, championship_id: item.championship_id, refund_amount: queueAmount } });
          } else {
            // Transient failure before dispatch: return to pending state for lease recovery
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

      // ------------------------------------------------------------
      // 1v1 Cancellation Refund Queue Processing (SSOT)
      // ------------------------------------------------------------
      while (true) {
        const { data: claim1v1, error: claim1v1Err } = await adminClient.rpc("claim_next_1v1_cancellation_refund_atomic");
        if (claim1v1Err) {
          console.error("Error claiming 1v1 refund item:", claim1v1Err);
          break;
        }

        if (!claim1v1 || !claim1v1.found || !claim1v1.refund) {
          break; // 1v1 queue is empty or no claimable items
        }

        const item = claim1v1.refund;
        processedCount++;

        // 1. Data Integrity Assertion: gross_amount in order matches queue amount
        const { data: order, error: orderErr } = await adminClient
          .from("vsp_1v1_tournament_orders")
          .select("id, order_reference, amount, gross_amount, payment_status")
          .eq("id", item.order_id)
          .single();

        const orderPrincipal = Number(order?.amount ?? 0);
        const orderGross = Number(order?.gross_amount ?? 0);
        const queueAmount = Number(item.amount);

        if (orderErr || !order || orderPrincipal <= 0 || Math.abs(orderPrincipal - queueAmount) > 0.01) {
          const reason = `Refund principal integrity mismatch: principal=${orderPrincipal}, originalGross=${orderGross}, queue=${queueAmount}`;
          console.error(`1v1 Item ${item.id} failed integrity check:`, reason);
          const nowIso = new Date().toISOString();

          await adminClient.from("vsp_1v1_cancellation_refund_queue").update({
            status: "failed_manual_review",
            failure_reason: reason,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await adminClient.from("vsp_1v1_tournament_orders").update({
            payment_status: "refund_failed_manual_review",
            updated_at: nowIso,
          }).eq("id", item.order_id);

          await adminClient.from("transactions").update({
            status: "failed_manual_review",
            metadata: {
              failure_reason: reason,
              failed_at: nowIso,
            },
            updated_at: nowIso,
          }).eq("user_id", item.user_id)
            .eq("type", "refund_request")
            .eq("paymob_transaction_id", item.paymob_transaction_id);

          results.push({ id: item.id, order_id: item.order_id, type: "1v1", success: false, error: reason });
          continue;
        }

        // 2. Prevent Double Refund: If already marked refunded, complete immediately
        if (order.payment_status === "refunded") {
          const nowIso = new Date().toISOString();
          await adminClient.from("vsp_1v1_cancellation_refund_queue").update({
            status: "completed",
            processed_at: nowIso,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await ensureRefundNotification(adminClient, { userId: item.user_id, queueId: item.id, title: "تم استرداد رسوم بطولة 1 ضد 1 بنجاح 💳", body: `تم تأكيد استرداد مبلغ ${queueAmount.toFixed(2)} ج.م عبر بوابة الدفع. قد يستغرق ظهوره حسب البنك أو المحفظة.`, metadata: { order_reference: order.order_reference, tournament_id: item.tournament_id, refund_amount: queueAmount } });
          results.push({ id: item.id, order_id: item.order_id, type: "1v1", success: true, note: "already_refunded" });
          continue;
        }

        // 3. Call Paymob Refund API
        const txnId = String(item.paymob_transaction_id || "").replace(/\D/g, "");
        const refundAmtCents = Math.round(queueAmount * 100);

        let refundSuccess = false;
        let refundError: string | null = null;
        let refundId: string | null = null;
        let refundRequestSent = false;

        if (!txnId || refundAmtCents <= 0) {
          refundError = "Invalid transaction ID or zero amount";
        } else {
          try {
            // A dispatched call may have succeeded even when its response is lost.
            // Durably reserve this exact claim before any external refund.
            // Crashes after dispatch must not cause a second refund after 15m.
            const dispatchAllowed = await markTournamentRefundDispatched(adminClient, "vsp_1v1_cancellation_refund_queue", item);
            if (!dispatchAllowed) {
              results.push({ id: item.id, success: false, error: "REFUND_DISPATCH_GUARD_UNAVAILABLE" });
              continue;
            }
            refundRequestSent = true;
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
            if (isConfirmedPaymobRefund(refundRes.ok, refundData)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "");
            } else if (isAlreadyRefundedProviderMessage(refundData)) {
              // Text alone is not verified refund proof: manual reconciliation.
              refundError = "GATEWAY_ALREADY_REFUNDED_NEEDS_VERIFICATION";
            } else {
              refundError = "GATEWAY_REFUND_RESPONSE_UNCONFIRMED";
            }
          } catch (e: any) {
            // Never retain raw provider/network exception diagnostics.
            refundError = refundRequestSent
              ? "GATEWAY_OUTCOME_AMBIGUOUS_AFTER_DISPATCH" : "GATEWAY_REQUEST_NOT_SENT";
          }
        }

        const nowIso = new Date().toISOString();

        if (refundSuccess) {
          await adminClient.from("vsp_1v1_cancellation_refund_queue").update({
            status: "completed",
            processed_at: nowIso,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await adminClient.from("vsp_1v1_tournament_orders").update({
            payment_status: "refunded",
            updated_at: nowIso,
          }).eq("id", item.order_id);

          await adminClient.from("vsp_1v1_tournament_players").update({
            payment_status: "refunded",
            updated_at: nowIso,
          }).eq("tournament_id", item.tournament_id).eq("user_id", item.user_id);

          // 🛡️ Gate 3: Close transaction to completed with metadata
          await adminClient.from("transactions").update({
            status: "completed",
            metadata: {
              paymob_refund_id: refundId,
              refund_amount: queueAmount,
              original_gross_amount: orderGross,
              non_refundable_fee_amount: Number(Math.max(0, orderGross - queueAmount).toFixed(2)),
              completed_at: nowIso,
            },
            updated_at: nowIso,
          }).eq("user_id", item.user_id)
            .eq("type", "refund_request")
            .eq("paymob_transaction_id", item.paymob_transaction_id);

          await ensureRefundNotification(adminClient, { userId: item.user_id, queueId: item.id, title: "تم استرداد رسوم بطولة 1 ضد 1 بنجاح 💳", body: `تم تأكيد استرداد مبلغ ${queueAmount.toFixed(2)} ج.م عبر بوابة الدفع. قد يستغرق ظهوره حسب البنك أو المحفظة.`, metadata: { order_reference: order.order_reference, tournament_id: item.tournament_id, refund_amount: queueAmount, paymob_refund_id: refundId } });
          results.push({ id: item.id, order_id: item.order_id, type: "1v1", success: true, refund_id: refundId });
        } else {
          console.error(`1v1 Refund failed for queue item ${item.id}:`, refundError);
          const isAmbiguousTimeout = refundError?.includes("GATEWAY_OUTCOME_AMBIGUOUS_AFTER_DISPATCH");

          if (item.retry_count >= 3 || isAmbiguousTimeout || refundRequestSent) {
            await adminClient.from("vsp_1v1_cancellation_refund_queue").update({
              status: "failed_manual_review",
              failure_reason: refundRequestSent
                ? "GATEWAY_VERIFICATION_REQUIRED_BEFORE_RETRY" : refundError,
              locked_until: null,
              updated_at: nowIso,
            }).eq("id", item.id);

            await adminClient.from("vsp_1v1_tournament_orders").update({
              payment_status: "refund_failed_manual_review",
              updated_at: nowIso,
            }).eq("id", item.order_id);

            // 🛡️ Close transaction to failed_manual_review (never pending forever)
            await adminClient.from("transactions").update({
              status: "failed_manual_review",
              metadata: {
                failure_reason: refundError,
                failed_at: nowIso,
              },
              updated_at: nowIso,
            }).eq("user_id", item.user_id)
              .eq("type", "refund_request")
              .eq("paymob_transaction_id", item.paymob_transaction_id);
            await ensureRefundNotification(adminClient, { userId: item.user_id, queueId: item.id, type: "tournament_refund_manual", title: "استرداد رسوم بطولة 1 ضد 1 يحتاج متابعة", body: "تعذر تأكيد الاسترداد تلقائيًا حتى الآن. تم إيقاف إعادة المحاولة الآلية لحماية المبلغ، ويجري التحقق من حالة الدفع.", metadata: { order_reference: order.order_reference, tournament_id: item.tournament_id, refund_amount: queueAmount } });
          } else {
            await adminClient.from("vsp_1v1_cancellation_refund_queue").update({
              status: "pending",
              failure_reason: refundError,
              locked_until: null,
              updated_at: nowIso,
            }).eq("id", item.id);
          }

          results.push({ id: item.id, order_id: item.order_id, type: "1v1", success: false, error: refundError });
        }
      }

      // ------------------------------------------------------------
      // Team League Cancellation Refund Queue Processing (SSOT)
      // ------------------------------------------------------------
      while (true) {
        const { data: claimLeague, error: claimLeagueErr } = await adminClient.rpc("claim_next_team_league_cancellation_refund_atomic");
        if (claimLeagueErr) {
          console.error("Error claiming team league refund item:", claimLeagueErr);
          break;
        }

        if (!claimLeague || !claimLeague.found || !claimLeague.refund) {
          break; // Team league queue is empty or no claimable items
        }

        const item = claimLeague.refund;
        processedCount++;

        // 1. Data Integrity Assertion
        const { data: payment, error: paymentErr } = await adminClient
          .from("team_league_payments")
          .select("id, order_reference, amount, gross_amount, payment_status")
          .eq("id", item.payment_id)
          .single();

        const paymentPrincipal = Number(payment?.amount ?? 0);
        const paymentGross = Number(payment?.gross_amount ?? 0);
        const queueAmount = Number(item.amount);

        if (paymentErr || !payment || paymentPrincipal <= 0 || Math.abs(paymentPrincipal - queueAmount) > 0.01) {
          const reason = `Refund principal integrity mismatch: principal=${paymentPrincipal}, originalGross=${paymentGross}, queue=${queueAmount}`;
          console.error(`Team League Item ${item.id} failed integrity check:`, reason);
          const nowIso = new Date().toISOString();

          await adminClient.from("team_league_cancellation_refund_queue").update({
            status: "failed_manual_review",
            failure_reason: reason,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await adminClient.from("team_league_payments").update({
            payment_status: "refund_failed_manual_review",
            updated_at: nowIso,
          }).eq("id", item.payment_id);

          await adminClient.from("transactions").update({
            status: "failed_manual_review",
            metadata: {
              failure_reason: reason,
              failed_at: nowIso,
            },
            updated_at: nowIso,
          }).eq("championship_id", item.championship_id)
            .eq("type", "refund_request")
            .eq("paymob_transaction_id", item.paymob_transaction_id);

          results.push({ id: item.id, payment_id: item.payment_id, type: "team_league", success: false, error: reason });
          continue;
        }

        // 2. Prevent Double Refund: If already marked refunded, complete immediately
        if (payment.payment_status === "refunded") {
          const nowIso = new Date().toISOString();
          await adminClient.from("team_league_cancellation_refund_queue").update({
            status: "completed",
            processed_at: nowIso,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await ensureRefundNotification(adminClient, { userId: item.user_id, queueId: item.id, title: "تم استرداد رسوم دوري الفرق بنجاح 💳", body: `تم تأكيد استرداد مبلغ ${queueAmount.toFixed(2)} ج.م عبر بوابة الدفع. قد يستغرق ظهوره حسب البنك أو المحفظة.`, metadata: { order_reference: payment.order_reference, championship_id: item.championship_id, refund_amount: queueAmount } });
          results.push({ id: item.id, payment_id: item.payment_id, type: "team_league", success: true, note: "already_refunded" });
          continue;
        }

        // 3. Call Paymob Refund API
        const txnId = String(item.paymob_transaction_id || "").replace(/\D/g, "");
        const refundAmtCents = Math.round(queueAmount * 100);

        let refundSuccess = false;
        let refundError: string | null = null;
        let refundId: string | null = null;
        let refundRequestSent = false;

        if (!txnId || refundAmtCents <= 0) {
          refundError = "Invalid transaction ID or zero amount";
        } else {
          try {
            // A dispatched call may have succeeded even when its response is lost.
            // Durably reserve this exact claim before any external refund.
            // Crashes after dispatch must not cause a second refund after 15m.
            const dispatchAllowed = await markTournamentRefundDispatched(adminClient, "team_league_cancellation_refund_queue", item);
            if (!dispatchAllowed) {
              results.push({ id: item.id, success: false, error: "REFUND_DISPATCH_GUARD_UNAVAILABLE" });
              continue;
            }
            refundRequestSent = true;
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
            if (isConfirmedPaymobRefund(refundRes.ok, refundData)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "");
            } else if (isAlreadyRefundedProviderMessage(refundData)) {
              // Text alone is not verified refund proof: manual reconciliation.
              refundError = "GATEWAY_ALREADY_REFUNDED_NEEDS_VERIFICATION";
            } else {
              refundError = "GATEWAY_REFUND_RESPONSE_UNCONFIRMED";
            }
          } catch (e: any) {
            // Never retain raw provider/network exception diagnostics.
            refundError = refundRequestSent
              ? "GATEWAY_OUTCOME_AMBIGUOUS_AFTER_DISPATCH" : "GATEWAY_REQUEST_NOT_SENT";
          }
        }

        const nowIso = new Date().toISOString();

        if (refundSuccess) {
          await adminClient.from("team_league_cancellation_refund_queue").update({
            status: "completed",
            processed_at: nowIso,
            locked_until: null,
            updated_at: nowIso,
          }).eq("id", item.id);

          await adminClient.from("team_league_payments").update({
            payment_status: "refunded",
            updated_at: nowIso,
          }).eq("id", item.payment_id);

          // 🛡️ Close transaction to completed with full metadata
          await adminClient.from("transactions").update({
            status: "completed",
            metadata: {
              paymob_refund_id: refundId,
              refund_amount: queueAmount,
              original_gross_amount: paymentGross,
              non_refundable_fee_amount: Number(Math.max(0, paymentGross - queueAmount).toFixed(2)),
              completed_at: nowIso,
            },
            updated_at: nowIso,
          }).eq("championship_id", item.championship_id)
            .eq("type", "refund_request")
            .eq("paymob_transaction_id", item.paymob_transaction_id);

          await ensureRefundNotification(adminClient, { userId: item.user_id, queueId: item.id, title: "تم استرداد رسوم دوري الفرق بنجاح 💳", body: `تم تأكيد استرداد مبلغ ${queueAmount.toFixed(2)} ج.م عبر بوابة الدفع. قد يستغرق ظهوره حسب البنك أو المحفظة.`, metadata: { order_reference: payment.order_reference, championship_id: item.championship_id, refund_amount: queueAmount, paymob_refund_id: refundId } });
          results.push({ id: item.id, payment_id: item.payment_id, type: "team_league", success: true, refund_id: refundId });
        } else {
          console.error(`Team League Refund failed for queue item ${item.id}:`, refundError);
          const isAmbiguousTimeout = refundError?.includes("GATEWAY_OUTCOME_AMBIGUOUS_AFTER_DISPATCH");

          if (item.retry_count >= 3 || isAmbiguousTimeout || refundRequestSent) {
            await adminClient.from("team_league_cancellation_refund_queue").update({
              status: "failed_manual_review",
              failure_reason: refundRequestSent
                ? "GATEWAY_VERIFICATION_REQUIRED_BEFORE_RETRY" : refundError,
              locked_until: null,
              updated_at: nowIso,
            }).eq("id", item.id);

            await adminClient.from("team_league_payments").update({
              payment_status: "refund_failed_manual_review",
              updated_at: nowIso,
            }).eq("id", item.payment_id);

            await adminClient.from("transactions").update({
              status: "failed_manual_review",
              metadata: {
                failure_reason: refundError,
                failed_at: nowIso,
              },
              updated_at: nowIso,
            }).eq("championship_id", item.championship_id)
              .eq("type", "refund_request")
              .eq("paymob_transaction_id", item.paymob_transaction_id);
            await ensureRefundNotification(adminClient, { userId: item.user_id, queueId: item.id, type: "tournament_refund_manual", title: "استرداد رسوم دوري الفرق يحتاج متابعة", body: "تعذر تأكيد الاسترداد تلقائيًا حتى الآن. تم إيقاف إعادة المحاولة الآلية لحماية المبلغ، ويجري التحقق من حالة الدفع.", metadata: { order_reference: payment.order_reference, championship_id: item.championship_id, refund_amount: queueAmount } });
          } else {
            await adminClient.from("team_league_cancellation_refund_queue").update({
              status: "pending",
              failure_reason: refundError,
              locked_until: null,
              updated_at: nowIso,
            }).eq("id", item.id);
          }

          results.push({ id: item.id, payment_id: item.payment_id, type: "team_league", success: false, error: refundError });
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
    // A malformed provider ID must NEVER be silently normalized by stripping
    // non-digits; this can target a different Paymob transaction.
    if (!orderReference || !/^[1-9][0-9]*$/.test(transactionId) ||
      !Number.isSafeInteger(Number(transactionId)) ||
      !Number.isFinite(refundAmount) || refundAmount <= 0) {
      return new Response(
        JSON.stringify({
          success: false,
          refund_failed: true,
          message: "تعذر تجهيز بيانات الاسترداد. لم يتم إخراج الفريق من البطولة.",
        }),
        { status: 409, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // The withdrawal RPC above checks the player's actual team/captain
    // authority, but it only READS the paid order. Claim that order here
    // before dispatching Paymob's irreversible refund endpoint.
    //
    // This CAS also blocks duplicate user/API retries and process crashes.
    // Team-league states require the accompanying schema CHECK migration
    // before Staging/Production can deploy this Edge Function safely.
    const { data: withdrawalChampionship, error: withdrawalChampionshipError } =
      await adminClient.from("championships")
        .select("template_type")
        .eq("id", championshipId)
        .maybeSingle();
    if (withdrawalChampionshipError || !withdrawalChampionship) {
      return new Response(JSON.stringify({
        success: false, refund_pending: true, manual_review: true,
        message: "تعذر تأكيد نوع البطولة قبل الاسترداد. يلزم المراجعة.",
      }), { status: 409, headers: { "Content-Type": "application/json", ...corsHeaders } });
    }
    const withdrawalOrderTable = withdrawalChampionship.template_type === "team_league"
      ? "team_league_payments" : "tournament_orders";
    const { data: withdrawalClaim, error: withdrawalClaimError } = await adminClient
      .from(withdrawalOrderTable)
      .update({ payment_status: "refund_pending", updated_at: new Date().toISOString() })
      .eq("order_reference", orderReference)
      .eq("championship_id", championshipId)
      .eq("team_id", teamId)
      .eq("paymob_transaction_id", transactionId)
      .eq("payment_status", "paid")
      .select("id")
      .maybeSingle();
    if (withdrawalClaimError || !withdrawalClaim) {
      // A prior request may have already reserved/refunded the same payment.
      // Never retry the gateway call when the atomic claim is absent.
      return new Response(JSON.stringify({
        success: false, refund_pending: true, manual_review: true,
        message: "تم حجز الاسترداد أو تعذر تثبيت الطلب. لن يتم إرسال طلب مكرر.",
      }), { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } });
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
          transaction_id: Number(transactionId),
          amount_cents: Math.round(refundAmount * 100),
        }),
      });
      const refundData = await refundRes.json();
      if (isConfirmedPaymobRefund(refundRes.ok, refundData)) {
        refundSuccess = true;
        refundId = String(refundData.id || refundData.transaction_id || "");
      } else {
        refundError = isAlreadyRefundedProviderMessage(refundData)
          ? "GATEWAY_ALREADY_REFUNDED_NEEDS_VERIFICATION"
          : "GATEWAY_REFUND_RESPONSE_UNCONFIRMED";
      }
    } catch (e: any) {
      refundError = "GATEWAY_OUTCOME_AMBIGUOUS_NEEDS_RECONCILIATION";
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
    if (finalizeError || finalized?.success !== true) {
      // The provider may already have moved money. Do not throw a 5xx which
      // encourages a new client refund attempt; reconcile manually instead.
      console.error("Team withdrawal refund ledger not confirmed");
      return new Response(JSON.stringify({
        success: false, refund_pending: true, manual_review: true,
        message: "حالة الاسترداد تحتاج مراجعة محاسبية قبل أي إعادة محاولة.",
      }), { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } });
    }

    return new Response(
      JSON.stringify({
        ...finalized,
        championship_id: championshipId,
        team_id: teamId,
        order_reference: orderReference,
        refund_amount: refundAmount,
        refund_success: refundSuccess,
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (err: any) {
    // Errors can contain provider tokens or DB diagnostics; keep them out of
    // public responses and logs. Operator reconciliation is required.
    console.error("process_tournament_refund failed; investigate safe server traces");
    return new Response(
      JSON.stringify({
        success: false,
        message: "تعذر إتمام استرداد اشتراك البطولة حالياً؛ يرجى مراجعة الإدارة.",
      }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});