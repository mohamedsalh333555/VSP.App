// Response Generator Layer for VSP Copilot
// Prompts Gemini for natural Egyptian Arabic phrasing while enforcing Zero-Hallucination of operational facts.

import type { ConversationState } from "./conversation_state.ts";
import type { ToolResultContract } from "./tool_executor.ts";
import type { ToolPlan } from "./tool_planner.ts";

export function formatArabicCount(count: number, singular: string, dual: string, plural: string): string {
  if (count === 1) return singular;
  if (count === 2) return dual;
  if (count >= 3 && count <= 10) return `${count} ${plural}`;
  return `${count} ${singular}`;
}

export function buildResponseGeneratorPrompt(
  state: ConversationState,
  plan: ToolPlan,
  toolResult: ToolResultContract | null,
  userMessage: string
): string {
  const verifiedFacts: Record<string, any> = {};

  if (state.stadium.name) verifiedFacts.stadium_name = state.stadium.name;
  if (state.date.value) verifiedFacts.date = state.date.value;
  if (state.times.length > 0) verifiedFacts.preferred_times = state.times.map(t => t.time);
  if (state.duration_hours > 1) verifiedFacts.duration_hours = state.duration_hours;
  if (state.group_size) verifiedFacts.group_size = state.group_size;
  if (state.pending_confirmation) verifiedFacts.pending_confirmation = state.pending_confirmation;

  if (toolResult) {
    verifiedFacts.tool_name = toolResult.tool_name;
    verifiedFacts.tool_status = toolResult.status;
    verifiedFacts.tool_data = toolResult.data;
    if (toolResult.error_message) verifiedFacts.tool_error = toolResult.error_message;
  }

  return `أنت "كابتن VSP"، المساعد الرياضي الذكي لتطبيق VSP في مصر.
مهمتك صياغة رد نهائي ذكي وطبيعي ومختصر باللهجة المصرية الودودة.

قواعد الصياغة الصارمة (STRICT RULES):
1. اعتمد 100% فقط على الحقائق الموثقة أدناه (VERIFIED FACTS). ممنوع نهائياً اختراع أي ملعب أو سعر أو موعد أو حجز.
2. لا تذكر للمستخدم أي مصطلحات تقنية أو بنية داخلية: ممنوع منعاً باتاً "من بيانات VSP"، "قاعدة البيانات"، "السيستم"، "الأدوات"، أو "API". اعرض النتائج مباشرة كأنك تراها في التطبيق.
3. التزم باللغة العربية السليمة للعدد والمعدود: قل "لقيتلك ملعب واحد" (وليس "1 ملاعب")، قل "ملعبين"، قل "3 ملاعب".
4. استخدم لقب "يا كابتن" بحد أقصى مرة واحدة في أول الرد فقط، وبشكل عفوي غير متكلف.
5. إذا كان المطلوب تأكيد الموعد أو الفترة، اسأل للتأكيد بأسلوب طبيعي وموجز:
   مثال: "عايز تحجز ملعب [اسم الملعب] الساعة [الوقت] بالليل، مظبوط كده؟"
   وممنوع أن تسأل: "الساعة كام؟" طالما أن الساعة محددة بالفعل في الحقائق الموثقة.
6. إذا حدث خطأ تقني أو لم توجد نتائج، وضّح ذلك بأسلوب رياضي راقٍ واقترح حلاً بديلاً.

رسالة المستخدم الأصلية:
"${userMessage}"

خطة الإجراء (PLAN):
${JSON.stringify(plan, null, 2)}

الحقائق الموثقة (VERIFIED FACTS):
${JSON.stringify(verifiedFacts, null, 2)}

صِغ ردك النهائي بالعامية المصرية الودية الآن:`;
}

