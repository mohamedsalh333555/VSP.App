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
  description: "توجيه المستخدم لشاشة داخل التطبيق. للاعب: فريقي، البطولات، دوري 1v1، حجوزاتي، البروفايل والإعدادات. لمالك الملعب: لوحة التحكم، الحجوزات، السجل المالي، الباقة، المحادثات والبروفايل. استدعِ هذه الأداة فوراً عندما يطلب المستخدم الذهاب لشاشة معينة، ولا تخترع مساراً غير موجود.",
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
      payment_status: {
        type: "STRING",
        description: "حالة الدفع: paid أو pending أو failed، فقط عندما يذكر المالك حالة الدفع.",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم ملعب من ملاعب هذا المالك فقط إذا كان محدداً بوضوح.",
      },
    },
  },
};

// 9. Tool: getOwnerFinancialInsights
const getOwnerFinancialInsightsTool = {
  name: "getOwnerFinancialInsights",
  description: "استعلام مالي دقيق لمالك الملعب. ممنوع اعتبار كلمات مثل دخلي أو عملت كام مقياساً محدداً من نفسك؛ يجب تحديد المقياس والفترة، والملعب فقط إذا طلب المالك ملعباً بعينه. لا تقدّر ولا تخمّن رقماً.",
  parameters: {
    type: "OBJECT",
    properties: {
      metric: {
        type: "STRING",
        description: "available_balance، owner_online_earnings، completed_booking_value، completed_booking_count، cash_collected، owner_total_revenue",
      },
      period: {
        type: "STRING",
        description: "today، yesterday، current_week، last_7_days، current_month، last_month، all_time، أو current للبيانات الحالية.",
      },
      stadium_id: {
        type: "STRING",
        description: "UUID لملعب من ملاعب المالك فقط إذا كان محدداً بوضوح.",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم ملعب من ملاعب المالك فقط إذا كان محدداً بوضوح.",
      },
    },
    required: ["metric", "period"],
  },
};

// 10. Tool: checkStadiumAvailability
const checkStadiumAvailabilityTool = {
  name: "checkStadiumAvailability",
  description: "فحص مواعيد وتوافر الملعب والتحقق من الفترات والساعات المتاحة والشاغرة للحجز بتاريخ وتوقيت محدد، وتجنب الحجوزات المتضاربة من قاعدة البيانات الحقيقية. استدعِ هذه الأداة فوراً عندما يسأل المستخدم عن موعد شاغر، أو توفر ملعب، أو حجز في وقت أو يوم محدد (مثل: بكرة الساعة 8، الجمعة القادمة، العصر، بالليل).",
  parameters: {
    type: "OBJECT",
    properties: {
      stadium_id: {
        type: "STRING",
        description: "معرف الملعب (UUID) المطلوب فحص مواعيده",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم الملعب المطلوب فحص مواعيده إذا لم يتوفر المعرف",
      },
      date: {
        type: "STRING",
        description: "التاريخ المطلوب (مثل: YYYY-MM-DD أو 'غداً' أو 'اليوم')",
      },
      time_preference: {
        type: "STRING",
        description: "التوقيت المفضل (مثل: 'صباحاً'، 'مساءً'، 'الساعة 8 مساءً')",
      },
    },
    required: ["date"],
  },
};

// 11. Tool: createBookingFromChat
const createBookingFromChatTool = {
  name: "createBookingFromChat",
  description: "إدارة خطوة الحجز من داخل المحادثة. الطلب الأول يجهّز موعداً للتأكيد ولا ينشئ حجزاً، ولا يسمح بالتنفيذ إلا بعد وجود confirmation_pending وتأكيد صريح من المستخدم مثل أيوه/تمام/أكد الحجز. عند التنفيذ استخدم مسار الحجز الذري الحالي.",
  parameters: {
    type: "OBJECT",
    properties: {
      stadium_id: {
        type: "STRING",
        description: "معرف الملعب (UUID)",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم الملعب",
      },
      start_time: {
        type: "STRING",
        description: "وقت بداية الحجز بصيغة ISO 8601 (UTC)",
      },
      end_time: {
        type: "STRING",
        description: "وقت نهاية الحجز بصيغة ISO 8601 (UTC)",
      },
      payment_method: {
        type: "STRING",
        description: "طريقة الدفع: 'online' أو 'cash' (إذا كان الملعب يقبل الكاش)",
      },
      confirm: {
        type: "BOOLEAN",
        description: "لا تستخدم true إلا بعد أن يكون النظام قد عرض ملخص الحجز وطلب تأكيد المستخدم، ثم قال المستخدم موافق/أيوه/تمام/أكد الحجز.",
      },
    },
    required: ["stadium_id"],
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

const COPILOT_ROLE_CAPABILITIES: Record<string, Set<string>> = {
  player: new Set([
    "searchStadiums",
    "searchTournaments",
    "get1v1Leaderboard",
    "getOpenMatches",
    "executeAppAction",
    "updateUserProfile",
    "getUserBookingsAndRefunds",
    "checkStadiumAvailability",
    "createBookingFromChat",
  ]),
  owner: new Set([
    "executeAppAction",
    "updateUserProfile",
    "getOwnerStadiumsAndBookings",
    "getOwnerFinancialInsights",
  ]),
  admin: new Set(allCopilotTools.map((tool: any) => tool.name)),
  co_founder: new Set(allCopilotTools.map((tool: any) => tool.name)),
};

function normalizeCopilotRole(role: string | null | undefined): string {
  const value = (role || "player").toString().trim().toLowerCase();
  if (value === "co-founder" || value === "cofounder") return "co_founder";
  if (value === "administrator") return "admin";
  return value || "player";
}

function isCopilotToolAllowed(role: string | null | undefined, toolName: string): boolean {
  const normalizedRole = normalizeCopilotRole(role);
  return COPILOT_ROLE_CAPABILITIES[normalizedRole]?.has(toolName) === true;
}

function isCopilotRouteAllowed(role: string | null | undefined, route: string): boolean {
  const normalizedRole = normalizeCopilotRole(role);
  const value = (route || "").trim().toLowerCase();

  if (normalizedRole === "player") {
    return [
      "/player",
      "/tournaments",
      "/1v1",
      "/my-team",
      "/bookings",
      "/profile",
      "/settings",
      "/notifications",
      "/copilot",
    ].some((allowed) => value === allowed || value.startsWith(allowed + "/"));
  }

  if (normalizedRole === "owner") {
    return [
      "/owner",
      "/owner/dashboard",
      "/bookings",
      "/profile",
      "/settings",
      "/notifications",
      "/copilot",
      "/ledger",
      "/owner/ledger",
      "/subscription",
      "/owner/subscription",
      "/owner/inbox",
      "/owner/chat",
    ].some((allowed) => value === allowed || value.startsWith(allowed + "/"));
  }

  return true;
}

function getCairoParts(date: Date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value || 0);
  return { year: get("year"), month: get("month"), day: get("day"), hour: get("hour"), minute: get("minute"), second: get("second") };
}

function getCairoOffsetMs(date: Date): number {
  const p = getCairoParts(date);
  return Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second) - date.getTime();
}

function cairoLocalToUtcIso(year: number, month: number, day: number, hour: number, minute = 0): string {
  const guessMs = Date.UTC(year, month - 1, day, hour, minute, 0);
  const first = new Date(guessMs - getCairoOffsetMs(new Date(guessMs)));
  const second = new Date(guessMs - getCairoOffsetMs(first));
  return second.toISOString();
}

function cairoDateStartIso(year: number, month: number, day: number): string {
  return cairoLocalToUtcIso(year, month, day, 0, 0);
}

function parseTargetDate(dateStr?: string): { targetDateStr: string; dayStartIso: string; dayEndIso: string } {
  const nowParts = getCairoParts(new Date());
  let target = new Date(Date.UTC(nowParts.year, nowParts.month - 1, nowParts.day, 12, 0, 0));

  const clean = normalizeArabicDigits((dateStr || "").trim().toLowerCase());
  if (clean.includes("بعد بكره") || clean.includes("بعد بكرة") || clean.includes("بعد غد")) {
    target.setUTCDate(target.getUTCDate() + 2);
  } else if (clean.includes("بكره") || clean.includes("بكرة") || clean.includes("غدا") || clean.includes("غداً") || clean.includes("tomorrow")) {
    target.setUTCDate(target.getUTCDate() + 1);
  } else if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) {
    const parts = clean.split("-").map(Number);
    target = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2], 12, 0, 0));
  }

  const yyyy = target.getUTCFullYear();
  const mm = String(target.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(target.getUTCDate()).padStart(2, "0");
  const targetDateStr = yyyy + "-" + mm + "-" + dd;
  const nextDay = new Date(target.getTime());
  nextDay.setUTCDate(nextDay.getUTCDate() + 1);
  const dayStartIso = cairoDateStartIso(yyyy, target.getUTCMonth() + 1, target.getUTCDate());
  const dayEndIso = cairoDateStartIso(nextDay.getUTCFullYear(), nextDay.getUTCMonth() + 1, nextDay.getUTCDate());
  return { targetDateStr, dayStartIso, dayEndIso };
}

function normalizeArabicDigits(value: string): string {
  const arabic = "٠١٢٣٤٥٦٧٨٩";
  return value.replace(/[٠-٩]/g, (d) => String(arabic.indexOf(d)));
}

function extractPreferredTimes(input: string): string[] {
  const normalized = normalizeArabicDigits((input || "").toString().toLowerCase());
  const hasTimeCue = /الساعة|ساعه|ساعة|وقت|ميعاد|موعد|احجز|الحجز|احجزلي|احجزه/.test(normalized);
  if (!hasTimeCue) return [];
  const correctionMarkers = [...normalized.matchAll(/قصدي|لأ|لا|أقصد|اقصد|بدّل|بدل|غيرت رأيي/g)].map(m => m.index ?? -1);
  const correctionIndex = correctionMarkers.length > 0 ? Math.max(...correctionMarkers) : -1;
  const effective = correctionIndex >= 0 ? normalized.slice(correctionIndex) : normalized;
  const globalPm = /مساء|مسا|\bم\b|بالليل|ليل/.test(effective);
  const globalAm = /صباح|صبح|\bص\b/.test(effective);
  const matches = new Set<string>();
  const re = /\b(\d{1,2})(?:\s*[:٫.]\s*(\d{1,2}))?\b/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(effective)) !== null) {
    let hour = Number(match[1]);
    const minute = Number(match[2] || 0);
    if (hour > 23 || minute > 59) continue;
    const after = effective.slice(match.index, Math.min(effective.length, match.index + 18));
    const explicitPm = globalPm || /مساء|مسا|\bم\b|بالليل|ليل/.test(after);
    const explicitAm = globalAm || /صباح|صبح|\bص\b/.test(after);
    if (explicitPm && hour < 12) hour += 12;
    else if (explicitAm && hour === 12) hour = 0;
    else if (!explicitAm && !explicitPm && hour >= 0 && hour <= 23) {
      // Keep the hour unresolved when AM/PM is not explicitly stated.
      matches.add(String(hour).padStart(2, "0") + ":" + String(minute).padStart(2, "0"));
      continue;
    }
    matches.add(String(hour).padStart(2, "0") + ":" + String(minute).padStart(2, "0"));
  }
  return Array.from(matches).slice(0, 4);
}

function hasDateCue(input: string): boolean {
  const normalized = normalizeArabicDigits((input || "").toString().toLowerCase());
  return /النهارده|النهاردة|اليوم|دلوقتي|حالا|حالاً|بكره|بكرة|غدا|غداً|بعد بكره|بعد بكرة|today|tomorrow/.test(normalized);
}

function isExplicitConfirmation(input: string): boolean {
  const normalized = normalizeArabicDigits((input || "").toString().toLowerCase()).trim().replace(/\s+/g, " ");
  return /^(?:ايوه|أيوه|اه|آه|تمام|ماشي|موافق|موافقة|أكد الحجز|اكد الحجز|أكدلي الحجز|اكدلي الحجز|ثبّت الحجز|ثبت الحجز|احجزه|احجزهولي|احجزه لي|نفذ الحجز|نفذه|اتفقنا)$/.test(normalized);
}

function extractTimeWindow(input: string): { type: string; label: string; from_hour: number; to_hour: number } | null {
  const normalized = normalizeArabicDigits((input || "").toString().toLowerCase());
  if (/بعد\s+العصر|بعد\s+الضهر|بعد\s+الظهر|من\s+بعد\s+العصر/.test(normalized)) {
    return { type: "after_afternoon", label: "بعد العصر", from_hour: 16, to_hour: 23 };
  }
  if (/بالليل|ليل|مساء|المساء/.test(normalized)) {
    return { type: "evening", label: "بالليل", from_hour: 20, to_hour: 23 };
  }
  return null;
}

