// Business Rules, Timezone & Role Authorization Firewall for VSP Copilot
// Deterministic operational logic and Egyptian timezone calculations.

import type { SemanticConfirmation } from "./semantic_schema.ts";

// Capability SSOT Re-exports from capability_registry.ts
export { isToolAllowedForRole, getAllowedToolsForRole, getCapabilityByTool, CAPABILITY_REGISTRY } from "./capability_registry.ts";

export function isRouteAllowedForRole(role: string | undefined | null, route: string): boolean {
  if (!route || typeof route !== "string") return false;
  const clean = route.trim();
  const normRole = (role || "").toLowerCase().trim();
  const canonicalRole = (normRole === "pitch_owner" || normRole === "owner") ? "owner" : normRole;

  if (canonicalRole === "owner") {
    const ownerAllowed = [
      "/dashboard",
      "/bookings",
      "/ledger",
      "/profile",
      "/settings",
      "/add-stadium",
      "/subscription-plans",
    ];
    return ownerAllowed.some((r) => clean === r || clean.startsWith(r + "/") || clean.startsWith(r + "?"));
  }
  return false;
}

// Egyptian Timezone (Africa/Cairo) Date Calculations
export function getCairoDateParts(now: Date = new Date()): { year: number; month: number; day: number; hour: number; minute: number; dayOfWeek: number } {
  const cairoFormatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = cairoFormatter.formatToParts(now);
  const get = (type: string) => Number(parts.find(p => p.type === type)?.value || 0);
  const y = get("year");
  const m = get("month");
  const d = get("day");
  // Calculate dayOfWeek in Cairo
  const cairoDate = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  return {
    year: y,
    month: m,
    day: d,
    hour: get("hour"),
    minute: get("minute"),
    dayOfWeek: cairoDate.getUTCDay(), // 0 = Sunday, 1 = Monday, ..., 5 = Friday, 6 = Saturday
  };
}

const EGYPTIAN_WEEKDAYS: Record<string, number> = {
  "الاحد": 0, "الأحد": 0, "احد": 0, "أحد": 0, "sunday": 0,
  "الاثنين": 1, "الإثنين": 1, "اتنين": 1, "monday": 1,
  "الثلاثاء": 2, "تلات": 2, "الثلاثا": 2, "tuesday": 2,
  "الاربعاء": 3, "الأربعاء": 3, "اربع": 3, "أربع": 3, "wednesday": 3,
  "الخميس": 4, "خميس": 4, "thursday": 4,
  "الجمعة": 5, "جمعة": 5, "جمعه": 5, "friday": 5,
  "السبت": 6, "سبت": 6, "saturday": 6,
};

export function resolveCairoDate(token: string | undefined | null, now: Date = new Date()): string {
  const cairo = getCairoDateParts(now);
  const base = new Date(Date.UTC(cairo.year, cairo.month - 1, cairo.day, 12, 0, 0));

  if (!token) {
    return base.toISOString().slice(0, 10);
  }

  const clean = token.toLowerCase().trim();

  // If already ISO YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) {
    return clean;
  }

  // Today
  if (clean === "today" || clean === "النهارده" || clean === "النهاردة" || clean === "اليوم") {
    return base.toISOString().slice(0, 10);
  }

  // Tomorrow
  if (clean === "tomorrow" || clean === "بكرة" || clean === "بكره" || clean === "غدا" || clean === "غداً") {
    base.setUTCDate(base.getUTCDate() + 1);
    return base.toISOString().slice(0, 10);
  }

  // After Tomorrow
  if (clean === "after_tomorrow" || clean === "بعد بكرة" || clean === "بعد بكره" || clean === "بعد غد") {
    base.setUTCDate(base.getUTCDate() + 2);
    return base.toISOString().slice(0, 10);
  }

  // Check Friday / Weekday relative phrases
  // E.g. "الجمعة دي", "this_friday", "الجمعة الجاية", "next_friday"
  const isThisWeek = clean.includes("دي") || clean.includes("ده") || clean.startsWith("this_");
  const isNextWeek = clean.includes("الجاية") || clean.includes("الجايه") || clean.includes("القادمة") || clean.startsWith("next_");

  let targetDayOfWeek: number | null = null;
  for (const [dayName, dayIndex] of Object.entries(EGYPTIAN_WEEKDAYS)) {
    if (clean.includes(dayName)) {
      targetDayOfWeek = dayIndex;
      break;
    }
  }

  if (targetDayOfWeek !== null) {
    const currentDay = cairo.dayOfWeek;
    let diff = (targetDayOfWeek - currentDay + 7) % 7;

    if (isThisWeek) {
      // "الجمعة دي": if today is Friday, it's today (diff = 0); otherwise the upcoming Friday of this cycle
      base.setUTCDate(base.getUTCDate() + diff);
      return base.toISOString().slice(0, 10);
    } else if (isNextWeek) {
      // "الجمعة الجاية": if today is Friday, it's next week's Friday (+7 days)
      // If diff is 0 (today is the day), add 7. If diff > 0, the next week's occurrence is diff + 7
      const addDays = diff === 0 ? 7 : diff + 7;
      base.setUTCDate(base.getUTCDate() + addDays);
      return base.toISOString().slice(0, 10);
    } else {
      // Bare day name (e.g. "الجمعة") without qualifier: defaults to next upcoming occurrence (or today if today)
      base.setUTCDate(base.getUTCDate() + (diff === 0 ? 7 : diff));
      return base.toISOString().slice(0, 10);
    }
  }

  return base.toISOString().slice(0, 10);
}

