// Tool Executor & Normalized Result Contract for VSP Owner Copilot
// Wraps all Supabase RPC and database calls with robust execution guards and typed status categories.
// Strictly restricted to Pitch Owner capabilities only.

import type { ConversationState, VisibleEntity } from "./conversation_state.ts";
import { isToolAllowedForRole } from "./capability_registry.ts";
import { isRouteAllowedForRole } from "./business_rules.ts";

export type ToolResultStatus =
  | "SUCCESS"
  | "NO_RESULT"
  | "AMBIGUOUS"
  | "INVALID_INPUT"
  | "BUSINESS_RULE_VIOLATION"
  | "TEMPORARY_ERROR"
  | "AUTH_ERROR"
  | "DATA_ERROR";

export interface ToolResultContract {
  status: ToolResultStatus;
  tool_name: string;
  data: Record<string, any>;
  error_message?: string;
  stadiums?: any[];
  tournaments?: any[];
  leaderboard?: any[];
  open_matches?: any[];
  bookings?: any[];
  reconciliation?: any;
  app_action?: any;
  quick_replies?: string[];
  updated_state?: Partial<ConversationState>;
}

// Helpers for slot generation & UTC conversion
function getCairoParts(now: Date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(now);
  const get = (type: string) => Number(parts.find(p => p.type === type)?.value || 0);
  return {
    year: get("year"),
    month: get("month"),
    day: get("day"),
    hour: get("hour"),
    minute: get("minute"),
  };
}

function cairoLocalToUtcIso(year: number, month: number, day: number, hour: number, minute: number): string {
  const guessUtc = new Date(Date.UTC(year, month - 1, day, hour, minute, 0));
  const cairoFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  });
  const parts = cairoFormatter.formatToParts(guessUtc);
  const cHour = Number(parts.find(p => p.type === "hour")?.value || 0);
  const offsetHours = (cHour - guessUtc.getUTCHours() + 24) % 24;
  const trueUtc = new Date(Date.UTC(year, month - 1, day, hour - offsetHours, minute, 0));
  return trueUtc.toISOString();
}

function parseTargetDate(dateStr: string) {
  let target = dateStr;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(target)) {
    const c = getCairoParts(new Date());
    target = `${c.year}-${String(c.month).padStart(2, "0")}-${String(c.day).padStart(2, "0")}`;
  }
  const [y, m, d] = target.split("-").map(Number);
  return {
    targetDateStr: target,
    dayStartIso: cairoLocalToUtcIso(y, m, d, 0, 0),
    dayEndIso: cairoLocalToUtcIso(y, m, d + 1, 0, 0),
  };
}

function generateStandardSlots(targetDateStr: string) {
  const [y, m, d] = targetDateStr.split("-").map(Number);
  const slots: any[] = [];
  for (let h = 0; h < 24; h++) {
    const startIso = cairoLocalToUtcIso(y, m, d, h, 0);
    const endIso = cairoLocalToUtcIso(y, m, h === 23 ? d + 1 : d, (h + 1) % 24, 0);
    const displayStart = h === 0 ? 12 : (h > 12 ? h - 12 : h);
    const endH = (h + 1) % 24;
    const displayEnd = endH === 0 ? 12 : (endH > 12 ? endH - 12 : endH);
    const period = h >= 12 || h === 0 ? "م" : "ص";

    slots.push({
      start_time: startIso,
      end_time: endIso,
      display_time: `${displayStart}:00 ${period} - ${displayEnd}:00 ${period}`,
      hour: h,
    });
  }
  return slots;
}

