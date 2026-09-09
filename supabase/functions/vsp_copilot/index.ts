// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const searchStadiumsTool = {
  name: "searchStadiums",
  description: "بحث واستكشاف الملاعب الرياضية المتاحة في مصر بالمنطقة أو السعر",
  parameters: {
    type: "OBJECT",
    properties: {
      governorate: {
        type: "STRING",
        description: "المحافظة أو المنطقة المراد البحث فيها (مثل: القاهرة، الجيزة، المعادي، مدينة نصر)",
      },
      date: {
        type: "STRING",
        description: "تاريخ اليوم أو التاريخ المطلوب بالصيغة YYYY-MM-DD",
      },
      max_price: {
        type: "NUMBER",
        description: "الحد الأقصى لسعر الساعة بالجنيه المصري",
      },
    },
  },
};

serve(async (req: Request) => {
  // 1. CORS Preflight
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

    // 2. Initialize Supabase Admin Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 3. 🔒 Strict Authentication First (Fail-Closed Auth)
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

    // 4. Check GEMINI_API_KEY server secret
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      console.error("🚨 Missing GEMINI_API_KEY in server environment!");
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: GEMINI_API_KEY missing" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. ⏱️ Rate Limiting: 10 requests per minute per user
    const { data: isAllowed, error: rateLimitErr } = await supabase.rpc("check_rate_limit", {
      p_user_id: callerUser.id,
      p_action: "copilot_chat",
      p_max_requests: 10,
      p_window_seconds: 60,
    });

    if (rateLimitErr || isAllowed === false) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Please wait a minute before sending more messages." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Parse Request Body
    const body = await req.json();
    const userMessage = (body.message ?? "").toString().trim();

    if (!userMessage) {
      return new Response(
        JSON.stringify({ error: "Bad Request: message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Gemini API Interaction (with single searchStadiums tool)
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`;

    const systemPrompt = "أنت كابتن VSP، المساعد الذكي لتطبيق VSP لحجز الملاعب والبطولات في مصر. تتحدث بلهجة مصرية مهذبة ومرحبة. يمكنك استكشاف الملاعب باستخدام أداة searchStadiums عند طلب المستخدم البحث عن ملاعب أو أوقات لعب.";

    const firstPayload = {
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents: [{ role: "user", parts: [{ text: userMessage }] }],
      tools: [{ functionDeclarations: [searchStadiumsTool] }],
    };

    const geminiRes1 = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(firstPayload),
    });

    if (!geminiRes1.ok) {
      const errText = await geminiRes1.text();
      console.error("Gemini API Error:", geminiRes1.status, errText);
      return new Response(
        JSON.stringify({ error: "AI Provider Error", details: errText }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData1 = await geminiRes1.json();
    const candidate1 = geminiData1.candidates?.[0]?.content;
    const functionCallPart = candidate1?.parts?.find((p: any) => p.functionCall);

    let stadiumResults: any[] = [];
    let assistantReply = "";

    if (functionCallPart && functionCallPart.functionCall.name === "searchStadiums") {
      const args = functionCallPart.functionCall.args || {};
      const governorate = (args.governorate || "").toString().trim();
      const maxPrice = Number(args.max_price);

      // 7. 🛡️ Read-Only Query with strict .limit(10)
      let query = supabase
        .from("stadiums")
        .select("id, name, governorate, price_per_hour, image_url, rating")
        .eq("is_verified", true)
        .eq("is_blocked", false)
        .eq("is_deleted_by_owner", false);

      if (governorate.length > 0) {
        query = query.ilike("governorate", `%${governorate}%`);
      }
      if (maxPrice > 0) {
        query = query.lte("price_per_hour", maxPrice);
      }

      query = query.order("rating", { ascending: false }).limit(10);

      const { data: stadiums, error: queryErr } = await query;
      if (queryErr) {
        console.error("Database query error:", queryErr);
      }
      stadiumResults = stadiums || [];

      // Second turn to summarize findings in natural Arabic
      const secondPayload = {
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [
          { role: "user", parts: [{ text: userMessage }] },
          candidate1,
          {
            role: "user",
            parts: [
              {
                functionResponse: {
                  name: "searchStadiums",
                  response: { count: stadiumResults.length, stadiums: stadiumResults },
                },
              },
            ],
          },
        ],
      };

      const geminiRes2 = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(secondPayload),
      });

      if (geminiRes2.ok) {
        const geminiData2 = await geminiRes2.json();
        assistantReply = geminiData2.candidates?.[0]?.content?.parts?.[0]?.text || "";
      } else {
        assistantReply = stadiumResults.length > 0
          ? `لقيتلك ${stadiumResults.length} ملاعب متاحة تناسب طلبك يا كابتن:`
          : "للأسف ملقتش ملاعب مطابقة للشروط دي حالياً، تحب نجرب منطقة تانية؟";
      }
    } else {
      assistantReply = candidate1?.parts?.[0]?.text || "أهلاً بك يا كابتن، كيف أقدر أساعدك اليوم في ملاعب VSP؟";
    }

    // 8. Return formatted payload to client
    return new Response(
      JSON.stringify({
        message: assistantReply,
        stadiums: stadiumResults,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("Unhandled Error in vsp_copilot:", err);
    return new Response(
      JSON.stringify({ error: "Internal Server Error", details: err?.message || String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