export function resolveEgyptianTimeExpression(phrase: string): {
  type: string;
  label: string;
  from_hour: number;
  to_hour: number;
  period: "morning" | "afternoon" | "evening" | "night";
} | null {
  if (!phrase) return null;
  const p = phrase.toLowerCase().trim();
  if (/سهرة|سهرة\s*متأخرة/i.test(p)) {
    return { type: "late_night", label: "سهرة", from_hour: 23, to_hour: 2, period: "night" };
  }
  if (/بعد\s*المغرب/i.test(p)) {
    return { type: "after_maghrib", label: "بعد المغرب", from_hour: 18, to_hour: 21, period: "evening" };
  }
  if (/بعد\s*الظهر|بعد\s*الضهر|بعد\s*العصر/i.test(p)) {
    return { type: "afternoon", label: "بعد الظهر", from_hour: 14, to_hour: 18, period: "afternoon" };
  }
  if (/بالليل|ليل|مساء|المساء/i.test(p)) {
    return { type: "evening", label: "بالليل", from_hour: 20, to_hour: 23, period: "evening" };
  }
  if (/الصبح|صباح|الصباح/i.test(p)) {
    return { type: "morning", label: "الصبح", from_hour: 6, to_hour: 12, period: "morning" };
  }
  return null;
}

export function isPastDate(isoDate: string, now: Date = new Date()): boolean {
  const today = resolveCairoDate("today", now);
  return isoDate < today;
}

export function parseHourMinute(timeStr: string): { hour: number; minute: number } | null {
  if (!timeStr) return null;
  const match = /^(\d{1,2}):(\d{2})$/.exec(timeStr.trim());
  if (!match) return null;
  const h = Number(match[1]);
  const m = Number(match[2]);
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return { hour: h, minute: m };
}

// Contextual Confirmation Evaluator
export function evaluateContextualConfirmation(
  lastInteraction: { type: string; prompt_target?: string | null } | null,
  confirmation: SemanticConfirmation,
  speechAct: string
): { isConfirmed: boolean; isRejected: boolean; target: string | null } {
  // If the user's speech act is reject or confirmation is rejected
  if (speechAct === "reject" || confirmation.meaning === "rejected") {
    return { isConfirmed: false, isRejected: true, target: confirmation.target || lastInteraction?.prompt_target || null };
  }

  // If the user explicitly confirmed
  if (speechAct === "confirm" || confirmation.meaning === "accepted") {
    // Check what was pending
    if (lastInteraction?.type === "PROMPT_TIME_PERIOD_CONFIRMATION") {
      return { isConfirmed: true, isRejected: false, target: "time_period" };
    }
    if (lastInteraction?.type === "PROMPT_BOOKING_PROPOSAL") {
      return { isConfirmed: true, isRejected: false, target: "booking_proposal" };
    }
    return { isConfirmed: true, isRejected: false, target: confirmation.target || null };
  }

  return { isConfirmed: false, isRejected: false, target: null };
}
