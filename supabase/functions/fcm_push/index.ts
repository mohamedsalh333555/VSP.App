// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";
declare const Deno: any;

serve(async (req: Request) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });

    const { data: secretRow } = await supabase
      .from("internal_function_secrets")
      .select("secret")
      .eq("name", "fcm_push")
      .maybeSingle();

    const expectedSecret = secretRow?.secret?.toString() || "";
    const authorized =
      (serviceRoleKey.length > 0 && token === serviceRoleKey) ||
      (expectedSecret.length > 0 && token === expectedSecret);

    if (!authorized) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const payload = await req.json();
    const record = payload.record || payload;
    if (!record || (!record.user_id && !record.userId)) {
      return new Response(JSON.stringify({ error: "Invalid payload: missing user_id" }), { status: 400 });
    }

    const userId = record.user_id || record.userId;
    const title = record.title || "VSP Sports";
    const body = record.body || record.message || "";
    const type = record.type || "info";

    const [{ data: deviceRows }, { data: userData }] = await Promise.all([
      supabase.from("user_device_tokens").select("token").eq("user_id", userId),
      supabase.from("users").select("fcm_token").eq("id", userId).maybeSingle(),
    ]);

    const fcmTokens = Array.from(new Set([
      ...(deviceRows || []).map((row: any) => String(row.token || "").trim()),
      String(userData?.fcm_token || "").trim(),
    ].filter(Boolean)));

    if (fcmTokens.length === 0) {
      return new Response(JSON.stringify({ status: "skipped", reason: "no_fcm_token" }), { status: 200 });
    }

    const metadata = typeof record.metadata === "object" && record.metadata !== null ? record.metadata : {};
    const bookingId = String(record.booking_id || record.bookingId || metadata.booking_id || metadata.bookingId || "");
    const tournamentId = String(metadata.championship_id || metadata.tournament_id || metadata.tournamentId || record.championship_id || record.tournament_id || "");
    const teamId = String(metadata.team_id || metadata.teamId || record.team_id || record.teamId || "");

    const firebaseJsonStr = Deno.env.get("FIREBASE_JSON") || Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!firebaseJsonStr) throw new Error("FIREBASE_JSON secret is missing");

    const serviceAccount = JSON.parse(firebaseJsonStr);
    const formattedPrivateKey = serviceAccount.private_key.replace(/\\n/g, "\n");
    const privateKey = await importPKCS8(formattedPrivateKey, "RS256");

    const jwt = await new SignJWT({
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    }).setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(privateKey);

    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
    const tokenData = await tokenResponse.json();
    if (!tokenResponse.ok) throw new Error("Google OAuth failure");
    const accessToken = tokenData.access_token;

    let sentCount = 0;
    let failedCount = 0;
    const invalidTokens: string[] = [];

    for (const fcmToken of fcmTokens) {
      const fcmMessage = {
        message: {
          token: fcmToken,
          notification: { title, body },
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
            headers: { "apns-priority": "10" },
            payload: { aps: { sound: "default", badge: 1, contentAvailable: true } },
          },
        },
      };

      const fcmResponse = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
          body: JSON.stringify(fcmMessage),
        },
      );

      const resultText = await fcmResponse.text();
      if (!fcmResponse.ok) {
        failedCount++;
        if (fcmResponse.status === 404 && resultText.includes("UNREGISTERED")) invalidTokens.push(fcmToken);
        continue;
      }
      sentCount++;
    }

    if (invalidTokens.length) {
      await supabase.from("user_device_tokens").delete().in("token", invalidTokens);
    }

    return new Response(JSON.stringify({
      success: sentCount > 0,
      sent_count: sentCount,
      failed_count: failedCount,
      invalid_tokens_removed: invalidTokens.length,
    }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error: any) {
    console.error("FCM internal error", error);
    return new Response(JSON.stringify({ error: "Internal notification service error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
