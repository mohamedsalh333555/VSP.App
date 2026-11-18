# VSP — Auth back navigation and login submission acceptance (scoped)

**18 November 2026 · `uxlp-44-implementation` · client-only acceptance; no release**

**Exact tested code before docs-only accounting commit:** [`1486c03f`](https://github.com/mohamedsalh333555/VSP.App/commit/1486c03f4c8b9f50e6da2825c26f48965ed72270).

## 07.02 — Shared back button behavior (accepted, limited)
- Verified actual `VSPAuthHeader` and `VSPBackButton` with `GoRouter`: back from a pushed login screen returns to the earlier route, Android system back exits a pushed screen, and an explicitly opened login path has a safe welcome fallback.
- Separate widget checks cover >=48dp interactive back target plus English/Arabic accessible labeling.
- [CI: Recovery/Navigation Widget Regression — passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44213691731). Includes `test/shared/widgets/vsp_auth_header_back_navigation_test.dart`.
- **Not accepted:** every button/stack in booking, owner, championship and team screens, Android physical-device system navigation, and predictive-back behavior. Those are additional release/QA checks; not a claim of global journey coverage.

## 11.02 — Login input and retry after exceptional failure (accepted, limited)
- `LoginScreen` now clears the loading lock when a sign-in provider call throws unexpectedly, shows a generic localized failure rather than leaking backend details, and allows a retry.
- Widget tests use a fake auth provider to reject malformed emails without a request, normalize a valid email, simulate an exception and verify the next submission works.
- [CI: VSP Login Input and Exception Recovery — passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44213691637). Includes `test/features/auth/login_submission_regression_widget_test.dart`.
- **Not accepted:** live Supabase authentication with multiple actual user accounts, SMS/email verification, OAuth return to app, rate limiting, or network/device E2E. They remain under 11.01/11.04–11.07 and staging security work.

## 07.06 — Sensitive modal back behavior (accepted, limited) / 05.03 still open
- In-flight password recovery dialog now prevents accidental Android back or scrim dismissals until the request finishes; the neutral reply is preserved. Cancellation **before** request remains possible.
- The widget test exercises system back, outside tap, pending request and eventual completion. The test initially attempted `pumpAndSettle` during an infinite spinner, which was correctly replaced with fixed-duration pumps.
- [CI: Recovery/Navigation Widget Regression — passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44213691731).
- Separate account-deletion tests, in Arabic and English, now verify idle Android back without deleting, outside taps, prevention of cancellation/repeat while deletion is pending, and retry after a failed attempt. [Current CI passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44214357012) at [`076e903e`](https://github.com/mohamedsalh333555/VSP.App/commit/076e903ee0ad5c8c8e4b93a746ba3620307ecb57).
- The preexisting recovery checks plus account-deletion checks provide narrow accepted regression evidence for two security-sensitive dialogs. Other money-related confirmations, owner booking sheets, camera/pickup/tournament modals and hardware back on a physical device have **not** been covered. These remain release/QA follow-ups. `05.03` remains open until all interactive components meet target sizes.

## Accounting
- Original unique tasks: **633** (unchanged).
- Previously accepted: **306**.
- Accepted with documented limited scope: **07.02, 11.02, 07.06** (+3 across two batches).
- After the second documented acceptance: **309 accepted / 324 open (48.82%)** (+3 total in this continuation: 07.02, 11.02 and 07.06).
- Full [Flutter CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44213691855) was in progress at documentation checkpoint, **not claimed successful**.
- No changes to Supabase, production, payments, bookings, release APK or main branch. PR #35 remains draft. Migration/server-level security checks remain open.
