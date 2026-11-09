# VSP — Live delivery ledger

Updated 2026-11-08. This ledger is the source of truth for **execution progress**, distinct from final release verification.

## Fixed scope and accounting

- Baseline: **82 parent items, 620 subtasks** from `VSP_80_DETAILED_SUBTASK_BREAKDOWN.md`. Never silently increase this denominator.
- Current inventory: **49 documented as completed; 571 not yet accepted**. This is NOT a claim that all 588 remaining tasks are untouched.
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

**Current audited counter: 49 / 620 completed, 571 remaining.** Source-audited inventory/decision tasks 67.01, 67.03, 67.05, 71.01 and 72.01 are now closed in addition to the previously accepted 38; original 23 baseline completions unchanged. A documentation task can close with reviewed source evidence; runtime tasks require their own acceptance evidence.

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

## Batch — RPC response integrity, safe checkout resume, payment authority

- `16e7d2b`: booking creation reads both `code` and legacy `error` from RPC failures, and rejects malformed or explicitly unsuccessful responses before using `booking_id`.
- `f088b34`: checkout fails closed when an explicit existing booking ID cannot be resumed, instead of silently creating a replacement.
- `b8c00f5`: architecture tests for RPC failure and resume guards (written, not executed).
- `41a4552`: [30.01 server payment authority](VSP_PAYMENT_SERVER_SOURCE_OF_TRUTH_30_01.md) documented; browser redirects are not financial proof; webhook, order, and booking reconciliation follow server state. **30.01 closed**.
- `07032bb`: task checklist updated.

**Accounting:** 1 scoped documentation task closed, **30/620 completed, 590 remaining**. Payment webhook runtime and retry behavior, integration tests and server deployments are unverified. No database schema, permissions, payment transaction logic or main branch changed.

## Batch — checkout failure UX, challenge states, refund rules

- Payment gateway screen now uses `PaymentFailureKind` bilingual, reconciliation-safe messages for unknown WebView outcomes and gateway unavailability, and classifies Paymob launch exceptions (`46ac5d4` plus preceding screen commit). **29.02 in progress** until all payment failure surfaces and user journeys are checked.
- `89f1a8c`: source-contract test for payment failure messages (written, not executed).
- `9e4f0e6`: [34.01 challenge status inventory](VSP_CHALLENGE_STATUS_INVENTORY_34_01.md) from checked-in SQL constraint, distinguishing challenge, booking, invitation and result states. **34.01 closed**.
- `27dc7b9`: [31.01 refund rules](VSP_REFUND_RULES_31_01.md) from the server Edge Function: 6-hour cutoff, 20-minute grace, ownership, atomic refund claim, pending/manual-review/duplicate handling. **31.01 closed**.
- `1e6f25e`, `e17c701`: task checklist updates.

**Accounting:** 2 scoped documentation tasks closed, **32/620 completed, 588 remaining**. Client code not live-verified; no schema, payment gateway transaction logic, permissions or main branch changed.

## Batch — Paymob checkout recovery and server reconciliation

- `db4f23c`: recover the payment gateway UI when `requestPaymobCheckoutUrl` throws: cancel webhook timeout, clear loading/awaiting flags and display classified, bilingual feedback. No new charge or payment status write.
- `19f2521`: add architecture regression test for URL request failure recovery (written, not run).
- `9c044cc`: keep server booking-status fallback polling after uncertain WebView closure and launch exceptions, so a successful charge is not missed merely because browser navigation failed.
- `d5b2532`: extend checkout feedback contract test to assert reconciliation polling (written, not run).

**Task accounting:** no complete 29.02/29.05/29.08 task closure yet; **32/620 completed, 588 remaining**. These are real checkout-path fixes but full payment failure journeys, safe retry and server-side reconciliation still need verification. No production schema, gateway transaction logic, permissions or main merge.

## Batch — uncertain Paymob outcome recharge guard

