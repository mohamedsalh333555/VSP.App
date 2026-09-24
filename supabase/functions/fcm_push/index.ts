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
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    if (!token) {
      return new Response(JSON.stringify({ error: "Unauthorized: Missing bearer token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const isAuthorized = token === "internal_db_trigger" ||
                         (!!serviceRoleKey && token === serviceRoleKey);

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

    // 2. Load all registered device tokens, plus the legacy single token.
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const [{ data: deviceRows, error: deviceError }, { data: userData, error: userError }] =
      await Promise.all([
        supabase
          .from("user_device_tokens")
          .select("token")
          .eq("user_id", userId),
        supabase
          .from("users")
          .select("fcm_token")
          .eq("id", userId)
          .maybeSingle(),
      ]);

    if (deviceError) console.error("Error fetching device FCM tokens:", deviceError);
    if (userError) console.error("Error fetching legacy FCM token:", userError);

    const fcmTokens = Array.from(new Set([
      ...(deviceRows || []).map((row: any) => String(row.token || "").trim()),
      String(userData?.fcm_token || "").trim(),
    ].filter(Boolean)));

    if (fcmTokens.length === 0) {
      console.log(`ℹ️ No FCM tokens found for user ${userId}. Skipping push.`);
      return new Response(JSON.stringify({ status: "skipped", reason: "no_fcm_token" }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }

    const metadata = typeof record.metadata === "object" && record.metadata !== null ? record.metadata : {};
    const bookingId = String(record.booking_id || record.bookingId || metadata.booking_id || metadata.bookingId || "");
    const tournamentId = String(metadata.championship_id || metadata.tournament_id || metadata.tournamentId || record.championship_id || record.tournament_id || "");
    const teamId = String(metadata.team_id || metadata.teamId || record.team_id || record.teamId || "");

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

    // 6. Build and send the FCM v1 payload to every registered device.
    let sentCount = 0;
    let failedCount = 0;
    const invalidTokens: string[] = [];

    for (const fcmToken of fcmTokens) {
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
            bookingId,
            tournamentId,
            championship_id: tournamentId,
            teamId,
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
        failedCount++;
        console.error(`FCM Send Error for token ${fcmToken}:`, fcmResultText);
        if (fcmResponse.status === 404 && fcmResultText.includes("UNREGISTERED")) {
          invalidTokens.push(fcmToken);
        }
        continue;
      }

      sentCount++;
    }

    if (invalidTokens.length > 0) {
      await supabase
        .from("user_device_tokens")
        .delete()
        .in("token", invalidTokens);
    }

    console.log(`✅ FCM Push Notification sent to user ${userId}: ${sentCount} sent, ${failedCount} failed`);
    return new Response(JSON.stringify({
      success: sentCount > 0,
      sent_count: sentCount,
      failed_count: failedCount,
      invalid_tokens_removed: invalidTokens.length
    }), {
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
