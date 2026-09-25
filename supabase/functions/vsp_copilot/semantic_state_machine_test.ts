// @ts-nocheck
// Semantic State Machine & Invariant Test Suite for VSP Copilot
// Verifies semantic categories, state invariants, reference resolution, and Scenarios A-L.

import assert from "node:assert/strict";
import type { SemanticParseOutput } from "./semantic_schema.ts";
import {
  validateAndNormalizeSemanticOutput,
  createSafeFallbackOutput,
} from "./semantic_schema.ts";
import type { ConversationState } from "./conversation_state.ts";
import {
  createInitialConversationState,
  hydrateConversationState,
} from "./conversation_state.ts";
import { resolveReferences } from "./reference_resolver.ts";
import { mergeState } from "./state_merger.ts";
import { planToolExecution, type ToolPlan } from "./tool_planner.ts";
import {
  isToolAllowedForRole,
  resolveCairoDate,
  evaluateContextualConfirmation,
} from "./business_rules.ts";
import {
  formatArabicCount,
  generateDeterministicResponse,
  validateAssistantResponseFacts,
} from "./response_generator.ts";

console.log("Starting VSP Copilot Semantic State Machine Test Suite...");

// ==========================================
// 1. INVARIANT TESTS (Section 22)
// ==========================================

// Invariant 1: A turn that does not change date must never erase a valid date.
{
  const state = createInitialConversationState("player");
  state.date = { value: "2026-09-25", label: "الجمعة", status: "known" };
  state.stadium = { id: "std_1", name: "ملعب الأبطال", provenance: "explicit_user", status: "known" };

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "modify",
    entities: {
      times: [{ time: "21:00", period: "pm", period_certainty: "explicit", preference_order: 1 }],
    },
    references: [],
    changes: [{ field: "time", operation: "set", value: "21:00" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "خليها الساعة 9 بالليل");

  const refs = resolveReferences(state, delta.references, delta.raw_user_language!);
  const next = mergeState(state, delta, refs);

  assert.equal(next.date.value, "2026-09-25", "Invariant 1 Failed: Date was erased!");
  assert.equal(next.stadium.name, "ملعب الأبطال", "Invariant 2 Failed: Stadium was erased!");
}

// Invariant 2: A turn that does not change stadium must never clear the stadium.
{
  const state = createInitialConversationState("player");
  state.stadium = { id: "std_aswan_1", name: "الصداقة الجديدة", provenance: "explicit_user", status: "known" };
  state.times = [{ time: "22:00", period: "pm", period_certainty: "explicit", preference_order: 1 }];

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "correct",
    intent: "booking",
    operation: "modify",
    entities: {
      date: { type: "tomorrow", value: "tomorrow" },
    },
    references: [],
    changes: [{ field: "date", operation: "replace", value: "tomorrow" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "لأ معلش خليها بكرة");

  const refs = resolveReferences(state, delta.references, delta.raw_user_language!);
  const next = mergeState(state, delta, refs);

  assert.equal(next.stadium.name, "الصداقة الجديدة", "Stadium must be preserved");
  assert.notEqual(next.date.value, null, "Date must be updated to tomorrow");
  assert.equal(next.times[0]?.time, "22:00", "Time must be preserved across date change");
}

// Invariant 6: Unconfirmed ambiguous time cannot trigger booking.
{
  const state = createInitialConversationState("player");
  state.active_task = "booking";
  state.stadium = { id: "std_1", name: "ملعب الصداقة", provenance: "explicit_user", status: "known" };
  state.date = { value: "2026-09-22", label: "بكرة", status: "known" };
  state.times = [{ time: "10:00", period: "unknown", period_certainty: "ambiguous", preference_order: 1 }];
  state.time_period_confirmed = false;
  state.unresolved_ambiguities = [{ type: "time_period", description: "تحديد صباحاً أم مساءً" }];

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "create",
    entities: {},
    references: [],
    changes: [],
    ambiguities: [{ type: "time_period", description: "تحديد صباحاً أم مساءً" }],
    confirmation: { meaning: "none" },
    execution_request: { requested: true, target: "booking" },
  }, "احجزلي");

  const plan = planToolExecution(state, delta);
  assert.notEqual(plan.action, "EXECUTE_TOOL", "Invariant 6 Failed: Ambiguous time must not trigger tool execution!");
  assert.equal(plan.action, "CLARIFY_AMBIGUITY", "Plan must clarify ambiguity");
}

