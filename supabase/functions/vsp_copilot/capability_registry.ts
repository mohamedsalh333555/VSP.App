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
  CHECK_AVAILABILITY: {
    id: "CHECK_AVAILABILITY",
    domain: "booking",
    object: "stadium",
    action: "inspect",
    sub_action: "availability",
    allowed_roles: ["owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_check_availability",
    tool_id: "checkStadiumAvailability",
    description: "فحص الفترات المتاحة والمشغولة لملعب محدد في تاريخ معين",
  },
  VIEW_BOOKING_DETAILS: {
    id: "VIEW_BOOKING_DETAILS",
    domain: "self_service",
    object: "booking",
    action: "inspect",
    sub_action: "details",
    allowed_roles: ["owner"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_view_booking_details",
    tool_id: "getOwnerStadiumsAndBookings",
    description: "استعراض تفاصيل حجز محدد بعد التحقق من تبعيته لملعب المالك",
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
