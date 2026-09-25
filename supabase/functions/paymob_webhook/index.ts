// @ts-nocheck
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

  // 1. Initialize Supabase Client early for comprehensive audit logging
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const rawUrl = req.url;
    const url = new URL(rawUrl);
    const receivedHmac = url.searchParams.get("hmac");

    let payload: any = {};
    try {
      payload = await req.json();
    } catch (parseErr: any) {
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "invalid_json",
          payload: { error: "Failed to parse JSON body", rawUrl },
          signature_verified: false,
          status: "rejected",
          error_message: `JSON parse error: ${parseErr?.message}`,
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
          payload: payload,
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
    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET");
    if (!hmacSecret) {
      console.error("🚨 CRITICAL: PAYMOB_HMAC_SECRET environment variable is missing on server!");
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "server_misconfig",
          txn_id: transactionId || null,
          order_id: orderId || null,
          booking_id: bookingId,
          payload: payload,
          signature_verified: false,
          status: "server_error",
          error_message: "PAYMOB_HMAC_SECRET environment variable is missing on server",
        });
      } catch (_) {}
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: Missing PAYMOB_HMAC_SECRET" }),
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
          payload: { ...payload, queryParams: Object.fromEntries(url.searchParams.entries()) },
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
    const isHmacValid = calculatedHmac.toLowerCase() === receivedHmac.toLowerCase();

    if (!isHmacValid) {
      console.error("❌ Paymob Webhook HMAC Verification Failed! Signatures do not match.");
      try {
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "hmac_mismatch",
          txn_id: transactionId || null,
          order_id: orderId || null,
          booking_id: bookingId,
          payload: {
            receivedHmac,
            calculatedHmacPrefix: calculatedHmac.substring(0, 8) + "...",
            objSummary: {
              id: obj.id,
              order: obj.order?.id ?? obj.order,
              amount_cents: obj.amount_cents,
              success: obj.success,
            },
          },
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

    console.log("✅ HMAC Signature Verified Successfully!");

    const isSuccess = Boolean(obj.success) && !Boolean(obj.pending);

    console.log(`🔔 Webhook received for Booking: ${bookingId} | Success: ${isSuccess} | Tx: ${transactionId}`);

    // 6. Log successful verified transaction into webhook_logs
    try {
      await supabase.from("webhook_logs").insert({
        provider: "paymob",
        event_type: "transaction_response",
        txn_id: transactionId,
        order_id: String(obj.order?.id ?? obj.order ?? ""),
        booking_id: bookingId,
        payload: obj,
        signature_verified: true,
        status: isSuccess ? "success" : "failed",
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
        .select("amount, payment_status")
        .eq("order_reference", reference)
        .maybeSingle();

      if (orderError || !order) {
        return { ok: false, reason: "payment_order_not_found" };
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

    // Team league payments: verify the server-created order, then atomically mark the team paid.
    if (specialReference.startsWith("LEAGUE_")) {
      if (isSuccess) {
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
          // Use the exact gross amount charged by Paymob when available.
          // If the webhook omits it, rebuild the same server-side gross used by checkout.
          let amountCents = Math.round(Number(obj.amount_cents || 0));
          if (amountCents <= 0) {
            const { data: feeConfig } = await supabase
              .from("platform_fee_config")
              .select("booking_vsp_rate, booking_paymob_local_rate, booking_paymob_fixed_fee")
              .eq("id", 1)
              .maybeSingle();
            const principal = Number(tournResult?.amount || 0);
            const vspRate = Number(feeConfig?.booking_vsp_rate ?? 0.02);
            const gatewayRate = Number(feeConfig?.booking_paymob_local_rate ?? 0.0275);
            const gatewayFixed = Number(feeConfig?.booking_paymob_fixed_fee ?? 3);
            const vspFee = Math.round(principal * vspRate * 100) / 100;
            const gatewayFee = Math.round((principal * gatewayRate + gatewayFixed) * 100) / 100;
            amountCents = Math.round((principal + vspFee + gatewayFee) * 100);
          }

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
            p_refund_amount: amountCents / 100,
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
              const authErrText = await authRes.text();
              throw new Error(`Paymob auth token request failed: ${authErrText}`);
            }

            const authData = await authRes.json();
            const authToken = authData.token;

            // Step B: Rebuild the same gross amount charged by the intention service:
            // principal + VSP fee + Paymob local fee + fixed fee.
            const { data: feeConfig } = await supabase
              .from("platform_fee_config")
              .select("booking_vsp_rate, booking_paymob_local_rate, booking_paymob_fixed_fee")
              .eq("id", 1)
              .maybeSingle();
            const principal = Number(tournResult.amount || 0);
            const vspRate = Number(feeConfig?.booking_vsp_rate ?? 0.02);
            const gatewayRate = Number(feeConfig?.booking_paymob_local_rate ?? 0.0275);
            const gatewayFixed = Number(feeConfig?.booking_paymob_fixed_fee ?? 3);
            const vspFee = Math.round(principal * vspRate * 100) / 100;
            const gatewayFee = Math.round((principal * gatewayRate + gatewayFixed) * 100) / 100;
            const grossAmount = Math.round((principal + vspFee + gatewayFee) * 100) / 100;
            const amountCents = Math.round(grossAmount * 100);
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
            p_refund_amount: amountCents / 100,
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
      .select("id, status, total_price, deposit_amount, needs_deposit, owner_id, user_id, created_by_user_id, stadium_name")
      .eq("id", bookingId)
      .maybeSingle();

    if (fetchError || !existingBooking) {
      console.error(`❌ Booking ${bookingId} not found in database.`);
      return new Response(JSON.stringify({ error: "Booking not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3.5 Handle Paymob Refund Callback if is_refunded is true
    if (obj.is_refunded === true) {
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
        }
      );
      if (refundRecordError || refundResult?.success !== true) {
        console.error("❌ Failed to atomically record booking refund:", refundRecordError || refundResult);
        return new Response(JSON.stringify({ error: "Refund recording failed" }), {
          status: 500,
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

          if (refundRes.ok && (refundData.success === true || refundData.is_refund === true || refundData.id)) {
            refundSuccess = true;
            refundId = String(refundData.id || refundData.transaction_id || transactionId);
          } else {
            refundErrorMsg = refundData.message || refundData.detail || JSON.stringify(refundData);
          }
        } catch (refundEx: any) {
          refundErrorMsg = refundEx?.message || String(refundEx);
        }

        if (refundSuccess) {
          await supabase.rpc("record_booking_gateway_refund_atomic", {
            p_booking_id: bookingId,
            p_refund_amount: chargedAmountEgp,
            p_refund_txn_id: refundId,
            p_refund_payment_method: "card",
          });
        } else {
          await supabase
            .from("bookings")
            .update({
              payment_status: "refund_pending",
              refund_amount: chargedAmountEgp,
              cancellation_reason: "انتهت مهلة الدفع ولم يكتمل الحجز، والاسترداد يحتاج معالجة.",
              updated_at: new Date().toISOString(),
            })
            .eq("id", bookingId);
        }

        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "auto_refund_expired_booking",
          txn_id: transactionId,
          booking_id: bookingId,
          payload: { refundSuccess, refundId, refundErrorMsg, originalTxn: obj },
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
      const principalAmount = (
        existingBooking.needs_deposit &&
        Number(existingBooking.deposit_amount) > 0
      ) ? Number(existingBooking.deposit_amount) : Number(existingBooking.total_price);

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

      const isDepositOnly =
        Boolean(existingBooking.needs_deposit) &&
        Number(existingBooking.deposit_amount) > 0 &&
        paidAmountEgp < (Number(existingBooking.total_price) - 0.5);

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
        console.error("Payment ledger RPC rejected verified webhook:", paymentError || paymentResult);
        await supabase.from("webhook_logs").insert({
          provider: "paymob",
          event_type: "payment_accounting_rejected",
          txn_id: transactionId,
          order_id: orderId,
          booking_id: bookingId,
          payload: obj,
          signature_verified: true,
          status: "rejected",
          error_message: JSON.stringify(paymentError || paymentResult),
        });
        return new Response(JSON.stringify({ error: "Payment accounting rejected" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      const finalPayment = paymentResult.is_final_payment === true;
      const remainingAmount = Number(paymentResult.remaining_amount || 0);
      const principalPaid = Number(paymentResult.principal_amount || principalAmount);

      const playerUserId = existingBooking.created_by_user_id || existingBooking.user_id;
      const amountText = principalPaid.toFixed(2);

      await supabase.from("notifications").insert([
        {
          user_id: existingBooking.owner_id,
          title: isDepositOnly ? "تم استلام عربون حجز" : "تم استلام دفعة حجز مؤكدة",
          body: isDepositOnly
            ? `تم دفع عربون بقيمة ${amountText} ج.م لحجز ${existingBooking.stadium_name || "الملعب"}. المتبقي: ${remainingAmount.toFixed(2)} ج.م`
            : `تم تأكيد سداد مبلغ ${amountText} ج.م لحجز ${existingBooking.stadium_name || "الملعب"}.`,
          type: isDepositOnly ? "deposit_received" : "payment_received",
          booking_id: bookingId,
          is_read: false,
        },
        {
          user_id: playerUserId,
          title: finalPayment ? "تأكيد الحجز والدفع" : "تأكيد سداد العربون",
          body: finalPayment
            ? `تم سداد حجزك بالكامل بنجاح في ${existingBooking.stadium_name || "الملعب"}.`
            : `تم سداد العربون بقيمة ${amountText} ج.م بنجاح. المتبقي: ${remainingAmount.toFixed(2)} ج.م.`,
          type: finalPayment ? "booking_confirmed" : "deposit_received",
          booking_id: bookingId,
          is_read: false,
        },
      ]);

      return new Response(JSON.stringify({
        status: "processed",
        type: "booking_payment",
        success: true,
        booking_id: bookingId,
        final_payment: finalPayment,
        principal_amount: principalPaid,
        remaining_amount: remainingAmount,
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    } else {
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
