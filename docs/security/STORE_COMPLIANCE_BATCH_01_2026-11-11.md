# VSP — Store compliance implementation batch 01

Date: 2026-11-11 (Africa/Cairo). Branch: `uxlp-44-implementation`. PR #35 remains Draft. No main merge or production mutation.

## Scope and accounting

Read baseline: `d4451e796e5d513d84d2d478e7849fbf48bea1b3`. Implementation commit: `00b530fcf5de6ed44324c36f0e623dc572ba7e18`. Test-harness correction: `1bee6f23133c808cc65fe5267e310237124a323f`; final chained-call whitespace assertion correction: `daae560e0d69208011160a95a82b1d1a7b9ccbb1` (application/function source unchanged by both test-only commits).

This batch implements **7 concrete defect corrections** in the existing owner payment and account deletion flows. It does not close seven baseline tasks or certify store compliance. The fixed scope remains **620 subtasks; 76 historical accepted entries; 544 not fully accepted**. Historical acceptance includes documentation. No new whole-subtask closure is claimed by these partial cross-cutting fixes.

Links: SEC-01/03/04/06/08/10, Phase 9 INT-03 and REL-03, core 25.03/25.06/30.03/30.05/30.07/30.08/79/80. Owner payment checks contribute to B02/B07; deletion checks contribute to B03. All larger runtime acceptance requirements remain open.

## Corrections and evidence

| Defect | Severity | Previously reproducible source behavior | Implemented behavior | Acceptance limits |
|---|---|---|---|---|
| BUG-001 | P1 | Subscription inquiry accepted matching amounts without checking currency, refund/void state, or authorization-only transactions; a one-cent tolerance was used | Inquiry and signed subscription webhook share exact minor-unit, EGP, completed-payment, refund/void/auth-state and stored-order validation | Isolated request tests passed; full provider sandbox and signed webhook runtime still needed |
| BUG-002 | P1 | Checkout ignored correlation update errors and returned a payment URL; subscription callback allowed missing stored provider order ID | Checkout requires a provider order ID and a successful row-returning correlation update before releasing the URL; callback fails closed for missing correlation | Existing pending legacy orders without IDs require reconciliation; no automatic entitlement granted |
| BUG-003 | P2 | Configured CAPTCHA was skipped when request omitted the token | Missing token is rejected when CAPTCHA secret is configured; existing no-CAPTCHA configuration retained | Client CAPTCHA integration and real challenge verification still need a sandbox browser journey |
| BUG-004 | P1 | Inquiry used an endpoint different from the current official order-inquiry API | Uses documented ecommerce order inquiry endpoint and auth_token body | Mock transport checks exact request shape; actual Paymob sandbox response needed |
| BUG-005 | P1 | Both deletion services treated null, non-map, or unspecified-success RPC results as successful deletion | Only a map with boolean success=true confirms deletion; AuthService does not sign out on ambiguous results | Does not prove server-side erasure, OAuth reauthentication, token revocation, retention, or web deletion path |
| BUG-006 | P2 | Auth-state log included email; auth error logger and deletion error paths could emit raw exceptions or backend messages | Auth events omit email; security logs record event and error type; deletion errors do not expose backend text | This is targeted cleanup, not a complete log/SDK inventory |
| BUG-007 | P3 | Malformed status-request JSON returned a generic server error | Returns INVALID_JSON/400 without provider or financial operations | Request-level test covers malformed input |

### Changed code

- `supabase/functions/_shared/owner_subscription_payment.ts`: shared strict provider-response validator. It does not replace HMAC or caller authentication.
- `supabase/functions/_shared/checkout_dependencies.ts`: test/runtime transport boundary.
- `supabase/functions/{create_owner_web_checkout,get_owner_web_checkout_status}/handler.ts`: actual request handlers, exercised without live services or credentials.
- Existing `index.ts` entrypoints retain the same pinned Supabase/HTTP dependencies and invoke the tested handlers.
- `supabase/functions/paymob_webhook/index.ts`: only owner-subscription confirmation branch changed; signature verification still precedes validation and activation.
- `lib/core/services/auth_service.dart` and `lib/core/providers/auth/auth_profile_service.dart`: explicit deletion confirmation and targeted log/error minimization.
- `supabase/functions/tests/owner_checkout_test.ts`: 39 isolated request/payment cases.
- `test/core/services/account_deletion_confirmation_test.dart`: 26 deletion cases using the actual services and a mocked HTTP backend.
- `test/owner_checkout_authorization_contract_test.dart`: retains owner-ID source guard and adds entrypoint/shared-validator wiring checks. These source checks are not live authorization evidence.
- `.github/workflows/owner-checkout-security.yml`: Deno request tests, no network permission, secrets, DB, user creation or payment operations.

