// Deterministic Tool Planner for VSP Owner Copilot
// Gates execution and plans operational actions for Pitch Owners strictly.
// Rejects all Player requests with direct, courteous refusal and NO tool execution.

import type { ConversationState } from "./conversation_state.ts";
import type { SemanticParseOutput } from "./semantic_schema.ts";
import { planClarification } from "./clarification_planner.ts";
import { isToolAllowedForRole } from "./capability_registry.ts";

export interface ToolPlan {
  action: "EXECUTE_TOOL" | "ASK_SLOT" | "CONFIRM_PROPOSAL" | "CLARIFY_AMBIGUITY" | "SAFE_DEGRADED_CLARIFICATION" | "RESPOND_DIRECTLY";
  toolName?: string;
  toolArgs?: Record<string, any>;
  missing_slot?: "stadium" | "date" | "time" | "time_period";
  quick_replies?: string[];
  ambiguity_type?: string;
  reason?: string;
}

export function planToolExecution(
  state: ConversationState,
  semanticOutput: SemanticParseOutput,
  options?: {
    isDegraded?: boolean;
    structuredUiAction?: { type: string; payload?: any };
    isIdempotentReplay?: boolean;
  }
): ToolPlan {
  const role = state.user_role;

  // SAFE DEGRADED MODE (Strict Non-Execution Rule):
  if (options?.isDegraded) {
    return {
      action: "SAFE_DEGRADED_CLARIFICATION",
      reason: "يا كابتن، في ضغط لحظي مؤقت على خدمة الذكاء الاصطناعي وما قدرتش أستوعب رسالتك الأخيرة بدقة. بياناتك ومواعيدك السابقة محفوظة بأمان، تقدر تختار الخطوة التالية من الخيارات بالأسفل:",
      quick_replies: state.active_task === "owner_financial"
        ? ["أرباح النهاردة", "الرصيد المتاح", "السجل المالي"]
        : ["جدول الحجوزات", "المواعيد الفاضية", "أرباحي كام"],
    };
  }

  // 0. Bot Identity / Side Question
  const isBotIdentity =
    semanticOutput.domain === "general" ||
    semanticOutput.object === "bot" ||
    semanticOutput.object === "bot_identity" ||
    (semanticOutput.speech_act === "question" && (semanticOutput.raw_user_language || "").includes("اسمك"));

  if (isBotIdentity) {
    return {
      action: "RESPOND_DIRECTLY",
      reason: "أنا «كابتن VSP»، المستشار الذكي لإدارة ملاعبك ومتابعة الحجوزات والماليات! ⚽📊",
      quick_replies: ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي كام", "السجل المالي"],
    };
  }

  // 1. Strict Player Capability Rejection Firewall:
  // If the owner asks for any player function (booking as a player, tournaments, 1v1, teams, player refunds)
  const rawText = (semanticOutput.raw_user_language || "").toLowerCase();
  const isPlayerIntent =
    semanticOutput.domain === "unsupported" ||
    semanticOutput.object === "unsupported" ||
    semanticOutput.domain === "tournament" ||
    semanticOutput.domain === "challenge" ||
    semanticOutput.domain === "self_service" ||
    semanticOutput.domain === "payment" ||
    semanticOutput.intent === "tournament" ||
    semanticOutput.intent === "challenge" ||
    semanticOutput.intent === "stadium_search" ||
    semanticOutput.action === "cancel" ||
    semanticOutput.action === "reconcile" ||
    rawText.includes("بطول") ||
    rawText.includes("1v1") ||
    rawText.includes("تقسيم") ||
    rawText.includes("فريقي") ||
    rawText.includes("احجزلي") ||
    rawText.includes("حجوزاتي الشخصية") ||
    rawText.includes("حجزي الشخصي") ||
    rawText.includes("استرد");

  if (isPlayerIntent) {
    return {
      action: "RESPOND_DIRECTLY",
      reason: "يا كابتن، كابتن VSP مخصص حصرياً لأصحاب ومسؤولي الملاعب لمساعدتك في إدارة وتشغيل ملاعبك ومتابعة الحجوزات والماليات؛ خدمات اللاعبين والبطولات متاحة عبر شاشات التطبيق المخصصة للاعبين.",
      quick_replies: ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي كام", "السجل المالي"],
    };
  }

  // 2. Acknowledge / non-operational turns
  if (semanticOutput.speech_act === "acknowledge" || (semanticOutput.operation === "none" && !semanticOutput.execution_request.requested && semanticOutput.speech_act === "inform")) {
    return { action: "RESPOND_DIRECTLY" };
  }

  // 3. Check Unresolved Ambiguities First
  if (state.unresolved_ambiguities.length > 0) {
    const amb = state.unresolved_ambiguities[0];
    return {
      action: "CLARIFY_AMBIGUITY",
      ambiguity_type: amb.type,
      reason: amb.description,
      quick_replies: amb.options || [],
    };
  }

  // 4. Adaptive Clarification Check
  const clarification = planClarification(state, semanticOutput);
  if (clarification.needsClarification) {
    if (clarification.type === "ambiguous_time" || clarification.type === "missing_stadium" || clarification.type === "missing_date" || clarification.type === "missing_time") {
      const slotMap: Record<string, "stadium" | "date" | "time" | "time_period"> = {
        missing_stadium: "stadium",
        missing_date: "date",
        missing_time: "time",
        ambiguous_time: "time_period",
      };
      return {
        action: "ASK_SLOT",
        missing_slot: slotMap[clarification.type],
        reason: clarification.question,
        quick_replies: clarification.quickReplies || [],
      };
    }

    return {
      action: "CLARIFY_AMBIGUITY",
      ambiguity_type: clarification.type,
      reason: clarification.question,
      quick_replies: clarification.quickReplies || [],
    };
  }

  // 5. Navigation Request
  if (semanticOutput.intent === "navigation" || semanticOutput.operation === "navigate") {
    if (isToolAllowedForRole(role, "executeAppAction")) {
      const rawText = (semanticOutput.raw_user_language || "").toLowerCase();
      let targetRoute = "/bookings";
      if (rawText.includes("مال") || rawText.includes("ارباح") || rawText.includes("أرباح") || rawText.includes("سجل") || rawText.includes("رصيد")) {
        targetRoute = "/ledger";
      } else if (rawText.includes("رئيسي") || rawText.includes("داشبورد") || rawText.includes("dashboard")) {
        targetRoute = "/dashboard";
      }
      return {
        action: "EXECUTE_TOOL",
        toolName: "executeAppAction",
        toolArgs: {
          action_type: "NAVIGATE",
          route: targetRoute,
          label: "عرض الشاشة",
        },
      };
    }
  }

  // 6. Owner Financial Insights
  if (state.active_task === "owner_financial" || semanticOutput.intent === "financial_question" || semanticOutput.domain === "financials") {
    if (role !== "owner" && role !== "pitch_owner") {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "البيانات المالية لملاك الملاعب متاحة فقط لحسابات المالكين.",
      };
    }

    const metric = semanticOutput.entities.money?.metric || "available_balance";
    return {
      action: "EXECUTE_TOOL",
      toolName: "getOwnerFinancialInsights",
      toolArgs: {
        metric,
        period: "current",
      },
    };
  }

  // 7. Owner Stadiums and Bookings (Schedule & Who booked)
  const isOwnerScheduleQuery =
    state.active_task === "owner_stadiums" ||
    semanticOutput.intent === "owner_operations" ||
    semanticOutput.domain === "owner_operations" ||
    (semanticOutput.object === "booking" && semanticOutput.action === "inspect");

  if (isOwnerScheduleQuery) {
    if (role !== "owner" && role !== "pitch_owner") {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "إدارة الملاعب والحجوزات مخصصة لحسابات ملاك الملاعب.",
      };
    }

    return {
      action: "EXECUTE_TOOL",
      toolName: "getOwnerStadiumsAndBookings",
      toolArgs: {
        stadium_name: semanticOutput.entities.stadium?.name || state.stadium?.name,
        query_type: "all",
      },
    };
  }

  // 8. Check Stadium Availability & Free Slots
  const isAvailabilityInquiry =
    semanticOutput.intent === "availability" ||
    (semanticOutput.action === "inspect" && (semanticOutput.object === "stadium" || semanticOutput.object === "slot")) ||
    (state.active_task === "booking" && (semanticOutput.speech_act === "question" || semanticOutput.speech_act === "inform"));

  if (isAvailabilityInquiry || (state.active_task === "booking" && (state.times.length > 0 || state.time_range))) {
    if (state.date.value && (state.times.length > 0 || state.time_range || isAvailabilityInquiry)) {
      if (state.stadium.name || state.stadium.id) {
        return {
          action: "EXECUTE_TOOL",
          toolName: "checkStadiumAvailability",
          toolArgs: {
            stadium_id: state.stadium.id,
            stadium_name: state.stadium.name,
            date: state.date.value,
            time_preference: state.times.map(t => t.time).join(" أو "),
          },
        };
      }
    }
  }

  return { action: "RESPOND_DIRECTLY" };
}