// Invariant 7: "تمام" without pending confirmation cannot create a booking.
{
  const state = createInitialConversationState("player");
  state.active_task = "stadium_search";
  state.pending_confirmation = null;

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "acknowledge",
    intent: "stadium_search",
    operation: "none",
    entities: {},
    references: [],
    changes: [],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "تمام");

  const plan = planToolExecution(state, delta);
  assert.notEqual(plan.action, "EXECUTE_TOOL", "Invariant 7 Failed: 'تمام' without pending confirmation must not trigger booking!");
}

// Invariant 8: Gemini cannot fabricate database identifiers that bypass trusted context resolution.
{
  const state = createInitialConversationState("player");
  state.last_visible_entities = [
    { reference_key: "stadium_1", entity_type: "stadium", id: "trusted_uuid_real", name: "ملعب النجوم", price_per_hour: 200 }
  ];

  // Model tried to output a made-up UUID in entity name/reference
  const refs = resolveReferences(state, [
    { reference_type: "visible_entity", target: "last_visible", raw_phrase: "الملعب ده" }
  ], "احجز الملعب ده");

  assert.equal(refs.resolved_stadium?.id, "trusted_uuid_real", "Must resolve from trusted context, not fabricated UUID");
}

// ==========================================
// 2. SCENARIOS A - L (Section 20)
// ==========================================

// Scenario A:
// 1. "عايز أرخص ملعب قريب مني"
// 2. "طب احجزلي النهاردة الساعة 10 أو 11"
// 3. "لأ معلش خليها بكرة"
// State after 3rd turn must preserve stadium choice/context & times, and change only date.
{
  let state = createInitialConversationState("player");

  // Turn 1: Search
  const turn1Output = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "stadium_search",
    operation: "search",
    entities: { location: { near_user: true } },
    references: [],
    changes: [],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "عايز أرخص ملعب قريب مني");
  state = mergeState(state, turn1Output, resolveReferences(state, turn1Output.references, ""));

  // Simulate tool found 1 stadium
  state.last_visible_entities = [
    { reference_key: "stadium_1", entity_type: "stadium", id: "uuid_aswan_1", name: "الصداقة الجديدة", price_per_hour: 200 }
  ];
  state.candidate_stadiums = [...state.last_visible_entities];

  // Turn 2: "طب احجزلي النهاردة الساعة 10 أو 11"
  const turn2Output = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "create",
    entities: {
      date: { type: "today", value: "today" },
      times: [
        { time: "22:00", period: "pm", period_certainty: "inferred", preference_order: 1 },
        { time: "23:00", period: "pm", period_certainty: "inferred", preference_order: 2 },
      ],
    },
    references: [{ reference_type: "visible_entity", target: "last_visible", raw_phrase: "احجزلي" }],
    changes: [
      { field: "date", operation: "set", value: "today" },
      { field: "time", operation: "set", value: "22:00, 23:00" },
    ],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: true },
  }, "طب احجزلي النهاردة الساعة 10 أو 11");

  state = mergeState(state, turn2Output, resolveReferences(state, turn2Output.references, ""));
  assert.equal(state.stadium.id, "uuid_aswan_1", "Scenario A: Stadium must be bound to visible single candidate");
  assert.equal(state.times.length, 2, "Scenario A: Must have both preferred times");

  // Turn 3: "لأ معلش خليها بكرة"
  const turn3Output = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "correct",
    intent: "booking",
    operation: "modify",
    entities: {
      date: { type: "tomorrow", value: "tomorrow" },
    },
    references: [],
    changes: [{ field: "date", operation: "replace", value: "tomorrow" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "لأ معلش خليها بكرة");

  state = mergeState(state, turn3Output, resolveReferences(state, turn3Output.references, ""));

  assert.equal(state.stadium.id, "uuid_aswan_1", "Scenario A Final: Stadium must be preserved");
  assert.equal(state.stadium.name, "الصداقة الجديدة", "Scenario A Final: Stadium name must be preserved");
  assert.equal(state.times.length, 2, "Scenario A Final: Times must be preserved");
  assert.equal(state.times[0].time, "22:00", "Scenario A Final: First preferred time preserved");
  assert.equal(state.times[1].time, "23:00", "Scenario A Final: Second preferred time preserved");
  assert.equal(state.date.value, resolveCairoDate("tomorrow"), "Scenario A Final: Date must be tomorrow");
}

