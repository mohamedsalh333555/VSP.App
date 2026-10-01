// Owner Copilot SSOT Verification Suite
// Tests Tasks 1, 2, and 3 with deterministic assertions and a controlled clock.

import assert from "node:assert/strict";
import {
  CAPABILITY_REGISTRY,
  isToolAllowedForRole,
  getAllowedToolsForRole,
  getCapabilityByTool,
} from "./capability_registry.ts";
import { validateAssistantResponseFacts } from "./response_generator.ts";
import { resolveCairoDate, getCairoDateParts, resolveEgyptianTimeExpression } from "./business_rules.ts";
import { createInitialConversationState } from "./conversation_state.ts";
import { resolveReferences } from "./reference_resolver.ts";
import { mergeState } from "./state_merger.ts";
import { planToolExecution } from "./tool_planner.ts";

console.log("===============================================================================");
console.log("RUNNING OWNER COPILOT SSOT VERIFICATION SUITE");
console.log("===============================================================================");

// ============================================================================
// TASK 1: Capability SSOT Verification
// ============================================================================
console.log("\n>>> [TASK 1] Testing Capability SSOT in capability_registry.ts...");

// 1. Verify exactly 4 capabilities exist in Registry
const registeredKeys = Object.keys(CAPABILITY_REGISTRY);
assert.equal(registeredKeys.length, 4, "Registry must contain exactly 4 capabilities");

const expectedTools = [
  "getOwnerStadiumsAndBookings",
  "getOwnerFinancialInsights",
  "checkStadiumAvailability",
  "executeAppAction",
];

for (const tool of expectedTools) {
  const cap = getCapabilityByTool(tool);
  assert.ok(cap, `Tool ${tool} must exist in CAPABILITY_REGISTRY`);
  assert.deepEqual(cap.allowed_roles, ["owner"], `Tool ${tool} must only be allowed for owner`);
  assert.ok(cap.workflow_id, `Tool ${tool} must declare a workflow`);
  assert.ok(typeof cap.is_read_only === "boolean", `Tool ${tool} must declare is_read_only`);
  assert.ok(cap.risk_level, `Tool ${tool} must declare risk_level`);
}

// 2. Test role allowlist matches Registry exactly
const ownerAllowed = getAllowedToolsForRole("owner");
assert.equal(ownerAllowed.length, 4);
for (const tool of expectedTools) {
  assert.ok(ownerAllowed.includes(tool), `Owner must have tool ${tool}`);
}

// 3. Player must have ZERO capabilities
const playerAllowed = getAllowedToolsForRole("player");
assert.equal(playerAllowed.length, 0, "Player must have 0 allowed tools in Copilot");

for (const tool of expectedTools) {
  assert.equal(isToolAllowedForRole("player", tool), false, `Player must not be allowed to call ${tool}`);
}
assert.equal(isToolAllowedForRole("player", "createBookingFromChat"), false);
assert.equal(isToolAllowedForRole("player", "searchStadiums"), false);

// 4. Unknown tool must be rejected
assert.equal(isToolAllowedForRole("owner", "unknownPhantomTool"), false, "Unknown tool must be rejected");
assert.equal(isToolAllowedForRole("owner", "createBookingFromChat"), false, "Player tool must be rejected for owner");

console.log("✅ [TASK 1 PASS] Capability SSOT verified: 4 owner tools, 0 player tools, 0 phantom capabilities.");

// ============================================================================
// TASK 2: Fact Validator Decoupling of stadiums_count vs bookings_count
// ============================================================================
console.log("\n>>> [TASK 2] Testing Fact Validator Booking Counts Decoupling...");

const dummyState = createInitialConversationState("owner-test-usr", "owner");

// Case A: 2 stadiums + 1 booking
const toolResultCaseA = {
  status: "SUCCESS" as const,
  tool_name: "getOwnerStadiumsAndBookings",
  data: {
    stadiums_count: 2,
    bookings_count: 1,
  },
  stadiums: [{ id: "std-1", name: "ملعب النجوم" }, { id: "std-2", name: "ملعب الأبطال" }],
  bookings: [{ id: "bk-1", stadium_id: "std-1", start_time: "2026-10-01T18:00:00Z" }],
};

