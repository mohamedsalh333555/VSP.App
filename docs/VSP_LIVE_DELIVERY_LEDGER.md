## 2026-11-13 — Payment timeout client simulation accepted (167/451)

- **29.06** accepted specifically for **client-side webhook timeout, cancellation and recovery timer tests**, using the direct `PaymentCheckoutCoordinator` unit test and source inspection of `PaymentGatewayScreen`. See [detailed acceptance and limits](VSP_PAYMENT_TIMEOUT_CLIENT_ACCEPTANCE_29_06_2026-11-13.md) and [Flutter CI 43501718030](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43501718030) (1288 passed, 11 skipped). This simulated callback/cancel behavior; **not** live Paymob sandbox, a financial success claim, a 5-minute device test, or proof of no double charging. Tasks 29.03–29.05, 29.07–29.08 and 30.02–30.08 remain open.
- The newest booking disclosure and payment logging code in `db9dec05` was awaiting fresh CI at this documentation checkpoint. The validated timer source and its tests are unchanged by those additions.
- **Total 618 / scoped accepted 167 / open 451.** No `main` merge, staging/production payment mutations or schema deployment.

## 2026-11-13 — Booking price disclosures and sensitive payment logging (new CI pending, 166/452)

- The [booking disclosure update](https://github.com/mohamedsalh333555/VSP.App/commit/ea913b36c60012dd799d73228e21f9a151e32561) made collective full-online payment explicit, stopped promising unconditional cash payment before location checks, and stopped a negative deposit remainder being disguised as 0 EGP. [Flutter CI 43504622650](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43504622650) identified **two older source-contract assertions** still requiring the previously unsafe `(totalPrice - deposit).clamp(0,...)` expression. Those tests have been revised to assert the new safer disclosure and remain runnable. This is an intentional change of contract, not an attempt to mask a runtime failure.
- Payment gateway UI, payment status coordinator and Paymob service now log **redacted fixed diagnostic messages** instead of interpolating provider exceptions and potentially leaking booking references, payment metadata or raw gateway content. A new source-contract test verifies the targeted logging boundaries. It does not prove all logging across the application is sanitized: SEC-03/76.05 remains open pending wider audit.
- [Issue #44](https://github.com/mohamedsalh333555/VSP.App/issues/44) remains open for challenge-code lifecycle/captain consent and 8-digit format. No trial, subscription, financial or real team data changed.
- **618 total / 166 scoped accepted / 452 open**, no production/staging mutation or merge to `main`. New Flutter tests and Android/iOS checks must pass before these follow-up changes are counted as verified.

## 2026-11-13 — Client booking disclosure and stale deep-link defenses (status: implementation awaiting CI, 166/452)

- [Payment disclosure and deposit preview fix](https://github.com/mohamedsalh333555/VSP.App/commit/ea913b36c60012dd799d73228e21f9a151e32561): regular booking summary no longer promises unrestricted cash before location/eligibility verification; collective bookings show full-online requirement; cash-restricted notice no longer promises automatic rating restoration; invalid deposit greater than selected total shows an explicit review message rather than a falsely clamped zero remainder. **Does not guarantee server-authoritative payment quote; 83.03 stays open**.
- Initial booking route now rejects slot-only deep links with no date, instead of assigning their previously selected time to an unrelated calendar day. Along with earlier expired/non-contiguous/out-of-range date filters, this reduces stale total-price and booking-attempt risk; server revalidates actual availability. **83.01/83.04 stay open pending full booking states and device verification**.
- Read-only staging function inspection found challenge lifecycle misaligned with consent/8-digit/post-match rotation specification; tracked as [Issue #44](https://github.com/mohamedsalh333555/VSP.App/issues/44). Existing codes were not queried, regenerated or rotated. No code delivery/acceptance is asserted for tasks 82.02–82.09.
- **No staging/production changes**, no booking/payment mutations or `main` merge. Existing accepted total stays **166 of 618** until new CI and real E2E acceptance.

## 2026-11-13 — CI-verified client gates accepted (166/452)

- **New narrowly accepted tasks:** **21.04** client EGP/pricing/deposit validation; **25.04** Arabic/English expired trial and expired paid plan presentation; **25.06** fail-closed **client** owner-stadium capacity gate and mock-HTTP tests; **29.02** safe classified Arabic/English payment failure messages. See [acceptance boundaries](VSP_OWNER_BOOKING_CLIENT_GUARDS_ACCEPTANCE_2026-11-13.md) with detailed scope, code and test evidence. These were covered by [Flutter CI 43501718030](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43501718030): **1288 passing / 11 skipped**, analyzer, privacy and architecture checks green, alongside account SQL/owner checkout and iOS compliance. **No server-security or real-payment end-to-end acceptance is implied.**
- **New unaccepted follow-up (pending separate CI):** strict 24h parsing of venue break/closure times prevents malformed values silently converting to midnight; both `currency` and `currency_code` now validated when supplied; added payment error UI source-contract checks. The new commit's CI must pass before these additional changes are considered verified.
- **P0/P1 and release blockers still open:** #41 owner capacity write-time server guard; #42 historic one-year trial default; #43 owner moderation/review field grants; payment webhook, booking race, physical-device and staging role tests. Security SQL candidates are source-only, **not deployed**, and `main` remains unchanged.
- **Total 618 / Accepted 166 (including scoped documentation/client tasks) / Open 452.**

## 2026-11-13 — Automated staging-test environment separation documented (162/456)

- **59.08** accepted **as an evidence-bound documentation deliverable for currently audited automated CI tests only**: [target and synthetic-data boundary](VSP_STAGING_TEST_ISOLATION_59_08_2026-11-13.md) references independent staging and production project identifiers, the exact-project fail-closed live-test guard, anonymous read-only staging contract, and isolated local SQL fixtures. [Staging Live Contract CI 43488898684](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43488898684) passed: four source safety guard tests and ten anonymous Dart assertions. [Account SQL CI 43488908311](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43488908311) passed synthetic local SQL contracts. No credentialed customer, server/merchant payment or actual money used in these audited test paths.
- **Limitations:** does NOT establish that the existing staging database contains no actual customer identities; does NOT prove payment sandbox, Firebase/FCM/analytics isolation, real multi-role staging, fixture-account cleanup, or production-replica safety. Tasks **59.01–59.06** and staging real-user tests remain open; user/production records were not inspected or mutated. [Issue #42](https://github.com/mohamedsalh333555/VSP.App/issues/42) confirms both staging and production have a historic 365-day trial default while a 7-day trial is displayed; a source-guarded SQL candidate is tested locally but **not deployed**.
- Owner subscription expiry UI task **25.04** remains open awaiting Flutter test-suite acceptance on latest source. **618 tasks / 162 narrowly accepted / 456 remaining.** No `main` merge, production change or release approval.

## 2026-11-13 — UXLP-44 independent rule acceptance matrix created (161/457)

- **01.07** accepted for the independently testable **44-rule acceptance matrix only**: [UXLP-44 criteria](UXLP_44_INDEPENDENT_ACCEPTANCE_CRITERIA_2026-11-13.md) maps every canonical UXLP rule to a distinct observable pass condition, with locale/state/role/viewport evidence template. **No source-screen, RTL, accessibility, performance or on-device UX rule is declared passed by authoring its acceptance criterion.** Related tasks 01.01–01.06 remain open.
- Fixed the mandatory `email` fixture argument omitted in the owner expiry presentation widget/domain test after [Flutter CI analyzer failure 43486621098](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43486621098). The owner expiry UI task **25.04 remains open until the latest test job is green**.
- Owner-stadium limit client guard and candidate DB trigger remain branch-only; test environments are disposable PostgreSQL and mock HTTP. The server trigger candidate was **not applied** to staging or production, and [Issue #41](https://github.com/mohamedsalh333555/VSP.App/issues/41) remains open. [Issue #42](https://github.com/mohamedsalh333555/VSP.App/issues/42) documents a separate default trial duration mismatch. No subscription payment/price changed; no `main` merge.
- **618 total / 161 accepted scoped deliverables / 457 open.**

## 2026-11-13 — Owner Free/Pro plan data inventory accepted (160/458)

- **25.01 and 25.02** accepted **as documentation tasks only**. [Staging public-plan comparison](VSP_OWNER_FREE_PRO_ENTITLEMENT_SOURCE_25_01_25_02_2026-11-13.md) records actual `basic` and `pro` table values, feature flags, max stadium counts, trial days, and source files. Observed staging snapshot: Free = 0 EGP/1 stadium, Pro = 1,000 EGP monthly/3 stadiums, annual = 11,000 EGP, Pro trial = 7 days. **No prices or rules changed**, and current staging display does not imply approved production billing. This does not establish player-paid features or functionality of every Pro flag.
- **Critical follow-up remains OPEN:** read-only RLS/catalog audit shows the current `stadiums_insert_own` policy is owner-only without plan cap, authenticated INSERT grant exists, and the stadiums table has no user triggers. A server-side over-limit bypass is plausible but not exploited/tested; tracked in [Issue #41](https://github.com/mohamedsalh333555/VSP.App/issues/41). Do not mark 25.03/25.06 done or change production schema/payment flows without isolated role/concurrency tests.
- Booking test fixes on code commit `604302bd` passed both [Flutter CI 43479534476](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43479534476) and [Flutter CI 43479523917](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43479523917); this covers automated suite, not physical/staging end-to-end booking. **618 total / 160 accepted scoped tasks / 458 open**. PR #35 remains draft; no `main` merge, production or staging mutation.

## 2026-11-13 — Release readiness HOLD decision report issued (158/460)

- **60.08** accepted as a report-delivery task **only**: [release readiness and blocker matrix](VSP_RELEASE_READINESS_REPORT_60_08_2026-11-13.md) records the explicit **NOT RELEASE-READY / HOLD** decision, checkpoint evidence, unverified tests, outstanding P0/P1 security/payment gates, performance and signed-APK unknowns. A report being written is not an APK build, E2E acceptance, store submission or production release.
- The prior 157 accepted tasks are unchanged. **618 total / 158 verified scoped deliverables / 460 open.** New booking Flutter code remains under CI and staging/device validation; no automatic acceptance of 83.01/83.04/83.06, no `main` merge.

## 2026-11-13 — Isolated final-seat pickup join race accepted (157/461)

- **35.08** accepted as a **two-session native PostgreSQL concurrency contract**, not staging/production E2E. [CI 43473270739](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43473270739) passed, including independent SQL clients attempting the one remaining booking slot; one accepted, one refused with `BOOKING_FULL`, final row/roster counts consistent. [Evidence and open integration conditions](VSP_PICKUP_LAST_SLOT_CONCURRENCY_ACCEPTANCE_35_08.md).
- This proves only the branch-only `accept_join_request` candidate under controlled isolation; related live entry-point mapping, applied migration, cross-account authorization, and physical device tests remain OPEN. No payment, customer, staging or production data was used/changed; no main merge.
- **618 total / 157 VERIFIED / 461 open**.

## 2026-11-13 — Android release signing configuration audit accepted (156/462)

- **60.07** accepted for a **source/config-only audit**: original-release-signing fail-closed guard, explicit debug-signed QA override, separate Shorebird signing secrets, ignored keystore files and manual build workflow. [Audit and unresolved certificate/Play checks](security/VSP_ANDROID_RELEASE_SIGNING_SOURCE_AUDIT_60_07_2026-11-13.md). No keystore, signature fingerprint, real APK, signing secret, production account or store delivery was accessed; clean release tasks remain OPEN.
- **618 total / 156 VERIFIED / 462 open.** This does **not** certify a store-ready signed artifact.

## 2026-11-13 — Role/permission exception register accepted (155/463)

- **78.06** accepted as a narrowly scoped **documentation** outcome: eight source-grounded role/permission exception classes, their necessary boundaries, evidence references and outstanding role tests. [Register](security/VSP_ROLE_PERMISSION_EXCEPTION_REGISTER_78_06_2026-11-13.md). This is neither a new permission grant nor production access validation. No database, account, payment, configuration or production mutation occurred.
- **618 total / 155 VERIFIED / 463 open.** Actual real-account auth/RLS/RPC/storage tests and PR #35 release/merge gates remain open.

## 2026-11-13 — Migration replay preflight accepted (154/464)

- **71.06** accepted as a **narrow legacy-runner safety guard**: reject non-staging/unapproved targets, duplicate migration prefixes and rollback files, and fail closed if Supabase's official read-only migration-history API reports an already-applied version or cannot return trustworthy history. [Evidence and limits](security/VSP_STAGING_MIGRATION_REPLAY_GUARD_ACCEPTANCE_2026-11-13.md).
- [Account SQL security CI 43469070268](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43469070268) passed on code/test commit `c4a5b072`, covering isolated synthetic/mocked replay checks. **No staging/production migration or data write occurred**. The GET preflight is non-atomic and does not replace a tracked migration pipeline; full clean rebuild/replay **71.07 remains OPEN**.
- **618 total / 154 VERIFIED / 464 open**. This is not release readiness; direct main merge remains gated on integration tests, security blockers and branch conflict resolution.

## 2026-11-13 — Verified badge source tracing accepted (153/465)

- **81.02 and 81.05** accepted as **source-inventory-only**, not deployed or displayed achievements. [Official winner and current roster sources](security/VSP_VERIFIED_TEAM_BADGE_SOURCE_AUDIT_2026-11-13.md) were mapped from deployed RPC and schema with read-only aggregate SQL: 0 venue-owner-completed approved team titles, 0 completed 1v1 champions and 12 teams in Staging.
- **UI gap remains:** `MyTeamScreen` does not pass `verifiedSummary`, and legacy `check_team_has_1v1_champion` may return stale/unverified flags. Tasks 81.07/81.09/81.10 remain open; no UI, DB or production change made.
- **618 total / 153 VERIFIED / 465 open**.

## 2026-11-13 — Scoped Flutter UI and policy inventory acceptance (151/467)

- **Five accepted scoped tasks:** `67.04` legacy notification template tests, `67.07` synthetic in-app legacy render tests, `83.05` stadium owner prose/stock label translation, `83.07` ball option/no-slot and UI total tests, `75.03` staging RLS overlap audit. These are test/UI/source-inventory deliverables, **not** production notification delivery, cross-account RLS proof or Paymob settlement.
- Flutter CI, Android smoke, iOS build, account SQL and owner checkout security were **all green** for earlier source commit `3333f252` (e.g., [Flutter CI run 43448408773](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43448408773)). Newer branch-only maintenance/date/RPC changes remain in verification. [Policy evidence](security/VSP_STAGING_POLICY_OVERLAP_AUDIT_2026-11-13.md) records 50 Advisor warnings versus 0 exact definition duplicates and 27 action-expansion overlaps; no policy DDL was applied.
- **618 total / 151 accepted / 467 open**, pending additional Cairo DST CI and security integration tests.


## 2026-11-13 — Notification body/message consumer trace (146/472)

- `67.02` accepted as a scoped consumer/source trace only. Staging `notifications`: 6 body-populated, 3 message-populated, 1 mismatch; source path prioritizes body while reading message for legacy compatibility. [Details](security/VSP_STAGING_NOTIFICATION_LEGACY_SOURCES_2026-11-13.md). No customer content read or edited.
- Total **618 / 146 accepted / 472 open**. Runtime render, endpoint and payment tasks remain pending.

## 2026-11-13 — Correct 1vs1 legacy table mapping / migration runner safety

- **Correction to the same 69.04–69.06 audit, no new task count:** Actual standalone legacy table `vsp_1vs1_players` has 0 Staging rows and no user/tournament key, distinct from `vsp_1v1_registrations` (also 0) and active `vsp_1v1_tournament_players` (16). Updated [source-of-truth decision](security/VSP_STAGING_LEGACY_1V1_CHALLENGE_DECISIONS_2026-11-13.md) and SQL audit. Never migrate standalone stats by a nonexistent user ID.
- Hardened the legacy `scripts/apply_migration_runner.py` to be **staging-only**, require explicit identity/review flags, refuse rollback/unversioned files and duplicate source-version migrations; added isolated unit tests to Account SQL CI. 71.06 stays OPEN pending a passing CI test on the new commit. No migrations ran.

## 2026-11-13 — Staging legacy 1v1 and challenge result preservation decisions (145/473)

- Read-only Staging aggregate and unique-index review: legacy standalone \`vsp_1vs1_players=0\`, old registration \`vsp_1v1_registrations=0\`, current tournament players=16 across two tournaments, no repeated current \`(tournament_id,user_id)\` keys, legacy \`challenge_results=0\`, and 20 confirmed booking-side challenge result statuses. Counts do not establish production historical integrity.
- Six **data review and source-retention decision** tasks accepted in a narrow scope: \`69.04\`, \`69.05\`, \`69.06\`, \`70.02\`, \`70.05\`, \`70.06\`. [Evidence and safe-migration plans](security/VSP_STAGING_LEGACY_1V1_CHALLENGE_DECISIONS_2026-11-13.md). No actual merge, payment reconciliation, RLS change or migration; \`69.07\`, \`70.04\`, \`70.07\` remain open.
- **618 total / 145 VERIFIED / 473 open**. Other recently proposed Flutter and refund dispatcher changes require final CI and staging integration gates before operational acceptance.


## 2026-11-13 — Source-of-truth and retention decisions accepted (139/479)

- **11 narrowly scoped decision/plan subtasks accepted:** \`61.06\`, \`62.04\`, \`62.06\`, \`63.06\`, \`64.03\`, \`64.06\`, \`65.04\`, \`65.05\`, \`65.07\`, \`68.04\`, \`68.06\`. [Evidence and decisions](VSP_FINANCIAL_LEGACY_SOURCE_DECISIONS_2026-11-13.md) distinguish final source choices from production data migration. These are **documentation/compatibility decisions, not 11 deployed bug fixes**.
- New branch code for refund dispatcher, overnight booking and server-hours precedence, legacy notification rendering and stadium description localization is **not accepted** until relevant CI and isolated integration tests pass. Refund scheduler #39 P1 remains HOLD pending project-local identity and worker credential review; do not activate.
- Canonical scope: **618 total / 139 VERIFIED / 479 open**. No changes to \`main\`, staging/production schemas or financial records.


## 2026-11-13 — Isolated SQL regression and staging view access accepted (128/490)

- **22.06 and 22.07 accepted as isolated validator FUNCTION TESTS only**. [Account SQL security contracts run 43440144002](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43440144002) on code commit `45a45e7` completed successfully, including a negative control requiring the legacy validator to fail and a positive control requiring the patched validator to pass its SQL cases for split-shift and overnight booking windows. The migration **is not applied** to staging/production; real booking inserts, owner/RLS checks, conflict with `court_operating_hours` and end-to-end acceptance are still open.
- **76.03 and 76.06 accepted for staging view protection CONFIGURATION AND DOCUMENTATION only**. Live staging catalog proves four historically flagged views have `security_invoker=true`; `owner_subscription_status` revokes anon SELECT. Read-only role-scoped `SELECT count(*)` returned anon `courts=2`, `public_subscription_plans=2`, `tournament_clean_sheets=0`, and an authenticated session without JWT claims saw `owner_subscription_status=0`. No row identities retrieved. Cross-account owner/admin positive/negative tests, production view hardening and full Issue #38 closure remain **open**.
- Evidence and acceptance boundaries: [booking SQL and four view acceptance](security/VSP_VIEW_AND_BOOKING_WINDOW_ACCEPTANCE_2026-11-13.md). **618 total / 128 accepted / 490 open**. No production/staging row or schema modifications, no `main` merge.

## 2026-11-13 — Reproduced split-break midnight bypass; branch-only repair

- Tested the deployed staging `vsp_validate_stadium_booking_window` using synthetic Cairo-local 22:00–02:00 operating times with 23:30–00:30 booking. With a 00:00–01:00 overnight break, the function incorrectly returned **true**, while 23:45–00:15 and 00:15–01:15 breaks also returned **true** for the same overlap; a slot ending after 02:00 correctly returned false. Source: [night-break reproduction](security/VSP_STAGING_OVERNIGHT_SPLIT_BREAK_REPRO_2026-11-13.md).
- Updated **unapplied** `20261113143000_fix_expired_stadium_maintenance_booking_guard.sql` to anchor breaks to shift opening date, plus SQL negative/positive cases and architecture contracts. No staging/prod function changed. **22.06, 22.07, 66.07 remain OPEN** pending a passing isolated DB run and role-level booking tests. Accepted counter remains **124/618, 494 open**.

## 2026-11-13 — Financial/refund read-only source and staging acceptance (124/494)

- **8 scoped audit tasks accepted:** `61.02`, `61.03`, `62.03`, `63.02`, `63.03`, `63.04`, `68.02`, `68.03`. Evidence: [read-only financial, webhook, canonical winner and debt field audit](security/VSP_STAGING_FINANCIAL_AND_REFUND_AUDIT_2026-11-13.md). Source/metadata/staging-aggregate acceptance only, NOT production cleanup, endpoint safety, actual refund delivery or confirmed booking outcome.
- The canonical **team championship** winner fields for new writes/readers are currently `champion_team_id/name` (crown RPC, get_team_active_league and Flutter model). `winner_team_id/name` remain guarded legacy fields; no migration or deletion. On 2 staging championships, neither ID field is populated; production conflict risk remains unknown.
- Read-only staging checks: 24 bookings, 0 mismatched populated booking Paymob aliases, 0 duplicate populated identifiers, 0 obvious `is_paid`/status conflicts; 117 users, 0 positive `accumulated_cash_debt`, 0 `cash_booking_banned`, 0 `is_debt_blocked`, 117 nonzero `debt_limit`. These numbers cannot establish production integrity.
- **P1 blocker discovered (65.02 remains OPEN):** source and staging catalog show three active refund queue consumers, but staging `reconcile_cancellation_refund_queue()` checks only the regular and 1v1 queues, its active ten-minute cron job has no `refund_worker` secret record, and its hardcoded endpoint points to the production project. No refund worker was invoked, secret read or financial state changed. Do not enable or deploy until reviewed environment isolation and worker tests pass.
- Separate code changes in this branch (maintenance guard SQL proposal, missing-hours handling, blocked/maintenance venue CTA and new tests) remain **UNACCEPTED** pending relevant CI and isolated database/device tests. `main`, production and staging data remain unchanged.
- Recount: **618 total / 124 VERIFIED / 494 open**. Group 56 retired; no release readiness implied.

## 2026-11-13 — Operating-hours precedence and maintenance defect reproduction (116/502)

- **66.02–66.06** accepted as **read-only source-precedence analysis, edge-case inventory, deterministic validator test and documented backend-authority decision only**. Evidence: [staging validator reproduction](security/VSP_STAGING_OPERATING_HOURS_GUARD_REPRO_2026-11-13.md) and [GitHub Issue #37](https://github.com/mohamedsalh333555/VSP.App/issues/37#issuecomment-6840270011).
- The active `vsp_validate_stadium_booking_window` in staging returns `true` for a normal in-hours booking, **false** for the same booking with an expired non-null `maintenance_until` marker, and **true** for a booking ending before a future `maintenance_until` marker. This is a **reproduced logic defect for conditional inputs**, *not* proven live impact; 0 of 17 staging stadiums currently have a non-null maintenance marker. No booking/user/payment rows changed or read.
- The server `trg_bookings_operating_window` is the authoritative booking guard; Flutter `features.workingHours` and `court_operating_hours` are not equivalent sources. **The defective maintenance predicate has not been repaired**; staging migration/rollback, live closure tests and task 66.07 remain open. Do not mark release ready from the new tally.
- Recount: **618 total / 116 VERIFIED / 502 open**. Scope group 56 still cancelled. No `main` merge and no production/staging mutation.

## 2026-11-13 — Privileged RPC review triage accepted: 111 / 507

- **77.02**: Classified 200 staging authenticated-executable SECURITY DEFINER overloads into financial/payment (21), admin/identity (36), booking/sports write (66) and other/utility (77) for **manual review prioritization**, not exploitability ranking. Source: [risk triage and execution-owner inventory](security/VSP_STAGING_PRIVILEGED_RPC_TRIAGE_2026-11-13.md).
- **77.03**: Verified the *staging* execution owner of all selected functions is the `postgres` role; callers are distinct from this effective execution role. 12 routines have no direct `auth.uid()/auth.jwt()` textual marker. This is **not** evidence of a vulnerable RPC: the actual authorization may be delegated.
- Total accepted: **111 / 618**. Remaining: **507**. Only catalog/definition-marker reads; no caller-side RPC invocation, real payment, account mutation, production change or main merge.
- Authorization, RLS, deployment, consumer and cross-user tests in 77.04–77.11 remain **open**, as do other staging validation tasks.

## 2026-11-13 — Staging dependency and migration audits: 109 / 509

- Audited staging SQL metadata and actual Supabase migration history (379 distinct entries), plus deployed `add_team_to_matchup_by_code(uuid,text)` function markers. No server mutation.
- **8 inventory/diagnostic tasks accepted:** `69.02`, `69.03`, `70.03`, `71.03`, `71.04`, `71.05`, `72.03`, `73.02`. Evidence: [staging relations/migration/credential requirements audit](security/VSP_STAGING_LEGACY_MIGRATION_AND_AUTH_DEPENDENCIES_2026-11-13.md).
- Key limits: legacy 1v1 table had 0 rows, newer 1v1 player table 16; challenge results had 0 rows. This is a schema/dependency review, **not** migration, duplicate-resolution or data-transfer acceptance. The current matchup RPC exposes the five-team limit marker with no legacy extra-fee marker; this is staging, not a verified production payment decision.
- Current canonical scoped count: **618 total / 109 VERIFIED / 509 open**. Previously 101/517. Group 56 stays cancelled. Do not infer that real-account, staging device, production security or payment tasks are complete.
- No `main` merge, production data reads or writes, or Auth settings changes.

## 2026-11-13 — Staging metadata audit acceptance batch: 101 / 517

- Canonical checklist recount: **618 tasks / 101 VERIFIED / 517 open**; group 56 remains retired. Previous verified count 89, this audit accepted **12 inventory/classification-only items**: `65.01`, `65.03`, `66.01`, `68.01`, `70.01`, `73.01`, `74.01`, `74.02`, `75.01`, `75.02`, `76.02`, `77.01`.
- Sources: [staging schema/queues/Auth/view grants](security/VSP_STAGING_SCHEMA_RISK_INVENTORY_2026-11-13.md), [full 200 RPC inventory](security/VSP_STAGING_PRIVILEGED_RPC_INVENTORY_2026-11-13.md), [44 initplan and 50 multiple-permissive advisor findings](security/VSP_STAGING_RLS_ADVISOR_INVENTORY_2026-11-13.md).
- Scope is *read-only metadata review on vsp-staging* `vtwgqyxglevcsxwdmhop`. No production access or database/auth mutation. **200 privileged callable RPC warnings are not 200 confirmed exploitable vulnerabilities.** Current historical-definer views are all `security_invoker=true`, but role and RLS negative tests remain open.
- Refund queues, `court_operating_hours` and `challenge_results` had 0 rows in staging. No data-driven refund, scheduling, challenge-result, authorization or production safety conclusions were accepted. Remaining related implementation/tests stay open.
- Current checkout, owner-analytics and anti-fabricated-scarcity code changes are not counted as accepted tasks pending an uncancelled passing CI run and scoped criteria evidence.

## 2026-11-13 — Analytics deduplication accepted (89/529)

- Verified uncancelled successful [Flutter CI run 43326492976](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43326492976) at `b19f7d9e`, covering `AnalyticsSessionDedupe` tests and repository architecture guards. iOS build and Android public smoke also green on that commit.
- **50.07** accepted: in-process venue-visit deduplication, test for repeat visit vs separate venues.
- **55.05** accepted: event-type-isolated deduplication tests and new-session behavior. Evidence: [acceptance report](VSP_ANALYTICS_DEDUPE_ACCEPTANCE_50_07_55_05.md).
- Scope stays limited to client-session logic, **not** cross-device counting, Firebase ingestion dashboards, offline recovery, or real-account staging acceptance.
- Recounted active detailed checklist: **618 total / 89 VERIFIED / 529 open**. Group 56 remains cancelled. No production or `main` changes.

## 2026-11-13 — Accepted 51.05 availability messages: 87 / 531

- Canonical inventory checked: **618 tasks / 87 VERIFIED / 531 open** (group 56 remains cancelled).
- **51.05** accepted for the *automated availability message contracts*: distinct no-schedule, all-past, all-booked, mixed booked/past, network/verification error and retry branches. Evidence: [acceptance scope](VSP_BOOKING_AVAILABILITY_COPY_ACCEPTANCE_51_05.md) and [Flutter CI run 43320006151](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006151).
- This acceptance does **not** close 83.01 actual stadium-operating-hours diagnosis, 83.04 calendar RTL/device tests, or server booking/concurrency test tasks.
- Separate analytics deduplication code and unit tests at commits `26e405e5` and `6e6210bf` are *not accepted* until an uncancelled passing CI run confirms them; 50.07 and 55.05 remain open.
- No changes to production or main.

## 2026-11-13 — Acceptance progress audited: 86 accepted / 532 open

- Canonical checklist recounted: **618 scoped tasks / 86 VERIFIED / 532 open**; group 56 (24 journeys) remains excluded.
- **59.07** accepted for a documented list of staging multi-role blockers and limits, not their resolution. Evidence: [staging blockers and performance budget](VSP_PERFORMANCE_BUDGET_AND_STAGING_BLOCKERS_2026-11-13.md).
- **60.01** accepted for defining explicit, measurable startup/navigation/availability/frame/memory/APK performance targets and measurement conditions; these targets remain **NOT MEASURED**. Tasks 60.02–60.09 are not accepted by implication.
- Independent prior acceptance: **58.06** Android log collection; acceptance count moved 83 → 84 before this 84 → 86 step.
- CI success for application commit `6ea1dc38`: [Flutter](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006151), [Android smoke](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006172), [iOS build](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006056), Account SQL security and Owner checkout security both successful. This does **not** close outstanding device, real-account or server-side payment test tasks.
- The accepted work in this batch is documentation/criteria, **not two completed feature implementations**. No `main` merge or production mutations.

## 2026-11-12 — Accepted Android smoke log collection (58.06)

- Verified [Android E2E Smoke run 43302703167](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43302703167) and [job 131480962116](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43302703167/job/131480962116), on application commit `366e75d8`: success. Decoded job logs confirm APK build and `+2: All tests passed!`; no fatal job-log error markers found.
- Evidence appended to [Android smoke verification](VSP_ANDROID_E2E_SMOKE_VERIFICATION_58.md); **58.06 is now VERIFIED** for scoped log collection. It does not imply credentialed login, booking, team invite or physical-device testing.
- Active task inventory recounted from canonical checklist: **618 total / 84 VERIFIED / 534 remaining**. Previously 83/535.
- No production modification or main branch merge.

## 2026-11-11 — Post-scope-removal execution: live venue verification safety

- Group 56 remains removed from the active task inventory: **618 total / 83 accepted / 535 open**.
- Found a booking-safety gap in stadium details: the unavailable-state check used `widget.stadium.isVerified` from route arguments, even after parsing a newer live `stadium` snapshot. A venue revoked in live data could continue to appear bookable.
- `7b61f6af` switches the availability gate to `stadium.isVerified`, retaining fail-closed booking behavior for loading/error/parse-failure. `1e19164c` adds an architecture regression assertion. **83.02 remains open** pending CI and server-side authorization/device validation.
- No changes to main, production Supabase, or payment logic.

## 2026-11-11 — Owner-requested scope removal: 24 E2E journeys (group 56)

- Removed the **entire nine-task group 56** from the active detailed task checklist at `cd9b2681`: 3 previously accepted documentation tasks (56.01, 56.02, 56.09) and 6 open tasks (56.03–56.08). This is **scope cancellation**, not completion.
- **Canonical new inventory: 618 total / 83 accepted / 535 open**, arithmetically verified against the checklist. 82 active groups remain (group number 56 intentionally retired; group identifiers are not renumbered).
- The historical 24-journey matrix is retained only as archived evidence; it is no longer an active delivery requirement. Other independently scoped Android smoke, UI/device, security, and booking tests remain active unless explicitly removed later.
- No application code, payment, production, or main-branch changes.

## 2026-11-11 — Flutter CI regression recovered, all core checks green

- Commit `c39e6110` completed **Flutter CI successfully twice** (runs `43076166273`, `43076157214`), **Android E2E Smoke success** (`43076166167`), **Account SQL security contracts success** (`43076166456`), and **Owner checkout security success** (`43076166066`). iOS compliance build was still running when checked.
- This confirms the architecture regression failure on `7edbd256` was resolved by `df47d64a`'s updated stale test assertion. It does **not** establish real-device acceptance for screenshot tasks 83.01–83.07 or a backend fix for the live stadium refresh cause.
- **Counter remains 86 accepted / 541 open / 627 total** until each task's complete acceptance criteria are met. No invented completion counts.

## 2026-11-11 — CI regression repair after stadium booking CTA guard

- Flutter CI on `7edbd256` failed at the **Architecture regression gate** (runs `43074919354` and `43074904681`); Account SQL security contracts and Owner checkout security passed. CI job metadata does not expose the failing assertion text.
- Source inspection identified a definite stale assertion in `test/architecture/stadium_details_safe_area_contract_test.dart`: it expected the former one-line `StadiumBottomBookingBar(stadium: stadium)` call, which the guarded booking-CTA implementation replaced with a multiline call and `bookingEnabled` predicate.
- `df47d64a` updates that assertion to the current guarded API. This is a **candidate cause** of the CI failure, not a claim that no other failures exist. Await rerun before accepting or closing any task.
- Counter remains **86 accepted / 541 open / 627 total**. No main, production, or payment changes.

## 2026-11-11 — 83.02 live stadium refresh booking safety

- **86 accepted / 541 open / 627 total** at this checkpoint. `01e94307` makes the stadium booking CTA explicitly disable-able; `a3bb534a` disables it while live stadium details are still loading, fail to refresh, or cannot be parsed. This prevents entering the booking flow from a stale route argument after a live refresh error, while preserving retry and stale-data information display.
- `930c2dee` adds architecture contract tests for stream-error/parse-failure guards and the disabled booking callback. **83.02 remains open**: actual stream failure cause, server-side booking authorization, recovery behavior and UI/E2E verification still need evidence. Do not claim backend booking protection from this UI guard.
- All changes are on `uxlp-44-implementation`, no payments/Supabase/main changes. CI on these commits not yet verified.

## 2026-11-11 — 83.04 calendar minimum date aligns with booking operational day

- **86 accepted / 541 open / 627 total: unchanged.** `e0524d85` anchors the monthly calendar's first bookable date and month navigation to the same `operationalBaseDate` used by the 14-day selector, rather than directly reading the device's `DateTime.now()`. `820ddd3c` wires the date from the selector into the modal.
- `8257ee34` adds an architecture regression contract for the date-boundary wiring. **83.04 remains open** pending actual date-availability markers, timezone rollover, and device calendar tests; this fix does not claim that a date with zero slots is bookable.
- No Supabase, payments, or main merge changes. CI on this new code is not yet verified.

# VSP — Live delivery ledger

Updated 2026-11-11. This ledger is the source of truth for **execution progress**, distinct from final release verification.

## 2026-11-11 — 83.04 calendar selected-date correctness (pending acceptance)

- **86 accepted / 541 open / 627 total: unchanged.** Commit `8d5e230` fixes 14-day strip selection to compare **year, month, and day**, not just month/day; removes the hard-coded comma in localized month/year header.
- Commit `37c45c6` adds architecture regression contract. **83.04 remains open**: calendar availability/closed-day indicators, accessibility, real Android RTL and CI on these commits still need acceptance.
- On previous head `fbac4a8d`, Account SQL security contracts and Owner checkout security completed successfully; Flutter CI, Android E2E, and iOS compliance were still in progress when checked. These are not new-commit test results.

## 2026-11-11 — 83.04 calendar availability copy (pending acceptance)

- **86 accepted / 541 open / 627 total: unchanged.** `f8478113` clarifies in the date selector that a selectable date is **not** confirmation of bookable slots; the actual slots appear after selection. The selector does not invent or color-code availability from missing data.
- `4efd268e` adds a static contract verifying the availability disclaimer and the calendar's existing past-date restriction.
- **83.04 remains open** pending Flutter CI, on-device calendar/RTL testing and an actual per-day availability data contract. The pre-edit branch `08620ed9` had passing Owner checkout and Account SQL security checks while Flutter, Android and iOS were still in progress.
- No DB, payment, or main changes.

## 2026-11-11 — 83.06 top SafeArea adjustment (pending CI and device layout acceptance)

- **86 accepted / 541 open / 627 total: unchanged.** `2eecf784` wraps the stadium-details main body in `SafeArea(bottom: false)` so the stream-error warning and carousel respect the system status-bar inset. The fixed booking bottom bar remains outside this wrapper.
- `53c9350c`: architecture contract for SafeArea, error warning, carousel and bottom booking bar. **83.06 remains open** pending Flutter CI and real-device short-height, large-text, tab scrolling and bottom-bar overlap tests. No design-token palette changes were made.
- At the pre-edit check, on commit `fbac4a8d`, Account SQL contracts and Owner checkout security had passed; Flutter, iOS and Android were still in progress. No claim that the latest edit has passed CI.

## 2026-11-11 — 83.07 ball rental without slot (pending CI and UI acceptance)

- **86 accepted / 541 open / 627 total: unchanged.** `8f817baa`: ball-rental toggle now requires a selected slot and not loading, with Arabic/English instruction to choose a slot first.
- `422eb7e3`: booking total excludes ball add-on when no slots are selected, including when a user clears previously selected slots; callback also rejects toggles without a slot or during loading.
- `10dc7a34`: architecture regression contracts for disabled toggle, zero-slot total and callback guard. **83.07 remains open** pending CI and real widget/date-switch/selection tests; no payment backend or Supabase changes.
- Previous branch commit `e7373587` passed Flutter CI (43070238156), Android E2E (43070248475), iOS build (43070248379), account SQL (43070248341), and checkout security (43070248344); the additional concurrent Flutter run was still in progress at the time checked. These results predate the new ball-rental code.

## 2026-11-11 — 83.05 mixed-language stadium labels (pending UI/CI verification)

- **86 accepted / 541 open / 627 total: unchanged.** Source commits `02d0848`, `e2af197`: stadium information tab translates only standalone known English rule labels (`Cleanliness`, `No Smoking`, `Punctuality`) when Arabic locale is active. Arbitrary owner prose and stored descriptions are not rewritten.
- `15434b3`: adds unit tests for Arabic known labels, unchanged free-form text, and unchanged English locale.
- **83.05 remains open** until Flutter CI and device RTL/long-description checks confirm actual rendering and clipping behavior. No Supabase, payment, or main merge changes.

## 2026-11-11 — CI green and 83.01 empty-state copy fix (pending device checks)

- **86 accepted / 541 open / 627 total: unchanged.** On commit `ecdfc0dd`, Flutter CI (runs 43062854125, 43062841461), Android E2E Smoke (43062854000), iOS compliance build (43062854302), Account SQL contracts (43062854398), and Owner checkout security (43062854012) all completed **successfully**. These are workflow results, not proof of real two-account booking authorization or payment amount scenarios.
- `70faedbd`: booking slot empty-state no longer states that the stadium does not open on that day; it states that no slots are configured and suggests another date/contact. The existing separate stream-error branch remains.
- `b3c9148c`: architecture contract covering neutral no-slots copy and separate error state. **83.01 remains open** pending real operating-hours/timezone/fully-booked vs error reproduction and CI on this new commit. **83.03 remains open** pending financial widget/server amount tests.
- No Supabase migrations, payment changes, customer data changes, or main merge.

## 2026-11-11 — 83.03 preselection financial summary UI fix (pending verification)

- **86 accepted / 541 open / 627 total: unchanged.** `83.03` remains open pending widget/Flutter CI and server-authoritative amount tests.
- Commits `7422496`, `a30526d`: before a time slot is selected, the deposit summary now says **“يُحسب بعد اختيار الموعد”** instead of falsely showing **0 EGP** as the remaining balance. The existing calculation after slot selection is unchanged.
- Commit `9bddcd3`: architecture regression contract for the placeholder and selected-slot wiring. No booking price formula, deposit rule, Supabase, payment backend, or main branch changed.
- Follow-up: verify UI rendering in Arabic/English and 1/2 slots plus ball add-on; confirm server-side final charges. Do not mark 83.03 accepted on a static contract alone.

## 2026-11-11 — Screenshot triage scope added; 86/627

- **86 accepted / 541 not yet accepted / 627 total**, previously 86/534/620. Added seven **open** screenshot-specific tasks **83.01–83.07**, no tasks accepted.
- [Evidence and source inspection](ux/VSP_STADIUM_BOOKING_SCREENSHOT_TRIAGE_2026-11-11.md), commit `fc64bd0`; [checklist update](VSP_80_DETAILED_SUBTASK_BREAKDOWN.md). Confirmed misleading no-slot copy, preselection financial display ambiguity, stale-data warning path and mixed-language screenshot; other visual observations require reproduction. No backend/payment root cause is claimed.
- **No runtime fix or staged/production validation** performed for these seven. No Supabase, payments, customer data, or main merge changed. Existing booking/RTL/design tasks remain distinct; acceptance needs screenshots + reproducible tests.

## 2026-11-11 — Owner booking direct-read server query narrowing (pending CI)

- **86 accepted / 534 not yet accepted / 620: unchanged.** This is a **CODE_DONE / pending automated and two-account staging verification** batch, not a completed 23.07/79.05 authorization test.
- `8389a655`: `fetchOwnerBookingsDirectlyStrict` now always scopes the REST query by `owner_id` **before** applying optional stadium IDs; a blank owner ID returns an empty list without querying. This removes the prior stadium-only query path. Post-query owner/stadium validation remains.
- `1f940083`: adds an architecture regression contract verifying owner scoping, stadium narrowing order and blank-owner handling.
- Follow-up required: Flutter CI, two-account authenticated Supabase/RLS checks and negative cross-owner reads. **No production database, payment, or main-branch changes.**

## 2026-11-11 — Task 78.07 storage role-matrix coverage; 86/620

- **86 accepted / 534 not yet accepted / 620**, previously 85/535. Exactly one new task closed: **78.07**, covering storage and file authorization in the role matrix.
- [Storage matrix and evidence limitations](security/VSP_STORAGE_ACCESS_MATRIX_78_07.md), source commit `8127c3b`: mapped sensitive private buckets, nine reviewed storage policy names, owner/admin boundaries, and explicit staging/production differences from batch-10 readbacks. This is **documentation/matrix coverage**, not proof of real file upload, download or cross-account E2E.
- **78.04–78.06, 79.01–79.08 remain open.** No Supabase migrations, storage object changes, production data/payment changes, or main merge in this batch.

## 2026-11-11 — Tasks 78.02 and 78.03 definition acceptance; 85/620

- **85 accepted / 535 not yet accepted / 620**, previously 83/537. Exactly two source-level documentation tasks closed, **78.02** (resource/operation inventory) and **78.03** (intended allow/deny role matrix).
- Evidence: [78.02 inventory](security/VSP_RESOURCE_OPERATION_INVENTORY_78_02.md), source commit `7d6f335`; [78.03 role matrix](security/VSP_ROLE_ACCESS_MATRIX_78_03.md), source commit `dd69596`. The matrix is a target contract **not** proof of deployed RLS/RPC/storage policy correctness.
- **78.04–78.07 and 79.01–79.08 remain open**, including real role tests, anonymous access, exception documentation, bucket-level checks and two-account tests. No code, production Supabase, payment or main merge changed in this batch.

## 2026-11-11 — Task 78.01 accepted; accounting 83/620

- **83 accepted / 537 not yet accepted / 620** (previously 82/538). Exactly one new checklist task closed: **78.01 — define player, stadium owner, and administrator roles**.
- [Role definitions and direct source references](security/VSP_ROLE_DEFINITIONS_78_01.md) document public `player`/`owner` registration, privileged admin/founder variants, and technical Supabase principals. Definition-only acceptance; this is **not** an RLS/RPC/staging authorization or E2E pass. Source document commit `9e1caf3`; checklist updated separately.
- The latest booking owner identity-scoping changes are **CODE_DONE pending CI** and do not close 23.07, 23.08, 79.05 or any other cross-account test. No production database, payments, pricing or main-branch change.

## 2026-11-11 — Batch11 legacy reporting/deletion rollout verified

- **82 accepted /538 pending /620**, no automatic additional closures. [Verified batch11](security/STORE_COMPLIANCE_BATCH_11_2026-11-11.md):7 legacy RPC corrections protect cross-account deletion and owner/admin financial/operational reports while preserving own privacy/deletion.8 known source variants; no business calculation/model/price changes.
- Native PG17.6 CI43020116975 SUCCESS:8 suites,17 weakened guards rejected,24 Python tests, source/inverse/helper-drift and staging-variant checks. Staging9 denial+9 allowed synthetic report calls pass and roll back;7/7 hosted definitions match. Production routine OIDs/owners/ACL/config preserved; invoker helper private. Advisor counts unchanged; no hosted customer-row deletion or financial mutation.
- Runtime code0ef4af8: Flutter43020117004, Android43020117129, iOS43020117237 and checkout43020117096 all SUCCESS. Not real OAuth/provider/signed-store approval. Remaining legacy booking/cash/cancellation/payout candidates are the next implementation batch, not accepted by this receipt.

## 2026-11-11 — Batch10 verified rollout and documentation acceptance80.07

- **82 accepted /538 not fully accepted /620**. Only newly closed task:80.07, [documented release acceptance policy](security/RELEASE_ACCEPTANCE_POLICY.md); runtime/store gates remain open. Corrected stale commission/deletion wording in LAUNCH_CHECKLIST without changing business code/prices.
- [Batch10 receipt](security/STORE_COMPLIANCE_BATCH_10_2026-11-11.md): blocked-admin self-unblock fixed and37 production RLS/storage policies guarded. Stage28 changed,1 pre-existing secure variant preserved,8 absent. Source fingerprints/metadata drift protection and inverse round trips verified.
- Native PG17.6 CI43012907874 SUCCESS:7 suites,11 weakened guards rejected,24 Python tests,37 policy definitions/metadata, guarded variant/helper-drift tests, replay/inverse/clean-fixture gates. Staging self-unblock/private storage denial plus own-profile/file and authorized-founder compatibility pass;0 remaining fixture accounts.
- Production37/37 definitions and trigger hash match; original policy OIDs/roles/commands/permissiveness/table ACLs and trigger OID/owner/ACL/config preserved. Three sensitive bucket flags read-only verified private. Advisor counts unchanged; no customer-row production tests.
- Tested runtime source f26bd2923d08e702fe72c02805ba63f54dca322e: Flutter43012907821 SUCCESS(1142/10skip,54 focused); Android43012907900 SUCCESS; iOS43012907858 SUCCESS(actual43.9MB unsigned app,SDK26.2,38 manifests,8 gate tests); checkout43012907769 SUCCESS. Web deletion page and updated JavaScript verified live after private site PR4/Vercel success. Exact-account/store/device/provider gaps remain.

## 2026-11-11 — Batches08/09 delivered; blocked-admin policy remediation underway

- **81 accepted /539 pending /620**. [Website delivery](security/STORE_COMPLIANCE_BATCH_08_2026-11-11.md): private PR4 merged after CI42968160243 passed28 tests, lint, types, build and audit0 (was11). Vercel SUCCESS. Real deletion fulfillment remains open.
- [Actual iOS build](security/STORE_COMPLIANCE_BATCH_09_2026-11-11.md): source65fead5, CI42967553018 SUCCESS on Xcode26.3/iOS SDK26.2. Runner43.9MB, correct app.vsp.sports identifier, iOS13 minimum,38 bundled privacy manifests,8 negative gate tests. Unsigned compilation is not signed/device/store verification.
- [New P0 findings and scoped fix](security/STORE_COMPLIANCE_BATCH_10_2026-11-11.md): staging synthetic blocked-admin self-unblock reproduced and rolled back;37 of42 admin-role policies require active-actor checks. Local7 SQL suites/11 weakened guards pass; native CI/hosted deployment pending at this entry. No production test rows.

## 2026-11-11 — Batches 06/07: dashboard delivery and active-admin RPC enforcement

- **81 accepted / 539 not fully accepted /620**; no duplicate closures for scoped fixes.
- [Batch 07 evidence and limits](security/STORE_COMPLIANCE_BATCH_07_2026-11-11.md): 40 admin routines reviewed, 32 source-checked guards deployed to staging and production. 192 staged unauthorized calls rejected; three real RPC positive fixtures roll back cleanly. Production 32/32 fingerprints and original OIDs/ACLs/owners/config verified read-only.
- Native PG17.6 run 42965386816 SUCCESS: six SQL suites, seven weakened guards rejected, 18 Python tests, idempotent replay/source-drift and fresh-database gates. Existing security-advisor counts unchanged. No customer-row production test or pricing/model change.
- Private dashboard PR #9 merged at 91964ad after CI 42963826004 (53 tests/audit zero/build) passed. Vercel status SUCCESS and Google-only sign-in rendered live; real OAuth/post-login journey remains open.
- App source 379adb4; App main remains unchanged. These are partial implementation/verification contributions to existing Phase 8/9 tasks, not release acceptance. Follow-up source-checked inverse round trip is recorded by its CI.

## 2026-11-11 — Batch 05: client-role guard, native SQL tests and production deployment

- **81 accepted /539 not fully accepted /620**. Accepted additions: 80.01 defined change-triggered security contracts; 80.02 added profile RLS tests; 80.03 added lifecycle/conversation RPC tests. These are test-foundation tasks, not a claim that all database policies/RPCs or the entire release are verified.
- [Implementation, policy links, exact limits and deployment evidence](security/STORE_COMPLIANCE_BATCH_05_2026-11-11.md). Source `3e371a5`: one additive invoker guard blocks privileged client-role INSERT and direct role UPDATE, including admin-to-founder escalation, while preserving existing authorized role RPCs and legacy ordinary profile creation. Staging and production deployed after owner's blanket execution approval; no customer rows targeted.
- Native PostgreSQL [42958578778](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42958578778) SUCCESS: 5 transactional suites, 5 intentionally broken guards rejected, restored baseline, 9 Python target-safety tests and refusal to reinstall an existing DB. No hosted credentials/customer data in CI.
- Flutter push 42958578707 SUCCESS: 1142 passed, 10 skipped; Android PR 42958584079 SUCCESS with actual APK permission inspection and six gate tests; checkout 42958584012 SUCCESS. These are automated contracts, not real OAuth/payment-provider/24-journey proof.
- Production readback: role-guard body matches source, invoker mode, trigger enabled, client execute revoked; advisors unchanged (197 definer-callable warnings + deferred password warning). Other grant revocations and account/cancellation RPCs from prior batches remain staging-only; no blanket production migration replay or main merge.

## 2026-11-11 — Final verification receipt and accepted migration comparison

- **Current accepted: 78 / 620; not fully accepted: 542**. Newly accepted this series: 76.01 view inventory and 71.02 full textual collision comparison. These two audit/comparison results are not two shipped features.
- Application source `906846f` final push checks: Flutter CI [42954730210](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42954730210) SUCCESS — analyze, 54 focused privacy/account cases, 59 architecture checks, then **1142 passed / 10 skipped** in the full suite. Focused and architecture cases are included in full, not extra unique tests.
- Android [42954730199](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42954730199) SUCCESS — build, two public/auth smoke checks, six Python permission-gate tests and actual compiled APK policy gate. Checkout [42954735544](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42954735544) SUCCESS — 39 hermetic cases. PR duplicate checks also passed; not extra coverage.
- All three changed staging RPC bodies read back and matched repository function bodies exactly. All three transactional staging SQL suites passed after final deployment; no actual two-device/JWT concurrency claim.
- [71.02 comparison](security/MIGRATION_CONTENT_COMPARISON_2026-11-11.md): 314 forward SQL files, 19 collision groups / 79 files / 296 pairs, zero byte-identical pairs; eight rollback files excluded. All pair byte results independently cross-checked. Does not establish safe replay or execution order.
- Eight app improvements plus two staging trigger repairs in batches 03/04; no additional feature count for tests/tooling. Production not changed. Privileged profile insertion proved only on synthetic staging fixtures; production table grants remain pending approved remediation and client coordination.
- Release remains NOT READY: external client inventory and production approval/rollout, provider sandbox and actual identities, full deletion/retention, iOS and store-console acceptance remain open. This is a batch verification receipt, not closure of 542 tasks.

## 2026-11-11 — Fourth implementation batch: server-owned profile provisioning

- [Four additional application corrections and verification boundaries](security/STORE_COMPLIANCE_BATCH_04_2026-11-11.md): direct profile INSERT/DELETE removed from authenticated clients, atomic server provisioning uses real Auth state and existing owner trial policy; no phantom local profile/role/completion.
- New source includes 14 Flutter cases. All three staging rollback scripts passed after deployment, including existing 17 lifecycle/chat and 11 sensitive-update checks. Final app source 906846f checks passed; exact runs/counts in the receipt above.
- Production grants inspected read-only; no production exploit/mutation. Applying these changes there requires explicit review/approval and coordination with all external clients.
- Accounting: **77 accepted / 543 not fully accepted / 620**; one new inventory closure (76.01), no automatic full journey closures from these partial corrections.

## 2026-11-11 — Accepted inventory task 76.01

- **77 accepted / 543 not fully accepted / 620 total**: 76 historical accepted checklist entries plus one newly accepted inventory task. This is a documentation/audit result, not one additional shipped feature.
- **76.01 VERIFIED**: all nine public views inventoried in each environment using read-only schema metadata, definitions and SELECT privileges; current count supersedes the historical “four” in task text. [Evidence and limits](security/VIEW_INVENTORY_2026-11-11.md). Remaining 76.xx permission design, runtime isolation and release acceptance stay open.

## 2026-11-11 — Third compliance batch: account cancellation and chat authorization

- [Exact changes and evidence](security/STORE_COMPLIANCE_BATCH_03_2026-11-11.md): **4 application corrections + 2 staging security trigger-binding repairs**. Application commit `3662402`.
- Application checks: Flutter 42939496320 SUCCESS — 1128 passed, 10 skipped (40 focused privacy/deletion cases also included in full suite); Android 42939496341 SUCCESS including actual APK gate and six Python tests; checkout 42939496233 SUCCESS — 39 isolated cases.
- Staging: new atomic cancellation RPC and conversation membership guard deployed. 17 rollback-fixture checks passed before/after deployment and after trigger repairs. Eleven trigger enforcement/allowed-edit checks passed. No real-token multi-device race claim; explicit registration completion-first case is verified.
- **76 historical accepted / 544 not fully accepted / 620 unchanged.** Partial SEC-01/02/04/07 and Phase 9 consistency evidence; no full-baseline subtask silently closed.
- Staging binding drift was verified and repaired against existing function definitions. Production inspected read-only for those definitions; no production mutation/main merge. Remaining: direct profile INSERT/DELETE audit, full environment parity, full deletion/privacy retention, actual OAuth/device/payment/iOS/store acceptance.

## 2026-11-11 — Second store compliance implementation batch

- [Ten app corrections, exact scope and evidence](security/STORE_COMPLIANCE_BATCH_02_2026-11-11.md); application source checkpoint `e862fbb`. Code, tests and APK permission gate updated; no schema or production mutation.
- **Final checks SUCCESS at e862fbb**: Flutter CI 42930897576 — 32 focused cases and 1120 passed, 10 skipped in the full suite; Android smoke and compiled APK permission gate 42930890192, including six Python gate tests; Owner checkout security 42930897573 — 39 isolated cases. No broad media/storage/advertising permissions or mandatory camera/GPS in the verified APK. Earlier failures, corrections and cancelled superseded runs remain documented.
- Contributions: partial 03.02/03.04/03.05, 04.06, 05.04, 12.03, 20.02; SEC-01/03/04/08 and Phase 9 failure/race handling. These checks do not close every screen or live upload/deletion acceptance condition.
- **Core accounting unchanged: 76 historically accepted / 544 not fully accepted / 620 total.** Ten defects corrected is not ten closed baseline subtasks. One introduced dialog layout regression and test-fixture/timing corrections were fixed and recorded without inflating the delivered improvement count.
- Remaining: actual photo upload/camera/device variants, valid multi-account staging journeys, atomic server cleanup/deletion and retention, OAuth/web deletion, payment sandbox, iOS/archive/store metadata. Current data safety/readiness is not certified.

## 2026-11-11 — Unified plan, first security implementation batch

- Code commit: `00b530fcf5de6ed44324c36f0e623dc572ba7e18`; [seven concrete corrections and evidence](security/STORE_COMPLIANCE_BATCH_01_2026-11-11.md). No new full baseline-subtask closure: **76 historical accepted / 544 not fully accepted / 620 total**. This batch is code execution, not seven documentation closures.
- Existing task contributions: 25.03/25.06 and 30.03/30.05/30.07/30.08, 79/80; SEC-01/03/04/06/08/10 and INT-03/REL-03. They remain IN_PROGRESS until their complete scope, including real staging identities/provider sandbox, is proven.
- **Final checks SUCCESS at `daae560e`**: Flutter CI 42924535090 — 1088 passed, 10 skipped, including all 26 deletion tests; Owner checkout security 42924534900 — 39 isolated request/payment tests; Android E2E Smoke 42924534915. Isolated tests use mocked DB/provider transport, not real payments or real JWT identities. Initial failed test fixtures/assertions and their fixes are retained in the linked report.
- Staging checkout/status functions updated with verify_jwt=true; source readback matches; four actual no-auth/invalid-token requests rejected 401 and two CORS preflights passed. Webhook source change was not deployed; no live signed callback acceptance claimed.
- No production, prices, subscription model, migration or main merge changed. APK/iOS archive not built. Full CODE_DONE/BLOCKED counts still require row-by-row reconciliation; no guessed totals.
- Added and ran read-only `python3 scripts/verify_task_accounting.py`: 620 unique IDs, 82 parents, 76 accepted historical checklist entries, 544 not accepted, zero ID/counter errors. It does not certify the evidence behind historical acceptance or close any task automatically.

## Fixed scope and accounting

- Baseline: **82 parent items, 620 subtasks** from `VSP_80_DETAILED_SUBTASK_BREAKDOWN.md`. Never silently increase this denominator.
- Historical inventory snapshot (2026-11-11): **83 verified; 535 not yet accepted** (618 tasks total). This is not a current tally.
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
| 16.02 | VERIFIED | Categorization tests, CI `42825931860` | Pending/upcoming/history, grace boundary, payment progress, overlap displacement and ordering |
| 16.03 | VERIFIED | Player details widget test `d18af67`, CI `42827626171` | Booking reference, exact total/deposit/remainder, payment/refund state and Arabic cancellation reason |
| 16.04 | VERIFIED | Realtime lifecycle tests, CI `42825931860` | Initial load, updates, cancellation, reconnect retention and transport-error preservation |
| 16.05 | VERIFIED | Categorization/cancellation tests, CI `42825931860` | Abandoned unpaid checkout hidden; refunded cancellation retained in history |

**Current audited counter: 76 / 620 completed, 544 remaining.** Phase 10 closes 14 analytics/instrumentation subtasks; booking-history tasks 16.02–16.05 add four current-head verified closures. Historical closures remain recorded below. A documentation task can close with reviewed source evidence; runtime tasks require their own acceptance evidence.

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

## Notification legacy categories and active-chat foreground routing — 2026-11-09

- Added normalized legacy notification type aliases for booking reminders, match-start reminders and challenge results. Owner and player category opt-outs apply consistently regardless of casing, dashes or spaces.
- Fixed foreground suppression so opening one chat no longer hides all incoming chat alerts: only an alert for the active booking chat is suppressed; other chats still obey preferences.
- Added regression coverage for type aliases. **58/620 verified, 562 remaining**. Pending CI, not an end-to-end notification delivery completion.
- No production database/payment changes or main merge.

## Notification foreground widget regression repair — 2026-11-09

- GitHub Flutter CI run `42674989384` analyzed and passed architecture gate but failed 1 of 1027 executed tests (1026 passed, 10 skipped). The failing `notification_ui_helper_test.dart` widget lacked the `AuthProvider` dependency now required by foreground preference checks.
- Updated widget fixture to supply `AuthProvider`, preserving production role-aware filtering instead of weakening it. Android E2E Smoke on commit `256f0e4` succeeded (runs `42674989320`, `42674997334`).
- Await fresh CI on this commit before declaring regression resolved. **58/620 verified, 562 remaining**. No main merge or production database changes.

## Notification private-booking access guard — 2026-11-09

- Both notification chat and booking navigation now require the signed-in account to be the booking owner, creator, or joined player before opening booking-related screens. The chat flow also rechecks account identity after async chat creation to prevent cross-account navigation after sign-out/switch.
- Added participant/stranger/null-user regression test for the pure access helper. This is a client guard only; RLS remains the authoritative security boundary.
- Prior CI on `256f0e4` isolated one foreground notification widget fixture failure (1026 passed/1 failed/10 skipped), with Android smoke success. Follow-up `d647703` CI still running at inspection.
- **58/620 verified, 562 remaining**; no main merge or production DB/payment changes.


## Phase 10 conversion analytics verification — 2026-11-09

- Current source commit `4a2893e9` passed Flutter CI [run 42685956248](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42685956248): analyzer, 56 architecture tests, and the full suite (**1033 passed, 10 skipped**). Duplicate current-head Flutter run `42685967807` also completed successfully.
- Android public/auth smoke [run 42685967573](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42685967573) passed on the same commit. It validates startup/onboarding/login navigation only, not booking/payment completion.
- Repaired the foreground notification widget fixture with `ChangeNotifierProvider<AuthProvider>`; production preference enforcement was not weakened.
- Added the canonical 13-event `VSPAnalyticsEvents` dictionary, privacy filtering, session dedupe, successful player/owner signup, confirmed booking completion and the existing venue/match/team/subscription funnel hooks.
- Automated contracts verify exact event names, Firebase-safe schema, property privacy, journey-boundary placement, absence of booking completion from pre-success confirmation, and absence of paid subscription activation from checkout initiation.
- Updated `CONVERSION_ANALYTICS.md`, Phase 10 status/report and experiment baseline. No conversion uplift, D7/D30 retention or revenue change is claimed without real consented data.
- Closed **50.01, 50.02, 50.03, 50.06, 51.01, 51.02, 51.03, 52.02, 52.07, 55.01, 55.02, 55.03, 55.04 and 55.07**.
- **Progress: 72/620 verified, 548 remaining.** No production database, RLS, payment backend, pricing, `main` merge or APK build.



## Deferred-verification implementation batch — 2026-11-09

Owner instruction: continue implementation and defer consolidated tests. The following changes are **CODE_DONE / Pending Verification** and do not increase the verified counter.

- `86f1f52`: booking categorization now preserves both `confirmed` and `upcoming` lifecycle states, includes expired/no-show history, orders future bookings chronologically and history newest-first without mutating input.
- `09a8e6a`: player bookings now labels the pending section explicitly instead of mixing pending cards between upcoming and history.
- `daefffa`, `398e0d6`: booking details now shows the reference, total, payment method, honest payment state, amount paid, remaining balance and cancellation reason from the existing booking record. It does not infer a successful payment from checkout initiation.
- `4bf31c2`, `1131de9`: invalid operating-hours data no longer appears as a legitimate empty schedule; the owner sees a retryable bilingual configuration error while genuine no-hours days keep the empty state.
- `a9aa62a`: team match-history load failures no longer masquerade as “no previous matches”; loading and retry states are explicit.
- `42f0e89`, `1824f19`: the existing one-hour matchup code is now described honestly as temporary in Arabic and English; the modal supports selection, semantics and copy confirmation only after clipboard success. This does **not** claim the persistent rotating consent-code contract in task 82.
- `369f23a`: a failed 1v1 champion verification now surfaces a retry state rather than silently implying the team has no champion.
- Candidate mapping: **03.02–03.05, 04.01–04.02, 16.02–16.04, 16.06, 22.01, 22.04, 22.07 and 81.07–81.09 remain IN_PROGRESS/CODE_DONE** until their complete acceptance scope and deferred regression/device checks are performed. Task 82.02–82.08 remains blocked on a server-authoritative consent-code lifecycle; the client does not mislabel the legacy expiring invite as that feature.
- **Verified progress remains 72/620; 548 remaining.** No production Supabase/schema/RLS, payment backend, pricing, permissions, `main` merge or APK action.



## Team invitations and active-team implementation — 2026-11-09

Owner authorized continuous execution; consolidated tests remain deferred. These changes are **CODE_DONE / Pending Verification** and do not change the verified counter.

- `3a75cd7`: invitation responses are scoped to the active account across async gaps; stale-account success/error feedback is suppressed and expired/already-handled failures are explained honestly.
- `88c3aed`, `12f8ea6`: a successful invitation acceptance refreshes the parent membership/team state without misreporting a subsequent view-refresh failure as an acceptance failure.
- `886d3eb`: repository exposes every verified team membership in deterministic order rather than relying on unordered “first row” selection.
- `d37350c`, `84877ad`, `c8bca9f`: centralized account-scoped active-team preference and added a Flutter-3.32-compatible selector when a player belongs to multiple teams.
- `2b10dfc`: team management honors the selected active team.
- `bc6391b`: challenge creation and its final verification resolve the same selected active team from current verified memberships.
- `4d70f91`: localized the invitation action tooltip and suppresses tab haptics when reduced motion is requested.
- Candidate mapping: **17.01–17.05, 17.08 and 18.01–18.06 are CODE_DONE/IN_PROGRESS** pending the deferred regression, two-account staging and device checks. Server RLS/RPCs remain authoritative.
- **Verified progress remains 72/620; 548 remaining.** No production schema/RLS/payment/pricing change, no `main` merge and no APK action.



## Venue schedule and media hardening — 2026-11-09

These changes are **CODE_DONE / Pending Verification** under the deferred-test instruction.

- `601ee50`: enabling split-shift hours now requires complete, non-overlapping closure intervals inside the operating window; half-configured breaks can no longer silently become bookable.
- `727c2ca`, `bb74a33`: stadium media uploads reject empty, oversized (>10 MiB) and non-JPEG/PNG/WebP files before storage upload, preserve a matching safe extension and contain validation/read failures.
- Candidate mapping: **20.02, 20.05, 20.07, 22.01, 22.02, 22.04 and 22.06 are CODE_DONE/IN_PROGRESS** pending deferred storage, widget, regression and real-device verification.
- **Verified progress remains 72/620; 548 remaining.** This is client defense in depth; Storage policies remain authoritative and were not changed.


## Next execution queue

1. 22 — operating hours/closures: finish one end-to-end owner-to-player scheduling flow.
2. 26 — booking overlap prevention: inspect server guarantees; do not change production schema without approval.
3. 03 — error/empty/retry states, then 16 — booking history.
4. 81–82 — team achievement badges and challenge consent code.
5. 56–60 — consolidated tests, security, release verification **at the end**.

Do not use the old `80-item` release tracker as the denominator for the 82-item/620-subtask inventory.


## Owner onboarding and stadium submission hardening — 2026-11-09

These changes are **CODE_DONE / Pending Verification** under the owner's deferred-test instruction.

- `314b04b`, `5e84166`: stadium create/update now rejects stale-account submissions, malformed/non-finite commercial values, invalid coordinate pairs, excessive deposits, invalid ball pricing, missing create images and duplicate/blank media URLs instead of silently substituting zero/default values.
- `4386fbc`: owner onboarding normalizes and validates Egyptian mobile numbers, prevents duplicate submission and rejects navigation if the signed-in account changes during the async completion.
- `ad73563`: facility onboarding completion/document actions are single-flight and retryable; failures no longer navigate as success. Copy now says documents are sent for review and does not promise a verified badge before an authoritative approval.
- `3bb68b7`, `490d40e`, `da74333`: legacy stadium records are parsed defensively, corrupt closure/image fields are ignored, edit ownership is retained and checked before data is exposed in the edit form, and duplicate saves are blocked. Repository/RLS checks remain authoritative.
- Candidate mapping: **19.01–19.05, 20.01–20.07 and 21.01–21.08 are CODE_DONE/IN_PROGRESS** pending deferred regression, two-account authorization, storage and device verification. This does not close subscription purchase or admin approval journeys.
- **Verified progress remains 72/620; 548 remaining.** No production Supabase/schema/RLS, payment backend, price, plan, `main` merge or APK action.


## Owner schedule defensive rendering batch — 2026-11-10

- `0656e1e`: match owner calendar bookings by actual local date-time overlap, preventing same-clock-time bookings on unrelated days from occupying slots.
- `a5e5db3`, `4741df9`: reject malformed, incomplete, out-of-hours and overlapping closure intervals; use the existing retryable configuration-error sentinel rather than displaying those intervals as free.
- `6910bee`: do not mark cancelled/expired bookings as occupying owner-calendar slots.
- `5bfcc9c`, `4595ece`: detect overlapping distinct active booking IDs in a displayed half-hour slot and fail closed; tolerate duplicate rows for the same booking ID.
- These are client-side schedule presentation safeguards only, not authoritative double-booking prevention. Server exclusion constraints, transactional booking paths, timezone handling, staging/device acceptance and CI still require verification.
- All six commits are **CODE_DONE / Pending Verification**. **Verified progress remains 72/620; 548 remaining**. No production schema/RLS/payment/pricing changes, main merge or APK.


## Booking list categorization and manual synchronization — 2026-11-10

- `41b4be6`: player pending-checkout categorization suppresses pending bookings whose **full time interval** overlaps another confirmed/upcoming booking for the same stadium; previously only identical start times were compared.
- `fe9851f`: manual-booking merge preserves distinct booking IDs even when start times coincide, avoiding silent data loss in owner display; backend overlap resolution remains separate.
- `94e442e`: local expired manual bookings are not resurrected after synchronization.
- Mapping: booking history/pending states and owner manual-booking integrity (Tasks 16 / 26 / 27); these are **partial fixes / IN_PROGRESS**, not newly closed baseline subtasks.
- Verification pending: Flutter analyze/tests, duplicate/replay scenarios, checkout grace periods, cancellation/refund cases, owner and player acceptance, server-side concurrency. No claim of authoritative double-booking prevention.
- Accounting: **72 VERIFIED / 620 total / 548 not accepted**. Nine source fixes since handoff, with seven additional commits including this ledger update. No release verification was performed.


## Booking history visibility fixes — 2026-11-10

- `4ceb2c3`: unpaid online pending checkouts beyond the 10-minute grace period are retained in booking history instead of vanishing from active and historical lists.
- `d512830`: pending checkouts displaced by a distinct confirmed overlapping booking are shown in history, not lost from both pending and history.
- Mapped to **16.02 booking status buckets** and **16.05 cancelled/abandoned booking behavior**, both **IN_PROGRESS** until all acceptance criteria, source synchronization and user journeys are verified.
- Code changed, tests and runtime verification deferred. **Verified 72/620; remaining 548**. No server-side availability guarantee claimed.


## Truthful owner subscription presentation and checkout guards — 2026-11-10

These changes are **CODE_DONE / Pending Verification** under the deferred-test instruction.

- `7d827dc`, `1cbbe8f`: removed a hard-coded 1000 EGP price, the unmeasured “double your profits” promise, and hard-coded Pro stadium/benefit claims from teaser and upgrade surfaces. Owners are sent to the live plan view for current prices, limits, features and renewal choices.
- `8569557`, `5b37ba7`: live plan records are rejected when prices, trial duration, stadium limits or feature data are malformed; decimal monetary values are preserved instead of silently rounded.
- `71b1d25`: subscription order billing periods are restricted to monthly/annual and checkout URLs must be valid HTTPS before external launch.
- `d54b6c8`: trial activation and checkout creation are single-flight and bound to the active authenticated owner across async boundaries.
- `d9a3b1b`: clarified the verified subscription model (no per-booking commission) and replaced internal “atomic” terminology with understandable conflict-safe booking copy.
- Candidate mapping: **25.01–25.08, 52.03–52.06 and Phase 10 UX-06/UX-07 are CODE_DONE/IN_PROGRESS** pending deferred widget, two-account, sandbox checkout and renewal/cancellation-source verification. No conversion or revenue uplift is claimed.
- **Verified progress remains 72/620; 548 remaining.** No production pricing, payment backend, Supabase schema/RLS, `main` merge or APK action.


## Public venue trust, review identity and owner data isolation — 2026-11-10

These changes are **CODE_DONE / Pending Verification**. Consolidated tests remain deferred.

- `78195f4`, `803cb8d`, `c75d466`: all public stadium list, nearby and detail-stream paths now exclude deleted, blocked and unverified stadiums; a removed/unpublished record can no longer remain visible through stale detail fallback.
- `2864f72`: facility onboarding renders stadiums in owner mode so review state and edit controls are not confused with player favorites.
- `19e4a41`, `ff8cb75`, `c4ce3e9`: reviews are limited to authenticated 1–5 star submissions with bounded comments, duplicate actions are suppressed, account-switch success feedback is contained, and malformed stored ratings/timestamps are not presented as social proof.
- `94693ac`: prepared migration `20261110010000_bind_stadium_reviews_to_auth_user.sql` to bind the privileged review RPC to `auth.uid()`, require a completed booking, revoke default/public execution and grant only authenticated execution. **Migration is committed but not applied to production and not database-verified.**
- `c4adee3`, `1aa537b`: venue, hourly and deposit amounts preserve decimal values; absence of a deposit no longer falsely claims that cash payment is available.
- `1f118fd`, `e79f45e`, `00a74a7`: owner venue, booking, financial and transaction reads are scoped to the active account; transaction realtime now includes an explicit `user_id` filter; cash/manual booking and maintenance mutations reject cross-account owner IDs and malformed values before RPC invocation. RLS/RPC authorization remains authoritative.
- Candidate mapping: **14.08, 20.04, 20.06, 21.04–21.05, 53.02, 77.03–77.04, 77.07, 77.11 and 79.02–79.05 are CODE_DONE/IN_PROGRESS** pending deferred Flutter, two-account, staging database, advisor and migration verification.
- **Verified progress remains 72/620; 548 not accepted.** No production migration was applied, no payment/pricing policy changed, no `main` merge and no APK action.


## Exact financial presentation and truthful rescheduling — 2026-11-10

These changes are **CODE_DONE / Pending Verification**. They correct client presentation and do not alter prices, calculations, gateway behavior, refunds, subscription rules or the database.

- Added the shared `VSPMoneyFormatter` contract and replaced integer truncation across player booking/payment summaries, owner booking cards, quick/manual booking forms, cash collection, owner ledger/payouts, operational dashboards, transactional notifications, WhatsApp receipts, cancellations and tournament/league entry and prize surfaces. Finite values retain up to two decimal places with trailing zeros removed; invalid non-finite values render as unavailable rather than a misleading amount.
- Added focused formatter tests, but they remain unexecuted under the owner's consolidated-test deferral.
- `97106fe`: corrected reschedule copy to match the authoritative RPC state machine. Declining a proposed time keeps the original booking; it does **not** cancel the booking or promise a full refund. Slot-conflict copy now states that the original booking remains unchanged, and async feedback is bound to the initiating account.
- `764b1b5`, `3125164`, `646cb75`, `790031c`: unknown booking-save and cancellation failures no longer expose PostgREST/SQL relation, constraint or infrastructure details; known policy failures and short safe server messages remain actionable. Regression contracts were added but not run.
- `6957d55`, `9a34dc6`, `6a24d8f`: owner reschedule requests and player responses are single-flight per booking, contain thrown repository failures, and present retryable feedback without stale success claims.
- Candidate mapping: booking price clarity, owner financial visibility, cancellation/refund transparency, tournament pricing, Phase 10 truthful scarcity/trust and rescheduling lifecycle tasks are **CODE_DONE/IN_PROGRESS** pending consolidated Flutter, widget, two-account, sandbox-payment and end-to-end verification.
- **Verified progress remains 72/620; 548 not accepted.** No production Supabase/schema/RLS/payment mutation, `main` merge, final test run or APK action.


## Availability, account-scope and reporting safeguards — 2026-11-10

This batch is **CODE_DONE / Pending Verification** under the consolidated-test deferral.

- `13318e4`, `6dd0ee7`: stadium-slot RPC failures are no longer converted into an empty schedule. Initial failures reach the retryable error UI; later polling failures retain the last verified snapshot. The pre-submit availability check therefore fails closed instead of treating a network error as proof that a slot is free.
- `214cc38`, `237ea19`, `291a7e1`: booking chat, match chat, public-match join/leave and booking/match report results are bound to the account that initiated the async action. Switching accounts while a request is in flight suppresses stale navigation and feedback.
- `b494407`, `87dece8`, `0e6e910`, `2c1dd81`: report submissions require the active authenticated reporter, supported target types and bounded reason/details, redact backend errors, and suppress duplicate in-flight submissions. The server `create_report_atomic` participant checks remain authoritative.
- `70095b6` through `fbe29c6`: remaining high-impact player price surfaces for ball rental, championship cards/details, Book Tonight, team-league payment choices, checkout totals and stadium add-ons now use the shared exact-money formatter instead of integer truncation.
- Added architecture contracts for availability fail-closed behavior and report client guards. They were updated but not executed.
- Candidate mapping: **03 error/retry states, 06/13 booking lifecycle, 16 history/visibility, 20 communication/content safety, 26 double-booking defense, 30–31 payment/refund clarity, 53 privacy and Phase 10 truthful price/trust tasks are CODE_DONE/IN_PROGRESS** pending consolidated tests and end-to-end acceptance.
- **Verified progress remains 72/620; 548 not accepted.** No production database, RLS, payment, pricing or permission change; no `main` merge, final test execution or APK build.


## Overnight scheduling and public-match action integrity — 2026-11-10

This batch is **CODE_DONE / Pending Verification**.

- `eafe8ea`, `bc35553`, `457aed6`, `ab9bd11`: owner manual-booking checks now compare real local intervals across midnight, detect overnight closures after midnight, include next-day bookings in duration/overlap checks, ignore expired holds and scope conflicts to the selected stadium.
- `9408408`, `aea5486`: added regression scenarios for overnight closing times, after-midnight bookings, overnight breaks, unrelated stadium bookings and expired holds. Tests remain deferred and unexecuted.
- `340ce10`, `48e4fca`, `487b893`, `be94aca`: public-match join/leave errors are reduced to stable safe codes, raw backend errors are not exposed, duplicate in-flight join/leave actions are suppressed, and public leave uses the guarded provider with actionable host/ended-state copy.
- `a67f423`, `1f30925`: successful atomic join, leave and participant-removal mutations are no longer reported as failures merely because optional public-feed enrichment or notification delivery failed afterward. Secondary notification work is best effort and cannot reverse the authoritative action result.
- `9007dce`, `619f403`, `d23586c`: architecture contracts guard single-flight actions, sanitized failures and mutation-before-enrichment ordering. They were written/updated but not run.
- Candidate mapping: **07 group booking, 13 booking management, 19 pickup matches, 20 notifications, 22 operating hours and 26 overlap prevention are CODE_DONE/IN_PROGRESS** pending consolidated Flutter, integration, two-account, staging and device verification.
- **Verified progress remains 72/620; 548 not accepted.** No production Supabase/schema/RLS/payment/pricing change, `main` merge, final tests or APK.


## Current-head CI remediation and verification — 2026-11-10

- Fixed unsupported chained filters on Supabase stream builders and restored the required stadium-owner test scope so the branch analyzes on Flutter 3.32.8.
- Booking categorization now keeps paid, deposit-paid and refund-in-progress pending records visible beyond the unpaid checkout grace period for both players and owners. Old unpaid online checkouts age into history; ended records remain historical.
- Empty stadium-break placeholder rows remain optional, while half-configured, out-of-hours, inverted or overlapping intervals fail validation.
- Replaced a formatting-sensitive team-invitation source assertion with a whitespace-tolerant contract without weakening the behavioral checks.
- Bounded Flutter test concurrency to two workers after a hosted runner exhausted its thread quota, and enabled cancellation of superseded branch validations.
- Flutter CI [run 42827626171](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42827626171) passed analyzer, architecture regression gate and the full suite: **1059 passed, 10 explicitly skipped**.
- Android public/auth staging smoke [run 42827626122](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42827626122) passed onboarding/login on the same head.
- The green regression run verifies the committed automated contracts but does not replace two-account staging, real-device, Paymob sandbox, email inbox, FCM delivery or production-policy checks. **Verified progress remains 72/620; 548 not accepted** until each subtask's complete acceptance scope is evidenced.
- No production database/RLS/payment/pricing change, `main` merge or APK build.