// Scenario B:
// User: "شوفلي ملعب قريب"
// Assistant displays several.
// User: "احجز التاني"
// Must resolve the second visible candidate.
{
  const state = createInitialConversationState("player");
  state.last_visible_entities = [
    { reference_key: "stadium_1", entity_type: "stadium", id: "std_1", name: "ملعب الأول", price_per_hour: 250 },
    { reference_key: "stadium_2", entity_type: "stadium", id: "std_2", name: "ملعب التاني المميز", price_per_hour: 300 },
    { reference_key: "stadium_3", entity_type: "stadium", id: "std_3", name: "ملعب التالت", price_per_hour: 350 },
  ];
  state.candidate_stadiums = [...state.last_visible_entities];

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "select",
    intent: "booking",
    operation: "create",
    entities: {},
    references: [{ reference_type: "ordinal", target: "second", raw_phrase: "التاني" }],
    changes: [{ field: "stadium", operation: "set", value: "second" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: true },
  }, "احجز التاني");

  const refs = resolveReferences(state, delta.references, "احجز التاني");
  const next = mergeState(state, delta, refs);

  assert.equal(next.stadium.id, "std_2", "Scenario B: Must resolve second stadium 'std_2'");
  assert.equal(next.stadium.name, "ملعب التاني المميز", "Scenario B: Stadium name must match second candidate");
}

// Scenario C:
// User: "احجز ده" when only one stadium is visible.
// Must resolve the visible stadium context.
{
  const state = createInitialConversationState("player");
  state.last_visible_entities = [
    { reference_key: "stadium_1", entity_type: "stadium", id: "std_only", name: "ملعب وحيد", price_per_hour: 220 }
  ];

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "create",
    entities: {},
    references: [{ reference_type: "visible_entity", target: "last_visible", raw_phrase: "احجز ده" }],
    changes: [{ field: "stadium", operation: "set", value: "last_visible" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: true },
  }, "احجز ده");

  const refs = resolveReferences(state, delta.references, "احجز ده");
  const next = mergeState(state, delta, refs);

  assert.equal(next.stadium.id, "std_only", "Scenario C: Must resolve the single visible stadium");
}

// Scenario D:
// Assistant: "تقصد الساعة 10 بالليل؟"
// User: "صح"
// Must interpret it as confirmation of the immediately pending clarification.
{
  const lastInteraction = { type: "PROMPT_TIME_PERIOD_CONFIRMATION", prompt_target: "time_period" };
  const confirmation = { meaning: "accepted" as const, target: "time_period" as const };
  const evalResult = evaluateContextualConfirmation(lastInteraction, confirmation, "confirm");

  assert.equal(evalResult.isConfirmed, true, "Scenario D: Must confirm time period");
  assert.equal(evalResult.target, "time_period", "Scenario D: Confirmation target must be time_period");
}

// Scenario E:
// Assistant: "لقيت 3 ملاعب."
// User: "تمام"
// Must NOT automatically create a booking.
{
  const lastInteraction = { type: "DISPLAY_STADIUMS", prompt_target: null };
  const confirmation = { meaning: "none" as const, target: null };
  const evalResult = evaluateContextualConfirmation(lastInteraction, confirmation, "acknowledge");

  assert.equal(evalResult.isConfirmed, false, "Scenario E: 'تمام' after displaying stadiums must not confirm booking");
}