// Deterministic Safe Fallback Generator (if Gemini is unavailable)
export function generateDeterministicResponse(
  state: ConversationState,
  plan: ToolPlan,
  toolResult: ToolResultContract | null
): { message: string; quick_replies: string[] } {
  // 1. Tool result responses
  if (toolResult) {
    if (toolResult.tool_name === "searchStadiums") {
      const count = toolResult.data.count || 0;
      if (count === 0) {
        return {
          message: "دورتلك في المنطقة المحددة ومفيش ملاعب متاحة دلوقتي يا كابتن. تحب نبحث في محافظة تانية أو نعدل السعر؟",
          quick_replies: ["القاهرة", "الجيزة", "أسوان"],
        };
      }
      const label = formatArabicCount(count, "ملعب متاح", "ملعبين متاحين", "ملاعب متاحة");
      return {
        message: `يا كابتن! لقيتلك ${label} جاهزة للحجز على VSP:`,
        quick_replies: toolResult.stadiums?.slice(0, 3).map(s => s.name) || [],
      };
    }

    if (toolResult.tool_name === "checkStadiumAvailability") {
      const availableCount = toolResult.data.available_slots_count || 0;
      const stadiumName = toolResult.data.stadium_name || state.stadium.name || "الملعب";
      if (availableCount === 0) {
        return {
          message: `بصيت على جدول مواعيد ${stadiumName}، واليوم ده مفيش فيه فترات فاضية يا كابتن. تحب نجرب يوم تاني؟`,
          quick_replies: ["بكرة", "بعد بكرة"],
        };
      }
      const prop = toolResult.data.proposed_slot;
      if (prop) {
        const h = new Date(prop.start_time).getUTCHours();
        const displayH = (h + 2) % 24; // Cairo approx or local
        return {
          message: `تمام يا كابتن! ${stadiumName} متاح في الميعاد المطلوب. تحب نأكد حجز الساعة ${displayH > 12 ? displayH - 12 : displayH} بالليل لمدة ساعة؟`,
          quick_replies: ["أيوه، أكد الحجز", "تغيير الميعاد"],
        };
      }
    }

    if (toolResult.tool_name === "createBookingFromChat") {
      if (toolResult.status === "SUCCESS") {
        const std = toolResult.data.stadium_name || "الملعب";
        if (toolResult.data.deposit_required) {
          return {
            message: `تم تجهيز موعدك في ${std} بنجاح يا كابتن ⚽! تم حفظ الحجز مؤقتاً، اضغط بالأسفل لإتمام دفع العربون وتأكيد الحجز.`,
            quick_replies: [],
          };
        }
        return {
          message: `ألف مبروك يا كابتن! تم تأكيد حجزك في ${std} بنجاح والدفع كاش في الملعب 📋`,
          quick_replies: [],
        };
      }
      return {
        message: toolResult.error_message || "تعذر إتمام الحجز في هذا التوقيت، تحب نختار ميعاد تاني؟",
        quick_replies: ["شوف ميعاد تاني"],
      };
    }

    if (toolResult.tool_name === "searchTournaments") {
      return {
        message: "يا كابتن! دي البطولات النشطة والمتاحة للاشتراك حالياً على VSP:",
        quick_replies: ["بطولات 5v5", "بطولات 1v1"],
      };
    }

    if (toolResult.tool_name === "get1v1Leaderboard") {
      return {
        message: "يا كابتن، ده ترتيب قمة دوري الـ 1v1 والنقاط محسوبة بمجموع (الأهداف + المهارات + قطع الكرات):",
        quick_replies: [],
      };
    }

    if (toolResult.tool_name === "getOpenMatches") {
      return {
        message: "دي الماتشات المفتوحة والتقسيمات اللي ناقصها لعيبة ومتاحة تنضم ليها فوراً يا كابتن ⚽:",
        quick_replies: [],
      };
    }

    if (toolResult.tool_name === "getOwnerFinancialInsights") {
      const avail = toolResult.data.available_balance ?? 0;
      return {
        message: `يا كابتن، الرصيد المتاح للسحب في حسابك حالياً هو ${avail} ج.م. تقدر تطلب سحب أو تعرض السجل المالي بالتفصيل.`,
        quick_replies: ["فتح السجل المالي"],
      };
    }

    if (toolResult.tool_name === "getOwnerStadiumsAndBookings") {
      return {
        message: "يا كابتن، دي تفاصيل ملاعبك وحجوزاتك المسجلة في التطبيق:",
        quick_replies: ["جدول الحجوزات"],
      };
    }
  }

  // 2. Plan actions
  if (plan.action === "ASK_SLOT") {
    if (plan.missing_slot === "stadium") {
      return {
        message: "تمام يا كابتن. تحب تحجز في أنهي ملعب؟",
        quick_replies: plan.quick_replies || [],
      };
    }
    if (plan.missing_slot === "date") {
      return {
        message: "تمام، طلبك اتسجل. تحب الحجز يكون النهارده ولا بكرة؟",
        quick_replies: plan.quick_replies || ["النهارده", "بكرة"],
      };
    }
    if (plan.missing_slot === "time") {
      return {
        message: "تحب نحجز الساعة كام يا كابتن؟",
        quick_replies: plan.quick_replies || ["8 بالليل", "9 بالليل", "10 بالليل"],
      };
    }
    if (plan.missing_slot === "time_period") {
      const targetTime = state.times[0]?.time || "10:00";
      const h = Number(targetTime.split(":")[0]);
      const displayH = h > 12 ? h - 12 : h;
      const stadiumName = state.stadium.name ? ` في ${state.stadium.name}` : "";
      return {
        message: `عايز تحجز${stadiumName} الساعة ${displayH} بالليل، مظبوط كده؟`,
        quick_replies: ["أيوه بالليل", "الصبح"],
      };
    }
  }

  if (plan.action === "SAFE_DEGRADED_CLARIFICATION") {
    return {
      message: plan.reason || "يا كابتن، في ضغط لحظي مؤقت على خدمة الذكاء الاصطناعي وما قدرتش أستوعب رسالتك الأخيرة بدقة. بياناتك ومواعيدك السابقة محفوظة بأمان، تقدر تختار الخطوة التالية من الخيارات بالأسفل:",
      quick_replies: plan.quick_replies || ["عايز ملعب قريب", "البطولات المفتوحة", "ترتيب الحريفة 1v1"],
    };
  }

  if (plan.action === "CLARIFY_AMBIGUITY") {
    return {
      message: plan.reason || "محتاج توضيح بسيط عشان أنفذ طلبك بدقة يا كابتن:",
      quick_replies: plan.quick_replies || [],
    };
  }

  if (plan.action === "RESPOND_DIRECTLY") {
    if (plan.reason) {
      return {
        message: plan.reason,
        quick_replies: plan.quick_replies || [],
      };
    }
    if (state.active_task === "booking") {
      if (!state.stadium.name && !state.stadium.id) {
        return {
          message: "تمام يا كابتن. تحب نحجز في أنهي ملعب؟",
          quick_replies: state.candidate_stadiums.slice(0, 3).map(s => s.name),
        };
      }
      if (!state.date.value) {
        return {
          message: "تمام، تحب الحجز يكون النهارده ولا بكرة؟",
          quick_replies: ["النهارده", "بكرة"],
        };
      }
    }
    return {
      message: "يا كابتن، تحب أساعدك في حجز ملعب ولا استكشاف البطولات أو ماتشات التقسيمة؟",
      quick_replies: ["عايز ملعب قريب", "البطولات المفتوحة", "ترتيب الحريفة 1v1"],
    };
  }

  // If conversation has an active task, do NOT return welcome greeting
  if (state.active_task && state.active_task !== "idle") {
    return {
      message: "محتاج توضيح بسيط عشان أنفذ طلبك بدقة يا كابتن، تحب نختار ميعاد تاني ولا ملعب مختلف؟",
      quick_replies: ["ميعاد تاني", "ملعب مختلف"],
    };
  }

  return {
    message: "أهلاً بيك يا كابتن! أنا جاهز أساعدك في حجز الملاعب، استكشاف البطولات، وماتشات التقسيمة. تحب تبدأ بإيه؟",
    quick_replies: ["عايز ملعب قريب", "البطولات المفتوحة", "ترتيب الحريفة 1v1"],
  };
}