function selectPreferredAvailableSlot(
  availableSlots: Array<{ start_time: string; end_time: string }>,
  preferredTimes: string[],
): { start_time: string; end_time: string } | null {
  if (!availableSlots.length) return null;
  if (!preferredTimes.length) return availableSlots[0];
  for (const preferred of preferredTimes) {
    const preferredHour = preferred.substring(0, 2);
    const match = availableSlots.find((slot: any) => String(slotHourFromIso(slot.start_time)).padStart(2, "0") === preferredHour);
    if (match) return match;
  }
  return null;
}

function resolveVisibleStadiumReference(contextSnapshot: Record<string, any>, input: string) {
  const visible = Array.isArray(contextSnapshot.last_visible_stadiums)
    ? contextSnapshot.last_visible_stadiums
    : [];
  if (visible.length === 0) return null;

  const normalized = normalizeArabicDigits((input || "").toString().toLowerCase()).trim();

  const ordinalPatterns = [
    /(?:^|\s)(?:اول|الأول|الاول)(?:\s|$)/,
    /(?:^|\s)(?:تاني|الثاني|التاني)(?:\s|$)/,
    /(?:^|\s)(?:تالت|الثالث|التالت)(?:\s|$)/,
    /(?:^|\s)(?:رابع|الرابع|الرابعه|الرابعة)(?:\s|$)/,
  ];

  for (let i = 0; i < ordinalPatterns.length; i++) {
    if (ordinalPatterns[i].test(normalized) && visible[i]) {
      return visible[i];
    }
  }

  // "الملعب ده/اللي فوق" is deterministic only when one stadium was visible.
  if (visible.length === 1 && /الملعب ده|الملعب دي|اللي فوق|ده الملعب|هو ده|دي هي/.test(normalized)) {
    return visible[0];
  }

  return null;
}

function mergeTaskState(contextSnapshot: Record<string, any>, userMessage: string) {
  const current = contextSnapshot.task_state && typeof contextSnapshot.task_state === "object"
    ? contextSnapshot.task_state
    : {};
  const next = { ...current };

  if (!next.stadium_id && contextSnapshot.last_stadium_id) next.stadium_id = contextSnapshot.last_stadium_id;
  if (!next.stadium_name && contextSnapshot.last_stadium_name) next.stadium_name = contextSnapshot.last_stadium_name;
  if (!next.date && contextSnapshot.last_date) next.date = contextSnapshot.last_date;

  const normalizedMessage = normalizeArabicDigits(userMessage).toLowerCase().trim();
  const correctionMatches = [...normalizedMessage.matchAll(/قصدي|لأ|لا|أقصد|اقصد|بدّل|بدل|غيرت رأيي/g)].map(m => m.index ?? -1);
  const effectiveMessage = correctionMatches.length > 0
    ? normalizedMessage.slice(Math.max(...correctionMatches))
    : normalizedMessage;

  const explicitConfirmation = isExplicitConfirmation(userMessage);

  if (hasDateCue(effectiveMessage)) next.date = parseTargetDate(effectiveMessage).targetDateStr;

  const preferredTimes = extractPreferredTimes(userMessage);
  const hasPm = /مساء|مسا|\bم\b|بالليل|ليل/.test(effectiveMessage);
  const hasAm = /صباح|صبح|\bص\b/.test(effectiveMessage);
  const timeWindow = extractTimeWindow(effectiveMessage);
  const visibleReference = resolveVisibleStadiumReference(contextSnapshot, effectiveMessage);

  if (visibleReference) {
    next.stadium_id = visibleReference.id;
    next.stadium_name = visibleReference.name;
  }

  const stateChangedBySchedule =
    hasDateCue(effectiveMessage) ||
    preferredTimes.length > 0 ||
    !!timeWindow ||
    (Array.isArray(next.preferred_times) && (hasPm || hasAm) && !normalizedMessage.match(/\b\d{1,2}\b/));

  const stateChangedByStadium = !!visibleReference;

  // A pending confirmation is valid only for the exact state it was created from.
  // Any later date/time/stadium change invalidates it before another confirmation can execute.
  if (!explicitConfirmation && (stateChangedBySchedule || stateChangedByStadium)) {
    delete next.confirmation_pending;
  }

  if (preferredTimes.length > 0) {
    next.preferred_times = preferredTimes;
    delete next.time_window;
  } else if (Array.isArray(next.preferred_times) && (hasPm || hasAm) && !normalizedMessage.match(/\b\d{1,2}\b/)) {
    next.preferred_times = next.preferred_times.map((t: string) => {
      let hour = Number(t.substring(0, 2));
      if (hasPm && hour < 12) hour += 12;
      if (hasAm && hour === 12) hour = 0;
      return String(hour).padStart(2, "0") + ":00";
    });
    delete next.time_window;
  } else if (timeWindow) {
    next.time_window = timeWindow;
    next.preferred_times = [];
    next.requires_time_clarification = false;
  }

  if (/احجز|حجز|احجزلي|احجزه|حجزلي/.test(normalizedMessage)) next.intent = "book_stadium";

  next.missing_slots = [];
  if (!next.stadium_id) next.missing_slots.push("stadium");
  if (!next.date) next.missing_slots.push("date");

  const hasExactTime = Array.isArray(next.preferred_times) && next.preferred_times.length > 0;
  const hasTimeWindow = !!next.time_window;
  if (!hasExactTime && !hasTimeWindow) next.missing_slots.push("time");

  const hasExplicitPeriod = hasPm || hasAm;
  if (hasExactTime && !hasExplicitPeriod && !hasTimeWindow) {
    next.time_period_confirmed = false;
    next.requires_time_clarification = true;
  } else {
    next.time_period_confirmed = true;
    next.requires_time_clarification = false;
  }

  next.ready_for_execution =
    next.missing_slots.length === 0 &&
    next.time_period_confirmed === true &&
    hasExactTime;

  next.updated_at = new Date().toISOString();
  contextSnapshot.task_state = next;
  return next;
}

function buildBookingMissingDateReply(taskState: Record<string, any>, userMessage: string): { message: string; quick_replies: string[] } | null {
  if (taskState?.intent !== "book_stadium") return null;
  const missing = Array.isArray(taskState?.missing_slots) ? taskState.missing_slots : [];
  if (!missing.includes("date")) return null;
  if (taskState?.confirmation_pending) return null;

  const preferred = Array.isArray(taskState?.preferred_times) ? taskState.preferred_times : [];
  if (preferred.length === 0 || taskState?.time_period_confirmed !== true) return null;

  const timeLabels = preferred.map((t: string) => {
    const hour = Number(String(t).substring(0, 2));
    const minute = Number(String(t).substring(3, 5) || 0);
    const displayHour = hour === 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    const period = hour >= 12 ? "بالليل" : "الصبح";
    return displayHour + ":" + String(minute).padStart(2, "0") + " " + period;
  });

  const timeText = timeLabels.length === 1
    ? "الساعة " + timeLabels[0]
    : "الساعة " + timeLabels.join(" أو ");

  return {
    message: "تمام، فهمت طلبك: حجز " + timeText + ". اليوم بس ناقص — تقصد النهارده ولا يوم تاني؟",
    quick_replies: ["النهارده", "بكرة"],
  };
}

function buildConversationalRecovery(
  taskState: Record<string, any>,
  contextSnapshot: Record<string, any>,
  userMessage: string,
): { message: string; quick_replies: string[] } {
  const t = normalizeArabicDigits((userMessage || "").toLowerCase()).trim();
  const missing = Array.isArray(taskState?.missing_slots) ? taskState.missing_slots : [];
  const preferred = Array.isArray(taskState?.preferred_times) ? taskState.preferred_times : [];
  const visible = Array.isArray(contextSnapshot?.last_visible_stadiums)
    ? contextSnapshot.last_visible_stadiums
    : [];

  if (taskState?.intent === "book_stadium") {
    if (taskState?.confirmation_pending) {
      const pending = taskState.confirmation_pending;
      return {
        message: "أنا فاهم الحجز المقصود: " + pending.stadium_name +
          " يوم " + formatDateForUser(pending.date) +
          " الساعة " + formatSlotTimeForUser(pending.start_time) +
          " لمدة ساعة. أأكد الحجز؟",
        quick_replies: ["أيوه، أكد الحجز", "عدّل الموعد"],
      };
    }

    if (taskState?.requires_time_clarification && preferred.length > 0) {
      const hour = Number(preferred[0].substring(0, 2));
      return {
        message: "تمام، الساعة " + hour + " وصلت. تقصدها الصبح ولا بالليل؟",
        quick_replies: [hour + ":00 الصبح", hour + ":00 بالليل"],
      };
    }

    if (missing.includes("date") && preferred.length > 0) {
      const labels = preferred.map((x: string) => {
        const h = Number(x.substring(0, 2));
        return (h === 0 ? 12 : (h > 12 ? h - 12 : h)) + ":00 " + (h >= 12 ? "بالليل" : "الصبح");
      });
      return {
        message: "فاهم إنك عايز تحجز " +
          (labels.length === 1 ? "الساعة " + labels[0] : "الساعة " + labels.join(" أو ")) +
          ". اليوم بس ناقص؛ تقصد النهارده ولا يوم تاني؟",
        quick_replies: ["النهارده", "بكرة"],
      };
    }

    if (missing.includes("time")) {
      return {
        message: "تمام، فهمت إنك عايز تحجز. فاضلي أعرف الساعة المناسبة ليك بس.",
        quick_replies: ["8 بالليل", "9 بالليل", "10 بالليل"],
      };
    }

    if (missing.includes("stadium")) {
      if (visible.length > 1) {
        return {
          message: "تمام، لقيتلك أكتر من ملعب ينفع للطلب. اختار الملعب اللي تقصده وأنا أكمل الحجز عليه.",
          quick_replies: visible.slice(0, 4).map((s: any) => s.name),
        };
      }
      return {
        message: "تمام، فاهم إنك عايز حجز. هحدد لك ملعب مناسب قريب منك وأكمل معاك الحجز.",
        quick_replies: [],
      };
    }
  }

  if (/ماتش|ملعب|حجز|بطولة|دوري|حريفة|مواعيد|متاح|شاغر/.test(t)) {
    return {
      message: "فاهمك. خلّيني أحدد المطلوب بدقة بدل ما أفترض: إنت عايز تدور على ملعب، تشوف ميعاد متاح، ولا تكمل حجز؟",
      quick_replies: ["أدور على ملعب", "أشوف المواعيد", "أكمل الحجز"],
    };
  }

  return {
    message: "فاهمك يا كابتن. قولّي عايز تعمل إيه في VSP وأنا أكمل معاك خطوة بخطوة.",
    quick_replies: ["حجز ملعب", "ملاعب قريبة", "مباريات مفتوحة", "بطولات"],
  };
}

function slotHourFromIso(iso: string): number {
  return getCairoParts(new Date(iso)).hour;
}

function slotMatchesPreferredTime(slot: { start_time: string }, preferredTimes: string[]): boolean {
  if (!preferredTimes || preferredTimes.length === 0) return true;
  const hh = String(slotHourFromIso(slot.start_time)).padStart(2, "0");
  return preferredTimes.some((t: string) => t.substring(0, 2) === hh);
}

function generateStandardSlots(targetDateStr: string) {
  const slots: { start_time: string; end_time: string; display_time: string; hour: number }[] = [];
  const parts = targetDateStr.split("-").map(Number);
  const [yyyy, month, day] = parts;
  const cairoHours = [16, 17, 18, 19, 20, 21, 22, 23, 0];

  for (const h of cairoHours) {
    const isNextDay = h === 0;
    const slotDayDate = new Date(Date.UTC(yyyy, month - 1, day + (isNextDay ? 1 : 0), 12, 0, 0));
    const slotYear = slotDayDate.getUTCFullYear();
    const slotMonth = slotDayDate.getUTCMonth() + 1;
    const slotDay = slotDayDate.getUTCDate();
    const startIso = cairoLocalToUtcIso(slotYear, slotMonth, slotDay, h, 0);
    const nextLocal = new Date(Date.UTC(slotYear, slotMonth - 1, slotDay, h + 1, 0, 0));
    const endIso = cairoLocalToUtcIso(nextLocal.getUTCFullYear(), nextLocal.getUTCMonth() + 1, nextLocal.getUTCDate(), h === 23 ? 0 : h + 1, 0);
    const displayHourStart = h === 0 ? 12 : (h > 12 ? h - 12 : h);
    const endH = (h + 1) % 24;
    const displayHourEnd = endH === 0 ? 12 : (endH > 12 ? endH - 12 : endH);
    const period = h >= 12 || h === 0 ? "م" : "ص";

    slots.push({
      start_time: startIso,
      end_time: endIso,
      display_time: displayHourStart + ":00 " + period + " - " + displayHourEnd + ":00 " + period,
      hour: h,
    });
  }
  return slots;
}