- `baa6d1f`: payment screen refuses a second Paymob checkout while the first gateway outcome is uncertain. The guard is set on WebView dismissal, reconciliation-required launch errors and webhook wait timeout; no server transaction or payment state is altered.
- `f855297`: architecture regression test asserts the uncertainty guard precedes checkout URL creation (written, not run).
- **Accounting:** no full 29.03/29.04 task closure; 32/620 complete, 588 remain. This is a client-side defense in depth only, not a substitute for backend idempotency or live double-charge verification. No schema, payments backend or permissions modified.

## Batch — draft round-trip correctness and payment cleanup safety

- `23989eb`, `af65837`: preserve `isPaid` and `needsDeposit` through `BookingDraft.toMap/fromMap` and extend round-trip unit test. Draft fields are client serialization only, not server payment authority.
- `74cbcb6`, `62c7309`: reject unknown restored booking types rather than silently converting a challenge/team reservation into a personal booking; add regression test.
- `c46848b`, `5bcf78d`: prevent user-triggered cancellation/lock release while an electronic payment is awaiting or has an uncertain result, with source-contract test.
- `fe1c075`, `84b0cad`: prevent client checkout-expiry cleanup while Paymob processing/reconciliation is unresolved, with source-contract test.

**Accounting:** 0 newly accepted full subtasks; **32/620 complete, 588 remaining**. Eight commits of functional changes and test assertions; Flutter tests and end-to-end payment checks were not executed. Client safety improvements do not prove double-charge prevention on the backend. No production schema, payment transaction processing, role permissions or main branch modified.

## Batch — four legacy financial-field inventory closures

- `e2cddaf`: [source-grounded inventory](VSP_LEGACY_FINANCIAL_FIELD_INVENTORY_61_64.md) of championship winner aliases, booking payment-state fields, Paymob transaction/order aliases, and payment method/source mapping, with source references and explicit risks.
- `b815cd3`: close inventory-only subtasks **61.01, 62.01, 63.01, 64.01** in the canonical breakdown.
- **Accounting: 4 scoped documentation tasks closed, 36/620 completed, 584 remaining.** No DB queries, data migration, payment or permissions modifications. The rest of 61–64 remain open.

## Batch — challenge points formula

- `c5c0438`: [37.01 challenge points formula](VSP_CHALLENGE_POINTS_FORMULA_37_01.md) documented from the actual trigger: win=3, draw=1, loss=0, confirmed challenge result only, with `elo_processed` one-time guard and limitations.
- `30029aa`: close 37.01 in the task breakdown.
- **Accounting: 1 additional source documentation subtask closed; 37/620 complete, 583 remaining.** No runtime match result recalculation or database deployment.

## Batch — booking mapper guard and payment-state semantics

- `30c20ae`: reject unknown server booking types instead of silently rendering them as personal reservations.
- `30a2415`: restore legacy enum-qualified booking types before validation.
- `1876ee6`: add two unit tests for unknown and enum-qualified booking types (written, not executed).
- `24476dc`: [62.02 payment-state semantics](VSP_PAYMENT_STATE_SEMANTICS_62_02.md) documents existing server trigger precedence, refund preservation, client fallback and booking/payment matrix.
- `61f76f1`: close **62.02** in canonical breakdown.
- **Accounting: 1 documentation subtask closed; 38/620 complete, 582 remain.** Client mapper changed, not server finance logic. Tests not run; no production schema, permission or main changes.

## Batch — notification compatibility and migration collision audit

- `7c06e0a`: notification model reads legacy `message` when canonical `body` is absent/blank; new writes remain `body`.
- `5be5b84`: three tests for canonical precedence and historical message fallback (written, not run).
- `d96c4f4`: [migration collision and notification inventory](VSP_MIGRATION_COLLISIONS_AND_NOTIFICATION_INVENTORY.md) identifies 7 timestamp-collision groups, including conflicting sixth-team fee/no-fee RPC definitions; closes 67.01, 71.01, 72.01.
- `7bab47a`: [canonical notification field and compatibility plan](VSP_NOTIFICATION_FIELD_CANONICAL_AND_COMPATIBILITY_67.md) closes 67.03 and 67.05.
- `00720f3`, `b3f99f5`: update canonical checklist.
- **Accounting:** 5 source-inventory/decision tasks closed, **43/620 complete, 577 remaining**. The two incompatible matchup fee migrations are **not** applied; live schema, migration runner order and tests remain unverified. No schema, fee, permissions or main branch changes.

