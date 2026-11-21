# VSP release acceptance policy — task80.07

Effective for VSP execution from2026-11-11 (Cairo). This is the documented engineering release policy, not a declaration that its gates currently pass.

## Scope and authority

This policy links existing Phase8 SEC-01–11, Phase9 integration/reliability, the24 journeys, [launch checklist](../../LAUNCH_CHECKLIST.md) and the fixed620-task ledger. It does not add duplicate tasks. Owner standing execution approval is already recorded; routine fixes/tests and proven scoped rollouts do not need another permission request. The venue-owner subscription model and prices remain unchanged. Authorization does not replace missing store access, signing credentials or technical evidence.

## Two separate decisions

A scoped backend security correction may ship before complete mobile-store readiness if all of these hold: exact source/metadata reviewed; isolated native PostgreSQL contracts including negative controls pass; applicable staging behavior and compatibility pass; source/metadata drift aborts instead of overwriting; a tested inverse/rollback exists; no customer rows are used as test targets; production definition/ACL readback and advisor comparison are recorded. New findings or drift require investigation, not automatic retry or a blanket migration replay. A failed migration is not marked deployed.

A store release, App main integration or production distribution of the complete application requires the full relevant gates below. A green backend batch, website deployment, unsigned iOS build or task-count increase does not authorize calling the application ready. Actual App Store/Play decisions remain external outcomes.

## Required release evidence

| Gate | Required evidence | Failure/unknown handling |
|---|---|---|
| Code identity | Repository/branch/SHA, clean intended diff and linked Phase8/9 tasks; document-only receipts may reference a previous tested code SHA only when runtime source is unchanged and that limit is stated | Hold integration/distribution on unknown code or unresolved conflict |
| Automated regression | Analyzer and applicable full Flutter suite, architecture/privacy gates, checkout contracts and native SQL/RLS/RPC/storage controls; skipped cases individually explained | Hold on failures or skipped critical coverage; never claim an unrun test |
| Cross-account security | Independent authenticated roles through real sessions; normal/invalid/other-account/anonymous access; database/storage effects and no leakage | SQL-injected JWT fixtures are scoped tests, not GoTrue/OAuth/E2E proof |
| Payments/business | Server-authoritative amount/subscription state, signed webhooks/idempotency, provider sandbox success/failure/refund evidence; classify every paid SKU/platform/territory | Digital owner tools are not automatically classified as physical pitch bookings. Prove required billing/IAP or an applicable permitted exception/program; do not change prices/model to make a test pass |
| Content/sports | Permission/integrity checks for teams/invitations/results/winners and applicable reporting/blocking/moderation | Hold any bypass or required missing moderation |
| Privacy/deletion | Actual data/SDK/permission/retention map matches Privacy Policy, App Privacy and Data Safety; real in-app deletion and accessible web request/ownership verification; retained records explicitly justified | Request receipt is not deletion completion; no raw personal data/tokens in logs or evidence |
| Android | Signed release AAB/APK, actual manifest/target/permissions and device/in-place-update checks; review account | Source targetSdk alone and debug smoke are insufficient |
| iOS | Xcode/iPhone SDK compliance, actual bundle/entitlements/SDK manifests, signed archive/export, real device login/notifications and review account | Unsigned compile and38 SDK manifests do not prove App Privacy/required-reason completeness, APNs or sign-in |
| Infrastructure/advisors | Current named findings, least privilege/secrets/dependencies, backups and tested relevant rollback | A stable advisor count is not a clean audit. Every unresolved critical finding blocks; known definer-callable findings require per-routine review |
| Store operations | Current questionnaire/age rating/privacy/billing declarations, support/legal links, reviewer instructions/test accounts and necessary console access | Missing access or declarations remain explicit blockers; never infer submission or approval |

## Severity and exceptions

P0: demonstrated account takeover/privilege bypass, private-data exposure, payment-state/price manipulation or exposed secrets. Reproduce safely, test the protection immediately and hold the affected release until fixed and verified.

P1: required account deletion, billing, moderation, material privacy or platform/store blockers. A code patch without its applicable acceptance evidence stays open.

P2/P3: noncritical improvements may be tracked with a concrete reason, scope and owner decision. A waiver cannot convert a P0/P1 into a passing test or assert store compliance. The already deferred leaked-password protection setting remains unchanged; record its unresolved advisory and review it explicitly before final release. Do not silently enable it or call all advisor findings resolved.

An exception records task/finding, impact, affected environments/users, mitigation, decision and next review condition. Standing authorization permits implementation; it is not evidence that a legal/policy exception applies.

## Evidence record and status transitions

For each accepted task record its type (documentation/code/runtime), scope, files/SHA, commands/results, environment and remaining limits. A parent item is not closed because one child passes. Count620 core IDs once; auxiliary incidents/receipts are not extra tasks. CODE_DONE and a reproducible fixture do not become VERIFIED until the task's own acceptance scope is satisfied.

Before a rollout capture source/ACL/advisor metadata; after it capture exact definitions, preserved metadata and applicable outcomes. Keep test data synthetic and rolled back/cleaned. Avoid production exploit probes or customer-data mutations. On timeout, unknown receipt or duplicate webhook, reconcile authoritative state before any destructive retry.

## Current decision (2026-11-11)

**Complete store release: HOLD.** Accepted baseline at this policy's creation is81/620, with539 not fully accepted; acceptance of this documentation alone becomes82/620,538 pending. Known successful evidence includes native security CI,1142 Flutter tests/10 explicit skips, Android smoke/compiled permissions and unsigned iOS device builds; none closes real-account journeys, provider/live delivery, signed store artifacts or console disclosures. Existing197 production definer-callable findings plus the deferred password advisory are not claimed clean.

The launch checklist previously contained a2% booking-commission example. It must use current server subscription/gateway policy; that example is superseded and must not drive prices, booking commissions or tests.

## Official requirements referenced (checked2026-11-11)

- [Apple review/security, privacy and billing](https://developer.apple.com/app-store/review/guidelines/): existing obligations; check each section's current text, not a fabricated effective date.
- [Apple SDK minimum](https://developer.apple.com/news/upcoming-requirements/?id=04282026a): since2026-04-28, Xcode26+/iOS26+ SDK for submissions.
- [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).
- [Google target API](https://developer.android.com/google/play/requirements/target-sdk): new app/update mobile submissions target API36+ from2026-08-31; the extension date2026-11-01 has passed.
- [Google User Data](https://support.google.com/googleplay/android-developer/answer/10144311) and [Payments](https://support.google.com/googleplay/android-developer/answer/9858738): existing obligations; eligible external billing requires its actual conditions/enrollment.
- [Apple developer news](https://developer.apple.com/news/): the2026-11-02 age-rating announcement introduces Shared Location/Dating declarations from2026-11-16, with all apps completed by2027-01-12. Inspect actual VSP behavior and complete the console declaration; do not infer an answer or claim it is submitted.

Re-check official sources at release time. No policy document can guarantee acceptance by either store.