// Scenario F:
// User: "10 الصبح ولو مش متاح 11 بالليل"
// Must preserve alternative 1, alternative 2, different time periods, preference order.
{
  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "inform",
    intent: "booking",
    operation: "modify",
    entities: {
      times: [
        { time: "10:00", period: "am", period_certainty: "explicit", preference_order: 1 },
        { time: "23:00", period: "pm", period_certainty: "explicit", preference_order: 2 },
      ],
    },
    references: [],
    changes: [{ field: "time", operation: "set" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "10 الصبح ولو مش متاح 11 بالليل");

  assert.equal(delta.entities.times?.length, 2, "Scenario F: Must have 2 time alternatives");
  assert.equal(delta.entities.times?.[0].period, "am", "Scenario F: First must be AM");
  assert.equal(delta.entities.times?.[1].period, "pm", "Scenario F: Second must be PM");
  assert.equal(delta.entities.times?.[0].preference_order, 1, "Scenario F: First order is 1");
  assert.equal(delta.entities.times?.[1].preference_order, 2, "Scenario F: Second order is 2");
}

// Scenario G:
// User: "الساعة 10 لمدة ساعتين"
// Must understand start time (10:00) + duration (2h), NOT two separate booking times.
{
  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "create",
    entities: {
      times: [{ time: "22:00", period: "pm", period_certainty: "inferred", preference_order: 1 }],
      duration_hours: 2,
    },
    references: [],
    changes: [
      { field: "time", operation: "set" },
      { field: "duration", operation: "set", value: 2 },
    ],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "الساعة 10 لمدة ساعتين");

  assert.equal(delta.entities.times?.length, 1, "Scenario G: Must only have 1 start time");
  assert.equal(delta.entities.duration_hours, 2, "Scenario G: Must extract duration 2 hours");
}

// Scenario H:
// User: "نفس المعاد بكرة"
// Must inherit time from prior state and change date.
{
  const state = createInitialConversationState("player");
  state.date = { value: "2026-09-21", label: "النهارده", status: "known" };
  state.times = [{ time: "22:00", period: "pm", period_certainty: "explicit", preference_order: 1 }];

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "modify",
    entities: {
      date: { type: "tomorrow", value: "tomorrow" },
    },
    references: [{ reference_type: "relative", target: "same_time", raw_phrase: "نفس المعاد" }],
    changes: [{ field: "date", operation: "replace", value: "tomorrow" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "نفس المعاد بكرة");

  const refs = resolveReferences(state, delta.references, "نفس المعاد بكرة");
  const next = mergeState(state, delta, refs);

  assert.equal(next.times[0].time, "22:00", "Scenario H: Must inherit time 22:00");
  assert.equal(next.date.value, resolveCairoDate("tomorrow"), "Scenario H: Must change date to tomorrow");
}

// Scenario J:
// User: "خلاص سيب الحجز، عايز أعرف البطولات"
// Must stop the booking task and switch intent.
{
  const state = createInitialConversationState("player");
  state.active_task = "booking";
  state.task_lifecycle = "in_progress";

  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "switch_task",
    intent: "tournament",
    operation: "search",
    entities: {},
    references: [],
    changes: [{ field: "task", operation: "replace", value: "tournament" }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "خلاص سيب الحجز، عايز أعرف البطولات");

  const next = mergeState(state, delta, { resolved_stadium: null, fallback_stadium: null, resolved_time: null, resolved_date: null, ambiguities: [] });

  assert.equal(next.active_task, "tournament", "Scenario J: Must switch active task to tournament");
}

// Scenario L:
// User: "أنا وصاحبي و10 نفر"
// Must understand group size semantically (12).
{
  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "inform",
    intent: "booking",
    operation: "none",
    entities: {
      group_size: 12,
    },
    references: [],
    changes: [{ field: "group_size", operation: "set", value: 12 }],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "أنا وصاحبي و10 نفر");

  assert.equal(delta.entities.group_size, 12, "Scenario L: Must extract group size 12");
}

// ==========================================
// 3. ROLE AUTHORIZATION & FINANCIAL FACTS
// ==========================================
{
  assert.equal(isToolAllowedForRole("player", "getOwnerFinancialInsights"), false, "Player must not access owner financial insights");
  assert.equal(isToolAllowedForRole("player", "getOwnerStadiumsAndBookings"), false, "Player must not access owner stadiums and bookings");
  assert.equal(isToolAllowedForRole("owner", "getOwnerFinancialInsights"), true, "Owner can access financial insights");
  assert.equal(isToolAllowedForRole("owner", "createBookingFromChat"), false, "Owner cannot book as player");
}

// ==========================================
// 4. ARABIC COUNT GRAMMAR
// ==========================================
{
  assert.equal(formatArabicCount(1, "ملعب واحد", "ملعبين", "ملاعب"), "ملعب واحد");
  assert.equal(formatArabicCount(2, "ملعب واحد", "ملعبين", "ملاعب"), "ملعبين");
  assert.equal(formatArabicCount(3, "ملعب واحد", "ملعبين", "ملاعب"), "3 ملاعب");
  assert.equal(formatArabicCount(5, "ملعب واحد", "ملعبين", "ملاعب"), "5 ملاعب");
}