## Batch — notification repository legacy read fix, 1v1/result inventory

- `ceee2c9`: fix `NotificationRepository._mapToCamelCase` to forward legacy `message` to `AppNotification.fromFirestore`. Without this, previous model-only fallback could not work for actual Supabase stream rows.
- `a35b541`: architecture regression contract test for repository → model legacy mapping (written, not run).
- `bc6350b`: trace notification read/write consumers and record canonical `body` decision; close **67.06** only. 67.02 remains open pending exhaustive producer/template trace.
- `6f7bcce`: source inventory of `vsp_1v1_tournament_players` and locked legacy `challenge_results`; close **69.01** only. 70.01 remains open because legacy primary key and references were not confirmed.
- `6be9e46`: update canonical checklist.
- **Accounting:** 2 source-scoped documentation tasks closed, **45/620 completed, 575 remaining**. Tests not executed; no database migration, RLS change, fee change or main merge.

## Batch — notification legacy stability, lifecycle, recipient guards and delivery key

- `b839022`: `AppNotification.fromFirestore` accepts direct snake-case legacy records, parses read flags safely and uses stable epoch fallback for malformed or missing dates rather than crashing a notification list.
- `5a37993`: three additional unit cases for snake-case, malformed and missing timestamps (not run).
- `82c9542`: prevent `setState` after disposal while loading notification preferences.
- `146c02c`: source-level lifecycle regression test (not run).
- `92761e9`: reject blank user ID and notification ID before send, restore, mark-read, mark-all or delete Supabase writes.
- `a6db524`: source-level identity guard regression test (not run).
- `17eebe2`: [48.01 notification dedup key](VSP_NOTIFICATION_DELIVERY_DEDUP_KEY_48_01.md) specifies logical notification ID and per-channel/device delivery identity; does not claim server dedup implemented.
- `6da6c42`: close **48.01** in task breakdown.
- **Accounting: 1 scoped specification task closed; 46/620 complete, 574 remaining.** Three functional client fixes and three test updates, tests not run; no production schema, RLS, FCM queue or main merge.

## Batch — notification account isolation, safe streams and matchup dependencies

- `c203dfb`: return empty notifications/zero unread count without opening Supabase stream for missing user IDs; clamp inbox stream page size to 1–200.
- `e6a5917`: actual async unit tests for blank identity streams and mutation guards, designed to run without initializing Supabase.
- `39246af`, `ee90bcb`: tolerate non-string legacy notification metadata keys without breaking the inbox.
- `1a12d64`: model unit tests for malformed metadata and mixed-type legacy fields.
- `34f06ff`, `5d40ed4`: scope notification preference keys to authenticated user; reset on logout; prevent stale async reads/writes and avoid synchronous setState during dependency change. **Intentional behavior change:** old global preferences are not imported across accounts, preventing cross-account leakage on shared devices.
- `5c99b4d`, `d29ec5e`, `5a73d1c`: lifecycle and account-isolation source regression tests.
- `2218756`, `62ef516`: keep mark-all request feedback scoped to initiating account, with source regression test.
- `bf0a7b8`: [matchup fee RPC dependencies and no-fee product decision](VSP_MATCHUP_TEAM_CAP_DEPENDENCIES_AND_DECISION_72.md); closes **72.02 and 72.06**. No deployed RPC or financial changes.
- `5d51a08`: update canonical task breakdown.
- **Accounting: 2 source-scoped tasks closed; 48/620 completed, 572 remaining.** Multiple real client fixes and regression tests committed. Tests not executed (Flutter/Dart unavailable in this execution environment); no staging/production DB changes or main merge.

## Batch — notification account-safe routing and storage resilience; position registry inventory

