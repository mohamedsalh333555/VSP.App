// Adaptive Clarification Planner for VSP Copilot
// Determines whether to ask, why to ask, and what is the minimum required field.
// Enforces invariants: Never ask for known information, never ask for data queryable from DB.

import type { ConversationState } from "./conversation_state.ts";
import type { SemanticParseOutput } from "./semantic_schema.ts";

export interface ClarificationPlan {
  needsClarification: boolean;
  type?: "ambiguous_time" | "ambiguous_booking_choice" | "missing_stadium" | "missing_date" | "missing_time" | "general_ambiguity";
  question?: string;
  quickReplies?: string[];
  reason?: string;
}

export function planClarification(
  state: ConversationState,
  semanticOutput: SemanticParseOutput
): ClarificationPlan {
  // 1. Check if an explicit ambiguity was captured by the Semantic Parser
  if (state.unresolved_ambiguities.length > 0) {
    const amb = state.unresolved_ambiguities[0];
    if (amb.type === "time_period") {
      const timeVal = state.times[0]?.time || "10:00";
      return {
        needsClarification: true,
        type: "ambiguous_time",
        question: amb.description || `الوقت غير محدد صباحاً أم مساءً للساعة ${timeVal}، تحب نحجز الصبح ولا بالليل؟`,
        quickReplies: amb.options || ["بالليل", "الصبح"],
        reason: amb.description,
      };
    }

    if (amb.type === "entity_choice" || amb.type === "booking_choice") {
      return {
        needsClarification: true,
        type: "ambiguous_booking_choice",
        question: amb.description || "لقيت أكتر من حجز مطابق، تقصد أنهي حجز فيهم؟",
        quickReplies: amb.options || [],
        reason: amb.description,
      };
    }

    return {
      needsClarification: true,
      type: "general_ambiguity",
      question: amb.description || "محتاج توضيح بسيط يا كابتن:",
      quickReplies: amb.options || [],
      reason: amb.description,
    };
  }

  // 2. Booking Task: Check missing slots adaptively
  // INVARIANT 1: Only check missing slots if user is genuinely CREATING a booking!
  // If user is inspecting or reconciling, NEVER ask for stadium!
  if (state.active_task === "booking" && semanticOutput.action === "create") {
    // Missing Stadium: only ask if location_scope is not "nearby"
    if (!state.stadium.name && !state.stadium.id && state.location_scope !== "nearby") {
      return {
        needsClarification: true,
        type: "missing_stadium",
        question: "تمام يا كابتن. تحب نحجز في أنهي ملعب؟",
        quickReplies: state.candidate_stadiums.slice(0, 3).map(s => s.name),
        reason: "stadium_missing_for_create",
      };
    }

    // Missing Date: only ask if date is genuinely unknown
    if (!state.date.value) {
      return {
        needsClarification: true,
        type: "missing_date",
        question: "تمام، طلبك اتسجل. تحب الحجز يكون النهارده ولا بكرة؟",
        quickReplies: ["النهارده", "بكرة"],
        reason: "date_missing_for_create",
      };
    }

    // Missing Time: only ask if no times and no time range
    if (state.times.length === 0 && !state.time_range) {
      return {
        needsClarification: true,
        type: "missing_time",
        question: "تحب نحجز الساعة كام يا كابتن؟",
        quickReplies: ["8 بالليل", "9 بالليل", "10 بالليل"],
        reason: "time_missing_for_create",
      };
    }

    // Ambiguous Time Period: only ask if period is not yet confirmed
    if (!state.time_period_confirmed && state.times.length > 0) {
      const firstHour = state.times[0].time;
      const h = Number(firstHour.split(":")[0]);
      const displayH = h > 12 ? h - 12 : h;
      return {
        needsClarification: true,
        type: "ambiguous_time",
        question: `الساعة ${displayH} تقصدها الصبح ولا بالليل؟`,
        quickReplies: ["الصبح", "بالليل"],
        reason: "time_period_unconfirmed",
      };
    }
  }

  return { needsClarification: false };
}
