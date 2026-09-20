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
      capability_id: {
        type: "STRING",
        description: "معرف Capability معتمد من VSP AI Registry. استخدمه بدلاً من اختراع مسار.",
      },
      route: {
        type: "STRING",
        description: "مسار legacy اختياري للتوافق فقط.",
      },
      label: {
        type: "STRING",
        description: "عنوان الإجراء بالعربية ليظهر كزر للمستخدم (مثال: 'الانتقال لصفحة فريقي')",
      },
    },
    required: ["action_type", "capability_id", "label"],
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
        description: "نوع الاستعلام: 'active' للحجوزات القادمة، 'past' للحجوزات المنتهية، 'refunds' للمستردات، 'all' للكل",
      },
    },
  },
};

// 7b. Tool: cancelBookingFromChat ⚡ Phase 6
const cancelBookingFromChatTool = {
  name: "cancelBookingFromChat",
  description: "إلغاء حجز محدد للمستخدم بناءً على معرف الحجز (booking_id). استدعِ هذه الأداة فوراً عندما يطلب المستخدم إلغاء حجز، سواء قال 'الغي حجزي' أو 'مش هينفع أجي' أو 'احذف الحجز'.",
  parameters: {
    type: "OBJECT",
    properties: {
      booking_id: {
        type: "STRING",
        description: "معرف الحجز (UUID) المراد إلغاؤه — استخدم last_booking_id من السياق إن لم يذكره المستخدم",
      },
      reason: {
        type: "STRING",
        description: "سبب الإلغاء إن ذكره المستخدم (اختياري)",
      },
    },
    required: ["booking_id"],
  },
};

// 7c. Tool: leavePublicMatchFromChat — confirmation is mandatory.
const leavePublicMatchFromChatTool = {
  name: "leavePublicMatchFromChat",
  description: "مغادرة مباراة حجز مفتوح للمستخدم الحالي. يجب طلب تأكيد صريح قبل التنفيذ، ولا تمرر confirmed=true إلا بعد التأكيد.",
  parameters: {
    type: "OBJECT",
    properties: {
      booking_id: {
        type: "STRING",
        description: "معرف المباراة/الحجز UUID. استخدم last_booking_id من السياق إن كان يشير للمباراة المقصودة.",
      },
      confirmed: {
        type: "BOOLEAN",
        description: "true فقط بعد تأكيد المستخدم للمغادرة.",
      },
    },
    required: ["booking_id", "confirmed"],
  },
};

