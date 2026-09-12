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

    // 4. Check GEMINI_API_KEY server secret (optional with smart fallback)
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      console.warn("⚠️ GEMINI_API_KEY is not set in environment. Activating Smart Resilient Fallback Engine.");
    }

    // 5. ⏱️ Rate Limiting: 10 requests per minute per user (atomic advisory lock)
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

    // 6. Parse Request Body
    const body = await req.json();
    const userMessage = (body.message ?? "").toString().trim();
    let conversationId = (body.conversation_id ?? "").toString().trim();

    if (!userMessage) {
      return new Response(
        JSON.stringify({ error: "Bad Request: message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 7. Conversation Session Management
    if (conversationId) {
      const { data: existingConv } = await supabase
        .from("copilot_conversations")
        .select("id")
        .eq("id", conversationId)
        .eq("user_id", callerUser.id)
        .maybeSingle();

      if (!existingConv) {
        conversationId = ""; // fallback to new conversation if invalid or mismatched user
      }
    }

    if (!conversationId) {
      const generatedTitle = userMessage.length > 35
        ? userMessage.substring(0, 35) + "..."
        : userMessage;

      const { data: newConv, error: convErr } = await supabase
        .from("copilot_conversations")
        .insert({
          user_id: callerUser.id,
          title: generatedTitle,
        })
        .select("id")
        .single();

      if (convErr || !newConv) {
        throw new Error("Failed to initialize conversation session: " + (convErr?.message || ""));
      }
      conversationId = newConv.id;
    }

    // 8. Build Multi-Turn History for Gemini
    const { data: priorMessages } = await supabase
      .from("copilot_messages")
      .select("role, content")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true })
      .limit(8);

    const contents: any[] = [];
    if (priorMessages && priorMessages.length > 0) {
      for (const msg of priorMessages) {
        contents.push({
          role: msg.role === "user" ? "user" : "model",
          parts: [{ text: msg.content }],
        });
      }
    }
    contents.push({
      role: "user",
      parts: [{ text: userMessage }],
    });

    let stadiumResults: any[] = [];
    let assistantReply = "";
    let handledByGemini = false;

    // 9. Gemini API Interaction (if key is configured)
    if (geminiApiKey) {
      try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`;
        const systemPrompt = "أنت كابتن VSP، المساعد الذكي لتطبيق VSP لحجز الملاعب والبطولات في مصر. تتحدث بلهجة مصرية مهذبة ومرحبة. يمكنك استكشاف الملاعب باستخدام أداة searchStadiums عند طلب المستخدم البحث عن ملاعب أو أوقات لعب. وتتذكر ما دار بينكما في سياق المحادثة السابقة.";

        const firstPayload = {
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: contents,
          tools: [{ functionDeclarations: [searchStadiumsTool] }],
        };

        const geminiRes1 = await fetch(geminiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(firstPayload),
        });

        if (geminiRes1.ok) {
          const geminiData1 = await geminiRes1.json();
          const candidate1 = geminiData1.candidates?.[0]?.content;
          const functionCallPart = candidate1?.parts?.find((p: any) => p.functionCall);

          if (functionCallPart && functionCallPart.functionCall.name === "searchStadiums") {
            const args = functionCallPart.functionCall.args || {};
            const governorate = (args.governorate || "").toString().trim();
            const maxPrice = Number(args.max_price);

            // 10. 🛡️ Read-Only Query with strict .limit(10)
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
            const secondContents = [
              ...contents,
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
            ];

            const secondPayload = {
              systemInstruction: { parts: [{ text: systemPrompt }] },
              contents: secondContents,
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
            handledByGemini = true;
          } else {
            assistantReply = candidate1?.parts?.[0]?.text || "";
            if (assistantReply.trim().length > 0) {
              handledByGemini = true;
            }
          }
        } else {
          console.warn("Gemini API non-ok status:", geminiRes1.status);
        }
      } catch (geminiErr) {
        console.warn("Gemini API network error, falling back to smart search:", geminiErr);
      }
    }

    // 🛡️ Intelligent NLP & Database Fallback (Runs when GEMINI_API_KEY is missing or Gemini fails)
    if (!handledByGemini) {
      const egyptianGovs = [
        "القاهرة", "الجيزة", "المعادي", "مدينة نصر", "التجمع", "الدقي", "المهندسين",
        "الشيخ زايد", "أكتوبر", "الإسكندرية", "الشروق", "العبور", "حلوان", "شبرا",
        "طنطا", "المنصورة", "الشرقية", "الهرم", "فيصل", "الزمالك", "الرحاب", "مدينتي"
      ];
      let detectedGov = "";
      for (const gov of egyptianGovs) {
        if (userMessage.includes(gov)) {
          detectedGov = gov;
          break;
        }
      }

      let maxPrice = 0;
      const priceMatch = userMessage.match(/(\d{2,4})\s*(جنيه|ج|egp)?/i);
      if (priceMatch) {
        maxPrice = parseInt(priceMatch[1], 10);
      } else if (userMessage.includes("رخيص") || userMessage.includes("اقتصادي")) {
        maxPrice = 350;
      }

      let query = supabase
        .from("stadiums")
        .select("id, name, governorate, price_per_hour, image_url, rating")
        .eq("is_verified", true)
        .eq("is_blocked", false)
        .eq("is_deleted_by_owner", false);

      if (detectedGov) {
        query = query.ilike("governorate", `%${detectedGov}%`);
      }
      if (maxPrice > 0) {
        query = query.lte("price_per_hour", maxPrice);
      }

      query = query.order("rating", { ascending: false }).limit(10);
      const { data: stadiums } = await query;
      stadiumResults = stadiums || [];

      if (stadiumResults.length > 0) {
        if (detectedGov && maxPrice > 0) {
          assistantReply = `يا كابتن! بحثتلك في ${detectedGov} ولقيت ${stadiumResults.length} ملاعب ممتازة في حدود ${maxPrice} جنيه تناسب طلبك تماماً:`;
        } else if (detectedGov) {
          assistantReply = `يا كابتن! بحثتلك في ${detectedGov} ولقيت ${stadiumResults.length} ملاعب متاحة وتقييمها عالي وجاهزة للحجز:`;
        } else if (maxPrice > 0) {
          assistantReply = `تمام يا كابتن! دي أفضل ملاعب بأسعار في حدود ${maxPrice} جنيه أو أقل:`;
        } else {
          assistantReply = `أهلاً بك يا كابتن! دي تشكيلة من أفضل الملاعب المتاحة على VSP وتقييماتها عالية ومتاحة للحجز الآن:`;
        }
      } else {
        if (detectedGov) {
          assistantReply = `يا كابتن، حالياً مفيش ملاعب متاحة مسجلة في منطقة "${detectedGov}" بالشروط دي، تحب نجرب نبحث في منطقة تانية قريبة منها؟`;
        } else {
          assistantReply = `أهلاً بك يا كابتن في VSP! أنا كابتن VSP الذكي، تقدر تقولي بتدور على ملعب في أي منطقة أو بسعر كام، وأنا هجيبلك أفضل الخيارات فوراً!`;
        }
      }
    }

    // 11. Persist Messages & Update Conversation in Database
    await supabase.from("copilot_messages").insert([
      {
        conversation_id: conversationId,
        user_id: callerUser.id,
        role: "user",
        content: userMessage,
        stadium_results: [],
      },
      {
        conversation_id: conversationId,
        user_id: callerUser.id,
        role: "assistant",
        content: assistantReply,
        stadium_results: stadiumResults,
      },
    ]);

    await supabase
      .from("copilot_conversations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", conversationId);

    // 12. Return payload to client
    return new Response(
      JSON.stringify({
        conversation_id: conversationId,
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
