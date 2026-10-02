// Application-Controlled Capability Registry for VSP Copilot
// Declares all permissible operational capabilities partitioned by role (Player, Owner, Admin).

export type RoleType = "owner" | "pitch_owner" | "player" | "admin";
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
  SEARCH_STADIUMS: {
    id: "searchStadiums",
    domain: "booking",
    object: "stadium",
    action: "search",
    allowed_roles: ["player", "owner", "pitch_owner", "admin"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_search_stadiums",
    tool_id: "searchStadiums",
    description: "البحث عن الملاعب حسب الاسم والمحافظة والسعر للاعبين ومسؤولي الملاعب",
  },
  CHECK_STADIUM_AVAILABILITY: {
    id: "checkStadiumAvailability",
    domain: "booking",
    object: "stadium",
    action: "inspect",
    sub_action: "availability",
    allowed_roles: ["player", "owner", "pitch_owner", "admin"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_check_availability",
    tool_id: "checkStadiumAvailability",
    description: "فحص الفترات المتاحة والمشغولة لملعب محدد في تاريخ معين",
  },
  EXECUTE_APP_ACTION: {
    id: "executeAppAction",
    domain: "navigation",
    object: "app",
    action: "navigate",
    allowed_roles: ["player", "owner", "pitch_owner", "admin"],
    is_read_only: false,
    risk_level: "low",
    workflow_id: "workflow_navigate_action",
    tool_id: "executeAppAction",
    description: "تنفيذ إجراءات التنقل أو الحجز التفاعلية داخل التطبيق",
  },
  OWNER_STADIUMS_AND_BOOKINGS: {
    id: "getOwnerStadiumsAndBookings",
    domain: "owner_operations",
    object: "booking",
    action: "inspect",
    allowed_roles: ["owner", "pitch_owner", "admin"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_owner_stadiums",
    tool_id: "getOwnerStadiumsAndBookings",
    description: "استعراض ملاعب المالك وحجوزاتها وجدول المواعيد (خاص بمالك الملعب)",
  },
  OWNER_FINANCIAL_INSIGHTS: {
    id: "getOwnerFinancialInsights",
    domain: "financials",
    object: "financials",
    action: "inspect",
    allowed_roles: ["owner", "pitch_owner", "admin"],
    is_read_only: true,
    risk_level: "low",
    workflow_id: "workflow_owner_financials",
    tool_id: "getOwnerFinancialInsights",
    description: "استعراض الأرباح والرصيد القابل للسحب لمالك الملعب (خاص بمالك الملعب)",
  },
};

export function isToolAllowedForRole(role: string | undefined | null, toolName: string): boolean {
  if (!toolName || !role) return false;
  const normRole = role.toLowerCase().trim() as RoleType;
  const cap = getCapabilityByTool(toolName);
  if (!cap) return false;
  return cap.allowed_roles.includes(normRole);
}

export function getCapabilityByTool(toolName: string): CapabilityDefinition | null {
  for (const cap of Object.values(CAPABILITY_REGISTRY)) {
    if (cap.tool_id === toolName) {
      return cap;
    }
  }
  return null;
}

export function getAllowedToolsForRole(role: string | undefined | null): string[] {
  if (!role) return [];
  const normRole = role.toLowerCase().trim() as RoleType;
  return Object.values(CAPABILITY_REGISTRY)
    .filter(cap => cap.tool_id && cap.allowed_roles.includes(normRole))
    .map(cap => cap.tool_id as string);
}

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
