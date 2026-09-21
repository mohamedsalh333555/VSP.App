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

  if (plan.action === "CLARIFY_AMBIGUITY") {
    return {
      message: plan.reason || "محتاج توضيح بسيط عشان أنفذ طلبك بدقة يا كابتن:",
      quick_replies: plan.quick_replies || [],
    };
  }

  return {
    message: "أهلاً بيك يا كابتن! أنا جاهز أساعدك في حجز الملاعب، استكشاف البطولات، وماتشات التقسيمة. تحب تبدأ بإيه؟",
    quick_replies: ["عايز ملعب قريب", "البطولات المفتوحة", "ترتيب الحريفة 1v1"],
  };
}
