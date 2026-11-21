# VSP — performance acceptance budget and staging test blockers

Date: 2026-11-13. Scope: **documentation only**. Branch: `uxlp-44-implementation`.

## 60.01 — Performance budget (defined, not yet measured)

The following are initial acceptance targets, **not observed performance results**. Record hardware, Flutter version, build mode, network and 5-run repetitions for every measurement. Use the same staging fixture and anonymized results for comparisons. Fail/revisit the budget if the agreed reference device class cannot realistically meet these targets; do not silently weaken thresholds.

| Metric | Initial acceptance budget | Measurement / evidence |
|---|---|---|
| Cold start to usable home/welcome screen | P95 ≤ 5 seconds on a mid-range Android device | 20 fresh-process profile/release launches, `flutter run --profile`, timestamp first actionable frame; record device/OS |
| Warm navigation to stadium details | P95 ≤ 1.5 seconds to meaningful content, excluding first network fetch | 20 transitions with warmed cache; report slow network separately |
| Booking slot availability refresh | P95 ≤ 3 seconds on a representative Egyptian 4G connection; never present unverified slots | 20 controlled staging RPC requests, record time-to-verified-data plus error rates |
| Flutter frame rendering | ≤ 5% frames over 16.7ms and no visible freeze over 250ms on target 60Hz device | Flutter DevTools frame timeline on scrolling discovery, booking, and owner dashboard |
| Peak application memory during 10-minute navigation | ≤ 350 MiB on reference mid-range Android handset | Android Studio/DevTools memory profiler; measure clean session and repeated navigations |
| Downloadable Android release APK | ≤ 80 MiB (initial guardrail only) | Clean signed/unsigned release build, file byte count; note ABI splitting and bundle size separately |

**Conditions:** run on a real mid-range Android device (record device, RAM, API), Arabic/RTL as well as English, normal vs poor network, and with realistic staging data. Never infer p95 from a single sample. If a metric is not instrumented, mark **NOT MEASURED**, not PASS. iOS acceptance needs a separate recorded iPhone baseline.

**Current evidence:** [Android public smoke workflow](../.github/workflows/android-e2e-smoke.yml) and [Android smoke verification](VSP_ANDROID_E2E_SMOKE_VERIFICATION_58.md) establish app bootstrap/onboarding smoke on an API 35 emulator, **not** any of the performance targets. Tasks 60.02–60.09 remain open until profiling, APK measurements and release acceptance are performed. Closing **60.01** certifies only the presence of an explicit, testable budget.

## 59.07 — Staging multi-role test blockers (documented, not resolved)

- Current Android smoke covers welcome, language switching, skip onboarding, login screen and editable fields, **not successful login**. Source: [Android smoke evidence](VSP_ANDROID_E2E_SMOKE_VERIFICATION_58.md) and [successful run 43320006172](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006172).
- No evidence is attached here of two isolated staging player accounts, a venue owner test account, a staging admin role, or fixture lifecycle/cleanup. Therefore 59.01–59.06 cannot be accepted based on public smoke.
- Booking, payments, team invitations, challenges and admin role tests require controlled staging identities and seeded non-customer test fixtures, plus negative-permission checks. Real payment movement or production modification is not authorized by these documentation tasks.
- The workflow is labelled staging and passes explicit Supabase project configuration, but **the label alone is not evidence of complete production/staging isolation**. Document project IDs, credentials permissions, payment sandbox endpoint, and test-data cleanup before accepting 59.08.
- Build/CI success proves compilation and scoped tests, not two-user or end-to-end staging scenarios. No successful credentialed login or real payment scenario is claimed.

**Decision:** **59.07** is complete as a transparent blocker register, **not** as blocker remediation. Do not mark 59.01–59.06 or 59.08 complete until direct evidence exists.

No repository secrets or end-user data reproduced. No change to production, payments, or `main`.
