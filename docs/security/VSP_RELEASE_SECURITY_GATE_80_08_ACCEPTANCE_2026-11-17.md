# 80.08 — Release must fail closed when a critical security finding remains

**Acceptance type:** scoped code + CI negative test, **not** live Supabase Advisor integration or production release readiness.  
**Date:** 17 November 2026 (Africa/Cairo). **Branch:** `uxlp-44-implementation`. No production/Staging mutation, store build, secret, key rotation or `main` merge.

## Implemented

- [4baa6521](https://github.com/mohamedsalh333555/VSP.App/commit/4baa6521a3483f95e69bfa608e1a2783c36d7eff) added `scripts/check_release_security_gate.py`, the fail-closed `docs/security/VSP_RELEASE_GATE_STATE.json`, nine isolated negative/positive tests and a dedicated no-secret `VSP Release Security Gate` CI job. The manual `build-release-apk.yml` now executes the gate **after checkout and before keystore configuration or APK compilation**.
- [340e4e89](https://github.com/mohamedsalh333555/VSP.App/commit/340e4e8955b0550f154402ba2aa7fff6b6e9163b) corrected Python's test-file import invocation after the initial CI failure. The corrected test command is `python3 test/tooling/test_release_security_gate.py -v`.
- The gate refuses **HOLD**, an open critical-finding array, absent reviewer/evidence, invalid or stale Git SHA, missing/invalid JSON, and non-matching schema. A synthetic fully approved state with matching SHA passes unit validation. This positive fixture does **not** change the committed HOLD state.
- Committed release state lists unresolved Storage advisory applicability, Paymob Sandbox/refund tests and independent JWT/RLS/Storage cross-account checks. It **intentionally blocks manual signed APK production/test-release builds** until a reviewed, evidence-backed status update and separate approval.

## Proof

- [VSP Release Security Gate — run 44111816114 **SUCCESS**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44111816114): **9/9 tests passed**, including critical synthetic finding → release denial and correct positioning before signing.
- [Initial run 44111651520 **FAILURE**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44111651520): Python unittest module path import collision, **corrected and retested**. Not a bypass or security exploit.
- This is a **declaration gate**; it does not automatically query the live Supabase security advisor or independently establish that a reviewer-approved evidence link is truthful. Tasks **80.04** (actual advisor checks) and **80.05** (full advisor/CI automation) are **OPEN**; 80.06 (fixing critical findings) also remains OPEN. A documented HOLD is not a clean security report.
- The gate is intended for a manual signed release. Debug/isolated tests can continue despite its HOLD. No APK was produced, signed, distributed or uploaded in this batch.

## Narrow task acceptance and counting

- **Accepted: 80.08**, only the automated test that a release gate fails upon an open critical finding, with the above explicit source/CI scope.
- Previously accepted **266** → **267**. The active scope remains **633** unique IDs; remaining **367** → **366**.
- This must **not** be described as full app/store readiness, passing Supabase Advisor, passing Paymob Sandbox, or as accepting 80.04/80.05/80.06. Other Phase 8 work remains open.
