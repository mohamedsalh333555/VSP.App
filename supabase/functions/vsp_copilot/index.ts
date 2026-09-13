// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// 1. Tool: searchStadiums
const searchStadiumsTool = {
  name: "searchStadiums",
  description: "بحث واستكشاف الملاعب الرياضية المتاحة في مصر بالمنطقة أو السعر أو المواعيد. استدعِ هذه الأداة فوراً عندما يسأل المستخدم عن الملاعب أو أسعار الحجز.",
  parameters: {
    type: "OBJECT",
    properties: {
      governorate: {
        type: "STRING",
        description: "المحافظة أو المنطقة المراد البحث فيها (مثل: القاهرة، الجيزة، المعادي، مدينة نصر)",
      },
      max_price: {
        type: "NUMBER",
        description: "الحد الأقصى لسعر الساعة بالجنيه المصري",
      },
    },
  },
};

// 2. Tool: searchTournaments
const searchTournamentsTool = {
  name: "searchTournaments",
  description: "البحث عن بطولات كرة القدم المتاحة للاشتراك، سواء بطولات خماسية للفرق (5x5) أو بطولات فردية (1v1) ومعرفة جوائزها وشروطها وتاريخها. استدعِ هذه الأداة فوراً عندما يسأل المستخدم عن البطولات أو الجوائز المالية أو الكؤوس.",
  parameters: {
    type: "OBJECT",
    properties: {
      tournament_type: {
        type: "STRING",
        description: "نوع البطولة: '5v5' لبطولات الفرق، أو '1v1' للتحديات الفردية، أو 'all' للكل",
      },
      governorate: {
        type: "STRING",
        description: "المحافظة (اختياري)",
      },
    },
  },
};

// 3. Tool: get1v1Leaderboard
const get1v1LeaderboardTool = {
  name: "get1v1Leaderboard",
  description: "عرض جدول ترتيب المتصدرين في دوري 1 ضد 1 الفردي (الحريفة) وأرقامهم. النقاط تُحسب بمجموع: (الأهداف + المهارات + قطع الكرات). استدعِ هذه الأداة فوراً عندما يسأل المستخدم عن الأول أو الترتيب أو المتصدر أو الرانك.",
  parameters: {
    type: "OBJECT",
    properties: {
      limit: {
        type: "NUMBER",
        description: "عدد اللاعبين المطلوب عرضهم (افتراضي 5)",
      },
    },
  },
};

// 4. Tool: getOpenMatches
const getOpenMatchesTool = {
  name: "getOpenMatches",
  description: "البحث عن مباريات وحجوزات خماسية مفتوحة ناقصها لاعيبة للانضمام فوراً واللعب (Open Join Matches). استدعِ هذه الأداة فوراً كلما سأل المستخدم عن ماتش ناقصه لاعيبة أو تقسيمة مفتوحة حتى لو لم يذكر محافظة معينة.",
  parameters: {
    type: "OBJECT",
    properties: {
      governorate: {
        type: "STRING",
        description: "المحافظة أو المنطقة (اختياري)",
      },
    },
  },
};

// 5. Tool: executeAppAction
const executeAppActionTool = {
  name: "executeAppAction",
  description: "توجيه المستخدم لشاشة داخل التطبيق وتنفيذ أمر التنقل، مثل: وديني لفريقي، افتح البطولات، وريني دوري 1v1، إعداداتي، البروفايل، حجوزاتي. استدعِ هذه الأداة فوراً عندما يطلب المستخدم الذهاب لشاشة معينة.",
  parameters: {
    type: "OBJECT",
    properties: {
      action_type: {
        type: "STRING",
        description: "نوع الإجراء: دائماً 'NAVIGATE'",
      },
      route: {
        type: "STRING",
        description: "المسار داخل التطبيق: '/tournaments' للبطولات، '/1v1' لدوري 1v1، '/my-team' لإدارة فريقي، '/bookings' لحجوزاتي، '/profile' للبروفايل، '/settings' للإعدادات",
      },
      label: {
        type: "STRING",
        description: "عنوان الإجراء بالعربية ليظهر كزر للمستخدم (مثال: 'الانتقال لصفحة فريقي')",
      },
    },
    required: ["action_type", "route", "label"],
  },
};

