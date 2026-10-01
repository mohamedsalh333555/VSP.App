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

  const isOwnerDataTool =
    toolResult?.tool_name === "getOwnerFinancialInsights" ||
    toolResult?.tool_name === "getOwnerStadiumsAndBookings" ||
    toolResult?.tool_name === "getOwnerOperationalInsights";

  const proactiveSection = isOwnerDataTool && toolResult?.data
    ? `

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
مهمة إضافية — الذكاء الاستباقي:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
أنت شايف البيانات الكاملة لملعب صاحب الملعب ده:

${JSON.stringify(toolResult.data, null, 2)}

بعد ما تجاوب على سؤاله مباشرة، افحص الأرقام دي بعين خبير تشغيل ملاعب.
لو لاحظت حاجة واحدة فعلاً تستحق انتباهه — سواء:
- رقم يلفت النظر (أعلى أو أقل من المتوقع)
- فرصة بتعدي من غير ما يحس
- مشكلة ممكن تتعمل أكبر لو ما انتبهلهاش

أضف سطر فراغ واحد بعد ردك الأساسي، ثم جملة واحدة بس تفتح الموضوع.
لا تسأل أكتر من سؤال واحد.
لو مفيش حاجة فعلاً تستحق — متضيفش حاجة خالص. الصمت أحسن من الكلام الزيادة.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`
    : "";

  return `أنت "كابتن VSP"، المستشار الذكي لإدارة وتشغيل الملاعب لأصحاب ومسؤولي الملاعب في منصة VSP الرياضية بمصر.
مهمتك صياغة رد نهائي ذكي وطبيعي ومختصر باللهجة المصرية الودودة.

قواعد الصياغة الصارمة (STRICT RULES):
1. اعتمد 100% فقط على الحقائق الموثقة أدناه (VERIFIED FACTS). ممنوع نهائياً اختراع أي ملعب أو سعر أو موعد أو حجز أو معاملة دفع.
2. لا تذكر للمستخدم أي مصطلحات تقنية أو بنية داخلية: ممنوع منعاً باتاً "من بيانات VSP"، "قاعدة البيانات"، "السيستم"، "الأدوات"، أو "API". اعرض النتائج مباشرة كأنك تراها في التطبيق.
3. التزم باللغة العربية السليمة للعدد والمعدود: قل "لقيتلك ملعب واحد" (وليس "1 ملاعب")، قل "ملعبين"، قل "3 ملاعب".
4. استخدم لقب "يا كابتن" بحد أقصى مرة واحدة في أول الرد فقط، وبشكل عفوي غير متكلف.
5. لا تفترض أبداً أن السؤال عن الحجز يعني إنشاء حجز جديد. إذا كان المستخدم يسأل عن حجزه السابق أو القادم أو مشكلة دفع، أجب بناءً على الحقائق الفعلية.
6. إذا كان هناك حجز قادم، أذكر الملعب والميعاد والحالة بدقة.
7. في مشاكل الدفع، انقل التوضيح المعتمد من نتيجة التحقق دون اختراع نجاح دفع وهمي.
${proactiveSection}
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
  // 1. Tool result responses (Owner tools only)
  if (toolResult) {
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
        message: plan.reason || "تمام يا كابتن. تحب نراجع جدول أنهي ملعب فيهم؟",
        quick_replies: plan.quick_replies || [],
      };
    }
    if (plan.missing_slot === "date") {
      return {
        message: plan.reason || "تمام، تحب تتابع المواعيد ليوم النهارده ولا بكرة؟",
        quick_replies: plan.quick_replies || ["النهارده", "بكرة"],
      };
    }
    if (plan.missing_slot === "time") {
      return {
        message: plan.reason || "تحب تفحص الساعة كام يا كابتن؟",
        quick_replies: plan.quick_replies || ["8 بالليل", "9 بالليل", "10 بالليل"],
      };
    }
    if (plan.missing_slot === "time_period") {
      const targetTime = state.times[0]?.time || "10:00";
      const h = Number(targetTime.split(":")[0]);
      const displayH = h > 12 ? h - 12 : h;
      const stadiumName = state.stadium.name ? ` في ${state.stadium.name}` : "";
      return {
        message: plan.reason || `تقصد${stadiumName} الساعة ${displayH} بالليل، مظبوط كده؟`,
        quick_replies: ["أيوه بالليل", "الصبح"],
      };
    }
  }

  if (plan.action === "SAFE_DEGRADED_CLARIFICATION") {
    return {
      message: plan.reason || "يا كابتن، في ضغط لحظي مؤقت على خدمة الذكاء الاصطناعي وما قدرتش أستوعب رسالتك الأخيرة بدقة. بياناتك ومواعيدك السابقة محفوظة بأمان، تقدر تختار الخطوة التالية من الخيارات بالأسفل:",
      quick_replies: plan.quick_replies || ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي", "السجل المالي"],
    };
  }

  if (plan.action === "CLARIFY_AMBIGUITY") {
    return {
      message: plan.reason || "محتاج توضيح بسيط عشان أساعدك بدقة يا كابتن:",
      quick_replies: plan.quick_replies || ["جدول ملاعبي", "المواعيد الفاضية"],
    };
  }

  if (plan.action === "RESPOND_DIRECTLY") {
    if (plan.reason) {
      return {
        message: plan.reason,
        quick_replies: plan.quick_replies || ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي", "السجل المالي"],
      };
    }
    return {
      message: "أهلاً بك يا كابتن! أنا «كابتن VSP»، المستشار الذكي لإدارة ملاعبك ومتابعة الحجوزات والماليات. تحب نتابع جدول الحجوزات، نشيك على الفترات الفاضية، ولا نستعرض أرباحك؟ ⚽📊",
      quick_replies: ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي", "السجل المالي"],
    };
  }

  // Safe Operational Fallback: Strictly Pitch Owner Advisor
  return {
    message: "أهلاً بك يا كابتن! أنا «كابتن VSP»، المستشار الذكي لإدارة ملاعبك ومتابعة الحجوزات والماليات. تحب نتابع جدول الحجوزات، نشيك على الفترات الفاضية، ولا نستعرض أرباحك؟ ⚽📊",
    quick_replies: ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي", "السجل المالي"],
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
    // Owner financial summary metrics
    if (toolResult?.data?.available_balance !== undefined) allowedPrices.add(Number(toolResult.data.available_balance));
    if (toolResult?.data?.total_revenue !== undefined) allowedPrices.add(Number(toolResult.data.total_revenue));
    if (toolResult?.data?.pending_balance !== undefined) allowedPrices.add(Number(toolResult.data.pending_balance));
    if (toolResult?.data?.total_withdrawn !== undefined) allowedPrices.add(Number(toolResult.data.total_withdrawn));

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

  // 6. Strict Operational Count Validation: Decouple stadiums_count from bookings_count completely
  // 6a. Bookings Count Validation
  const bookingCountMatches = [...response.matchAll(/(\d{1,4})\s*(?:حجز|حجوزات|ماتش|ماتشات)/gi)];
  const allowedBookingCounts = new Set<number>();
  if (toolResult?.bookings && Array.isArray(toolResult.bookings)) {
    allowedBookingCounts.add(toolResult.bookings.length);
  }
  if (toolResult?.data?.bookings && Array.isArray(toolResult.data.bookings)) {
    allowedBookingCounts.add(toolResult.data.bookings.length);
  }
  if (typeof toolResult?.data?.bookings_count === "number") {
    allowedBookingCounts.add(toolResult.data.bookings_count);
  }
  if (typeof toolResult?.data?.total_bookings === "number") {
    allowedBookingCounts.add(toolResult.data.total_bookings);
  }

  if (bookingCountMatches.length > 0 && allowedBookingCounts.size > 0) {
    for (const cm of bookingCountMatches) {
      const claimedCount = Number(cm[1]);
      if (!allowedBookingCounts.has(claimedCount)) {
        return {
          isValid: false,
          reason: `Claimed booking count (${claimedCount}) does not match verified count (${Array.from(allowedBookingCounts).join(", ")})`,
        };
      }
    }
  }

  // 6b. Stadiums Count Validation
  const stadiumCountMatches = [...response.matchAll(/(\d{1,4})\s*(?:ملعب|ملاعب)/gi)];
  const allowedStadiumCounts = new Set<number>();
  if (toolResult?.stadiums && Array.isArray(toolResult.stadiums)) {
    allowedStadiumCounts.add(toolResult.stadiums.length);
  }
  if (toolResult?.data?.stadiums && Array.isArray(toolResult.data.stadiums)) {
    allowedStadiumCounts.add(toolResult.data.stadiums.length);
  }
  if (typeof toolResult?.data?.stadiums_count === "number") {
    allowedStadiumCounts.add(toolResult.data.stadiums_count);
  }
  if (typeof toolResult?.data?.total_stadiums === "number") {
    allowedStadiumCounts.add(toolResult.data.total_stadiums);
  }

  if (stadiumCountMatches.length > 0 && allowedStadiumCounts.size > 0) {
    for (const sm of stadiumCountMatches) {
      const claimedStadiums = Number(sm[1]);
      if (!allowedStadiumCounts.has(claimedStadiums)) {
        return {
          isValid: false,
          reason: `Claimed stadium count (${claimedStadiums}) does not match verified count (${Array.from(allowedStadiumCounts).join(", ")})`,
        };
      }
    }
  }

  // 6c. Completed Bookings Count Validation
  const completedMatches = [...response.matchAll(/(\d{1,4})\s*(?:حجز\s+مكتمل|حجوزات\s+مكتملة|حجز\s+منتهي|حجوزات\s+منتهية)/gi)];
  const allowedCompletedCounts = new Set<number>();
  if (typeof toolResult?.data?.completed_bookings_count === "number") {
    allowedCompletedCounts.add(toolResult.data.completed_bookings_count);
  }
  if (toolResult?.bookings && Array.isArray(toolResult.bookings)) {
    const completed = toolResult.bookings.filter((b: any) => b.status === "completed" || b.status === "confirmed").length;
    allowedCompletedCounts.add(completed);
  }

  if (completedMatches.length > 0 && allowedCompletedCounts.size > 0) {
    for (const cm of completedMatches) {
      const claimedCompleted = Number(cm[1]);
      if (!allowedCompletedCounts.has(claimedCompleted)) {
        return {
          isValid: false,
          reason: `Claimed completed booking count (${claimedCompleted}) does not match verified count (${Array.from(allowedCompletedCounts).join(", ")})`,
        };
      }
    }
  }

  // 7. Check for leaked internal terms
  const leakedInternals = /(?:قاعدة البيانات|السيستم|API|Supabase|Gemini|RPC|السيرفر|الأداة|tool)/i.test(response);
  if (leakedInternals) {
    return {
      isValid: false,
      reason: "Leaked internal technical terminology",
    };
  }

  return { isValid: true };
}
