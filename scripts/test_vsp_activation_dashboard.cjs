"use strict";
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { runInNewContext } = require("node:vm");
const { test } = require("node:test");
const { join } = require("node:path");

const html = readFileSync(join(__dirname, "vsp_activation_dashboard.html"), "utf8");
const match = html.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(match, "The offline dashboard must contain a locally auditable script");
assert.doesNotMatch(html, /<script[^>]+src=/i, "External scripts are forbidden");
assert.doesNotMatch(match[1], /\b(?:fetch|XMLHttpRequest|sendBeacon)\s*\(/,
  "The offline dashboard must not send analytics data anywhere");

class Element {
  constructor(tag = "div") {
    this.tag = tag;
    this.children = [];
    this.textContent = "";
    this.hidden = false;
    this.value = "";
    this.files = null;
    this.listeners = Object.create(null);
  }
  appendChild(item) { this.children.push(item); return item; }
  replaceChildren(...items) { this.children = items; this.textContent = ""; }
  addEventListener(event, callback) { this.listeners[event] = callback; }
}

function harness() {
  const ids = ["report", "status", "results", "funnels", "cohorts", "clear"];
  const elements = Object.fromEntries(ids.map(id => [id, new Element(id)]));
  const document = {
    getElementById: (id) => {
      assert.ok(Object.hasOwn(elements, id), "Unexpected DOM element: " + id);
      return elements[id];
    },
    createElement: (tag) => new Element(tag),
  };
  runInNewContext(match[1], { document }, { timeout: 1500 });
  const visible = (node) =>
    [node.textContent, ...node.children.map(visible)].join(" ");
  async function load(value) {
    const source = JSON.stringify(value);
    elements.report.files = [{ size: Buffer.byteLength(source), text: async () => source }];
    await elements.report.listeners.change();
    return {
      message: elements.status.textContent,
      hidden: elements.results.hidden,
      display: visible(elements.results).concat(
        " ", visible(elements.funnels), " ", visible(elements.cohorts)),
    };
  }
  return { load, elements };
}

function funnel(counts, dropOffs, rates) {
  const names = [
    "app_opened", "signup_completed", "venue_viewed",
    "booking_started", "booking_completed",
  ];
  return {
    journey: "player_booking",
    role: "player",
    observedThroughUtc: "2026-11-17T00:00:00.000Z",
    stages: names.map((event, index) => ({
      event, accounts: counts[index],
      dropOffFromPrevious: dropOffs[index],
      conversionFromPrevious: rates[index],
    })),
  };
}

test("valid aggregate funnel renders no raw account data", async () => {
  const page = harness();
  const report = funnel(
    [10, 10, 10, 10, 5], [null, 0, 0, 0, 5],
    [null, 1, 1, 1, 0.5],
  );
  const result = await page.load(report);
  assert.equal(result.hidden, false);
  assert.match(result.display, /تأكيد الحجز/);
  assert.match(result.display, /50\.0%/);
  assert.doesNotMatch(result.display, /accountKey|user_id/);
  page.elements.clear.listeners.click();
  assert.equal(page.elements.results.hidden, true);
});

test("small adjacent dropout cannot leak by subtracting headline counts", async () => {
  const page = harness();
  const report = funnel(
    [10, 10, 10, 10, 6], [null, 0, 0, 0, null],
    [null, 1, 1, 1, null],
  );
  const result = await page.load(report);
  assert.equal(result.hidden, true);
  assert.match(result.message, /تعذر فتح التقرير/);
});

test("masked funnel remains masked downstream", async () => {
  const result = await harness().load(funnel(
    [10, 10, null, 6, 6], [null, 0, null, null, null],
    [null, 1, null, null, null],
  ));
  assert.equal(result.hidden, true);
});

test("small top-level cohort rejects data rather than displaying it", async () => {
  const result = await harness().load(funnel(
    [4, 4, 4, 4, 0], [null, 0, 0, 0, 4],
    [null, 1, 1, 1, null],
  ));
  assert.equal(result.hidden, true);
});

test("cohort safe export displays suppressed days as hidden", async () => {
  const report = {
    cohorts: [{
      role: "player", firstValueEvent: "booking_completed",
      cohortDayUtc: "2026-11-01T00:00:00.000Z",
      accounts: 10,
      eligibleD1: 10, activeD1: null,
      eligibleD7: 10, activeD7: 0,
      eligibleD30: 0, activeD30: 0,
    }],
  };
  const result = await harness().load(report);
  assert.equal(result.hidden, false);
  assert.match(result.display, /محجوب/);
  assert.match(result.display, /0 \/ 10/);
});

test("cohort refuses complementary disclosure of fewer than five exits", async () => {
  const report = {
    cohorts: [{
      role: "player", firstValueEvent: "booking_completed",
      cohortDayUtc: "2026-11-01T00:00:00.000Z",
      accounts: 10, eligibleD1: 10, activeD1: 6,
      eligibleD7: 0, activeD7: 0, eligibleD30: 0, activeD30: 0,
    }],
  };
  const result = await harness().load(report);
  assert.equal(result.hidden, true);
});

test("viewer refuses a four-person difference between cohort and eligible day", async () => {
  const report = {
    cohorts: [{
      role: "player", firstValueEvent: "booking_completed",
      cohortDayUtc: "2026-11-01T00:00:00.000Z",
      accounts: 10,
      eligibleD1: 6, activeD1: null,
      eligibleD7: null, activeD7: null,
      eligibleD30: null, activeD30: null,
    }],
  };
  const result = await harness().load(report);
  assert.equal(result.hidden, true);
  assert.match(result.message, /تعذر فتح التقرير/);
});

test("viewer rejects exposed later eligibility after an earlier suppressed day", async () => {
  const report = {
    cohorts: [{
      role: "owner", firstValueEvent: "owner_dashboard_viewed",
      cohortDayUtc: "2026-11-01T00:00:00.000Z",
      accounts: 10,
      eligibleD1: null, activeD1: null,
      eligibleD7: 5, activeD7: 0,
      eligibleD30: 0, activeD30: 0,
    }],
  };
  assert.equal((await harness().load(report)).hidden, true);
});

test("viewer rejects a four-person gap between eligible D1 and D7", async () => {
  const report = {
    cohorts: [{
      role: "owner", firstValueEvent: "owner_dashboard_viewed",
      cohortDayUtc: "2026-11-01T00:00:00.000Z",
      accounts: 20,
      eligibleD1: 20, activeD1: 15,
      eligibleD7: 16, activeD7: null,
      eligibleD30: null, activeD30: null,
    }],
  };
  assert.equal((await harness().load(report)).hidden, true);
});

test("invalid JSON and oversized files fail closed", async () => {
  const page = harness();
  page.elements.report.files = [{
    size: 10,
    text: async () => "{invalid",
  }];
  await page.elements.report.listeners.change();
  assert.equal(page.elements.results.hidden, true);
  page.elements.report.files = [{
    size: 1024 * 1024 + 1,
    text: async () => '{"cohorts":[]}',
  }];
  await page.elements.report.listeners.change();
  assert.equal(page.elements.results.hidden, true);
  assert.match(page.elements.status.textContent, /كبير/);
});
