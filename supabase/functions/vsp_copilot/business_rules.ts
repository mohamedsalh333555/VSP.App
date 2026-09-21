// Business Rules, Timezone & Role Authorization Firewall for VSP Copilot
// Deterministic operational logic and Egyptian timezone calculations.

import type { SemanticConfirmation } from "./semantic_schema.ts";

// Role-Based Access Control allowlist
const PLAYER_ALLOWED_TOOLS = new Set([
  "searchStadiums",
  "checkStadiumAvailability",
  "createBookingFromChat",
  "searchTournaments",
  "get1v1Leaderboard",
  "getOpenMatches",
  "getUserBookingsAndRefunds",
  "updateUserProfile",
  "executeAppAction",
]);

const OWNER_ALLOWED_TOOLS = new Set([
  "getOwnerStadiumsAndBookings",
  "getOwnerFinancialInsights",
  "checkStadiumAvailability",
  "executeAppAction",
  "updateUserProfile",
]);

export function isToolAllowedForRole(role: string | undefined | null, toolName: string): boolean {
  const normRole = (role || "").toLowerCase().trim();
  if (normRole === "owner" || normRole === "pitch_owner") {
    return OWNER_ALLOWED_TOOLS.has(toolName);
  }
  // Default to player
  return PLAYER_ALLOWED_TOOLS.has(toolName);
}

export function isRouteAllowedForRole(role: string | undefined | null, route: string): boolean {
  const normRole = (role || "").toLowerCase().trim();
  if (normRole === "owner" || normRole === "pitch_owner") {
    return ["/dashboard", "/bookings", "/ledger", "/profile", "/settings", "/add-stadium", "/subscription-plans"].some(r => route.startsWith(r));
  }
  return ["/player", "/tournaments", "/1v1", "/my-team", "/bookings", "/profile", "/settings", "/checkout"].some(r => route.startsWith(r));
}

// Egyptian Timezone (Africa/Cairo) Date Calculations
export function getCairoDateParts(now: Date = new Date()): { year: number; month: number; day: number; hour: number; minute: number } {
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
  return {
    year: get("year"),
    month: get("month"),
    day: get("day"),
    hour: get("hour"),
    minute: get("minute"),
  };
}

export function resolveCairoDate(token: string | undefined | null, now: Date = new Date()): string {
  const cairo = getCairoDateParts(now);
  const base = new Date(Date.UTC(cairo.year, cairo.month - 1, cairo.day, 12, 0, 0));

  if (!token || token === "today") {
    return base.toISOString().slice(0, 10);
  }
  if (token === "tomorrow") {
    base.setUTCDate(base.getUTCDate() + 1);
    return base.toISOString().slice(0, 10);
  }
  if (token === "after_tomorrow") {
    base.setUTCDate(base.getUTCDate() + 2);
    return base.toISOString().slice(0, 10);
  }
  // If already ISO YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(token)) {
    return token;
  }
  return base.toISOString().slice(0, 10);
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