const dummyPlan = { action: "EXECUTE_TOOL" as const, toolName: "getOwnerStadiumsAndBookings" };

// 1. Response claiming 2 stadiums + 1 booking => MUST PASS
const resA1 = validateAssistantResponseFacts("عندك 2 ملاعب و 1 حجز اليوم", dummyState, dummyPlan, toolResultCaseA);
assert.equal(resA1.isValid, true, `Should accept verified 2 stadiums and 1 booking: ${resA1.reason}`);

// 2. Response claiming "2 حجوزات" => MUST BE REJECTED! (The core bug: stadiums_count must never be used for bookings!)
const resA2 = validateAssistantResponseFacts("عندك 2 حجوزات مسجلة اليوم", dummyState, dummyPlan, toolResultCaseA);
assert.equal(resA2.isValid, false, "Must reject claiming 2 bookings when only 1 booking exists!");
assert.match(resA2.reason || "", /Claimed booking count \(2\) does not match verified count/);

// 3. Response claiming "1 حجز" => MUST PASS
const resA3 = validateAssistantResponseFacts("عندك 1 حجز مسجل اليوم", dummyState, dummyPlan, toolResultCaseA);
assert.equal(resA3.isValid, true, "Should accept 1 booking");

// 4. Response claiming "2 ملاعب" => MUST PASS
const resA4 = validateAssistantResponseFacts("مسجل عندك 2 ملاعب في النظام", dummyState, dummyPlan, toolResultCaseA);
assert.equal(resA4.isValid, true, "Should accept 2 stadiums");

// 5. Response claiming "3 ملاعب" => MUST BE REJECTED
const resA5 = validateAssistantResponseFacts("مسجل عندك 3 ملاعب", dummyState, dummyPlan, toolResultCaseA);
assert.equal(resA5.isValid, false, "Must reject false stadium count");

// Case B: 0 Bookings
const toolResultZeroBookings = {
  status: "SUCCESS" as const,
  tool_name: "getOwnerStadiumsAndBookings",
  data: { stadiums_count: 1, bookings_count: 0 },
  stadiums: [{ id: "std-1", name: "الملعب" }],
  bookings: [],
};

const resB1 = validateAssistantResponseFacts("عندك 0 حجز اليوم في ملعبك", dummyState, dummyPlan, toolResultZeroBookings);
assert.equal(resB1.isValid, true, "Should accept 0 bookings");

const resB2 = validateAssistantResponseFacts("عندك 1 حجز اليوم في ملعبك", dummyState, dummyPlan, toolResultZeroBookings);
assert.equal(resB2.isValid, false, "Must reject 1 booking when 0 bookings exist");

// Case C: Multiple Bookings (3 bookings)
const toolResultThreeBookings = {
  status: "SUCCESS" as const,
  tool_name: "getOwnerStadiumsAndBookings",
  data: { stadiums_count: 1, bookings_count: 3 },
  stadiums: [{ id: "std-1", name: "الملعب" }],
  bookings: [
    { id: "bk-1", status: "confirmed" },
    { id: "bk-2", status: "confirmed" },
    { id: "bk-3", status: "pending" },
  ],
};

const resC1 = validateAssistantResponseFacts("عندك 3 حجوزات مسجلة اليوم", dummyState, dummyPlan, toolResultThreeBookings);
assert.equal(resC1.isValid, true, "Should accept 3 bookings");

const resC2 = validateAssistantResponseFacts("عندك 4 حجوزات مسجلة اليوم", dummyState, dummyPlan, toolResultThreeBookings);
assert.equal(resC2.isValid, false, "Must reject 4 bookings when 3 exist");

console.log("✅ [TASK 2 PASS] Fact Validator strictly decouples stadiums_count and bookings_count.");

// ============================================================================
// TASK 3: Egyptian Temporal Engine with Controlled Clock
// ============================================================================
console.log("\n>>> [TASK 3] Testing Egyptian Temporal Engine with Controlled Clock...");

// Clock A: Fixed Thursday (2026-10-01 14:00 Cairo time)
const thursdayClock = new Date(Date.UTC(2026, 9, 1, 12, 0, 0)); // 2026-10-01 (Oct 1 is Thursday)

