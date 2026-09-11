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
      amount_egp,
      user_phone = "",
      user_name = "Player",
      user_email = "player@vsp.app",
      integration_id,
    } = payload;

    if (!booking_id) {
      return new Response(
        JSON.stringify({ error: "Missing required booking_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Determine Amount & Verify Ownership (IDOR Prevention - Fail-Closed)
    let finalBaseAmount = Number(amount_egp) || 0;
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
      finalBaseAmount = (booking.needs_deposit && Number(booking.deposit_amount) > 0)
        ? Number(booking.deposit_amount)
        : Number(booking.total_price);
    }

    if (finalBaseAmount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid payment amount" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate official platform fee: (amount * 0.0475) + 3.0 EGP
    const platformFee = Math.round(((finalBaseAmount * 0.0475) + 3.0) * 100) / 100;
    const totalAmountEgp = Math.round((finalBaseAmount + platformFee) * 100) / 100;
    const amountInCents = Math.round(totalAmountEgp * 100);

    const safeFirstName = user_name.trim().split(" ")[0] || "Player";
    const safeLastName = user_name.trim().split(" ").slice(1).join(" ") || "VSP";
    const rawPhone = user_phone.trim().replace(/[^\d+]/g, "");
    const safePhone = rawPhone.length > 0
      ? (rawPhone.startsWith("+") ? rawPhone : `+2${rawPhone}`)
      : "+201000000000";

    const activeIntegration = Number(integration_id) || 5772488;

    // 5. Call Paymob Intention API securely from backend (AFTER ALL SECURITY CHECKS PASS)
    const intentionPayload = {
      amount: amountInCents,
      currency: "EGP",
      payment_methods: [activeIntegration, 5772488, 5772511],
      billing_data: {
        first_name: safeFirstName,
        last_name: safeLastName,
        phone_number: safePhone,
        email: user_email.trim() || "customer@vsp.eg",
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
