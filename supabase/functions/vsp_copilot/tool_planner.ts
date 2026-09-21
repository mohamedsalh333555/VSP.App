// Deterministic Tool Planner for VSP Copilot
// Gates execution and plans operational actions based on state completeness, ambiguity, and role permissions.
// Uses Capability Registry, Task Manager, and Adaptive Clarification Planner.

import type { ConversationState } from "./conversation_state.ts";
import type { SemanticParseOutput } from "./semantic_schema.ts";
import { isToolAllowedForRole } from "./business_rules.ts";
import { planClarification } from "./clarification_planner.ts";
import { resolveCapability } from "./capability_registry.ts";

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

  // 0. Bot Identity / Side Question (Zero Booking Pollution)
  const isBotIdentity =
    semanticOutput.domain === "general" ||
    semanticOutput.object === "bot" ||
    semanticOutput.object === "bot_identity" ||
    (semanticOutput.speech_act === "question" && (semanticOutput.raw_user_language || "").includes("اسمك"));

  if (isBotIdentity) {
    const hasParked = state.task_manager?.parked_tasks && state.task_manager.parked_tasks.length > 0;
    return {
      action: "RESPOND_DIRECTLY",
      reason: "أنا «كابتن VSP»، مساعدك الرياضي الذكي لحجز الملاعب والبطولات في مصر! ⚽",
      quick_replies: hasParked ? ["تمام نرجع للحجز", "عايز ملعب قريب", "البطولات المفتوحة"] : ["عايز ملعب قريب", "حجوزاتي", "البطولات المفتوحة"],
    };
  }

  // 1. Acknowledge / non-operational turns
  if (semanticOutput.speech_act === "acknowledge" || (semanticOutput.operation === "none" && !semanticOutput.execution_request.requested && semanticOutput.speech_act === "inform")) {
    return { action: "RESPOND_DIRECTLY" };
  }

  // 1b. Check Unresolved Ambiguities First (Version 93 Invariant)
  if (state.unresolved_ambiguities.length > 0) {
    const amb = state.unresolved_ambiguities[0];
    return {
      action: "CLARIFY_AMBIGUITY",
      ambiguity_type: amb.type,
      reason: amb.description,
      quick_replies: amb.options || [],
    };
  }

  // 2. Adaptive Clarification Check
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

  // 3. Payment Reconciliation Workflow ("دفعت ومظهرش الحجز", "الفلوس اتخصمت")
  const isPaymentReconcile =
    semanticOutput.domain === "payment" ||
    semanticOutput.action === "reconcile" ||
    semanticOutput.sub_action === "reconcile_missing";

  if (isPaymentReconcile) {
    if (!isToolAllowedForRole(role, "reconcileBookingPayment")) {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "خدمة تدقيق ومطابقة الدفع الإلكتروني مخصصة لحسابات اللاعبين.",
      };
    }

    return {
      action: "EXECUTE_TOOL",
      toolName: "reconcileBookingPayment",
      toolArgs: {},
    };
  }

  // 4. Self-Service Booking Inspection ("اين حجزي", "امتى حجزي الجاي")
  const isBookingInspect =
    semanticOutput.domain === "self_service" ||
    (semanticOutput.object === "booking" && semanticOutput.action === "inspect");

  if (isBookingInspect) {
    if (!isToolAllowedForRole(role, "getUserBookingsAndRefunds")) {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "استعراض الحجوزات الشخصية متاح لحسابات اللاعبين.",
      };
    }

    const isUpcoming = semanticOutput.sub_action === "upcoming" || (semanticOutput.raw_user_language || "").includes("الجاي");
    return {
      action: "EXECUTE_TOOL",
      toolName: "getUserBookingsAndRefunds",
      toolArgs: {
        filter: isUpcoming ? "upcoming" : "recent",
      },
    };
  }

  // 5. Booking Cancellation ("الغى الحجز ده")
  const isBookingCancel =
    (semanticOutput.domain === "booking" && semanticOutput.action === "cancel") ||
    (semanticOutput.object === "booking" && semanticOutput.action === "cancel");

  if (isBookingCancel) {
    if (!isToolAllowedForRole(role, "cancelUserBooking")) {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "إلغاء الحجز متاح فقط لصاحب الحجز.",
      };
    }

    const candidateBookings = state.candidate_bookings || [];
    if (candidateBookings.length === 1) {
      return {
        action: "EXECUTE_TOOL",
        toolName: "cancelUserBooking",
        toolArgs: {
          booking_id: candidateBookings[0].id,
        },
      };
    }

    if (candidateBookings.length > 1) {
      return {
        action: "CLARIFY_AMBIGUITY",
        ambiguity_type: "booking_choice",
        reason: "لقيت أكتر من حجز بحسابك، تحب تلغي حجز أنهي ملعب فيهم؟",
        quick_replies: candidateBookings.map(b => b.name),
      };
    }

    // Zero candidates currently cached in state: fetch user bookings first
    return {
      action: "EXECUTE_TOOL",
      toolName: "getUserBookingsAndRefunds",
      toolArgs: { filter: "upcoming" },
    };
  }

  // 6. Booking Proposal Confirmation
  const isUserConfirmed =
    semanticOutput.confirmation?.meaning === "accepted" ||
    (semanticOutput.speech_act === "confirm" && state.pending_confirmation !== null);

  if (state.pending_confirmation && isUserConfirmed) {
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

  // 7. Booking Creation: Check Stadium Availability when slots are complete
  if (state.active_task === "booking" && (semanticOutput.action === "create" || semanticOutput.action === "resume")) {
    if (state.date.value && (state.times.length > 0 || state.time_range)) {
      if (state.location_scope === "nearby" && !state.stadium.id) {
        return {
          action: "EXECUTE_TOOL",
          toolName: "searchStadiums",
          toolArgs: { governorate: "" },
        };
      }

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

  // 8. Stadium Search
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

  // 9. Tournaments
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

  // 10. 1v1 Leaderboard
  if (state.active_task === "challenge" || semanticOutput.intent === "challenge") {
    return {
      action: "EXECUTE_TOOL",
      toolName: "get1v1Leaderboard",
      toolArgs: { limit: 5 },
    };
  }

  // 11. Open Matches (تقسيمة)
  if (semanticOutput.intent === "navigation" && (semanticOutput.raw_user_language || "").includes("تقسيمة")) {
    return {
      action: "EXECUTE_TOOL",
      toolName: "getOpenMatches",
      toolArgs: {},
    };
  }

  // 12. Owner Inquiries
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
      toolArgs: { query_type: "all" },
    };
  }

  // 13. Navigation Request
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
