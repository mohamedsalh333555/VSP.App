// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

declare const Deno: any;

console.log("FCM Push Notification Function Started!");

serve(async (req: Request) => {
  try {
    // 0. Security Guard: Verify Authorization Token (Strict Fail-Closed)
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    if (!token) {
      return new Response(JSON.stringify({ error: "Unauthorized: Missing bearer token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const isAuthorized = (serviceRoleKey && token === serviceRoleKey) ||
                         (anonKey && token === anonKey);

    if (!isAuthorized) {
      console.error("🚨 Unauthorized access attempt to fcm_push endpoint");
      return new Response(JSON.stringify({ error: "Unauthorized: Invalid bearer token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 1. Parse Webhook Body
    const payload = await req.json();
    const record = payload.record || payload;

    if (!record || (!record.user_id && !record.userId)) {
      return new Response("Invalid payload: missing user_id", { status: 400 });
    }

    const userId = record.user_id || record.userId;
    const title = record.title || "VSP Sports";
    const body = record.body || record.message || "";
    const type = record.type || "info";

    // 2. Connect to Supabase to fetch FCM Token for the user
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", userId)
      .maybeSingle();

    if (userError) {
      console.error("Error fetching user FCM token:", userError);
    }

    const fcmToken = userData?.fcm_token;

    if (userError || !fcmToken) {
      console.log(`ℹ️ No FCM token found for user ${userId}. Skipping push.`);
      return new Response(JSON.stringify({ status: "skipped", reason: "no_fcm_token" }), { 
        status: 200, 
        headers: { "Content-Type": "application/json" } 
      });
    }

    // 3. Read Firebase Secret JSON
    const firebaseJsonStr = Deno.env.get("FIREBASE_JSON") || Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!firebaseJsonStr) {
      throw new Error("FIREBASE_JSON secret is missing from Supabase environment");
    }
    const serviceAccount = JSON.parse(firebaseJsonStr);

    // 4. Generate OAuth2 JWT Token for Google APIs using jose
    const formattedPrivateKey = serviceAccount.private_key.replace(/\\n/g, "\n");
    const privateKey = await importPKCS8(formattedPrivateKey, "RS256");

    const jwt = await new SignJWT({
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(privateKey);

    // 5. Get Access Token from Google OAuth2
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    const tokenData = await tokenResponse.json();
    if (!tokenResponse.ok) {
      throw new Error(`Google OAuth Error: ${JSON.stringify(tokenData)}`);
    }
    const accessToken = tokenData.access_token;

    // 6. Build FCM v1 payload for High-Importance Heads-Up System Banner
    const fcmMessage = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: String(type),
          notification_id: String(record.id || ""),
          bookingId: String(record.booking_id || record.bookingId || ""),
        },
        android: {
          priority: "HIGH",
          notification: {
            sound: "default",
            channel_id: "vsp_default_channel",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            default_sound: true,
            default_vibrate_timings: true,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              contentAvailable: true,
            },
          },
        },
      },
    };

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmMessage),
      }
    );

    const fcmResultText = await fcmResponse.text();
    if (!fcmResponse.ok) {
      console.error("FCM Send Error:", fcmResultText);
      return new Response(JSON.stringify({ error: fcmResultText }), { 
        status: 200, 
        headers: { "Content-Type": "application/json" } 
      });
    }

    console.log(`✅ FCM Push Notification sent successfully to user ${userId}`);
    return new Response(JSON.stringify({ success: true, message: "Notification sent successfully" }), { 
      status: 200, 
      headers: { "Content-Type": "application/json" } 
    });
  } catch (error: any) {
    console.error("Function Error:", error);
    return new Response(JSON.stringify({ error: String(error?.message || error) }), { 
      status: 500, 
      headers: { "Content-Type": "application/json" } 
    });
  }
});
