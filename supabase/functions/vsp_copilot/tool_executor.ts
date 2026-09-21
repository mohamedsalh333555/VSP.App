// Tool Executor & Normalized Result Contract for VSP Copilot
// Wraps all Supabase RPC and database calls with robust execution guards and typed status categories.

import type { ConversationState, VisibleEntity } from "./conversation_state.ts";
import { isToolAllowedForRole } from "./business_rules.ts";

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
  // 1. Role Authorization Check
  if (!isToolAllowedForRole(state.user_role, toolName)) {
    return {
      status: "AUTH_ERROR",
      tool_name: toolName,
      data: {},
      error_message: "هذا الإجراء غير مصرح به لهذا الدور.",
    };
  }

  try {
    // 2. searchStadiums
    if (toolName === "searchStadiums") {
      const governorate = (args.governorate || state.location_scope || "").toString().trim();
      const maxPrice = Number(args.max_price || 0);

      let query = supabase
        .from("stadiums")
        .select("id, name, governorate, price_per_hour, image_url, rating, seats_capacity, players_per_team, total_field_capacity")
        .eq("is_verified", true)
        .eq("is_blocked", false)
        .eq("is_deleted_by_owner", false);

      if (governorate && governorate !== "nearby") {
        query = query.ilike("governorate", `%${governorate}%`);
      }
      if (maxPrice > 0) {
        query = query.lte("price_per_hour", maxPrice);
      }

      const { data: stadiums, error: dbError } = await query.order("rating", { ascending: false }).limit(10);
      if (dbError) {
        return {
          status: "DATA_ERROR",
          tool_name: toolName,
          data: {},
          error_message: "تعذر استرجاع الملاعب من قاعدة البيانات حالياً.",
        };
      }

      const stadiumList = stadiums || [];
      const visibleEntities: VisibleEntity[] = stadiumList.map((s: any, idx: number) => ({
        reference_key: `stadium_${idx + 1}`,
        entity_type: "stadium",
        id: s.id,
        name: s.name,
        price_per_hour: s.price_per_hour,
        governorate: s.governorate,
      }));

      if (stadiumList.length === 0) {
        return {
          status: "NO_RESULT",
          tool_name: toolName,
          data: { count: 0, governorate },
          stadiums: [],
        };
      }

      return {
        status: "SUCCESS",
        tool_name: toolName,
        data: { count: stadiumList.length, governorate },
        stadiums: stadiumList,
        updated_state: {
          last_visible_entities: visibleEntities,
          candidate_stadiums: visibleEntities,
          // If only 1 stadium matched, automatically set it
          stadium: stadiumList.length === 1 ? {
            id: stadiumList[0].id,
            name: stadiumList[0].name,
            price_per_hour: stadiumList[0].price_per_hour,
            provenance: "inferred_single",
            status: "known",
          } : state.stadium,
        },
      };
    }

    // 3. checkStadiumAvailability
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
          .maybeSingle();
        targetStadium = s;
      }
      if (!targetStadium && stadiumName) {
        const { data: sList } = await supabase
          .from("stadiums")
          .select("id, name, governorate, price_per_hour, needs_deposit, deposit_amount, owner_id")
          .ilike("name", `%${stadiumName}%`)
          .limit(1);
        if (sList && sList.length > 0) targetStadium = sList[0];
      }

      if (!targetStadium) {
        return {
          status: "INVALID_INPUT",
          tool_name: toolName,
          data: {},
          error_message: "لم يتم العثور على الملعب المحدد للتحقق من المواعيد.",
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
            : new Date(b.created_at).getTime() + 5 * 60 * 1000;
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

    // 4. createBookingFromChat (Atomic Execution)
    if (toolName === "createBookingFromChat") {
      const pending = state.pending_confirmation;
      if (!pending) {
        return {
          status: "INVALID_INPUT",
          tool_name: toolName,
          data: {},
          error_message: "لا يوجد عرض حجز معتمد لتأكيده.",
        };
      }

      const { data: activeCashBookings, error: cashErr } = await supabase
        .from("bookings")
        .select("id")
        .or(`created_by_user_id.eq.${callerUser.id},user_id.eq.${callerUser.id}`)
        .eq("payment_method", "cash")
        .eq("is_paid", false)
        .in("status", ["pending", "confirmed"])
        .gt("end_time", new Date().toISOString())
        .limit(1);

      const hasActiveCash = !cashErr && Array.isArray(activeCashBookings) && activeCashBookings.length > 0;
      const { data: stadiumRow } = await supabase
        .from("stadiums")
        .select("id, name, needs_deposit, deposit_amount, owner_id")
        .eq("id", pending.stadium_id)
        .maybeSingle();

      if (!stadiumRow) {
        return {
          status: "DATA_ERROR",
          tool_name: toolName,
          data: {},
          error_message: "تعذر استرجاع بيانات الملعب.",
        };
      }

      const needsDeposit = !hasActiveCash && Boolean(stadiumRow.needs_deposit);
      const paymentMethod = hasActiveCash || needsDeposit ? "paymob" : "cash";

      const { data: bookingResult, error: rpcErr } = await supabase.rpc("create_booking_atomic", {
        p_stadium_id: stadiumRow.id,
        p_user_id: callerUser.id,
        p_owner_id: stadiumRow.owner_id,
        p_start_time: pending.start_time,
        p_end_time: pending.end_time,
        p_booking_type: "individual",
        p_total_price: pending.price_per_hour,
        p_stadium_name: stadiumRow.name,
        p_payment_method: paymentMethod,
      });

      if (rpcErr || (bookingResult && bookingResult.success === false)) {
        return {
          status: "BUSINESS_RULE_VIOLATION",
          tool_name: toolName,
          data: {},
          error_message: rpcErr?.message || bookingResult?.message || "الميعاد المطلوب تم حجزه بالفعل.",
        };
      }

      const bookingId = bookingResult?.booking_id || bookingResult?.id;
      let appAction: any = null;

      if (hasActiveCash || needsDeposit) {
        appAction = {
          action_type: "OPEN_PAYMENT",
          route: "/checkout",
          label: needsDeposit ? `إتمام دفع العربون (${stadiumRow.deposit_amount || 50} ج.م) 💳` : "سداد الحجز أونلاين 💳",
          params: {
            booking_id: bookingId,
            stadium_id: stadiumRow.id,
            stadium_name: stadiumRow.name,
            total_price: pending.price_per_hour,
            deposit_amount: needsDeposit ? (stadiumRow.deposit_amount || 50) : 0,
            start_time: pending.start_time,
            end_time: pending.end_time,
          },
        };
      } else {
        appAction = {
          action_type: "NAVIGATE",
          route: "/bookings",
          label: "عرض تفاصيل الحجز المؤكد 📋",
          params: { booking_id: bookingId },
        };
      }

      return {
        status: "SUCCESS",
        tool_name: toolName,
        data: {
          booking_id: bookingId,
          stadium_name: stadiumRow.name,
          start_time: pending.start_time,
          end_time: pending.end_time,
          total_price: pending.price_per_hour,
          deposit_required: needsDeposit,
          deposit_amount: stadiumRow.deposit_amount || 0,
          payment_method: paymentMethod,
        },
        app_action: appAction,
        updated_state: {
          pending_confirmation: null,
          task_lifecycle: "completed",
        },
      };
    }

    // 5. searchTournaments
    if (toolName === "searchTournaments") {
      const gov = (args.governorate || "").toString().trim();
      let q5v5 = supabase.from("championships").select("id, name, type, grand_prize, entry_fee, max_teams, status, governorate").eq("status", "open");
      if (gov) q5v5 = q5v5.ilike("governorate", `%${gov}%`);
      const { data: champs } = await q5v5.limit(5);

      let q1v1 = supabase.from("vsp_1v1_tournaments").select("id, name, status, prize_pool, entry_fee, target_player_count, governorate").eq("status", "registration_open");
      if (gov) q1v1 = q1v1.ilike("governorate", `%${gov}%`);
      const { data: t1v1 } = await q1v1.limit(5);

      const all = [...(champs || []), ...(t1v1 || [])];
      return {
        status: all.length > 0 ? "SUCCESS" : "NO_RESULT",
        tool_name: toolName,
        data: { tournaments_count: all.length },
        tournaments: all,
      };
    }

    // 6. get1v1Leaderboard
    if (toolName === "get1v1Leaderboard") {
      const limit = Number(args.limit) || 5;
      const { data: players } = await supabase
        .from("vsp_1vs1_players")
        .select("name, total_points, skill_points, goals, tackles, titles, trend")
        .order("total_points", { ascending: false })
        .limit(limit);

      return {
        status: (players || []).length > 0 ? "SUCCESS" : "NO_RESULT",
        tool_name: toolName,
        data: { top_players: players || [] },
        leaderboard: players || [],
      };
    }

    // 7. getOpenMatches
    if (toolName === "getOpenMatches") {
      const { data: matches } = await supabase
        .from("bookings")
        .select("id, stadium_name, start_time, current_players, max_players, notes, total_price")
        .eq("booking_type", "open_join")
        .eq("status", "confirmed")
        .gte("start_time", new Date().toISOString())
        .order("start_time", { ascending: true })
        .limit(5);

      return {
        status: (matches || []).length > 0 ? "SUCCESS" : "NO_RESULT",
        tool_name: toolName,
        data: { matches: matches || [] },
        open_matches: matches || [],
      };
    }

    // 8. executeAppAction
    if (toolName === "executeAppAction") {
      const route = (args.route || "/bookings").toString().trim();
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

    // 9. Owner Tools
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
      };
    }

    return {
      status: "INVALID_INPUT",
      tool_name: toolName,
      data: {},
      error_message: `أداة غير معروفة: ${toolName}`,
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