No dependency upgrade, price edit, commission change, migration, permission SQL, legal-identity invention, or feature removal.

Added `scripts/verify_task_accounting.py`, a read-only check that compares all core IDs in the original detailed list, the reordered plan and the ledger counter. Actual local result: **620 rows, 620 unique IDs, 82 parent items, 76 accepted checklist entries, 544 not accepted, no accounting errors**. It explicitly does not certify historical evidence or runtime readiness. This maintenance check is separate from the seven application fixes.

## Verification

- Local Deno 2.2.12: **39 passed / 0 failed**, type-checking the real request handlers and shared validator as part of the test run. Repeated after formatting and final handler changes.
- Owner checkout security CI: **SUCCESS**, [run 42922218192](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42922218192), implementation SHA above. Duplicate successful trigger run 42922209767 is not counted as extra test coverage.
- `git diff --check`: passed. Deno formatting check: passed for five new handler/shared/test files.
- Full entrypoint `deno check` locally: **BLOCKED** by connection refusal fetching existing deno.land dependencies. No claim of a successful local entrypoint check. Supabase staging bundling of the two entrypoints succeeded instead.
- Local Flutter bootstrap/verification: **BLOCKED by automatic approval review** because it attempted cloud metadata access. It was not retried or bypassed. GitHub-hosted Flutter checks are the independent alternative.
- Initial Flutter CI [42922218200](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42922218200): analyze and architecture gates passed, full suite **1084 passed / 4 failed / 10 skipped**. The three positive deletion failures exposed missing request metadata in mocked HTTP responses, required by the PostgREST response parser; the fourth was a whitespace-sensitive source assertion after formatting. Negative deletion cases from this initial run are not treated as adequate evidence because the fixture could fail before decoding the intended response. Both fixture and assertion were corrected in `1bee6f2`; acceptance requires the rerun.
- Android E2E [42922217963](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42922217963): **SUCCESS** at implementation SHA `00b530f`. This is onboarding/login smoke, not booking/payment/24-journey acceptance. The later commit changes only test fixtures/assertions, not app code.
- Second Flutter CI [42923346806](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42923346806): **1087 passed / 1 failed / 10 skipped**, including all **26 account-deletion tests passed**. The remaining failure was the source assertion: the formatter split the chained `auth.getUser` access before the dot as well as inside the argument list. `daae560e` corrects whitespace handling between chain segments; the expression was checked against the actual source before pushing. Final full Flutter rerun pending below; the second run is not a full pass.
- Android E2E [42923357379](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42923357379) and Owner checkout security [42923357358](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42923357358) also passed on `1bee6f2`.

### Final verified checkpoint

All three checks completed **SUCCESS** for `daae560e0d69208011160a95a82b1d1a7b9ccbb1`:

| Check | Actual result | Evidence |
|---|---|---|
| Flutter CI | Analyze, architecture gate and full suite passed; **1088 passed, 10 skipped**; all 26 deletion cases passed | [42924535090](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42924535090), job 130207508196 |
| Owner checkout security | **39 isolated handler/payment cases passed** | [42924534900](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42924534900) |
| Android E2E Smoke | Passed; public/onboarding/login smoke scope | [42924534915](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42924534915) |

Skipped tests are not passes. The two earlier failed runs and test-harness fixes remain in this report; they are superseded for the corrected test source, not erased. The later report/accounting-check commit changes no mobile or backend runtime code. The Python accounting checker was run locally and passed separately. No iOS archive, release APK/AAB, provider sandbox charge, live signed webhook or valid-user multi-account E2E pass is claimed.

## Staging deployment and readback

Project `vsp-staging` / `vtwgqyxglevcsxwdmhop`, verified ACTIVE_HEALTHY. Production project was not deployed or queried for changes.

| Function | Prior version | New version | JWT verification | Readback |
|---|---:|---:|---|---|
| get_owner_web_checkout_status | 3 | 4 | true | Handler source exactly matches committed implementation |
| create_owner_web_checkout | 2 | 3 | true | Handler source exactly matches committed implementation |

Before replacement, both existing deployed sources were read and compared with the baseline. Status source matched exactly; create source differed only by a trailing blank line. Rollback is therefore to the same function source from baseline SHA d4451e7 with verify_jwt=true; rollback deployment creates a new version rather than editing history.

For **each** deployed function, actual HTTPS smoke requests returned:

- POST without Authorization: **401**, gateway rejection.
- POST with invalid test token: **401**, gateway rejection.
- OPTIONS from `https://vspapp.online`: **200**, expected allow-origin header and `ok` response.