async function findAvailableSlotsForStadium(
  supabase: any,
  stadium: any,
  targetDateStr: string,
  preferredTimes: string[],
  timeWindow: any,
) {
  const target = parseTargetDate(targetDateStr);
  const { data: existingBookings } = await supabase
    .from("bookings")
    .select("start_time, end_time, status, locked_until, created_at")
    .eq("stadium_id", stadium.id)
    .neq("status", "cancelled")
    .gte("start_time", target.dayStartIso)
    .lte("start_time", target.dayEndIso);

  const activeBookings = (existingBookings || []).filter((b: any) => {
    if (b.status === "pending") {
      const lockExpire = b.locked_until
        ? new Date(b.locked_until).getTime()
        : new Date(b.created_at).getTime() + 5 * 60 * 1000;
      return lockExpire > Date.now();
    }
    return true;
  });

  const cairoNow = getCairoParts(new Date());
  const isToday =
    targetDateStr ===
    String(cairoNow.year).padStart(4, "0") + "-" +
    String(cairoNow.month).padStart(2, "0") + "-" +
    String(cairoNow.day).padStart(2, "0");

  let availableSlots = generateStandardSlots(targetDateStr).filter((slot) => {
    const sStart = new Date(slot.start_time).getTime();
    const sEnd = new Date(slot.end_time).getTime();
    if (isToday && sEnd <= Date.now()) return false;

    for (const b of activeBookings) {
      const bStart = new Date(b.start_time).getTime();
      const bEnd = new Date(b.end_time).getTime();
      if (sStart < bEnd && sEnd > bStart) return false;
    }
    return true;
  });

  if (preferredTimes.length > 0) {
    availableSlots = availableSlots.filter((slot) => slotMatchesPreferredTime(slot, preferredTimes));
  } else if (timeWindow && typeof timeWindow.from_hour === "number") {
    availableSlots = availableSlots.filter((slot) => {
      const hour = slotHourFromIso(slot.start_time);
      return hour >= timeWindow.from_hour && hour <= (timeWindow.to_hour ?? 23);
    });
  }

  return {
    targetDate: targetDateStr,
    dayStartIso: target.dayStartIso,
    dayEndIso: target.dayEndIso,
    availableSlots,
  };
}

function refreshBookingTaskState(task: Record<string, any>) {
  task.missing_slots = [];
  if (!task.stadium_id) task.missing_slots.push("stadium");
  if (!task.date) task.missing_slots.push("date");
  const hasExactTime = Array.isArray(task.preferred_times) && task.preferred_times.length > 0;
  const hasTimeWindow = !!task.time_window;
  if (!hasExactTime && !hasTimeWindow) task.missing_slots.push("time");
  task.ready_for_execution =
    task.missing_slots.length === 0 &&
    task.time_period_confirmed === true &&
    hasExactTime;
  return task;
}

function ownerFactNorm(value: string): string {
  return normalizeArabicDigits((value || "").toString().toLowerCase()).trim().replace(/\s+/g, " ");
}

function isOwnerFactQuestion(input: string): boolean {
  return /كام|قد ايه|قد إيه|اعرف|عايز اعرف|عايز أعرف|إيراد|ايراد|دخل|دخلي|عملت|فلوس|رصيد|رصيدي|مديون|مستحق|حجوزات|حجز|دافع|دفع|تحصيل|محصل|داخل|داخلين|فاضي|متاح/.test(ownerFactNorm(input));
}

function detectOwnerFinancialMetric(input: string): string | null {
  const t = ownerFactNorm(input);
  const m: string[] = [];
  if (/الرصيد|رصيدي|المتاح للسحب|متاح للسحب|أقدر اسحب|اقدر اسحب/.test(t)) m.push("available_balance");
  if (/الكاش|كاش|نقدي|نقد|التحصيل الكاش|الكاش المحصل/.test(t)) m.push("cash_collected");
  if (/اونلاين|أونلاين|الكتروني|إلكتروني/.test(t)) m.push("owner_online_earnings");
  if (/إجمالي التحصيل|اجمالي التحصيل|كل الإيراد|كل التحصيل/.test(t)) m.push("owner_total_revenue");
  if (/عدد الحجوزات|كام حجز|كم حجز|عدد الحجز/.test(t)) m.push("completed_booking_count");
  if (/قيمة الحجوزات|اجمالي قيمة الحجوزات|إجمالي قيمة الحجوزات/.test(t)) m.push("completed_booking_value");
  const u = [...new Set(m)];
  return u.length === 1 ? u[0] : null;
}

function detectOwnerFinancialPeriod(input: string): string | null {
  const t = ownerFactNorm(input);
  if (/النهارده|النهاردة|اليوم|اليوم ده/.test(t)) return "today";
  if (/امبارح|امبارحة|مبارح/.test(t)) return "yesterday";
  if (/آخر 7 أيام|اخر 7 ايام|السبع أيام|الاسبوع الأخير|الأسبوع الأخير/.test(t)) return "last_7_days";
  if (/الأسبوع ده|الاسبوع ده|هذا الأسبوع|الاسبوع الحالي|الأسبوع الحالي/.test(t)) return "current_week";
  if (/من أول الشهر|من اول الشهر|الشهر ده|هذا الشهر|الشهر الحالي/.test(t)) return "current_month";
  if (/الشهر اللي فات|الشهر الماضي/.test(t)) return "last_month";
  if (/من أول ما بدأت|من اول ما بدأت|إجمالي كل الوقت|اجمالي كل الوقت|كل الوقت|الإجمالي الكلي|الاجمالي الكلي/.test(t)) return "all_time";
  return null;
}

function cairoDateKey(offsetDays = 0): string {
  const p = getCairoParts(new Date());
  const d = new Date(Date.UTC(p.year, p.month - 1, p.day + offsetDays, 12, 0, 0));
  return d.getUTCFullYear() + "-" + String(d.getUTCMonth() + 1).padStart(2, "0") + "-" + String(d.getUTCDate()).padStart(2, "0");
}

function ownerCurrentWeekStartKey(): string {
  const p = getCairoParts(new Date());
  const d = new Date(Date.UTC(p.year, p.month - 1, p.day, 12, 0, 0));
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 1) % 7));
  return d.getUTCFullYear() + "-" + String(d.getUTCMonth() + 1).padStart(2, "0") + "-" + String(d.getUTCDate()).padStart(2, "0");
}

function resolveOwnerFinancialRange(period: string): { start: string; end: string; label: string } | null {
  if (period === "today") return { start: cairoDateKey(), end: cairoDateKey(), label: "اليوم" };
  if (period === "yesterday") return { start: cairoDateKey(-1), end: cairoDateKey(-1), label: "أمس" };
  if (period === "last_7_days") return { start: cairoDateKey(-6), end: cairoDateKey(), label: "آخر 7 أيام" };
  if (period === "current_week") return { start: ownerCurrentWeekStartKey(), end: cairoDateKey(), label: "هذا الأسبوع (من السبت حتى اليوم)" };
  if (period === "current_month") { const p = getCairoParts(new Date()); return { start: p.year + "-" + String(p.month).padStart(2, "0") + "-01", end: cairoDateKey(), label: "من أول الشهر حتى اليوم" }; }
  if (period === "last_month") { const p = getCairoParts(new Date()); const first = new Date(Date.UTC(p.year, p.month - 2, 1, 12)); const last = new Date(Date.UTC(p.year, p.month - 1, 0, 12)); return { start: first.getUTCFullYear() + "-" + String(first.getUTCMonth() + 1).padStart(2, "0") + "-01", end: last.getUTCFullYear() + "-" + String(last.getUTCMonth() + 1).padStart(2, "0") + "-" + String(last.getUTCDate()).padStart(2, "0"), label: "الشهر الماضي" }; }
  if (period === "all_time") return { start: "1900-01-01", end: cairoDateKey(), label: "من بداية السجل حتى اليوم" };
  return null;
}

