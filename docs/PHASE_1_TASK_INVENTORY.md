# VSP — Phase 1: Consolidated Task Inventory

**Phase:** 1 of 7 — inventory only  
**Prepared:** 2026-10-31  
**Repository:** `mohamedsalh333555/VSP.App`  
**Working branch:** `uxlp-44-implementation`  
**Branch head at inventory:** `96d8e08d44c83eef69effd4d2da951e746b54cf9`

## Purpose and boundary

This document consolidates the outstanding VSP work before implementation phases are approved. Phase 1 is a read-only inventory/documentation activity. It does not implement the next phase, run the final test pass, change production data, apply migrations, or build an APK.

Status meanings:
- **Existing source work:** code/documentation already exists; not runtime-proven.
- **Open:** work remains.
- **Approval required:** do not change policy/backend behavior until the product owner approves.
- **Final validation:** intentionally reserved for Phase 6.
- **APK:** intentionally reserved for Phase 7.

## Evidence baseline

- Current branch head: `96d8e08d44c83eef69effd4d2da951e746b54cf9`.
- The UXLP standard contains **44 rules**. The current rule matrix contains all 44, and every row is explicitly marked **source reviewed—runtime pending**. Therefore, none of the 44 rules is currently recorded as a final pass.
- The screen register contains **137 unique Dart screen/surface file paths**, plus one shared bottom-navigation component entry. It has 143 table records because five paths are repeated to track separate embedded-component findings. The register itself states that it is an inventory, not proof of complete embedded-widget/state coverage.
- Existing source notes cover substantial work in authentication, player and owner booking, stadium discovery, tournaments, teams, payments, notifications, support, and shared dialogs/sheets. These notes are evidence of source review or source edits only; runtime remains pending.
- Latest CI run inspected: `41212312576`, commit `96d8e08d44c83eef69effd4d2da951e746b54cf9`; conclusion **failure**. Analyze failed, so tests and debug APK build were skipped.
- Exact latest analyzer errors: `lib/features/owner/screens/owner_cup_screen.dart:81:25` — `VSPBottomNavMetrics` is undefined and the value is invalid in a const expression. This is an open source/build blocker, not a test result.
- CI workflow currently runs `flutter analyze`, then `flutter test --coverage`, then a **debug** APK build. It does not build the requested Release APK.

## Consolidated work register

| ID | Workstream | Current evidence/status | Remaining work / exit evidence |
|---|---|---|---|
| P1-01 | UXLP-44 rule implementation | All 44 rules are documented in the matrix; all 44 remain source-reviewed/runtime-pending. | Map each rule to applicable screens, widgets, roles, locales and states; implement gaps; later attach evidence. |
| P1-02 | Screen and surface coverage | 137 unique Dart screen/surface paths registered, plus shared navigation. | Discover embedded widgets and route/modal entry points; complete per-screen and per-state review without treating the file list as exhaustive proof. |
| P1-03 | Design-system consolidation | V2 tokens, semantic roles, canonical finance/navigation components and migration notes exist. | Verify actual usages, remove divergent implementations/values, unify tokens and shared button/filter/segmented/action-bar components; runtime visual proof remains later. |
| P1-04 | Bottom navigation and layout geometry | Shared navigation uses separate active/inactive icon variants in source; canonical geometry naming is documented. | Fix the current undefined `VSPBottomNavMetrics` reference; verify one geometry source and actual Bold-vs-Outline glyphs; inspect FAB, scroll and action-bar clearance. |
| P1-05 | Responsive layout and safe areas | Several screens, sheets and dialogs have source-level SafeArea, scrolling and keyboard-inset changes. | Complete remaining screen/modal review; inspect 320/360/390/412 widths, long Arabic/English text, enlarged text, keyboard, short viewports and actual device rendering. |
| P1-06 | Booking and payment integrity | Booking operating-window trigger/function provenance was read-only verified; prior deposit fix is documented as already deployed. | Build complete mutation/payment matrix; verify all booking mutation paths, deposit and Paymob states, cash/online wording, refund behavior, server-authoritative amounts and failure handling. No new SQL without approval. |
| P1-07 | Stadium discovery, filters and amenities | Source changes cover server-side filtering before pagination, combined filters, sorting, quick-filter reset/count, and error propagation. | Reconcile every query with live Supabase schema and canonical amenity representation; verify multi-select end-to-end, real results, pagination, reset and no false empty/zero states. |
| P1-08 | Owner finance, plans and analytics | Source notes cover canonical finance surface, subscription-plan reads, metrics cache and fail-closed withdrawal balance. | Verify all financial concepts against server truth, Free/Pro entitlements and labels; reconcile analytics date semantics, maintenance exclusions, team-vs-challenge counting and full dataset scope. |
| P1-09 | Loading, empty, error and retry contracts | Many booking, stadium, team, notification, league and support flows have source-level state handling. | Inventory all remaining data sections and streams; prove no server/stream error becomes empty, zero or hidden content; ensure safe localized retry and preserve last good data where appropriate. |
| P1-10 | Arabic/English UX writing and RTL/LTR | Several targeted bilingual copy corrections exist. | Full text audit of every visible label, action, validation, notification, modal, status and error in both locales; check truncation, mixed-language strings and RTL/LTR layout. |
| P1-11 | Teams, challenges, tournaments and results | Source notes include captain-scoped result eligibility, retryable result dialogs, roster and tournament layout fixes. | Verify complete role/eligibility/lifecycle matrix, scoring, team membership, tournament states and result confirmation. Resolve policy questions below before behavior changes. |
| P1-12 | Notifications and refunds | Client notification stream error handling and refund notification insertion paths have been inspected. | Correlate missing refund notifications and historical disappearance with runtime rows/logs; verify retention and delivery without assuming the cause is solved. |
| P1-13 | Security, RLS and backend governance | Earlier security remediation and read-only function/trigger inspections are documented. | Review SECURITY DEFINER authorization, RLS overlaps, sensitive RPC callers, advisor findings and production-vs-main migration reproducibility. |
| P1-14 | Support and help flows | Recent source changes add required subject validation, single-flight submission, localized categories/statuses and stream error/retry states. | Reconcile the latest analyzer/build blocker; inspect all support paths and verify sheet/button visibility and submission behavior at runtime in Phase 6. |
| P1-15 | CI and release readiness | Latest Flutter CI run failed at Analyze; test and debug APK steps were skipped. | Fix analyzer/build blockers during implementation; after Phase 5 approval run one consolidated test pass in Phase 6; then configure/run and verify a Release APK in Phase 7. |

