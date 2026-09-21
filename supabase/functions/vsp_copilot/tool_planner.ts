// Deterministic Tool Planner for VSP Copilot
// Gates execution and plans operational actions based on state completeness, ambiguity, and role permissions.

import type { ConversationState } from "./conversation_state.ts";
import type { SemanticParseOutput } from "./semantic_schema.ts";
import { isToolAllowedForRole } from "./business_rules.ts";

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
  // When models are exhausted, NO new tool execution and NO state mutation.
  // Exception: structured UI actions or idempotent replays.
  if (options?.isDegraded) {
    if (options.structuredUiAction?.type === "CONFIRM_BOOKING" && state.pending_confirmation) {
      if (isToolAllowedForRole(role, "createBookingFromChat")) {
        return {
          action: "EXECUTE_TOOL",
          toolName: "createBookingFromChat",
          toolArgs: {
            stadium_id: state.pending_confirmation.stadium_id,
            stadium_name: state.pending_confirmation.stadium_name,
            start_time: state.pending_confirmation.start_time,
            end_time: state.pending_confirmation.end_time,
            confirm: true,
          },
        };
      }
    }

    return {
      action: "SAFE_DEGRADED_CLARIFICATION",
      reason: "يا كابتن، في ضغط لحظي مؤقت على خدمة الذكاء الاصطناعي وما قدرتش أستوعب رسالتك الأخيرة بدقة. بياناتك ومواعيدك السابقة محفوظة بأمان، تقدر تختار الخطوة التالية من الخيارات بالأسفل:",
      quick_replies: state.pending_confirmation
        ? ["تأكيد الحجز", "تغيير الميعاد", "إلغاء"]
        : state.active_task === "booking"
          ? ["اختيار ملعب", "ميعاد تاني", "مساعدة"]
          : ["عايز ملعب قريب", "البطولات المفتوحة", "ترتيب الحريفة 1v1"],
    };
  }

  // 0. Acknowledge / non-operational turns do not trigger tool calls
  if (semanticOutput.speech_act === "acknowledge" || (semanticOutput.operation === "none" && !semanticOutput.execution_request.requested)) {
    return { action: "RESPOND_DIRECTLY" };
  }

  // 1. Check Unresolved Ambiguities First
  if (state.unresolved_ambiguities.length > 0) {
    const amb = state.unresolved_ambiguities[0];
    return {
      action: "CLARIFY_AMBIGUITY",
      ambiguity_type: amb.type,
      reason: amb.description,
      quick_replies: amb.options || [],
    };
  }

  // 2. Booking Task Planning
  if (state.active_task === "booking") {
    // Missing Stadium
    if (!state.stadium.name && !state.stadium.id && state.location_scope !== "nearby") {
      return {
        action: "ASK_SLOT",
        missing_slot: "stadium",
        quick_replies: state.candidate_stadiums.slice(0, 3).map(s => s.name),
      };
    }

    // Missing Date
    if (!state.date.value) {
      return {
        action: "ASK_SLOT",
        missing_slot: "date",
        quick_replies: ["النهارده", "بكرة"],
      };
    }

    // Missing Time
    if (state.times.length === 0 && !state.time_range) {
      return {
        action: "ASK_SLOT",
        missing_slot: "time",
        quick_replies: ["8 بالليل", "9 بالليل", "10 بالليل"],
      };
    }

    // Ambiguous Time Period (e.g. 10 without am/pm confirmation)
    if (!state.time_period_confirmed && state.times.length > 0) {
      const firstHour = state.times[0].time;
      return {
        action: "ASK_SLOT",
        missing_slot: "time_period",
        reason: `تأكيد وقت الحجز: هل المقصود ${firstHour} بالليل؟`,
        quick_replies: ["بالليل", "الصبح"],
      };
    }

    // Check if we have an active booking proposal pending user confirmation
    const isUserConfirmed =
      semanticOutput.confirmation.meaning === "accepted" ||
      (semanticOutput.speech_act === "confirm" && state.pending_confirmation !== null);

    if (state.pending_confirmation && isUserConfirmed) {
      // User confirmed the proposal! Gate open for booking execution!
      if (!isToolAllowedForRole(role, "createBookingFromChat")) {
        return {
          action: "RESPOND_DIRECTLY",
          reason: "حسابك لا يملك صلاحية تنفيذ الحجز كلاعب.",
        };
      }

      return {
        action: "EXECUTE_TOOL",
        toolName: "createBookingFromChat",
        toolArgs: {
          stadium_id: state.pending_confirmation.stadium_id,
          stadium_name: state.pending_confirmation.stadium_name,
          start_time: state.pending_confirmation.start_time,
          end_time: state.pending_confirmation.end_time,
          confirm: true,
        },
      };
    }

    // If slots are complete, check availability with the database
    if (state.date.value && (state.times.length > 0 || state.time_range)) {
      // If nearby scope search
      if (state.location_scope === "nearby" && !state.stadium.id) {
        return {
          action: "EXECUTE_TOOL",
          toolName: "searchStadiums",
          toolArgs: {
            governorate: "",
          },
        };
      }

      // Check live availability
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

  // 3. Stadium Search
  if (state.active_task === "stadium_search" || semanticOutput.intent === "stadium_search") {
    return {
      action: "EXECUTE_TOOL",
      toolName: "searchStadiums",
      toolArgs: {
        governorate: semanticOutput.entities.location?.governorate || state.location_scope || "",
        max_price: semanticOutput.entities.money?.max_price,
      },
    };
  }

  // 4. Tournaments
  if (state.active_task === "tournament" || semanticOutput.intent === "tournament") {
    return {
      action: "EXECUTE_TOOL",
      toolName: "searchTournaments",
      toolArgs: {
        tournament_type: "all",
        governorate: semanticOutput.entities.location?.governorate || "",
      },
    };
  }

  // 5. 1v1 Leaderboard
  if (state.active_task === "challenge" || semanticOutput.intent === "challenge") {
    return {
      action: "EXECUTE_TOOL",
      toolName: "get1v1Leaderboard",
      toolArgs: { limit: 5 },
    };
  }

  // 6. Owner Inquiries
  if (state.active_task === "owner_financial" || semanticOutput.intent === "financial_question") {
    if (role !== "owner") {
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

  if (state.active_task === "owner_stadiums" || semanticOutput.intent === "owner_operations") {
    if (role !== "owner") {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "إدارة الملاعب والحجوزات مخصصة لحسابات ملاك الملاعب.",
      };
    }

    return {
      action: "EXECUTE_TOOL",
      toolName: "getOwnerStadiumsAndBookings",
      toolArgs: {
        query_type: "all",
      },
    };
  }

  // 7. Navigation Request
  if (semanticOutput.intent === "navigation" || semanticOutput.operation === "navigate") {
    return {
      action: "EXECUTE_TOOL",
      toolName: "executeAppAction",
      toolArgs: {
        action_type: "NAVIGATE",
        route: "/bookings",
        label: "عرض الشاشة",
      },
    };
  }

  return { action: "RESPOND_DIRECTLY" };
}
