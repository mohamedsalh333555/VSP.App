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
  description: "بحث واستكشاف الملاعب الرياضية المتاحة في مصر بالاسم أو المنطقة أو السعر أو المواعيد. استدعِ هذه الأداة فوراً عندما يسأل المستخدم عن ملعب باسمه أو بالمنطقة أو أسعار الحجز.",
  parameters: {
    type: "OBJECT",
    properties: {
      query: {
        type: "STRING",
        description: "اسم الملعب المطلوب أو جزء منه (مثال: 'صدقة جديدة'، 'الصداقة'، 'ملعب الصداقة')",
      },
      governorate: {
        type: "STRING",
        description: "المحافظة أو المنطقة المراد البحث فيها (مثل: أسوان، القاهرة، الجيزة، المعادي، مدينة نصر)",
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
  description: "البحث عن مباريات وحجوزات خماسية مفتوحة ناقصها لاعيبة للانضمام فوراً واللعب (Open Join Matches). استدعِ هذه الأداة فوراً كلما سأل المستخدم عن ماتش ناقصه لاعيبة أو تقسيمة مفتوحة، أو عندما يقول 'ناقصنا جون' أو 'ناقصنا حارس' للبحث عن ماتشات محتاجة حارس مرمى.",
  parameters: {
    type: "OBJECT",
    properties: {
      governorate: {
        type: "STRING",
        description: "المحافظة أو المنطقة (اختياري)",
      },
      required_position: {
        type: "STRING",
        description: "المركز المطلوب إن وجد (مثل: 'goalkeeper' أو 'حارس مرمى' أو 'مهاجم')",
      },
      date: {
        type: "STRING",
        description: "تاريخ الماتش المطلوب (اختياري)",
      },
    },
  },
};

// 5. Tool: executeAppAction
const executeAppActionTool = {
  name: "executeAppAction",
  description: "توجيه المستخدم لشاشة داخل التطبيق عند طلبه صراحة التنقل (مثال: 'وديني لفريقي'، 'افتح الإعدادات'، 'وريني البروفايل'). تحذير: ممنوع استدعاء هذه الأداة لتوجيهه لحجز ملعب عندما يطلب حجز ملعب أو موعد محدد!",
  parameters: {
    type: "OBJECT",
    properties: {
      action_type: {
        type: "STRING",
        description: "نوع الإجراء: دائماً 'NAVIGATE'",
      },
      route: {
        type: "STRING",
        description: "المسار داخل التطبيق: '/tournaments' للبطولات، '/1v1' لدوري 1v1، '/my-team' لإدارة فريقي، '/profile' للبروفايل، '/settings' للإعدادات",
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

// 8. Tool: getOwnerStadiumsAndBookings
const getOwnerStadiumsAndBookingsTool = {
  name: "getOwnerStadiumsAndBookings",
  description: "عرض واستعلام ملاعب مالك الملعب المسجلة باسمه في VSP، وحجوزات ملاعبه الحالية أو القادمة، والتحقق من مواعيد اللعب وتفاصيل اللاعبين. استدعِ هذه الأداة فوراً عندما يسأل مالك الملعب عن ملاعبه، أو حجوزات ملعبه، أو مواعيد الحجز، أو التحصيل.",
  parameters: {
    type: "OBJECT",
    properties: {
      query_type: {
        type: "STRING",
        description: "نوع الاستعلام: 'stadiums' لملاعبه المسجلة، 'bookings' لحجوزات ملاعبه، 'today' لحجوزات اليوم فقط، 'all' للكل",
      },
      status: {
        type: "STRING",
        description: "حالة الحجز للفلترة: 'pending' للمعلقة، 'confirmed' للمؤكدة، 'all' للكل",
      },
    },
  },
};

// 9. Tool: getOwnerFinancialInsights
const getOwnerFinancialInsightsTool = {
  name: "getOwnerFinancialInsights",
  description: "استعلام السجل المالي لمالك الملعب، والرصيد الإلكتروني القابل للسحب، والإيرادات النقدية (كاش) المحصلة، ومديونية المنصة، وعدد الحجوزات المكتملة مباشرة من قاعدة البيانات. استدعِ هذه الأداة فوراً عندما يسأل مالك الملعب عن أرباحه، رصيده، إيراداته، فلوسه، أو مديونية الكاش.",
  parameters: {
    type: "OBJECT",
    properties: {
      period: {
        type: "STRING",
        description: "الفترة: 'all' للإجمالي، أو 'current' للرصيد الحالي",
      },
    },
  },
};

// 10. Tool: checkStadiumAvailability
const checkStadiumAvailabilityTool = {
  name: "checkStadiumAvailability",
  description: "فحص مواعيد وتوافر الملعب والتحقق من الفترات والساعات المتاحة والشاغرة للحجز بتاريخ وتوقيت محدد، وتجنب الحجوزات المتضاربة من قاعدة البيانات الحقيقية. استدعِ هذه الأداة عندما يسأل المستخدم عن موعد شاغر أو توفر ملعب أو جدول مواعيد.",
  parameters: {
    type: "OBJECT",
    properties: {
      stadium_id: {
        type: "STRING",
        description: "معرف الملعب (UUID) إن وجد",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم الملعب المطلوب فحص مواعيده (مثل: 'الصداقة الجديدة'، 'صدقة جديدة')",
      },
      date: {
        type: "STRING",
        description: "التاريخ المطلوب (مثل: YYYY-MM-DD أو 'غداً' أو 'اليوم' - اختياري)",
      },
      time_preference: {
        type: "STRING",
        description: "التوقيت المفضل (مثل: 'صباحاً'، 'مساءً'، 'الساعة 8 مساءً'، '12 في منتصف الليل')",
      },
    },
  },
};

// 11. Tool: createBookingFromChat
const createBookingFromChatTool = {
  name: "createBookingFromChat",
  description: "بدء إجراءات حجز الملعب مباشرة وقفل الموعد ذرياً (Atomic Lock) من داخل المحادثة بناءً على طلب المستخدم. تفحص ما إذا كان الملعب يتطلب عربون إلكتروني مسبقاً (needs_deposit) أم يقبل الدفع كاش كاملاً، وتقفل الموعد ذرياً لمدة 5 دقائق وتنشئ زر الدفع المباشر أو تأكيد الحجز. استدعِ هذه الأداة فوراً عندما يطلب المستخدم حجز ملعب أو يحدد موعداً يريد حجزه (مثل: 'اريد ان احجز في الساعه 12 في منتصف الليل في الملعب صدقه جديده' أو 'احجزلي ميعاد الساعه 8').",
  parameters: {
    type: "OBJECT",
    properties: {
      stadium_id: {
        type: "STRING",
        description: "معرف الملعب (UUID) إن وجد",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم الملعب المطلوب حجزه (مثل: 'الصداقة الجديدة'، 'صدقة جديدة')",
      },
      date: {
        type: "STRING",
        description: "التاريخ المطلوب للحجز (مثل: 'اليوم'، 'غداً'، 'بكرة' أو YYYY-MM-DD)",
      },
      time: {
        type: "STRING",
        description: "الساعة أو التوقيت المطلوب للحجز (مثل: '12 في منتصف الليل'، '12 بالليل'، 'الساعة 8 مساءً')",
      },
      start_time: {
        type: "STRING",
        description: "وقت بداية الحجز بصيغة ISO 8601 (اختياري)",
      },
      end_time: {
        type: "STRING",
        description: "وقت نهاية الحجز بصيغة ISO 8601 (اختياري)",
      },
      payment_method: {
        type: "STRING",
        description: "طريقة الدفع: 'online' أو 'cash'",
      },
      rent_ball: {
        type: "BOOLEAN",
        description: "هل يرغب المستخدم في استئجار كرة مع الحجز (إذا ذكر 'عايز كورة' أو 'مع كورة')",
      },
      fallback_slots: {
        type: "ARRAY",
        items: { type: "STRING" },
        description: "المواعيد البديلة إن تعذر الموعد الأساسي (مثال: ['21:00'] عند قوله 'لو مفيش 8 خليه 9')",
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
  getOwnerStadiumsAndBookingsTool,
  getOwnerFinancialInsightsTool,
  checkStadiumAvailabilityTool,
  createBookingFromChatTool,
];

// ==========================================
// 🧠 Arabic Normalization & Fuzzy Search Engine
// ==========================================

function normalizeArabic(text: string): string {
  if (!text) return "";
  return text
    .toLowerCase()
    .replace(/[\u064B-\u065F\u0670]/g, "") // strip diacritics / tashkeel
    .replace(/[أإآآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/ؤ/g, "و")
    .replace(/ئ/g, "ي")
    .replace(/گ/g, "ك")
    .replace(/پ/g, "ب")
    .replace(/ژ/g, "ز")
    .replace(/چ/g, "ج")
    .replace(/\s+/g, " ")
    .trim();
}

function stripArabicPrefixes(word: string): string {
  if (word.startsWith("ال") && word.length > 3) {
    return word.substring(2);
  }
  return word;
}

function tokenizeArabic(text: string): string[] {
  return normalizeArabic(text)
    .split(/[\s,.\-_/]+/)
    .map((w) => stripArabicPrefixes(w))
    .filter(
      (w) =>
        w.length > 1 &&
        !["ملعب", "استاد", "في", "على", "من", "الى", "إلى", "عايز", "عاوز", "اريد", "حجز", "احجز"].includes(w)
    );
}

function stringSimilarity(a: string, b: string): number {
  if (a === b) return 1.0;
  if (!a || !b) return 0.0;
  const longer = a.length > b.length ? a : b;
  const shorter = a.length > b.length ? b : a;
  if (longer.length === 0) return 1.0;

  const costs: number[] = [];
  for (let i = 0; i <= longer.length; i++) {
    let lastValue = i;
    for (let j = 0; j <= shorter.length; j++) {
      if (i === 0) {
        costs[j] = j;
      } else if (j > 0) {
        let newValue = costs[j - 1];
        if (longer.charAt(i - 1) !== shorter.charAt(j - 1)) {
          newValue = Math.min(Math.min(newValue, lastValue), costs[j]) + 1;
        }
        costs[j - 1] = lastValue;
        lastValue = newValue;
      }
    }
    if (i > 0) costs[shorter.length] = lastValue;
  }
  return (longer.length - costs[shorter.length]) / longer.length;
}

async function findMatchingStadium(
  supabase: any,
  queryName?: string,
  stadiumId?: string,
  userGov?: string
): Promise<any> {
  // 1. Explicit valid UUID provided
  if (stadiumId && /^[0-9a-fA-F-]{36}$/.test(stadiumId)) {
    const { data: s } = await supabase
      .from("stadiums")
      .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id, image_url, opening_time, closing_time, is_split_shift, break_start_time, break_end_time, rating")
      .eq("id", stadiumId)
      .maybeSingle();
    if (s) return s;
  }

  // 2. Fetch all verified active stadiums to do fuzzy scoring
  const { data: stadiums } = await supabase
    .from("stadiums")
    .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id, image_url, opening_time, closing_time, is_split_shift, break_start_time, break_end_time, rating")
    .eq("is_verified", true)
    .eq("is_blocked", false)
    .eq("is_deleted_by_owner", false);

  if (!stadiums || stadiums.length === 0) return null;
  if (stadiums.length === 1) return stadiums[0];

  if (!queryName || queryName.trim().length === 0) {
    if (userGov) {
      const inGov = stadiums.filter((s: any) => {
        const normGov = normalizeArabic(s.governorate);
        const normUserGov = normalizeArabic(userGov);
        return normGov.includes(normUserGov) || normUserGov.includes(normGov);
      });
      if (inGov.length > 0) return inGov[0];
    }
    return stadiums[0];
  }

  const queryTokens = tokenizeArabic(queryName);
  const scoredStadiums: { stadium: any; score: number }[] = [];

  for (const s of stadiums) {
    const sTokens = tokenizeArabic(s.name);
    let score = 0;

    const normQuery = normalizeArabic(queryName);
    const normName = normalizeArabic(s.name);
    if (normName.includes(normQuery) || normQuery.includes(normName)) {
      score += 60;
    }

    for (const qToken of queryTokens) {
      for (const sToken of sTokens) {
        if (qToken === sToken) {
          score += 40;
        } else if (qToken.length >= 3 && (sToken.includes(qToken) || qToken.includes(sToken))) {
          score += 25;
        } else {
          const sim = stringSimilarity(qToken, sToken);
          if (sim >= 0.70) {
            score += Math.round(sim * 30);
          }
        }
      }
    }

    if (userGov) {
      const normGov = normalizeArabic(s.governorate);
      const normUserGov = normalizeArabic(userGov);
      if (normGov.includes(normUserGov) || normUserGov.includes(normGov)) {
        score += 15;
      }
    }

    scoredStadiums.push({ stadium: s, score });
  }

  scoredStadiums.sort((a, b) => b.score - a.score);
  const top1 = scoredStadiums[0];
  const top2 = scoredStadiums.length > 1 ? scoredStadiums[1] : null;

  // Rule from section 15: No auto-booking when top 2 stadiums are ambiguous
  if (top1 && top2 && (top1.score - top2.score <= 15) && top1.score >= 35 && top2.score >= 35) {
    const resultStadium = { ...top1.stadium };
    resultStadium.is_ambiguous = true;
    resultStadium.candidates = [
      { id: top1.stadium.id, label: top1.stadium.name },
      { id: top2.stadium.id, label: top2.stadium.name },
    ];
    return resultStadium;
  }

  return top1 && top1.score > 10 ? top1.stadium : stadiums[0];
}

// ==========================================
// ⏰ Egyptian Temporal Engine (TemporalResolver)
// ==========================================

interface ClarificationOption {
  id: string;
  label: string;
}

interface Clarification {
  type: string;
  question: string;
  options: ClarificationOption[];
}

interface TemporalResult {
  startTimeIso: string;
  endTimeIso: string;
  displayTime: string;
  cairoHour: number;
  targetDateStr: string;
  operationalDateStr: string;
  clarification?: Clarification | null;
  preferredSlots?: string[];
}

class TemporalResolver {
  static getCairoNow(referenceNow: Date = new Date()): {
    year: number;
    month: number;
    day: number;
    hour: number;
    minute: number;
    dayOfWeek: number;
    offsetStr: string;
  } {
    const cairoFormatter = new Intl.DateTimeFormat("en-US", {
      timeZone: "Africa/Cairo",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      weekday: "short",
      hour12: false,
    });
    const parts = cairoFormatter.formatToParts(referenceNow);
    const getPart = (t: string) => parts.find((p) => p.type === t)?.value || "0";

    const year = Number(getPart("year"));
    const month = Number(getPart("month"));
    const day = Number(getPart("day"));
    const hour = Number(getPart("hour"));
    const minute = Number(getPart("minute"));

    const cairoLocal = new Date(referenceNow.toLocaleString("en-US", { timeZone: "Africa/Cairo" }));
    const utcLocal = new Date(referenceNow.toLocaleString("en-US", { timeZone: "UTC" }));
    const offsetHours = Math.round((cairoLocal.getTime() - utcLocal.getTime()) / (3600 * 1000));
    const offsetSign = offsetHours >= 0 ? "+" : "-";
    const offsetStr = `${offsetSign}${String(Math.abs(offsetHours)).padStart(2, "0")}:00`;

    const weekdayMap: Record<string, number> = {
      Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
    };
    const dayOfWeek = weekdayMap[getPart("weekday")] ?? referenceNow.getDay();

    return { year, month, day, hour, minute, dayOfWeek, offsetStr };
  }

  static resolve(input: string, referenceNow: Date = new Date()): TemporalResult {
    const text = input.toLowerCase();
    const cairo = this.getCairoNow(referenceNow);

    let dayOffset = 0;
    let targetDayDate: Date | null = null;
    let clarification: Clarification | null = null;

    // 1. Relative Dates (Check longest expressions first!)
    if (
      text.includes("بعد بعد بكره") ||
      text.includes("بعد ٣ ايام") ||
      text.includes("بعد 3 ايام") ||
      text.includes("بعد ثلاثة ايام")
    ) {
      dayOffset = 3;
    } else if (text.includes("بعد بكره") || text.includes("بعد غد") || text.includes("بعد يومين")) {
      dayOffset = 2;
    } else if (
      text.includes("بكره") ||
      text.includes("غدا") ||
      text.includes("غداً") ||
      text.includes("tomorrow")
    ) {
      dayOffset = 1;
    } else if (text.includes("النهارده") || text.includes("اليوم") || text.includes("today")) {
      dayOffset = 0;
    } else {
      // 2. Weekdays matching
      const weekdayNames: { name: string; dayIndex: number; arabicName: string }[] = [
        { name: "الجمعة", dayIndex: 5, arabicName: "الجمعة" },
        { name: "الجمعه", dayIndex: 5, arabicName: "الجمعة" },
        { name: "الخميس", dayIndex: 4, arabicName: "الخميس" },
        { name: "الاربعاء", dayIndex: 3, arabicName: "الأربعاء" },
        { name: "الأربعاء", dayIndex: 3, arabicName: "الأربعاء" },
        { name: "الاربع", dayIndex: 3, arabicName: "الأربعاء" },
        { name: "الثلاثاء", dayIndex: 2, arabicName: "الثلاثاء" },
        { name: "التلات", dayIndex: 2, arabicName: "الثلاثاء" },
        { name: "الاثنين", dayIndex: 1, arabicName: "الإثنين" },
        { name: "الإثنين", dayIndex: 1, arabicName: "الإثنين" },
        { name: "الاتنين", dayIndex: 1, arabicName: "الإثنين" },
        { name: "الاحد", dayIndex: 0, arabicName: "الأحد" },
        { name: "الأحد", dayIndex: 0, arabicName: "الأحد" },
        { name: "السبت", dayIndex: 6, arabicName: "السبت" },
      ];

      const foundWeekday = weekdayNames.find((w) => text.includes(w.name));
      if (foundWeekday) {
        const isNextMentioned =
          text.includes("الجاي") ||
          text.includes("القادم") ||
          text.includes("اللي جاي") ||
          text.includes("اللي بعده");

        const targetDay = foundWeekday.dayIndex;
        let diff = (targetDay - cairo.dayOfWeek + 7) % 7;
        if (diff === 0) diff = 7;

        // Ambiguity Rule (Section 6):
        // If the day is close (diff <= 2) and user said "الجمعة الجاية" or similar:
        // Do NOT guess! Generate clarification chips for this week vs next week!
        if (isNextMentioned && diff <= 2) {
          const dateOption1 = new Date(Date.UTC(cairo.year, cairo.month - 1, cairo.day + diff, 12, 0, 0));
          const dateOption2 = new Date(Date.UTC(cairo.year, cairo.month - 1, cairo.day + diff + 7, 12, 0, 0));

          const fmtDate = (d: Date) => {
            const mNames = [
              "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
              "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
            ];
            return `${foundWeekday.arabicName} ${d.getUTCDate()} ${mNames[d.getUTCMonth()]}`;
          };

          const toIsoDate = (d: Date) => {
            return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
          };

          clarification = {
            type: "date",
            question: `تقصد أنهي ${foundWeekday.arabicName} يا كابتن؟`,
            options: [
              { id: toIsoDate(dateOption1), label: fmtDate(dateOption1) },
              { id: toIsoDate(dateOption2), label: fmtDate(dateOption2) },
            ],
          };
          dayOffset = diff;
        } else {
          dayOffset = isNextMentioned && diff === 0 ? 7 : diff;
        }
      } else {
        const dateMatch = text.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
        if (dateMatch) {
          const y = Number(dateMatch[1]);
          const m = Number(dateMatch[2]);
          const d = Number(dateMatch[3]);
          targetDayDate = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
        }
      }
    }

    if (!targetDayDate) {
      targetDayDate = new Date(Date.UTC(cairo.year, cairo.month - 1, cairo.day + dayOffset, 12, 0, 0));
    }

    const opYyyy = targetDayDate.getUTCFullYear();
    const opMm = String(targetDayDate.getUTCMonth() + 1).padStart(2, "0");
    const opDd = String(targetDayDate.getUTCDate()).padStart(2, "0");
    const operationalDateStr = `${opYyyy}-${opMm}-${opDd}`;

    let targetCairoHour = 20; // Default 8 PM
    let preferredSlots: string[] = [];

    // Fallback detection: "لو مفيش 8 خليه 9"
    const fallbackMatch = text.match(/لو\s+(?:مش|مفيش)\s+(\d{1,2})\s+(?:خليه|خلّيه|يبقى|خليه ميعاد)\s+(\d{1,2})/);
    if (fallbackMatch) {
      let h1 = parseInt(fallbackMatch[1], 10);
      let h2 = parseInt(fallbackMatch[2], 10);
      if (h1 <= 11 && h1 >= 1) h1 += 12;
      if (h2 <= 11 && h2 >= 1) h2 += 12;
      preferredSlots = [
        `${String(h1).padStart(2, "0")}:00`,
        `${String(h2).padStart(2, "0")}:00`,
      ];
      targetCairoHour = h1;
    }

    const isTwelveMentioned =
      text.includes("منتصف الليل") ||
      text.includes("منتصف ليل") ||
      text.includes("نص الليل") ||
      text.includes("نص ليل") ||
      text.includes("12 بالليل") ||
      text.includes("12 بليل") ||
      text.includes("١٢ بالليل") ||
      text.includes("١٢ بليل") ||
      text.includes("12 am") ||
      text.includes("12am") ||
      text.includes("12 pm") ||
      text.includes("12pm") ||
      text.includes("الساعة 12") ||
      text.includes("الساعه 12") ||
      text.includes("الساعة ١٢") ||
      text.includes("الساعه ١٢");

    const isExplicitNoon =
      text.includes("صبح") ||
      text.includes("الصبح") ||
      text.includes("صباحا") ||
      text.includes("صباحاً") ||
      text.includes("ضهر") ||
      text.includes("الظهر") ||
      text.includes("ظهرا") ||
      text.includes("ظهراً") ||
      text.includes("نهار") ||
      text.includes("النهار") ||
      text.includes("pm");

    const isLateNightHour =
      text.includes("1 بالليل") || text.includes("1 بليل") || text.includes("١ بليل") || text.includes("١ بالليل") || text.includes("واحدة بالليل") || text.includes("واحده بليل")
        ? 1
        : text.includes("2 بالليل") || text.includes("2 بليل") || text.includes("٢ بليل") || text.includes("٢ بالليل") || text.includes("اتنين بالليل") || text.includes("اتنين بليل")
        ? 2
        : text.includes("3 بالليل") || text.includes("3 بليل") || text.includes("٣ بليل") || text.includes("٣ بالليل") || text.includes("تلاتة بالليل") || text.includes("تلاته بليل")
        ? 3
        : null;

    if (isLateNightHour !== null) {
      targetCairoHour = isLateNightHour;
    } else if (isTwelveMentioned) {
      targetCairoHour = isExplicitNoon ? 12 : 0;
    } else if (text.includes("بعد الفجر") || text.includes("الفجر")) {
      targetCairoHour = 5;
    } else if (text.includes("بعد صلاة الجمعة") || text.includes("بعد صلاة الجمعه")) {
      targetCairoHour = 14;
    } else if (text.includes("بعد الظهر") || text.includes("الظهر") || text.includes("الضهر")) {
      targetCairoHour = 13;
    } else if (text.includes("بعد العصر") || text.includes("العصر")) {
      targetCairoHour = 16;
    } else if (text.includes("بين المغرب والعشا") || text.includes("بين المغرب والعشاء")) {
      targetCairoHour = 19;
    } else if (text.includes("بعد المغرب") || text.includes("المغرب")) {
      targetCairoHour = 18;
    } else if (text.includes("بعد التراويح")) {
      targetCairoHour = 21;
    } else if (text.includes("بعد العشا") || text.includes("بعد العشاء") || text.includes("العشا") || text.includes("العشاء")) {
      targetCairoHour = 20;
    } else {
      const hourMatch = text.match(/(?:الساعه|الساعة|ساعة|الساعة|ساعه)?\s*(\d{1,2}|[١٢٣٤٥٦٧٨٩٠]{1,2})/);
      if (hourMatch && !fallbackMatch) {
        let hRaw = hourMatch[1];
        const arabicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
        for (let i = 0; i < 10; i++) {
          hRaw = hRaw.replace(new RegExp(arabicDigits[i], "g"), i.toString());
        }
        const h = parseInt(hRaw, 10);
        if (h === 12) {
          targetCairoHour = isExplicitNoon ? 12 : 0;
        } else if (h >= 1 && h <= 11) {
          if (text.includes("صباحا") || text.includes("صباحاً") || text.includes("الصبح") || text.includes("am")) {
            targetCairoHour = h;
          } else {
            if (h <= 3 && (text.includes("بليل") || text.includes("بالليل"))) {
              targetCairoHour = h;
            } else {
              targetCairoHour = h + 12;
            }
          }
        } else if (h >= 12 && h <= 23) {
          targetCairoHour = h;
        }
      }
    }

    const actualDate = new Date(targetDayDate);
    if (targetCairoHour >= 0 && targetCairoHour <= 3) {
      actualDate.setUTCDate(actualDate.getUTCDate() + 1);
    }

    const aYyyy = actualDate.getUTCFullYear();
    const aMm = String(actualDate.getUTCMonth() + 1).padStart(2, "0");
    const aDd = String(actualDate.getUTCDate()).padStart(2, "0");
    const targetDateStr = `${aYyyy}-${aMm}-${aDd}`;

    const cairoTimeStr = `${aYyyy}-${aMm}-${aDd}T${String(targetCairoHour).padStart(2, "0")}:00:00`;
    const startTimeIso = new Date(`${cairoTimeStr}${cairo.offsetStr}`).toISOString();
    const endDate = new Date(new Date(`${cairoTimeStr}${cairo.offsetStr}`).getTime() + 60 * 60 * 1000);
    const endTimeIso = endDate.toISOString();

    const displayPeriod = targetCairoHour >= 12 && targetCairoHour !== 0 ? "م" : "ص";
    const displayH = targetCairoHour === 0 ? 12 : targetCairoHour > 12 ? targetCairoHour - 12 : targetCairoHour;
    const nextH = (targetCairoHour + 1) % 24;
    const nextDisplayH = nextH === 0 ? 12 : nextH > 12 ? nextH - 12 : nextH;
    const nextPeriod = nextH >= 12 && nextH !== 0 ? "م" : "ص";

    const displayTime = `${displayH}:00 ${displayPeriod} - ${nextDisplayH}:00 ${nextPeriod}`;

    return {
      startTimeIso,
      endTimeIso,
      displayTime,
      cairoHour: targetCairoHour,
      targetDateStr,
      operationalDateStr,
      clarification,
      preferredSlots: preferredSlots.length > 0 ? preferredSlots : undefined,
    };
  }
}

// ==========================================
// ⚽ Egyptian Football Lexicon Engine
// ==========================================

class EgyptianFootballLexicon {
  static analyze(userMessage: string, contextSnapshot?: any) {
    const text = userMessage.toLowerCase();

    // 1. "عايز كورة" alone vs with booking
    const isBallMentioned =
      text.includes("عايز كورة") ||
      text.includes("عايز كوره") ||
      text.includes("محتاج كورة") ||
      text.includes("مع كورة") ||
      text.includes("مع كوره");

    const isBookingContext =
      text.includes("احجز") ||
      text.includes("حجز") ||
      text.includes("ملعب") ||
      !!contextSnapshot?.last_stadium_id;

    let rentBall = false;
    let ballClarification: Clarification | null = null;

    if (isBallMentioned) {
      if (isBookingContext) {
        rentBall = true;
      } else {
        ballClarification = {
          type: "ball_intent",
          question: "تقصد تأجير كرة مع حجز ملعب، ولا حجز ملعب للعب يا كابتن؟",
          options: [
            { id: "rent_ball_booking", label: "تأجير كرة مع حجز ملعب" },
            { id: "book_field", label: "حجز ملعب جديد للعب" },
          ],
        };
      }
    }

    // 2. "ناقصنا جون" / "ناقصنا حارس"
    const isGoalkeeperSearch =
      text.includes("ناقصنا جون") ||
      text.includes("محتاجين جون") ||
      text.includes("عايزين جون") ||
      text.includes("ناقصنا حارس") ||
      text.includes("محتاجين حارس");

    // 3. "تثبيتة" / "ثبتلي" / "عايز أثبت"
    const isRecurringBooking =
      text.includes("تثبيتة") ||
      text.includes("تثبيته") ||
      text.includes("ثبتلي") ||
      text.includes("ثبت لي") ||
      text.includes("عايز اثبت") ||
      text.includes("عايز أثبت");

    return {
      rentBall,
      ballClarification,
      isGoalkeeperSearch,
      isRecurringBooking,
    };
  }
}

// Backward-compatible wrappers
function parseArabicTimeAndDate(timeStr?: string, dateStr?: string, defaultUserMessage?: string): {
  startTimeIso: string;
  endTimeIso: string;
  displayTime: string;
  cairoHour: number;
  targetDateStr: string;
  operationalDateStr: string;
  clarification?: Clarification | null;
  preferredSlots?: string[];
} {
  const combined = `${timeStr || ""} ${dateStr || ""} ${defaultUserMessage || ""}`.trim();
  return TemporalResolver.resolve(combined);
}

function parseTargetDate(dateStr?: string): { targetDateStr: string; dayStartIso: string; dayEndIso: string } {
  const res = TemporalResolver.resolve(dateStr || "اليوم");
  const parts = res.targetDateStr.split("-").map(Number);
  const yyyy = parts[0];
  const mm = parts[1] - 1;
  const dd = parts[2];

  const dayStartIso = new Date(Date.UTC(yyyy, mm, dd - 1, 21, 0, 0)).toISOString();
  const dayEndIso = new Date(Date.UTC(yyyy, mm, dd, 21, 0, 0)).toISOString();

  return { targetDateStr: res.targetDateStr, dayStartIso, dayEndIso };
}

function generateStandardSlots(targetDateStr: string, stadium?: any) {
  const slots: { start_time: string; end_time: string; display_time: string; hour: number }[] = [];
  const parts = targetDateStr.split("-").map(Number);
  const [yyyy, month, day] = parts;

  // Determine hours dynamically from stadium or default (15:00 to 02:00 next day)
  let openH = 15;
  let closeH = 2;
  if (stadium?.opening_time) {
    openH = parseInt(stadium.opening_time.split(":")[0], 10);
  }
  if (stadium?.closing_time) {
    closeH = parseInt(stadium.closing_time.split(":")[0], 10);
  }

  const cairoHours: number[] = [];
  if (closeH <= openH) {
    // Overnight shift: e.g. 15 to 23, then 0 to (closeH - 1)
    for (let h = openH; h <= 23; h++) cairoHours.push(h);
    for (let h = 0; h < closeH; h++) cairoHours.push(h);
  } else {
    for (let h = openH; h < closeH; h++) cairoHours.push(h);
  }

  // Dynamically compute exact Cairo UTC offset
  const testDate = new Date();
  const cairoLocal = new Date(testDate.toLocaleString("en-US", { timeZone: "Africa/Cairo" }));
  const utcLocal = new Date(testDate.toLocaleString("en-US", { timeZone: "UTC" }));
  const offsetHours = Math.round((cairoLocal.getTime() - utcLocal.getTime()) / (3600 * 1000));
  const offsetSign = offsetHours >= 0 ? "+" : "-";
  const offsetStr = `${offsetSign}${String(Math.abs(offsetHours)).padStart(2, "0")}:00`;

  for (const h of cairoHours) {
    const isNextDay = h < openH && closeH <= openH;
    const slotDay = isNextDay ? day + 1 : day;

    const cairoTimeStr = `${yyyy}-${String(month).padStart(2, "0")}-${String(slotDay).padStart(2, "0")}T${String(h).padStart(2, "0")}:00:00`;
    const startIso = new Date(`${cairoTimeStr}${offsetStr}`).toISOString();
    const endIso = new Date(new Date(`${cairoTimeStr}${offsetStr}`).getTime() + 60 * 60 * 1000).toISOString();

    const displayHourStart = h === 0 ? 12 : h > 12 ? h - 12 : h;
    const endH = (h + 1) % 24;
    const displayHourEnd = endH === 0 ? 12 : endH > 12 ? endH - 12 : endH;
    const period = h >= 12 ? "م" : "ص";
    const endPeriod = endH >= 12 ? "م" : "ص";

    slots.push({
      start_time: startIso,
      end_time: endIso,
      display_time: `${displayHourStart}:00 ${period} - ${displayHourEnd}:00 ${endPeriod}`,
      hour: h,
    });
  }
  return slots;
}

// ==========================================
// 🚀 Main Server Function
// ==========================================

serve(async (req: Request) => {
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

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 🔒 Fail-Closed Authentication
    const authHeader = req.headers.get("Authorization") || req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "").trim();
    const {
      data: { user: callerUser },
      error: authError,
    } = await supabase.auth.getUser(token);
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid or expired authentication token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

    // Rate Limiting
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

    const body = await req.json();
    const userMessage = (body.message ?? "").toString().trim();
    let conversationId = (body.conversation_id ?? "").toString().trim();
    const requestedGov = (body.governorate ?? "").toString().trim();

    if (!userMessage) {
      return new Response(
        JSON.stringify({ error: "Bad Request: message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch caller profile from DB
    const { data: userProfile } = await supabase
      .from("users")
      .select("name, governorate, position, role")
      .eq("id", callerUser.id)
      .maybeSingle();

    const { data: recentUserBookings } = await supabase
      .from("bookings")
      .select("stadium_name, start_time, status, total_price")
      .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
      .order("created_at", { ascending: false })
      .limit(3);

    const userGov = requestedGov || userProfile?.governorate || "أسوان";
    const userName = userProfile?.name || "يا كابتن";
    const userPosition = userProfile?.position || "مهاجم";

    // Conversation Session Management
    let contextSnapshot: Record<string, any> = {};
    if (conversationId) {
      const { data: existingConv } = await supabase
        .from("copilot_conversations")
        .select("id, context_snapshot")
        .eq("id", conversationId)
        .eq("user_id", callerUser.id)
        .maybeSingle();

      if (existingConv) {
        contextSnapshot = existingConv.context_snapshot || {};
      } else {
        conversationId = "";
      }
    }

    if (!conversationId) {
      const generatedTitle =
        userMessage.length > 35 ? userMessage.substring(0, 35) + "..." : userMessage;

      const { data: newConv, error: convErr } = await supabase
        .from("copilot_conversations")
        .insert({
          user_id: callerUser.id,
          title: generatedTitle,
          context_snapshot: {},
        })
        .select("id, context_snapshot")
        .single();

      if (convErr || !newConv) {
        throw new Error("Failed to initialize conversation session: " + (convErr?.message || ""));
      }
      conversationId = newConv.id;
      contextSnapshot = newConv.context_snapshot || {};
    }

    // Multi-Turn History
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
    let appClarification: any = null;
    let assistantReply = "";
    let handledByGemini = false;

    // ⚽ Egyptian Football Lexicon Analysis
    const lexiconAnalysis = EgyptianFootballLexicon.analyze(userMessage, contextSnapshot);

    // 🔄 Pending Intent Resumption
    if (contextSnapshot.pending_intent) {
      const p = contextSnapshot.pending_intent;
      if (p.clarification_type === "date") {
        const dateMatch = userMessage.match(/\b\d{4}-\d{2}-\d{2}\b/);
        if (dateMatch) {
          p.date = dateMatch[0];
          p.clarification_type = null;
        } else if (userMessage.includes("الاولى") || userMessage.includes("الأولى") || userMessage.includes("الاول") || userMessage.includes("أول")) {
          if (p.candidate_options && p.candidate_options[0]) {
            p.date = p.candidate_options[0].id;
            p.clarification_type = null;
          }
        } else if (userMessage.includes("التانية") || userMessage.includes("الثانية") || userMessage.includes("التاني") || userMessage.includes("تاني")) {
          if (p.candidate_options && p.candidate_options[1]) {
            p.date = p.candidate_options[1].id;
            p.clarification_type = null;
          }
        }
      } else if (p.clarification_type === "stadium") {
        if (/^[0-9a-fA-F-]{36}$/.test(userMessage.trim())) {
          p.stadium_id = userMessage.trim();
          p.clarification_type = null;
        } else {
          const matched = await findMatchingStadium(supabase, userMessage, undefined, userGov);
          if (matched && !matched.is_ambiguous) {
            p.stadium_id = matched.id;
            p.stadium_name = matched.name;
            p.clarification_type = null;
          }
        }
      } else if (p.clarification_type === "ball_intent") {
        if (userMessage.includes("rent_ball") || userMessage.includes("تأجير كرة") || userMessage.includes("مع كرة") || userMessage.includes("مع كورة")) {
          p.rent_ball = true;
          p.clarification_type = null;
        }
      }
    }

    // Progressive Clarification: "عايز كورة" alone without booking context
    if (lexiconAnalysis.ballClarification && !contextSnapshot.pending_intent) {
      appClarification = lexiconAnalysis.ballClarification;
      assistantReply = lexiconAnalysis.ballClarification.question;
      contextSnapshot.pending_intent = {
        intent: "create_booking",
        clarification_type: "ball_intent",
        rent_ball: true,
      };
      handledByGemini = true;
    }

    // Gemini 2.5 Flash Interaction
    if (!handledByGemini && geminiApiKey) {
      try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
        const systemPrompt = `أنت "كابتن VSP"، المساعد والمدير الذكي الشامل والوكيل التشغيلي لتطبيق VSP لحجز الملاعب والبطولات في مصر (Omni-Capable In-App Operating Agent).
تتحدث بلهجة مصرية كروية حماسية وودودة ومحترمة (يا كابتن، يا حريف، يا بطل).

سياق المستخدم الحالي:
- اسم المستخدم: ${userName}
- دور المستخدم: ${userProfile?.role || 'لاعب'}
- المحافظة الحالية: ${userGov}
- المركز المفضل: ${userPosition}
- آخر 3 حجوزات للمستخدم: ${recentUserBookings && recentUserBookings.length > 0 ? recentUserBookings.map((b: any) => `${b.stadium_name} (${b.start_time})`).join("، ") : "لا توجد حجوزات سابقة بعد"}
عندما يسأل المستخدم عن ملاعب قريبة، أو ملاعب للحجز، أو ماتشات دون ذكر محافظة، استخدم محافظته الحالية (${userGov}) كخيار افتراضي!

ذاكرة وسياق المحادثة المحفوظ:
${JSON.stringify(contextSnapshot, null, 2)}
إذا أشار المستخدم إلى "الملعب ده" أو "احجزلي" أو "بكره" أو موعد سبق استعراضه، ارجع إلى السياق المخزن فوراً دون إعادة سؤاله!

⚡⚡ قواعد المحرك اللغوي والكروي المصري (VSP Egyptian Linguistic & Football Engine):
1. عند طلب حجز ملعب (مثال: "اريد ان احجز في الساعه 12 في منتصف الليل في الملعب صدقه جديده" أو "احجزلي الساعة 8 بالليل"):
   - استدعِ createBookingFromChat فوراً مع تمرير اسم الملعب والتوقيت والتاريخ.
   - إذا ذكر "عايز كورة" أو "مع كورة": مرر rent_ball: true.
   - إذا ذكر شرط بديل "لو مفيش 8 خليه 9": مرر fallback_slots: ['21:00'].
2. عند قول "ناقصنا جون" أو "ناقصنا حارس":
   - استدعِ getOpenMatches فوراً مع required_position: 'goalkeeper' (للبحث عن ماتشات ناقصها حارس مرمى).
3. فهم التوقيت بالعامية المصرية:
   - "12 بليل" / "منتصف الليل" = 00:00 (منتصف الليل 12:00 ص).
   - "12 صبح" / "12 ضهر" = 12:00 (منتصف النهار 12:00 م).
   - "2 بليل" أو "3 بليل" = سهرة متأخرة بعد منتصف الليل (02:00 ص / 03:00 ص).
   - "بعد العصر" / "بعد المغرب" / "بعد العشا" / "بعد صلاة الجمعة" = مواعيد وفترات لعب شاغرة.
4. ممنوع التوجيه اليدوي للروابط عند طلب الحجز، بل نفذ الحجز ذرياً عبر الأدوات مباشرة.

قواعد صارمة لرفض الأسئلة الخارجة عن نطاق التطبيق (STRICT OUT-OF-SCOPE REFUSAL POLICY):
1. أنت وكيل رياضي وتشغيلي حصري لتطبيق VSP فقط (حجز الملاعب، إدارة ملاعب المالكين، البطولات، دوري الحريفة 1v1، والعمليات المالية).
2. ممنوع منعاً باتاً الإجابة عن أي أسئلة خارج هذا النطاق إطلاقاً (طبخ، سياسة، برمجة عامة، دراسة، أفلام، طقس).
3. عند طرح أي سؤال خارج النطاق، ارفض فوراً بلباقة:
   "عذراً يا كابتن! أنا "كابتن VSP"، مساعدك الرياضي المتخصص فقط في تطبيق VSP لحجز وإدارة الملاعب والبطولات في مصر ⚽. مقدرش أساعدك غير في اللي يخص ملاعبك وحجوزاتك وخدمات التطبيق يا بطل!"

قاعدة النزاهة والتحقق من قاعدة البيانات الحقيقية (ZERO-HALLUCINATION POLICY):
1. أنت متصل مباشرة بقاعدة بيانات VSP الحقيقية.
2. لا تخترع ملاعب أو بطولات أو أسعاراً غير موجودة.
3. لحجز ملعب أو تحديد موعد: استدعِ createBookingFromChat فوراً.
4. لفحص التوافر والمواعيد الشاغرة: استدعِ checkStadiumAvailability فوراً.
5. للبحث عن ملاعب: استدعِ searchStadiums فوراً.`;

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
              const querySearch = (args.query || "").toString().trim();
              let governorate = (args.governorate || "").toString().trim();
              if (
                !governorate ||
                governorate.includes("قريب") ||
                governorate.includes("هنا") ||
                governorate.includes("عندي")
              ) {
                governorate = userGov;
              }
              const maxPrice = Number(args.max_price);

              // Smart match if query is provided
              if (querySearch) {
                const matched = await findMatchingStadium(supabase, querySearch, undefined, governorate);
                if (matched) {
                  stadiumResults = [matched];
                }
              }

              if (stadiumResults.length === 0) {
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
              }

              toolResponseData = { count: stadiumResults.length, governorate: governorate, stadiums: stadiumResults };

              contextSnapshot.last_searched_governorate = governorate;
              if (stadiumResults.length > 0) {
                contextSnapshot.last_stadium_id = stadiumResults[0].id;
                contextSnapshot.last_stadium_name = stadiumResults[0].name;
              }
            } else if (funcName === "searchTournaments") {
              const tType = (args.tournament_type || "all").toString().toLowerCase();
              const gov = (args.governorate || "").toString().trim();

              const results: any = {};
              if (tType === "all" || tType === "5v5") {
                let q5v5 = supabase
                  .from("championships")
                  .select("id, name, type, grand_prize, entry_fee, max_teams, status, governorate")
                  .eq("status", "open");
                if (gov) q5v5 = q5v5.ilike("governorate", `%${gov}%`);
                const { data: champs } = await q5v5.limit(5);
                results.team_tournaments_5v5 = champs || [];
              }
              if (tType === "all" || tType === "1v1") {
                let q1v1 = supabase
                  .from("vsp_1v1_tournaments")
                  .select("id, name, status, prize_pool, entry_fee, target_player_count, governorate")
                  .eq("status", "registration_open");
                if (gov) q1v1 = q1v1.ilike("governorate", `%${gov}%`);
                const { data: t1v1 } = await q1v1.limit(5);
                results.individual_tournaments_1v1 = t1v1 || [];
              }
              tournamentResults = [
                ...(results.team_tournaments_5v5 || []),
                ...(results.individual_tournaments_1v1 || []),
              ];
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
              let mQuery = supabase
                .from("bookings")
                .select("id, stadium_name, start_time, current_players, max_players, notes, total_price")
                .eq("booking_type", "open_join")
                .eq("status", "confirmed")
                .gte("start_time", new Date().toISOString());

              if (args.date) {
                const { dayStartIso, dayEndIso } = parseTargetDate(args.date);
                mQuery = mQuery.gte("start_time", dayStartIso).lte("start_time", dayEndIso);
              }

              const { data: matches } = await mQuery
                .order("start_time", { ascending: true })
                .limit(10);

              let openList = matches || [];
              const reqPos = args.required_position || (lexiconAnalysis.isGoalkeeperSearch ? "goalkeeper" : null);

              if (reqPos) {
                const normReq = normalizeArabic(reqPos);
                const filtered = openList.filter((m: any) => {
                  const n = normalizeArabic(m.notes || "");
                  return n.includes(normReq) || n.includes("جون") || n.includes("حارس") || n.includes("حراسة");
                });
                if (filtered.length > 0) {
                  openList = filtered;
                }
              }

              openMatchResults = openList.slice(0, 5);
              toolResponseData = {
                open_matches: openMatchResults,
                required_position: reqPos,
                date: args.date || null,
              };
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
              const refunds = bookingsList.filter(
                (b: any) =>
                  (b.refund_amount && Number(b.refund_amount) > 0) ||
                  b.refunded_at ||
                  b.status === "cancelled"
              );

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
            } else if (funcName === "getOwnerStadiumsAndBookings") {
              const { data: ownerStadiums } = await supabase
                .from("stadiums")
                .select("id, name, governorate, price_per_hour, is_verified, is_blocked")
                .eq("owner_id", callerUser.id)
                .eq("is_deleted_by_owner", false);

              const stadiumIds = (ownerStadiums || []).map((s: any) => s.id);
              let ownerBookings: any[] = [];
              if (stadiumIds.length > 0) {
                let bQuery = supabase
                  .from("bookings")
                  .select("id, stadium_name, start_time, end_time, status, total_price, deposit_paid, payment_method, payment_status, host_name, player_phone")
                  .or(`owner_id.eq.${callerUser.id},stadium_id.in.(${stadiumIds.join(",")})`);

                if (args.status && args.status !== "all") {
                  bQuery = bQuery.eq("status", args.status);
                }
                const { data: bList } = await bQuery
                  .order("start_time", { ascending: false })
                  .limit(10);
                ownerBookings = bList || [];
              }

              appAction = {
                action_type: "NAVIGATE",
                route: "/bookings",
                label: "فتح جدول حجوزات الملاعب 📅",
              };

              toolResponseData = {
                owner_stadiums_count: (ownerStadiums || []).length,
                owner_stadiums: ownerStadiums || [],
                bookings_count: ownerBookings.length,
                recent_bookings: ownerBookings,
              };
            } else if (funcName === "getOwnerFinancialInsights") {
              const { data: finSummary, error: finErr } = await supabase.rpc(
                "get_owner_financial_summary",
                { p_owner_id: callerUser.id }
              );

              appAction = {
                action_type: "NAVIGATE",
                route: "/ledger",
                label: "فتح السجل المالي والمستحقات 💰",
              };

              toolResponseData = finSummary || { success: false, error: finErr?.message };
            } else if (funcName === "checkStadiumAvailability") {
              const stadiumId = (args.stadium_id || contextSnapshot.last_stadium_id || "").toString().trim();
              const stadiumName = (args.stadium_name || contextSnapshot.last_stadium_name || "").toString().trim();
              const dateInput = (args.date || "اليوم").toString().trim();
              const timePref = (args.time_preference || "").toString().trim();

              const targetStadium = await findMatchingStadium(supabase, stadiumName || userMessage, stadiumId, userGov);

              if (!targetStadium) {
                toolResponseData = {
                  success: false,
                  message: "لم يتم العثور على الملعب المطلوب في قاعدة البيانات.",
                };
              } else {
                const { targetDateStr, dayStartIso, dayEndIso } = parseTargetDate(dateInput);

                const { data: existingBookings } = await supabase
                  .from("bookings")
                  .select("start_time, end_time, status, locked_until, created_at")
                  .eq("stadium_id", targetStadium.id)
                  .neq("status", "cancelled")
                  .gte("start_time", dayStartIso)
                  .lte("start_time", dayEndIso);

                const activeBookings = (existingBookings || []).filter((b: any) => {
                  if (b.status === "pending") {
                    const lockExpire = b.locked_until
                      ? new Date(b.locked_until).getTime()
                      : new Date(b.created_at).getTime() + 5 * 60 * 1000;
                    return lockExpire > Date.now();
                  }
                  return true;
                });

                const allSlots = generateStandardSlots(targetDateStr, targetStadium);
                const availableSlots = allSlots.filter((slot) => {
                  const sStart = new Date(slot.start_time).getTime();
                  const sEnd = new Date(slot.end_time).getTime();
                  for (const b of activeBookings) {
                    const bStart = new Date(b.start_time).getTime();
                    const bEnd = new Date(b.end_time).getTime();
                    if (sStart < bEnd && sEnd > bStart) return false;
                  }
                  return true;
                });

                contextSnapshot.last_stadium_id = targetStadium.id;
                contextSnapshot.last_stadium_name = targetStadium.name;
                contextSnapshot.last_date = targetDateStr;
                contextSnapshot.last_available_slots = availableSlots;
                stadiumResults = [targetStadium];

                toolResponseData = {
                  stadium_id: targetStadium.id,
                  stadium_name: targetStadium.name,
                  date: targetDateStr,
                  price_per_hour: targetStadium.price_per_hour,
                  needs_deposit: targetStadium.needs_deposit || false,
                  deposit_amount: targetStadium.deposit_amount || 0,
                  total_slots_generated: allSlots.length,
                  available_slots_count: availableSlots.length,
                  available_slots: availableSlots,
                  time_preference: timePref,
                };
              }
            } else if (funcName === "createBookingFromChat") {
              const stadiumId = (args.stadium_id || contextSnapshot.last_stadium_id || "").toString().trim();
              const stadiumName = (args.stadium_name || contextSnapshot.last_stadium_name || "").toString().trim();
              let startTime = (args.start_time || "").toString().trim();
              let endTime = (args.end_time || "").toString().trim();

              const targetStadium = await findMatchingStadium(supabase, stadiumName || userMessage, stadiumId, userGov);

              // 🏟️ Stadium Disambiguation Check (Section 15: No auto-booking from ambiguous stadium match!)
              if (targetStadium && targetStadium.is_ambiguous) {
                appClarification = {
                  type: "stadium",
                  question: "أي ملعب تقصد يا كابتن؟",
                  options: targetStadium.candidates,
                };
                assistantReply = "وجدت أكثر من ملعب مطابق يا كابتن، أي ملعب تقصد؟";
                contextSnapshot.pending_intent = {
                  intent: "create_booking",
                  stadium_id: null,
                  time: args.time,
                  date: args.date,
                  rent_ball: args.rent_ball === true || lexiconAnalysis.rentBall,
                  fallback_slots: args.fallback_slots,
                  candidate_options: targetStadium.candidates,
                  clarification_type: "stadium",
                };
                toolResponseData = {
                  clarification_needed: true,
                  clarification: appClarification,
                };
              } else {
                // Parse Arabic time & temporal expression
                let displaySlot = "";
                let parsedTime: any = null;
                if (!startTime || !startTime.includes("T")) {
                  parsedTime = parseArabicTimeAndDate(args.time, args.date, userMessage);
                  startTime = parsedTime.startTimeIso;
                  endTime = parsedTime.endTimeIso;
                  displaySlot = parsedTime.displayTime;
                } else if (!endTime) {
                  const sDate = new Date(startTime);
                  endTime = new Date(sDate.getTime() + 60 * 60 * 1000).toISOString();
                  displaySlot = "موعد محدد";
                }

                // 📅 Date Disambiguation Check (Section 6: E.g., "الجمعة الجاية" with multiple dates)
                if (parsedTime?.clarification) {
                  appClarification = parsedTime.clarification;
                  assistantReply = parsedTime.clarification.question;
                  contextSnapshot.pending_intent = {
                    intent: "create_booking",
                    stadium_id: targetStadium ? targetStadium.id : null,
                    stadium_name: targetStadium ? targetStadium.name : null,
                    time: args.time,
                    date: null,
                    rent_ball: args.rent_ball === true || lexiconAnalysis.rentBall,
                    fallback_slots: args.fallback_slots || parsedTime.preferredSlots,
                    candidate_options: parsedTime.clarification.options,
                    clarification_type: "date",
                  };
                  toolResponseData = {
                    clarification_needed: true,
                    clarification: parsedTime.clarification,
                  };
                } else if (!targetStadium || !startTime || !endTime) {
                  toolResponseData = {
                    success: false,
                    message: "عذراً يا كابتن، بيانات الحجز غير مكتملة. يرجى توضيح الملعب والموعد المطلوب.",
                  };
                } else {
                  const needsDeposit = targetStadium.needs_deposit === true;
                  const paymentMethod = needsDeposit ? "paymob" : args.payment_method || "cash";
                  const rentBallParam = args.rent_ball === true || lexiconAnalysis.rentBall;

                  // 🔄 Conditional Fallback Engine (Section 12: Try preferred slots atomically)
                  const preferred = args.fallback_slots || parsedTime?.preferredSlots || [];
                  const trySlots: { start: string; end: string; display: string }[] = [
                    { start: startTime, end: endTime, display: displaySlot },
                  ];

                  if (preferred.length > 1) {
                    const h2 = parseInt(preferred[1].split(":")[0], 10);
                    const targetDatePart = parsedTime?.targetDateStr || startTime.split("T")[0];
                    const testDate = new Date();
                    const cairoLocal = new Date(testDate.toLocaleString("en-US", { timeZone: "Africa/Cairo" }));
                    const utcLocal = new Date(testDate.toLocaleString("en-US", { timeZone: "UTC" }));
                    const offsetHours = Math.round((cairoLocal.getTime() - utcLocal.getTime()) / (3600 * 1000));
                    const offsetSign = offsetHours >= 0 ? "+" : "-";
                    const offsetStr = `${offsetSign}${String(Math.abs(offsetHours)).padStart(2, "0")}:00`;
                    const s2Start = new Date(`${targetDatePart}T${String(h2).padStart(2, "0")}:00:00${offsetStr}`).toISOString();
                    const s2End = new Date(new Date(s2Start).getTime() + 60 * 60 * 1000).toISOString();
                    const displayH2 = h2 > 12 ? h2 - 12 : h2;
                    const nextH2 = (h2 + 1) % 24;
                    const nextDH2 = nextH2 > 12 ? nextH2 - 12 : nextH2;
                    const disp2 = `${displayH2}:00 م - ${nextDH2}:00 م`;
                    trySlots.push({ start: s2Start, end: s2End, display: disp2 });
                  }

                  let bookedSlot: any = null;
                  let lastErrorMsg = "";

                  for (let idx = 0; idx < trySlots.length; idx++) {
                    const slotToTry = trySlots[idx];

                    // Check conflict
                    const { data: conflictBookings } = await supabase
                      .from("bookings")
                      .select("id, status, locked_until, created_at")
                      .eq("stadium_id", targetStadium.id)
                      .neq("status", "cancelled")
                      .filter("start_time", "lt", slotToTry.end)
                      .filter("end_time", "gt", slotToTry.start);

                    const hasConflict = (conflictBookings || []).some((b: any) => {
                      if (b.status === "pending") {
                        const lockExpire = b.locked_until
                          ? new Date(b.locked_until).getTime()
                          : new Date(b.created_at).getTime() + 5 * 60 * 1000;
                        return lockExpire > Date.now();
                      }
                      return true;
                    });

                    if (hasConflict) {
                      lastErrorMsg = "عذراً يا كابتن، هذا الموعد محجوز أو قيد الدفع حالياً من قِبل لاعب آخر.";
                      continue; // Try next fallback slot
                    }

                    // Atomic booking RPC with p_rent_ball
                    const { data: bookingResult, error: bookingErr } = await supabase.rpc(
                      "create_booking_atomic",
                      {
                        p_stadium_id: targetStadium.id,
                        p_user_id: callerUser.id,
                        p_owner_id: targetStadium.owner_id,
                        p_start_time: slotToTry.start,
                        p_end_time: slotToTry.end,
                        p_booking_type: "individual",
                        p_total_price: targetStadium.price_per_hour,
                        p_stadium_name: targetStadium.name,
                        p_payment_method: paymentMethod,
                        p_rent_ball: rentBallParam,
                      }
                    );

                    if (bookingErr || (bookingResult && bookingResult.success === false)) {
                      lastErrorMsg = bookingErr?.message || bookingResult?.message || "تعذر إتمام الحجز، قد يكون الموعد محجوزاً بالفعل.";
                      continue;
                    }

                    bookedSlot = {
                      bookingResult,
                      slot: slotToTry,
                      isFallback: idx > 0,
                      originalSlot: trySlots[0].display,
                    };
                    break;
                  }

                  if (!bookedSlot) {
                    toolResponseData = {
                      success: false,
                      error: lastErrorMsg || "عذراً يا كابتن، لم نتمكن من إتمام الحجز في المواعيد المطلوبة.",
                    };
                  } else {
                    const bookingId = bookedSlot.bookingResult?.booking_id || bookedSlot.bookingResult?.id;
                    contextSnapshot.last_booking_id = bookingId;
                    contextSnapshot.last_booked_stadium = targetStadium.name;
                    contextSnapshot.last_slot = bookedSlot.slot.display;
                    stadiumResults = [targetStadium];

                    const ballNote = rentBallParam ? " + تأجير كرة ⚽" : "";
                    const fallbackNote = bookedSlot.isFallback
                      ? ` (الموعد الأول ${bookedSlot.originalSlot} كان غير متاح، فتم حجز موعدك البديل ${bookedSlot.slot.display})`
                      : "";

                    if (needsDeposit || paymentMethod === "paymob") {
                      appAction = {
                        action_type: "OPEN_PAYMENT",
                        route: "/checkout",
                        label: `إتمام دفع العربون (${targetStadium.deposit_amount || 50} ج.م) وتأكيد الحجز 💳`,
                        params: {
                          booking_id: bookingId,
                          stadium_id: targetStadium.id,
                          stadium_name: targetStadium.name,
                          owner_id: targetStadium.owner_id,
                          total_price: targetStadium.price_per_hour,
                          deposit_amount: targetStadium.deposit_amount || 50,
                          start_time: bookedSlot.slot.start,
                          end_time: bookedSlot.slot.end,
                          slot: bookedSlot.slot.display,
                          rent_ball: rentBallParam,
                        },
                      };
                    } else {
                      appAction = {
                        action_type: "NAVIGATE",
                        route: "/bookings",
                        label: "عرض تفاصيل الحجز المؤكد 📋",
                        params: { booking_id: bookingId },
                      };
                    }

                    toolResponseData = {
                      success: true,
                      booking_id: bookingId,
                      stadium_name: targetStadium.name,
                      start_time: bookedSlot.slot.start,
                      end_time: bookedSlot.slot.end,
                      slot: bookedSlot.slot.display,
                      total_price: targetStadium.price_per_hour,
                      deposit_required: needsDeposit,
                      deposit_amount: targetStadium.deposit_amount || 50,
                      rent_ball: rentBallParam,
                      is_fallback: bookedSlot.isFallback,
                      message: needsDeposit
                        ? `تم قفل الموعد (${bookedSlot.slot.display}${ballNote})${fallbackNote} بنجاح في ${targetStadium.name} لمدة 5 دقائق! اضغط على زر الدفع لإتمام دفع العربون (${targetStadium.deposit_amount || 50} ج.م) وتأكيد الحجز فوراً.`
                        : `تم تأكيد حجزك في ${targetStadium.name} (${bookedSlot.slot.display}${ballNote})${fallbackNote} بنجاح والدفع كاش في الملعب ⚽!`,
                    };
                  }
                }
              }
            }

            // Second turn for Gemini natural response
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

            // 🛡️ Zero-Hallucination & Fallback Guard
            if (funcName === "searchTournaments" && tournamentResults.length === 0) {
              const targetGov = (args.governorate || userGov).toString().trim();
              assistantReply = `عذراً يا كابتن، بحثتلك في قاعدة بيانات VSP ومافيش حالياً بطولات مفتوحة للتسجيل في ${targetGov}. أول ما تنزل بطولة جديدة هتلاقيها معلنة في صفحة البطولات وتقدر تشترك فوراً!`;
            } else if (funcName === "searchStadiums" && stadiumResults.length === 0) {
              const targetGov = (args.governorate || userGov).toString().trim();
              assistantReply = `عذراً يا كابتن، بحثتلك في قاعدة بيانات VSP ومافيش حالياً ملاعب مسجلة في ${targetGov}. الملعب المتاح حالياً في التطبيق هو ملعب الصداقة الجديدة في أسوان!`;
            } else if (funcName === "getOpenMatches" && openMatchResults.length === 0) {
              assistantReply =
                "عذراً يا كابتن، مفيش حالياً ماتشات خماسية مفتوحة محتاجة لاعيبة في قاعدة البيانات. تقدر تحجز ملعب وتبدأ تقسيمة جديدة بنفسك!";
            } else if (funcName === "createBookingFromChat") {
              if (toolResponseData.clarification_needed) {
                assistantReply = appClarification?.question || "يرجى توضيح المطلوب يا كابتن.";
              } else if (toolResponseData.success) {
                if (toolResponseData.deposit_required) {
                  assistantReply = `تم قفل موعدك بنجاح (${toolResponseData.slot || 'الساعة 12:00 ص'}${toolResponseData.rent_ball ? ' + تأجير كرة' : ''}) في ملعب ${toolResponseData.stadium_name} يا كابتن ⚽!${toolResponseData.is_fallback ? '\n(الموعد البديل المفضل بعد تعذر الموعد الأول)' : ''}\nتم حفظ وحجز الموعد لمدة 5 دقائق، اضغط على زر الدفع بالأسفل لإتمام دفع العربون (${toolResponseData.deposit_amount} ج.م) وتأكيد الحجز فوراً 💳.`;
                } else {
                  assistantReply = `ألف مبروك يا كابتن! تم تأكيد حجزك في ملعب ${toolResponseData.stadium_name} (${toolResponseData.slot || 'الساعة 12:00 ص'}${toolResponseData.rent_ball ? ' + تأجير كرة' : ''}) بنجاح والدفع كاش في الملعب (${toolResponseData.total_price} ج.م).${toolResponseData.is_fallback ? ' (الموعد البديل المفضل)' : ''} حجزك مسجل في قائمة حجوزاتك 📋`;
                }
              } else {
                assistantReply = `عذراً يا كابتن، لم نتمكن من إتمام الحجز: ${toolResponseData.error || toolResponseData.message}`;
              }
            } else if (!assistantReply) {
              if (funcName === "checkStadiumAvailability") {
                if (toolResponseData.available_slots_count === 0) {
                  assistantReply = `عذراً يا كابتن، راجعت جدول مواعيد ${toolResponseData.stadium_name || 'الملعب'} ليوم ${toolResponseData.date} وجميع الفترات محجوزة بالكامل في هذا اليوم. تحب نفحص يوم تاني؟`;
                } else {
                  const slotsText = (toolResponseData.available_slots || [])
                    .slice(0, 5)
                    .map((s: any) => `• ${s.display_time}`)
                    .join("\n");
                  assistantReply = `يا كابتن! بحثتلك في جدول مواعيد ${toolResponseData.stadium_name || 'الملعب'} ليوم ${toolResponseData.date}، ودي الفترات المتاحة للحجز:\n${slotsText}\nسعر الساعة: ${toolResponseData.price_per_hour} ج.م. تحب أحجزلك أي ميعاد منهم؟`;
                }
              } else if (funcName === "searchStadiums") {
                assistantReply = `يا كابتن! دي الملاعب المتاحة على VSP للحجز الفوري:`;
              } else {
                assistantReply = "تمام يا كابتن، طلبك جاهز!";
              }
            }
            handledByGemini = true;
          } else {
            // Out-of-scope check
            const lowerMsg = userMessage.toLowerCase();
            const isOutOfScope =
              lowerMsg.includes("طبخ") ||
              lowerMsg.includes("طبيخ") ||
              lowerMsg.includes("أكل") ||
              lowerMsg.includes("أكلة") ||
              lowerMsg.includes("طريقة عمل") ||
              lowerMsg.includes("وصفة") ||
              lowerMsg.includes("مقادير") ||
              lowerMsg.includes("كشري") ||
              lowerMsg.includes("شاورما") ||
              lowerMsg.includes("بيتزا") ||
              lowerMsg.includes("برجر") ||
              lowerMsg.includes("ملوخية") ||
              lowerMsg.includes("كيكة") ||
              lowerMsg.includes("سياسة") ||
              lowerMsg.includes("سياسي") ||
              lowerMsg.includes("رئيس") ||
              lowerMsg.includes("انتخابات") ||
              lowerMsg.includes("حكومة") ||
              lowerMsg.includes("وزير") ||
              lowerMsg.includes("برلمان") ||
              lowerMsg.includes("حرب") ||
              lowerMsg.includes("بايثون") ||
              lowerMsg.includes("python") ||
              lowerMsg.includes("كود") ||
              lowerMsg.includes("برمجة") ||
              lowerMsg.includes("مبرمج") ||
              lowerMsg.includes("جافاسكريبت") ||
              lowerMsg.includes("javascript") ||
              lowerMsg.includes("فيزياء") ||
              lowerMsg.includes("كيمياء") ||
              lowerMsg.includes("فلسفة") ||
              lowerMsg.includes("رياضيات") ||
              lowerMsg.includes("معادلة") ||
              lowerMsg.includes("تفاضل") ||
              lowerMsg.includes("تكامل") ||
              lowerMsg.includes("أينشتاين") ||
              lowerMsg.includes("نيوتن") ||
              lowerMsg.includes("فيلم") ||
              lowerMsg.includes("مسلسل") ||
              lowerMsg.includes("أغنية") ||
              lowerMsg.includes("اغنية") ||
              lowerMsg.includes("طقس") ||
              lowerMsg.includes("درجة الحرارة") ||
              lowerMsg.includes("نكتة") ||
              lowerMsg.includes("فزورة") ||
              lowerMsg.includes("مرسيدس") ||
              lowerMsg.includes("سيارات") ||
              lowerMsg.includes("عقارات") ||
              lowerMsg.includes("بورصة") ||
              lowerMsg.includes("بيتكوين") ||
              lowerMsg.includes("crypto") ||
              lowerMsg.includes("علاج") ||
              lowerMsg.includes("دواء") ||
              lowerMsg.includes("تاريخ فرنسا") ||
              lowerMsg.includes("عاصمة");

            if (isOutOfScope) {
              assistantReply =
                'عذراً يا كابتن! أنا "كابتن VSP"، مساعدك الرياضي المتخصص فقط في تطبيق VSP لحجز وإدارة الملاعب والبطولات في مصر ⚽. مقدرش أساعدك غير في اللي يخص ملاعبك وحجوزاتك وخدمات التطبيق يا بطل!';
              handledByGemini = true;
            } else {
              assistantReply = candidate1?.parts?.[0]?.text || "";
              if (assistantReply.trim().length > 0) {
                handledByGemini = true;
              }
            }
          }
        }
      } catch (geminiErr) {
        console.warn("Gemini API error:", geminiErr);
      }
    }

    if (!handledByGemini) {
      assistantReply =
        "عذراً يا كابتن! حدث ضغط لحظي في خدمة الذكاء الاصطناعي، يرجى إعادة إرسال رسالتك أو تصفح الملاعب والبطولات مباشرة من القوائم.";
    }

    // Persist Messages & Update Conversation
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
      .update({
        updated_at: new Date().toISOString(),
        context_snapshot: contextSnapshot,
      })
      .eq("id", conversationId);

    // Return enriched payload
    return new Response(
      JSON.stringify({
        conversation_id: conversationId,
        message: assistantReply,
        stadiums: stadiumResults,
        tournaments: tournamentResults,
        leaderboard: leaderboardResults,
        open_matches: openMatchResults,
        action: appAction,
        clarification: appClarification,
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