## Product decisions requiring explicit approval before changing behavior

1. **Challenge-result authorization:** the server RPC does not explicitly enforce confirmed/completed booking status and distinct captains for the second review. Proposed guards are recorded in the master remediation document; no SQL change was made.
2. **Multiple-team selection semantics:** a user may belong to multiple teams; participating/captained team selection must be consistent and unambiguous.
3. **Notification retention and refund reconciliation:** observed client/database evidence does not prove the historical deletion/delivery cause. Do not introduce retention or refund behavior based on assumptions.
4. **Any new database migration, RPC policy, RLS policy, payment/refund rule, or business eligibility change:** present exact change and rationale for approval before applying it.

## Execution order after Phase 1 approval

1. Phase 2 — complete UXLP-44 rule-by-rule implementation and evidence mapping.
2. Phase 3 — complete screen/surface, copy, data-source, state, role and layout review.
3. Phase 4 — implement grouped, approved fixes from those reviews.
4. Phase 5 — reconcile the register against the repository and confirm implementation closure; report any blocked/approval-required item rather than silently skipping it.
5. Phase 6 — one consolidated final analysis/test/runtime validation pass after approval.
6. Phase 7 — build, extract and verify the Release APK after approval.

## Phase 1 completion criteria

- [x] Current branch and commit identified.
- [x] UXLP-44 count and actual status recorded.
- [x] Screen/surface register count and limitations recorded.
- [x] Existing source work separated from runtime proof.
- [x] Latest CI failure and exact blocker recorded.
- [x] Remaining implementation work grouped into actionable workstreams.
- [x] Approval-required product/backend decisions listed.
- [x] Phases 2–7 and their boundaries recorded.

**Phase 1 result: COMPLETE — inventory only. No implementation phase has been started by this inventory.**

## Follow-up status — 2026-11-01

The evidence baseline above is a historical snapshot from 2026-10-31 and is intentionally preserved. It must not be read as the current branch state.

Current documentation/source status on `uxlp-44-implementation`:
- UXLP-44 rule matrix: exactly 44 numbered rows; every rule remains source-reviewed/runtime-pending. Notification retention is recorded separately as an open product decision, not as a duplicate numbered rule.
- Screen register: 216 table records across 190 unique Dart paths, including 26 repeated entries for separate findings. Four malformed concatenated rows were split; no multi-path table rows remain.
- The register is an implementation tracking inventory, not proof that every embedded widget, modal, state, or route is covered.
- Grouped source changes and test-fixture corrections have continued since the inventory snapshot. They have not been given a final validation pass; no runtime pass is claimed.
- Product decisions remain open for team-booking authorization (member vs captain), multiple-team selection semantics, notification retention/refund-notification reconciliation, and server-side result eligibility/time guards. No SQL, RLS, RPC, payment, refund, or retention behavior was changed as part of this follow-up.
- The user requested continued source/documentation work while explicitly deferring tests and APK extraction. Those gates remain deferred; do not interpret this follow-up as Phase 6 or Phase 7 completion.

**Current phase state: Phase 2/3 source remediation and evidence mapping in progress; Phase 6 tests/runtime validation and Phase 7 APK remain intentionally not run in this batch.**

### Embedded UI coverage follow-up — 2026-11-01

Repository filename reconciliation identified nine additional embedded UI components that were missing from the earlier register. They were added with `not yet inspected` status. The current register therefore supersedes the previous count with 225 table records across 199 unique Dart paths, including 26 repeated entries. The historical baseline above remains unchanged.