function buildOwnerPrecisionClarification(userMessage: string) {
  const t = ownerFactNorm(userMessage);
  const financialSignal = /دخل|دخلي|إيراد|ايراد|فلوس|رصيد|رصيدي|مديون|مستحق|كاش|اونلاين|أونلاين|عمولة|رسوم/.test(t);
  if (financialSignal) {
    const metric = detectOwnerFinancialMetric(userMessage);
    const period = detectOwnerFinancialPeriod(userMessage);
    const currentOnly = metric === "available_balance";
    if (!metric) return { needs_clarification: true, message: "عشان أديك رقم صحيح من غير تخمين: تقصد الرصيد المتاح، ولا الكاش المحصل، ولا إيراد الأونلاين، ولا إجمالي التحصيل؟", quick_replies: ["الرصيد المتاح", "الكاش المحصل", "إيراد الأونلاين", "إجمالي التحصيل"] };
    if (!currentOnly && !period) return { needs_clarification: true, message: "حددلي الفترة عشان أطلع لك الرقم الدقيق: النهارده، آخر 7 أيام، من أول الشهر، ولا إجمالي السجل؟", quick_replies: ["النهارده", "آخر 7 أيام", "من أول الشهر", "إجمالي السجل"] };
  }
  if (/كام حجز|كم حجز|عدد الحجوزات|حجوزات/.test(t) && !detectOwnerFinancialPeriod(userMessage) && !/النهارده|النهاردة|اليوم|بكرة|بكره|غدا|غداً|امبارح|مبارح|الأسبوع|الاسبوع|الشهر|آخر 7 أيام|اخر 7 ايام/.test(t))
    return { needs_clarification: true, message: "تقصد عدد الحجوزات النهارده، ولا خلال فترة معينة؟", quick_replies: ["حجوزات النهارده", "هذا الأسبوع", "من أول الشهر"] };
  if (/مين داخل|مين حاجز|مين عندي الساعة|مين داخل عندي|مين حاجز عندي/.test(t) && !/النهارده|النهاردة|اليوم|بكرة|بكره|غدا|غداً|امبارح|مبارح/.test(t))
    return { needs_clarification: true, message: "حدد اليوم الأول عشان أقولك مين داخل بالضبط.", quick_replies: ["النهارده", "بكرة"] };
  const hasExplicitPeriod = /مساء|مسا|بالليل|ليل|صباح|صبح/.test(t);
  const requestedTimes = extractPreferredTimes(userMessage);
  if (/الساعة\s*\d{1,2}|ساعه\s*\d{1,2}/.test(t) && !/النهارده|النهاردة|اليوم|بكرة|بكره|غدا|غداً|امبارح|مبارح/.test(t))
    return { needs_clarification: true, message: "الساعة وصلت، بس اليوم ناقص. تقصد النهارده ولا يوم تاني؟", quick_replies: ["النهارده", "بكرة"] };
  if (requestedTimes.length > 0 && !hasExplicitPeriod && /الساعة|ساعه/.test(t))
    return { needs_clarification: true, message: "حدد الساعة الصبح ولا بالليل عشان أحدد الحجز الصحيح.", quick_replies: ["10 الصبح", "10 بالليل"] };
  return null;
}
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
    const requestedGov = (body.governorate ?? "").toString().trim();

    if (!userMessage) {
      return new Response(
        JSON.stringify({ error: "Bad Request: message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch caller user profile from DB to personalize and bind governorate
    const { data: userProfile } = await supabase
      .from("users")
      .select("name, governorate, position, role")
      .eq("id", callerUser.id)
      .maybeSingle();

    // Fetch caller user's last 3 bookings for personalization
    const { data: recentUserBookings } = await supabase
      .from("bookings")
      .select("stadium_name, start_time, status, total_price")
      .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
      .order("created_at", { ascending: false })
      .limit(3);

    const userGov = requestedGov || userProfile?.governorate || "أسوان";
    const userName = userProfile?.name || "يا كابتن";
    const userPosition = userProfile?.position || "مهاجم";

    // 7. Conversation Session Management & Context Snapshot
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
      const generatedTitle = userMessage.length > 35
        ? userMessage.substring(0, 35) + "..."
        : userMessage;

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

    // 8. Build Multi-Turn History for Gemini
    const taskState = mergeTaskState(contextSnapshot, userMessage);

    const { data: priorMessages } = await supabase
      .from("copilot_messages")
      .select("role, content, stadium_results, ui_metadata")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true })
      .limit(10);

    const contents: any[] = [];
    if (priorMessages && priorMessages.length > 0) {
      for (const msg of priorMessages) {
        let historyText = msg.content;
        if (msg.role === "assistant") {
          const ui = msg.ui_metadata || {};
          const storedStadiums = Array.isArray(msg.stadium_results) && msg.stadium_results.length > 0
            ? msg.stadium_results
            : (Array.isArray(ui.stadiums) ? ui.stadiums : []);
          const visible = {
            stadiums: storedStadiums,
            tournaments: Array.isArray(ui.tournaments) ? ui.tournaments : [],
            open_matches: Array.isArray(ui.open_matches) ? ui.open_matches : [],
            action: ui.action || null,
          };
          if ((visible.stadiums && visible.stadiums.length > 0) || (visible.tournaments && visible.tournaments.length > 0) || (visible.open_matches && visible.open_matches.length > 0) || visible.action) {
            historyText += "\n[UI_CONTEXT_INTERNAL]" + JSON.stringify(visible) + "[/UI_CONTEXT_INTERNAL]";
          }
        }
        contents.push({
          role: msg.role === "user" ? "user" : "model",
          parts: [{ text: historyText }],
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

    // 9. Deterministic owner factual-query guard.
    const ownerRole = normalizeCopilotRole(userProfile?.role);
    const ownerPrecisionClarification = ownerRole === "owner" ? buildOwnerPrecisionClarification(userMessage) : null;
    let forcedOwnerTool: string | null = null;

    if (ownerRole === "owner" && !ownerPrecisionClarification?.needs_clarification) {
      const t = ownerFactNorm(userMessage);
      const financialSignal = /دخل|دخلي|إيراد|ايراد|فلوس|رصيد|رصيدي|مديون|مستحق|كاش|اونلاين|أونلاين|عمولة|رسوم/.test(t);
      if (financialSignal && detectOwnerFinancialMetric(userMessage)) forcedOwnerTool = "getOwnerFinancialInsights";
      else if (/كام حجز|كم حجز|عدد الحجوزات|مين داخل|مين حاجز|مين عندي|فاضي|متاح/.test(t)) forcedOwnerTool = "getOwnerStadiumsAndBookings";
    }

    if (ownerPrecisionClarification?.needs_clarification) {
      assistantReply = ownerPrecisionClarification.message;
      quickReplies = ownerPrecisionClarification.quick_replies || [];
      handledByGemini = true;
    }

    // 10. Gemini 2.5 Flash Interaction
    if (!handledByGemini && geminiApiKey) {
      try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
        const systemPrompt = `أنت "كابتن VSP"، المساعد والمدير الذكي الشامل والوكيل التشغيلي لتطبيق VSP لحجز الملاعب والبطولات في مصر (Omni-Capable In-App Operating Agent).
تتحدث باللهجة المصرية بشكل طبيعي، ودود ومختصر. استخدم "يا كابتن" عند الحاجة وبحد أقصى مرة واحدة في بداية الرد. لا تكرر ألقاباً شعبية متعددة في نفس الرد.

سياق المستخدم الحالي:
- اسم المستخدم: ${userName}
- دور المستخدم: ${userProfile?.role || 'لاعب'}
- المحافظة الحالية: ${userGov}
- المركز المفضل: ${userPosition}
- آخر 3 حجوزات للمستخدم: ${recentUserBookings && recentUserBookings.length > 0 ? recentUserBookings.map((b: any) => `${b.stadium_name} (${b.start_time})`).join("، ") : "لا توجد حجوزات سابقة بعد"}
عندما يسأل المستخدم عن ملاعب قريبة، أو ملاعب للحجز، أو ماتشات، أو بطولات دون ذكر محافظة معينة، استخدم محافظته الحالية (${userGov}) كخيار افتراضي للبحث والتحقق!

ذاكرة وسياق المحادثة المحفوظ (Conversation State & Context Snapshot):
${JSON.stringify(contextSnapshot, null, 2)}
حالة المهمة الحالية (Task State):
${JSON.stringify(taskState, null, 2)}

قاعدة صلاحيات الدور (ROLE CAPABILITY POLICY):
- صلاحيات الأدوات التشغيلية يحددها السيرفر حسب دور الحساب، وليست اجتهاداً منك.
- لا تقل أبداً إن المستخدم يستطيع تنفيذ ميزة أو فتح شاشة لا يسمح بها دوره.
- إذا كان السؤال عاماً عن ميزة تخص دوراً آخر، يمكنك شرحها كمعلومة عامة، لكن لا تعرض بيانات خاصة ولا تنفذ إجراءً خارج صلاحيات الحساب.
- اللاعب: الملاعب والحجز، البطولات، 1v1، المباريات المفتوحة، ملفه وحجوزاته.
- مالك الملعب: إدارة ملاعبه، حجوزاته، الحسابات المالية والبروفايل.
- إذا طلب المستخدم عملية ليست متاحة لدوره، وضّح ذلك ووجّهه إلى ما يستطيع فعله بدلاً من اختراع مسار بديل.

قواعد استمرارية السياق:
- إذا كان هناك ملعب واحد فقط في آخر النتائج أو UI_CONTEXT_INTERNAL، وعبارة المستخدم تشير إليه مثل "الملعب ده" أو "احجزه" أو "احجزلي"، اعتبره المقصود تلقائياً.
- إذا كانت هناك عدة ملاعب، لا تخمّن؛ اطلب تحديد الملعب.
- لا تعيد سؤال slot موجود بالفعل في Task State إلا إذا غيّره المستخدم أو أصبح غير صالح.
- إذا قال المستخدم "10 أو 11"، فهذه تفضيلات مرتبة وليست إذناً بالحجز. افحص الوقت الأول ثم البديل؛ إذا كان الأول متاحاً اقترحه، وإذا لم يكن متاحاً استخدم البديل، ثم اعرض ملخص الحجز واطلب تأكيداً نهائياً قبل التنفيذ.
- إذا قال المستخدم "10 أو 11 بالليل"، اعتبرهما تفضيلين مرتبّين: افحص 10 أولاً، وإذا لم يتوفر افحص 11. لا تنفذ الحجز قبل عرض الموعد المقترح وطلب التأكيد النهائي.
- إذا قال المستخدم "بعد العصر" أو "بالليل" بدون ساعة محددة، اعتبرها نافذة زمنية وليست ساعة واحدة؛ افحص الفترات الحقيقية داخل النافذة ثم اعرض الخيارات المتاحة بدل اختيار ساعة من نفسك.
- إذا قال المستخدم "10" فقط دون صباح/مساء، لا تفترض الفترة. اطلب: "تقصد 10 الصبح ولا 10 بالليل؟"
- إذا قال "قصدي..." أو "لأ..." أو صحح نفسه، اعتبر الجزء الأخير هو المعتمد وتجاهل القيمة المصححة السابقة لنفس الحقل.
- بعد الوصول إلى موعد قابل للحجز، استخدم تأكيداً ذكياً بصيغة طبيعية: اذكر الملعب + اليوم + الساعة + المدة، ثم اطلب تأكيداً واحداً قبل التنفيذ.
- لو قال المستخدم "طب ما أنا لسه قايلك" أو "ما أنا قلتلك"، لا تعيد السؤال من البداية. راجع السياق فوراً، استخرج المعلومة السابقة، وامتص الاعتذار في جملة قصيرة ثم أكمل المهمة.
- تعامل مع العامية والتصحيح داخل نفس الرسالة كمعنى واحد؛ مثال: "دلوقتي... لأ قصدي النهاردة" يعني اعتمد "النهاردة" للحقل المصحح.
- أمثلة واقعية:
  المستخدم: "عايز أحجز دلوقتي قصدي النهاردة الساعة 10 11 بالليل لو لقيت"
  الاستنتاج: اليوم؛ 22:00 كخيار أول و23:00 كبديل؛ افحص التوفر؛ اقترح أول خيار متاح؛ اطلب التأكيد.
  المستخدم: "طب ما انت عرضت عليا الملعب فوق"
  الاستنتاج: الملعب الوحيد الظاهر في السياق السابق هو المقصود.
  المستخدم: "خلاص خليها بكرة بعد العصر كده"
  الاستنتاج: غداً؛ نطاق زمني تقريبي، ولا تحوله إلى ساعة دقيقة إلا بعد التحقق أو طلب تضييق النطاق.

قواعد الحقيقة المالية للمالك (OWNER FINANCIAL FACTS):
1. نموذج المالك الحالي هو اشتراك فقط: لا توجد عمولة حجز على المالك.
2. قيمة الحجز المكتملة والمدفوعة هي دخل المالك من الحجز بكامل قيمة الحجز.
3. رسوم بوابة الدفع تكلفة تشغيلية على VSP ولا تُخصم من مستحق المالك.
4. لا تستخدم "Net Profit" أو "صافي بعد الخصم" كرقم مالي للمالك.
5. الرصيد المتاح للسحب هو المبلغ الأونلاين المكتمل المتاح بعد التسويات وطلبات السحب فقط.
6. الكاش المحصل هو كامل الكاش المدفوع للملعب.
7. عند سؤال المالك عن "دخلي" أو "إيرادي" بدون تعريف، اطلب تحديد نوع الدخل والفترة بدل التخمين.
8. لا تعرض رقماً خارج fact_type/value القادم من مصدر البيانات المالي.
9. إذا كان المصدر فاشلاً أو المعنى غامضاً، لا تختلق رقماً أو تفسيراً بديلاً.
10. إذا حُدد ملعب، يجب أن تكون البيانات محصورة في ملعب تابع لهذا المالك.

قواعد صارمة جداً لرفض الأسئلة الخارجة عن نطاق التطبيق (STRICT OUT-OF-SCOPE REFUSAL POLICY):
1. أنت وكيل رياضي وتشغيلي حصري لتطبيق VSP فقط (حجز الملاعب، إدارة ملاعب المالكين، البطولات، دوري الحريفة 1v1، والعمليات المالية في التطبيق).
2. ممنوع منعاً باتاً الإجابة عن أي أسئلة خارجة عن هذا النطاق إطلاقاً، مثل:
   - الطبخ، الأكلات، الوصفات والمطاعم الخارجية.
   - السياسة، الأحداث الجارية، والأخبار العامة.
   - كتابة الأكواد والبرمجة العامة (إلا ما يتعلق بتطبيق VSP).
   - المواد الدراسية، المسائل العلمية، الرياضيات، الفيزياء، الفلك، الفلسفة.
   - الفن، الأفلام، المسلسلات، الأغاني، أو أي موضوع عام لا يخص تطبيق VSP.
3. عند طرح أي سؤال خارج هذا النطاق، يجب أن ترفض فوراً بلباقة وبنص واضح:
   "عذراً يا كابتن! أنا "كابتن VSP"، مساعدك الرياضي المتخصص فقط في تطبيق VSP لحجز وإدارة الملاعب والبطولات في مصر ⚽. مقدرش أساعدك غير في اللي يخص ملاعبك وحجوزاتك وخدمات التطبيق يا بطل!"

قاعدة الحقيقة المطلقة والنزاهة الصارمة (STRICT ZERO-HALLUCINATION POLICY):
1. استخدم فقط البيانات التي تعيدها الأدوات والسياق المرفق لك.
2. ممنوع اختلاق أو افتراض أي ملعب أو بطولة أو مباراة أو موعد أو سعر أو اسم لاعب أو رقم مالي غير موجود في نتائج الأدوات أو السياق.
3. عند فحص التوافر، استخدم checkStadiumAvailability واذكر فقط الفترات التي تعيدها الأداة.
4. عند طلب حجز بوقت واحد واضح، استخدم createBookingFromChat بعد التحقق من البيانات المطلوبة. إذا ذكر المستخدم أكثر من وقت بديل مثل "10 أو 11"، افحص التوافر أولاً ثم اطلب اختيار وقت واحد، ولا تختَر ساعة من نفسك.
5. لا تذكر للمستخدم مصدر البيانات أو البنية الداخلية: ممنوع "من بيانات VSP" أو "من قاعدة البيانات" أو "من السيستم" أو "من الـAPI" أو أي وصف تقني مشابه.
6. إذا لم توجد نتائج، قل ذلك مباشرة وبأسلوب طبيعي، بدون الإيحاء بوجود نتائج غير موجودة.
7. لمالك الملعب، استخدم أدوات المالك للبيانات الفعلية، لكن اعرض النتيجة بشكل طبيعي دون الإشارة إلى قاعدة البيانات أو آلية الاستعلام.
قاعدة إلزامية وصارمة لاستدعاء الأدوات:
عندما يسأل أو يطلب المستخدم أي شيء يتعلق بالوظائف التالية، استدعِ الأداة المناسبة فوراً دون تأليف:
1. بطولات أو كؤوس أو جوائز أو بطولات فردية (1v1): استدعِ searchTournaments فوراً.
2. ماتشات ناقصة لاعيبة أو تقسيمة: استدعِ getOpenMatches فوراً.
3. الأول أو الترتيب أو دوري 1v1 أو النقاط: استدعِ get1v1Leaderboard فوراً.
4. البحث عن ملاعب أو أسعار كلاعب: استدعِ searchStadiums فوراً.
5. فحص التوافر أو المواعيد الشاغرة أو وقت محدد لملعب: استدعِ checkStadiumAvailability فوراً.
6. حجز ملعب أو تأكيد موعد من داخل الشات: استدعِ createBookingFromChat فوراً.
7. تغيير المركز أو تعديل بيانات الملف الشخصي: استدعِ updateUserProfile فوراً.
8. الاستفسار عن حجز، فلوس، استرداد أموال للاعب: استدعِ getUserBookingsAndRefunds فوراً.
9. مالك ملعب يسأل عن ملاعبه أو حجوزات ملعبه: استدعِ getOwnerStadiumsAndBookings فوراً.
10. مالك ملعب يسأل عن أرباحه، رصيده المتاح، فلوسه، دخله، الكاش، مديونيته: استدعِ getOwnerFinancialInsights فوراً.
11. طلب الذهاب لشاشة معينة: استدعِ executeAppAction فوراً.

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
            const taskNow = contextSnapshot.task_state || {};
            const forcedConfirmation =
              isExplicitConfirmation(userMessage) &&
              !!taskNow.confirmation_pending;

            // Deterministic orchestration:
            // booking intent with complete exact-time slots must always check live
            // availability before any booking tool can be executed.
            const forcedAvailability =
              !forcedConfirmation &&
              taskNow.intent === "book_stadium" &&
              taskNow.ready_for_execution === true &&
              !taskNow.confirmation_pending;

            const funcName = forcedConfirmation
              ? "createBookingFromChat"
              : (forcedAvailability
                  ? "checkStadiumAvailability"
                  : (forcedOwnerTool || functionCallPart.functionCall.name));

            const args = forcedConfirmation
              ? {
                  stadium_id: taskNow.confirmation_pending.stadium_id,
                  start_time: taskNow.confirmation_pending.start_time,
                  end_time: taskNow.confirmation_pending.end_time,
                  confirm: true,
                }
              : (forcedAvailability
                  ? {
                      stadium_id: taskNow.stadium_id,
                      stadium_name: taskNow.stadium_name,
                      date: taskNow.date,
                      time_preference: Array.isArray(taskNow.preferred_times)
                        ? taskNow.preferred_times.join(" أو ")
                        : "",
                    }
                  : (functionCallPart.functionCall.args || {}));
            let toolResponseData: any = {};
            const toolExecutionBlocked = !isCopilotToolAllowed(userProfile?.role, funcName);

            if (toolExecutionBlocked) {
              toolResponseData = {
                success: false,
                code: "CAPABILITY_DENIED",
                message: "الإجراء ده مش متاح لنوع الحساب ده.",
              };
            } else if (funcName === "searchStadiums") {
              let governorate = (args.governorate || "").toString().trim();
              if (!governorate || governorate.includes("قريب") || governorate.includes("هنا") || governorate.includes("عندي")) {
                governorate = userGov;
              }
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

              contextSnapshot.last_searched_governorate = governorate;
              contextSnapshot.last_visible_stadiums = stadiumResults.map((s: any) => ({
                id: s.id,
                name: s.name,
                governorate: s.governorate,
                price_per_hour: s.price_per_hour,
                image_url: s.image_url,
                rating: s.rating,
              }));

              const currentTask = contextSnapshot.task_state || {};
              const requestedDate = currentTask.date;
              const requestedTimes = Array.isArray(currentTask.preferred_times) ? currentTask.preferred_times : [];
              const requestedWindow = currentTask.time_window || null;
              const hasScheduleConstraint =
                !!requestedDate && (requestedTimes.length > 0 || !!requestedWindow);

              if (stadiumResults.length === 1) {
                const only = stadiumResults[0];
                contextSnapshot.last_stadium_id = only.id;
                contextSnapshot.last_stadium_name = only.name;
                currentTask.stadium_id = only.id;
                currentTask.stadium_name = only.name;
                refreshBookingTaskState(currentTask);
              } else {
                delete contextSnapshot.last_stadium_id;
                delete contextSnapshot.last_stadium_name;
                delete currentTask.stadium_id;
                delete currentTask.stadium_name;
                refreshBookingTaskState(currentTask);
              }

              // Do not stop at discovery when the user already supplied a date/time.
              // Automatically check real availability for the best candidates.
              const availabilityCandidates = stadiumResults.slice(0, 5);
              const availabilityMatches: any[] = [];
              if (hasScheduleConstraint && availabilityCandidates.length > 0) {
                const checks = await Promise.all(availabilityCandidates.map(async (stadium: any) => {
                  try {
                    const availability = await findAvailableSlotsForStadium(
                      supabase,
                      stadium,
                      requestedDate,
                      requestedTimes,
                      requestedWindow,
                    );
                    return { stadium, ...availability };
                  } catch (_) {
                    return { stadium, targetDate: requestedDate, availableSlots: [] };
                  }
                }));

                for (const check of checks) {
                  if (Array.isArray(check.availableSlots) && check.availableSlots.length > 0) {
                    availabilityMatches.push(check);
                  }
                }

                toolResponseData = {
                  count: stadiumResults.length,
                  governorate,
                  stadiums: stadiumResults,
                  schedule_checked: true,
                  schedule_date: requestedDate,
                  schedule_matches: availabilityMatches.map((m: any) => ({
                    stadium_id: m.stadium.id,
                    stadium_name: m.stadium.name,
                    price_per_hour: m.stadium.price_per_hour,
                    available_slots: m.availableSlots,
                  })),
                };

                // One matching stadium: continue the booking flow automatically.
                if (availabilityMatches.length === 1) {
                  const match = availabilityMatches[0];
                  currentTask.stadium_id = match.stadium.id;
                  currentTask.stadium_name = match.stadium.name;
                  contextSnapshot.last_stadium_id = match.stadium.id;
                  contextSnapshot.last_stadium_name = match.stadium.name;
                  contextSnapshot.last_date = requestedDate;
                  contextSnapshot.last_available_slots = match.availableSlots;

                  const proposedSlot = requestedTimes.length > 0
                    ? selectPreferredAvailableSlot(match.availableSlots, requestedTimes)
                    : null;

                  if (currentTask.intent === "book_stadium" && proposedSlot) {
                    currentTask.confirmation_pending = {
                      stadium_id: match.stadium.id,
                      stadium_name: match.stadium.name,
                      date: requestedDate,
                      start_time: proposedSlot.start_time,
                      end_time: proposedSlot.end_time,
                      price_per_hour: match.stadium.price_per_hour,
                    };
                    appAction = {
                      action_type: "CONFIRM_BOOKING",
                      route: "/bookings",
                      label: "تأكيد الحجز",
                      params: { message: "أيوه، أكد الحجز" },
                    };
                  }
                  refreshBookingTaskState(currentTask);
                } else {
                  // Multiple matches: present choices, never select one silently.
                  quickReplies = availabilityMatches.slice(0, 4).map((m: any) => m.stadium.name);
                }
              } else {
                toolResponseData = {
                  count: stadiumResults.length,
                  governorate,
                  stadiums: stadiumResults,
                  schedule_checked: false,
                };
              }

              contextSnapshot.task_state = currentTask;

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
              const requestedRoute = (args.route || "/tournaments").toString().trim();
              if (!isCopilotRouteAllowed(userProfile?.role, requestedRoute)) {
                toolResponseData = {
                  success: false,
                  code: "CAPABILITY_DENIED",
                  message: "الشاشة دي مش متاحة لنوع الحساب ده.",
                };
              } else {
                appAction = {
                  action_type: args.action_type || "NAVIGATE",
                  route: requestedRoute,
                  label: args.label || "فتح الشاشة",
                };
                toolResponseData = { status: "ready_to_navigate", action: appAction };
              }

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
                  message: "تم تحديث بيانات البروفايل بنجاح",
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

            } else if (funcName === "getOwnerStadiumsAndBookings") {
              const { data: ownerStadiums } = await supabase
                .from("stadiums")
                .select("id, name, governorate, price_per_hour, is_verified, is_blocked")
                .eq("owner_id", callerUser.id)
                .eq("is_deleted_by_owner", false);

              const stadiumIds = (ownerStadiums || []).map((s: any) => s.id);
              let ownerBookings: any[] = [];
              let ownerBookingsTotal = 0;
              if (stadiumIds.length > 0) {
                let bQuery = supabase
                  .from("bookings")
                  .select("id, stadium_id, stadium_name, start_time, end_time, status, total_price, deposit_paid, payment_method, payment_status, is_paid, player_name, player_phone", { count: "exact" })
                  .or(`owner_id.eq.${callerUser.id},stadium_id.in.(${stadiumIds.join(",")})`);

                if (args.status && args.status !== "all") {
                  bQuery = bQuery.eq("status", args.status);
                }
                if (args.payment_status && args.payment_status !== "all") {
                  bQuery = bQuery.eq("payment_status", args.payment_status);
                }

                const requestedOwnerStadiumId = (args.stadium_id || "").toString().trim();
                const requestedOwnerStadiumName = (args.stadium_name || "").toString().trim();
                if (requestedOwnerStadiumId) {
                  const ownStadium = (ownerStadiums || []).find((s: any) => s.id === requestedOwnerStadiumId);
                  if (ownStadium) bQuery = bQuery.eq("stadium_id", ownStadium.id);
                  else toolResponseData = { success: false, code: "STADIUM_NOT_FOUND", needs_clarification: true, message: "الملعب ده مش تابع لحسابك، فمش هفترضه." };
                } else if (requestedOwnerStadiumName) {
                  const matches = (ownerStadiums || []).filter((s: any) => ownerFactNorm(s.name).includes(ownerFactNorm(requestedOwnerStadiumName)));
                  if (matches.length === 1) bQuery = bQuery.eq("stadium_id", matches[0].id);
                  else if (matches.length === 0) toolResponseData = { success: false, code: "STADIUM_NOT_FOUND", needs_clarification: true, message: "الملعب المطلوب مش مسجل باسمك." };
                  else toolResponseData = { success: false, code: "STADIUM_AMBIGUOUS", needs_clarification: true, message: "في أكتر من ملعب مطابق للاسم، فمش هفترض واحد منهم." };
                }

                const detectedOwnerBookingPeriod = detectOwnerFinancialPeriod(userMessage);
                const ownerQueryType = (detectedOwnerBookingPeriod || (args.query_type || "all")).toString().toLowerCase();
                const ownerMessageText = ownerFactNorm(userMessage);
                const bookingDateInput = /بكره|بكرة|غدا|غداً/.test(ownerMessageText) ? "بكرة" : /امبارح|امبارحة|مبارح/.test(ownerMessageText) ? "امبارح" : /النهارده|النهاردة|اليوم/.test(ownerMessageText) ? "اليوم" : "";
                if (bookingDateInput) {
                  const bookingWindow = parseTargetDate(bookingDateInput);
                  bQuery = bQuery.gte("start_time", bookingWindow.dayStartIso).lt("start_time", bookingWindow.dayEndIso);
                } else if (ownerQueryType === "current_week" || ownerQueryType === "current_month" || ownerQueryType === "last_7_days" || ownerQueryType === "last_month") {
                  const bookingRange = resolveOwnerFinancialRange(ownerQueryType);
                  if (bookingRange) bQuery = bQuery.gte("operational_date", bookingRange.start).lte("operational_date", bookingRange.end);
                }

                const ownerRequestedTimes = extractPreferredTimes(userMessage);
                const ownerHasExplicitPeriod = /مساء|مسا|بالليل|ليل|صباح|صبح/.test(ownerMessageText);
                if (bookingDateInput && ownerRequestedTimes.length === 1 && ownerHasExplicitPeriod) {
                  const bookingTarget = parseTargetDate(bookingDateInput);
                  const dateParts = bookingTarget.targetDateStr.split("-").map(Number);
                  const timeParts = ownerRequestedTimes[0].split(":").map(Number);
                  const requestedStart = cairoLocalToUtcIso(dateParts[0], dateParts[1], dateParts[2], timeParts[0], timeParts[1] || 0);
                  const endHour = (timeParts[0] + 1) % 24;
                  const endDay = dateParts[2] + (timeParts[0] === 23 ? 1 : 0);
                  const requestedEnd = cairoLocalToUtcIso(dateParts[0], dateParts[1], endDay, endHour, timeParts[1] || 0);
                  bQuery = bQuery.gte("start_time", requestedStart).lt("start_time", requestedEnd);
                }

                if (!toolResponseData?.needs_clarification) {
                  const { data: bList, count: bCount, error: bErr } = await bQuery
                    .order("start_time", { ascending: true })
                    .limit(50);
                  if (bErr) {
                    toolResponseData = { success: false, code: "OWNER_BOOKINGS_QUERY_ERROR", needs_clarification: false, message: "تعذر قراءة الحجوزات بدقة حالياً." };
                  } else {
                    ownerBookings = bList || [];
                    ownerBookingsTotal = bCount ?? ownerBookings.length;
                  }
                }
              }

              appAction = {
                action_type: "NAVIGATE",
                route: "/bookings",
                label: "فتح جدول حجوزات الملاعب 📅",
              };

              if (!toolResponseData?.success && toolResponseData?.code) {
                // Preserve a deterministic query/scope failure; never replace it with a fake zero.
              } else {
                toolResponseData = {
                  success: true,
                  owner_stadiums_count: (ownerStadiums || []).length,
                  owner_stadiums: ownerStadiums || [],
                  bookings_count: ownerBookingsTotal,
                  details_truncated: ownerBookingsTotal > ownerBookings.length,
                  count_definition: "العدد إجمالي ومطابق للفلاتر المطلوبة، وليس عدد الصفوف المعروضة فقط.",
                  recent_bookings: ownerBookings,
                };
              }

            } else if (funcName === "getOwnerFinancialInsights") {
              const ownerMetric = detectOwnerFinancialMetric(userMessage) || (args.metric || "").toString().trim().toLowerCase();
              const ownerPeriod = detectOwnerFinancialPeriod(userMessage) || (args.period || "").toString().trim().toLowerCase();
              const currentMetric = ownerMetric === "available_balance";
              const validOwnerMetrics = ["available_balance","owner_online_earnings","completed_booking_value","completed_booking_count","cash_collected","owner_total_revenue"];
              const ownerMetricValid = validOwnerMetrics.includes(ownerMetric);
              const ownerPeriodRange = resolveOwnerFinancialRange(ownerPeriod);
              const ownerNeedsHistoricalFacts = ownerMetricValid && !currentMetric && !!ownerPeriodRange;
              const { data: finSummary, error: finErr } = await supabase.rpc("get_owner_financial_summary", {
                p_owner_id: callerUser.id,
              });

              appAction = {
                action_type: "NAVIGATE",
                route: "/ledger",
                label: "فتح السجل المالي والمستحقات 💰",
              };

              toolResponseData = finSummary || { success: false, error: finErr?.message };
              if (!ownerMetricValid) {
                toolResponseData = { success: false, code: "FINANCIAL_METRIC_AMBIGUOUS", needs_clarification: true, message: "حدد نوع الرقم المطلوب قبل ما أجيبلك نتيجة." };
              } else if (!currentMetric && !ownerPeriodRange) {
                toolResponseData = { success: false, code: "FINANCIAL_PERIOD_MISSING", needs_clarification: true, message: "حدد الفترة عشان أطلع لك الرقم الدقيق: النهارده، آخر 7 أيام، من أول الشهر، ولا إجمالي السجل؟", quick_replies: ["النهارده","آخر 7 أيام","من أول الشهر","إجمالي السجل"] };
              } else if (currentMetric) {
                if (finErr || !finSummary?.success) {
                  toolResponseData = { success: false, code: "FINANCIAL_SOURCE_ERROR", error: finErr?.message || finSummary?.error || "تعذر قراءة الرقم المالي حالياً." };
                } else {
                  const currentValue = finSummary?.available_balance;
                  toolResponseData = { success: true, fact_type: ownerMetric, value: Number(currentValue || 0), metric_definition: ownerMetric === "available_balance" ? "الرصيد المتاح للسحب حالياً بعد التسويات والمدفوعات المعلقة والمديونية القائمة." : "مديونية عمولة الكاش الحالية المسجلة على حساب المالك.", period_label: "الوضع الحالي", as_of_cairo_date: cairoDateKey(), stadium_id: null, stadium_name: null };
                }
              } else if (ownerNeedsHistoricalFacts) {
                const { data: ownerStadiums } = await supabase.from("stadiums").select("id, name").eq("owner_id", callerUser.id).eq("is_deleted_by_owner", false);
                const ownerStadiumMap = new Map((ownerStadiums || []).map((s: any) => [s.id, s]));
                let financialStadium: any = null;
                const requestedStadiumId = (args.stadium_id || "").toString().trim();
                const requestedStadiumName = (args.stadium_name || "").toString().trim();
                if (requestedStadiumId) financialStadium = ownerStadiumMap.get(requestedStadiumId) || null;
                if (requestedStadiumId && !financialStadium) toolResponseData = { success: false, code: "STADIUM_NOT_FOUND", needs_clarification: true, message: "الملعب ده مش تابع لحسابك، فمش هفترضه." };
                if (!toolResponseData?.needs_clarification && requestedStadiumName) {
                  const matches = (ownerStadiums || []).filter((s: any) => ownerFactNorm(s.name).includes(ownerFactNorm(requestedStadiumName)));
                  if (matches.length === 1) financialStadium = matches[0];
                  else if (matches.length === 0) toolResponseData = { success: false, code: "STADIUM_NOT_FOUND", needs_clarification: true, message: "الملعب المطلوب مش مسجل باسمك." };
                  else toolResponseData = { success: false, code: "STADIUM_AMBIGUOUS", needs_clarification: true, message: "في أكتر من ملعب مطابق للاسم، فمش هفترض واحد منهم." };
                }
                if (!toolResponseData?.needs_clarification) {
                  const t = ownerFactNorm(userMessage);
                  const ordinal = /(?:^|\s)(?:اول|الأول|الاول)(?:\s|$)/.test(t) ? 0 : /(?:^|\s)(?:تاني|الثاني|التاني)(?:\s|$)/.test(t) ? 1 : /(?:^|\s)(?:تالت|الثالث|التالت)(?:\s|$)/.test(t) ? 2 : -1;
                  if (!financialStadium && ordinal >= 0) financialStadium = ownerStadiums?.[ordinal] || null;
                }
                const { data: facts, error: factsErr } = !toolResponseData?.needs_clarification
                  ? await supabase.rpc("get_owner_copilot_financial_facts", { p_owner_id: callerUser.id, p_period_start: ownerPeriodRange.start, p_period_end: ownerPeriodRange.end, p_stadium_id: financialStadium?.id || null })
                  : { data: null, error: null };
                if (factsErr || !facts?.success) {
                  toolResponseData = { success: false, code: "FINANCIAL_SOURCE_ERROR", error: factsErr?.message || facts?.message || "تعذر قراءة الأرقام المالية حالياً." };
                } else {
                  const values = {
                    completed_booking_value: facts.completed_booking_value,
                    completed_booking_count: facts.completed_booking_count,
                    cash_collected: facts.completed_cash_collected,
                    owner_online_earnings: facts.completed_online_gross,
                    owner_total_revenue: Number(facts.completed_online_gross || 0) + Number(facts.completed_cash_collected || 0),
                  };
                  const definitions = {
                    completed_booking_value: "قيمة الحجوزات المكتملة والمدفوعة خلال الفترة.",
                    completed_booking_count: "عدد الحجوزات المكتملة والمدفوعة خلال الفترة.",
                    cash_collected: "قيمة الكاش المحصل من الحجوزات المكتملة والمدفوعة خلال الفترة.",
                    owner_online_earnings: "إيراد المالك من الحجوزات الأونلاين المكتملة والمدفوعة خلال الفترة، بكامل قيمة الحجز دون خصم عمولة من المالك.",
                    owner_total_revenue: "إجمالي تحصيل المالك من الحجوزات المكتملة والمدفوعة خلال الفترة: أونلاين + كاش، دون خصم عمولة من المالك.",
                  };
                  toolResponseData = { success: true, fact_type: ownerMetric, value: Number(values[ownerMetric] || 0), metric_definition: definitions[ownerMetric], period_label: ownerPeriodRange.label, period_start: ownerPeriodRange.start, period_end: ownerPeriodRange.end, as_of_cairo_date: cairoDateKey(), stadium_id: facts.stadium_id, stadium_name: facts.stadium_name };
                }
              }
            } else if (funcName === "checkStadiumAvailability") {
              let stadiumId = (args.stadium_id || "").toString().trim();
              const stadiumName = (args.stadium_name || "").toString().trim();
              const dateInput = (args.date || "غداً").toString().trim();
              const timePref = (args.time_preference || "").toString().trim();

              let targetStadium: any = null;
              if (stadiumId) {
                const { data: s } = await supabase.from("stadiums").select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id").eq("id", stadiumId).maybeSingle();
                targetStadium = s;
              }
              if (!targetStadium && stadiumName) {
                const { data: sList } = await supabase.from("stadiums").select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id").ilike("name", `%${stadiumName}%`).limit(1);
                if (sList && sList.length > 0) targetStadium = sList[0];
              }
              if (!targetStadium && contextSnapshot.last_stadium_id) {
                const { data: s } = await supabase.from("stadiums").select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id").eq("id", contextSnapshot.last_stadium_id).maybeSingle();
                targetStadium = s;
              }
              if (!targetStadium && contextSnapshot.last_visible_stadiums && contextSnapshot.last_visible_stadiums.length === 1) {
                const visible = contextSnapshot.last_visible_stadiums[0];
                const { data: s } = await supabase.from("stadiums")
                  .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
                  .eq("id", visible.id)
                  .maybeSingle();
                targetStadium = s;
              }

              if (!targetStadium) {
                toolResponseData = { success: false, message: "لم يتم تحديد ملعب بشكل كافٍ لفحص التوافر. حدّد الملعب المطلوب أولاً." };
              } else if (contextSnapshot.task_state?.requires_time_clarification) {
                const ambiguousTimes = Array.isArray(contextSnapshot.task_state?.preferred_times)
                  ? contextSnapshot.task_state.preferred_times
                  : [];
                quickReplies = ambiguousTimes.length === 1
                  ? [
                      String(Number(ambiguousTimes[0].substring(0, 2))) + ":00 ص",
                      String(Number(ambiguousTimes[0].substring(0, 2))) + ":00 م",
                    ]
                  : ["10 و11 ص", "10 و11 م"];
                toolResponseData = {
                  success: false,
                  needs_clarification: true,
                  missing_slot: "time_period",
                  stadium_id: targetStadium.id,
                  stadium_name: targetStadium.name,
                  quick_replies: quickReplies,
                  message: ambiguousTimes.length === 1 ? "تقصد الساعة الصبح ولا بالليل؟" : "تقصد 10 و11 الصبح ولا بالليل؟",
                };
              } else {
                // A fresh availability check replaces any older proposal. A previous
                // confirmation must never survive a re-check with changed availability.
                if (contextSnapshot.task_state?.intent === "book_stadium") {
                  delete contextSnapshot.task_state.confirmation_pending;
                }

                const { targetDateStr, dayStartIso, dayEndIso } = parseTargetDate(dateInput);
                const taskForAvailability = contextSnapshot.task_state || {};
                const preferredTimes = Array.isArray(taskForAvailability.preferred_times)
                  ? taskForAvailability.preferred_times
                  : [];

                const availability = await findAvailableSlotsForStadium(
                  supabase,
                  targetStadium,
                  targetDateStr,
                  preferredTimes,
                  taskForAvailability.time_window || null,
                );
                const availableSlots = availability.availableSlots;
                const allSlots = generateStandardSlots(targetDateStr);

                contextSnapshot.last_stadium_id = targetStadium.id;
                contextSnapshot.last_stadium_name = targetStadium.name;
                contextSnapshot.last_date = targetDateStr;
                contextSnapshot.last_available_slots = availableSlots;
                contextSnapshot.task_state = {
                  ...(contextSnapshot.task_state || {}),
                  stadium_id: targetStadium.id,
                  stadium_name: targetStadium.name,
                  date: targetDateStr,
                  preferred_times: preferredTimes,
                  time_window: taskForAvailability.time_window || null,
                  available_times: availableSlots.map((s: any) => s.start_time),
                };

                if (
                  contextSnapshot.task_state.intent === "book_stadium" &&
                  availableSlots.length > 0 &&
                  preferredTimes.length > 0
                ) {
                  const proposedSlot = selectPreferredAvailableSlot(availableSlots, preferredTimes);
                  if (proposedSlot) {
                    contextSnapshot.task_state.confirmation_pending = {
                      stadium_id: targetStadium.id,
                      stadium_name: targetStadium.name,
                      date: targetDateStr,
                      start_time: proposedSlot.start_time,
                      end_time: proposedSlot.end_time,
                      price_per_hour: targetStadium.price_per_hour,
                    };
                    appAction = {
                      action_type: "CONFIRM_BOOKING",
                      route: "/bookings",
                      label: "تأكيد الحجز",
                      params: { message: "أيوه، أكد الحجز" },
                    };
                    quickReplies = [];
                  }
                } else if (
                  contextSnapshot.task_state.intent === "book_stadium" &&
                  availableSlots.length > 0 &&
                  taskForAvailability.time_window
                ) {
                  // A vague window (e.g. "بعد العصر") must not pick an arbitrary hour.
                  // Show the real available options and let the user choose one.
                  quickReplies = availableSlots.slice(0, 4).map((slot: any) => slot.display_time);
                }

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
                  proposed_slot: contextSnapshot.task_state?.confirmation_pending || null,
                  quick_replies: quickReplies,
                };
              }

            } else if (funcName === "createBookingFromChat") {
              const explicitConfirm = isExplicitConfirmation(userMessage);
              const confirmRequested = args.confirm === true || explicitConfirm;
              let stadiumId = (args.stadium_id || contextSnapshot.last_stadium_id || contextSnapshot.task_state?.stadium_id || "").toString().trim();
              const stadiumName = (args.stadium_name || contextSnapshot.last_stadium_name || contextSnapshot.task_state?.stadium_name || "").toString().trim();
              let startTime = (args.start_time || "").toString().trim();
              let endTime = (args.end_time || "").toString().trim();
              let targetStadium: any = null;

              if (stadiumId) {
                const { data: s } = await supabase.from("stadiums")
                  .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
                  .eq("id", stadiumId)
                  .maybeSingle();
                targetStadium = s;
              }
              if (!targetStadium && stadiumName) {
                const { data: sList } = await supabase.from("stadiums")
                  .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
                  .ilike("name", "%" + stadiumName + "%")
                  .limit(1);
                if (sList && sList.length > 0) targetStadium = sList[0];
              }

              const task = contextSnapshot.task_state || {};
              if (task.requires_time_clarification) {
                const ambiguousTimes = Array.isArray(task.preferred_times) ? task.preferred_times : [];
                quickReplies = ambiguousTimes.length === 1
                  ? [
                      String(Number(ambiguousTimes[0].substring(0, 2))) + ":00 ص",
                      String(Number(ambiguousTimes[0].substring(0, 2))) + ":00 م",
                    ]
                  : ["10 و11 ص", "10 و11 م"];
                toolResponseData = {
                  success: false,
                  needs_clarification: true,
                  missing_slot: "time_period",
                  quick_replies: quickReplies,
                  message: "تقصد الساعة الصبح ولا بالليل؟",
                };
              } else {
                const pending = task.confirmation_pending;
                if (confirmRequested) {
                  if (!pending || !explicitConfirm) {
                    toolResponseData = {
                      success: false,
                      needs_confirmation: true,
                      message: "لازم أعرض لك ملخص الحجز الأول قبل التنفيذ.",
                    };
                  } else {
                    stadiumId = pending.stadium_id;
                    startTime = pending.start_time;
                    endTime = pending.end_time;
                    const { data: pendingStadium } = await supabase.from("stadiums")
                      .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
                      .eq("id", pending.stadium_id)
                      .maybeSingle();
                    targetStadium = pendingStadium || targetStadium;

                    if (!targetStadium) {
                      toolResponseData = { success: false, error: "تعذر استرجاع بيانات الملعب للحجز." };
                    } else {
                      const { data: activeCashBookings, error: activeCashErr } = await supabase
                        .from("bookings")
                        .select("id")
                        .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
                        .eq("payment_method", "cash")
                        .eq("is_paid", false)
                        .in("status", ["pending", "confirmed"])
                        .gt("end_time", new Date().toISOString())
                        .limit(1);

                      const hasActiveCashBooking =
                        !activeCashErr &&
                        Array.isArray(activeCashBookings) &&
                        activeCashBookings.length > 0;
                      const needsDeposit =
                        !hasActiveCashBooking && (targetStadium.needs_deposit || false);
                      const paymentMethod =
                        hasActiveCashBooking || needsDeposit ? "paymob" : "cash";

                      const { data: bookingResult, error: bookingErr } = await supabase.rpc("create_booking_atomic", {
                        p_stadium_id: targetStadium.id,
                        p_user_id: callerUser.id,
                        p_owner_id: targetStadium.owner_id,
                        p_start_time: startTime,
                        p_end_time: endTime,
                        p_booking_type: "individual",
                        p_total_price: targetStadium.price_per_hour,
                        p_stadium_name: targetStadium.name,
                        p_payment_method: paymentMethod,
                      });

                      if (bookingErr || (bookingResult && bookingResult.success === false)) {
                        toolResponseData = {
                          success: false,
                          error: bookingErr?.message || bookingResult?.message || "تعذر إتمام الحجز، قد يكون الموعد محجوزاً بالفعل.",
                        };
                      } else {
                        const bookingId = bookingResult?.booking_id || bookingResult?.id;
                        delete task.confirmation_pending;
                        contextSnapshot.last_booking_id = bookingId;
                        contextSnapshot.last_booked_stadium = targetStadium.name;
                        if (hasActiveCashBooking) {
                          appAction = {
                            action_type: "OPEN_PAYMENT",
                            route: "/checkout",
                            label: "إتمام الدفع الكامل أونلاين 💳",
                            params: {
                              booking_id: bookingId,
                              stadium_id: targetStadium.id,
                              stadium_name: targetStadium.name,
                              total_price: targetStadium.price_per_hour,
                              deposit_amount: 0,
                              start_time: startTime,
                              end_time: endTime,
                              force_full_payment: true,
                            },
                          };
                        } else if (needsDeposit) {
                          appAction = {
                            action_type: "OPEN_PAYMENT",
                            route: "/checkout",
                            label: "إتمام دفع العربون (" + (targetStadium.deposit_amount || 50) + " ج.م) وتأكيد الحجز 💳",
                            params: {
                              booking_id: bookingId,
                              stadium_id: targetStadium.id,
                              stadium_name: targetStadium.name,
                              total_price: targetStadium.price_per_hour,
                              deposit_amount: targetStadium.deposit_amount || 50,
                              start_time: startTime,
                              end_time: endTime,
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
                          start_time: startTime,
                          end_time: endTime,
                          total_price: targetStadium.price_per_hour,
                          deposit_required: needsDeposit,
                          deposit_amount: needsDeposit ? (targetStadium.deposit_amount || 0) : 0,
                          full_payment_required: hasActiveCashBooking || !needsDeposit,
                          message: needsDeposit
                            ? "تم تجهيز الحجز. أكمل دفع العربون لتأكيده."
                            : (hasActiveCashBooking
                              ? "تم تجهيز الحجز الثاني، ويجب سداده بالكامل أونلاين بسبب وجود حجز كاش قائم."
                              : "تم تأكيد الحجز بنجاح."),
                        };
                      }
                    }
                  }
                } else {
                  if (!targetStadium) {
                    toolResponseData = { success: false, message: "حدّد الملعب المطلوب أولاً." };
                  } else {
                    let proposedStart = startTime;
                    let proposedEnd = endTime;
                    if (!proposedStart || !proposedEnd) {
                      const candidates = (contextSnapshot.last_available_slots || []).filter((slot: any) =>
                        !Array.isArray(task.preferred_times) || task.preferred_times.length === 0 ||
                        task.preferred_times.includes(String(slotHourFromIso(slot.start_time)).padStart(2, "0") + ":00")
                      );
                      if (candidates.length > 0) {
                        proposedStart = candidates[0].start_time;
                        proposedEnd = candidates[0].end_time;
                      }
                    }
                    if (!proposedStart || !proposedEnd) {
                      toolResponseData = { success: false, message: "حدّد الموعد المطلوب أولاً." };
                    } else {
                      const dateForConfirmation = task.date || contextSnapshot.last_date || parseTargetDate("اليوم").targetDateStr;
                      const slotDate = parseTargetDate(dateForConfirmation);
                      const { data: existingBookings } = await supabase.from("bookings")
                        .select("start_time, end_time, status, locked_until, created_at")
                        .eq("stadium_id", targetStadium.id)
                        .neq("status", "cancelled")
                        .gte("start_time", slotDate.dayStartIso)
                        .lte("start_time", slotDate.dayEndIso);
                      const conflicts = (existingBookings || []).some((b: any) => {
                        if (b.status === "pending") {
                          const expires = b.locked_until ? new Date(b.locked_until).getTime() : new Date(b.created_at).getTime() + 5 * 60 * 1000;
                          if (expires <= Date.now()) return false;
                        }
                        return new Date(proposedStart).getTime() < new Date(b.end_time).getTime() &&
                          new Date(proposedEnd).getTime() > new Date(b.start_time).getTime();
                      });
                      if (conflicts) {
                        toolResponseData = { success: false, message: "الميعاد ده اتاخد دلوقتي. اختار ميعاد تاني." };
                      } else {
                        task.confirmation_pending = {
                          stadium_id: targetStadium.id,
                          stadium_name: targetStadium.name,
                          date: dateForConfirmation,
                          start_time: proposedStart,
                          end_time: proposedEnd,
                          price_per_hour: targetStadium.price_per_hour,
                        };
                        appAction = {
                          action_type: "CONFIRM_BOOKING",
                          route: "/bookings",
                          label: "تأكيد الحجز",
                          params: { message: "أيوه، أكد الحجز" },
                        };
                              toolResponseData = {
                          success: false,
                          needs_confirmation: true,
                          stadium_id: targetStadium.id,
                          stadium_name: targetStadium.name,
                          date: dateForConfirmation,
                          start_time: proposedStart,
                          end_time: proposedEnd,
                          price_per_hour: targetStadium.price_per_hour,
                          confirmation_pending: true,
                          message: "تم تجهيز ملخص الحجز وينتظر تأكيد المستخدم.",
                        };
                      }
                    }
                  }
                }
              }
            }


            // Deterministic response for chained discovery + availability.
            // When the user already supplied a schedule constraint, never stop at
            // "I found a stadium" and ask another unnecessary question.
            if (funcName === "searchStadiums" && toolResponseData?.schedule_checked === true) {
              const matches = Array.isArray(toolResponseData.schedule_matches)
                ? toolResponseData.schedule_matches
                : [];
              const task = contextSnapshot.task_state || {};
              if (matches.length === 0) {
                assistantReply =
                  "دورتلك في الملاعب القريبة المتاحة، ومفيش ملعب متاح في الوقت اللي طلبته. تحب أجرب وقت قريب منه؟";
                appAction = null;
                quickReplies = ["9 بالليل", "11 بالليل"];
              } else if (matches.length === 1 && task.confirmation_pending) {
                const pending = task.confirmation_pending;
                assistantReply =
                  "تمام. لقيتلك " + pending.stadium_name + " متاح " +
                  formatSlotTimeForUser(pending.start_time) + " النهارده. " +
                  "نحجزه لمدة ساعة؟ أأكد الحجز؟";
              } else if (matches.length === 1) {
                const match = matches[0];
                const slot = Array.isArray(match.available_slots) ? match.available_slots[0] : null;
                const slotText = slot ? formatSlotTimeForUser(slot.start_time) : "في الوقت المطلوب";
                assistantReply =
                  "تمام، لقيتلك " + match.stadium_name + " متاح " + slotText +
                  " بسعر " + Number(match.price_per_hour || 0).toLocaleString("ar-EG") +
                  " ج.م للساعة.";
                quickReplies = ["احجزه"];
              } else {
                const names = matches.slice(0, 4).map((m: any) => m.stadium_name);
                assistantReply =
                  "لقيتلك " + matches.length.toLocaleString("ar-EG") +
                  " ملاعب متاحة في الوقت اللي طلبته. اختار واحد منهم:";
                quickReplies = names;
              }
            }

            // Second turn for natural conversational response.
            // Reconstruct the model's tool-call part using the deterministic function
            // name/args so the following functionResponse always matches the call.
            const normalizedToolCallContent = {
              role: "model",
              parts: [
                {
                  functionCall: {
                    name: funcName,
                    args: args,
                  },
                },
              ],
            };
            const secondContents = [
              ...contents,
              normalizedToolCallContent,
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

            // Never let the model override a server-side capability decision.
            if (toolResponseData?.code === "CAPABILITY_DENIED") {
              const role = normalizeCopilotRole(userProfile?.role);
              if (role === "owner") {
                assistantReply =
                  "الميزة دي مش متاحة لحساب مالك الملعب. أقدر أساعدك في إدارة ملاعبك وحجوزاتها وحساباتك.";
              } else if (role === "player") {
                assistantReply =
                  "الميزة دي مش متاحة لحساب اللاعب. أقدر أساعدك في الملاعب والحجوزات والبطولات وخدمات اللاعب.";
              } else {
                assistantReply = "الميزة دي مش متاحة لهذا النوع من الحسابات.";
              }
              appAction = null;
              quickReplies = [];
            }

            // Smart Confirmation: once availability is known, show a concise booking summary instead of booking or asking from scratch.
            if (funcName === "checkStadiumAvailability") {
              const pending = contextSnapshot.task_state?.confirmation_pending;
              if (pending && toolResponseData?.available_slots_count > 0 && contextSnapshot.task_state?.intent === "book_stadium") {
                const proposed = pending.start_time;
                const preferred = Array.isArray(contextSnapshot.task_state?.preferred_times)
                  ? contextSnapshot.task_state.preferred_times
                  : [];
                let preferenceNote = "";
                if (preferred.length > 1) {
                  const proposedHour = String(slotHourFromIso(proposed)).padStart(2, "0");
                  const proposedIndex = preferred.findIndex((t: string) => t.substring(0, 2) === proposedHour);
                  if (proposedIndex > 0) {
                    const firstRequested = preferred[0];
                    preferenceNote =
                      " الساعة " + formatSlotTimeForUser(
                        cairoLocalToUtcIso(
                          Number(pending.date.substring(0, 4)),
                          Number(pending.date.substring(5, 7)),
                          Number(pending.date.substring(8, 10)),
                          Number(firstRequested.substring(0, 2)),
                          Number(firstRequested.substring(3, 5) || 0)
                        )
                      ) + " مش متاحة، و" + formatSlotTimeForUser(proposed) + " متاحة.";
                  }
                }
                assistantReply =
                  "تمام. " +
                  (preferenceNote || ("متاح " + formatSlotTimeForUser(proposed) + ".")) +
                  " " +
                  "نحجز في " + pending.stadium_name + "، " +
                  formatDateForUser(pending.date) +
                  " الساعة " + formatSlotTimeForUser(proposed) +
                  " لمدة ساعة؟ أأكد الحجز؟";
              } else if (toolResponseData?.needs_clarification && toolResponseData?.missing_slot === "time_period") {
                assistantReply = toolResponseData.message || "تقصد الساعة الصبح ولا بالليل؟";
              }
            } else if (funcName === "createBookingFromChat" && toolResponseData?.needs_confirmation) {
              const pending = contextSnapshot.task_state?.confirmation_pending;
              if (pending) {
                assistantReply = "تمام. تقصد نحجز في " + pending.stadium_name + "، " + formatDateForUser(pending.date) + " الساعة " + formatSlotTimeForUser(pending.start_time) + " لمدة ساعة؟ أأكد الحجز؟";
              }
            }

            // 🛡️ Zero-Hallucination Guard: When DB returns 0 rows, strictly prevent any hallucinated text!
            if (funcName === "searchTournaments" && tournamentResults.length === 0) {
              const targetGov = (args.governorate || userGov).toString().trim();
              assistantReply = `دورتلك على البطولات المفتوحة حالياً في ${targetGov}، ومفيش بطولة متاحة للتسجيل دلوقتي. تحب أدورلك على 5v5 ولا 1v1؟`;
            } else if (funcName === "searchStadiums" && stadiumResults.length === 0) {
              const targetGov = (args.governorate || userGov).toString().trim();
              assistantReply = `دورتلك في ${targetGov} ومفيش ملعب متاح بالمواصفات دي دلوقتي. تحب أوسّع البحث لمنطقة قريبة ولا نغيّر الوقت؟`;
            } else if (funcName === "getOpenMatches" && openMatchResults.length === 0) {
              assistantReply = "دورت على الماتشات المفتوحة ومفيش تقسيمة محتاجة لاعيبة دلوقتي. تحب أدور في محافظة تانية ولا تفتح ماتش جديد؟";
            } else if (funcName === "getOwnerStadiumsAndBookings") {
              if (toolResponseData?.success === false) {
                assistantReply = "مش هفترض نتيجة. " + (toolResponseData.message || "تعذر قراءة الحجوزات بدقة حالياً.");
              } else if (/كام حجز|كم حجز|عدد الحجوزات/.test(ownerFactNorm(userMessage))) {
                assistantReply = "عدد الحجوزات المطابقة للطلب: " + Number(toolResponseData.bookings_count || 0).toLocaleString("ar-EG") + " حجز."; 
              } else if (toolResponseData?.details_truncated) {
                assistantReply = "عندي " + Number(toolResponseData.bookings_count || 0).toLocaleString("ar-EG") + " حجز مطابق للطلب، والتفاصيل الكاملة موجودة في جدول الحجوزات."; 
              }
            } else if (funcName === "getOwnerFinancialInsights") {
              if (toolResponseData?.needs_clarification) {
                assistantReply = toolResponseData.message || "حددلي المقصود والفترة عشان أطلعلك الرقم الصحيح.";
              } else if (toolResponseData?.success === false) {
                assistantReply = "مش هديك رقم تقريبي. " + (toolResponseData.error || toolResponseData.message || "تعذر استخراج الرقم بدقة حالياً.");
              } else if (toolResponseData?.fact_type) {
                const fact = toolResponseData.fact_type;
                const value = Number(toolResponseData.value || 0);
                const label = fact === "available_balance" ? "الرصيد المتاح للسحب حالياً" :
                  fact === "owner_online_earnings" ? "إيراد المالك من الحجوزات الأونلاين المكتملة والمدفوعة" :
                  fact === "owner_total_revenue" ? "إجمالي تحصيل المالك من الحجوزات المكتملة والمدفوعة" :
                  fact === "completed_booking_value" ? "قيمة الحجوزات المكتملة والمدفوعة" :
                  fact === "completed_booking_count" ? "عدد الحجوزات المكتملة والمدفوعة" :
                  "الكاش المحصل من الحجوزات المكتملة والمدفوعة";
                const suffix = fact === "completed_booking_count" ? " حجز" : " ج.م";
                const scope = toolResponseData.stadium_name ? " — ملعب " + toolResponseData.stadium_name : " — كل ملاعبك";
                const period = toolResponseData.period_label ? " — " + toolResponseData.period_label : "";
                assistantReply = label + ": " + value.toLocaleString("ar-EG", { maximumFractionDigits: 2 }) + suffix + scope + period + ".";
              } else {
                assistantReply = "لم أجد تعريفاً رقمياً مؤكداً للطلب، لذلك لن أعطيك رقماً بالتخمين.";
              }
            } else if (!assistantReply) {
              if (funcName === "get1v1Leaderboard") {
                assistantReply = "يا كابتن، ده ترتيب قمة دوري الـ 1v1، والنقاط محسوبة بمجموع (الأهداف + المهارات + قطع الكرات):";
              } else if (funcName === "searchStadiums") {
                const targetGov = (args.governorate || userGov).toString().trim();
                assistantReply = `يا كابتن! دي الملاعب المتاحة على VSP في ${targetGov} للحجز الفوري:`;
              } else if (funcName === "searchTournaments") {
                assistantReply = "لقيتلك البطولات النشطة وجاهزة للتسجيل يا كابتن:";
              } else if (funcName === "getOpenMatches") {
                assistantReply = "دي الماتشات المفتوحة اللي ناقصها لعيبة ومتاحة تنضم ليها فوراً:";
              } else if (funcName === "updateUserProfile") {
                assistantReply = "تم يا كابتن! عدلتلك بياناتك في البروفايل بنجاح ⚽";
              } else if (funcName === "getUserBookingsAndRefunds") {
                assistantReply = "يا كابتن، راجعتلك سجل حجوزاتك ومستحقاتك وكل العمليات مسجلة ومضمونة في VSP:";
              } else if (funcName === "getOwnerStadiumsAndBookings") {
                assistantReply = "يا كابتن، دي تفاصيل ملاعبك وحجوزاتك المسجلة في التطبيق:";
              } else if (funcName === "checkStadiumAvailability") {
                if (toolResponseData.available_slots_count === 0) {
                  assistantReply = `بصيت على جدول مواعيد ${toolResponseData.stadium_name || 'الملعب'} يوم ${formatDateForUser(toolResponseData.date)}، ومفيش فترة فاضية في اليوم ده. تحب نجرب بكرة ولا تختار وقت تاني؟`;
                } else {
                  const slotsText = (toolResponseData.available_slots || []).slice(0, 5).map((s: any) => `• ${s.display_time}`).join("\n");
                  assistantReply = `يا كابتن! بحثتلك في جدول مواعيد ${toolResponseData.stadium_name || 'الملعب'} ليوم ${toolResponseData.date}، ودي الفترات المتاحة للحجز:\n${slotsText}\nسعر الساعة: ${toolResponseData.price_per_hour} ج.م. تحب أحجزلك أي ميعاد منهم؟`;
                }
              } else if (funcName === "createBookingFromChat") {
                if (toolResponseData.success) {
                  if (toolResponseData.deposit_required) {
                    assistantReply = `تم قفل موعدك بنجاح في ${toolResponseData.stadium_name} يا كابتن ⚽! تم حفظ الحجز لمدة 5 دقائق، اضغط على الزر بالأسفل لإتمام دفع العربون (${toolResponseData.deposit_amount} ج.م) وتأكيد الحجز فوراً.`;
                  } else {
                    assistantReply = `ألف مبروك يا كابتن! تم تأكيد حجزك في ${toolResponseData.stadium_name} بنجاح والدفع كاش في الملعب. حجزك مسجل في قائمة حجوزاتك 📋`;
                  }
                } else if (toolResponseData.needs_clarification) {
                  const options = (toolResponseData.preferred_times || []).join(" أو ");
                  assistantReply = `الوقت لسه محتاج اختيار واحد. المتاح من اختياراتك: ${options || "أكثر من موعد"}. اختار الساعة اللي تناسبك.`;
                } else {
                  const bookingFailure = (toolResponseData.error || toolResponseData.message || "الحجز ما اكتملش حالياً").toString();
                  assistantReply = bookingFailure.includes("محجوز") || bookingFailure.includes("اتاخد")
                    ? "الميعاد ده اتاخد قبل ما نكمل الحجز. تحب أشوف لك أقرب ميعاد متاح؟"
                    : "الحجز ما اكتملش المرة دي. تحب أعيد فحص الميعاد نفسه ولا نجرّب وقت تاني؟";
                }
              } else {
                assistantReply = "تمام يا كابتن، طلبك جاهز!";
              }
            }
            handledByGemini = true;

          } else {
            // 🛡️ Strict Out-of-Scope Detection
            const lowerMsg = userMessage.toLowerCase();
            const isOutOfScope =
              lowerMsg.includes("طبخ") || lowerMsg.includes("طبيخ") || lowerMsg.includes("أكل") || lowerMsg.includes("أكلة") ||
              lowerMsg.includes("طريقة عمل") || lowerMsg.includes("وصفة") || lowerMsg.includes("مقادير") || lowerMsg.includes("كشري") ||
              lowerMsg.includes("شاورما") || lowerMsg.includes("بيتزا") || lowerMsg.includes("برجر") || lowerMsg.includes("ملوخية") ||
              lowerMsg.includes("كيكة") || lowerMsg.includes("سياسة") || lowerMsg.includes("سياسي") || lowerMsg.includes("رئيس") ||
              lowerMsg.includes("انتخابات") || lowerMsg.includes("حكومة") || lowerMsg.includes("وزير") || lowerMsg.includes("برلمان") ||
              lowerMsg.includes("حرب") || lowerMsg.includes("بايثون") || lowerMsg.includes("python") || lowerMsg.includes("كود") ||
              lowerMsg.includes("برمجة") || lowerMsg.includes("مبرمج") || lowerMsg.includes("جافاسكريبت") || lowerMsg.includes("javascript") ||
              lowerMsg.includes("فيزياء") || lowerMsg.includes("كيمياء") || lowerMsg.includes("فلسفة") || lowerMsg.includes("رياضيات") ||
              lowerMsg.includes("معادلة") || lowerMsg.includes("تفاضل") || lowerMsg.includes("تكامل") || lowerMsg.includes("أينشتاين") ||
              lowerMsg.includes("نيوتن") || lowerMsg.includes("فيلم") || lowerMsg.includes("مسلسل") || lowerMsg.includes("أغنية") ||
              lowerMsg.includes("اغنية") || lowerMsg.includes("طقس") || lowerMsg.includes("درجة الحرارة") || lowerMsg.includes("نكتة") ||
              lowerMsg.includes("فزورة") || lowerMsg.includes("مرسيدس") || lowerMsg.includes("سيارات") || lowerMsg.includes("عقارات") ||
              lowerMsg.includes("بورصة") || lowerMsg.includes("بيتكوين") || lowerMsg.includes("crypto") || lowerMsg.includes("علاج") ||
              lowerMsg.includes("دواء") || lowerMsg.includes("تاريخ فرنسا") || lowerMsg.includes("عاصمة");

            if (isOutOfScope) {
              assistantReply = 'خلّينا في اللي أقدر أساعدك فيه داخل VSP ⚽: حجز الملاعب، مواعيدها، البطولات، المباريات المفتوحة، وحسابات مالك الملعب.';
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
        console.warn("Gemini API error, falling back to safe message:", geminiErr);
      }
    }

    // 🛡️ Safe Server Fallback (Phase 5: Clean Architecture - No brittle keyword guessing on Edge Function)
    if (!handledByGemini) {
      const recovery = buildConversationalRecovery(
        contextSnapshot.task_state || {},
        contextSnapshot,
        userMessage,
      );
      assistantReply = recovery.message;
      quickReplies = recovery.quick_replies;
    }

    // 10. Build the exact turn payload before atomic persistence.
    const persistedUiMetadata = {
      stadiums: stadiumResults,
      tournaments: tournamentResults,
      leaderboard: leaderboardResults,
      open_matches: openMatchResults,
      action: appAction,
      task_state: contextSnapshot.task_state || {},
    };

    // Deterministic clarification guard:
    // If booking intent has an exact time but no date, preserve the understood time
    // and ask only for the missing date. Never let Gemini erase known slots.
    const bookingMissingDateReply = buildBookingMissingDateReply(
      contextSnapshot.task_state || {},
      userMessage,
    );
    if (bookingMissingDateReply) {
      assistantReply = bookingMissingDateReply.message;
      quickReplies = bookingMissingDateReply.quick_replies;
      persistedUiMetadata.task_state = contextSnapshot.task_state || {};
      persistedUiMetadata.action = null;
      appAction = null;
    }

    // Persist the user+assistant turn and conversation state in ONE database transaction.
    // The database trigger assigns a deterministic per-conversation message_sequence.
    const { data: persistedTurn, error: persistTurnErr } = await supabase.rpc("persist_copilot_turn", {
      p_conversation_id: conversationId,
      p_user_id: callerUser.id,
      p_user_content: userMessage,
      p_assistant_content: assistantReply,
      p_stadium_results: stadiumResults,
      p_ui_metadata: persistedUiMetadata,
      p_context_snapshot: contextSnapshot,
    });

    if (persistTurnErr || persistedTurn !== true) {
      console.error("VSP Copilot turn persistence failed:", persistTurnErr?.message || "unknown error");
      return new Response(
        JSON.stringify({ error: "Failed to persist Copilot conversation turn" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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
        ui_metadata: persistedUiMetadata,
        task_state: contextSnapshot.task_state || {},
        quick_replies: quickReplies,
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
