# Android E2E smoke — verified scope and evidence (58.01, 58.02, 58.07)

Date: 2026-11-08. Branch: `uxlp-44-implementation`.

## Scenario inventory and exact scope (58.01)

The checked-in automated scenario is `integration_test/app_public_smoke_test.dart`, executed by `.github/workflows/android-e2e-smoke.yml`.

Verified assertions:
1. Real Flutter app bootstrap completes on Android with staging Supabase configuration.
2. Welcome screen is visible after splash.
3. Language selector changes the current language and can switch back to English.
4. Skip onboarding displays Player, Owner and Login choices.
5. Tapping Login displays the login screen with two editable inputs, without widget exceptions.

**Not covered:** signing in with real credentials, successful signup, booking and payments, team/challenge flows, invitation accept/reject, multiple users, admin, or release APK acceptance. Do not infer those from the workflow name.

## Emulator setup (58.02)

The GitHub Actions workflow provisions Android emulator **API 35, x86_64, Pixel 6** with animations disabled, Java 17, Flutter 3.32.8, KVM enabled, and generates localizations. It runs `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_public_smoke_test.dart` with staging Supabase configuration. This establishes a repeatable Android emulator environment; it does not certify physical devices.

## Execution results (58.07)

- [Android E2E Smoke run 42489433379](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42489433379), commit `df76e5eb6c0b45a0202915491e0175f023c2a6f5`: **success**.
- Job `128759476325`: Firebase config, dependencies/localizations, KVM, emulator smoke and status publication each **success**.
- [Flutter CI run 42489433328](https://github.com/mohamedsalh333555/VSP.App/actions/runs/42489433328) on the same commit: **success**.

## Outstanding acceptance

58.03 requires actual successful sign-in, not just navigating to the login screen. 58.04/58.05 need booking/team/challenge scenarios. 58.06 needs explicit log collection/report. 58.08 needs accept/reject invitation Android test. None is claimed complete. Live payment and user account journeys require appropriately isolated staging test users and controlled test data.

## Android smoke log collection (58.06) — 2026-11-12

- Source: [Android E2E Smoke workflow run 43302703167](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43302703167), branch `uxlp-44-implementation`, commit `366e75d897343633563db92c36446ab4a5115770`.
- Source job: [Android public/auth journey smoke — job 131480962116](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43302703167/job/131480962116), **success**.
- Retrieved and reviewed the workflow job's decoded execution log (1,701 lines). The staging Android public smoke command used `flutter drive` targeting `integration_test/app_public_smoke_test.dart` on `emulator-5554`.
- Relevant log evidence (excluding environment credentials):
  - `2026-11-12T20:52:57Z ✓ Built build/app/outputs/flutter-apk/app-debug.apk`
  - `2026-11-12T20:53:13Z I/flutter: 00:10 +2: All tests passed!`
  - `2026-11-12T20:53:13Z All tests passed.`
- The job shows successful configuration/dependency installation, KVM, fixture safety guard, Android onboarding/login smoke, compiled APK permission verification, and commit-status publication. No `##[error]`, `BUILD FAILED`, or nonzero process-exit marker was found in the reviewed job log.
- **Acceptance boundary:** This closes **log collection (58.06)** for the checked-in public smoke only; it does not establish successful sign-in with credentials, booking, payment, invitations, team/challenge operations, physical-device validation, or complete E2E coverage. Tasks 58.03–58.05 and 58.08 remain open. No sensitive environment values have been reproduced in this evidence note.