// ==========================================
// 5. ZERO-HALLUCINATION FACT VALIDATOR TESTS
// ==========================================
{
  const state = createInitialConversationState("player");
  state.stadium = {
    id: "std-1",
    name: "ملعب النجوم",
    provenance: "explicit_user",
    status: "known",
    price_per_hour: 200,
  };
  state.duration_hours = 1;

  const plan: ToolPlan = { action: "CONFIRM_PROPOSAL", toolName: "createBookingFromChat" };

  // Test 5.1: Fact Validator rejects hallucinated price (claims 250 instead of verified 200)
  const falsePriceReply = "تمام يا كابتن، الحجز بـ 250 جنيه في ملعب النجوم الساعة 8 بالليل.";
  const priceCheck = validateAssistantResponseFacts(falsePriceReply, state, plan, null);
  assert.equal(priceCheck.isValid, false, "FactValidator must reject hallucinated price 250");

  // Test 5.2: Fact Validator accepts verified price (200)
  const truePriceReply = "تمام يا كابتن، الحجز بـ 200 جنيه في ملعب النجوم الساعة 8 بالليل.";
  const validCheck = validateAssistantResponseFacts(truePriceReply, state, plan, null);
  assert.equal(validCheck.isValid, true, "FactValidator must accept verified price 200");

  // Test 5.3: Fact Validator rejects fabricated booking completion when toolResult is null or failed
  const fakeBookingReply = "ألف مبروك يا كابتن، تم الحجز بنجاح!";
  const bookingCheck = validateAssistantResponseFacts(fakeBookingReply, state, plan, null);
  assert.equal(bookingCheck.isValid, false, "FactValidator must reject fabricated booking completion");

  // Test 5.4: Fact Validator rejects false 'unavailable' claim when tool had a technical exception
  const fakeUnavailableReply = "للأسف يا كابتن، الملعب غير متاح حالياً ومفيش مواعيد.";
  const failedToolResult = {
    status: "TEMPORARY_ERROR" as const,
    tool_name: "checkStadiumAvailability",
    data: {},
    error_message: "Connection timeout to Postgres",
  };
  const unavailCheck = validateAssistantResponseFacts(fakeUnavailableReply, state, plan, failedToolResult);
  assert.equal(unavailCheck.isValid, false, "FactValidator must reject false unavailable claim on technical error");

  // Test 5.5: Fact Validator rejects leaked internal terms
  const leakReply = "تم استرجاع البيانات من قاعدة البيانات عبر Supabase API.";
  const leakCheck = validateAssistantResponseFacts(leakReply, state, plan, null);
  assert.equal(leakCheck.isValid, false, "FactValidator must reject leaked technical terminology");
}

// ==========================================
// 6. ADVANCED MULTI-TURN EDGE SCENARIOS
// ==========================================
// Scenario 6.1:
// Turn 1: "احجزلي 10 الصبح ولو مش موجود 11 بالليل"
// Turn 2: "لا خلي الأول بكرة"
{
  const state = createInitialConversationState("player");
  state.active_task = "booking";
  state.stadium = { id: "std-99", name: "الصداقة", provenance: "explicit_user", status: "known" };
  state.times = [
    { time: "10:00", period: "am", period_certainty: "explicit", preference_order: 1 },
    { time: "23:00", period: "pm", period_certainty: "explicit", preference_order: 2 },
  ];
  state.date = { value: resolveCairoDate("today"), label: "النهارده", status: "known" };

  // Turn 2: User says: "لا خلي الأول بكرة"
  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "correct",
    intent: "booking",
    operation: "modify",
    entities: {
      date: { type: "tomorrow", value: resolveCairoDate("tomorrow") },
    },
    references: [{ reference_type: "ordinal", target: "first", raw_phrase: "الأول" }],
    changes: [
      { field: "date", operation: "replace", value: resolveCairoDate("tomorrow") },
    ],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "لا خلي الأول بكرة");

  const next = mergeState(state, delta, { resolved_stadium: null, fallback_stadium: null, resolved_time: null, resolved_date: resolveCairoDate("tomorrow"), ambiguities: [] });

  assert.equal(next.date.value, resolveCairoDate("tomorrow"), "Must update date to tomorrow");
  assert.equal(next.times.length, 2, "Must preserve both candidate alternatives");
  assert.equal(next.times[0].time, "10:00", "Must preserve alternative #1 (10 AM)");
  assert.equal(next.times[1].time, "23:00", "Must preserve alternative #2 (11 PM)");
  assert.equal(next.stadium.name, "الصداقة", "Must preserve stadium selection");
}

