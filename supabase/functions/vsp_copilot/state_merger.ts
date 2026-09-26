// Deterministic State Merger for VSP Copilot
// Merges Semantic Parse Output with Current State while preserving untouched facts and invalidating stale caches.

import type { ConversationState } from "./conversation_state.ts";
import type { SemanticParseOutput, TimeEntity } from "./semantic_schema.ts";
import type { ResolvedReferences } from "./reference_resolver.ts";
import { resolveCairoDate } from "./business_rules.ts";
import { createTaskRecord, parkActiveTask, resumeParkedTask } from "./task_manager.ts";

export function mergeState(
  currentState: ConversationState,
  semanticOutput: SemanticParseOutput,
  references: ResolvedReferences
): ConversationState {
  // Clone current state for deterministic update
  const next: ConversationState = {
    ...currentState,
    version: currentState.version + 1,
    stadium: { ...currentState.stadium },
    date: { ...currentState.date },
    times: [...currentState.times],
    candidate_stadiums: [...currentState.candidate_stadiums],
    candidate_bookings: [...(currentState.candidate_bookings || [])],
    task_manager: {
      active_task: currentState.task_manager?.active_task ? { ...currentState.task_manager.active_task } : null,
      parked_tasks: Array.isArray(currentState.task_manager?.parked_tasks)
        ? currentState.task_manager.parked_tasks.map(t => ({ ...t }))
        : [],
    },
    unresolved_ambiguities: [...currentState.unresolved_ambiguities],
    updated_at: new Date().toISOString(),
  };

  let stadiumChanged = false;
  let dateChanged = false;
  let timeChanged = false;

  // 1. Task Lifecycle & Task Switching with Task Stack Support
  const isGeneralOrSideQuestion =
    semanticOutput.domain === "general" ||
    semanticOutput.intent === "general_question" ||
    semanticOutput.object === "bot" ||
    semanticOutput.object === "bot_identity";

  const isResumeRequest =
    semanticOutput.action === "resume" ||
    (semanticOutput.speech_act === "request" && (semanticOutput.raw_user_language || "").includes("نرجع"));

  const isSelfServiceOrPayment =
    semanticOutput.domain === "self_service" ||
    semanticOutput.domain === "payment" ||
    semanticOutput.action === "reconcile" ||
    (semanticOutput.action === "inspect" && semanticOutput.object === "booking");

  if (isResumeRequest) {
    const resumed = resumeParkedTask(next.task_manager, "booking_create");
    if (resumed && resumed.state_snapshot) {
      if (resumed.state_snapshot.stadium) next.stadium = { ...resumed.state_snapshot.stadium };
      if (resumed.state_snapshot.date) next.date = { ...resumed.state_snapshot.date };
      if (resumed.state_snapshot.times) next.times = [...resumed.state_snapshot.times];
      if (resumed.state_snapshot.duration_hours) next.duration_hours = resumed.state_snapshot.duration_hours;
      if (resumed.state_snapshot.group_size) next.group_size = resumed.state_snapshot.group_size;
      next.active_task = "booking";
      next.task_lifecycle = "in_progress";
    } else {
      next.active_task = "booking";
      next.task_lifecycle = "in_progress";
    }
  } else if (isGeneralOrSideQuestion) {
    // If currently in booking, PARK it safely so the side question doesn't destroy the booking task!
    if (next.active_task === "booking") {
      const snapshot = {
        stadium: { ...next.stadium },
        date: { ...next.date },
        times: [...next.times],
        duration_hours: next.duration_hours,
        group_size: next.group_size,
      };
      if (!next.task_manager.active_task) {
        next.task_manager.active_task = createTaskRecord("booking_create", snapshot, "حجز ملعب قيد الإعداد");
      }
      parkActiveTask(next.task_manager);
    }
    next.active_task = "general";
    next.task_lifecycle = "in_progress";
  } else if (isSelfServiceOrPayment) {
    if (next.active_task === "booking" && (next.stadium.name || next.date.value)) {
      const snapshot = {
        stadium: { ...next.stadium },
        date: { ...next.date },
        times: [...next.times],
        duration_hours: next.duration_hours,
      };
      if (!next.task_manager.active_task) {
        next.task_manager.active_task = createTaskRecord("booking_create", snapshot, "حجز ملعب قيد الإعداد");
      }
      parkActiveTask(next.task_manager);
    }
    next.active_task = semanticOutput.domain === "payment" ? "payment" : "self_service";
    next.task_lifecycle = "in_progress";
  } else if (semanticOutput.speech_act === "switch_task" || (semanticOutput.intent !== "unknown" && semanticOutput.intent !== currentState.active_task)) {
    if (next.active_task === "booking" && (next.stadium.name || next.date.value)) {
      const snapshot = { stadium: { ...next.stadium }, date: { ...next.date }, times: [...next.times] };
      if (!next.task_manager.active_task) {
        next.task_manager.active_task = createTaskRecord("booking_create", snapshot);
      }
      parkActiveTask(next.task_manager);
    }
    if (semanticOutput.intent === "booking") {
      next.active_task = "booking";
      next.task_lifecycle = "in_progress";
    } else if (semanticOutput.intent === "stadium_search") {
      next.active_task = "stadium_search";
      next.task_lifecycle = "in_progress";
    } else if (semanticOutput.intent === "tournament") {
      next.active_task = "tournament";
      next.task_lifecycle = "in_progress";
      next.pending_confirmation = null;
    } else if (semanticOutput.intent === "challenge") {
      next.active_task = "challenge";
      next.task_lifecycle = "in_progress";
      next.pending_confirmation = null;
    } else if (semanticOutput.intent === "owner_operations") {
      next.active_task = "owner_stadiums";
      next.task_lifecycle = "in_progress";
    } else if (semanticOutput.intent === "financial_question") {
      next.active_task = "owner_financial";
      next.task_lifecycle = "in_progress";
    }
  } else if (!next.active_task && semanticOutput.intent !== "unknown") {
    next.active_task = semanticOutput.intent as any;
    next.task_lifecycle = "in_progress";
  }

  // 2. Cancellation of current task
  if (semanticOutput.speech_act === "cancel" || (semanticOutput.operation === "cancel" && semanticOutput.changes.some(c => c.field === "task" || c.field === "all"))) {
    next.task_lifecycle = "cancelled";
    next.pending_confirmation = null;
    next.last_verified_availability = null;
    return next;
  }

  // 3. Apply Explicit Semantic Changes (Delta)
  for (const change of semanticOutput.changes) {
    if (change.field === "stadium") {
      if (change.operation === "clear") {
        next.stadium = { id: null, name: null, provenance: "none", status: "cleared" };
        stadiumChanged = true;
      }
    } else if (change.field === "date") {
      if (change.operation === "clear") {
        next.date = { value: null, label: null, status: "cleared" };
        dateChanged = true;
      }
    } else if (change.field === "time") {
      if (change.operation === "clear") {
        next.times = [];
        next.time_period_confirmed = false;
        timeChanged = true;
      }
    } else if (change.field === "group_size") {
      if (change.operation === "clear") next.group_size = null;
    }
  }

  // 4. Resolve Stadium from references or explicit entities
  if (references.resolved_stadium) {
    const resolved = references.resolved_stadium;
    if (next.stadium.id !== resolved.id) {
      next.stadium = {
        id: resolved.id,
        name: resolved.name,
        price_per_hour: resolved.price_per_hour,
        provenance: "resolved_reference",
        status: "known",
      };
      stadiumChanged = true;
    }
  } else if (semanticOutput.entities.stadium?.name) {
    const explicitName = semanticOutput.entities.stadium.name;
    if (next.stadium.name !== explicitName) {
      next.stadium = {
        id: null, // Will be verified by DB query
        name: explicitName,
        provenance: "explicit_user",
        status: "known",
      };
      stadiumChanged = true;
    }
  }

  // 5. Date Updates
  if (semanticOutput.entities.date?.value || semanticOutput.entities.date?.type) {
    const dateType = semanticOutput.entities.date.type;
    const dateVal = semanticOutput.entities.date.value || dateType;
    const resolvedIso = resolveCairoDate(dateVal);
    if (next.date.value !== resolvedIso) {
      next.date = {
        value: resolvedIso,
        label: dateType === "today" ? "النهارده" : dateType === "tomorrow" ? "بكرة" : null,
        status: "known",
      };
      dateChanged = true;
    }
  }

  // 6. Time Updates
  if (Array.isArray(semanticOutput.entities.times) && semanticOutput.entities.times.length > 0) {
    const newTimes: TimeEntity[] = semanticOutput.entities.times.map(t => {
      // Never guess AM/PM for an ambiguous Egyptian time.
      // The planner must ask for clarification when the period is unknown/ambiguous.
      let hourNum = Number(t.time.split(":")[0]);
      let period = t.period;
      let certainty = t.period_certainty;

      if (period === "pm" && hourNum < 12) {
        hourNum += 12;
      } else if (period === "am" && hourNum === 12) {
        hourNum = 0;
      }

      const formatted = String(hourNum).padStart(2, "0") + ":" + (t.time.split(":")[1] || "00");
      return {
        time: formatted,
        period,
        period_certainty: certainty,
        preference_order: t.preference_order,
      };
    });

    const isDifferent = JSON.stringify(newTimes) !== JSON.stringify(next.times);
    if (isDifferent) {
      next.times = newTimes;
      timeChanged = true;
      // If time was explicitly confirmed or inferred
      const hasAmbiguous = newTimes.some(t => t.period_certainty === "ambiguous");
      next.time_period_confirmed = !hasAmbiguous;
    }
  } else if (semanticOutput.entities.time_range) {
    next.time_range = semanticOutput.entities.time_range;
    next.times = [];
    timeChanged = true;
  }

  // Duration
  if (semanticOutput.entities.duration_hours) {
    next.duration_hours = semanticOutput.entities.duration_hours;
  }

  // Group Size
  if (semanticOutput.entities.group_size != null) {
    next.group_size = semanticOutput.entities.group_size;
  }

  // Location
  if (semanticOutput.entities.location?.governorate) {
    next.location_scope = semanticOutput.entities.location.governorate;
  } else if (semanticOutput.entities.location?.near_user) {
    next.location_scope = "nearby";
  }

  // 7. Invalidate Stale Availability & Proposal on Field Mutations
  if (stadiumChanged || dateChanged || timeChanged) {
    next.last_verified_availability = null;
    next.pending_confirmation = null;
  }

  // 8. Handle Confirmation of Pending Time Period
  if (semanticOutput.confirmation.meaning === "accepted" && semanticOutput.confirmation.target === "time_period") {
    next.time_period_confirmed = true;
    next.unresolved_ambiguities = next.unresolved_ambiguities.filter(a => a.type !== "time_period");
  }

  // 9. Update Ambiguities
  const allAmbiguities = [...semanticOutput.ambiguities, ...references.ambiguities];
  // Deduplicate by type
  const uniqueAmbiguities = Array.from(new Map(allAmbiguities.map(a => [a.type, a])).values());
  next.unresolved_ambiguities = uniqueAmbiguities;

  return next;
}