- `2826a1d`: block stale-account navigation and feedback after notification read updates; challenge details action also verifies current user before routing.
- `f6ab703`: source regression tests for account-safe notification taps.
- `299e01b`: recover notification settings screen from unavailable SharedPreferences and surface save failures rather than spinning indefinitely or silently claiming persistence.
- `dc8435e`, `22ce5ce`: lifecycle contract adjustment and storage failure regression tests.
- `f8b31ac`: [13.01 sport position registry inventory](VSP_PLAYER_POSITIONS_INVENTORY_13_01.md), documenting supported codes/defaults and canonical selector.
- `b1ae5eb`: close **13.01** in canonical checklist.
- `c5cd2e2`: unit tests for position registry/defaults, written but not executed.
- **Accounting: 1 source-inventory task closed; 49/620 completed, 571 remaining.** Real notification fixes and tests committed; tests not executed. No live Supabase schema, RLS, payments or main branch changes.

## Batch — responsive position selector and legacy notification read flags

- `6c481be`: `VSPPositionSelector` now wraps options in a two-column adaptive layout rather than forcing all positions into a single row; honors `MediaQuery.disableAnimationsOf(context)` by disabling selection animation.
- `a106546`: widget tests for 220px width selection and reduced motion (written, not executed).
- `054aac8`: notification model now accepts trimmed legacy `is_read='1'` string as read, while `'0'` and unknown values remain unread.
- `4eb26f2`: tests for legacy string read flags (written, not executed).
- **Accounting:** no full subtasks accepted in this batch: **49/620 completed, 571 remaining**. These are partial implementation of responsive/accessibility and legacy data quality scopes. No production schema, payments, permissions or main changes.

## Batch — extra-narrow position selection and accessibility

- `5a9506a`: position selector now uses a single column below 240 logical pixels and two columns at wider finite widths, instead of forcing cramped 2-column cells on very narrow devices.
- `72bbaad`: widget regression case for a 140px position selector (written, not run).
- `7a26e96`: suppress selector haptic feedback when the platform requests reduced motion, in addition to the prior zero-duration animations.
- **Accounting:** no full subtask closed in this batch: **49/620 completed, 571 remaining**. Source code and tests committed; runtime layout/accessibility tests remain unexecuted. No live database, payment, permissions or main changes.

## CI validation and repair — 2026-11-08

- First full Flutter CI run: **1003 passed, 2 failed, 10 skipped**. Analyzer was initially blocked by duplicated trailing code in `app_date_formatter.dart`, a nullable Paymob WebView URL, missing required fields in a booking draft test, and an unused import; repaired in `0d59dab`, `4cab911`, `47f8641`, `434c4e3`.
- After these fixes, **Flutter analyze** and **architecture regression gate** passed. Full suite exposed two failing tests: Arabic team achievement badge fixture and past-date slot selection fixture.
- `4be4e6e`: slot toggle test now uses future date, retaining the production guard against booking in the past.
- `a6c492a`: declares Arabic as supported in achievement widget test; still insufficient because the Flutter localization delegates were absent.
- `fc345aa`: adds Material, Cupertino, and Widgets localization delegates to the Arabic badge test fixture.
- Android E2E Smoke **passed** on `4be4e6e` (run `42485905095`). This is automated smoke coverage, not proof of live end-to-end payments or device acceptance.
- The newest Flutter CI for `fc345aa` (run `42486761911`) was pending when this record was written. Do **not** mark full test suite passed until its result is confirmed.
- **Accounting unchanged: 49/620 completed, 571 remaining.** Fixes are committed; final verification pending. No main merge, production database, RLS, or payment changes.

## Verified CI closure — 2026-11-08