// 6. Tool: updateUserProfile
const updateUserProfileTool = {
  name: "updateUserProfile",
  description: "تحديث وتعديل بيانات الملف الشخصي للمستخدم مباشرة في قاعدة البيانات، مثل تغيير المركز المفضل (مهاجم، مدافع، خط وسط، حارس مرمى) أو المحافظة أو الاسم أو رقم الهاتف. استدعِ هذه الأداة فوراً عندما يطلب المستخدم تعديل أي من بياناته الشخصية دون سؤاله.",
  parameters: {
    type: "OBJECT",
    properties: {
      position: {
        type: "STRING",
        description: "مركز اللاعب المفضل: 'مهاجم'، 'خط وسط'، 'مدافع'، أو 'حارس مرمى'",
      },
      governorate: {
        type: "STRING",
        description: "المحافظة (مثل: القاهرة، الجيزة، الإسكندرية)",
      },
      name: {
        type: "STRING",
        description: "اسم المستخدم الجديد إذا طلب تعديله",
      },
      phone: {
        type: "STRING",
        description: "رقم الهاتف الجديد إذا طلب تعديله",
      },
    },
  },
};

// 7. Tool: getUserBookingsAndRefunds
const getUserBookingsAndRefundsTool = {
  name: "getUserBookingsAndRefunds",
  description: "الاستعلام عن حجوزات المستخدم وسجل العمليات وتتبع حالة استرداد الأموال والمبالغ المسترجعة (Refunds) أو الإلغاءات. استدعِ هذه الأداة فوراً عندما يسأل المستخدم عن حجزه، فلوسه، الاسترداد، أو إلغاء حجز ليطمئن.",
  parameters: {
    type: "OBJECT",
    properties: {
      query_type: {
        type: "STRING",
        description: "نوع الاستعلام: 'all' للكل، أو 'refunds' للمستردات والإلغاءات، أو 'active' للحجوزات القادمة",
      },
    },
  },
};