export interface FactValidationResult {
  isValid: boolean;
  reason?: string;
}

// Runtime Fact Validator: Guarantees zero hallucination of financial or operational facts
export function validateAssistantResponseFacts(
  response: string,
  state: ConversationState,
  plan: ToolPlan,
  toolResult: ToolResultContract | null
): FactValidationResult {
  if (!response || typeof response !== "string") {
    return { isValid: false, reason: "Empty response" };
  }

  // 1. Check for fabricated booking completion claims
  const claimsBookingComplete = /(?:تم الحجز|حجزتلك|تم تأكيد الحجز بنجاح|حجزنا الملعب|تم تسجيل حجزك)/i.test(response);
  if (claimsBookingComplete) {
    const actuallySucceeded = toolResult && toolResult.tool_name === "createBookingFromChat" && toolResult.status === "SUCCESS";
    if (!actuallySucceeded) {
      return {
        isValid: false,
        reason: "Fabricated booking completion claim without verified SUCCESS booking tool result",
      };
    }
  }

  // 2. Check for false availability claims when an error occurred
  const claimsUnavailable = /(?:الملعب غير متاح|مفيش مواعيد|غير متوفر|مفيش فترات فاضية)/i.test(response);
  if (claimsUnavailable && toolResult) {
    if (toolResult.status === "TEMPORARY_ERROR" || toolResult.status === "DATA_ERROR" || toolResult.status === "AUTH_ERROR") {
      return {
        isValid: false,
        reason: "Reported stadium as unavailable when the actual result was a technical error",
      };
    }
  }

  // 3. Check for price fabrication in EGP
  const priceMatches = [...response.matchAll(/(?:بـ\s*|سعر(?:ها|ه)?\s*|بمبلغ\s*)?(\d{2,5})\s*(?:جنيه|ج\.م|ج\b)/gi)];
  if (priceMatches.length > 0) {
    const allowedPrices = new Set<number>();
    if (state.stadium.price_per_hour) {
      const p = state.stadium.price_per_hour;
      allowedPrices.add(p);
      allowedPrices.add(p * (state.duration_hours || 1));
    }
    if (toolResult?.stadiums) {
      for (const s of toolResult.stadiums) {
        if (s.price_per_hour) {
          allowedPrices.add(s.price_per_hour);
          allowedPrices.add(s.price_per_hour * (state.duration_hours || 1));
        }
      }
    }
    if (toolResult?.data?.price_per_hour) {
      const p = toolResult.data.price_per_hour;
      allowedPrices.add(p);
      allowedPrices.add(p * (state.duration_hours || 1));
    }
    if (toolResult?.data?.total_amount) allowedPrices.add(toolResult.data.total_amount);
    if (toolResult?.data?.deposit_amount) allowedPrices.add(toolResult.data.deposit_amount);

    if (allowedPrices.size > 0) {
      for (const m of priceMatches) {
        const claimedPrice = Number(m[1]);
        if (!allowedPrices.has(claimedPrice)) {
          return {
            isValid: false,
            reason: `Claimed price (${claimedPrice}) does not match any verified price (${Array.from(allowedPrices).join(", ")})`,
          };
        }
      }
    }
  }

  // 4. Check for leaked internal terms
  const leakedInternals = /(?:قاعدة البيانات|السيستم|API|Supabase|Gemini|RPC|السيرفر|الأداة|tool)/i.test(response);
  if (leakedInternals) {
    return {
      isValid: false,
      reason: "Leaked internal technical terminology",
    };
  }

  return { isValid: true };
}