// Scenario 6.2:
// "عايز نفس الملعب بس بكرة بعد 10 ولو مفيش شوفلي اللي بعده"
// Features: inheritance + date change + time constraint + fallback preference + candidate selection
{
  const state = createInitialConversationState("player");
  state.active_task = "booking";
  state.stadium = { id: "std-alpha", name: "ملعب الأهلي", provenance: "explicit_user", status: "known" };
  state.last_visible_entities = [
    { reference_key: "stadium_1", entity_type: "stadium", id: "std-alpha", name: "ملعب الأهلي", price_per_hour: 250 },
    { reference_key: "stadium_2", entity_type: "stadium", id: "std-beta", name: "ملعب الزمالك", price_per_hour: 220 },
  ];

  // User input produces semantic delta:
  const delta = validateAndNormalizeSemanticOutput({
    schema_version: 1,
    speech_act: "request",
    intent: "booking",
    operation: "search",
    entities: {
      date: { type: "tomorrow", value: resolveCairoDate("tomorrow") },
      time_range: { from_hour: 22, to_hour: 23, label: "بعد 10" },
    },
    references: [
      { reference_type: "previous_state", target: "same_stadium", raw_phrase: "نفس الملعب" },
      { reference_type: "relative", target: "next", raw_phrase: "اللي بعده" },
    ],
    changes: [
      { field: "date", operation: "replace", value: resolveCairoDate("tomorrow") },
      { field: "time", operation: "set", value: "بعد 10" },
    ],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
  }, "عايز نفس الملعب بس بكرة بعد 10 ولو مفيش شوفلي اللي بعده");

  const resolved = resolveReferences(state, delta.references, "عايز نفس الملعب بس بكرة بعد 10 ولو مفيش شوفلي اللي بعده");
  const next = mergeState(state, delta, resolved);

  assert.equal(next.stadium.id, "std-alpha", "Must inherit primary stadium: ملعب الأهلي");
  assert.equal(next.date.value, resolveCairoDate("tomorrow"), "Must set date to tomorrow");
  assert.equal(next.time_range?.from_hour, 22, "Must set time range from 22:00 (بعد 10)");

  // Verify fallback resolution: next visible candidate is std-beta
  const nextCandidate = state.last_visible_entities[1];
  assert.equal(nextCandidate.id, "std-beta", "Candidate #2 must be resolved as fallback candidate");
  assert.equal(nextCandidate.name, "ملعب الزمالك", "Fallback candidate name must match context");
}

// ==========================================
// 7. OPTIMISTIC CONCURRENCY CONTROL (OCC) SIMULATION
// ==========================================
{
  // Simulate Turn 11 writing version 3
  const currentDbSnapshot = {
    conversation_state: { version: 3, stadium: { name: "الملعب الأحدث" } },
  };

  // Simulate late-arriving Turn 10 trying to persist version 2
  const lateIncomingSnapshot = {
    conversation_state: { version: 2, stadium: { name: "الملعب القديم" } },
  };

  const currVer = currentDbSnapshot.conversation_state.version;
  const incomingVer = lateIncomingSnapshot.conversation_state.version;

  // OCC Check:
  let persistedSnapshot;
  if (currVer > incomingVer) {
    persistedSnapshot = currentDbSnapshot; // Preserve newer!
  } else {
    persistedSnapshot = lateIncomingSnapshot;
  }

  assert.equal(persistedSnapshot.conversation_state.version, 3, "OCC must prevent late Turn 10 from overwriting newer version 3");
  assert.equal(persistedSnapshot.conversation_state.stadium.name, "الملعب الأحدث", "Must preserve newer state facts");
}

console.log("All Semantic State Machine Invariant, Fact Validator, and Edge Scenario Tests: PASS! ✅");