export async function executeGuardedTool(
  supabase: any,
  callerUser: any,
  toolName: string,
  args: Record<string, any>,
  state: ConversationState
): Promise<ToolResultContract> {
  // 1. Role Authorization Check: Strictly Pitch Owners only
  if (!isToolAllowedForRole(state.user_role, toolName)) {
    return {
      status: "AUTH_ERROR",
      tool_name: toolName,
      data: {},
      error_message: "هذا الإجراء غير مصرح به لهذا الدور.",
    };
  }

  try {
    // 2. checkStadiumAvailability (Owner slot inspector)
    if (toolName === "checkStadiumAvailability") {
      const stadiumId = args.stadium_id || state.stadium.id;
      const stadiumName = args.stadium_name || state.stadium.name;
      const dateStr = args.date || state.date.value || parseTargetDate("اليوم").targetDateStr;

      let targetStadium: any = null;
      if (stadiumId) {
        const { data: s } = await supabase
          .from("stadiums")
          .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
          .eq("id", stadiumId)
          .eq("owner_id", callerUser.id)
          .maybeSingle();
        targetStadium = s;
      }
      if (!targetStadium && stadiumName) {
        const { data: sList } = await supabase
          .from("stadiums")
          .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
          .ilike("name", `%${stadiumName}%`)
          .eq("owner_id", callerUser.id)
          .limit(1);
        if (sList && sList.length > 0) targetStadium = sList[0];
      }

      if (!targetStadium) {
        return {
          status: "INVALID_INPUT",
          tool_name: toolName,
          data: {},
          error_message: "لم يتم العثور على هذا الملعب ضمن ملاعبك المسجلة يا كابتن.",
        };
      }

      const target = parseTargetDate(dateStr);
      const { data: bookings, error: bError } = await supabase
        .from("bookings")
        .select("start_time, end_time, status, locked_until, created_at")
        .eq("stadium_id", targetStadium.id)
        .neq("status", "cancelled")
        .gte("start_time", target.dayStartIso)
        .lte("start_time", target.dayEndIso);

      if (bError) {
        return {
          status: "DATA_ERROR",
          tool_name: toolName,
          data: {},
          error_message: "تعذر فحص المواعيد من قاعدة البيانات حالياً.",
        };
      }

      const activeBookings = (bookings || []).filter((b: any) => {
        if (b.status === "pending") {
          const lockExpire = b.locked_until
            ? new Date(b.locked_until).getTime()
            : new Date(b.created_at).getTime() + 8 * 60 * 1000;
          return lockExpire > Date.now();
        }
        return true;
      });

      const allSlots = generateStandardSlots(target.targetDateStr);
      const isToday = target.targetDateStr === parseTargetDate("اليوم").targetDateStr;
      const nowMs = Date.now();

      let availableSlots = allSlots.filter((slot) => {
        const sStart = new Date(slot.start_time).getTime();
        const sEnd = new Date(slot.end_time).getTime();
        if (isToday && sEnd <= nowMs) return false;

        for (const b of activeBookings) {
          const bStart = new Date(b.start_time).getTime();
          const bEnd = new Date(b.end_time).getTime();
          if (sStart < bEnd && sEnd > bStart) return false;
        }
        return true;
      });

      // Filter by preferred times if specified
      if (state.times.length > 0) {
        const preferredHours = state.times.map(t => Number(t.time.split(":")[0]));
        const filtered = availableSlots.filter(s => preferredHours.includes(s.hour));
        if (filtered.length > 0) {
          availableSlots = filtered;
        }
      }

      const hasSlots = availableSlots.length > 0;
      let proposal: any = null;

      if (hasSlots) {
        const chosenSlot = availableSlots[0];
        proposal = {
          type: "booking_proposal",
          stadium_id: targetStadium.id,
          stadium_name: targetStadium.name,
          date: target.targetDateStr,
          start_time: chosenSlot.start_time,
          end_time: chosenSlot.end_time,
          price_per_hour: targetStadium.price_per_hour,
        };
      }

      return {
        status: hasSlots ? "SUCCESS" : "NO_RESULT",
        tool_name: toolName,
        data: {
          stadium_id: targetStadium.id,
          stadium_name: targetStadium.name,
          date: target.targetDateStr,
          available_slots: availableSlots,
          available_slots_count: availableSlots.length,
          price_per_hour: targetStadium.price_per_hour,
          proposed_slot: proposal,
        },
        quick_replies: hasSlots ? ["أيوه، أكد الحجز", "تغيير الميعاد"] : ["شوف يوم تاني", "شوف ملعب تاني"],
        updated_state: {
          stadium: {
            id: targetStadium.id,
            name: targetStadium.name,
            status: "known" as const,
            provenance: (state.stadium.provenance || "explicit_user") as any,
            price_per_hour: targetStadium.price_per_hour,
          },
          pending_confirmation: proposal,
          last_verified_availability: {
            stadium_id: targetStadium.id,
            date: target.targetDateStr,
            slots: availableSlots,
            checked_at: new Date().toISOString(),
          },
        },
      };
    }

    // 3. executeAppAction (Owner navigation action)
    if (toolName === "executeAppAction") {
      const route = (args.route !== undefined && args.route !== null) ? args.route.toString().trim() : "/bookings";
      if (!route || !isRouteAllowedForRole(state.user_role, route)) {
        return {
          status: "AUTH_ERROR",
          tool_name: toolName,
          data: { route },
          error_message: "هذا المسار غير مصرح به لهذا الدور.",
        };
      }
      return {
        status: "SUCCESS",
        tool_name: toolName,
        data: { route },
        app_action: {
          action_type: args.action_type || "NAVIGATE",
          route,
          label: args.label || "فتح الشاشة",
        },
      };
    }

    // 4. getOwnerFinancialInsights (Owner ledger & balance)
    if (toolName === "getOwnerFinancialInsights") {
      const { data: finSummary, error: finErr } = await supabase.rpc("get_owner_financial_summary", {
        p_owner_id: callerUser.id,
      });

      if (finErr) {
        return {
          status: "DATA_ERROR",
          tool_name: toolName,
          data: {},
          error_message: "تعذر استخراج السجل المالي حالياً.",
        };
      }

      return {
        status: "SUCCESS",
        tool_name: toolName,
        data: finSummary || {},
        app_action: {
          action_type: "NAVIGATE",
          route: "/ledger",
          label: "فتح السجل المالي 💰",
        },
      };
    }

    // 5. getOwnerStadiumsAndBookings (Owner pitch bookings & schedule)
    if (toolName === "getOwnerStadiumsAndBookings") {
      const { data: ownerStadiums } = await supabase
        .from("stadiums")
        .select("id, name, governorate, price_per_hour, is_verified, is_blocked")
        .eq("owner_id", callerUser.id)
        .eq("is_deleted_by_owner", false);

      const stadiumIds = (ownerStadiums || []).map((s: any) => s.id);
      let ownerBookings: any[] = [];
      if (stadiumIds.length > 0) {
        const { data: bList } = await supabase
          .from("bookings")
          .select("id, stadium_id, stadium_name, start_time, end_time, status, total_price, player_name, player_phone")
          .in("stadium_id", stadiumIds)
          .order("start_time", { ascending: false })
          .limit(10);
        ownerBookings = bList || [];
      }

      const matchedStadium = (ownerStadiums && ownerStadiums.length === 1)
        ? ownerStadiums[0]
        : (state.stadium?.name && ownerStadiums
            ? ownerStadiums.find((s: any) => s.name?.includes(state.stadium.name!) || state.stadium.name!.includes(s.name))
            : null);

      const updatedStateObj: any = {};
      if (matchedStadium) {
        updatedStateObj.stadium = {
          id: matchedStadium.id,
          name: matchedStadium.name,
          price_per_hour: matchedStadium.price_per_hour,
          status: "known" as const,
          provenance: state.stadium?.name ? "explicit_user" : "inferred_single",
        };
      }

      return {
        status: "SUCCESS",
        tool_name: toolName,
        data: {
          stadiums_count: (ownerStadiums || []).length,
          stadiums: ownerStadiums || [],
          bookings: ownerBookings,
        },
        app_action: {
          action_type: "NAVIGATE",
          route: "/bookings",
          label: "فتح جدول الحجوزات 📅",
        },
        updated_state: Object.keys(updatedStateObj).length > 0 ? updatedStateObj : undefined,
      };
    }

    return {
      status: "INVALID_INPUT",
      tool_name: toolName,
      data: {},
      error_message: `أداة غير مصرح بها لمساعد إدارة الملاعب: ${toolName}`,
    };
  } catch (err: any) {
    console.error(`[ToolExecutor Guard Exception] Tool ${toolName}:`, err);
    return {
      status: "TEMPORARY_ERROR",
      tool_name: toolName,
      data: {},
      error_message: "حدث تعذر مؤقت أثناء تنفيذ الطلب، يرجى المحاولة مرة أخرى.",
    };
  }
}
