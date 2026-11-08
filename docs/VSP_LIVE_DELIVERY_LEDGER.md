# VSP — Live delivery ledger

Updated 2026-11-08. This ledger is the source of truth for **execution progress**, distinct from final release verification.

## Fixed scope and accounting

- Baseline: **82 parent items, 620 subtasks** from `VSP_80_DETAILED_SUBTASK_BREAKDOWN.md`. Never silently increase this denominator.
- Current inventory: **29 documented as completed; 591 not yet accepted**. This is NOT a claim that all 597 are untouched.
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
| 27.02 | VERIFIED (contract deliverable) | [Transition contract](VSP_BOOKING_TRANSITIONS_27_02.md), commit `f3ddb3d` | Allowed/disallowed edges defined; server enforcement remains under 27.03 |
| 28.01 | VERIFIED (documentation deliverable) | [Booking creation lifecycle](VSP_BOOKING_CREATION_LIFECYCLE_28_01.md), commit `0ec3794` | Lifecycle stages, statuses and follow-on gates defined; runtime enforcement remains separate |
| 29.01 | CODE_DONE (verification deferred) | `lib/core/utils/payment_failure_classifier.dart` `b91cfbc`, test `7625cef` | Payment failure categories and uncertainty flags implemented; integration into payment screens and live verification belong to 29.02–29.08 |
| 28.02 | VERIFIED (documentation deliverable) | [Cancellation cutoffs](VSP_BOOKING_CANCELLATION_CUTOFFS_28_02.md), commit `870a599` | Client-visible 6-hour cutoff and 20-minute grace documented; server boundary verification still open |

**Current audited counter: 29 / 620 completed, 591 remaining.** Tasks 26.07, 27.01, 27.02, 28.01, 28.02 and 29.01 are marked delivered; original 23 baseline completions unchanged. A documentation task can close with reviewed source evidence; runtime tasks require their own acceptance evidence.

## Existing implementation evidence — not yet full-task completion

| Task ID | State | Concrete evidence | Outstanding acceptance |
|---|---|---|---|
| 27.03 | IN_PROGRESS | Shared Dart guard `BookingStatusExtension.canTransitionTo` in `lib/data/models/booking_enums.dart`, commit `034c817` | Wire all client mutation paths, enforce on server and test forbidden transitions |
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

## Batch — 2026-11-08: booking deserialization

| Candidate task | State | Implementation evidence | Remaining acceptance |
|---|---|---|---|
| 27.04 | IN_PROGRESS | Canonical upcoming normalization `f5bea6e`, tolerant result-state parsing `d9aef63` | Compare all server status writers/readers; verify client/server state parity |
| 36.01–36.07 | IN_PROGRESS (partial) | Unknown match outcomes no longer throw in booking mapper `1847042` | End-to-end result lifecycle, deduplication and timing still required |
| 34.01–34.13 | IN_PROGRESS (partial) | Challenge opponent metadata retained for normalized and legacy types `de074bf`, `626cd64` | Challenge invitation lifecycle and server checks remain open |

**Batch accounting:** 5 source commits, 0 fully closed subtasks. No additional scope items; all changes map to existing baseline categories. Current audited count remains **25 completed / 595 remaining / 620 total**. Flutter compilation and integration checks pending.

## Batch — booking data integrity (current turn)

Five code commits in `lib/data/models/booking_mapper.dart`:
- `b41a971`: reject bookings whose end time is not after start time.
- `31f1d42`: normalize hyphenated booking type aliases.
- `4c8744d`: normalize operational date objects to calendar-day values.
- `711d5ab`: reject NaN/infinite monetary values while deserializing.
- `13cee29`: reject non-finite numeric counters and trim numeric strings.

**Progress classification:** these are implementation improvements to booking integrity and legacy data handling, **not** five fully completed baseline subtasks. Tasks 27.04, 28.01, and 62 remain in progress or open until their full acceptance scope is satisfied. No new tasks added. Counter remains **25/620 complete, 595 remaining**. Flutter analyze and end-to-end acceptance deferred.

## Batch — 2026-11-08: lifecycle contract coverage

Added `test/data/models/booking_status_transition_contract_test.dart` covering all enum edges and idempotent repeats (`9d3a25e`, import fix `e8b24f2`). Test is written but **not run**; task 27.05 remains open because backend repeated requests are not covered. No false closure.

## Batch — payment failure classification

Task 29.01 marked code-complete with eight typed failure categories, classification by provider text/HTTP status, and explicit reconciliation-required flags. Tests added but not run. This classifier is not wired into payment flows yet and must never itself authorize a charge. Commit `b91cfbc`, test `7625cef`, counter update `62d3950`.

