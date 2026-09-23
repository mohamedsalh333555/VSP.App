// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

function calculatePaymobGrossCents(
  baseAmountEgp: number,
  vspRate: number,
  gatewayRate: number,
  fixedFeeEgp: number,
): number {
  const baseCents = Math.round(baseAmountEgp * 100);
  const vspCents = Math.round(baseCents * Number(vspRate));
  const gatewayVariableCents = Math.round(baseCents * Number(gatewayRate));
  const gatewayFixedCents = Math.round(Number(fixedFeeEgp) * 100);
  return baseCents + vspCents + gatewayVariableCents + gatewayFixedCents;
}

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
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Read Server Secrets & Initialize Supabase Admin Client
    const paymobSecretKey = Deno.env.get("PAYMOB_SECRET_KEY");
    const paymobPublicKey = Deno.env.get("PAYMOB_PUBLIC_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!paymobSecretKey) {
      console.error("🚨 Missing PAYMOB_SECRET_KEY on Supabase server environment!");
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: PAYMOB_SECRET_KEY missing" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 3. 🔒 Strict User Authentication Check (JWT Verification - Fail-Closed)
    const authHeader = req.headers.get("Authorization") || req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "").trim();
    const { data: { user: callerUser }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid or expired authentication token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const payload = await req.json();
    const {
      booking_id,
      is_tournament_payment = false,
      is_full_payment = false,
      amount_egp,
      payment_method = "card",
      user_phone = "",
      user_name = "",
      user_email = "",
    } = payload;

    if (!booking_id) {
      return new Response(
        JSON.stringify({ error: "Missing required booking_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Determine Amount & Verify Ownership (IDOR Prevention - Fail-Closed)
    let finalBaseAmount = Number(amount_egp) || 0;

    // Paid tournament checkouts must reference a server-created order.
    // Never trust an amount supplied by the mobile client for tournament flows.
    if (is_tournament_payment) {
      const isOneVsOne = booking_id.startsWith("TOURN_1V1_");
      const tableName = isOneVsOne
        ? "vsp_1v1_tournament_orders"
        : "tournament_orders";

      const selectColumns = isOneVsOne
        ? "order_reference, amount, user_id, payment_status"
        : "order_reference, amount, captain_user_id, payment_status";

      const { data: tournamentOrder, error: tournamentOrderError } = await supabase
        .from(tableName)
        .select(selectColumns)
        .eq("order_reference", booking_id)
        .maybeSingle();

      if (tournamentOrderError || !tournamentOrder) {
        return new Response(
          JSON.stringify({ error: "Tournament payment order not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const orderOwnerId = isOneVsOne
        ? tournamentOrder.user_id
        : tournamentOrder.captain_user_id;

      if (orderOwnerId !== callerUser.id) {
        const { data: callerProfile } = await supabase
          .from("users")
          .select("role")
          .eq("id", callerUser.id)
          .maybeSingle();

        if (!callerProfile || !["admin", "co_founder", "super_admin"].includes(callerProfile.role)) {
          return new Response(
            JSON.stringify({ error: "Forbidden: You do not own this tournament payment order" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      if (tournamentOrder.payment_status !== "pending") {
        return new Response(
          JSON.stringify({ error: "Tournament payment order is no longer pending" }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      finalBaseAmount = Number(tournamentOrder.amount) || 0;
    }


    if (!is_tournament_payment && booking_id && !booking_id.startsWith("mock_")) {
      const { data: booking, error: fetchErr } = await supabase
        .from("bookings")
        .select("id, total_price, deposit_amount, needs_deposit, created_by_user_id, user_id, status")
        .eq("id", booking_id)
        .maybeSingle();

      if (fetchErr || !booking) {
        return new Response(
          JSON.stringify({ error: "Booking record not found in database" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Check if booking is already confirmed/paid
      if (booking.status === "confirmed") {
        return new Response(
          JSON.stringify({ error: "Booking is already confirmed and paid" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 🔒 IDOR Prevention: Ensure authenticated caller owns this booking
      const bookingOwnerId = booking.created_by_user_id || booking.user_id;
      if (bookingOwnerId && bookingOwnerId !== callerUser.id) {
        const { data: userData } = await supabase
          .from("users")
          .select("role")
          .eq("id", callerUser.id)
          .maybeSingle();

        if (!userData || !["admin", "co_founder"].includes(userData.role)) {
          return new Response(
            JSON.stringify({ error: "Forbidden: You do not have permission to pay for this booking" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // Trust only the DB price (prevent client price tampering)
      finalBaseAmount = (!is_full_payment && booking.needs_deposit && Number(booking.deposit_amount) > 0)
        ? Number(booking.deposit_amount)
        : Number(booking.total_price);
    }

    if (finalBaseAmount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid payment amount" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate official checkout fees from public.platform_fee_config.
    // Contract: VSP 2.0%; Paymob local cards/wallets 2.4% + 3 EGP;
    // Paymob foreign cards 2.6% + 3 EGP. The database is authoritative.
    const { data: feeConfig, error: feeConfigError } = await supabase
      .from("platform_fee_config")
      .select("booking_vsp_rate, booking_paymob_rate, booking_paymob_local_rate, booking_paymob_foreign_rate, booking_paymob_wallet_rate, booking_paymob_fixed_fee")
      .eq("id", 1)
      .maybeSingle();

    if (feeConfigError || !feeConfig) {
      console.error("Missing authoritative booking fee configuration:", feeConfigError);
      return new Response(
        JSON.stringify({ error: "Payment fee configuration unavailable" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const normalizedPaymentMethod = String(payment_method || "card").toLowerCase();
    const gatewayRate = normalizedPaymentMethod === "wallet"
      ? Number(feeConfig.booking_paymob_wallet_rate ?? feeConfig.booking_paymob_rate)
      : Number(feeConfig.booking_paymob_local_rate ?? feeConfig.booking_paymob_rate);
    const amountInCents = calculatePaymobGrossCents(
      finalBaseAmount,
      Number(feeConfig.booking_vsp_rate),
      gatewayRate,
      Number(feeConfig.booking_paymob_fixed_fee),
    );
    const baseAmountCents = Math.round(finalBaseAmount * 100);
    const vspFeeCents = Math.round(
      baseAmountCents * Number(feeConfig.booking_vsp_rate),
    );
    const gatewayFeeCents = amountInCents - baseAmountCents - vspFeeCents;
    const totalPaymentFeesCents = amountInCents - baseAmountCents;
    const totalAmountEgp = amountInCents / 100;

    const profileName = String(user_name || callerUser.user_metadata?.full_name || "").trim();
    const profileEmail = String(user_email || callerUser.email || "").trim();
    const profilePhone = String(user_phone || callerUser.phone || "").trim();

    if (!profileName || !profileEmail || !profilePhone) {
      return new Response(
        JSON.stringify({ error: "Complete authenticated user billing information is required before creating a Paymob checkout session" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const nameParts = profileName.split(/\s+/).filter(Boolean);
    const safeFirstName = nameParts[0];
    const safeLastName = nameParts.slice(1).join(" ") || safeFirstName;
    const rawPhone = profilePhone.trim().replace(/[^\d+]/g, "");
    const safePhone = rawPhone.startsWith("+") ? rawPhone : `+2${rawPhone}`;

    // Paymob Intention API requires Integration IDs, not the public key or iframe ID.
    // Integration IDs are identifiers, not secrets. Keep them server-side and allow
    // optional environment overrides, with the known production IDs as fallbacks.
    const cardIntegration =
      Number(Deno.env.get("PAYMOB_INTEGRATION_ID_CARD")) || 5933044;
    const walletIntegration =
      Number(Deno.env.get("PAYMOB_INTEGRATION_ID_WALLET")) || 5933043;
    const paymentMethods = [cardIntegration, walletIntegration]
      .filter((value) => Number.isInteger(value) && value > 0);

    if (paymentMethods.length === 0) {
      console.error("No valid Paymob integration IDs are configured.");
      return new Response(
        JSON.stringify({ error: "Paymob payment configuration is unavailable on the server" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Call Paymob Intention API securely from backend (AFTER ALL SECURITY CHECKS PASS)
    const intentionPayload = {
      amount: amountInCents,
      currency: "EGP",
      payment_methods: paymentMethods,
      billing_data: {
        first_name: safeFirstName,
        last_name: safeLastName,
        phone_number: safePhone,
        email: profileEmail,
      },
      special_reference: booking_id,
      redirection_url: "https://vspapp.online/payment-callback",
    };

    console.log(`📡 Creating Paymob intention for booking: ${booking_id} with amount: ${totalAmountEgp} EGP`);

    const intentionRes = await fetch("https://accept.paymob.com/v1/intention/", {
      method: "POST",
      headers: {
        "Authorization": `Token ${paymobSecretKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(intentionPayload),
    });

    const intentionData = await intentionRes.json();

    if (!intentionRes.ok) {
      console.error("❌ Paymob Intention API Error:", intentionData);
      return new Response(
        JSON.stringify({ error: "Failed to generate Paymob checkout session", details: intentionData }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const clientSecret = intentionData.client_secret;
    if (!clientSecret) {
      return new Response(
        JSON.stringify({ error: "No client_secret returned from Paymob" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const checkoutUrl = `https://accept.paymob.com/unifiedcheckout/?publicKey=${paymobPublicKey}&clientSecret=${clientSecret}&lang=ar`;

    return new Response(
      JSON.stringify({
        success: true,
        checkout_url: checkoutUrl,
        client_secret: clientSecret,
        base_amount: finalBaseAmount,
        vsp_fee: vspFeeCents / 100,
        gateway_fee: gatewayFeeCents / 100,
        total_fees: totalPaymentFeesCents / 100,
        total_amount: totalAmountEgp,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Unhandled error in create_paymob_intention:", err);
    return new Response(
      JSON.stringify({ error: err?.message || String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