// Relative Dates
assert.equal(resolveCairoDate("النهارده", thursdayClock), "2026-10-01");
assert.equal(resolveCairoDate("today", thursdayClock), "2026-10-01");
assert.equal(resolveCairoDate("بكرة", thursdayClock), "2026-10-02");
assert.equal(resolveCairoDate("tomorrow", thursdayClock), "2026-10-02");
assert.equal(resolveCairoDate("بعد بكرة", thursdayClock), "2026-10-03");
assert.equal(resolveCairoDate("after_tomorrow", thursdayClock), "2026-10-03");

// Egyptian Friday relative resolution from Thursday:
// "الجمعة دي" = tomorrow (Friday Oct 2)
assert.equal(resolveCairoDate("الجمعة دي", thursdayClock), "2026-10-02");
// "الجمعة الجاية" = next week Friday (Friday Oct 9)
assert.equal(resolveCairoDate("الجمعة الجاية", thursdayClock), "2026-10-09");

// Clock B: Fixed Friday (2026-10-02 12:00 Cairo time)
const fridayClock = new Date(Date.UTC(2026, 9, 2, 10, 0, 0));
// On Friday, "الجمعة دي" is today (2026-10-02)
assert.equal(resolveCairoDate("الجمعة دي", fridayClock), "2026-10-02");
// On Friday, "الجمعة الجاية" is next Friday (2026-10-09)
assert.equal(resolveCairoDate("الجمعة الجاية", fridayClock), "2026-10-09");

// Time Expressions (الصبح, بعد الظهر, بعد المغرب, بالليل, سهرة)
const expMorning = resolveEgyptianTimeExpression("الصبح");
assert.ok(expMorning);
assert.equal(expMorning.period, "morning");
assert.equal(expMorning.from_hour, 6);
assert.equal(expMorning.to_hour, 12);

const expAfternoon = resolveEgyptianTimeExpression("بعد الظهر");
assert.ok(expAfternoon);
assert.equal(expAfternoon.period, "afternoon");
assert.equal(expAfternoon.from_hour, 14);

const expMaghrib = resolveEgyptianTimeExpression("بعد المغرب");
assert.ok(expMaghrib);
assert.equal(expMaghrib.period, "evening");
assert.equal(expMaghrib.from_hour, 18);
assert.equal(expMaghrib.to_hour, 21);

const expEvening = resolveEgyptianTimeExpression("بالليل");
assert.ok(expEvening);
assert.equal(expEvening.period, "evening");
assert.equal(expEvening.from_hour, 20);
assert.equal(expEvening.to_hour, 23);

const expLateNight = resolveEgyptianTimeExpression("سهرة");
assert.ok(expLateNight);
assert.equal(expLateNight.period, "night");
assert.equal(expLateNight.from_hour, 23);

// Time Ambiguity Handling: "الساعة 10" vs "الساعة 10 أو 11"
// 1. "الساعة 10" without PM/AM clue must be ambiguous
const stateWithAmbiguousTime = mergeState(
  dummyState,
  {
    schema_version: 1,
    speech_act: "inform",
    domain: "booking",
    object: "booking",
    action: "create",
    semantic_status: "in_progress",
    intent: "booking",
    operation: "create",
    entities: {
      times: [{ time: "10:00", period: "unknown", period_certainty: "inferred" }],
    },
    references: [],
    changes: [{ field: "time", operation: "set", value: "10:00" }],
    ambiguities: [{ type: "time_period", description: "الساعة 10 الصبح ولا بالليل؟", options: ["10 الصبح", "10 بالليل"] }],
    confirmation: { meaning: "none", target: null },
    execution_request: { requested: false, target: null },
  },
  { resolved_stadium: null, fallback_stadium: null, resolved_time: null, resolved_date: null, ambiguities: [] }
);

assert.equal(stateWithAmbiguousTime.time_period_confirmed, false, "Period must not be confirmed without AM/PM clue");
const planAmbiguous = planToolExecution(stateWithAmbiguousTime, {
  schema_version: 1,
  speech_act: "inform",
  domain: "booking",
  object: "booking",
  action: "create",
  semantic_status: "in_progress",
  intent: "booking",
  operation: "create",
  entities: {},
  references: [],
  changes: [],
  ambiguities: [{ type: "time_period", description: "الساعة 10 الصبح ولا بالليل؟" }],
  confirmation: { meaning: "none", target: null },
  execution_request: { requested: false, target: null },
});
assert.equal(planAmbiguous.action, "CLARIFY_AMBIGUITY", "Planner must clarify AM/PM ambiguity rather than guessing");