// 7d. Tool: leaveChampionshipFromChat — team captain only.
const leaveChampionshipFromChatTool = {
  name: "leaveChampionshipFromChat",
  description: "انسحاب فريق اللاعب من بطولة. يجب أن يكون المستخدم قائد الفريق ويجب طلب تأكيد صريح قبل التنفيذ.",
  parameters: {
    type: "OBJECT",
    properties: {
      championship_id: {
        type: "STRING",
        description: "معرف البطولة UUID. استخدم المعرف الموجود في سياق المحادثة أو نتيجة البحث.",
      },
      confirmed: {
        type: "BOOLEAN",
        description: "true فقط بعد تأكيد المستخدم للانسحاب.",
      },
    },
    required: ["championship_id", "confirmed"],
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
const ownerCreateManualBookingTool = {
  name: "ownerCreateManualBooking",
  description: "إنشاء حجز يدوي/هاتف لمالك الملعب. لا تستخدمها إلا لمالك لديه Owner AI entitlement وبعد تحديد الملعب والموعد. السعر النهائي يحسبه السيرفر من سعر الملعب.",
  parameters: {
    type: "OBJECT",
    properties: {
      stadium_id: { type: "STRING", description: "معرف الملعب UUID" },
      start_time: { type: "STRING", description: "وقت بداية الحجز بصيغة ISO 8601 مع المنطقة الزمنية إن أمكن" },
      end_time: { type: "STRING", description: "وقت نهاية الحجز بصيغة ISO 8601 مع المنطقة الزمنية إن أمكن" },
      customer_name: { type: "STRING", description: "اسم العميل إن توفر" },
      customer_phone: { type: "STRING", description: "رقم هاتف العميل إن توفر" },
      notes: { type: "STRING", description: "ملاحظات الحجز إن وجدت" },
      collected_amount: { type: "NUMBER", description: "المبلغ المحصل نقداً من العميل. إن لم يذكره المالك استخدم 0 ولا تخمّن." },
      current_players: { type: "NUMBER", description: "عدد اللاعبين الحالي إن ذكره المالك، وإلا 0." },
      confirmed: { type: "BOOLEAN", description: "true فقط بعد تأكيد المالك إنشاء الحجز اليدوي." },
    },
    required: ["stadium_id", "start_time", "end_time", "confirmed"],
  },
};

const getOwnerOperationalInsightsTool = {
  name: "getOwnerOperationalInsights",
  description: "للمالك فقط: تحليل تشغيلي حقيقي من قاعدة البيانات للحجوزات والإيراد ونسبة الإشغال والإلغاءات وساعات الذروة وأداء الملاعب. لا تخمّن أي رقم.",
  parameters: {
    type: "object",
    properties: {
      period: { type: "string", enum: ["7d", "30d", "90d", "all"] }
    }
  }
};

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
  description: "بدء إجراءات حجز الملعب مباشرة وقفل الموعد ذرياً (Atomic Lock) من داخل المحادثة بناءً على طلب المستخدم. استدعِ هذه الأداة فوراً ودون أي تردد كلما طلب المستخدم حجز ملعب أو حجز موعد (مثل: 'احجزلي الجمعة الجاية الساعة 9'، 'احجزلي 2 بليل'، 'احجزلي ميعاد الساعه 8'). إذا لم يذكر المستخدم تاريخاً صراحة، مرر date: 'اليوم'. إذا لم يذكر اسم الملعب، اتركه فارغاً. الأداة والـ Guard هما المسؤولان عن حسم التاريخ واكتشاف الغموض وسؤال المستخدم عبر Action Chips إن لزم.",
  parameters: {
    type: "OBJECT",
    properties: {
      stadium_id: {
        type: "STRING",
        description: "معرف الملعب (UUID) إن وجد",
      },
      stadium_name: {
        type: "STRING",
        description: "اسم الملعب المطلوب حجزه (مثل: 'الصداقة الجديدة'، 'صدقة جديدة' - أو اتركه فارغاً)",
      },
      date: {
        type: "STRING",
        description: "التاريخ المطلوب للحجز (مثل: 'اليوم'، 'غداً'، 'بكرة' أو YYYY-MM-DD - إذا لم يذكر مرر 'اليوم')",
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

// ==========================================
// 🧭 VSP AI Capability Contract (server-side)
// Capability IDs are the only trusted identifiers for app actions.
// Flutter owns concrete navigation; Edge owns role/entitlement policy.
// ==========================================

const AI_CAPABILITIES: Record<string, {
  role: "player" | "owner" | "admin" | "any";
  requiredEntitlement: "none" | "owner_ai";
}> = {
  PLAYER_SEARCH_STADIUMS: { role: "player", requiredEntitlement: "none" },
  PLAYER_SEARCH_TOURNAMENTS: { role: "player", requiredEntitlement: "none" },
  PLAYER_SEARCH_OPEN_MATCHES: { role: "player", requiredEntitlement: "none" },
  PLAYER_CHECK_AVAILABILITY: { role: "player", requiredEntitlement: "none" },
  PLAYER_CREATE_BOOKING: { role: "player", requiredEntitlement: "none" },
  PLAYER_VIEW_BOOKINGS: { role: "player", requiredEntitlement: "none" },
  PLAYER_CANCEL_BOOKING: { role: "player", requiredEntitlement: "none" },
  PLAYER_EDIT_PROFILE: { role: "player", requiredEntitlement: "none" },
  PLAYER_VIEW_NOTIFICATIONS: { role: "player", requiredEntitlement: "none" },
  PLAYER_MY_TEAM: { role: "player", requiredEntitlement: "none" },
  PLAYER_LEAVE_MATCH: { role: "player", requiredEntitlement: "none" },
  PLAYER_LEAVE_TOURNAMENT: { role: "player", requiredEntitlement: "none" },
  PLAYER_DELETE_ACCOUNT: { role: "player", requiredEntitlement: "none" },
  USER_UPDATE_PROFILE: { role: "any", requiredEntitlement: "none" },
  OWNER_VIEW_FINANCIALS: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_VIEW_OPERATIONAL_INSIGHTS: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_VIEW_UPCOMING_BOOKINGS: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_VIEW_STADIUMS: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_BLOCK_SLOT: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_UNBLOCK_SLOT: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_EDIT_STADIUM: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_CREATE_MANUAL_BOOKING: { role: "owner", requiredEntitlement: "owner_ai" },
  OWNER_RENEW_SUBSCRIPTION: { role: "owner", requiredEntitlement: "none" },
  SYSTEM_LOGIN: { role: "any", requiredEntitlement: "none" },
};

function getAiCapability(capabilityId: string | undefined | null) {
  if (!capabilityId) return null;
  return AI_CAPABILITIES[capabilityId.trim().toUpperCase()] ?? null;
}

function isCapabilityAllowed(capabilityId: string | undefined | null, userRole: string, ownerAiEnabled: boolean): boolean {
  const id = capabilityId?.trim().toUpperCase();
  const cap = getAiCapability(id);
  if (!cap) return false;
  const role = (userRole || "player").toLowerCase().trim();
  if (cap.role !== "any" && cap.role !== role && !(role === "admin" && cap.role !== "admin")) return false;
  if (cap.requiredEntitlement === "owner_ai" && role !== "admin" && !ownerAiEnabled) return false;
  return true;
}

function buildAiAction(capabilityId: string, action: Record<string, any>) {
  const normalizedId = capabilityId.trim().toUpperCase();
  if (!getAiCapability(normalizedId)) return null;
  return { ...action, capability_id: normalizedId };
}

function inferCapabilityIdFromAction(action: any, userRole: string): string | null {
  if (!action) return null;
  const explicit = action.capability_id || action.capabilityId;
  if (explicit && getAiCapability(String(explicit))) return String(explicit).trim().toUpperCase();
  const role = (userRole || "player").toLowerCase().trim();
  const type = String(action.action_type || "").toUpperCase();
  const route = String(action.route || "").toLowerCase();
  if (type === "OPEN_PAYMENT") return role === "player" ? "PLAYER_CREATE_BOOKING" : null;
  if (type === "PROFILE_UPDATED") return "USER_UPDATE_PROFILE";
  if (role === "owner") {
    if (route.includes("ledger") || route.includes("financial")) return "OWNER_VIEW_FINANCIALS";
if (route.includes("insight") || route.includes("analytics") || route.includes("performance")) return "OWNER_VIEW_OPERATIONAL_INSIGHTS";
    if (route.includes("booking")) return "OWNER_VIEW_UPCOMING_BOOKINGS";
    if (route.includes("documentation")) return "OWNER_EDIT_STADIUM";
    if (route.includes("facility-onboarding") || route.includes("subscription")) return "OWNER_RENEW_SUBSCRIPTION";
  }
  if (route.includes("notification")) return "PLAYER_VIEW_NOTIFICATIONS";
  if (route.includes("my-team") || route.includes("/team")) return "PLAYER_MY_TEAM";
  if (route.includes("championship") || route.includes("tournament")) return "PLAYER_LEAVE_TOURNAMENT";
  if (route.includes("/match")) return "PLAYER_LEAVE_MATCH";
  if (route.includes("refund") || route.includes("booking")) return "PLAYER_VIEW_BOOKINGS";
  if (route.includes("profile") || route.includes("setting")) return "PLAYER_EDIT_PROFILE";
  if (route.includes("stadium")) return "PLAYER_SEARCH_STADIUMS";
  return null;
}

function finalizeAiAction(action: any, userRole: string, ownerAiEnabled: boolean) {
  if (!action) return null;
  const capabilityId = inferCapabilityIdFromAction(action, userRole);
  if (!capabilityId || !isCapabilityAllowed(capabilityId, userRole, ownerAiEnabled)) return null;
  return buildAiAction(capabilityId, action);
}

function hasConfirmedPendingIntent(contextSnapshot: any, intent: string, key: string, value: string): boolean {
  const p = contextSnapshot?.pending_intent;
  if (!p || p.intent !== intent || p.confirmed !== true) return false;
  return String(p[key] ?? "").trim() === String(value).trim();
}

// ==========================================
// 🔒 Phase 2: Role-Based Tool Registry
// Gemini sees ONLY the tools the user's role permits.
// This is a server-enforced security boundary, not a prompt hint.
// ==========================================

/** Tools available to every authenticated role */
const SHARED_TOOLS = [
  searchStadiumsTool,
  searchTournamentsTool,
  get1v1LeaderboardTool,
  getOpenMatchesTool,
  executeAppActionTool,
  updateUserProfileTool,
  checkStadiumAvailabilityTool,
];

/** Tools exclusive to Player role */
const PLAYER_ONLY_TOOLS = [
  getUserBookingsAndRefundsTool,
  cancelBookingFromChatTool,
  createBookingFromChatTool,
  leavePublicMatchFromChatTool,
  leaveChampionshipFromChatTool,
];

/** Tools exclusive to Owner role */
const OWNER_ONLY_TOOLS = [
  getOwnerStadiumsAndBookingsTool,
  getOwnerFinancialInsightsTool,
  getOwnerOperationalInsightsTool,
  ownerCreateManualBookingTool,
];

/** A flat list of all tool names allowed per role — for server-side validation */
const ROLE_ALLOWED_TOOL_NAMES: Record<string, Set<string>> = {
  player: new Set([
    ...SHARED_TOOLS.map((t) => t.name),
    ...PLAYER_ONLY_TOOLS.map((t) => t.name),
  ]),
  owner: new Set([
    ...SHARED_TOOLS.map((t) => t.name),
    ...OWNER_ONLY_TOOLS.map((t) => t.name),
  ]),
  admin: new Set([
    ...SHARED_TOOLS.map((t) => t.name),
    ...PLAYER_ONLY_TOOLS.map((t) => t.name),
    ...OWNER_ONLY_TOOLS.map((t) => t.name),
  ]),
};

/**
 * Returns the tool list that Gemini is allowed to see for a given role.
 * Owner tools are completely invisible to players — and vice versa.
 */
function buildToolRegistryForRole(role: string, ownerAiEnabled: boolean = true): any[] {
  const r = (role || "player").toLowerCase();
  if (r === "owner") {
    return ownerAiEnabled ? [...SHARED_TOOLS, ...OWNER_ONLY_TOOLS] : [...SHARED_TOOLS];
  }
  if (r === "admin" || r === "co_founder" || r === "co-founder") {
    return [...SHARED_TOOLS, ...PLAYER_ONLY_TOOLS, ...OWNER_ONLY_TOOLS];
  }
  return [...SHARED_TOOLS, ...PLAYER_ONLY_TOOLS];
}

/**
 * Server-side guard: reject tool calls that the user's role does not permit,
 * even if Gemini somehow emits them.
 */
function isToolAllowedForRole(toolName: string, role: string, ownerAiEnabled: boolean = true): boolean {
  const r = (role || "player").toLowerCase();
  const allowed = ROLE_ALLOWED_TOOL_NAMES[r] ?? ROLE_ALLOWED_TOOL_NAMES["player"];
  if (!allowed.has(toolName)) return false;
  if (r === "owner" && OWNER_ONLY_TOOLS.some((t) => t.name === toolName) && !ownerAiEnabled) return false;
  return true;
}

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
  // 1. Explicit valid UUID — verify against DB (reject hallucinated UUIDs)
  if (stadiumId && /^[0-9a-fA-F-]{36}$/.test(stadiumId)) {
    const { data: s } = await supabase
      .from("stadiums")
      .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id, image_url, opening_time, closing_time, is_split_shift, break_start_time, break_end_time, rating")
      .eq("id", stadiumId)
      .eq("is_verified", true)
      .eq("is_blocked", false)
      .eq("is_deleted_by_owner", false)
      .maybeSingle();
    // If UUID is real and active → return directly
    if (s) return s;
    // If UUID looks real but not found → it was hallucinated or deleted;
    // fall through to fuzzy name search using queryName (if provided)
    if (!queryName || queryName.trim().length === 0) return null;
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
    // No name and no UUID → cannot guess; return null to force clarification
    return null;
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

  // ⚡ Phase 4 — Truth Guard
  // 1. Ambiguity: top 2 stadiums are too close in score → ask user which one
  if (top1 && top2 && (top1.score - top2.score <= 20) && top1.score >= 40 && top2.score >= 40) {
    const resultStadium = { ...top1.stadium };
    resultStadium.is_ambiguous = true;
    resultStadium.candidates = [
      { id: top1.stadium.id, label: top1.stadium.name },
      { id: top2.stadium.id, label: top2.stadium.name },
    ];
    return resultStadium;
  }

  // 2. Confident single match (score >= 40)
  if (top1 && top1.score >= 40) return top1.stadium;

  // 3. Score too low — do NOT fallback to a random stadium.
  //    Return null so executeBookingFlow returns a proper clarification/error.
  return null;
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

    // 0. Explicit ISO Date (Highest Priority - e.g. YYYY-MM-DD from Action Chip or direct API)
    const dateMatch = text.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
    if (dateMatch) {
      const y = Number(dateMatch[1]);
      const m = Number(dateMatch[2]);
      const d = Number(dateMatch[3]);
      targetDayDate = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
    } else if (
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
          text.includes("المقبل") ||
          text.includes("المقبلة") ||
          text.includes("اللي جاي") ||
          text.includes("اللي بعده");

        const targetDay = foundWeekday.dayIndex;
        let diff = (targetDay - cairo.dayOfWeek + 7) % 7;
        if (diff === 0) diff = 7;

        // Ambiguity Rule:
        // Check if query contains an explicit day of month or ISO date (e.g., 25 سبتمبر or YYYY-MM-DD or يوم 25)
        const hasExplicitDate =
          /\d{1,2}\s*(?:يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر)/.test(text) ||
          /\d{4}-\d{2}-\d{2}/.test(text) ||
          /(?:يوم\s*|بتاريخ\s*)\d{1,2}/.test(text) ||
          /\d{1,2}\/\d{1,2}/.test(text);

        // If user says "الجمعة الجاية" without an explicit date -> Ambiguous Temporal Expression!
        if (isNextMentioned && !hasExplicitDate) {
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

    // Fallback detection:
    // Case 1: "لو مفيش 8 خليه 9"
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
    } else {
      // Case 2: "الساعة 9 ... لو مفيش خليه 10"
      const fallbackSingleMatch = text.match(/لو\s+(?:مش|مفيش)\s*(?:متاح|فاضي|محجوز)?\s*(?:خليه|خلّيه|يبقى)?\s*(\d{1,2})/);
      if (fallbackSingleMatch) {
        let h2 = parseInt(fallbackSingleMatch[1], 10);
        if (h2 <= 11 && h2 >= 1) h2 += 12;

        const primaryMatch = text.match(/(?:الساعه|الساعة|ساعة)\s*(\d{1,2}|[١٢٣٤٥٦٧٨٩٠]{1,2})/);
        let h1 = 20;
        if (primaryMatch) {
          let h1Raw = primaryMatch[1];
          const arabicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
          for (let i = 0; i < 10; i++) {
            h1Raw = h1Raw.replace(new RegExp(arabicDigits[i], "g"), i.toString());
          }
          h1 = parseInt(h1Raw, 10);
          if (h1 <= 11 && h1 >= 1) h1 += 12;
        }
        preferredSlots = [
          `${String(h1).padStart(2, "0")}:00`,
          `${String(h2).padStart(2, "0")}:00`,
        ];
        targetCairoHour = h1;
      }
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
      const directTimeMatch = text.match(/\b(\d{1,2}):00\b/) || text.match(/\b(\d{1,2}):\d{2}\b/);
      if (directTimeMatch) {
        targetCairoHour = parseInt(directTimeMatch[1], 10);
      } else {
        const hourMatch = text.match(/(?:الساعه|الساعة|ساعة)\s*(\d{1,2}|[١٢٣٤٥٦٧٨٩٠]{1,2})/);
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
          } else if (h >= 1 && h <= 6) {
            // ⚡ Phase 3: Time Disambiguation — hours 1-6 may be AM or PM
            const hasNightContext = text.includes("بليل") || text.includes("بالليل") ||
              text.includes("ليل") || text.includes("سهر") || text.includes("سهرة");
            const hasMorningContext = text.includes("صبح") || text.includes("الصبح") ||
              text.includes("صباح") || text.includes("am");
            const hasAfternoonContext = text.includes("ضهر") || text.includes("بعد الظهر") ||
              text.includes("عصر") || text.includes("بعد العصر") || text.includes("pm");

            if (hasNightContext) {
              targetCairoHour = h; // Late night: 1-6 AM
            } else if (hasMorningContext) {
              targetCairoHour = h; // Explicit morning
            } else if (hasAfternoonContext) {
              targetCairoHour = h + 12; // Explicit afternoon
            } else if (h <= 3) {
              // 1,2,3 → default night (most common in Egyptian sports booking culture)
              targetCairoHour = h;
            } else {
              // 4,5,6 → genuinely ambiguous → trigger time_disambiguation chip
              clarification = {
                type: "time",
                question: `يعني إيه "الساعة ${h}" يا كابتن؟ صبح ولا مساء؟`,
                options: [
                  { id: `${String(h).padStart(2, "0")}:00`, label: `${h} صباحاً` },
                  { id: `${String(h + 12).padStart(2, "0")}:00`, label: `${h} مساءً / ${h} م` },
                ],
              };
              targetCairoHour = h + 12; // default to afternoon until clarified
            }
          }
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

    // ── 1. Ball Detection ────────────────────────────────────────────────────
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
    // ── 3. Recurring Booking ─────────────────────────────────────────────────
    const isGoalkeeperSearch =
      text.includes("ناقصنا جون") || text.includes("محتاجين جون") ||
      text.includes("عايزين جون") || text.includes("ناقصنا حارس") ||
      text.includes("محتاجين حارس");

    const isRecurringBooking =
      text.includes("تثبيتة") || text.includes("تثبيته") ||
      text.includes("ثبتلي") || text.includes("ثبت لي") ||
      text.includes("عايز اثبت") || text.includes("عايز أثبت");

    // ── 4. ⚡ Phase 3: Pre-Gemini Booking Interceptor ────────────────────────
    // Extract booking intent directly from text — no Gemini needed.
    // Activated when احجزلي or احجز + context triggers are detected.
    let bookingRequest: {
      stadiumName?: string;
      time?: string;
      date?: string;
      rentBall: boolean;
      fallbackSlots: string[];
    } | null = null;

    const isExplicitBookingTrigger =
      text.includes("احجزلي") || text.includes("احجزلى") ||
      text.includes("احجز لي") || text.includes("احجز لى") ||
      (text.includes("احجز") && (text.includes("ملعب") || text.includes("الساعة") || text.includes("الساعه")));

    if (isExplicitBookingTrigger) {
      // Stadium name: "في ملعب X" or "ملعب X" from original message
      let stadiumName: string | undefined;
      const sMatch = userMessage.match(/(?:في|فى)\s+ملعب\s+([^،,\n]+)/i) ||
                     userMessage.match(/ملعب\s+([^،,\n]+)/i);
      if (sMatch) {
        stadiumName = sMatch[1].trim()
          .replace(/\s*(ولو|لو|بس|اللى|اللي|يبقا|يبقى).*/i, "").trim();
      } else if (text.includes("نفس الملعب") || text.includes("الملعب ده") || text.includes("الملعب الاخير") || text.includes("الملعب الأخير")) {
        stadiumName = contextSnapshot?.last_stadium_name || contextSnapshot?.last_booked_stadium;
      } else if (contextSnapshot?.last_stadium_name) {
        stadiumName = contextSnapshot.last_stadium_name;
      } else if (contextSnapshot?.last_booked_stadium) {
        stadiumName = contextSnapshot.last_booked_stadium;
      }

      // Raw time string for TemporalResolver
      const tMatch = userMessage.match(/(?:الساعه|الساعة|ساعة)\s*[١٢٣٤٥٦٧٨٩٠\d]{1,2}/i);
      const rawTime = tMatch ? tMatch[0] : undefined;

      // Date keyword
      const dateKeywords = [
        "الجمعة الجاية", "الجمعة القادمة", "الجمعه الجايه",
        "السبت الجاي", "السبت القادم", "الأحد الجاي", "الاحد الجاي",
        "الأحد القادم", "الاثنين الجاي", "الثلاثاء الجاي",
        "الأربعاء الجاي", "الأربع الجاي", "الخميس الجاي",
        "بكرة", "بكره", "النهارده", "اليوم",
      ];
      let rawDate: string | undefined;
      for (const dk of dateKeywords) {
        if (text.includes(dk.toLowerCase())) { rawDate = dk; break; }
      }

      // Fallback slots: "لو مفيش خليه 10"
      const fallbackSlots: string[] = [];
      const fbMatches = userMessage.matchAll(/(?:لو\s+(?:مش|مفيش)(?:\s+متاح|\s+فاضي)?\s*(?:خليه|خلّيه|يبقى|يبقا)?\s*)(\d{1,2})/gi);
      for (const fm of fbMatches) {
        let h = parseInt(fm[1], 10);
        if (h >= 1 && h <= 12) h += 12;
        fallbackSlots.push(`${String(h).padStart(2, "0")}:00`);
      }

      bookingRequest = {
        stadiumName,
        time: rawTime,
        date: rawDate,
        rentBall: isBallMentioned,
        fallbackSlots,
      };
    }

    // ── 5. ⚡ Phase 6: Cancel Request Interceptor ─────────────────────────────
    let cancelRequest: { explicit: boolean; reason?: string } | null = null;
    const cancelPhrases = [
      "الغي حجزي", "الغي حجزى", "الغي الحجز", "الغى حجزي",
      "مش هينفع أجي", "مش هينفع اجي", "مش جاي", "مش قادر اجي",
      "احذف الحجز", "امسح الحجز", "لغي الحجز",
      "عايز الغي", "عايز ألغي", "ابغي الغي",
      "cancel booking", "cancel my booking",
    ];
    const isCancelTrigger = cancelPhrases.some((p) => text.includes(p.toLowerCase()));
    if (isCancelTrigger) {
      let cancelReason: string | undefined;
      if (text.includes("ظروف") || text.includes("شغل") || text.includes("سفر")) cancelReason = "user_circumstances";
      else if (text.includes("غلط") || text.includes("خطأ")) cancelReason = "user_error";
      else cancelReason = "user_request_via_chat";
      cancelRequest = { explicit: true, reason: cancelReason };
    }

    // ── 6. ⚡ Phase 6: My Bookings Query Interceptor ──────────────────────────
    let bookingsQuery: { explicit: boolean; queryType?: string } | null = null;
    const bookingsPhrases = [
      "حجوزاتي", "حجوزاتى", "حجوزاتي القادمة", "حجوزاتي النشطة",
      "عندي حجز امتى", "عندى حجز امتى", "عندي حجز", "عندى حجز",
      "شوفلي حجوزاتي", "شوفلي حجزي", "شوفلي الحجز",
      "مواعيد لعبي", "سجل الحجوزات", "مستحقات الاسترداد", "فلوس الاسترداد",
      "my bookings", "my booking",
    ];
    const isBookingsQueryTrigger = bookingsPhrases.some((p) => text.includes(p.toLowerCase()));
    if (isBookingsQueryTrigger && !isCancelTrigger && !isExplicitBookingTrigger) {
      let qType = "all";
      if (text.includes("قادمة") || text.includes("نشطة") || text.includes("امتى") || text.includes("الجاية")) qType = "active";
      else if (text.includes("سابقة") || text.includes("قديمة") || text.includes("منتهية")) qType = "past";
      else if (text.includes("استرداد") || text.includes("مستحقات") || text.includes("فلوس")) qType = "refunds";
      bookingsQuery = { explicit: true, queryType: qType };
    }

    // ── 7. ⚡ Phase 7: Owner Query Interceptor ────────────────────────────────
    let ownerQuery: { type: "financial" | "bookings" } | null = null;
    const ownerFinPhrases = [
      "أرباحي", "ارباحي", "فلوسي", "رصيدي", "مديونيتي", "حسابي كام",
      "عايز اسحب", "السجل المالي", "إيراداتي", "ايراداتي", "ارباح الملعب",
    ];
    const ownerSchedulePhrases = [
      "حجوزات ملعبي", "حجوزات ملاعبي", "مين حجز", "مين حاجز",
      "جدول الحجوزات", "حجوزات اليوم", "ملاعبي المسجلة", "ملاعبي",
    ];
    if (ownerFinPhrases.some((p) => text.includes(p.toLowerCase()))) {
      ownerQuery = { type: "financial" };
    } else if (ownerSchedulePhrases.some((p) => text.includes(p.toLowerCase()))) {
      ownerQuery = { type: "bookings" };
    }

    return {
      rentBall,
      ballClarification,
      isGoalkeeperSearch,
      isRecurringBooking,
      bookingRequest,
      cancelRequest,
      bookingsQuery,
      ownerQuery,
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
// ⚽ Unified Atomic Booking Executor
// ==========================================

async function executeBookingFlow({
  supabase,
  callerUser,
  userGov,
  stadiumId,
  stadiumName,
  date,
  time,
  rentBall,
  fallbackSlots,
  contextSnapshot,
  userMessage,
}: {
  supabase: any;
  callerUser: any;
  userGov: string;
  stadiumId?: string;
  stadiumName?: string;
  date?: string;
  time?: string;
  rentBall?: boolean;
  fallbackSlots?: string[];
  contextSnapshot: any;
  userMessage?: string;
}): Promise<{
  reply: string;
  action: any;
  stadiumResults: any[];
  clarification?: any;
}> {
  const targetStadium = await findMatchingStadium(supabase, stadiumName, stadiumId, userGov);
  if (!targetStadium) {
    // ⚡ Phase 4 — Truth Guard: Distinguish "not found" from "not specified"
    if (stadiumName && stadiumName.trim().length > 0) {
      // Name was given but not matched → it might be hallucinated or misspelled
      return {
        reply: `عذراً يا كابتن! ما لقيتش ملعب بإسم "${stadiumName}" في قاعدة بيانات VSP. ابحث عن الملعب من خلال البحث في القائمة أو أرسل اسمه مرة تانية.`,
        action: null,
        stadiumResults: [],
        clarification: null,
      };
    }

    // No stadium name at all → offer top stadiums in userGov as chips
    const { data: topStadiums } = await supabase
      .from("stadiums")
      .select("id, name, governorate")
      .eq("is_verified", true)
      .eq("is_blocked", false)
      .eq("is_deleted_by_owner", false)
      .limit(4);

    const govStadiums = (topStadiums || []).filter((s: any) => {
      if (!userGov) return true;
      const normGov = normalizeArabic(s.governorate);
      const normUserGov = normalizeArabic(userGov);
      return normGov.includes(normUserGov) || normUserGov.includes(normGov);
    }).slice(0, 3);

    if (govStadiums.length > 0) {
      const clar = {
        type: "stadium",
        question: "أي ملعب تحب تحجز فيه يا كابتن؟",
        options: govStadiums.map((s: any) => ({ id: s.id, label: s.name })),
      };
      contextSnapshot.pending_intent = {
        intent: "create_booking",
        stadium_id: null,
        time,
        date,
        rent_ball: rentBall === true,
        fallback_slots: fallbackSlots,
        clarification_type: "stadium",
      };
      contextSnapshot.clarification = clar;
      return {
        reply: clar.question,
        action: null,
        stadiumResults: govStadiums,
        clarification: clar,
      };
    }

    return {
      reply: "عذراً يا كابتن، لم يتم العثور على ملاعب متاحة حالياً في منطقتك.",
      action: null,
      stadiumResults: [],
    };
  }


  // 1. Stadium Disambiguation Guard
  if (targetStadium.is_ambiguous) {
    const appClar = {
      type: "stadium",
      question: "أي ملعب تقصد يا كابتن؟",
      options: targetStadium.candidates,
    };
    contextSnapshot.pending_intent = {
      intent: "create_booking",
      stadium_id: null,
      time: time,
      date: date,
      rent_ball: rentBall === true,
      fallback_slots: fallbackSlots,
      clarification_type: "stadium",
    };
    contextSnapshot.clarification = appClar;
    return {
      reply: "وجدت أكثر من ملعب مطابق يا كابتن، أي ملعب تقصد؟",
      action: null,
      stadiumResults: [],
      clarification: appClar,
    };
  }

  // 2. Parse Date & Time
  const parsedTime = parseArabicTimeAndDate(time, date, userMessage || "");

  // 3. Date Disambiguation Guard (Ambiguous Temporal Expression)
  if (parsedTime?.clarification) {
    contextSnapshot.pending_intent = {
      intent: "create_booking",
      stadium_id: targetStadium.id,
      stadium_name: targetStadium.name,
      time: parsedTime?.cairoHour !== undefined ? `${String(parsedTime.cairoHour).padStart(2, "0")}:00` : time,
      date: null,
      rent_ball: rentBall === true,
      fallback_slots: fallbackSlots && fallbackSlots.length > 0
        ? fallbackSlots
        : parsedTime?.preferredSlots && parsedTime.preferredSlots.length > 1
          ? parsedTime.preferredSlots.slice(1)
          : [],
      clarification_type: "date",
    };
    contextSnapshot.clarification = parsedTime.clarification;
    return {
      reply: parsedTime.clarification.question,
      action: null,
      stadiumResults: [targetStadium],
      clarification: parsedTime.clarification,
    };
  }

  const startTime = parsedTime.startTimeIso;
  const endTime = parsedTime.endTimeIso;
  const displaySlot = parsedTime.displayTime;

  const needsDeposit = targetStadium.needs_deposit === true;
  const paymentMethod = needsDeposit ? "paymob" : "cash";

  // 4. Build try slots (preferred + fallback slots)
  const trySlots: { start: string; end: string; display: string }[] = [
    { start: startTime, end: endTime, display: displaySlot },
  ];

  const preferred = fallbackSlots && fallbackSlots.length > 0
    ? fallbackSlots
    : parsedTime?.preferredSlots && parsedTime.preferredSlots.length > 1
      ? parsedTime.preferredSlots.slice(1)
      : [];

  if (preferred.length > 0) {
    for (const fSlot of preferred) {
      const h2 = parseInt(fSlot.split(":")[0], 10);
      if (!isNaN(h2)) {
        const targetDatePart = parsedTime?.targetDateStr || startTime.split("T")[0];
        const testDate = new Date();
        const cairoLocal = new Date(testDate.toLocaleString("en-US", { timeZone: "Africa/Cairo" }));
        const utcLocal = new Date(testDate.toLocaleString("en-US", { timeZone: "UTC" }));
        const offsetHours = Math.round((cairoLocal.getTime() - utcLocal.getTime()) / (3600 * 1000));
        const offsetSign = offsetHours >= 0 ? "+" : "-";
        const offsetStr = `${offsetSign}${String(Math.abs(offsetHours)).padStart(2, "0")}:00`;

        const s2Start = new Date(`${targetDatePart}T${String(h2).padStart(2, "0")}:00:00${offsetStr}`).toISOString();
        const s2End = new Date(new Date(s2Start).getTime() + 60 * 60 * 1000).toISOString();
        const dispH = h2 > 12 ? h2 - 12 : h2 === 0 ? 12 : h2;
        const nextH = (h2 + 1) % 24;
        const dispNextH = nextH > 12 ? nextH - 12 : nextH === 0 ? 12 : nextH;
        const period = h2 >= 12 ? "م" : "ص";
        const nextPeriod = nextH >= 12 ? "م" : "ص";
        const disp2 = `${dispH}:00 ${period} - ${dispNextH}:00 ${nextPeriod}`;
        if (s2Start !== startTime) {
          trySlots.push({ start: s2Start, end: s2End, display: disp2 });
        }
      }
    }
  }

  let bookedSlot: any = null;
  let lastErrorMsg = "";

  for (let idx = 0; idx < trySlots.length; idx++) {
    const slotToTry = trySlots[idx];

    // Conflict check against other active bookings
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
      continue;
    }

    // ⚡ Phase 5: Idempotency Key — deterministic per (user + stadium + slot)
    // Prevents double-tap / network retry from creating duplicate bookings
    const idemRaw = `${callerUser.id}:${targetStadium.id}:${slotToTry.start}`;
    const idemEncoder = new TextEncoder();
    const idemHash = await crypto.subtle.digest("SHA-256", idemEncoder.encode(idemRaw));
    const idemKey = Array.from(new Uint8Array(idemHash)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);

    // Call atomic RPC
    const { data: bookingResult, error: bookingErr } = await supabase.rpc(
      "create_booking_atomic",
      {
        p_stadium_id: targetStadium.id,
        p_user_id: callerUser.id,
        p_owner_id: targetStadium.owner_id,
        p_start_time: slotToTry.start,
        p_end_time: slotToTry.end,
        p_booking_type: "personal",
        p_total_price: targetStadium.price_per_hour,
        p_stadium_name: targetStadium.name,
        p_payment_method: paymentMethod,
        p_rent_ball: rentBall === true,
        p_idempotency_key: idemKey,
      }
    );

    if (bookingErr || (bookingResult && bookingResult.success === false)) {
      lastErrorMsg = bookingErr?.message || bookingResult?.message || "تعذر إتمام الحجز في هذا الموعد.";
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
    // ⚡ Phase 3: Instead of dead-end error, fetch real available slots and offer them as Action Chips
    if (targetStadium) {
      try {
        const checkDate = parsedTime?.targetDateStr || new Date().toISOString().split("T")[0];
        const { dayStartIso, dayEndIso } = parseTargetDate(checkDate);
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

        const allSlots = generateStandardSlots(checkDate, targetStadium);
        const availableSlots = allSlots.filter((slot: any) => {
          const sStart = new Date(slot.start_time).getTime();
          const sEnd = new Date(slot.end_time).getTime();
          for (const b of activeBookings) {
            const bStart = new Date(b.start_time).getTime();
            const bEnd = new Date(b.end_time).getTime();
            if (sStart < bEnd && sEnd > bStart) return false;
          }
          return true;
        });

        if (availableSlots.length > 0) {
          const chipSlots = availableSlots.slice(0, 3);
          const slotsChipClar = {
            type: "slot_selection",
            question: `عذراً يا كابتن! الموعد المطلوب محجوز في ${targetStadium.name}. إليك المواعيد الشاغرة القادمة، اختار:`,
            options: chipSlots.map((s: any) => ({
              id: JSON.stringify({ stadium_id: targetStadium.id, date: checkDate, time: `${String(s.hour).padStart(2, "0")}:00` }),
              label: s.display_time,
            })),
          };
          contextSnapshot.pending_intent = {
            intent: "create_booking",
            stadium_id: targetStadium.id,
            stadium_name: targetStadium.name,
            rent_ball: rentBall === true,
            fallback_slots: [],
            clarification_type: "slot_selection",
          };
          contextSnapshot.clarification = slotsChipClar;
          return {
            reply: slotsChipClar.question,
            action: null,
            stadiumResults: [targetStadium],
            clarification: slotsChipClar,
          };
        }
      } catch (_) {}
    }

    return {
      reply: `عذراً يا كابتن! ${lastErrorMsg || "المواعيد المطلوبة غير متاحة حالياً ولا توجد مواعيد شاغرة في هذا اليوم."}`,
      action: null,
      stadiumResults: targetStadium ? [targetStadium] : [],
    };

  }

  const bookingId = bookedSlot.bookingResult?.booking_id || bookedSlot.bookingResult?.id;
  contextSnapshot.last_booking_id = bookingId;
  contextSnapshot.last_booked_stadium = targetStadium.name;
  contextSnapshot.last_slot = bookedSlot.slot.display;

  const ballNote = rentBall ? " + تأجير كرة ⚽" : "";
  const fallbackNote = bookedSlot.isFallback
    ? `\n(تنبيه: الموعد الأول ${bookedSlot.originalSlot} كان غير متاح، فتم قفل موعدك البديل المفضل ${bookedSlot.slot.display})`
    : "";

  let action: any = null;
  let reply = "";

  if (needsDeposit || paymentMethod === "paymob") {
    action = {
      action_type: "OPEN_PAYMENT",
      route: "/checkout",
      label: `إتمام دفع العربون (${targetStadium.deposit_amount || 50} ج.م) وتأكيد الحجز 💳`,
      params: {
        booking_id: bookingId,
        stadium_id: targetStadium.id,
        stadium_name: targetStadium.name,
        owner_id: targetStadium.owner_id,
        start_time: bookedSlot.slot.start,
        end_time: bookedSlot.slot.end,
        deposit_amount: targetStadium.deposit_amount || 50,
        total_price: targetStadium.price_per_hour,
        slot: bookedSlot.slot.display,
        rent_ball: rentBall === true,
      },
    };
    reply = `تم قفل موعدك بنجاح (${bookedSlot.slot.display}${ballNote}) في ${targetStadium.name} يا كابتن ⚽!${fallbackNote}\nتم حفظ الحجز لمدة 5 دقائق، اضغط على الزر بالأسفل لإتمام دفع العربون (${targetStadium.deposit_amount || 50} ج.م) وتأكيد الحجز فوراً.`;
  } else {
    action = {
      action_type: "NAVIGATE",
      route: "/bookings",
      label: "عرض تفاصيل حجزي 📋",
      params: {
        booking_id: bookingId,
        stadium_id: targetStadium.id,
        stadium_name: targetStadium.name,
        owner_id: targetStadium.owner_id,
        start_time: bookedSlot.slot.start,
        end_time: bookedSlot.slot.end,
        total_price: targetStadium.price_per_hour,
      },
    };
    reply = `تم تأكيد حجزك بنجاح (${bookedSlot.slot.display}${ballNote}) في ${targetStadium.name} يا كابتن ⚽!${fallbackNote}\nالحجز مسجل بنظام الدفع كاش عند الحضور للملعب.`;
  }

  return {
    reply,
    action,
    stadiumResults: [targetStadium],
  };
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

    // 🔐 Phase 2: Owner AI entitlement. Fail closed if the subscription lookup fails.
    const effectiveUserRole = (userProfile?.role || "player").toLowerCase().trim();
    let ownerAiEnabled = effectiveUserRole !== "owner";
    let ownerSubscriptionStatus = "not_applicable";
    let ownerSubscriptionPlan: string | null = null;
    let ownerSubscriptionExpiresAt: string | null = null;

    if (effectiveUserRole === "owner") {
      const { data: ownerSub, error: ownerSubErr } = await supabase
        .from("owner_subscription_status")
        .select("subscription_plan, effective_status, subscription_expires_at, trial_ends_at")
        .eq("id", callerUser.id)
        .maybeSingle();

      if (ownerSubErr) {
        console.warn("[VSP AI] Owner subscription lookup failed; owner AI disabled.");
        ownerAiEnabled = false;
      } else {
        ownerSubscriptionStatus = ownerSub?.effective_status || "expired";
        ownerSubscriptionPlan = ownerSub?.subscription_plan || null;
        ownerSubscriptionExpiresAt = ownerSub?.subscription_expires_at || ownerSub?.trial_ends_at || null;
        ownerAiEnabled = ["active_paid", "active_trial"].includes(ownerSubscriptionStatus);
      }
    } else if (effectiveUserRole === "admin") {
      ownerAiEnabled = true;
      ownerSubscriptionStatus = "admin";
    }

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
    let debugInfo: any = null;
    let assistantReply = "";
    let handledByGemini = false;

    // ⚽ Egyptian Football Lexicon Analysis
    const lexiconAnalysis = EgyptianFootballLexicon.analyze(userMessage, contextSnapshot);

    const normalizeAction = (action: any) => finalizeAiAction(action, effectiveUserRole, ownerAiEnabled);

    // 🔄 Pending Intent Resumption (Conversation Transaction State)
    if (contextSnapshot.pending_intent) {
      const p = contextSnapshot.pending_intent;
      const clar = contextSnapshot.clarification;

      let optionMatched = false;

      // Match against Action Chips options by id or label
      if (clar && clar.options) {
        const matchedOpt = clar.options.find(
          (opt: any) =>
            userMessage.includes(opt.id) ||
            userMessage.trim() === opt.label.trim() ||
            userMessage.includes(opt.label) ||
            (userMessage.trim().length >= 3 && opt.label.includes(userMessage.trim())) ||
            ((userMessage.includes("الاولى") || userMessage.includes("الأولى") || userMessage.includes("الاول") || userMessage.includes("أول")) && opt === clar.options[0]) ||
            ((userMessage.includes("التانية") || userMessage.includes("الثانية") || userMessage.includes("التاني") || userMessage.includes("تاني")) && opt === clar.options[1])
        );

        if (matchedOpt) {
          optionMatched = true;
          if (clar.type === "date" || p.clarification_type === "date") {
            p.date = matchedOpt.id;
            p.clarification_type = null;
          } else if (clar.type === "stadium" || p.clarification_type === "stadium") {
            p.stadium_id = matchedOpt.id;
            p.stadium_name = matchedOpt.label;
            p.clarification_type = null;
          } else if (clar.type === "ball_intent" || p.clarification_type === "ball_intent") {
            p.rent_ball = matchedOpt.id === "rent_ball_booking";
            p.clarification_type = null;
          } else if (clar.type === "time" || p.clarification_type === "time") {
            // matchedOpt.id is HH:00 format (e.g. "06:00" or "18:00")
            p.time = matchedOpt.id;
            p.clarification_type = null;
          } else if (clar.type === "slot_selection" || p.clarification_type === "slot_selection") {
            // matchedOpt.id is JSON: {stadium_id, date, time}
            try {
              const slotData = JSON.parse(matchedOpt.id);
              if (slotData.stadium_id && slotData.date && slotData.time) {
                p.stadium_id = slotData.stadium_id;
                p.date = slotData.date;
                p.time = slotData.time;
                p.clarification_type = null;
              }
            } catch (_) {}
          } else if (clar.type === "cancel_selection" || p.clarification_type === "cancel_selection") {
            p.booking_id = matchedOpt.id;
            p.confirmed = true;
            p.clarification_type = null;
          } else if (clar.type === "cancel_confirmation" || p.clarification_type === "cancel_confirmation") {
            if (matchedOpt.id === "confirm_cancel_booking") {
              p.confirmed = true;
              p.clarification_type = null;
            }
          }          } else if (clar.type === "leave_match_confirmation" || p.clarification_type === "leave_match_confirmation") {
            if (matchedOpt.id === "confirm_leave_match") {
              p.confirmed = true;
              p.clarification_type = null;
            }
          } else if (clar.type === "leave_tournament_confirmation" || p.clarification_type === "leave_tournament_confirmation") {
            if (matchedOpt.id === "confirm_leave_tournament") {
              p.confirmed = true;
              p.clarification_type = null;
            }
          } else if (clar.type === "owner_manual_booking_confirmation" || p.clarification_type === "owner_manual_booking_confirmation") {
            if (matchedOpt.id === "confirm_owner_manual_booking") {
              p.confirmed = true;
              p.clarification_type = null;
            }
          }
        }
      }

      if (!optionMatched) {
        if (["cancel_confirmation", "leave_match_confirmation", "leave_tournament_confirmation", "owner_manual_booking_confirmation"].includes(p.clarification_type) &&
            /^(نعم|ايوه|أيوه|اه|أه|موافق|أكد|تأكيد|yes|confirm)$/i.test(userMessage.trim())) {
          p.confirmed = true;
          p.clarification_type = null;
        } else if (p.clarification_type === "date") {
          const dateMatch = userMessage.match(/\b\d{4}-\d{2}-\d{2}\b/);
          if (dateMatch) {
            p.date = dateMatch[0];
            p.clarification_type = null;
          }
        } else if (p.clarification_type === "stadium") {
          if (/^[0-9a-fA-F-]{36}$/.test(userMessage.trim())) {
            p.stadium_id = userMessage.trim();
            p.clarification_type = null;
          }
        } else if (p.clarification_type === "cancel_selection") {
          if (/^[0-9a-fA-F-]{36}$/.test(userMessage.trim())) {
            p.booking_id = userMessage.trim();
            p.confirmed = true;
            p.clarification_type = null;
          }
        } else if (p.clarification_type === "time") {
          // User typed HH:00 or just a number — resolve manually
          const timeMatch = userMessage.match(/\b(\d{2}):(\d{2})\b/);
          if (timeMatch) {
            p.time = `${timeMatch[1]}:${timeMatch[2]}`;
            p.clarification_type = null;
          } else {
            const hourMatch = userMessage.match(/\b(\d{1,2})\b/);
            if (hourMatch) {
              const h = parseInt(hourMatch[1], 10);
              if (h >= 0 && h <= 23) {
                p.time = `${String(h).padStart(2, "0")}:00`;
                p.clarification_type = null;
              }
            }
          }
        } else if (p.clarification_type === "slot_selection") {
          // User typed a time manually instead of tapping a chip
          const hourMatch = userMessage.match(/\b(\d{1,2})\b/);
          if (hourMatch) {
            const h = parseInt(hourMatch[1], 10);
            if (h >= 0 && h <= 23) {
              const resolvedH = h <= 6 || h >= 13 ? h : h + 12; // default to PM for 7-12
              p.time = `${String(resolvedH).padStart(2, "00")}:00`;
              p.clarification_type = null;
            }
          }
        }
      }

      // ⚡ Confirmed leave-match -> use the existing atomic domain RPC.
      if (p.intent === "leave_match" && p.booking_id && p.confirmed === true &&
          hasConfirmedPendingIntent(contextSnapshot, "leave_match", "booking_id", p.booking_id) &&
          !p.clarification_type) {
        contextSnapshot.pending_intent = null;
        contextSnapshot.clarification = null;
        const { data: leaveResult, error: leaveErr } = await supabase.rpc("leave_public_match_atomic", {
          p_booking_id: p.booking_id,
          p_user_id: callerUser.id,
        });
        assistantReply = !leaveErr && leaveResult === true
          ? "تمام يا كابتن، خرجتك من المباراة بنجاح ✅"
          : "ماقدرتش أخرجك من المباراة. ممكن تكون خرجت منها بالفعل أو لم تعد مشاركاً فيها.";
        if (!leaveErr && leaveResult === true) {
          appAction = buildAiAction("PLAYER_LEAVE_MATCH", {
            action_type: "NAVIGATE",
            route: "/match/" + p.booking_id,
            label: "فتح تفاصيل المباراة 📋",
            params: { booking_id: p.booking_id },
          });
        }
        handledByGemini = true;
      }

      // ⚡ Confirmed tournament withdrawal -> verify captain and use atomic RPC.
      if (p.intent === "leave_tournament" && p.championship_id && p.confirmed === true &&
          hasConfirmedPendingIntent(contextSnapshot, "leave_tournament", "championship_id", p.championship_id) &&
          !p.clarification_type) {
        contextSnapshot.pending_intent = null;
        contextSnapshot.clarification = null;
        const { data: team } = await supabase
          .from("teams")
          .select("id, name, captain_id")
          .eq("captain_id", callerUser.id)
          .limit(1)
          .maybeSingle();
        if (!team) {
          assistantReply = "الانسحاب من البطولة متاح لقائد الفريق المسجل فقط.";
        } else {
          const { data: leaveResult, error: leaveErr } = await supabase.rpc("leave_championship_atomic", {
            p_championship_id: p.championship_id,
            p_team_id: team.id,
          });
          if (!leaveErr && leaveResult?.success !== false) {
            assistantReply = "تم انسحاب فريقك من البطولة بنجاح ✅";
            appAction = buildAiAction("PLAYER_LEAVE_TOURNAMENT", {
              action_type: "NAVIGATE",
              route: "/championship/" + p.championship_id,
              label: "فتح تفاصيل البطولة 🏆",
              params: { championship_id: p.championship_id },
            });
          } else {
            assistantReply = "ماقدرتش أنفذ الانسحاب من البطولة. راجع حالة البطولة والفريق وحاول مرة أخرى.";
          }
        }
        handledByGemini = true;
      }

      // ⚡ Confirmed owner manual booking -> server-authoritative price + atomic RPC.
      if (p.intent === "owner_manual_booking" && p.stadium_id && p.start_time && p.end_time && p.confirmed === true &&
          hasConfirmedPendingIntent(contextSnapshot, "owner_manual_booking", "stadium_id", p.stadium_id) &&
          !p.clarification_type) {
        contextSnapshot.pending_intent = null;
        contextSnapshot.clarification = null;
        const start = new Date(p.start_time);
        const end = new Date(p.end_time);
        const { data: stadium, error: stadiumErr } = await supabase
          .from("stadiums")
          .select("id, owner_id, price_per_hour")
          .eq("id", p.stadium_id)
          .eq("owner_id", callerUser.id)
          .maybeSingle();
        if (stadiumErr || !stadium || isNaN(start.getTime()) || isNaN(end.getTime()) || end <= start) {
          assistantReply = "ماقدرتش أتحقق من الملعب والموعد للحجز اليدوي.";
        } else {
          const hours = (end.getTime() - start.getTime()) / 3600000;
          const totalPrice = Number(stadium.price_per_hour || 0) * hours;
          const { data: result, error: rpcErr } = await supabase.rpc("owner_create_manual_booking_atomic", {
            p_owner_id: callerUser.id,
            p_stadium_id: p.stadium_id,
            p_start_time: start.toISOString(),
            p_end_time: end.toISOString(),
            p_customer_name: p.customer_name || null,
            p_customer_phone: p.customer_phone || null,
            p_notes: p.notes || null,
            p_total_price: totalPrice,
            p_collected_amount: Number(p.collected_amount || 0),
            p_current_players: Number(p.current_players || 0),
          });
          if (!rpcErr) {
            assistantReply = "تم تسجيل الحجز اليدوي بنجاح ✅";
            appAction = buildAiAction("OWNER_VIEW_UPCOMING_BOOKINGS", {
              action_type: "NAVIGATE", route: "/owner", label: "عرض الحجوزات 📅",
            });
          } else {
            assistantReply = "ماقدرتش أسجل الحجز اليدوي. ممكن الموعد اتاخد بالفعل أو البيانات غير صالحة.";
          }
        }
        handledByGemini = true;
      }

      // ⚡ If pending create_booking intent is now fully resolved -> Execute atomically without Gemini!
      if (p.intent === "create_booking" && p.stadium_id && p.date && !p.clarification_type) {
        contextSnapshot.pending_intent = null;
        contextSnapshot.clarification = null;

        const bookingRes = await executeBookingFlow({
          supabase,
          callerUser,
          userGov,
          stadiumId: p.stadium_id,
          stadiumName: p.stadium_name,
          date: p.date,
          time: p.time,
          rentBall: p.rent_ball,
          fallbackSlots: p.fallback_slots,
          contextSnapshot,
          userMessage,
        });

        assistantReply = bookingRes.reply;
        appAction = bookingRes.action;
        stadiumResults = bookingRes.stadiumResults;
        if (bookingRes.clarification) {
          appClarification = bookingRes.clarification;
        }
        handledByGemini = true;
      }

      // ⚡ If pending cancel_booking intent is now fully resolved -> Execute atomically without Gemini!
      if (p.intent === "cancel_booking" && p.booking_id && p.confirmed === true &&
          hasConfirmedPendingIntent(contextSnapshot, "cancel_booking", "booking_id", p.booking_id) &&
          !p.clarification_type) {
        contextSnapshot.pending_intent = null;
        contextSnapshot.clarification = null;

        const cancelReason = p.reason || "user_request_via_chat";
        const { data: bRow } = await supabase
          .from("bookings")
          .select("id, stadium_name, start_time, status, is_paid, deposit_amount")
          .eq("id", p.booking_id)
          .or(`user_id.eq.${callerUser.id},created_by_user_id.eq.${callerUser.id}`)
          .maybeSingle();

        if (bRow && ["pending", "confirmed"].includes(bRow.status)) {
          const { data: cancelResult, error: cancelErr } = await supabase.rpc("cancel_booking_with_refund_atomic", {
            p_booking_id: p.booking_id,
            p_reason: cancelReason,
            p_user_id: callerUser.id,
          });
          if (!cancelErr && cancelResult?.success === true) {
            contextSnapshot.last_booking_id = null;
            const refundAmount = Number(cancelResult.refund_amount || 0);
            const needsRefund = refundAmount > 0;
            assistantReply = `تمام يا كابتن، تم إلغاء حجزك في ${bRow.stadium_name} بنجاح ✅${needsRefund ? "\nمبلغ الاسترداد: " + refundAmount.toFixed(2) + " ج.م 💰" : ""}`;
            appAction = { action_type: "NAVIGATE", route: needsRefund ? "/refunds" : "/bookings", label: needsRefund ? "تتبع الاسترداد 💰" : "عرض سجل الحجوزات 📋" };
          } else {
            assistantReply = cancelResult?.message || cancelErr?.message || "تعذر إلغاء الحجز حالياً.";
          }
          handledByGemini = true;
        } else {
          assistantReply = "الحجز ده غير متاح للإلغاء أو ملغي بالفعل يا كابتن.";
          handledByGemini = true;
        }
      }

    // 🔐 Owner entitlement fast-path for requests that require the paid Owner AI.
    if (effectiveUserRole === "owner" && !ownerAiEnabled && !handledByGemini && lexiconAnalysis.ownerQuery) {
      assistantReply = "اشتراك إدارة الملاعب غير نشط حالياً. جدّد الباقة لاستعادة أدوات الذكاء الاصطناعي الخاصة بالمالك.";
      appAction = buildAiAction("OWNER_RENEW_SUBSCRIPTION", {
        action_type: "NAVIGATE",
        route: "/facility-onboarding",
        label: "تجديد الباقة وتفعيل VSP AI 🔓",
      });
      handledByGemini = true;
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

    // ⚡ Phase 3: Pre-Gemini Booking Guard
    // If lexicon detected an explicit booking request, execute immediately without Gemini.
    if (lexiconAnalysis.bookingRequest && !handledByGemini && !contextSnapshot.pending_intent) {
      const br = lexiconAnalysis.bookingRequest;
      const bookingRes = await executeBookingFlow({
        supabase,
        callerUser,
        userGov,
        stadiumName: br.stadiumName,
        date: br.date,
        time: br.time,
        rentBall: br.rentBall,
        fallbackSlots: br.fallbackSlots,
        contextSnapshot,
        userMessage,
      });
      assistantReply = bookingRes.reply;
      appAction = bookingRes.action;
      stadiumResults = bookingRes.stadiumResults;
      if (bookingRes.clarification) {
        appClarification = bookingRes.clarification;
      }
      handledByGemini = true;
    }

    // ⚡ Phase 6: Pre-Cancel Guard
    // If lexicon detected "الغي حجزي", cancel directly without Gemini
    if (lexiconAnalysis.cancelRequest?.explicit && !handledByGemini && userProfile?.role !== "owner") {
      const cancelReason = lexiconAnalysis.cancelRequest.reason || "user_request_via_chat";
      let targetBookingId = contextSnapshot.last_booking_id || null;

      if (!targetBookingId) {
        const { data: activeList } = await supabase
          .from("bookings")
          .select("id, stadium_name, start_time, status, is_paid, deposit_amount")
          .or(`user_id.eq.${callerUser.id},created_by_user_id.eq.${callerUser.id}`)
          .in("status", ["pending", "confirmed"])
          .gte("start_time", new Date().toISOString())
          .order("start_time", { ascending: true })
          .limit(3);

        const list = activeList || [];
        if (list.length === 0) {
          assistantReply = "ما لقيتش عندك حجوزات نشطة قادمة تقدر تلغيها يا كابتن 🤷‍♂️";
          handledByGemini = true;
        } else if (list.length === 1) {
          targetBookingId = list[0].id;
          const b = list[0];
          const clar = {
            type: "cancel_confirmation",
            question: `تأكد إنك عايز تلغي حجز ${b.stadium_name}؟`,
            options: [
              { id: "confirm_cancel_booking", label: "تأكيد الإلغاء" },
              { id: "keep_booking", label: "لا، خليه" },
            ],
          };
          appClarification = clar;
          contextSnapshot.pending_intent = {
            intent: "cancel_booking",
            booking_id: b.id,
            reason: cancelReason,
            clarification_type: "cancel_confirmation",
            confirmed: false,
          };
          contextSnapshot.clarification = clar;
          assistantReply = "قبل ما ألغي الحجز، محتاج تأكيدك.";
          handledByGemini = true;
        } else {
          // Multiple active bookings -> Progressive Clarification with Action Chips
          const clar = {
            type: "cancel_selection",
            question: "عندك أكتر من حجز نشط يا كابتن. تحب تلغي أنهي حجز؟",
            options: list.map((b: any) => ({
              id: b.id,
              label: `${b.stadium_name} (${new Date(b.start_time).toLocaleDateString("ar-EG", { weekday: "short", day: "numeric", month: "numeric" })})`,
            })),
          };
          appClarification = clar;
          contextSnapshot.pending_intent = { intent: "cancel_booking", clarification_type: "cancel_selection", reason: cancelReason, confirmed: false };
          contextSnapshot.clarification = clar;
          assistantReply = "عندك أكتر من حجز قادم. اختر الحجز اللي عايز تلغيه:";
          handledByGemini = true;
        }
      }

      if (targetBookingId && !handledByGemini) {
        const { data: bRow } = await supabase.from("bookings").select("id, stadium_name, start_time, status, is_paid, deposit_amount").eq("id", targetBookingId).maybeSingle();
        if (bRow && ["pending", "confirmed"].includes(bRow.status)) {
          const { data: cancelResult, error: cancelErr } = await supabase.rpc("cancel_booking_with_refund_atomic", {
            p_booking_id: targetBookingId,
            p_reason: cancelReason,
            p_user_id: callerUser.id,
          });
          if (!cancelErr && cancelResult?.success === true) {
            contextSnapshot.last_booking_id = null;
            const refundAmount = Number(cancelResult.refund_amount || 0);
            const needsRefund = refundAmount > 0;
            assistantReply = `تمام يا كابتن، تم إلغاء حجزك في ${bRow.stadium_name} بنجاح ✅${needsRefund ? "\nمبلغ الاسترداد: " + refundAmount.toFixed(2) + " ج.م 💰" : ""}`;
            appAction = { action_type: "NAVIGATE", route: needsRefund ? "/refunds" : "/bookings", label: needsRefund ? "تتبع الاسترداد 💰" : "عرض سجل الحجوزات 📋" };
          } else {
            assistantReply = cancelResult?.message || cancelErr?.message || "تعذر إلغاء الحجز حالياً.";
          }
          handledByGemini = true;
        } else {
          assistantReply = "ما لقيتش حجز نشط متاح للإلغاء يا كابتن.";
          handledByGemini = true;
        }
      }
    }

    // ⚡ Phase 6: Pre-Gemini My Bookings Query Fast-Path
    if (lexiconAnalysis.bookingsQuery?.explicit && !handledByGemini && userProfile?.role !== "owner") {
      const qType = lexiconAnalysis.bookingsQuery.queryType || "active";
      const nowIso = new Date().toISOString();
      let bQuery = supabase
        .from("bookings")
        .select("id, stadium_name, start_time, end_time, status, payment_status, total_price, deposit_amount, refund_amount")
        .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
        .order("start_time", { ascending: false })
        .limit(5);

      if (qType === "active") {
        bQuery = bQuery.in("status", ["pending", "confirmed"]).gte("start_time", nowIso);
      } else if (qType === "past") {
        bQuery = bQuery.lt("start_time", nowIso);
      } else if (qType === "refunds") {
        bQuery = bQuery.or("status.eq.cancelled,refund_amount.gt.0");
      }

      const { data: bList } = await bQuery;
      const list = bList || [];

      if (qType === "refunds") {
        if (list.length === 0) {
          assistantReply = "ما عندكش أي مستحقات استرداد معلقة حالياً يا كابتن ✅";
        } else {
          assistantReply = `عندك ${list.length} حجز مرتبط بالاسترداد. تقدر تتابع حالة الاسترداد مباشرة من شاشة المستحقات 💰`;
          appAction = { action_type: "NAVIGATE", route: "/refunds", label: "تتبع المستحقات 💰" };
        }
      } else if (list.length === 0) {
        assistantReply = "ما لقيتش عندك حجوزات قادمة يا كابتن. تحب أحجزلك ملعب قريب تلعب فيه؟ ⚽";
        appAction = { action_type: "NAVIGATE", route: "/stadiums", label: "استعراض الملاعب 🏟️" };
      } else {
        const nextB = list[0];
        contextSnapshot.last_booking_id = nextB.id;
        contextSnapshot.last_booked_stadium = nextB.stadium_name;
        const d = new Date(nextB.start_time);
        const dateStr = d.toLocaleDateString("ar-EG", { weekday: "long", year: "numeric", month: "long", day: "numeric" });
        const timeStr = d.toLocaleTimeString("ar-EG", { hour: "2-digit", minute: "2-digit" });

        let msg = `عندك حجز قادم في **${nextB.stadium_name}** ⚽\n📅 ${dateStr}\n⏰ الساعة ${timeStr}\nالحالة: ${nextB.status === "confirmed" ? "مؤكد ✅" : "معلق الدفع ⏳"}`;
        if (list.length > 1) {
          msg += `\n(وعندك ${list.length - 1} حجز تاني مسجل)`;
        }
        assistantReply = msg;
        appAction = { action_type: "NAVIGATE", route: "/bookings", label: "عرض كل الحجوزات 📋" };
      }
      handledByGemini = true;
    }

    // ⚡ Phase 7: Pre-Gemini Owner Fast-Path (Financial & Booking Schedule)
    if (effectiveUserRole === "owner" && ownerAiEnabled && !handledByGemini) {
      if (lexiconAnalysis.ownerQuery?.type === "operational" || lexiconAnalysis.ownerQuery?.type === "analytics") {
        const requestedPeriod = lexiconAnalysis.ownerQuery?.period || "30d";
        const period = ["7d", "30d", "90d", "all"].includes(requestedPeriod) ? requestedPeriod : "30d";
        const { data: opSummary, error: opErr } = await supabase.rpc("get_owner_ai_operational_insights", {
          p_owner_id: callerUser.id,
          p_period: period,
        });

        if (opErr || !opSummary?.success) {
          assistantReply = "تعذر قراءة مؤشرات التشغيل من قاعدة البيانات حالياً. حاول مرة أخرى بعد قليل.";
        } else {
          const periodLabel = opSummary.period === "7d" ? "آخر 7 أيام" : opSummary.period === "90d" ? "آخر 90 يوم" : opSummary.period === "all" ? "كل البيانات المتاحة" : "آخر 30 يوم";
          const alerts = Array.isArray(opSummary.alerts) ? opSummary.alerts : [];
          const alertText = alerts.length ? "\n\nملاحظات مبنية على البيانات:\n" + alerts.map((a: any) => "• " + a.message_ar).join("\n") : "";
          const peak = opSummary.peak_start_hour_cairo == null ? "غير متاح لعدم وجود حجوزات" : String(opSummary.peak_start_hour_cairo).padStart(2, "0") + ":00 (" + opSummary.peak_hour_bookings + " حجز)";
          assistantReply = "تحليل تشغيل ملاعبك — " + periodLabel + ":\n" +
            "🏟️ عدد الملاعب: " + opSummary.stadium_count + "\n" +
            "📅 الحجوزات: " + opSummary.total_bookings + " (مكتملة: " + opSummary.completed_bookings + "، ملغاة: " + opSummary.cancelled_bookings + ")\n" +
            "⏱️ الساعات المحجوزة: " + Number(opSummary.booked_hours || 0).toFixed(1) + " من " + Number(opSummary.available_hours_estimate || 0).toFixed(1) + " ساعة متاحة تقديرياً\n" +
            "📊 نسبة الإشغال: " + Number(opSummary.utilization_pct || 0).toFixed(2) + "%\n" +
            "❌ معدل الإلغاء: " + Number(opSummary.cancellation_rate_pct || 0).toFixed(2) + "%\n" +
            "💰 الإيراد المحقق: " + Number(opSummary.realized_revenue || 0).toFixed(2) + " ج.م\n" +
            "🔥 ساعة الذروة: " + peak + alertText;
          handledByGemini = true;
        }
      } else if (lexiconAnalysis.ownerQuery?.type === "financial") {
        const { data: finSummary } = await supabase.rpc(
          "get_owner_financial_summary",
          { p_owner_id: callerUser.id }
        );

        if (finSummary && finSummary.success !== false) {
          const avail = Number(finSummary.available_balance || 0).toFixed(2);
          const totalOnline = Number(finSummary.total_online_revenue || 0).toFixed(2);
          const cashRev = Number(finSummary.cash_revenue || 0).toFixed(2);
          const debt = Number(finSummary.accumulated_cash_debt || 0).toFixed(2);
          const completedCount = finSummary.completed_bookings_count || 0;

          assistantReply = `أهلاً بك يا كابتن (مالك الملعب) ⚽\nإليك الملخص المالي لحسابك:\n💰 **الرصيد المتاح للسحب:** ${avail} ج.م\n📈 **إجمالي الدخل الإلكتروني:** ${totalOnline} ج.م\n💵 **إيرادات الكاش المحصلة:** ${cashRev} ج.م\n⚠️ **مديونية الكاش للمنصة:** ${debt} ج.م\n✅ **الحجوزات المكتملة:** ${completedCount} حجز\n\nتقدر تطلب سحب أرباحك مباشرة من شاشة السجل المالي!`;
          appAction = {
            action_type: "NAVIGATE",
            route: "/ledger",
            label: "فتح السجل المالي والمستحقات 💰",
          };
          handledByGemini = true;
        }
      } else if (lexiconAnalysis.ownerQuery?.type === "bookings") {
        const { data: ownerStadiums } = await supabase
          .from("stadiums")
          .select("id, name")
          .eq("owner_id", callerUser.id)
          .eq("is_deleted_by_owner", false);

        const stadiumIds = (ownerStadiums || []).map((s: any) => s.id);
        if (stadiumIds.length > 0) {
          const { data: bList } = await supabase
            .from("bookings")
            .select("id, stadium_name, start_time, end_time, status, host_name, total_price")
            .in("stadium_id", stadiumIds)
            .gte("start_time", new Date().toISOString())
            .order("start_time", { ascending: true })
            .limit(5);

          const upBookings = bList || [];
          if (upBookings.length === 0) {
            assistantReply = `أهلاً يا كابتن، ملاعبك المسجلة (${ownerStadiums?.length || 0} ملعب) جاهزة، ومافيش حجوزات قادمة مسجلة حالياً 🏟️`;
          } else {
            const listStr = upBookings.map((b: any) => {
              const d = new Date(b.start_time);
              const dateS = d.toLocaleDateString("ar-EG", { weekday: "short", day: "numeric", month: "numeric" });
              const timeS = d.toLocaleTimeString("ar-EG", { hour: "2-digit", minute: "2-digit" });
              return `• **${b.stadium_name}**: ${dateS} الساعة ${timeS} (${b.status === "confirmed" ? "مؤكد ✅" : "معلق ⏳"})`;
            }).join("\n");

            assistantReply = `يا كابتن! دي الحجوزات القادمة في ملاعبك (${upBookings.length} حجز):\n${listStr}`;
          }
          appAction = {
            action_type: "NAVIGATE",
            route: "/bookings",
            label: "فتح جدول الحجوزات 📅",
          };
          handledByGemini = true;
        }
      }
    }

    // Gemini 2.5 Flash Interaction
    if (!handledByGemini && geminiApiKey) {

      try {
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
1. عند طلب حجز ملعب أو موعد (مثال: "احجزلي الجمعة الجاية الساعة 9 في ملعب الصداقة"، "احجزلي في ملعب الصداقة 2 بليل"، "احجزلي 2 بليل"، "احجزلي الجمعة الجاية الساعة 9"، "احجزلي الساعة 8"):
   - استدعِ createBookingFromChat فوراً وبدون تردد مع استخراج البيانات.
   - إذا لم يذكر تاريخاً صراحة (مثل "احجزلي 2 بليل" أو "احجزلي الساعة 8")، مرر date: 'اليوم'.
   - إذا لم يذكر اسم ملعب، اتركه فارغاً.
   - إذا ذكر "عايز كورة" أو "مع كورة": مرر rent_ball: true.
   - إذا ذكر شرط بديل "لو مفيش 8 خليه 9" أو "لو مفيش خليه 10": مرر fallback_slots.
   - ممنوع سؤال المستخدم نصياً قبل استدعاء الأداة؛ فالأداة والـ Guard هما المسؤولان عن التحقق وتوليد Action Chips في حال وجود غموض!
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
2. لا تخترع ملاعب أو بطولات أو أسعاراً أو تواريخ غير موجودة.
3. لحجز ملعب أو تحديد موعد: استدعِ createBookingFromChat فوراً وبلا استثناء، وممنوع منعاً باتاً الإجابة بنص تأكيدي أو سؤال المستخدم نصياً أو تخمين تواريخ قبل استدعاء الأداة! الأداة والـ Guard هما المسؤولان عن التحقق وسؤال المستخدم عبر Action Chips إن لزم.
4. لفحص التوافر والمواعيد الشاغرة: استدعِ checkStadiumAvailability فوراً.
5. للبحث عن ملاعب: استدعِ searchStadiums فوراً.
6. لمغادرة مباراة أو بطولة: استخدم أداة المغادرة، ولا تمرر confirmed=true إلا بعد تأكيد صريح من المستخدم.
7. مالك الملعب يمكنه تسجيل حجز يدوي فقط بعد تحديد الملعب والموعد وطلب تأكيد صريح قبل التنفيذ.`;

        // 🔒 Phase 2: Build role-filtered tool list — Gemini sees ONLY allowed tools
        const userRole = userProfile?.role || "player";
        const roleFilteredTools = buildToolRegistryForRole(userRole, ownerAiEnabled);

        const firstPayload = {
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: contents,
          tools: [{ functionDeclarations: roleFilteredTools }],
          toolConfig: {
            functionCallingConfig: {
              mode: "AUTO",
            },
          },
        };

        let geminiModel = "gemini-2.5-flash";
        let geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiApiKey}`;

        let geminiRes1 = await fetch(geminiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(firstPayload),
        });

        // 🛡️ High-Availability Model Fallback on 429 Quota
        if (geminiRes1.status === 429) {
          geminiModel = "gemini-flash-latest";
          geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiApiKey}`;
          geminiRes1 = await fetch(geminiUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(firstPayload),
          });
        }

        if (geminiRes1.ok) {
          const geminiData1 = await geminiRes1.json();
          const candidate1 = geminiData1.candidates?.[0]?.content;
          const functionCallPart = candidate1?.parts?.find((p: any) => p.functionCall);

          if (functionCallPart) {
            const funcName = functionCallPart.functionCall.name;
            const args = functionCallPart.functionCall.args || {};
            let toolResponseData: any = {};

            // 🔒 Phase 2: Server-side tool authorization guard
            // Reject any tool call that is not permitted for this user's role,
            // even if Gemini somehow emitted it.
            const userRoleForGuard = userProfile?.role || "player";
            if (!isToolAllowedForRole(funcName, userRoleForGuard, ownerAiEnabled)) {
              console.warn(`[VSP Security] Role '${userRoleForGuard}' attempted unauthorized tool: ${funcName}`);
              if (
                userRoleForGuard === "owner" &&
                OWNER_ONLY_TOOLS.some((t) => t.name === funcName) &&
                !ownerAiEnabled
              ) {
                const renewalAction = buildAiAction("OWNER_RENEW_SUBSCRIPTION", {
                  action_type: "NAVIGATE",
                  route: "/facility-onboarding",
                  label: "تجديد باقة المالك وتفعيل VSP AI 🔓",
                });
                return new Response(
                  JSON.stringify({
                    conversation_id: conversationId,
                    message: "انتهت صلاحية اشتراك إدارة الملاعب. جدّد الباقة لتفعيل الذكاء الاصطناعي التشغيلي للمالك.",
                    error: { code: "OWNER_AI_SUBSCRIPTION_REQUIRED", subscription_status: ownerSubscriptionStatus, subscription_plan: ownerSubscriptionPlan },
                    verification: { verified: false, source: "entitlement_guard" },
                    data: { stadiums: [], tournaments: [], open_matches: [], leaderboard: [] },
                    context_snapshot: contextSnapshot,
                    clarification: null,
                    action: renewalAction,
                  }),
                  { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
                );
              }
              return new Response(
                JSON.stringify({
                  conversation_id: conversationId,
                  message: "عذراً يا كابتن! هذه العملية غير متاحة لدورك الحالي في التطبيق.",
                  error: { code: "UNAUTHORIZED_TOOL", tool: funcName, role: userRoleForGuard },
                  verification: { verified: false, source: "security_guard" },
                  data: { stadiums: [], tournaments: [], open_matches: [], leaderboard: [] },
                  context_snapshot: contextSnapshot,
                  clarification: null,
                  action: null,
                }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
              );
            }

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
              const capabilityId = (args.capability_id || "").toString().trim().toUpperCase();
              const cap = getAiCapability(capabilityId);

              if (!capabilityId || !cap) {
                toolResponseData = {
                  success: false,
                  error: "INVALID_CAPABILITY_ID",
                  message: "يجب استخدام Capability ID معتمد من VSP AI Registry.",
                };
              } else if (!isCapabilityAllowed(capabilityId, userRoleForGuard, ownerAiEnabled)) {
                toolResponseData = {
                  success: false,
                  error: "CAPABILITY_NOT_ALLOWED",
                  capability_id: capabilityId,
                };
              } else {
                appAction = buildAiAction(capabilityId, {
                  action_type: args.action_type || (cap?.canExecuteByAi ? "EXECUTE" : "NAVIGATE"),
                  route: (args.route || "").toString(),
                  label: args.label || "فتح الشاشة",
                  params: args.params || undefined,
                });
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
                  message: "تم تحديث بيانات البروفايل بنجاح في قاعدة البيانات",
                };
              }
            } else if (funcName === "getUserBookingsAndRefunds") {
              // ⚡ Phase 6: Enhanced — active/past/refunds/all filtering
              const queryType = (args.query_type || "all").toLowerCase();
              const nowIso = new Date().toISOString();

              let bQuery = supabase
                .from("bookings")
                .select("id, stadium_name, start_time, end_time, status, payment_status, payment_method, total_price, deposit_amount, refund_amount, refunded_at, cancellation_reason, needs_deposit, is_paid, locked_until")
                .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
                .order("start_time", { ascending: false })
                .limit(10);

              if (queryType === "active") bQuery = bQuery.in("status", ["pending", "confirmed"]).gte("start_time", nowIso);
              else if (queryType === "past") bQuery = bQuery.lt("start_time", nowIso);
              else if (queryType === "refunds") bQuery = bQuery.or("status.eq.cancelled,refund_amount.gt.0");

              const { data: userBookings } = await bQuery;
              const bookingsList = userBookings || [];

              const activeBookings = bookingsList.filter((b: any) => ["pending", "confirmed"].includes(b.status) && new Date(b.start_time) > new Date());
              const refunds = bookingsList.filter((b: any) => (b.refund_amount && Number(b.refund_amount) > 0) || b.refunded_at || b.status === "cancelled");

              if (activeBookings.length > 0) {
                contextSnapshot.last_booking_id = activeBookings[0].id;
                contextSnapshot.last_booked_stadium = activeBookings[0].stadium_name;
              }

              appAction = { action_type: "NAVIGATE", route: "/bookings", label: "عرض سجل الحجوزات والمستحقات 📋" };
              toolResponseData = {
                total_bookings: bookingsList.length,
                active_bookings_count: activeBookings.length,
                active_bookings: activeBookings.slice(0, 3),
                recent_bookings: bookingsList.slice(0, 5),
                refund_related_bookings: refunds,
                has_refunds: refunds.length > 0,
                has_active: activeBookings.length > 0,
              };

            } else if (funcName === "leavePublicMatchFromChat") {
              const bookingId = (args.booking_id || contextSnapshot.last_booking_id || "").toString().trim();
              const confirmed = args.confirmed === true;
              const confirmedFromPending = hasConfirmedPendingIntent(contextSnapshot, "leave_match", "booking_id", bookingId);

              if (!bookingId || !/^[0-9a-fA-F-]{36}$/.test(bookingId)) {
                assistantReply = "محتاج أعرف أنهي مباراة تقصد.";
                toolResponseData = { success: false, message: assistantReply };
              } else if (!confirmed) {
                appClarification = {
                  type: "leave_match_confirmation",
                  question: "تأكد إنك عايز تخرج من المباراة دي؟",
                  options: [
                    { id: "confirm_leave_match", label: "تأكيد المغادرة" },
                    { id: "keep_leave_match", label: "لا، خليك" },
                  ],
                };
                contextSnapshot.pending_intent = {
                  intent: "leave_match",
                  booking_id: bookingId,
                  clarification_type: "leave_match_confirmation",
                };
                contextSnapshot.clarification = appClarification;
                assistantReply = "تمام، قبل ما أنفذ: تحب أخرجك من المباراة؟";
                toolResponseData = { success: false, needs_confirmation: true };
              } else if (!confirmedFromPending) {
                appClarification = {
                  type: "leave_match_confirmation",
                  question: "تأكد إنك عايز تخرج من المباراة دي؟",
                  options: [{ id: "confirm_leave_match", label: "تأكيد المغادرة" }, { id: "keep_leave_match", label: "لا، خليك" }],
                };
                contextSnapshot.pending_intent = { intent: "leave_match", booking_id: bookingId, clarification_type: "leave_match_confirmation", confirmed: false };
                contextSnapshot.clarification = appClarification;
                assistantReply = "تمام، قبل التنفيذ أكّد مغادرة المباراة.";
                toolResponseData = { success: false, needs_confirmation: true };
              } else {
                const { data: leaveResult, error: leaveErr } = await supabase.rpc("leave_public_match_atomic", {
                  p_booking_id: bookingId,
                  p_user_id: callerUser.id,
                });
                if (!leaveErr && leaveResult === true) {
                  assistantReply = "تم خروجك من المباراة بنجاح ✅";
                  appAction = buildAiAction("PLAYER_LEAVE_MATCH", {
                    action_type: "NAVIGATE",
                    route: "/match/" + bookingId,
                    label: "فتح تفاصيل المباراة 📋",
                    params: { booking_id: bookingId },
                  });
                } else {
                  assistantReply = "تعذر الخروج من المباراة أو لم تعد مشاركاً فيها.";
                }
                toolResponseData = { success: !leaveErr && leaveResult === true, booking_id: bookingId };
              }

            } else if (funcName === "leaveChampionshipFromChat") {
              const championshipId = (args.championship_id || "").toString().trim();
              const confirmed = args.confirmed === true;
              const confirmedFromPending = hasConfirmedPendingIntent(contextSnapshot, "leave_tournament", "championship_id", championshipId);

              if (!championshipId || !/^[0-9a-fA-F-]{36}$/.test(championshipId)) {
                assistantReply = "محتاج أعرف أنهي بطولة تقصد.";
                toolResponseData = { success: false, message: assistantReply };
              } else if (!confirmed) {
                appClarification = {
                  type: "leave_tournament_confirmation",
                  question: "تأكد إنك عايز تنسحب بفريقك من البطولة؟",
                  options: [
                    { id: "confirm_leave_tournament", label: "تأكيد الانسحاب" },
                    { id: "keep_leave_tournament", label: "لا، خليك" },
                  ],
                };
                contextSnapshot.pending_intent = {
                  intent: "leave_tournament",
                  championship_id: championshipId,
                  clarification_type: "leave_tournament_confirmation",
                };
                contextSnapshot.clarification = appClarification;
                assistantReply = "تمام، قبل ما أنفذ: تحب أنسحب بفريقك من البطولة؟";
                toolResponseData = { success: false, needs_confirmation: true };
              } else if (!confirmedFromPending) {
                appClarification = {
                  type: "leave_tournament_confirmation",
                  question: "تأكد إنك عايز تنسحب بفريقك من البطولة؟",
                  options: [{ id: "confirm_leave_tournament", label: "تأكيد الانسحاب" }, { id: "keep_leave_tournament", label: "لا، خليك" }],
                };
                contextSnapshot.pending_intent = { intent: "leave_tournament", championship_id: championshipId, clarification_type: "leave_tournament_confirmation", confirmed: false };
                contextSnapshot.clarification = appClarification;
                assistantReply = "تمام، قبل التنفيذ أكّد الانسحاب من البطولة.";
                toolResponseData = { success: false, needs_confirmation: true };
              } else {
                const { data: team } = await supabase
                  .from("teams")
                  .select("id, name, captain_id")
                  .eq("captain_id", callerUser.id)
                  .limit(1)
                  .maybeSingle();

                if (!team) {
                  assistantReply = "الانسحاب من البطولة متاح لقائد الفريق المسجل فقط.";
                  toolResponseData = { success: false, message: assistantReply };
                } else {
                  const { data: leaveResult, error: leaveErr } = await supabase.rpc("leave_championship_atomic", {
                    p_championship_id: championshipId,
                    p_team_id: team.id,
                  });
                  if (!leaveErr && leaveResult?.success !== false) {
                    assistantReply = "تم انسحاب فريقك من البطولة بنجاح ✅";
                    appAction = buildAiAction("PLAYER_LEAVE_TOURNAMENT", {
                      action_type: "NAVIGATE",
                      route: "/championship/" + championshipId,
                      label: "فتح تفاصيل البطولة 🏆",
                      params: { championship_id: championshipId },
                    });
                    toolResponseData = { success: true, championship_id: championshipId, team_id: team.id };
                  } else {
                    assistantReply = "تعذر الانسحاب من البطولة. راجع حالة البطولة وحاول مرة أخرى.";
                    toolResponseData = { success: false, message: assistantReply };
                  }
                }
              }

            } else if (funcName === "cancelBookingFromChat") {
              // ⚡ Phase 6: Cancel Booking — server-side confirmation gate.
              const bookingId = (args.booking_id || contextSnapshot.last_booking_id || "").toString().trim();
              const cancelReason = (args.reason || "user_request_via_chat").toString().trim();
              const confirmedFromPending = hasConfirmedPendingIntent(contextSnapshot, "cancel_booking", "booking_id", bookingId);

              if (!bookingId || !/^[0-9a-fA-F-]{36}$/.test(bookingId)) {
                // No ID → fetch active bookings and offer chips
                const { data: activeB } = await supabase
                  .from("bookings").select("id, stadium_name, start_time, status")
                  .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
                  .in("status", ["pending", "confirmed"]).gte("start_time", new Date().toISOString())
                  .order("start_time", { ascending: true }).limit(3);
                const actList = activeB || [];
                if (actList.length === 0) {
                  toolResponseData = { success: false, message: "ما عندكش حجوزات نشطة قادمة يا كابتن." };
                } else if (actList.length === 1) {
                  const b = actList[0];
                  const { data: cancelResult, error: cErr } = await supabase.rpc("cancel_booking_with_refund_atomic", {
                    p_booking_id: b.id,
                    p_reason: cancelReason,
                    p_user_id: callerUser.id,
                  });
                  if (!cErr && cancelResult?.success === true) {
                    contextSnapshot.last_booking_id = null;
                    appAction = { action_type: "NAVIGATE", route: Number(cancelResult.refund_amount || 0) > 0 ? "/refunds" : "/bookings", label: Number(cancelResult.refund_amount || 0) > 0 ? "تتبع الاسترداد 💰" : "عرض سجل الحجوزات 📋" };
                    toolResponseData = { success: true, cancelled_booking_id: b.id, stadium_name: b.stadium_name, start_time: b.start_time, refund_amount: Number(cancelResult.refund_amount || 0) };
                  } else {
                    toolResponseData = { success: false, message: cancelResult?.message || cErr?.message || "تعذّر إلغاء الحجز حالياً." };
                  }
                } else {
                  const clar = { type: "cancel_selection", question: "أي حجز تريد إلغاؤه يا كابتن؟", options: actList.map((b: any) => ({ id: b.id, label: `${b.stadium_name} — ${new Date(b.start_time).toLocaleDateString("ar-EG")}` })) };
                  appClarification = clar;
                  contextSnapshot.pending_intent = { intent: "cancel_booking", clarification_type: "cancel_selection" };
                  contextSnapshot.clarification = clar;
                  toolResponseData = { success: false, needs_clarification: true };
                }
              } else if (!confirmedFromPending) {
                appClarification = {
                  type: "cancel_confirmation",
                  question: "تأكد إنك عايز تلغي الحجز ده؟",
                  options: [
                    { id: "confirm_cancel_booking", label: "تأكيد الإلغاء" },
                    { id: "keep_booking", label: "لا، خليه" },
                  ],
                };
                contextSnapshot.pending_intent = {
                  intent: "cancel_booking",
                  booking_id: bookingId,
                  reason: cancelReason,
                  clarification_type: "cancel_confirmation",
                  confirmed: false,
                };
                contextSnapshot.clarification = appClarification;
                assistantReply = "تمام، قبل التنفيذ أكّد إلغاء الحجز.";
                toolResponseData = { success: false, needs_confirmation: true };
              } else {
                const { data: bRow } = await supabase.from("bookings").select("id, stadium_name, start_time, status, is_paid, deposit_amount, needs_deposit").eq("id", bookingId).or(`user_id.eq.${callerUser.id},created_by_user_id.eq.${callerUser.id}`).maybeSingle();
                if (!bRow) {
                  toolResponseData = { success: false, message: "الحجز غير موجود أو لا تملك صلاحية إلغائه." };
                } else if (!["pending", "confirmed"].includes(bRow.status)) {
                  toolResponseData = { success: false, message: `الحجز ده ${bRow.status === "cancelled" ? "ملغي بالفعل" : "مكتمل"} يا كابتن.` };
                } else {
                  const { data: cancelResult, error: cErr } = await supabase.rpc("cancel_booking_with_refund_atomic", {
                    p_booking_id: bookingId,
                    p_reason: cancelReason,
                    p_user_id: callerUser.id,
                  });
                  if (cErr || cancelResult?.success !== true) {
                    toolResponseData = { success: false, message: cancelResult?.message || cErr?.message || "تعذّر إلغاء الحجز. حاول مرة أخرى." };
                  } else {
                    contextSnapshot.last_booking_id = null;
                    const refundAmount = Number(cancelResult.refund_amount || 0);
                    const needsRefund = refundAmount > 0;
                    appAction = { action_type: "NAVIGATE", route: needsRefund ? "/refunds" : "/bookings", label: needsRefund ? "تتبع الاسترداد 💰" : "عرض سجل الحجوزات 📋" };
                    toolResponseData = { success: true, cancelled_booking_id: bookingId, stadium_name: bRow.stadium_name, needs_refund: needsRefund, refund_amount: refundAmount };
                  }
                }
              }

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
            } else if (funcName === "ownerCreateManualBooking") {
              if (userRoleForGuard !== "owner" && userRoleForGuard !== "admin") {
                toolResponseData = { success: false, error: "ROLE_NOT_ALLOWED" };
              } else if (!ownerAiEnabled && userRoleForGuard !== "admin") {
                toolResponseData = { success: false, error: "OWNER_AI_ENTITLEMENT_REQUIRED" };
                assistantReply = "اشتراك إدارة الملاعب غير نشط. جدّد الباقة أولاً.";
                appAction = buildAiAction("OWNER_RENEW_SUBSCRIPTION", {
                  action_type: "NAVIGATE",
                  route: "/facility-onboarding",
                  label: "تجديد الباقة 🔓",
                });
              } else {
                const stadiumId = String(args.stadium_id || "").trim();
                const start = new Date(String(args.start_time || ""));
                const end = new Date(String(args.end_time || ""));
                const confirmedFromPending = hasConfirmedPendingIntent(contextSnapshot, "owner_manual_booking", "stadium_id", stadiumId);
                if (!/^[0-9a-fA-F-]{36}$/.test(stadiumId) || isNaN(start.getTime()) || isNaN(end.getTime()) || end <= start) {
                  toolResponseData = { success: false, error: "INVALID_BOOKING_INPUT" };
                  assistantReply = "محتاج ملعب وموعد بداية ونهاية صحيحين للحجز اليدوي.";
                } else if (args.confirmed !== true || !confirmedFromPending) {
                  appClarification = {
                    type: "owner_manual_booking_confirmation",
                    question: "تأكد إنك عايز أسجل الحجز اليدوي ده على الملعب؟",
                    options: [
                      { id: "confirm_owner_manual_booking", label: "تأكيد الحجز" },
                      { id: "keep_owner_manual_booking", label: "إلغاء" },
                    ],
                  };
                  contextSnapshot.pending_intent = {
                    intent: "owner_manual_booking",
                    stadium_id: stadiumId,
                    start_time: start.toISOString(),
                    end_time: end.toISOString(),
                    customer_name: args.customer_name || null,
                    customer_phone: args.customer_phone || null,
                    notes: args.notes || null,
                    collected_amount: Number(args.collected_amount || 0),
                    current_players: Number(args.current_players || 0),
                    clarification_type: "owner_manual_booking_confirmation",
                    confirmed: false,
                  };
                  contextSnapshot.clarification = appClarification;
                  assistantReply = "تمام. قبل ما أسجل الحجز، أكّد العملية.";
                  toolResponseData = { success: false, needs_confirmation: true };
                } else {
                  const { data: stadium, error: stadiumErr } = await supabase
                    .from("stadiums")
                    .select("id, owner_id, price_per_hour")
                    .eq("id", stadiumId)
                    .eq("owner_id", callerUser.id)
                    .maybeSingle();
                  if (stadiumErr || !stadium) {
                    toolResponseData = { success: false, error: "STADIUM_NOT_OWNED" };
                    assistantReply = "الملعب ده مش موجود ضمن ملاعبك المسجلة.";
                  } else {
                    const hours = (end.getTime() - start.getTime()) / 3600000;
                    const totalPrice = Number(stadium.price_per_hour || 0) * hours;
                    const { data: result, error: rpcErr } = await supabase.rpc("owner_create_manual_booking_atomic", {
                      p_owner_id: callerUser.id,
                      p_stadium_id: stadiumId,
                      p_start_time: start.toISOString(),
                      p_end_time: end.toISOString(),
                      p_customer_name: args.customer_name?.toString() || null,
                      p_customer_phone: args.customer_phone?.toString() || null,
                      p_notes: args.notes?.toString() || null,
                      p_total_price: totalPrice,
                      p_collected_amount: Number(args.collected_amount || 0),
                      p_current_players: Number(args.current_players || 0),
                    });
                    if (rpcErr) {
                      toolResponseData = { success: false, error: "MANUAL_BOOKING_FAILED", details: rpcErr.message };
                      assistantReply = "ماقدرتش أسجل الحجز اليدوي. ممكن الموعد اتاخد بالفعل أو البيانات غير صالحة.";
                    } else {
                      assistantReply = "تم تسجيل الحجز اليدوي بنجاح ✅";
                      appAction = buildAiAction("OWNER_VIEW_UPCOMING_BOOKINGS", {
                        action_type: "NAVIGATE",
                        route: "/owner",
                        label: "عرض الحجوزات 📅",
                      });
                      toolResponseData = { success: true, booking: result, server_total_price: totalPrice };
                    }
                  }
                }
              }
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
              const rentBallParam = args.rent_ball === true || lexiconAnalysis.rentBall;
              const preferred = args.fallback_slots || [];

              const res = await executeBookingFlow({
                supabase,
                callerUser,
                userGov,
                stadiumId,
                stadiumName,
                date: args.date,
                time: args.time,
                rentBall: rentBallParam,
                fallbackSlots: preferred,
                contextSnapshot,
                userMessage,
              });

              if (res.clarification) {
                appClarification = res.clarification;
                assistantReply = res.reply;
              } else {
                assistantReply = res.reply;
                appAction = res.action;
                stadiumResults = res.stadiumResults;
              }

              toolResponseData = {
                success: !res.clarification && !!res.action,
                clarification: res.clarification,
                action: res.action,
                message: res.reply,
              };
            }

            if (funcName === "createBookingFromChat") {
              handledByGemini = true;
            } else {
              // Second turn for Gemini natural response (for read-only tools)
              try {
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
              } catch (_) {}

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
                } else if (funcName === "cancelBookingFromChat") {
                  assistantReply = toolResponseData.message || (toolResponseData.success ? `تمام يا كابتن، تم إلغاء حجزك في ${toolResponseData.stadium_name || 'الملعب'} بنجاح ✅` : "تعذر إلغاء الحجز حالياً يا كابتن.");
                } else if (funcName === "getUserBookingsAndRefunds") {
                  assistantReply = `يا كابتن! عندك ${toolResponseData.active_bookings_count || 0} حجز نشط، وإجمالي ${toolResponseData.total_bookings || 0} حجز مسجل في حسابك.`;
                } else if (funcName === "getOwnerOperationalInsights") {
                if (effectiveUserRole !== "owner" || !ownerAiEnabled) {
                  toolResponseData = { success: false, message: "هذه الميزة متاحة لمالك الملعب المشترك في خدمة Owner AI فقط." };
                } else {
                  const period = ["7d", "30d", "90d", "all"].includes(String(args.period || "")) ? String(args.period) : "30d";
                  const { data: insights, error: insightErr } = await supabase.rpc("get_owner_ai_operational_insights", {
                    p_owner_id: callerUser.id,
                    p_period: period,
                  });
                  if (insightErr || !insights?.success) {
                    toolResponseData = { success: false, message: "تعذر جلب مؤشرات التشغيل من قاعدة البيانات حالياً." };
                  } else {
                    toolResponseData = insights;
                  }
                }
              } else if (funcName === "getOwnerFinancialInsights") {
                  assistantReply = `يا كابتن (المالك)! الرصيد المتاح للسحب في حسابك هو ${toolResponseData.available_balance ?? 0} ج.م، وإجمالي الأرباح الإلكترونية ${toolResponseData.net_online_earnings ?? 0} ج.م.`;
                } else if (funcName === "getOwnerStadiumsAndBookings") {
                  assistantReply = `يا كابتن! لديك ${toolResponseData.owner_stadiums_count || 0} ملعب مسجل، و${toolResponseData.bookings_count || 0} حجز حالي في ملاعبك.`;
                } else {
                  assistantReply = "تمام يا كابتن، طلبك جاهز!";
                }
              }
              handledByGemini = true;
            }
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
        } else {
          const errText = await geminiRes1.text();
          debugInfo = { source: "gemini_res1", status: geminiRes1.status, body: errText };
          console.warn("Gemini call failed:", geminiRes1.status, errText);
        }
      } catch (geminiErr: any) {
        debugInfo = { source: "catch_gemini", message: geminiErr?.message || String(geminiErr) };
        console.warn("Gemini API error:", geminiErr);
      }
    }

    if (!handledByGemini) {
      assistantReply =
        "عذراً يا كابتن! حدث ضغط لحظي في خدمة الذكاء الاصطناعي، يرجى إعادة إرسال رسالتك أو تصفح الملاعب والبطولات مباشرة من القوائم.";
    }

    // 🧭 Phase 1/2: every emitted action must map to a trusted capability and entitlement.
    appAction = normalizeAction(appAction);

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

    // Phase 1: Return structured contract — full Response Contract
    return new Response(
      JSON.stringify({
        // Core identity
        conversation_id: conversationId,
        entitlement: {
          owner_ai_enabled: ownerAiEnabled,
          owner_subscription_status: ownerSubscriptionStatus,
          owner_subscription_plan: ownerSubscriptionPlan,
          owner_subscription_expires_at: ownerSubscriptionExpiresAt,
        },
        // Natural language response
        message: assistantReply,
        // Interactive clarification (Action Chips)
        clarification: appClarification ?? null,
        // In-app action (navigate, open payment, etc.)
        action: appAction ?? null,
        // Structured data payloads
        data: {
          stadiums: stadiumResults,
          tournaments: tournamentResults,
          open_matches: openMatchResults,
          leaderboard: leaderboardResults,
        },
        // Conversation memory snapshot (for Flutter to re-attach on next turn)
        context_snapshot: {
          pending_intent: contextSnapshot.pending_intent ?? null,
          last_stadium_id: contextSnapshot.last_stadium_id ?? null,
          last_stadium_name: contextSnapshot.last_stadium_name ?? null,
          last_date: contextSnapshot.last_date ?? null,
          user_role: effectiveUserRole,
          owner_ai_enabled: ownerAiEnabled,
          owner_subscription_status: ownerSubscriptionStatus,
          owner_subscription_plan: ownerSubscriptionPlan,
          owner_subscription_expires_at: ownerSubscriptionExpiresAt,
        },
        // Verification status — tells Flutter if data came from DB or was AI-generated
        verification: {
          verified: stadiumResults.length > 0 || tournamentResults.length > 0 || openMatchResults.length > 0 || !!appAction,
          source: stadiumResults.length > 0 ? "database_rpc" : (appAction ? "atomic_booking" : "gemini_text"),
        },
        // Error field — null on success
        error: null,
        // Legacy flat fields for backward compatibility with older Flutter clients
        stadiums: stadiumResults,
        tournaments: tournamentResults,
        leaderboard: leaderboardResults,
        open_matches: openMatchResults,
        debug: debugInfo,
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
