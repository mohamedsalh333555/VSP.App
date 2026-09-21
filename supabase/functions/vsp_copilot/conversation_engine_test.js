import assert from "node:assert/strict";
import {
  analyzeCopilotTurn,
  mergeConversationState,
  buildDialogueDecision,
  extractPreferredTimes,
  extractGroupSize,
  isBookingHowTo,
} from "./conversation_engine.js";

const rows = [
  ["عايزه احجز ملعب قريب مني انا وعشر اشخاص", 11, [], "book_stadium"],
  ["عايز ملعب قريب مني انا و10 نفر", 11, [], "search_stadiums"],
  ["الساعة 10", null, ["10:00"], null],
  ["10 نفر", 10, [], null],
  ["10 بالليل", null, ["22:00"], null],
  ["10 م", null, ["22:00"], null],
  ["10 ص", null, ["10:00"], null],
  ["10 أو 11 بالليل", null, ["22:00","23:00"], null],
  ["الساعة عشرة بالليل", null, ["22:00"], null],
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

let ctx = {task_state:{}};
let a = analyzeCopilotTurn("عايزه احجز ملعب قريب مني انا وعشر اشخاص", ctx);
let s = mergeConversationState(ctx, a);
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
assert.equal(extractGroupSize("انا وعشر اشخاص النهارده بالليل"), 11);

console.log("conversation_engine_test: PASS");