- GitHub Flutter CI [run 42486800643](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42486800643) succeeded: analyzer, architecture regression (53 tests passed), and full Flutter suite (**1005 passed, 10 skipped**). Android E2E Smoke [run 42486800662](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42486800662) also succeeded on the same commit.
- `docs/VSP_FLUTTER_CI_VERIFICATION_57.md` (`ea07921`) captures the run IDs, job evidence, failure/fix commits and verification limits.
- `67a98fb` closes **57.01–57.06**, six subtasks with direct passing CI evidence. **57.07 remains open** pending verification of enforced branch protection.
- `45be581` briefly changed notification mark-all return semantics; `3889a5e` restored correct idempotent behavior for an empty inbox before the final verified closure. This was not counted as a completed subtask.
- **Progress: 55/620 completed, 565 remaining.** The successful run predates the subsequent notification and documentation commits; new code still requires a fresh green run. No production schema, RLS, payments, or main merge.

## Verified Android smoke closure — 2026-11-08

- Latest validated branch commit `df76e5e`: [Flutter CI 42489433328](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42489433328) **success** and [Android E2E Smoke 42489433379](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42489433379) **success**.
- `docs/VSP_ANDROID_E2E_SMOKE_VERIFICATION_58.md` (`5cdf59a`) inventories actual assertions, repeatable Android emulator setup and run/job evidence. `5eecc96` closes **58.01, 58.02, 58.07**.
- Important limitation: Android smoke covers **welcome, language toggle, onboarding Skip and login form navigation**, **not** successful login, booking, payments, team challenges, or invitation acceptance. 58.03–58.06 and 58.08 remain open.
- Attempted read of GitHub main branch protection returned **403 Resource not accessible by integration**. Thus 57.07 remains open; do not assume CI is required for merging.
- **Progress: 58/620 completed, 562 remaining.** New commits after `df76e5e` need fresh green CI before release readiness. No main merge or production database/payment change.

## Notification deep-link hardening batch — 2026-11-08

- `02bb992`: `NotificationFilterService.resolveDeepLinkRoute` now accepts legacy snake-case booking/team identifiers and rejects malformed IDs, route traversal, encoded slashes, queries/fragments, control characters, overlong IDs and non-string values; invalid payloads fall back to the notification inbox or a valid team route.
- `021e348`: unit tests for legacy IDs and hostile payloads. `157aa69`: clarify route-validation documentation.
- Prior branch commit `2c310b3` passed [Flutter CI 42512915158](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42512915158) and [Android E2E Smoke 42512915102](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42512915102).
- Fresh [Flutter CI 42514888405](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42514888405) and [Android smoke 42514888523](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42514888523) were **pending** at record time. Do not claim tests passed on new code until completed.
- No checklist closure in this batch yet: 07.07 requires end-to-end auth/role navigation verification, not merely ID sanitization. **58/620 completed, 562 remaining**. No main merge or production schema/payment changes.

## Booking-state and notification payload safety — 2026-11-08

- `8684b9d`: booking mapper now rejects unknown server booking statuses with `FormatException`, rather than treating them as `pending` and potentially displaying unsafe payment/retry actions. Existing `upcoming` alias remains mapped to confirmed.
- `742201d`: regression tests cover unknown status, `upcoming` compatibility and invalid time ranges.
- `415ce10`: notification deep-link resolver validates camelCase and snake_case IDs separately; malformed modern value can no longer mask a valid legacy value.
- `0be9b2b`: tests for malformed-modern/valid-legacy fallback.
- Previous [Android smoke 42514922345](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42514922345) **succeeded** on `b4f7f03`; Flutter CI for that earlier commit was still in progress at inspection. New [Flutter CI 42515885719](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42515885719) was pending at inspection.
- This is a code-hardening batch, not closure of the complete 27.x or 07.x user-journey tasks. **Count remains 58/620 completed, 562 remaining** until full acceptance criteria are met. No main merge or production DB/payment modifications.

## Restored booking draft financial validation — 2026-11-08

- `be7c9ea`: `BookingDraft.fromMap` rejects restored deposits greater than the total price, matching `BookingDraft.validate` and preventing an inconsistent draft from reaching checkout.
- `6e8f129`: regression test verifies an overlarge restored deposit throws `FormatException` and a valid saved draft round-trips.
- The prior `679c7cf` Flutter CI [42515913921](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42515913921) and Android smoke [42515913915](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42515913915) were still in progress at inspection. The new Flutter CI [42516555825](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42516555825) was pending. Do not mark tests green without completion.
- **Progress unchanged: 58/620 completed, 562 remaining.** This is a targeted safety fix within broader booking/payment acceptance tasks, not a closed full journey. No main merge or production schema/payment changes.

