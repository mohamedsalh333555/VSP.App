# VSP Android release signing — source configuration audit (60.07)

**Date:** 2026-11-13 | **Branch:** `uxlp-44-implementation`

**Accepted scope:** inspect Android Gradle signing selection, repository secret exclusions, the manual release APK workflow and the independent Shorebird release workflow. This is a **source/configuration audit**, *not* proof of a signed build, of certificates matching Play Console, or of a published APK/AAB. No key material, secret values, user data or store account was retrieved.

## Findings

| Gate | Verified source behavior | Outcome/remaining risk |
|---|---|---|
| Original Android release signing | `android/app/build.gradle.kts` declares `release` signing from ignored `android/key.properties`. An explicitly requested release build without that file throws an error, unless `VSP_TEST_RELEASE_APK=true`. | **Source guard present.** Actual release key/certificate unavailable for inspection. |
| Test-only release APK | `VSP_TEST_RELEASE_APK=true` explicitly selects Android's `debug` signing config for a release-mode test APK. The comment labels this *not Play Store signed*. | **Intended QA bypass, not a distributable production artifact.** Never treat such an APK as a store upload. |
| Manual signed APK workflow | `.github/workflows/build-release-apk.yml` runs only by `workflow_dispatch`. It runs Flutter analyze and unit/widget tests, requires four `ANDROID_KEYSTORE_*`/alias/password secrets, decodes the key into `android/app/vsp-release-key.jks`, writes `android/key.properties`, then builds and uploads an APK. | **Fail-closed source path.** No confirmed actual secrets, successful build receipt, certificate match, AAB, Play signing configuration, or installed-device result. |
| Shorebird Android base release | `.github/workflows/shorebird-release.yml` uses a **different secret naming family** (`KEYSTORE`, `KEYSTORE_ALIAS`, `KEYSTORE_PASSWORD`) and `shorebird-release`. | Need compare public certificate fingerprints / Play Console expected key identity across both workflows. *Names alone do not prove same or different keys*. No Shorebird release is claimed. |
| Git secret hygiene | `.gitignore` excludes `android/key.properties`, `android/app/*.jks` and `android/app/*.keystore`, plus generated Firebase config and local environment files. | Source-level exclusion present; does not prove old commits/secrets or other paths have never leaked. |
| Debug build behavior | In `android/app/build.gradle.kts`, debug builds use the release signing configuration *when a local key.properties exists*. | Document for maintainers: ensure CI/debug QA never accidentally distributes an artifact signed with the production key. Review developer workflow if debug keys should be isolated. |
| Android E2E | `.github/workflows/android-e2e-smoke.yml` tests emulator onboarding/public flow and compiled media permissions. | Successful smoke is not a signed-store APK/AAB or Play Console certificate proof. |

## Release requirements remaining OPEN

1. Confirm both workflow keystore certificate fingerprints and their relationship to the **actual** Play app signing/upload keys using a secure fingerprint-only process, without revealing private keys or passwords.
2. Execute a clean **signed release artifact** build from the intended final commit and capture artifact SHA-256, signature certificate SHA-256 (using `apksigner verify --print-certs`), versionCode/package ID and file size. For Play Store upload, build and validate AAB plus its upload signing as applicable.
3. Check absent/misconfigured keys fail closed and the test-only debug-signing override cannot be mistaken for a production package; add release-specific negative tests when safe.
4. Validate on an Android device/updating existing installation; verify the release artifact is retrievable and matches the exact expected commit.
5. Confirm signing/Play console custody, account access and rollback/update continuity; do not infer from workflow YAML that a key exists or belongs to VSP.

**Task 60.07 acceptance:** review and risk register of signing configuration *only*. Task 60.06 (release build), 60.08 (overall readiness), 60.09 (clean final APK) and store publication are **not** accepted. No Gradle/CI configuration changed, no signing material opened, no APK built and no `main` merge occurred.

## Exact reviewed files

- `android/app/build.gradle.kts`
- `.github/workflows/build-release-apk.yml`
- `.github/workflows/shorebird-release.yml`
- `.github/workflows/android-e2e-smoke.yml`
- `.gitignore`
- `docs/VSP_PERFORMANCE_BUDGET_AND_STAGING_BLOCKERS_2026-11-13.md`
