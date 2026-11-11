# VSP — Final verification defect register

**Independent from the 620 core subtasks.**

| Defect ID | Severity | Area | Reproduction / evidence | Root cause | Fix commit | Retest status |
|---|---|---|---|---|---|---|
| BUG-001 | P1 | Owner payment validation | Inquiry could accept refunded/void/auth-only/wrong-currency or one-cent-mismatched payment | Incomplete provider validation | `00b530f` | 39-case isolated suite covers rejection; sandbox/signed webhook runtime pending |
| BUG-002 | P1 | Checkout/provider correlation | Payment URL returned even when provider order correlation was missing/not saved | Ignored update result and optional callback correlation | `00b530f` | Isolated save-failure/missing-ID rejection passed; actual sandbox pending |
| BUG-003 | P2 | Configured CAPTCHA | Omit token to skip configured verification | Conditional required both secret and token | `00b530f` | Isolated omission/failure/valid cases passed; browser sandbox pending |
| BUG-004 | P1 | Payment reconciliation | Order inquiry URL differed from current documented API | Incorrect endpoint and request shape | `00b530f` | Exact mock transport request passed; provider sandbox pending |
| BUG-005 | P1 | Account deletion | Null/malformed/unspecified RPC success treated as deletion | Rejected only explicit success=false | `00b530f` | All 26 deletion service cases passed in run 42923346806; server erasure/retention acceptance remains open |
| BUG-006 | P2 | Auth/privacy logs | Email and raw exceptions/backend messages could be emitted | Unsanitized logs/error text | `00b530f` | Targeted deletion privacy cases passed in 42923346806; full SDK/log audit pending |
| BUG-007 | P3 | Status request errors | Malformed JSON returned server error | Parse error not classified | `00b530f` | Request-level malformed JSON test passed |
| BUG-008 | P2 | Deletion test fixture | Three positive deletion tests failed in CI 42922218200; negative cases could also fail before decoding the intended response | Mock HTTP responses lacked request metadata required by PostgREST | `1bee6f2` | All 26 deletion service tests passed in 42923346806; app code unchanged |
| BUG-009 | P3 | Checkout source contract test | Auth-call source check failed after formatter split the call | Assertion assumed no whitespace inside/between chained calls | `1bee6f2`, `daae560e` | Final source assertion passed in successful full CI 42924535090; 1088 passed, 10 skipped |
| BUG-010 | P1 | Broad media access | App declared broad media/storage access while callers use system file/photo pickers | Unnecessary manifest permissions | `27b34f7` | Final real APK gate passed 42930890192 at e862fbb; no broad media/storage permissions |
| BUG-011 | P2 | Device availability | Camera/location permissions can imply required sensors | Hardware requirements not explicitly optional | `27b34f7` | Actual APK reported no required hardware; additional real-device coverage pending |
| BUG-012 | P2 | Photo metadata | Picker default requests full metadata | No minimal metadata option at selection boundary | `27b34f7` | Four picker boundary cases passed in 42930897576; no EXIF-redaction claim |
| BUG-013 | P1 | Location session privacy | Precise device cache and delayed response can outlive auth identity | Cache not cleared/invalidated on logout/switch | `27b34f7` | Five location/cache cases passed in 42930897576; real-device coverage remains separate |
| BUG-014 | P2 | Cached location recovery | Malformed cached timestamp aborts location fallback | DateTime.parse on unchecked cache | `27b34f7` | Corrupt timestamp/refused-GPS case passed in 42930897576 |
| BUG-015 | P2 | Deletion UI lifecycle | Pending confirmation dismissible; duplicate/stuck state possible | State/controller lifetime separate from dialog request | `27b34f7` | All 14 bilingual dialog cases passed in 42930897576, including narrow/large-text layout |
| BUG-016 | P2 | Incomplete registration cleanup | Logs claim purge without explicit success and include UID/raw error | RPC result not checked | `27b34f7` | All eight final cleanup cases passed in 42930897576; source log minimization reviewed |
| BUG-017 | P1 | Owner deletion identity | Identity can switch while reauthentication awaits | No account snapshot check around awaits | `27b34f7` | Identity-switch widget case passed in 42930897576; full server-session acceptance remains separate |
| BUG-018 | P2 | New auth test fixtures | Three analyzer errors in 42928441811 | Nullable User.fromJson result used as non-null fixture | `fe14d20` | Corrected fixtures, analyzer, focused gate and full suite passed in 42930897576 |
| BUG-019 | P2 | Advertising permissions | Compiled APK requested ad identifier/attribution permissions not used by product code | Analytics dependency defaults | `1a89e0d` | Final APK gate passed 42930890192: ad identifier/attribution permissions absent; SDK network/iOS audit still open |
| BUG-020 | P1 | Newly shared deletion dialog layout | Actual widget assertions in fe14d20 logs before cancellation: LayoutBuilder cannot provide intrinsic dimensions to AlertDialog | Introduced action layout incompatible with dialog intrinsic sizing | `1143044`, `3f44b3c` | Bounded action layout passed focused/full CI 42930897576; not an additional delivered feature |
| BUG-021 | P1 | Automatic incomplete-account cleanup | Null/stale mismatched profile could be treated as proof that account is incomplete | Unconfirmed profile state used for destructive cleanup | `e862fbb` | Unknown/mismatched negative cases passed in 42930897576. Full server-atomic registration completion race still open |
| BUG-022 | P2 | New widget test timing | 42930243839: 23 passed, 7 failed; retry assertions and pending toast timers | Fixtures advanced 500ms despite existing 1500ms button debounce and 3s toast timer | `e862fbb` | Corrected timing passed all 32 focused cases and full suite in 42930897576; app debounce unchanged |