## Stage 11 booking-status regression repair — 2026-11-08

- Inspected failed Flutter CI [42515913921](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42515913921): **1010 passed, 1 failed, 10 skipped**. Analyzer and architecture gate passed; the only failed test was `test/stage11_state_consistency_test.dart` expecting unknown server status to silently become `pending`.
- `56b984e` updates that legacy test to require `FormatException`, consistent with the safer `BookingMapper` behavior introduced by `8684b9d`. It does **not** revert unknown statuses to pending.
- The restored-draft deposit overflow fix `be7c9ea` and regression `6e8f129` remain committed.
- Full suite on latest commit requires fresh CI. **Count stays 58/620 complete, 562 pending**, pending end-to-end task acceptance; no production schema/payment or main merge.

## Restored booking capacity validation — 2026-11-08

- `4dc2207`: `BookingDraft.fromMap` rejects invalid player/team capacity (nonpositive players per team, nonpositive field capacity, negative current players, or current players exceeding field capacity). The checks mirror existing draft validation before restored data can proceed toward checkout.
- `d4d25e4`: unit regression tests cover four invalid count/capacity cases and valid restoration.
- Latest [Flutter CI 42516946511](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42516946511) was pending at inspection. No claim of passing tests on these commits yet.
- **58/620 completed, 562 remaining**. Booking lifecycle end-to-end tasks remain open. No main merge or production database/payment changes.

## Strict restored booking count parsing — 2026-11-08

- Atomic code/test/ledger batch: `BookingDraft.fromMap` rejects fractional, non-finite and malformed player counts instead of silently truncating or defaulting; null/missing values retain the historical fallback. Added regression fixtures for fractional current players, malformed string, NaN and Infinity alongside existing negative/overflow cases.
- Previous branch baseline **58/620 complete, 562 remaining**. This hardening does not close full booking journey acceptance; CI must pass on the atomic commit before counting any additional task.
- No main merge or production schema/payment change.

## Restored booking identity validation — 2026-11-08

- Following verified green [Flutter CI 42517061137](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42517061137) and [Android smoke 42517061154](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42517061154) on `285d8bf`, hardened `BookingDraft.fromMap` to reject missing/blank/non-string venue and owner identifiers. Supports legacy `stadium_id`/`owner_id`, trims valid IDs and runs the shared draft validation on the restored object.
- Regression tests cover six invalid identities and valid snake-case restoration. These tests need fresh CI on the new commit.
- No complete booking E2E task is closed by these guards: **58/620 completed, 562 remaining**. No production DB/payment or main changes.

## Payment HTTP ambiguity and notification type compatibility — 2026-11-09

- Prior Flutter CI [42520206334](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42520206334) and Android smoke [42520206344](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42520206344) both succeeded on `72b8996`.
- Classify HTTP 408/504 as uncertain payment timeouts, 409 as potential duplicate/idempotency conflict, and transport status 0 as network uncertainty. These classifications require server reconciliation before any charge retry; regression tests added.
- Normalize notification type case and surrounding whitespace for preference filtering (player and owner) and cover this with regression tests. Unknown types still retain existing behavior.
- **58/620 completed, 562 remaining** until broader journeys are verified. No production schema, payment service, or main merge. Fresh CI needed.

## Payment timeout precedence and booking-status casing — 2026-11-09

- Verified Flutter CI [42669581542](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42669581542) and Android smoke [42669581673](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42669581673) succeeded on `95ce6b5`.
- Explicit ambiguous HTTP transport statuses 504/408/409/0 now override contradictory gateway message text (e.g., "cancelled"), preventing false safe-retry decisions; tests cover precedence.
- `BookingMapper` normalizes enum status comparisons across casing/underscores and tests uppercase confirmed and no-show, while continuing to reject unknown statuses.
- These are incremental regression fixes, not full payment reconciliation or booking state E2E completion: **58/620 complete, 562 remaining** until broader acceptance. CI pending for new commit; no main merge or production changes.

