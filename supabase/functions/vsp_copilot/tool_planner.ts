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
    const isOwner = role === "owner" || role === "pitch_owner";
    return {
      action: "RESPOND_DIRECTLY",
      reason: isOwner
        ? "أنا «كابتن VSP»، المستشار الذكي لإدارة ملاعبك ومتابعة الحجوزات والماليات! ⚽📊"
        : "أنا «كابتن VSP»، مساعدك الذكي لاستكشاف الملاعب وحجز مواعيد المباريات بسهولة! ⚽",
      quick_replies: isOwner
        ? ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي كام", "السجل المالي"]
        : ["ملاعب قريبة", "احجز ملعب", "مواعيد اليوم"],
    };
  }

  // 1. Role-Aware Capability Firewall:
  const rawText = (semanticOutput.raw_user_language || "").toLowerCase();
  const isOwner = role === "owner" || role === "pitch_owner";

  if (isOwner) {
    // If the owner asks for personal player functions (tournaments, 1v1, refunds)
    const isPlayerOnlyIntent =
      semanticOutput.domain === "tournament" ||
      semanticOutput.domain === "challenge" ||
      semanticOutput.intent === "tournament" ||
      semanticOutput.intent === "challenge" ||
      rawText.includes("بطول") ||
      rawText.includes("1v1") ||
      rawText.includes("تقسيم") ||
      rawText.includes("فريقي") ||
      rawText.includes("حجوزاتي الشخصية") ||
      rawText.includes("حجزي الشخصي") ||
      rawText.includes("استرد");

    if (isPlayerOnlyIntent) {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "يا كابتن، كابتن VSP للمالك مخصص لمساعدتك في إدارة ملاعبك ومتابعة الحجوزات والماليات؛ خدمات البطولات والتحديات متاحة عبر شاشات التطبيق المخصصة للاعبين.",
        quick_replies: ["جدول ملاعبي", "المواعيد الفاضية", "أرباحي كام", "السجل المالي"],
      };
    }
  } else {
    // If a player asks for owner operations or pitch management
    const isOwnerOnlyIntent =
      semanticOutput.domain === "owner_operations" ||
      semanticOutput.intent === "owner_operations" ||
      semanticOutput.domain === "financials" ||
      semanticOutput.intent === "financial_question" ||
      rawText.includes("أرباح") ||
      rawText.includes("سجل مالي") ||
      rawText.includes("ملاعيبي") ||
      rawText.includes("ملاعب مسجلة");

    if (isOwnerOnlyIntent) {
      return {
        action: "RESPOND_DIRECTLY",
        reason: "البيانات المالية وإدارة تشغيل الملاعب مخصصة حصرياً لأصحاب ومسؤولي الملاعب.",
        quick_replies: ["استكشاف الملاعب", "احجز ملعب", "مواعيد اليوم"],
      };
    }

    // Direct pitch search for players
    if (isToolAllowedForRole(role, "searchStadiums") && (semanticOutput.intent === "stadium_search" || (!state.stadium?.id && (rawText.includes("ملعب") || rawText.includes("ملاعب"))))) {
      return {
        action: "EXECUTE_TOOL",
        toolName: "searchStadiums",
        toolArgs: {
          query: semanticOutput.entities.stadium?.name || state.stadium?.name || "",
          governorate: state.location_scope || "",
        },
      };
    }
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

    const rawText = (semanticOutput.raw_user_language || "").toLowerCase();

    // Determine target period from user query
    let period = "current";
    if (rawText.includes("الشهر اللي فات") || rawText.includes("الشهر الماضي") || rawText.includes("اخر شهر") || rawText.includes("آخر شهر")) {
      period = "last_month";
    } else if (rawText.includes("الشهر ده") || rawText.includes("هذا الشهر") || rawText.includes("من اول الشهر") || rawText.includes("من أول الشهر")) {
      period = "this_month";
    } else if (rawText.includes("النهارده") || rawText.includes("اليوم") || rawText.includes("النهاردة")) {
      period = "today";
    } else if (rawText.includes("امبارح") || rawText.includes("أمس") || rawText.includes("امس")) {
      period = "yesterday";
    } else if (rawText.includes("الاسبوع") || rawText.includes("الأسبوع") || rawText.includes("اخر 7") || rawText.includes("آخر 7")) {
      period = "this_week";
    }

    // Determine metric: period_revenue vs available_balance
    const isBalanceQuery = rawText.includes("رصيد") || rawText.includes("سحب") || rawText.includes("اسحب") || rawText.includes("متاح");
    const isPeriodRevenue = (period !== "current") || (!isBalanceQuery && (rawText.includes("ارباح") || rawText.includes("أرباح") || rawText.includes("دخل") || rawText.includes("كسبت") || rawText.includes("مبيعات") || rawText.includes("عملت كام") || rawText.includes("كام عملت")));

    const metric = isPeriodRevenue ? "period_revenue" : (isBalanceQuery ? "available_balance" : (semanticOutput.entities.money?.metric || "available_balance"));

    return {
      action: "EXECUTE_TOOL",
      toolName: "getOwnerFinancialInsights",
      toolArgs: {
        metric,
        period,
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
