import assert from "node:assert/strict";
import {
  analyzeCopilotTurn,
  mergeConversationState,
  buildDialogueDecision,
  buildResponseContract,
  extractPreferredTimes,
  extractGroupSize,
  isBookingHowTo,
} from "./conversation_engine.js";

const rows = [
  ["عايزه احجز ملعب قريب مني انا وعشر اشخاص", 11, [], "book_stadium"],
  ["عايز ملعب قريب مني انا و10 نفر", 11, [], "search_stadiums"],
  ["الساعة 10", null, ["22:00"], null],
  ["10 نفر", 10, [], null],
  ["10 بالليل", null, ["22:00"], null],
  ["10 م", null, ["22:00"], null],
  ["10 ص", null, ["10:00"], null],
  ["10 أو 11 بالليل", null, ["22:00","23:00"], null],
  ["الساعة عشرة بالليل", null, ["22:00"], null],
  ["الساعة 10:00 11:00", null, ["22:00","23:00"], null],
];

for (const [input, group, times, intent] of rows) {
  const a = analyzeCopilotTurn(input, {});
  assert.equal(a.entities.group_size, group, input);
  assert.deepEqual(a.entities.preferred_times, times, input);
  if (intent) assert.equal(a.intent, intent, input);
}

assert.equal(isBookingHowTo("ازاي احجز"), true);
assert.equal(analyzeCopilotTurn("ازاي احجز", {}).intent, "booking_howto");
assert.equal(analyzeCopilotTurn("ممكن تحجزلي النهارده الساعة 10", {}).intent, "book_stadium");

const visibleStadium = {
  id: "stadium-1",
  name: "ملعب الصداقة الجديدة",
};
let ctx = {
  last_visible_stadiums: [visibleStadium],
  task_state: {},
};

let a = analyzeCopilotTurn(
  "طب عايزك تحجز لي دلوقتي النهارده الساعه 10:00 11:00",
  ctx,
);
assert.equal(a.intent, "book_stadium");
assert.equal(a.entities.date_token, "today");
assert.deepEqual(a.entities.preferred_times, ["22:00", "23:00"]);
assert.deepEqual(a.entities.stadium_reference, {
  id: "stadium-1",
  name: "ملعب الصداقة الجديدة",
});
assert.ok(a.ambiguities.includes("time_period"));

let s = mergeConversationState(ctx, a);
assert.equal(s.intent, "book_stadium");
assert.equal(s.stadium_id, "stadium-1");
assert.equal(s.stadium_name, "ملعب الصداقة الجديدة");
assert.deepEqual(s.preferred_times, ["22:00", "23:00"]);
assert.ok(s.missing_slots.includes("time_period"));
assert.equal(s.ready_for_execution, false);
assert.equal(buildDialogueDecision(s, a).next_slot, "time_period");

const contract = buildResponseContract(s, buildDialogueDecision(s, a), a);
assert.equal(contract.facts.time_period_candidate, "evening");
assert.deepEqual(contract.quick_replies, ["بالليل", "الصبح"]);

// "صح" confirms the previously inferred period; it must not erase 10/11 or ask for the hour again.
a = analyzeCopilotTurn("صح", ctx);
assert.equal(a.entities.confirmation, true);
s = mergeConversationState(ctx, a);
assert.deepEqual(s.preferred_times, ["22:00", "23:00"]);
assert.deepEqual(s.missing_slots, []);
assert.equal(s.time_period_confirmed, true);
assert.equal(s.ready_for_execution, true);
assert.equal(buildDialogueDecision(s, a).type, "CHECK_AVAILABILITY");

ctx = {
  last_visible_stadiums: [visibleStadium],
  task_state: {},
};
a = analyzeCopilotTurn("عايزك تحجز لي النهارده الساعة 10:00 11:00", ctx);
s = mergeConversationState(ctx, a);
a = analyzeCopilotTurn("مظبوط", ctx);
s = mergeConversationState(ctx, a);
assert.equal(s.time_period_confirmed, true);
assert.deepEqual(s.preferred_times, ["22:00", "23:00"]);
assert.equal(s.ready_for_execution, true);

ctx = {task_state:{}};
a = analyzeCopilotTurn("عايزه احجز ملعب قريب مني انا وعشر اشخاص", ctx);
s = mergeConversationState(ctx, a);
assert.equal(s.intent, "book_stadium");
assert.equal(s.group_size, 11);
assert.equal(s.stadium_scope, "nearby");
assert.deepEqual(s.missing_slots, ["date","time"]);
assert.equal(buildDialogueDecision(s, a).next_slot, "date");

a = analyzeCopilotTurn("النهارده الساعة 10", ctx);
s = mergeConversationState(ctx, a);
assert.deepEqual(s.missing_slots, ["time_period"]);
assert.equal(buildDialogueDecision(s, a).next_slot, "time_period");

a = analyzeCopilotTurn("10 بالليل", ctx);
s = mergeConversationState(ctx, a);
assert.deepEqual(s.missing_slots, []);
assert.equal(s.ready_for_execution, false);
assert.equal(buildDialogueDecision(s, a).type, "SEARCH_AND_CHECK");

ctx = {task_state:{intent:"book_stadium",confirmation_pending:{stadium_id:"x"}}};
a = analyzeCopilotTurn("ازاي احجز", ctx);
s = mergeConversationState(ctx, a);
assert.equal(s.intent, "booking_howto");
assert.equal(s.confirmation_pending, undefined);

assert.deepEqual(extractPreferredTimes("انا وعشر اشخاص النهارده بالليل"), []);
assert.deepEqual(extractPreferredTimes("10 م"), ["22:00"]);
assert.deepEqual(extractPreferredTimes("10 ص"), ["10:00"]);
assert.deepEqual(extractPreferredTimes("الساعة 10:00 11:00"), ["22:00","23:00"]);
assert.equal(extractGroupSize("انا وعشر اشخاص النهارده بالليل"), 11);

console.log("conversation_engine_test: PASS");