// 2. "الساعة 10 أو 11" maintains BOTH choices in state
const stateWithMultipleTimes = mergeState(
  dummyState,
  {
    schema_version: 1,
    speech_act: "inform",
    domain: "booking",
    object: "booking",
    action: "create",
    semantic_status: "in_progress",
    intent: "booking",
    operation: "create",
    entities: {
      times: [
        { time: "22:00", period: "pm", period_certainty: "explicit", preference_order: 1 },
        { time: "23:00", period: "pm", period_certainty: "explicit", preference_order: 2 },
      ],
    },
    references: [],
    changes: [],
    ambiguities: [],
    confirmation: { meaning: "none", target: null },
    execution_request: { requested: false, target: null },
  },
  { resolved_stadium: null, fallback_stadium: null, resolved_time: null, resolved_date: null, ambiguities: [] }
);

assert.equal(stateWithMultipleTimes.times.length, 2, "Must preserve both 10 and 11 choices");
assert.equal(stateWithMultipleTimes.times[0].time, "22:00");
assert.equal(stateWithMultipleTimes.times[1].time, "23:00");

// 3. Multi-turn Stadium Persistence ("نفس الملعب")
// Turn 1: User establishes stadium "ملعب الأبطال" (id: "std-abc")
let turnState = createInitialConversationState("owner-test", "owner");
turnState.stadium = {
  id: "std-abc",
  name: "ملعب الأبطال",
  status: "known",
  provenance: "explicit_user",
};

// Turn 2: User says "الجمعة الجاية بالليل"
turnState = mergeState(
  turnState,
  {
    schema_version: 1,
    speech_act: "inform",
    domain: "booking",
    object: "stadium",
    action: "inspect",
    semantic_status: "in_progress",
    intent: "booking",
    operation: "inspect",
    entities: {
      date: { type: "next_friday", value: "2026-10-09" },
      time_range: { from_hour: 20, to_hour: 23, label: "بالليل" },
    },
    references: [],
    changes: [{ field: "date", operation: "set", value: "2026-10-09" }],
    ambiguities: [],
    confirmation: { meaning: "none", target: null },
    execution_request: { requested: false, target: null },
  },
  { resolved_stadium: null, fallback_stadium: null, resolved_time: null, resolved_date: null, ambiguities: [] }
);

assert.equal(turnState.stadium.id, "std-abc", "Stadium identity must be retained in Turn 2");
assert.equal(turnState.date.value, "2026-10-09", "Date must be resolved to next Friday");

// Turn 3: User says "نفس الملعب"
const refResolved = resolveReferences(
  turnState,
  [{ reference_type: "context_entity", source_phrase: "نفس الملعب", target: "same_stadium" }],
  "نفس الملعب"
);

assert.ok(refResolved.resolved_stadium, "Reference resolver must resolve 'same_stadium'");
assert.equal(refResolved.resolved_stadium?.id, "std-abc");
assert.equal(refResolved.resolved_stadium?.name, "ملعب الأبطال");

turnState = mergeState(
  turnState,
  {
    schema_version: 1,
    speech_act: "inform",
    domain: "booking",
    object: "stadium",
    action: "inspect",
    semantic_status: "in_progress",
    intent: "booking",
    operation: "inspect",
    entities: {},
    references: [{ reference_type: "context_entity", source_phrase: "نفس الملعب", target: "same_stadium" }],
    changes: [],
    ambiguities: [],
    confirmation: { meaning: "none", target: null },
    execution_request: { requested: false, target: null },
  },
  refResolved
);

assert.equal(turnState.stadium.id, "std-abc", "Stadium identity must remain intact after 'نفس الملعب'");
assert.equal(turnState.stadium.name, "ملعب الأبطال");

console.log("✅ [TASK 3 PASS] Controlled clock temporal engine & context persistence verified.");

console.log("\n===============================================================================");
console.log("ALL TARGETED TESTS FOR TASKS 1, 2, AND 3 PASSED PERFECTLY!");
console.log("===============================================================================");