These six live requests do not exercise a valid user's handler, cross-account isolation, CAPTCHA provider, checkout creation, charge, refund or entitlement activation. Mocked HTTP tests demonstrate those request branches in isolation; live two-account and provider sandbox acceptance remains open. The webhook function is absent from the inspected staging function inventory and was **not newly deployed** in this batch. Its source correction has not received a deployed webhook runtime test.

Read-only staging security advisor: 4 public-extension warnings; 198 authenticated-callable security-definer function warnings; 1 leaked-password-protection warning. A callable function warning is not proof of an authorization bypass. No blanket revocation was made. Leaked-password protection remains deferred under the existing project instruction. Remediation references:

- https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

## Policy relevance and dates

Primary sources consulted on 2026-11-11:

| Official source | Relevant review requirement | Date handling |
|---|---|---|
| [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Privacy/security, account deletion, payments classification | Current document consulted; no new amendment or effective date asserted by this batch |
| [Google Play User Data](https://support.google.com/googleplay/android-developer/answer/10144311) | Accurate data handling/disclosure and secure treatment | Current requirement; effective date of a new change not established |
| [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111) | In-app and web account/data deletion request paths | Existing requirement, not a newly discovered policy change; full VSP deletion acceptance remains open |
| [Google Play Payments](https://support.google.com/googleplay/android-developer/answer/9858738) | Classify each digital/physical service before deciding billing channel | No determination that every owner subscription is exempt; no payment model change implemented |
| [Paymob order inquiry](https://developers.paymob.com/paymob-docs/developers/transaction-inquiry-apis/transaction-inquiry/by-order-id-or-reference) | Provider response fields and documented request endpoint | Page states last updated June 28, 2026; that is a documentation update, not an App Store/Play policy effective date |
| [Supabase securing functions](https://supabase.com/docs/guides/functions/auth) and [changelog](https://supabase.com/changelog.md) | Verified caller identity and runtime conventions | Existing pinned packages retained; no v3 upgrade performed |

These defects were confirmed in application logic; they are not claimed as seven separately adjudicated store-policy violations. SC01–SC16 remain subject to full applicability and evidence review. No claim of legal certification or store acceptance.

### Current announcements and concrete follow-up dates

- [Google official deadlines](https://support.google.com/googleplay/android-developer/table/12921780?hl=en) and [October 29 announcement](https://support.google.com/googleplay/android-developer/answer/18100766?hl=en) were checked on 2026-11-11. Location-policy deadline: **2027-01-27**. The app declares fine/coarse location and targets API 36 (`android/app/build.gradle.kts`); assess minimum scope and the fine-location declaration. The API-37 location-button condition must not be claimed as already applicable to API 36. No permission change or Console declaration made in this batch.
- The same deadline table lists **2027-01-27** for eligibility-based subscription discounts, **2027-04-14** for AppFunctions, and **2027-08-25** for local-network/manage-contacts permissions. Applicability to VSP is not established from these payment fixes; do not introduce features or changes solely because a policy exists.
- Google’s October announcement says trader-status declaration starts in **November 2026**. VSP’s actual Play Console declaration/verification state needs account access; no day within November is invented.
- [Apple Developer News](https://developer.apple.com/news/) dated **2026-10-16** describes strengthened UGC moderation and review-transparency rules. VSP’s profiles/images/interactions require SC10 coverage; moderation was not implemented or accepted in this batch. This is the announcement date; no separate grace deadline is asserted.
- [Apple account-deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/) identifies **2022-06-30** as the start of the in-app deletion submission requirement. The deletion confirmation correction contributes to it but does not satisfy the whole requirement.

Source-only permission inventory: main Android manifest declares internet, fine/coarse location, camera, legacy external-storage read, media-images read, and notifications. Broad photo access needs a separate current-use-case/picker audit; neither the manifest nor a permission string alone proves a violation. iOS Info.plist has location/photo/camera descriptions. No Runner-level PrivacyInfo.xcprivacy appeared in the source file listing; merged SDK privacy manifests and archive validation remain unverified.

## Remaining blockers and next execution

1. Current code-SHA Flutter, Android smoke and isolated payment checks passed as above. The remaining work is broader feature/store acceptance, not rerunning these same passed checks without a new reason.
2. Obtain/use isolated valid staging identities for owner, other owner, player and admin; prove permitted and denied requests on the deployed functions.
3. Verify Paymob sandbox configuration, exercise intention/correlation persistence, inquiry, duplicate and reverse-order signed webhook events and entitlement idempotency. Never substitute real charges for missing sandbox access.
4. Complete server account deletion/retention/storage/session checks and OAuth users' reauthentication, plus usable public web deletion request path.
5. Continue all 16 compliance gates, particularly actual service billing classification, UGC, permissions/SDK inventory, store disclosures and iOS build/review environment.
6. No APK/AAB/iOS archive produced in this batch. No release-ready conclusion and no production/main action.
