# VSP — Scoped signup privacy, accessibility and layout acceptance

**18 November 2026** · `uxlp-44-implementation` · source code / automated Flutter Widget QA only.

**Tested head (code before documentation):** [`d6e5ec80`](https://github.com/mohamedsalh333555/VSP.App/commit/d6e5ec80fe41ab61a25fb0303710894b1342ed30)

## CI evidence on the same code SHA
- [Flutter analyze + 41 Auth UX, accessibility, focus, screen-size and role-choice widget tests: SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44220528014).
- [Flutter analyze + 27 Signup validation and full-form widget tests: SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44220528090).
- [Release Security Gate: SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44220528184). **This does not mean full application Flutter CI or production security audit passed.**

## 11 task IDs accepted at *limited* scope

| Task IDs | Verified surface | Boundaries / untested items |
|---|---|---|
| 05.02 / 05.03 / 05.06 | Explicit bilingual screen-reader semantics on bottom-sheet player/owner role cards; checkable terms action and 48dp touch target; role selection works from accessible labels | Other modules, true Android TalkBack/VoiceOver, full color-accessibility sweep |
| 05.05 | Real keyboard `Next` action transfers focus from login email `EditableText` to password for both locales | Other form controls, full keyboard-only journeys and platform devices |
| 09.03 / 09.05 / 09.06 | Login and owner account entry remain renderable/scrollable on simulated large portrait, landscape and 3x-density Flutter viewports | Stadium detail/booking/team modules, actual rotation and different OEM device scaling |
| 10.05 | Bilingual RTL and enlarged text (1.4x–1.8x) in auth layout, role sheet and small screen flows | Golden image baselines and global navigation/RTL |
| 11.01 / 08.07 / 19.01 | Player and owner full registration forms filled end-to-end **inside widget harness**, date picker, phone/email/password, terms, role-specific payload, redacted error when fake auth rejects/throws | **No real Supabase Auth request or email delivery**, no verified owner onboarding, no staging role/RLS assertions |

## Registration privacy hardening (security progress, not a server authorization acceptance)
- Removed unprivileged `UserRepository().getUserByPhone(...)` pre-check. This previously attempted to read arbitrary users' phone registrations and made a best-effort uniqueness decision outside the authoritative registration transaction. Client-side user existence enumeration and its race are no longer necessary.
- The registered phone still goes into sign-up user metadata, where server-side uniqueness **must** be enforced and verified independently. No claim that the server currently enforces it.
- Unrecognized `AuthProvider.errorMessage` values now become generic bilingual registration failure copy instead of leaking provider/SQL/user information. Allowlisted age and confirmation-email errors remain localized.
- Raw provider exceptions and stack traces are no longer printed from the sign-up screen. A thrown provider request no longer triggers two different failure toasts.
- Unit contracts test malformed email rejection, no phone lookup in signup, sanitized backend strings, and exception fallback; widget tests verify both roles and error privacy.

## Task arithmetic
- Original: **633** (unchanged).
- Before: **317 accepted / 316 open (50.08%)**.
- New scoped accepted task IDs: **11** (`05.02`, `05.03`, `05.05`, `05.06`, `08.07`, `09.03`, `09.05`, `09.06`, `10.05`, `11.01`, `19.01`).
- After: **328 accepted / 305 open (51.82%)**.

## Unchanged release/security blockers
- **05.07** screen-reader navigation on a real device is still open: finding a Semantics node and tapping text is not an actual TalkBack/VoiceOver traversal.
- **11.04/11.05/11.06/11.07** OTP verification, session expiry, brute-force/rate limiting and actual-device live authentication remain open.
- **19.02–19.07**, bookings, payment/Paymob, challenge two-captain consent / #44, Supabase RLS and the other P0 gates still require independent backend/staging evidence.
- Not merged to `main`, not deployed, no production database/payment mutations, no new APK or app-store release. PR #35 remains draft.
