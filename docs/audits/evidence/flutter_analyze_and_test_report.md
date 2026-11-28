# VSP — Local & CI Verification Evidence (Analyze, Tests & Web Builds)

- **Timestamp (UTC):** 2026-11-28T06:52Z
- **Branch (`VSP.App`):** `feat/vsp-recovery-gamification-ds` (PR #47)

---

## 1. Flutter Analyze (`flutter analyze --no-pub`)
- **Result:** `No issues found! (ran in 13.9s)` — **Exit Code `0`** (executed AFTER `no_show_dispute_service.dart` security fix).

---

## 2. Full Flutter Test Suite (`flutter test --no-pub --reporter expanded`)
- **Scope:** Full local test suite executed without skipped or relaxed assertions.
- **Outcome:** **724 Passed, 2 Failed (`EXIT_CODE=1`)**.
- **Exact Failing Cases (Windows Host vs Linux Golden Baselines):**
  1. `test/unit/design_system_and_formatter_test.dart`: `VSPPaymentSummaryCard & Component Goldens matches golden snapshot for canonical 100 EGP breakdown (LTR)`
  2. `test/unit/design_system_and_formatter_test.dart`: `VSPPaymentSummaryCard & Component Goldens matches golden snapshot for PrimaryButton & VSPStateView`
- **Root Cause Note:** `test/unit/goldens/*.png` are Linux CI baselines (`.github/workflows/update-goldens.yml`); on GitHub Actions Ubuntu runner (`run 46117217355`, Step 11 `Test`), `flutter test --coverage` passed (`completed success`). On Windows desktop font rasterization differs slightly in subpixel anti-aliasing. All **724** unit/widget/security/championship/booking tests passed cleanly on Windows.

---

## 3. GitHub Actions CI Status (`VSP.App` PR #47)
- **Run checked:** `https://github.com/mohamedsalh333555/VSP.App/actions/runs/46117217355` (`commit 329e2404`, job `140893625412`)
  - Step 9 `Verify real Firebase client options`: `success`
  - Step 10 `Analyze`: `success`
  - Step 11 `Test`: `success`
  - Step 13 `Build Android debug APK`: **`failure`** (step exit code 1)
- Earlier run `46114833022` was `cancelled` due to workflow concurrency (`cancel-in-progress: true`) on subsequent commits.
- Note: PR #47 CI is currently `PARTIAL` until `Build Android debug APK` passes on GitHub Actions (local `app-staging-debug.apk` built cleanly; CI failure logs require authenticated repo maintainer access — GitHub returned `403` for unauthenticated log download).

---

## 4. Web Repositories Production Builds (`npm run build`)
- **`vsp_website` (`feat/unify-commission-paymob-fees`, PR #5):** `next build` (`Next.js 15.5.29`) compiled cleanly in `21.5s`, generating 17 static/dynamic routes with **Exit Code `0`** after removing hardcoded Prod URLs in `PricingClient.tsx` and `server.ts`.
- **`vsp-admin-panel` (`feat/unify-commission-paymob-fees`, PR #11):** `vite build` (`vite v5.4.21`) transformed 1,109 modules and built cleanly in `21.91s` with **Exit Code `0`** including the updated `src/pages/PayoutSettlementsPage.jsx` dual-commission & reconciliation ledger columns.