A failed test must create a distinct BUG-### row with reproduction details. Do not infer a bug from a cancelled workflow; rerun it in the final verification phase. **Eighteen application defects (including one introduced-and-corrected dialog regression) and four test-harness/assertion defects recorded across batches 01 and 02; source fixes committed; full deployment/provider/store acceptance is not complete.** See [batch 01](security/STORE_COMPLIANCE_BATCH_01_2026-11-11.md) and [batch 02](security/STORE_COMPLIANCE_BATCH_02_2026-11-11.md). These findings arose during pre-release implementation review; their IDs are kept in this existing register rather than creating a second defect count. Test corrections and the introduced regression are not extra delivered product features.

Batch 01 source verification: Flutter CI 42924535090 SUCCESS (1088 passed, 10 skipped), Owner checkout security 42924534900 SUCCESS (39 passed), Android E2E Smoke 42924534915 SUCCESS at `daae560e`. This resolves the batch 01 test failures but does not replace sandbox/deployed authorization or full feature acceptance. Batch 02 evidence is in its own linked checkpoint.

Batch 02 final source verification at `e862fbb`: Flutter CI 42930897576 SUCCESS (32 focused cases, 1120 passed and 10 skipped in full suite), Android smoke/compiled APK gate 42930890192 SUCCESS (six tool tests plus actual package inspection), Owner checkout security 42930897573 SUCCESS (39 isolated cases). Broader server/provider/device/store acceptance remains open.


Batch 03 checkpoint (does not renumber prior findings):

| ID | Priority | Scope | Finding / correction | Evidence |
|---|---|---|---|---|
| BUG-023 | P0 | Registration cancellation | Known but stale incomplete profile could invoke general permanent deletion; use locking server cancellation RPC | 17 staging checks, app source 3662402 |
| BUG-024 | P0 | Cleanup network failure | Unconditional deleteAccount fallback could bypass completion check; removed | Added network-negative case, 1128 full suite passed |
| BUG-025 | P1 | Owner onboarding | Non-map response counted as success, profile identity mismatch not checked; require explicit success and matching UID | Seven added response/identity cases; CI 42939496320 |
| BUG-026 | P0 | Chat reads | Non-participant could mark another conversation read through definer RPC; membership authorization before mutation | Denied self/impersonation requests leave message/counters intact, authorized/repeat pass |
| BUG-027 | P0 | Staging account state guard | Existing sensitive field function not attached to users UPDATE; restored production-equivalent trigger binding | Before synthetic privilege escalation reproduced under ROLLBACK; after role/subscription/debt/completion writes denied |
| BUG-028 | P0 | Staging profile reauthentication guard | Existing recent-password function not attached; restored binding | Four sensitive phone/payment changes denied; recent password claim and ordinary edit allowed |
| BUG-029 | P2 | New SQL test fixture | Auth email-sync fixture left transaction-local system override enabled, bypassing guard under test | Clear flag before simulated client, rerun 11 checks and all 17 lifecycle/chat checks successfully |

Batch 03 adds four app corrections and two environment corrections. BUG-029 is test setup repair, not product progress. Actual multi-session overlap not observed; no concurrency success claimed. No new baseline task acceptance counted.


Batch 04 findings: source and staging remediation; production approval pending.

| ID | Priority | Finding / fix | Evidence |
|---|---|---|---|
| BUG-030 | P0 | Direct own-profile INSERT can choose admin/pro; DELETE bypasses account lifecycle. Revoke client INSERT/DELETE and provision via identity-scoped server RPC | Synthetic privileged INSERT reproduced before fix; all new provisioning server checks and explicit cancellation passed after fix |
| BUG-031 | P1 | Failed OAuth profile upsert manufactured an unpersisted local profile; require explicit response and matching persisted profile | Added response/network/missing-profile tests; passed in 54-case gate and 1142-case suite, push 42954730210 |
| BUG-032 | P1 | setUserRole failure or stale reread still changed local routing role; require success and authoritative matching reread | Added two negative role tests; passed in push 42954730210 |
| BUG-033 | P1 | Phone present locally granted registration completion before/without server state | Added false/true update-result tests with server state still incomplete; passed in push 42954730210 |


Final batch 04 verification at app source 906846f: Flutter push 42954730210 SUCCESS (1142 passed, 10 skipped); Android push 42954730199 SUCCESS including actual APK gate; checkout 42954735544 SUCCESS (39). SQL suites and three RPC body readbacks passed on staging. Application release and production remediation remain pending; no signed phone APK/iOS archive claimed.