## Booking financial map integrity and notification route regression — 2026-11-09

- Server booking mapping now rejects malformed, negative, non-finite total price/deposit and deposit larger than total rather than silently substituting zero; valid numeric strings and null legacy amounts remain supported. Regression fixtures cover seven corrupt variants and a valid decimal deposit.
- Added regression checks that malicious legacy notification route IDs cannot override safe modern IDs, plus explicit documentation of destination authorization responsibility.
- Previous commit `4bd521a` has workflow-level failures with **zero jobs returned** for [Flutter CI 42673052963](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42673052963) and [Android 42673045331](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42673045331), while other attempts were still running when checked. Do not misstate this as a test assertion failure or as passing.
- **58/620 complete, 562 remaining**. These are partial booking and notification hardening, not full E2E task closure; no production schema/payment or main merge.

## Legacy booking draft field compatibility — 2026-11-09

- Restored draft parser now accepts legacy snake-case time, total price, player count, paid flag, payment method/transaction, team/opponent IDs and idempotency key, while retaining strict validation. This prevents an older saved draft from losing payment correlation or replay identity.
- Added round-trip test for ten legacy field aliases and negative tests for invalid legacy time/price.
- The previous branch commit `6675e75` had pending CI at inspection. This change needs its own full CI before any task closure.
- **58/620 completed, 562 remaining**; no main merge, production database or payment-provider changes.

## Server error payment precedence and draft replay-key validation — 2026-11-09

- Explicit HTTP 500/502/503/429 gateway failures override misleading "cancelled" message text, requiring authoritative server reconciliation before retry; regression coverage added.
- Restored booking drafts now preserve only trimmed, nonempty safe replay/idempotency keys (up to 128 characters), rejecting malformed and non-string keys; regression tests cover valid and invalid keys.
- Prior Flutter/Android runs on `f427bbe` still pending at inspection. **58/620 complete, 562 remaining**, no full payment/booking E2E task closed. No production DB/payment changes or main merge.

## Critical build repair — 2026-11-09

- Detected a malformed, duplicated tail in `lib/data/models/booking_draft.dart` introduced during replay-key validation: truncated regular expression and duplicate closing blocks. Rebuilt the factory tail as a single valid Dart expression, preserving safe replay-key checks and shared validation.
- This is a build-blocking source fix; **do not count new tasks closed** before fresh CI is green. Existing queue backlog remains **58/620 complete, 562 remaining**.
- No production database or payment changes; no merge to main.

## Foreground notification preference enforcement — 2026-11-09

- `NotificationUiHelper.showInAppAlert` now checks the shared master/category notification preferences for the signed-in user's owner/player role before haptics and foreground banners. An opted-out owner will not receive a foreground booking alert merely because a push arrived.
- On preference-storage failure the pure filter now fails closed (returns false), instead of bypassing opt-outs; tests cover distinct owner/player booking settings.
- This is a client-side foreground UX safeguard; it does not implement push delivery opt-out or server consent logs. No task is closed until end-to-end acceptance. **58/620 complete, 562 remaining**.
- Prior GitHub Actions for `fa86b7c` show failed Android runs with zero jobs exposed and pending Flutter runs; investigate runner/workflow status separately. No production DB/payment changes or main merge.

## Next execution queue

1. 22 — operating hours/closures: finish one end-to-end owner-to-player scheduling flow.
2. 26 — booking overlap prevention: inspect server guarantees; do not change production schema without approval.
3. 03 — error/empty/retry states, then 16 — booking history.
4. 81–82 — team achievement badges and challenge consent code.
5. 56–60 — consolidated tests, security, release verification **at the end**.

Do not use the old `80-item` release tracker as the denominator for the 82-item/620-subtask inventory.
