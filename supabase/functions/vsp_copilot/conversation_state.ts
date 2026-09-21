// Conversation State Model & Lifecycle Definitions for VSP Copilot
// Maintains verified operational facts independently of LLM generation.

import type { TimeEntity, SemanticAmbiguity } from "./semantic_schema.ts";

export type FieldStatus = "unknown" | "known" | "inferred" | "ambiguous" | "confirmed" | "stale" | "cleared";

export interface StadiumState {
  id: string | null;
  name: string | null;
  provenance: "explicit_user" | "resolved_reference" | "inferred_single" | "none";
  status: FieldStatus;
  price_per_hour?: number;
}

export interface DateState {
  value: string | null; // ISO YYYY-MM-DD
  label: string | null; // e.g., "النهارده", "بكرة"
  status: FieldStatus;
}

export interface VisibleEntity {
  reference_key: string; // e.g. "stadium_1", "tournament_1"
  entity_type: "stadium" | "tournament" | "match";
  id: string;
  name: string;
  price_per_hour?: number;
  governorate?: string;
  extra?: Record<string, any>;
}

export interface PendingConfirmation {
  type: "booking_proposal" | "cancellation";
  stadium_id: string;
  stadium_name: string;
  date: string;
  start_time: string; // ISO 8601 UTC
  end_time: string;   // ISO 8601 UTC
  price_per_hour: number;
}

export interface ConversationState {
  version: number;
  active_task: "booking" | "stadium_search" | "availability" | "tournament" | "challenge" | "owner_financial" | "owner_stadiums" | "profile" | "general" | null;
  task_lifecycle: "idle" | "in_progress" | "pending_confirmation" | "awaiting_clarification" | "completed" | "cancelled";
  stadium: StadiumState;
  candidate_stadiums: VisibleEntity[];
  date: DateState;
  times: TimeEntity[];
  time_period_confirmed: boolean;
  time_range: { from_hour?: number; to_hour?: number; label?: string } | null;
  duration_hours: number;
  group_size: number | null;
  location_scope: string | null;
  pending_confirmation: PendingConfirmation | null;
  unresolved_ambiguities: SemanticAmbiguity[];
  last_verified_availability: {
    stadium_id: string;
    date: string;
    slots: Array<{ start_time: string; end_time: string; display_time: string }>;
    checked_at: string;
  } | null;
  last_visible_entities: VisibleEntity[];
  user_role: "player" | "owner" | "admin";
  created_at: string;
  updated_at: string;
}

export function createInitialConversationState(userRole: "player" | "owner" | "admin" = "player"): ConversationState {
  const now = new Date().toISOString();
  return {
    version: 1,
    active_task: null,
    task_lifecycle: "idle",
    stadium: {
      id: null,
      name: null,
      provenance: "none",
      status: "unknown",
    },
    candidate_stadiums: [],
    date: {
      value: null,
      label: null,
      status: "unknown",
    },
    times: [],
    time_period_confirmed: false,
    time_range: null,
    duration_hours: 1,
    group_size: null,
    location_scope: null,
    pending_confirmation: null,
    unresolved_ambiguities: [],
    last_verified_availability: null,
    last_visible_entities: [],
    user_role: userRole,
    created_at: now,
    updated_at: now,
  };
}

// Convert legacy task_state / context_snapshot to strongly-typed ConversationState
export function hydrateConversationState(rawSnapshot: any, userRole: "player" | "owner" | "admin" = "player"): ConversationState {
  if (!rawSnapshot || typeof rawSnapshot !== "object") {
    return createInitialConversationState(userRole);
  }

  // Check if it already has our new schema
  if (rawSnapshot.version && rawSnapshot.stadium && rawSnapshot.date) {
    return {
      ...createInitialConversationState(userRole),
      ...rawSnapshot,
      version: (rawSnapshot.version || 1) + 1,
      updated_at: new Date().toISOString(),
    };
  }

  // Hydrate from legacy context_snapshot / task_state
  const state = createInitialConversationState(userRole);
  const task = rawSnapshot.task_state || {};

  if (task.intent === "book_stadium" || task.intent === "booking") {
    state.active_task = "booking";
    state.task_lifecycle = task.confirmation_pending ? "pending_confirmation" : "in_progress";
  } else if (task.intent === "search_stadiums" || task.intent === "stadium_search") {
    state.active_task = "stadium_search";
    state.task_lifecycle = "in_progress";
  }

  if (task.stadium_id || task.stadium_name || rawSnapshot.last_stadium_id) {
    state.stadium = {
      id: task.stadium_id || rawSnapshot.last_stadium_id || null,
      name: task.stadium_name || rawSnapshot.last_stadium_name || null,
      provenance: "explicit_user",
      status: "known",
    };
  }

  if (task.date || rawSnapshot.last_date) {
    state.date = {
      value: task.date || rawSnapshot.last_date,
      label: null,
      status: "known",
    };
  }

  if (Array.isArray(task.preferred_times) && task.preferred_times.length > 0) {
    state.times = task.preferred_times.map((t: string, idx: number) => ({
      time: t,
      period: Number(t.substring(0, 2)) >= 12 ? "pm" : "am",
      period_certainty: "inferred",
      preference_order: idx + 1,
    }));
    state.time_period_confirmed = task.time_period_confirmed === true;
  }

  if (task.group_size) {
    state.group_size = Number(task.group_size);
  }

  if (task.time_window) {
    state.time_range = task.time_window;
  }

  if (task.confirmation_pending) {
    state.pending_confirmation = {
      type: "booking_proposal",
      stadium_id: task.confirmation_pending.stadium_id,
      stadium_name: task.confirmation_pending.stadium_name,
      date: task.confirmation_pending.date,
      start_time: task.confirmation_pending.start_time,
      end_time: task.confirmation_pending.end_time,
      price_per_hour: task.confirmation_pending.price_per_hour || 0,
    };
  }

  if (Array.isArray(rawSnapshot.last_visible_stadiums)) {
    state.last_visible_entities = rawSnapshot.last_visible_stadiums.map((s: any, idx: number) => ({
      reference_key: `stadium_${idx + 1}`,
      entity_type: "stadium",
      id: s.id,
      name: s.name,
      price_per_hour: s.price_per_hour,
      governorate: s.governorate,
    }));
    state.candidate_stadiums = [...state.last_visible_entities];
  }

  return state;
}
