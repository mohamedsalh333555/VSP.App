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

A failed test must create a distinct BUG-### row with reproduction details. Do not infer a bug from a cancelled workflow; rerun it in the final verification phase. **Seven application defects and two test-harness/assertion defects recorded; source fixes committed; full deployment/provider acceptance is not complete.** See [batch report](security/STORE_COMPLIANCE_BATCH_01_2026-11-11.md). These findings arose during pre-release implementation review; their IDs are kept in this existing register rather than creating a second defect count. The two test corrections are not extra delivered product features.

Final source verification: Flutter CI 42924535090 SUCCESS (1088 passed, 10 skipped), Owner checkout security 42924534900 SUCCESS (39 passed), Android E2E Smoke 42924534915 SUCCESS at `daae560e`. This resolves the test failures but does not replace sandbox/deployed authorization or full feature acceptance.
