# VSP — Registration network interruption & retry (08.05), 19 November 2026

**Branch:** `uxlp-44-implementation` (PR #35 Draft). **Task ID:** 08.05. **Acceptance:** Flutter client/widget level only.

## Verification delivered
- Extended `FakeRegisterAuth` in `test/features/auth/signup_full_form_widget_test.dart` with a controllable pending signup request. The test suspends the registration response, asserts the submit button remains disabled so a double tap cannot create another call, rejects the pending request with a simulated private network exception, and checks the UI safely restores a retryable form.
- All six input fields remain in their controllers, including the original email; DOB, consent, and player position selection survive a failed attempt. After the user explicitly retries, the same normalized registration payload is submitted again; neither raw exception nor private provider details appear.
- Four combinations verified independently: player Arabic, player English, owner Arabic, owner English. Existing valid/invalid form cases also passed.
- **Passing CI evidence:** [VSP Signup Input and Error Validation #44442134318](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44442134318), 35 tests passed; implementation [commit 6bd2888](https://github.com/mohamedsalh333555/VSP.App/commit/6bd2888d21321b96890de0ebf501ff91e70edc35).

## Exclusions
This simulates an **in-flight request interrupted inside the current screen**, not physical airplane-mode/network testing, app kill/restoration of an unsaved draft, completed real Supabase signup/OTP, or server idempotency. Real device session/network checks remain outstanding under device and account acceptance tasks. This does not authorize production deployment, Paymob changes, APK, or merge to `main`.

## Per-task counter movement
After prior accepted task 12.01: **640 / 336 accepted / 304 open**. After 08.05 bounded acceptance: **640 / 337 accepted / 303 open = 52.66%**. No new task ID introduced.
