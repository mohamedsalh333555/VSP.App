// Application-Controlled Capability Registry for VSP Copilot
// Declares all permissible operational capabilities with role policies, risk levels, and workflow mapping.

export type RoleType = "player" | "owner" | "admin";
export type RiskLevel = "low" | "medium" | "high";

export interface CapabilityDefinition {
  id: string;
  domain: string;
  object: string;
  action: string;
  sub_action?: string;
  allowed_roles: RoleType[];
  is_read_only: boolean;
  risk_level: RiskLevel;
  workflow_id: string;
  tool_id: string | null;
  description: string;
}

export const CAPABILITY_REGISTRY: Record<string, CapabilityDefinition> = {
  VIEW_USER_BOOKINGS: {
    id: "VIEW_USER_BOOKINGS",
    domain: "self_service",
    object: "booking",
    action: "inspect",
    sub_action: "recent",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_view_user_bookings",
    tool_id: "getUserBookingsAndRefunds",
    description: "استعراض حجوزات اللاعب الحالية والسابقة ومواعيدها وحالاتها",
  },
  VIEW_UPCOMING_BOOKING: {
    id: "VIEW_UPCOMING_BOOKING",
    domain: "self_service",
    object: "booking",
    action: "inspect",
    sub_action: "upcoming",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_view_upcoming_booking",
    tool_id: "getUserBookingsAndRefunds",
    description: "استعراض ميعاد الحجز القادم الأقرب للاعب",
  },
  VIEW_BOOKING_DETAILS: {
    id: "VIEW_BOOKING_DETAILS",
    domain: "self_service",
    object: "booking",
    action: "inspect",
    sub_action: "details",
    allowed_roles: ["player", "owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_view_booking_details",
    tool_id: "getUserBookingsAndRefunds",
    description: "استعراض تفاصيل حجز محدد بعد التحقق من ملكيته",
  },
  RECONCILE_BOOKING_PAYMENT: {
    id: "RECONCILE_BOOKING_PAYMENT",
    domain: "payment",
    object: "booking",
    action: "reconcile",
    sub_action: "reconcile_missing",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_reconcile_booking_payment",
    tool_id: "reconcileBookingPayment",
    description: "مطابقة الدفع الإلكتروني مع الحجز ومعالجة الحالات التي خُصم فيها المبلغ",
  },
  CANCEL_BOOKING: {
    id: "CANCEL_BOOKING",
    domain: "booking",
    object: "booking",
    action: "cancel",
    allowed_roles: ["player"],
    is_read_only: false,
    risk_level: "medium",
    workflow_id: "workflow_cancel_booking",
    tool_id: "cancelUserBooking",
    description: "إلغاء حجز قائم عبر الـ RPC الذري مع حساب مبالغ الاسترداد",
  },
  CREATE_BOOKING: {
    id: "CREATE_BOOKING",
    domain: "booking",
    object: "stadium",
    action: "create",
    allowed_roles: ["player"],
    is_read_only: false,
    risk_level: "high",
    workflow_id: "workflow_create_booking",
    tool_id: "createBookingFromChat",
    description: "إنشاء حجز ملعب جديد بعد اكتمال المدخلات وموافقة المستخدم الصريحة",
  },
  CHECK_AVAILABILITY: {
    id: "CHECK_AVAILABILITY",
    domain: "booking",
    object: "stadium",
    action: "inspect",
    sub_action: "availability",
    allowed_roles: ["player", "owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_check_availability",
    tool_id: "checkStadiumAvailability",
    description: "فحص الفترات المتاحة لملعب محدد في تاريخ معين",
  },
  SEARCH_STADIUMS: {
    id: "SEARCH_STADIUMS",
    domain: "booking",
    object: "stadium",
    action: "search",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_search_stadiums",
    tool_id: "searchStadiums",
    description: "البحث عن الملاعب القريبة أو حسب المحافظة والسعر",
  },
  SEARCH_TOURNAMENTS: {
    id: "SEARCH_TOURNAMENTS",
    domain: "tournament",
    object: "tournament",
    action: "search",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_search_tournaments",
    tool_id: "searchTournaments",
    description: "البحث عن البطولات المتاحة للاشتراك",
  },
  GET_1V1_LEADERBOARD: {
    id: "GET_1V1_LEADERBOARD",
    domain: "challenge",
    object: "leaderboard",
    action: "inspect",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_1v1_leaderboard",
    tool_id: "get1v1Leaderboard",
    description: "عرض جدول ترتيب المتصدرين في دوري 1v1",
  },
  GET_OPEN_MATCHES: {
    id: "GET_OPEN_MATCHES",
    domain: "match",
    object: "match",
    action: "search",
    allowed_roles: ["player"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_open_matches",
    tool_id: "getOpenMatches",
    description: "عرض مباريات التقسيمة المفتوحة التي تحتاج لاعبين",
  },
  OWNER_FINANCIAL_INSIGHTS: {
    id: "OWNER_FINANCIAL_INSIGHTS",
    domain: "financials",
    object: "financials",
    action: "inspect",
    allowed_roles: ["owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_owner_financials",
    tool_id: "getOwnerFinancialInsights",
    description: "استعراض الأرباح والرصيد القابل للسحب لمالك الملعب",
  },
  OWNER_STADIUMS_AND_BOOKINGS: {
    id: "OWNER_STADIUMS_AND_BOOKINGS",
    domain: "owner_operations",
    object: "booking",
    action: "inspect",
    allowed_roles: ["owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_owner_stadiums",
    tool_id: "getOwnerStadiumsAndBookings",
    description: "استعراض ملاعب المالك وحجوزاتها وجدول المواعيد",
  },
  GENERAL_BOT_INQUIRY: {
    id: "GENERAL_BOT_INQUIRY",
    domain: "general",
    object: "bot",
    action: "answer",
    sub_action: "identity",
    allowed_roles: ["player", "owner", "admin"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_general_inquiry",
    tool_id: null,
    description: "الإجابة على الأسئلة الجانبية أو سؤال هوية المساعد دون التأثير على المهام المعلقة",
  },
  RESUME_PARKED_TASK: {
    id: "RESUME_PARKED_TASK",
    domain: "booking",
    object: "booking",
    action: "resume",
    sub_action: "parked_task",
    allowed_roles: ["player", "owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_resume_parked",
    tool_id: null,
    description: "استئناف المهمة السابقة التي تم إيقافها مؤقتاً",
  },
};

export function resolveCapability(
  domain: string | undefined,
  object: string | undefined,
  action: string | undefined,
  sub_action: string | undefined,
  role: RoleType
): CapabilityDefinition | null {
  // Direct matching
  for (const cap of Object.values(CAPABILITY_REGISTRY)) {
    if (cap.domain === domain && cap.object === object && cap.action === action) {
      if (!sub_action || cap.sub_action === sub_action || !cap.sub_action) {
        if (cap.allowed_roles.includes(role)) {
          return cap;
        }
      }
    }
  }

  // Fallback matching by action & object
  for (const cap of Object.values(CAPABILITY_REGISTRY)) {
    if (cap.object === object && cap.action === action) {
      if (cap.allowed_roles.includes(role)) {
        return cap;
      }
    }
  }

  return null;
}
