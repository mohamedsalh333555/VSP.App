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
1. اعتمد 100% فقط على الحقائق الموثقة أدناه (VERIFIED FACTS). ممنوع نهائياً اختراع أي ملعب أو سعر أو موعد أو حجز أو معاملة دفع.
2. لا تذكر للمستخدم أي مصطلحات تقنية أو بنية داخلية: ممنوع منعاً باتاً "من بيانات VSP"، "قاعدة البيانات"، "السيستم"، "الأدوات"، أو "API". اعرض النتائج مباشرة كأنك تراها في التطبيق.
3. التزم باللغة العربية السليمة للعدد والمعدود: قل "لقيتلك ملعب واحد" (وليس "1 ملاعب")، قل "ملعبين"، قل "3 ملاعب".
4. استخدم لقب "يا كابتن" بحد أقصى مرة واحدة في أول الرد فقط، وبشكل عفوي غير متكلف.
5. لا تفترض أبداً أن السؤال عن الحجز يعني إنشاء حجز جديد. إذا كان المستخدم يسأل عن حجزه السابق أو القادم أو مشكلة دفع، أجب بناءً على الحقائق الفعلية.
6. إذا كان هناك حجز قادم، أذكر الملعب والميعاد والحالة بدقة.
7. في مشاكل الدفع، انقل التوضيح المعتمد من نتيجة التحقق دون اختراع نجاح دفع وهمي.

رسالة المستخدم الأصلية:
"${userMessage}"

خطة الإجراء (PLAN):
${JSON.stringify(plan, null, 2)}

الحقائق الموثقة (VERIFIED FACTS):
${JSON.stringify(verifiedFacts, null, 2)}

