// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { verifyOwnerSubscriptionPayment } from "../_shared/owner_subscription_payment.ts";
import { computePaymobHMAC, verifyPaymobHmacSignature } from "../_shared/paymob_hmac.ts";
import { classifyPaymobWebhookOutcome } from "../_shared/paymob_webhook_outcome.ts";
import { isAuthorizedPaymobIntegration } from "../_shared/paymob_integration_guard.ts";
import { matchesBoundPaymobOrder } from "../_shared/paymob_order_binding.ts";
import { sanitizePaymobAuditPayload } from "../_shared/paymob_audit_payload.ts";

declare const Deno: any;

console.log("⚡ Paymob Webhook Edge Function Initialized (Hardened & Unified)!");

serve(async (req: Request) => {
  // Paymob webhook is server-to-server. It does not expose browser CORS.
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 204,
      headers: {
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
      },
    });
  }

  // 1. Initialize Supabase Client early for comprehensive audit logging
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const url = new URL(req.url);
    const receivedHmac = url.searchParams.get("hmac");

    let payload: any = {};
    try {
      payload = await req.json();
    } catch (parseErr: any) {
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "invalid_json",
          payload: { rejected_before_authentication: true },
          signature_verified: false,
          status: "rejected",
          error_message: "Invalid JSON body",
        });
      } catch (_) {}
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const obj = payload.obj || payload;
    const transactionId = String(obj?.id || "");
    const orderId = String(obj?.order?.id ?? obj?.order ?? "");
    const specialReference = String(obj?.special_reference || obj?.order?.merchant_order_id || "");

    // Extract booking_id safely
    let bookingId: string | null = null;
    if (specialReference.includes("_")) {
      const candidate = specialReference.startsWith("VSP_BOOKING_")
        ? specialReference.replace("VSP_BOOKING_", "").split("_")[0]
        : specialReference.split("_")[0];
      if (candidate.length === 36) bookingId = candidate;
    } else if (specialReference.length === 36) {
      bookingId = specialReference;
    }

    // 🔒 2. Validate payload presence
    if (!obj || !obj.id) {
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "invalid_payload",
          txn_id: transactionId || null,
          order_id: orderId || null,
          booking_id: bookingId,
          payload: { rejected_before_authentication: true },
          signature_verified: false,
          status: "rejected",
          error_message: "Missing obj or obj.id in payload",
        });
      } catch (_) {}
      return new Response(JSON.stringify({ error: "Invalid Paymob payload: missing obj.id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 🔒 3. Verify HMAC Secret exists in Server Environment
    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") || Deno.env.get("PAYMOB_HMAC");
    if (!hmacSecret) {
      console.error("🚨 CRITICAL: PAYMOB_HMAC_SECRET environment variable is missing on server!");
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "server_misconfig",
          txn_id: transactionId || null,
          order_id: orderId || null,
          booking_id: bookingId,
          payload: { rejected_before_authentication: true },
          signature_verified: false,
          status: "server_error",
          error_message: "PAYMOB_HMAC_SECRET environment variable is missing on server",
        });
      } catch (_) {}
      return new Response(
        JSON.stringify({ error: "Webhook temporarily unavailable" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // 🔒 4. Check for received HMAC signature query param
    if (!receivedHmac) {
      console.error("❌ Rejected: Missing HMAC signature in webhook request parameters");
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "missing_hmac",
          txn_id: transactionId || null,
          order_id: orderId || null,
          booking_id: bookingId,
          payload: { rejected_before_authentication: true },
          signature_verified: false,
          status: "rejected",
          error_message: "Missing HMAC signature in query parameters (?hmac=...)",
        });
      } catch (_) {}
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing HMAC signature query parameter" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // 🔒 5. Compute & verify HMAC signature
    const calculatedHmac = await computePaymobHMAC(obj, hmacSecret);
    const isHmacValid = verifyPaymobHmacSignature(receivedHmac, calculatedHmac);

    if (!isHmacValid) {
      console.error("❌ Paymob Webhook HMAC Verification Failed! Signatures do not match.");
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "hmac_mismatch",
          txn_id: transactionId || null,
          order_id: orderId || null,
          booking_id: bookingId,
          payload: { rejected_before_authentication: true },
          signature_verified: false,
          status: "rejected",
          error_message: "HMAC signatures do not match",
        });
      } catch (_) {}
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid HMAC signature" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const amountCents = Number(obj?.amount_cents);
    // All VSP checkout intentions are EGP. A signed callback in another
    // currency cannot be reconciled against the EGP booking/plan ledger.
    if (obj?.currency !== "EGP") {
      return new Response(JSON.stringify({ error: "Unexpected payment currency" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "X-Content-Type-Options": "nosniff" },
      });
    }
    if (
      !/^[0-9]+$/.test(transactionId) ||
      !/^[0-9]+$/.test(orderId) ||
      !Number.isInteger(amountCents) ||
      amountCents <= 0 ||
      amountCents > 100000000000
    ) {
      return new Response(JSON.stringify({ error: "Invalid payment payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "X-Content-Type-Options": "nosniff" },
      });
    }

    // A valid HMAC proves authenticity but not membership in a VSP
    // integration. Reject unexpected integrations before financial writes.
    if (!isAuthorizedPaymobIntegration(
      obj.integration_id,
      Deno.env.get("PAYMOB_INTEGRATION_ID_CARD"),
      Deno.env.get("PAYMOB_INTEGRATION_ID_WALLET"),
      Deno.env.get("PAYMOB_WEBHOOK_ALLOWED_INTEGRATION_IDS") ?? "",
    )) {
      console.error("Rejected Paymob callback: unauthorized integration");
      return new Response(JSON.stringify({ error: "Payment integration is not authorized" }), {
        status: 403,
        headers: { "Content-Type": "application/json", "X-Content-Type-Options": "nosniff" },
      });
    }

    console.log("✅ HMAC Signature Verified Successfully!");

    // A signed pending/void/refund/authorization-only callback is not a
    // settled charge. Never turn those events into paid bookings or prizes.
    const paymentOutcome = classifyPaymobWebhookOutcome(obj);
    const isSuccess = paymentOutcome === "paid";

    console.log(`🔔 Webhook received for Booking: ${bookingId} | Success: ${isSuccess} | Tx: ${transactionId}`);

    // 6. Log successful verified transaction into webhook_logs
    try {
      await supabase.from("webhook_logs").insert({
        provider: "paymob",
        event_type: "transaction_response",
        txn_id: transactionId,
        order_id: String(obj.order?.id ?? obj.order ?? ""),
        booking_id: bookingId,
        payload: sanitizePaymobAuditPayload(obj),
        signature_verified: true,
        status: isSuccess ? "success" : paymentOutcome,
      });
    } catch (logErr) {
      console.warn("⚠️ Non-blocking warning: failed to write to webhook_logs", logErr);
    }

    // Strict gross-amount validation for all tournament orders.
    const validateTournamentGross = async (
      orderTable: string,
      reference: string,
      gatewayType: string,
    ) => {
      const { data: order, error: orderError } = await supabase
        .from(orderTable)
        .select("amount, payment_status, paymob_order_id")
        .eq("order_reference", reference)
        .maybeSingle();

      if (orderError || !order) {
        return { ok: false, reason: "payment_order_not_found" };
      }
      if (!matchesBoundPaymobOrder(order.paymob_order_id, orderId)) {
        return { ok: false, reason: "paymob_order_correlation_mismatch" };
      }
      if (order.payment_status === "paid") {
        return { ok: true, alreadyProcessed: true };
      }
      if (order.payment_status !== "pending") {
        return { ok: false, reason: "payment_order_not_pending" };
      }

      const { data: feeConfig, error: feeError } = await supabase
        .from("platform_fee_config")
        .select("booking_vsp_rate, booking_paymob_rate, booking_paymob_local_rate, booking_paymob_wallet_rate, booking_paymob_fixed_fee, paymob_applies_to_electronic")
        .eq("id", 1)
        .maybeSingle();

      if (feeError || !feeConfig || feeConfig.paymob_applies_to_electronic !== true) {
        return { ok: false, reason: "fee_policy_unavailable" };
      }

      const principal = Number(order.amount || 0);
      const vspRate = Number(feeConfig.booking_vsp_rate);
      const defaultGatewayRate = Number(feeConfig.booking_paymob_local_rate ?? feeConfig.booking_paymob_rate);
      const walletGatewayRate = Number(feeConfig.booking_paymob_wallet_rate ?? defaultGatewayRate);
      const gatewayRate = /wallet|vodafone|orange|etisalat|we|smartwallet/i.test(gatewayType)
        ? walletGatewayRate
        : defaultGatewayRate;
      const fixedFee = Number(feeConfig.booking_paymob_fixed_fee);
      const paidCents = Math.round(Number(obj.amount_cents || 0));

      if (![principal, vspRate, gatewayRate, fixedFee].every(Number.isFinite) || paidCents <= 0) {
        return { ok: false, reason: "invalid_payment_amount" };
      }

      const expectedCents = Math.round(
        (principal + Math.round(principal * vspRate * 100) / 100
          + Math.round((principal * gatewayRate + fixedFee) * 100) / 100) * 100
      );

      return {
        ok: paidCents === expectedCents,
        reason: paidCents === expectedCents ? null : "gross_amount_mismatch",
        principal,
        expectedCents,
        paidCents,
      };
    };

    // Owner subscription payments: activate only after verified Paymob success and exact gross amount.
    if (specialReference.startsWith("OWNER_SUB_")) {
      if (!isSuccess) {
        return new Response(JSON.stringify({ status: "processed", type: "owner_subscription", success: false }), { status: 200, headers: { "Content-Type": "application/json" } });
      }
      const subscriptionOrderId = specialReference.substring("OWNER_SUB_".length);
      const { data: subscriptionOrder, error: subscriptionOrderError } = await supabase
        .from("owner_subscription_orders")
        .select("id, owner_id, amount, gross_amount, status, paymob_order_id")
        .eq("id", subscriptionOrderId)
        .maybeSingle();
      if (subscriptionOrderError || !subscriptionOrder) {
        return new Response(JSON.stringify({ error: "Subscription payment order not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
      }
      if (!subscriptionOrder.paymob_order_id || String(subscriptionOrder.paymob_order_id) !== String(orderId)) {
        return new Response(JSON.stringify({ error: "Invalid subscription payment order correlation" }), { status: 400, headers: { "Content-Type": "application/json" } });
      }
      const verified = verifyOwnerSubscriptionPayment(obj, subscriptionOrder);
      if (!verified) {
        return new Response(JSON.stringify({ error: "Invalid subscription payment transaction" }), { status: 400, headers: { "Content-Type": "application/json" } });
      }
      const { data: confirmResult, error: confirmError } = await supabase.rpc("confirm_owner_subscription_payment", {
        p_order_id: subscriptionOrder.id,
        p_paymob_transaction_id: verified.transactionId,
        p_gross_amount: verified.amount,
      });
      if (confirmError || confirmResult?.success !== true) {
        return new Response(JSON.stringify({ error: "Owner subscription payment confirmation failed" }), { status: 500, headers: { "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ status: "processed", type: "owner_subscription", success: true }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // Team league payments: verify the server-created order, then atomically mark the team paid.
    if (specialReference.startsWith("LEAGUE_")) {
      if (isSuccess) {
        const { data: leaguePayment, error: leaguePaymentError } = await supabase
          .from("team_league_payments")
          .select("paymob_order_id, payment_status")
          .eq("order_reference", specialReference)
          .maybeSingle();

        if (leaguePaymentError || !leaguePayment) {
          return new Response(JSON.stringify({ error: "Team league payment order not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
        }
        if (!matchesBoundPaymobOrder(leaguePayment.paymob_order_id, orderId)) {
          console.error("Rejected league webhook Paymob order correlation mismatch:", specialReference);
          return new Response(JSON.stringify({ error: "Invalid payment order correlation" }), { status: 400, headers: { "Content-Type": "application/json" } });
        }

        const sourceType = String(obj.source_data?.sub_type || obj.source_data?.type || "").toLowerCase();
        const { data: leagueResult, error: leagueError } = await supabase.rpc("confirm_team_league_payment", {
          p_order_reference: specialReference,
          p_paymob_transaction_id: transactionId,
          p_gross_amount_cents: Number(obj.amount_cents || 0),
          p_gateway_type: sourceType,
        });
        if (leagueError || leagueResult?.success !== true) {
          console.error("Team league payment confirmation failed:", leagueError || leagueResult);
          return new Response(JSON.stringify({ error: "Team league payment confirmation failed" }), { status: 500, headers: { "Content-Type": "application/json" } });
        }
      }
      return new Response(JSON.stringify({ status: "processed", type: "team_league", success: isSuccess }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // 3.4 Handle 1v1 Tournament Orders (With Real Paymob Refund on Over-Capacity)
    if (specialReference.startsWith("TOURN_1V1_") && isSuccess) {
      const sourceType = String(obj.source_data?.sub_type || obj.source_data?.type || "").toLowerCase();
      const amountCheck = await validateTournamentGross("vsp_1v1_tournament_orders", specialReference, sourceType);
      if (!amountCheck.ok) {
        console.error("Rejected 1v1 webhook gross mismatch:", specialReference, amountCheck);
        return new Response(JSON.stringify({ error: "Invalid tournament payment amount" }), {
          status: 400, headers: { "Content-Type": "application/json" }
        });
      }
    }

    // 3.4 Handle 1v1 Tournament Orders (With Real Paymob Refund on Over-Capacity)
    if (specialReference.startsWith("TOURN_1V1_")) {
      console.log(`🥋 Processing 1v1 tournament webhook for order: ${specialReference}`);
      if (isSuccess) {
        // Step 1: Atomic confirmation & capacity check (with row lock)
        const actualGrossAmount = Math.round(Number(obj.amount_cents || 0)) / 100.0;
        if (actualGrossAmount <= 0) {
          console.error("❌ Rejected 1v1 webhook: zero or invalid gross amount:", specialReference, obj.amount_cents);
          return new Response(JSON.stringify({ error: "Invalid payment amount in webhook" }), {
            status: 400,
            headers: { "Content-Type": "application/json" },
          });
        }
        const { data: tournResult, error: tournErr } = await supabase.rpc(
          "confirm_1v1_payment_atomic",
          {
            p_order_reference: specialReference,
            p_paymob_transaction_id: transactionId,
            p_gross_amount: actualGrossAmount,
          }
        );

        if (tournErr) {
          console.error("❌ Failed to confirm 1v1 tournament order via RPC:", tournErr);
          return new Response(JSON.stringify({ error: "1v1 tournament payment confirmation failed" }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
          });
        } else if (tournResult?.needs_refund === true) {
          // 🛡️ OVER-CAPACITY DETECTED: Real Paymob Refund API call FIRST
          console.warn(`🚨 Capacity exceeded for 1v1 order ${specialReference}. Initiating REAL Paymob Refund API call...`);
          
          let refundSuccess = false;
          let refundId = null;
          let refundErrorMsg = null;
          // The signed callback's amountCents was HMAC-verified and validated
          // before this branch. Never reconstruct historical charges from a
          // mutable, current fee policy when refunding an over-capacity order.

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
              // Do not include Paymob's response body: it may contain sensitive data.
              throw new Error("Paymob refund authentication request failed");
            }

            const authData = await authRes.json();
            const authToken = authData.token;

            // Step B: Call Paymob Void/Refund API with exact transaction and amount in cents
            // Refund the exact gross amount Paymob actually charged, including VSP/gateway fees.
            // This is authoritative for the external refund and avoids under-refunding the payer.
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
            // Never log raw gateway responses, even when a refund is rejected.
            console.log("Paymob refund API response", { httpStatus: refundRes.status, accepted: refundRes.ok });

            if (refundRes.ok && (refundData.success === true || refundData.is_refund === true)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "REFUND_SUCCESS");
            } else {
              refundErrorMsg = `Paymob refund rejected (HTTP ${refundRes.status})`;
            }
          } catch (refundEx: any) {
            console.error("Paymob refund request failed (1v1)");
            refundErrorMsg = "Paymob refund request failed";
          }

          // Step C: Atomically record real refund status or flag for manual review
          const { data: refundRecorded, error: refundRecordingError } = await supabase.rpc("record_1v1_refund_status_atomic", {
            p_order_reference: specialReference,
            p_refund_success: refundSuccess,
            p_paymob_refund_id: refundId,
            p_error_message: refundErrorMsg,
            p_refund_amount: amountCents / 100,
          });
          if (refundRecordingError || refundRecorded?.success !== true) {
            // Gateway action may already have happened. Do not return a
            // retry-triggering 5xx that could cause another external refund.
            // Preserve an operator-visible audit and require reconciliation.
            console.error("Paymob tournament refund ledger requires manual reconciliation (1v1_tournament)");
            await supabase.from("webhook_logs").insert({
              provider: "paymob",
              event_type: "refund_ledger_reconciliation_required",
              txn_id: transactionId,
              order_id: orderId,
              payload: {
                order_reference: specialReference,
                refund_request_accepted: refundSuccess,
                refund_id: refundId,
              },
              signature_verified: true,
              status: "requires_reconciliation",
              error_message: "Paymob refund ledger write not confirmed",
            });
            return new Response(JSON.stringify({
              status: "requires_reconciliation", type: "1v1_tournament", success: false,
            }), { status: 200, headers: { "Content-Type": "application/json" } });
          }
          return new Response(JSON.stringify({
            status: refundSuccess ? "refund_recorded" : "refund_manual_review",
            type: "1v1_tournament",
            success: false,
          }), { status: 200, headers: { "Content-Type": "application/json" } });

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
    if (specialReference.startsWith("TOURN_") && !specialReference.startsWith("TOURN_1V1_") && isSuccess) {
      const sourceType = String(obj.source_data?.sub_type || obj.source_data?.type || "").toLowerCase();
      const amountCheck = await validateTournamentGross("tournament_orders", specialReference, sourceType);
      if (!amountCheck.ok) {
        console.error("Rejected team tournament webhook gross mismatch:", specialReference, amountCheck);
        return new Response(JSON.stringify({ error: "Invalid tournament payment amount" }), {
          status: 400, headers: { "Content-Type": "application/json" }
        });
      }
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
          return new Response(JSON.stringify({ error: "Tournament payment confirmation failed" }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
          });
        } else if (tournResult?.needs_refund === true || tournResult?.requires_refund === true) {
          // OVER-CAPACITY DETECTED: refund the exact gross amount charged to the payer.
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
              // Do not include Paymob's response body: it may contain sensitive data.
              throw new Error("Paymob refund authentication request failed");
            }

            const authData = await authRes.json();
            const authToken = authData.token;

            // Step B: Use the exact HMAC-verified Paymob transaction amount.
            // Recomputing from current fee settings can over/under-refund if
            // pricing has changed since this payment was actually captured.
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
            // Never log raw gateway responses, even when a refund is rejected.
            console.log("Paymob refund API response", { httpStatus: refundRes.status, accepted: refundRes.ok });

            if (refundRes.ok && (refundData.success === true || refundData.is_refund === true)) {
              refundSuccess = true;
              refundId = String(refundData.id || refundData.transaction_id || "REFUND_SUCCESS");
            } else {
              refundErrorMsg = `Paymob refund rejected (HTTP ${refundRes.status})`;
            }
          } catch (refundEx: any) {
            console.error("Paymob refund request failed (tournament)");
            refundErrorMsg = "Paymob refund request failed";
          }

          // Step C: Atomically record real refund status or flag for manual review
          const { data: refundRecorded, error: refundRecordingError } = await supabase.rpc("record_tournament_refund_status_atomic", {
            p_order_reference: specialReference,
            p_refund_success: refundSuccess,
            p_paymob_refund_id: refundId,
            p_error_message: refundErrorMsg,
            p_refund_amount: amountCents / 100,
          });
          if (refundRecordingError || refundRecorded?.success !== true) {
            // Gateway action may already have happened. Do not return a
            // retry-triggering 5xx that could cause another external refund.
            // Preserve an operator-visible audit and require reconciliation.
            console.error("Paymob tournament refund ledger requires manual reconciliation (tournament)");
            await supabase.from("webhook_logs").insert({
              provider: "paymob",
              event_type: "refund_ledger_reconciliation_required",
              txn_id: transactionId,
              order_id: orderId,
              payload: {
                order_reference: specialReference,
                refund_request_accepted: refundSuccess,
                refund_id: refundId,
              },
              signature_verified: true,
              status: "requires_reconciliation",
              error_message: "Paymob refund ledger write not confirmed",
            });
            return new Response(JSON.stringify({
              status: "requires_reconciliation", type: "tournament", success: false,
            }), { status: 200, headers: { "Content-Type": "application/json" } });
          }
          return new Response(JSON.stringify({
            status: refundSuccess ? "refund_recorded" : "refund_manual_review",
            type: "tournament",
            success: false,
          }), { status: 200, headers: { "Content-Type": "application/json" } });

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
      .select("id, status, total_price, deposit_amount, needs_deposit, owner_id, user_id, created_by_user_id, stadium_name, paymob_order_id")
      .eq("id", bookingId)
      .maybeSingle();

    if (fetchError || !existingBooking) {
      console.error(`❌ Booking ${bookingId} not found in database.`);
      return new Response(JSON.stringify({ error: "Booking not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!matchesBoundPaymobOrder(existingBooking.paymob_order_id, orderId)) {
      console.error("Rejected booking webhook Paymob order correlation mismatch:", bookingId);
      return new Response(JSON.stringify({ error: "Invalid payment order correlation" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3.5 Handle Paymob Refund Callback if is_refunded is true
    if (obj.is_refunded === true && paymentOutcome === "reversed") {
      const refundAmount = (obj.amount_cents || 0) / 100;
      const refundTxnId = String(obj.id || transactionId);
      const refundMethod = (() => {
        const subType = (obj.source_data?.sub_type || obj.source_data?.type || "").toLowerCase();
        if (subType.includes("wallet") || subType.includes("vodafone") || subType.includes("orange") || subType.includes("etisalat") || subType.includes("instapay")) {
          return "wallet";
        }
        if (subType.includes("card") || subType.includes("paymob") || subType.includes("online")) {
          return "card";
        }
        return "card";
      })();

      console.log(`💸 Paymob Webhook Refund confirmed for booking ${bookingId} via ${refundMethod} (Tx: ${refundTxnId})`);

      const { data: refundResult, error: refundRecordError } = await supabase.rpc(
        "record_booking_gateway_refund_atomic",
        {
          p_booking_id: bookingId,
          p_refund_amount: refundAmount,
          p_refund_txn_id: refundTxnId,
          p_refund_payment_method: refundMethod,
          p_refund_gross_amount: refundAmount,
        }
      );
      if (refundRecordError || refundResult?.success !== true) {
        console.error("❌ Failed to atomically record booking refund:", refundRecordError || refundResult);
        return new Response(JSON.stringify({ error: "Refund recording failed" }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }

      // The ledger RPC returns already_recorded for a repeated, signed
      // refund transaction. Replaying a webhook must not notify twice.
      if (refundResult?.already_recorded === true) {
        return new Response(JSON.stringify({ status: "already_processed", type: "booking_refund" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Notify player about successful refund
      const playerUserId = existingBooking.created_by_user_id || existingBooking.user_id;
      if (playerUserId) {
        try {
          await supabase.from("notifications").insert({
            user_id: playerUserId,
            title: "تم اعتماد الاسترداد المالي! 💸",
            body: `تم استرداد مبلغ (${refundAmount.toFixed(0)} ج.م) لحجز ${existingBooking.stadium_name || 'الملعب'} بنجاح.`,
            type: "refund_success",
            created_at: new Date().toISOString(),
          });
        } catch (notifErr) {
          console.warn("Non-blocking: failed to send refund notification in webhook", notifErr);
        }
      }

      return new Response(JSON.stringify({ status: "refund_processed", booking_id: bookingId }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Apply verified payment through the single financial SSOT RPC.
    if (isSuccess) {
      if (existingBooking.status === "cancelled") {
        const chargedAmountEgp = (obj.amount_cents || 0) / 100;
        let refundSuccess = false;
        let refundId = null;
        let refundErrorMsg = null;

        try {
          const paymobApiKey = Deno.env.get("PAYMOB_API_KEY") || Deno.env.get("PAYMOB_SECRET_KEY") || "";
          if (!paymobApiKey) throw new Error("Missing Paymob server API key");

          const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ api_key: paymobApiKey }),
          });
          if (!authRes.ok) throw new Error("Paymob auth token request failed");

          const authData = await authRes.json();
          const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              auth_token: authData.token,
              transaction_id: Number(transactionId),
              amount_cents: Number(obj.amount_cents || 0),
            }),
          });
          const refundData = await refundRes.json();

          if (refundRes.ok && (refundData.success === true || refundData.is_refund === true)) {
            refundSuccess = true;
            refundId = String(refundData.id || refundData.transaction_id || transactionId);
          } else {
            refundErrorMsg = `Paymob refund rejected (HTTP ${refundRes.status})`;
          }
        } catch (refundEx: any) {
          refundErrorMsg = "Paymob refund request failed";
        }

        if (refundSuccess) {
          const { data: refundAccounting, error: refundAccountingError } =
            await supabase.rpc("record_booking_gateway_refund_atomic", {
              p_booking_id: bookingId,
              p_refund_amount: chargedAmountEgp,
              p_refund_txn_id: refundId,
              p_refund_payment_method: "card",
              p_refund_gross_amount: chargedAmountEgp,
            });
          // The gateway response alone does not prove that this refund was
          // recorded in the server's financial ledger. Never tell the user
          // the money was refunded if authoritative accounting rejects it.
          if (refundAccountingError || refundAccounting?.success !== true) {
            refundSuccess = false;
            refundErrorMsg = "Gateway refund acknowledged; server refund accounting remains unverified";
          }
        }
        if (!refundSuccess) {
          await supabase
            .from("bookings")
            .update({
              payment_status: "refund_pending",
              refund_amount: chargedAmountEgp,
              cancellation_reason: "الاسترداد يحتاج مراجعة التسوية مع مزود الدفع.",
              updated_at: new Date().toISOString(),
            })
            .eq("id", bookingId)
            .eq("status", "cancelled");
        }

        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "auto_refund_expired_booking",
          txn_id: transactionId,
          booking_id: bookingId,
          payload: { refundSuccess, refundId, refundErrorMsg, originalTxn: sanitizePaymobAuditPayload(obj) },
          signature_verified: true,
          status: refundSuccess ? "refunded" : "refund_pending",
          error_message: refundErrorMsg,
        });

        const playerUserId = existingBooking.created_by_user_id || existingBooking.user_id;
        if (playerUserId) {
          await supabase.from("notifications").insert({
            user_id: playerUserId,
            title: refundSuccess ? "استرداد تلقائي للمبلغ 💸" : "حالة استرداد الدفع",
            body: refundSuccess
              ? `تم استرداد مبلغ (${chargedAmountEgp.toFixed(2)} ج.م) تلقائياً لأن مهلة الحجز انتهت.`
              : `تم تسجيل عملية الاسترداد للمراجعة بسبب انتهاء مهلة الحجز. رقم العملية: ${transactionId}`,
            type: refundSuccess ? "refund_success" : "refund_pending",
            booking_id: bookingId,
            created_at: new Date().toISOString(),
          });
        }

        return new Response(JSON.stringify({
          status: refundSuccess ? "expired_auto_refunded" : "expired_refund_pending",
          refund_success: refundSuccess,
          booking_id: bookingId,
        }), { status: 200, headers: { "Content-Type": "application/json" } });
      }

      const paidAmountEgp = (obj.amount_cents || 0) / 100;

      const resolvedPaymentMethod = (() => {
        const combined = `${obj.source_data?.type || ""} ${obj.source_data?.sub_type || ""}`.toLowerCase();
        if (
          combined.includes("wallet") ||
          combined.includes("vodafone") ||
          combined.includes("orange") ||
          combined.includes("etisalat") ||
          combined.includes("we") ||
          combined.includes("smartwallet")
        ) return "wallet";
        return "card";
      })();

      const { data: priorPayments } = await supabase
        .from("transactions")
        .select("amount, metadata")
        .eq("booking_id", bookingId)
        .in("type", ["payment", "deposit"])
        .eq("status", "completed");

      const collectedBefore = Math.round(
        (priorPayments || []).reduce((sum: number, tx: any) => sum + Number(tx.amount || 0), 0) * 100
      ) / 100;
      const remainingBefore = Math.max(
        0,
        Math.round((Number(existingBooking.total_price || 0) - collectedBefore) * 100) / 100
      );

      const { data: feeConfigForBooking } = await supabase
        .from("platform_fee_config")
        .select("booking_vsp_rate, booking_paymob_rate, booking_paymob_local_rate, booking_paymob_wallet_rate, booking_paymob_fixed_fee")
        .eq("id", 1)
        .maybeSingle();

      const vspRateForBooking = Number(feeConfigForBooking?.booking_vsp_rate);
      const cardRateForBooking = Number(
        feeConfigForBooking?.booking_paymob_local_rate ?? feeConfigForBooking?.booking_paymob_rate
      );
      const walletRateForBooking = Number(
        feeConfigForBooking?.booking_paymob_wallet_rate ?? cardRateForBooking
      );
      const gatewayRateForBooking =
        resolvedPaymentMethod === "wallet" ? walletRateForBooking : cardRateForBooking;
      const fixedFeeForBooking = Number(feeConfigForBooking?.booking_paymob_fixed_fee);

      const expectedGrossForPrincipal = (principal: number) => {
        const vspFee = Math.round(principal * vspRateForBooking * 100) / 100;
        const gatewayFee = Math.round((principal * gatewayRateForBooking + fixedFeeForBooking) * 100) / 100;
        return Math.round((principal + vspFee + gatewayFee) * 100) / 100;
      };

      const principalCandidates: number[] = [];
      if (remainingBefore > 0) principalCandidates.push(remainingBefore);
      if (
        collectedBefore <= 0.01 &&
        Boolean(existingBooking.needs_deposit) &&
        Number(existingBooking.deposit_amount || 0) > 0
      ) {
        principalCandidates.push(Math.min(
          remainingBefore,
          Math.round(Number(existingBooking.deposit_amount) * 100) / 100
        ));
      }

      const uniqueCandidates = [...new Set(principalCandidates.map((n) => Math.round(n * 100) / 100))];
      const principalAmount =
        uniqueCandidates.find((candidate) =>
          Math.abs(expectedGrossForPrincipal(candidate) - paidAmountEgp) <= 0.01
        ) ?? remainingBefore;

      const isDepositOnly = principalAmount < remainingBefore - 0.01;

      const { data: paymentResult, error: paymentError } = await supabase.rpc(
        "record_booking_payment_atomic",
        {
          p_booking_id: bookingId,
          p_user_id: existingBooking.created_by_user_id || existingBooking.user_id,
          p_paymob_transaction_id: transactionId,
          p_paymob_order_id: orderId,
          p_payment_method: resolvedPaymentMethod,
          p_principal_amount: principalAmount,
          p_gross_amount: paidAmountEgp,
          p_is_deposit: isDepositOnly,
          p_metadata: {
            paymob_order_id: orderId,
            source_data_type: obj.source_data?.type ?? null,
            source_data_sub_type: obj.source_data?.sub_type ?? null,
            card_origin: "local",
          },
        },
      );

      if (paymentError || paymentResult?.success !== true) {
        console.error("Payment ledger RPC rejected verified webhook");
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "payment_accounting_rejected",
          txn_id: transactionId,
          order_id: orderId,
          booking_id: bookingId,
          payload: sanitizePaymobAuditPayload(obj),
          signature_verified: true,
          status: "rejected",
          error_message: "Verified payment accounting rejected",
        });
        return new Response(JSON.stringify({ error: "Payment accounting rejected" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      // The verified financial RPC writes the booking and transaction
      // atomically. Its database trigger creates one in-app receipt only
      // when the signed successful Paymob log, gross amount and ledger match.
      // Never re-create payment notifications from a webhook replay.
      if (paymentResult.idempotent === true) {
        return new Response(JSON.stringify({
          status: "already_processed",
          type: "booking_payment",
          success: true,
          booking_id: bookingId,
        }), { status: 200, headers: { "Content-Type": "application/json" } });
      }

      const finalPayment = paymentResult.is_final_payment === true;
      const remainingAmount = Number(paymentResult.remaining_amount || 0);
      const principalPaid = Number(paymentResult.principal_amount || principalAmount);

      return new Response(JSON.stringify({
        status: "processed",
        type: "booking_payment",
        success: true,
        booking_id: bookingId,
        final_payment: finalPayment,
        principal_amount: principalPaid,
        remaining_amount: remainingAmount,
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    } else if (paymentOutcome === "failed") {
      // Only a terminal failure may cancel a pending booking; a pending
      // Paymob event must not destroy a still-valid payment attempt.
      await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: "failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId)
        .eq("status", "pending")
        // A newer checkout may have replaced this order ID since our read.
        // A late failure for the old order must not cancel the new attempt.
        .eq("paymob_order_id", orderId);
    }

    const responseStatus = paymentOutcome === "pending" ? "pending" :
      paymentOutcome === "reversed" || paymentOutcome === "unresolved"
      ? "requires_reconciliation" : "processed";
    return new Response(JSON.stringify({ status: responseStatus, success: isSuccess }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    console.error("Paymob Webhook Error", {
      reason: error instanceof Error ? error.name : "unknown",
    });
    return new Response(JSON.stringify({ error: "Webhook processing failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json", "X-Content-Type-Options": "nosniff" },
    });
  }
});