## Batch — user-facing payment feedback and booking draft validation

- `16fffdad`: Arabic/English safe messages for all `PaymentFailureKind` categories. **29.02 IN_PROGRESS**: presentation helper exists but payment screens are not yet wired.
- `68a4dea`: tests for bilingual feedback (not run).
- `2f5a957`: `BookingDraft.validate()` for required IDs, time order, non-negative finite money, deposit bounds and player capacity. **26/28 IN_PROGRESS**: validation not yet wired to submit path; server is source of truth.
- `b89efbc`: draft validation tests (not run).

**Accounting:** four source/test commits, zero full task closures; baseline remains **27 completed, 593 remaining, 620 total**. No new scope added. Do not count unconnected helper functions as complete UX or server safeguards.

## Batch — 2026-11-08 booking draft safety

- `88b973b`: introduced opt-in `BookingDraft.toValidatedMap()` to reject invalid drafts before serialization. Submission call sites are **not yet migrated**; no claim of enforcement.
- `ee3b602`: added tests for checked serialization; not run.
- `599a29b`: fixed `BookingDraft.fromMap` to parse historical numeric/string player counts and capacities safely rather than assuming `int` values.

**Task accounting:** 3 commits, **0 newly closed subtasks**, **27/620 completed; 593 remaining**. These changes advance booking input robustness but not full 26/28 lifecycle acceptance. No production schema, permissions or payment writes modified.

## Batch — restored booking draft integrity (2026-11-08)

- `19d767b`: `BookingDraft.fromMap` now rejects missing, malformed, or inverted start/end times instead of inventing `DateTime.now()` and a one-hour slot; rejects invalid/non-finite/negative persisted amounts.
- `8c287df`: regression tests for missing/corrupt dates, amounts and legacy player-count strings (written, not executed).
- `95d0884`: restored booking types support snake_case, hyphenated and enum-qualified historical values.
- `9d70a98`: tests for legacy booking type restoration (written, not executed).

**Scope note:** this batch improves restored draft integrity, not server-side booking enforcement, payment reconciliation, or release verification. **0 full tasks closed; 27/620 complete, 593 remain.** Flutter test/analyze deferred per project instruction.

## Batch — actual booking RPC validation and cancellation guard

- `a3e92e3`: `BookingCreationCoordinator.createBooking` calls `draft.validate()` before either `create_booking_atomic` or `create_challenge_booking_atomic` RPC; rejects blank user IDs. Server validation remains mandatory.
- `5fc8a14`: cancellation coordinator handles non-map error results from manual and standard cancellation RPCs without throwing an unrelated map access error.
- `870a599`: cancellation paths, client-visible cutoff and 20-minute grace, and server boundary acceptance criteria documented; **28.02 closed**.
- `09ac5b9`: tracker checkbox updated.

**Accounting:** 1 documentation task closed, **28/620 complete, 592 remaining**. RPC-path code changes are not counted as complete cancellation or payment tasks. No schema or payment transaction implementation changed. Verification deferred.

## Batch — booking idempotency and overlap source evidence

- `f177323`: pass `draft.idempotencyKey` (UUID fallback) to the standard `create_booking_atomic` RPC as already done for challenge creation. Stable replay requires the caller to reuse the same draft key; server enforcement must be verified.
- `cdfa77a`: complete [26.07 overlap evidence](VSP_BOOKING_OVERLAP_EVIDENCE_26_07.md), including latest SQL lock and half-open overlap predicate, source-only marker warning, idempotency and concurrency acceptance matrix. **26.07 closed** (documentation only).
- `ddd1791`: add source-contract tests for both RPC idempotency keys, preflight validation and SQL lock/overlap order (written, not run).
- `6da8303`: validate checkout draft before cleaning up any stale pending bookings, avoiding destructive cleanup for invalid new input.
- `34b1aec`: regression test asserting checkout preflight runs before cleanup and creation (written, not run).
- `e86323a`: checklist updated.

**Accounting: 1 scoped documentation subtask closed; 29/620 completed, 591 remaining.** Other booking concurrency, retry, cancellation and payment subtasks stay open. No production DB schema, payment transaction implementation or permissions changed. Flutter analyze/tests and live concurrency validation deferred.

## Next execution queue

1. 22 — operating hours/closures: finish one end-to-end owner-to-player scheduling flow.
2. 26 — booking overlap prevention: inspect server guarantees; do not change production schema without approval.
3. 03 — error/empty/retry states, then 16 — booking history.
4. 81–82 — team achievement badges and challenge consent code.
5. 56–60 — consolidated tests, security, release verification **at the end**.

Do not use the old `80-item` release tracker as the denominator for the 82-item/620-subtask inventory.
