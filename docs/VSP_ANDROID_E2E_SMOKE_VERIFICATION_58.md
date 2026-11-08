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
