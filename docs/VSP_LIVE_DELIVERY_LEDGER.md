# VSP — Live delivery ledger

Updated 2026-11-08. This ledger is the source of truth for **execution progress**, distinct from final release verification.

## Fixed scope and accounting

- Baseline: **82 parent items, 620 subtasks** from `VSP_80_DETAILED_SUBTASK_BREAKDOWN.md`. Never silently increase this denominator.
- Current inventory: **24 documented as completed; 596 not yet accepted**. This is NOT a claim that all 597 are untouched.
- Each task has exactly one state: `TODO`, `IN_PROGRESS`, `CODE_DONE`, `VERIFIED`, `BLOCKED`. Only `VERIFIED` reduces the final-release remaining count; `CODE_DONE` increases the visible implementation counter.
- A commit is **not** a task. Multiple commits fixing the same behavior count as one candidate implementation. Unmapped bug fixes are logged as **defects**, not new baseline tasks.
- New scope requires a separate `CHANGE_REQUEST` with rationale, acceptance criteria and owner approval before adding to the denominator.
- Each batch must publish: baseline total, verified, code-done-awaiting-verification, untouched/in-progress, blocked, new defects, and commit links. No unsubstantiated estimates or completion dates.
- Do not claim a task is `CODE_DONE` unless its full acceptance scope is implemented; partial work stays `IN_PROGRESS`.
- No `main` merge or production DB/payment/permission changes without the agreed release gates and approvals.

## Closed task register

| Task ID | State | Evidence | Scope |
|---|---|---|---|
| 27.01 | VERIFIED (documentation deliverable) | [Booking status inventory](VSP_BOOKING_STATUS_INVENTORY_27_01.md), commit `4ece7f6` | All declared Dart booking states and mapper normalization inventoried; backend behavior remains under 27.02–27.08 |

**Current audited counter: 24 / 620 completed, 596 remaining.** One newly closed task in this batch; existing 23 baseline completions remain unchanged. A documentation task can close with reviewed source evidence; runtime tasks require their own acceptance evidence.

## Existing implementation evidence — not yet full-task completion

| Task ID | State | Concrete evidence | Outstanding acceptance |
|---|---|---|---|
| 22.04 | IN_PROGRESS | BookingSlotCalculator excludes configured closure intervals and rejects invalid closure schedules: `6e3f60f`, `f937035`, `25644ce` | Confirm all booking entry points, server enforcement, holidays and real-device behavior |
| 22.07 | IN_PROGRESS | Overnight booking date computation: `3c717eb`; slot time range guard: `79c8858` | DST boundaries and device acceptance tests |
| 26.05 | IN_PROGRESS | Client availability filter ignores cancelled/expired bookings: `cb7dd106` | Confirm server re-availability and race safety |
| 26.06 | IN_PROGRESS | UTC overlap comparison and overnight date correction: `3c717eb` | Timezone tests and server checks |
| 51.01–51.07 | TODO | Booking selection safety fixes: `3545c78`, `d27e671`, `654bcd9` | Map to individual conversion subtasks only after examining their acceptance definitions |

## Unmapped defects repaired (not extra subtasks)

| Defect | Evidence | Status |
|---|---|---|
| Shared time parser syntax corruption | `a1139f3` | CODE_CHANGED; compile not yet checked |
| Duplicate/trailing formatter source | `6336135` | CODE_CHANGED; compile not yet checked |
| Owner split-shift schedule input parsing | `04c7935` | CODE_CHANGED; UI acceptance pending |

## Next execution queue

1. 22 — operating hours/closures: finish one end-to-end owner-to-player scheduling flow.
2. 26 — booking overlap prevention: inspect server guarantees; do not change production schema without approval.
3. 03 — error/empty/retry states, then 16 — booking history.
4. 81–82 — team achievement badges and challenge consent code.
5. 56–60 — consolidated tests, security, release verification **at the end**.

Do not use the old `80-item` release tracker as the denominator for the 82-item/620-subtask inventory.