const allCopilotTools = [
  searchStadiumsTool,
  searchTournamentsTool,
  get1v1LeaderboardTool,
  getOpenMatchesTool,
  executeAppActionTool,
  updateUserProfileTool,
  getUserBookingsAndRefundsTool,
];

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

    // 4. Check GEMINI_API_KEY
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

    // 5. Rate Limiting
    const { data: isAllowed, error: rateLimitErr } = await supabase.rpc("check_rate_limit", {
      p_user_id: callerUser.id,
      p_action: "copilot_chat",
      p_max_requests: 20,
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
        conversationId = "";
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
    let tournamentResults: any[] = [];
    let leaderboardResults: any[] = [];
    let openMatchResults: any[] = [];
    let appAction: any = null;
    let assistantReply = "";
    let handledByGemini = false;

    // 9. Gemini 2.5 Flash Interaction
    if (geminiApiKey) {
      try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
        const systemPrompt = `أنت "كابتن VSP"، المساعد والمدير الذكي الشامل والوكيل التشغيلي لتطبيق VSP لحجز الملاعب والبطولات في مصر (Omni-Capable In-App Operating Agent).
تتحدث بلهجة مصرية كروية حماسية وودودة ومحترمة (يا كابتن، يا حريف، يا بطل).

قاعدة الحقيقة المطلقة والنزاهة الصارمة (STRICT ZERO-HALLUCINATION POLICY):
1. أنت متصل مباشرة بقاعدة بيانات VSP الحقيقية وتعتمد عليها حصراً في كل معلومة.
2. ممنوع منعاً باتاً اختلاق، أو تأليف، أو افتراض، أو اقتراح أي بطولة، أو ملعب، أو مباراة، أو أسماء لاعبين، أو رسوم اشتراك، أو جوائز غير موجودة في نتائج الأدوات (Function Calling Database Results) إطلاقاً!
3. إذا عادت نتائج أداة searchTournaments أو searchStadiums فارغة (0 نتائج)، يجب أن تصرح بذلك للمستخدم بأمانة تامة: "عذراً يا كابتن، لا توجد حالياً بطولات مفتوحة للتسجيل في قاعدة البيانات" أو "لا توجد ملاعب مطابقة حالياً". لا تخترع أسماء بطولات أبداً مثل "ملك الـ 1v1" أو "تحدي الحريفة"!

قاعدة إلزامية وصارمة لاستدعاء الأدوات:
عندما يسأل أو يطلب المستخدم أي شيء يتعلق بالوظائف التالية، استدعِ الأداة المناسبة فوراً دون تأليف ودون طرح أي أسئلة استفسارية أولاً:
1. بطولات أو كؤوس أو جوائز أو بطولات فردية (1v1): استدعِ searchTournaments فوراً.
2. ماتشات ناقصة لاعيبة أو تقسيمة: استدعِ getOpenMatches فوراً.
3. الأول أو الترتيب أو دوري 1v1 أو النقاط: استدعِ get1v1Leaderboard فوراً.
4. البحث عن ملاعب أو أسعار: استدعِ searchStadiums فوراً.
5. تغيير المركز أو تعديل بيانات الملف الشخصي: استدعِ updateUserProfile فوراً.
6. الاستفسار عن حجز، فلوس، استرداد أموال: استدعِ getUserBookingsAndRefunds فوراً.
7. طلب الذهاب لشاشة معينة: استدعِ executeAppAction فوراً.

فلسفة احتساب نقاط دوري 1 ضد 1 الفردي (الحريفة):
- كل هدف = +1 نقطة.
- كل مهارة ناجحة/استعراض = +1 نقطة.
- كل قطع كرة/استخلاص = +1 نقطة.
- إجمالي النقاط = (أهداف + مهارات + قطع كرات).`;

        const firstPayload = {
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: contents,
          tools: [{ functionDeclarations: allCopilotTools }],
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

          if (functionCallPart) {
            const funcName = functionCallPart.functionCall.name;
            const args = functionCallPart.functionCall.args || {};
            let toolResponseData: any = {};

            if (funcName === "searchStadiums") {
              const governorate = (args.governorate || "").toString().trim();
              const maxPrice = Number(args.max_price);

              let query = supabase
                .from("stadiums")
                .select("id, name, governorate, price_per_hour, image_url, rating")
                .eq("is_verified", true)
                .eq("is_blocked", false)
                .eq("is_deleted_by_owner", false);

              if (governorate.length > 0) query = query.ilike("governorate", `%${governorate}%`);
              if (maxPrice > 0) query = query.lte("price_per_hour", maxPrice);
              query = query.order("rating", { ascending: false }).limit(10);

              const { data: stadiums } = await query;
              stadiumResults = stadiums || [];
              toolResponseData = { count: stadiumResults.length, stadiums: stadiumResults };

            } else if (funcName === "searchTournaments") {
              const tType = (args.tournament_type || "all").toString().toLowerCase();
              const gov = (args.governorate || "").toString().trim();

              const results: any = {};
              if (tType === "all" || tType === "5v5") {
                let q5v5 = supabase.from("championships").select("id, name, type, grand_prize, entry_fee, max_teams, status, governorate").eq("status", "open");
                if (gov) q5v5 = q5v5.ilike("governorate", `%${gov}%`);
                const { data: champs } = await q5v5.limit(5);
                results.team_tournaments_5v5 = champs || [];
              }
              if (tType === "all" || tType === "1v1") {
                let q1v1 = supabase.from("vsp_1v1_tournaments").select("id, name, status, prize_pool, entry_fee, target_player_count, governorate").eq("status", "registration_open");
                if (gov) q1v1 = q1v1.ilike("governorate", `%${gov}%`);
                const { data: t1v1 } = await q1v1.limit(5);
                results.individual_tournaments_1v1 = t1v1 || [];
              }
              tournamentResults = [...(results.team_tournaments_5v5 || []), ...(results.individual_tournaments_1v1 || [])];
              toolResponseData = results;

            } else if (funcName === "get1v1Leaderboard") {
              const limit = Number(args.limit) || 5;
              const { data: players } = await supabase
                .from("vsp_1vs1_players")
                .select("name, total_points, skill_points, goals, tackles, titles, trend")
                .order("total_points", { ascending: false })
                .limit(limit);

              leaderboardResults = players || [];
              toolResponseData = {
                formula: "total_points = tackles + goals + skill_points",
                top_players: leaderboardResults,
              };

            } else if (funcName === "getOpenMatches") {
              const { data: matches } = await supabase
                .from("bookings")
                .select("id, stadium_name, start_time, current_players, max_players, notes, total_price")
                .eq("booking_type", "open_join")
                .eq("status", "confirmed")
                .gte("start_time", new Date().toISOString())
                .order("start_time", { ascending: true })
                .limit(5);

              openMatchResults = matches || [];
              toolResponseData = { open_matches: openMatchResults };

            } else if (funcName === "executeAppAction") {
              appAction = {
                action_type: args.action_type || "NAVIGATE",
                route: args.route || "/tournaments",
                label: args.label || "فتح الشاشة",
              };
              toolResponseData = { status: "ready_to_navigate", action: appAction };

            } else if (funcName === "updateUserProfile") {
              const updates: any = { updated_at: new Date().toISOString() };
              if (args.position) updates.position = args.position;
              if (args.governorate) updates.governorate = args.governorate;
              if (args.name) updates.name = args.name;
              if (args.phone) updates.phone = args.phone;

              const { error: updateErr } = await supabase
                .from("users")
                .update(updates)
                .eq("id", callerUser.id);

              if (updateErr) {
                toolResponseData = { success: false, error: updateErr.message };
              } else {
                appAction = {
                  action_type: "PROFILE_UPDATED",
                  route: "/profile",
                  label: `تم تعديل ${args.position ? 'المركز إلى ' + args.position : 'بياناتك'} بنجاح ✅`,
                  params: updates,
                };
                toolResponseData = {
                  success: true,
                  updated_fields: updates,
                  message: "تم تحديث بيانات البروفايل بنجاح في قاعدة البيانات",
                };
              }

            } else if (funcName === "getUserBookingsAndRefunds") {
              const { data: userBookings } = await supabase
                .from("bookings")
                .select("id, stadium_name, start_time, status, payment_status, total_price, refund_amount, refunded_at, cancellation_reason")
                .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
                .order("created_at", { ascending: false })
                .limit(5);

              const bookingsList = userBookings || [];
              const refunds = bookingsList.filter((b: any) => (b.refund_amount && Number(b.refund_amount) > 0) || b.refunded_at || b.status === "cancelled");

              appAction = {
                action_type: "NAVIGATE",
                route: "/bookings",
                label: "عرض سجل الحجوزات والمستحقات 📋",
              };

              toolResponseData = {
                total_bookings: bookingsList.length,
                recent_bookings: bookingsList,
                refund_related_bookings: refunds,
                has_refunds: refunds.length > 0,
              };
            }

            // Second turn for natural conversational response
            const secondContents = [
              ...contents,
              candidate1,
              {
                role: "function",
                parts: [
                  {
                    functionResponse: {
                      name: funcName,
                      response: toolResponseData,
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
            }

            // 🛡️ Zero-Hallucination Guard: If searchTournaments returned 0 rows, never allow hallucinated tournament text!
            if (funcName === "searchTournaments" && tournamentResults.length === 0) {
              assistantReply = "عذراً يا كابتن، بحثتلك في قاعدة بيانات VSP ومافيش حالياً بطولات مفتوحة للتسجيل في منطقتك. أول ما تنزل بطولة جديدة هتلاقيها معلنة في صفحة البطولات وتقدر تشترك فوراً!";
            } else if (!assistantReply) {
              if (funcName === "get1v1Leaderboard") {
                assistantReply = "يا كابتن، ده ترتيب قمة دوري الـ 1v1، والنقاط محسوبة بمجموع (الأهداف + المهارات + قطع الكرات):";
              } else if (funcName === "searchTournaments") {
                assistantReply = "لقيتلك البطولات النشطة وجاهزة للتسجيل يا كابتن:";
              } else if (funcName === "getOpenMatches") {
                assistantReply = "دي الماتشات المفتوحة اللي ناقصها لعيبة ومتاحة تنضم ليها فوراً:";
              } else if (funcName === "updateUserProfile") {
                assistantReply = "تم يا كابتن! عدلتلك بياناتك في البروفايل بنجاح ⚽";
              } else if (funcName === "getUserBookingsAndRefunds") {
                assistantReply = "يا كابتن، راجعتلك سجل حجوزاتك ومستحقاتك وكل العمليات مسجلة ومضمونة في VSP:";
              } else {
                assistantReply = "تمام يا كابتن، طلبك جاهز!";
              }
            }
            handledByGemini = true;

          } else {
            // 🛡️ Anti-hallucination: If user asked about tournaments, stadiums, or leaderboard, but Gemini skipped tool call, fall back to live DB queries!
            const needsTool = userMessage.includes("بطول") ||
                              userMessage.includes("كأس") ||
                              userMessage.includes("دوري") ||
                              userMessage.includes("1v1") ||
                              userMessage.includes("ملعب") ||
                              userMessage.includes("ملاعب");
            if (needsTool) {
              handledByGemini = false;
            } else {
              assistantReply = candidate1?.parts?.[0]?.text || "";
              if (assistantReply.trim().length > 0) {
                handledByGemini = true;
              }
            }
          }
        }
      } catch (geminiErr) {
        console.warn("Gemini API error, falling back to smart engine:", geminiErr);
      }
    }

    // 🛡️ Intelligent Fallback Engine
    if (!handledByGemini) {
      if (userMessage.includes("بطول") || userMessage.includes("كأس") || (userMessage.includes("دوري") && !userMessage.includes("1v1"))) {
        const { data: champs } = await supabase.from("championships").select("name, grand_prize, entry_fee").eq("status", "open").limit(3);
        const { data: t1v1 } = await supabase.from("vsp_1v1_tournaments").select("name, prize_pool").eq("status", "registration_open").limit(2);
        tournamentResults = [...(champs || []), ...(t1v1 || [])];
        appAction = { action_type: "NAVIGATE", route: "/tournaments", label: "فتح صفحة البطولات 🏆" };
        if (tournamentResults.length === 0) {
          assistantReply = "يا كابتن، حالياً لا توجد بطولات مفتوحة للتسجيل في قاعدة بيانات VSP. تقدر تتابع صفحة البطولات أولاً بأول، أو تطلب مني البحث عن ملاعب أو ماتشات مفتوحة تنضم ليها!";
        } else {
          assistantReply = "يا كابتن! دي أحدث البطولات النشطة على VSP:\n" +
            (champs || []).map((c: any) => `🏆 ${c.name} - جائزة: ${c.grand_prize} ج.م`).join("\n") + "\n" +
            (t1v1 || []).map((t: any) => `⚡ ${t.name} - جائزة: ${t.prize_pool} ج.م`).join("\n");
        }
      } else if (userMessage.includes("الأول") || userMessage.includes("ترتيب") || userMessage.includes("1v1") || userMessage.includes("متصدر")) {
        const { data: players } = await supabase.from("vsp_1vs1_players").select("name, total_points, goals, tackles, skill_points").order("total_points", { ascending: false }).limit(4);
        leaderboardResults = players || [];
        appAction = { action_type: "NAVIGATE", route: "/1v1", label: "عرض دوري الـ 1v1 بالكامل ⚡" };
        assistantReply = "يا كابتن، جدول متصدري دوري الـ 1v1 (النقاط = أهداف + مهارات + قطع كرات):\n" +
          (players || []).map((p: any, i: number) => `${i + 1}. ${p.name}: ${p.total_points} نقطة (${p.goals} هدف، ${p.skill_points} مهارة، ${p.tackles} قطع)`).join("\n");
      } else if (userMessage.includes("ناقص") || userMessage.includes("ماتش") || userMessage.includes("تقسيمة") || userMessage.includes("انضم")) {
        const { data: matches } = await supabase.from("bookings").select("id, stadium_name, current_players, max_players, notes, total_price, start_time").eq("booking_type", "open_join").limit(3);
        openMatchResults = matches || [];
        appAction = { action_type: "NAVIGATE", route: "/bookings", label: "استعراض كل الماتشات المفتوحة ⚽" };
        assistantReply = "الماتشات المفتوحة اللي محتاجة لعيبة الآن يا كابتن:";
      } else if (userMessage.includes("فريق") || userMessage.includes("فرقتي")) {
        appAction = { action_type: "NAVIGATE", route: "/my-team", label: "الانتقال لصفحة فريقي 🛡️" };
        assistantReply = "حاضر يا كابتن! هوديك لصفحة إدارة فريقك وقائمتك دلوقتي.";
      } else if (userMessage.includes("مركزي") || userMessage.includes("بروفايل") || userMessage.includes("عدل") || userMessage.includes("غير")) {
        let pos = "";
        if (userMessage.includes("مهاجم")) pos = "مهاجم";
        else if (userMessage.includes("مدافع")) pos = "مدافع";
        else if (userMessage.includes("حارس")) pos = "حارس مرمى";
        else if (userMessage.includes("وسط")) pos = "خط وسط";

        if (pos) {
          await supabase.from("users").update({ position: pos, updated_at: new Date().toISOString() }).eq("id", callerUser.id);
          appAction = { action_type: "PROFILE_UPDATED", route: "/profile", label: `تم تغيير مركزك إلى ${pos} بنجاح ✅` };
          assistantReply = `تمام يا كابتن! تم تغيير مركزك المفضل في بروفايلك إلى (${pos}) بنجاح في قاعدة البيانات.`;
        } else {
          appAction = { action_type: "NAVIGATE", route: "/profile", label: "فتح الملف الشخصي 👤" };
          assistantReply = "تقدر تعدل بياناتك وبروفايلك بالكامل من هنا يا كابتن:";
        }
      } else if (userMessage.includes("فلوس") || userMessage.includes("استرداد") || userMessage.includes("حجزي") || userMessage.includes("ملغي") || userMessage.includes("ريفاوند")) {
        const { data: bookings } = await supabase.from("bookings").select("stadium_name, status, total_price, refund_amount, refunded_at").or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`).limit(3);
        appAction = { action_type: "NAVIGATE", route: "/bookings", label: "مراجعة سجل حجوزاتك ومستحقاتك 📋" };
        assistantReply = "متقلقش خالص يا كابتن، كل عملياتك المالية وحجوزاتك مسجلة ومضمونة في VSP! تقدر تراجع تفاصيل الحجز والمستردات فوراً من شاشة حجوزاتي.";
      } else {
        const { data: stadiums } = await supabase.from("stadiums").select("id, name, governorate, price_per_hour, image_url, rating").eq("is_verified", true).eq("is_blocked", false).limit(5);
        stadiumResults = stadiums || [];
        assistantReply = "أهلاً بك يا كابتن! دي أبرز الملاعب المتاحة على VSP للحجز الفوري وتقييمها عالي:";
      }
    }

    // 10. Persist Messages & Update Conversation
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

    // 11. Return enriched payload
    return new Response(
      JSON.stringify({
        conversation_id: conversationId,
        message: assistantReply,
        stadiums: stadiumResults,
        tournaments: tournamentResults,
        leaderboard: leaderboardResults,
        open_matches: openMatchResults,
        action: appAction,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("VSP Copilot function error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