صِغ ردك النهائي بالعامية المصرية الودية الآن:`;
}

// Deterministic Safe Fallback Generator (if Gemini is unavailable or for operational contracts)
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
        const displayH = (h + 2) % 24; // Cairo local
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

    // Player Self-Service: User Bookings / Upcoming Booking
    if (toolResult.tool_name === "getUserBookingsAndRefunds") {
      if (toolResult.data.has_upcoming !== undefined) {
        // Upcoming booking query
        if (!toolResult.data.has_upcoming || !toolResult.data.booking) {
          return {
            message: "يا كابتن، مفيش أي حجز قادم مسجل بحسابك حالياً. تحب نحجزلك ماتش جديد في أقرب ملعب؟",
            quick_replies: ["عايز ملعب قريب", "البطولات المفتوحة"],
          };
        }
        const b = toolResult.data.booking;
        const statusLabel = b.status === "confirmed" ? "مؤكد ✅" : "قيد التأكيد ⏳";
        return {
          message: `حجزك القادم في ${b.stadium_name || "الملعب"} (${statusLabel}): يوم ${b.start_time ? b.start_time.substring(0, 10) : ""} بإجمالي ${b.total_price || 0} ج.م.`,
          quick_replies: ["تفاصيل الحجز", "عرض كل حجوزاتي"],
        };
      }

      // Recent Bookings list
      const list = toolResult.data.bookings || [];
      if (list.length === 0) {
        return {
          message: "يا كابتن، مفيش أي حجوزات مسجلة بحسابك حتى الآن. تحب أساعدك تختار ملعب قريب؟",
          quick_replies: ["عايز ملعب قريب", "البطولات المفتوحة"],
        };
      }

      const count = list.length;
      const countLabel = formatArabicCount(count, "حجز واحد", "حجزين", "حجوزات");
      const summaryItems = list.slice(0, 3).map((b: any, idx: number) => {
        const sName = b.stadium_name || "الملعب";
        const dStr = b.start_time ? b.start_time.substring(0, 10) : "";
        const st = b.status === "confirmed" ? "مؤكد ✅" : b.status === "cancelled" ? "ملغى ❌" : "قيد المعالجة ⏳";
        return `${idx + 1}. ${sName} (${dStr}) - ${st}`;
      }).join("\n");

      return {
        message: `يا كابتن، لقيتلك ${countLabel} في سجلك:\n${summaryItems}`,
        quick_replies: ["الحجز القادم", "فتح قائمة الحجوزات"],
      };
    }

    // Payment / Booking Reconciliation
    if (toolResult.tool_name === "reconcileBookingPayment") {
      const rec = toolResult.data;
      if (rec && rec.explanation) {
        return {
          message: rec.explanation,
          quick_replies: rec.reconciliation_state === "PAYMENT_CONFIRMED_BOOKING_CONFIRMED"
            ? ["عرض تذكرة الحجز", "حجوزاتي"]
            : ["التواصل مع الدعم", "حجوزاتي"],
        };
      }
      return {
        message: "تم فحص حالة المعاملة، يرجى مراجعة التفاصيل أدناه.",
        quick_replies: ["حجوزاتي", "الدعم الفني"],
      };
    }

    // Booking Cancellation
    if (toolResult.tool_name === "cancelUserBooking") {
      if (toolResult.data?.already_cancelled) {
        return {
          message: "الحجز ده ملغى بالفعل يا كابتن.",
          quick_replies: ["عرض حجوزاتي"],
        };
      }
      const refund = toolResult.data?.refund_amount || 0;
      const refundMsg = refund > 0 ? ` وجاري استرداد مبلغ ${refund} ج.م إلى وسيلة الدفع الخاصة بك.` : " دون أي رسوم إضافية.";
      return {
        message: `تم إلغاء الحجز في ${toolResult.data?.stadium_name || "الملعب"} بنجاح ✅${refundMsg}`,
        quick_replies: ["عرض حجوزاتي", "حجز ملعب تاني"],
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
        message: plan.reason || "تمام يا كابتن. تحب تحجز في أنهي ملعب؟",
        quick_replies: plan.quick_replies || [],
      };
    }
    if (plan.missing_slot === "date") {
      return {
        message: plan.reason || "تمام، طلبك اتسجل. تحب الحجز يكون النهارده ولا بكرة؟",
        quick_replies: plan.quick_replies || ["النهارده", "بكرة"],
      };
    }
    if (plan.missing_slot === "time") {
      return {
        message: plan.reason || "تحب نحجز الساعة كام يا كابتن؟",
        quick_replies: plan.quick_replies || ["8 بالليل", "9 بالليل", "10 بالليل"],
      };
    }
    if (plan.missing_slot === "time_period") {
      const targetTime = state.times[0]?.time || "10:00";
      const h = Number(targetTime.split(":")[0]);
      const displayH = h > 12 ? h - 12 : h;
      const stadiumName = state.stadium.name ? ` في ${state.stadium.name}` : "";
      return {
        message: plan.reason || `عايز تحجز${stadiumName} الساعة ${displayH} بالليل، مظبوط كده؟`,
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
      message: "يا كابتن، أنا في خدمتك. تحب أساعدك في حجز ملعب، استعراض حجوزاتك، أو استكشاف البطولات؟",
      quick_replies: ["حجوزاتي", "عايز ملعب قريب", "البطولات المفتوحة"],
    };
  }

  // Safe Operational Fallback: Never return sticky welcome greeting for failed understanding
  return {
    message: "يا كابتن، أنا في خدمتك. تحب أساعدك في حجز ملعب، متابعة حجوزاتك السابقة، أو استكشاف البطولات وماتشات التقسيمة؟",
    quick_replies: ["حجوزاتي", "عايز ملعب قريب", "البطولات المفتوحة"],
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

  // 2. Check for fabricated booking cancellation claims
  const claimsBookingCancelled = /(?:تم إلغاء الحجز|لغيتلك الحجز|تم الإلغاء بنجاح)/i.test(response);
  if (claimsBookingCancelled) {
    const actuallyCancelled = toolResult && toolResult.tool_name === "cancelUserBooking" && toolResult.status === "SUCCESS";
    if (!actuallyCancelled) {
      return {
        isValid: false,
        reason: "Fabricated cancellation claim without verified cancelUserBooking SUCCESS result",
      };
    }
  }

  // 3. Check for false payment confirmation claims
  const claimsPaymentConfirmed = /(?:تم تأكيد الدفع|الحجز اتأكد بعد الدفع|عملية الدفع مؤكدة|تم سداد الحجز)/i.test(response);
  if (claimsPaymentConfirmed) {
    if (toolResult?.tool_name === "reconcileBookingPayment") {
      const recState = toolResult.data?.reconciliation_state;
      if (recState !== "PAYMENT_CONFIRMED_BOOKING_CONFIRMED") {
        return {
          isValid: false,
          reason: `Claimed payment confirmed when reconciliation state is actually ${recState}`,
        };
      }
    }
  }

  // 4. Check for false availability claims when an error occurred
  const claimsUnavailable = /(?:الملعب غير متاح|مفيش مواعيد|غير متوفر|مفيش فترات فاضية)/i.test(response);
  if (claimsUnavailable && toolResult) {
    if (toolResult.status === "TEMPORARY_ERROR" || toolResult.status === "DATA_ERROR" || toolResult.status === "AUTH_ERROR") {
      return {
        isValid: false,
        reason: "Reported stadium as unavailable when the actual result was a technical error",
      };
    }
  }

  // 5. Check for price fabrication in EGP
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
    if (toolResult?.bookings) {
      for (const b of toolResult.bookings) {
        if (b.total_price) allowedPrices.add(b.total_price);
        if (b.price) allowedPrices.add(b.price);
      }
    }
    if (toolResult?.data?.amount) allowedPrices.add(toolResult.data.amount);
    if (toolResult?.data?.refund_amount) allowedPrices.add(toolResult.data.refund_amount);
    if (toolResult?.data?.price_per_hour) {
      const p = toolResult.data.price_per_hour;
      allowedPrices.add(p);
      allowedPrices.add(p * (state.duration_hours || 1));
    }
    if (toolResult?.data?.total_amount) allowedPrices.add(toolResult.data.total_amount);
    if (toolResult?.data?.deposit_amount) allowedPrices.add(toolResult.data.deposit_amount);
    if (toolResult?.data?.transaction?.amount) allowedPrices.add(toolResult.data.transaction.amount);

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

  // 6. Check for leaked internal terms
  const leakedInternals = /(?:قاعدة البيانات|السيستم|API|Supabase|Gemini|RPC|السيرفر|الأداة|tool)/i.test(response);
  if (leakedInternals) {
    return {
      isValid: false,
      reason: "Leaked internal technical terminology",
    };
  }

  return { isValid: true };
}
