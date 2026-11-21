# VSP — staging/production separation for current automated test harness (59.08)

**Inspection date:** 2026-11-13. **Acceptance scope:** documentation of the *currently audited automated staging/public/isolated test flows*. Does not certify every staging data row is synthetic or that future credentialed user journeys are safely provisioned.

## Verified target separation

- Connected Supabase **project metadata only** identifies separate projects:
  - **Staging:** `vsp-staging`, ref `vtwgqyxglevcsxwdmhop`, eu-west-2.
  - **Production:** `VSP`, ref `mktqkddbcddrxjxabdua`, eu-west-1.
- Project IDs and API endpoints are different. A different project identifier establishes distinct targets but, **by itself, does not prove data cloning, identity isolation, payment-merchant separation, backups, privileges or secret-rotation hygiene.**
- [Staging Live Contract workflow](../.github/workflows/staging-live-contract.yml) passes the **staging-specific** HTTPS endpoint and a publishable key, runs [anonymous read-only contract checks](../test/db_live_verification_test.dart) only after an opt-in define, and includes an additional **exact staging-URL runtime assertion**. Production or unexpected URL fails the live guard; arbitrary non-staging URL is never treated as a valid test target.
- [Staging guard source tests](../test/tooling/test_staging_live_project_guard.py) check for immutable staging target in the test and workflow, no direct anonymous table writes, and loopback-only SQL runner. [Actual staging live workflow 43488898684](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43488898684): **success**. All 4 project-boundary guard tests passed and all 10 anonymous/live Dart test assertions passed. No authenticated user session or test account was created by this contract.

## Synthetic and local-only CI data

- [Account SQL security contracts](../scripts/run_account_security_contracts.py) require `VSP_CONTRACT_ISOLATED=1` plus loopback PostgreSQL, an explicitly named scratch DB and fixture owner; they reject remote hosts. [SQL CI 43488908311](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43488908311) passed. These contracts run fixture identities and SQL states locally, not on a customer Supabase project.
- The [owner stadium capacity race harness](../scripts/test_owner_stadium_capacity_concurrency.py) and [trial default harness](../scripts/test_owner_trial_default_isolated.py) each create and delete their own disposable databases on localhost and use fixed synthetic UUIDs or integers. [SQL CI 43488898558](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43488898558) confirms these isolation/negative cases passed.
- The [Android public smoke workflow](../.github/workflows/android-e2e-smoke.yml) explicitly targets the staging URL; its [smoke scenario](../integration_test/app_public_smoke_test.dart) covers unauthenticated welcome/language/skip/login-UI interactions. It does **not** sign in, create stadiums, run bookings or test real payments. No personal customer credentials were supplied for these reviewed workflows.

## What is **not** yet established

- A staging database may contain existing user/customer records; **absence of customer data in staging has not been independently verified**, and no production user rows were inspected. Current CI's synthetic/no-login behavior is a narrower claim than full environment data isolation.
- Staging role-based **real-account journeys** and synthetic-account provenance, role entitlements, password/email ownership, fixture cleanup and negative cross-account tests require a separate approved fixture lifecycle. See tasks **59.01–59.06** and **79.01–79.08**; do not use customer accounts.
- The current **Paymob sandbox merchant/configuration and transaction destination isolation remain unverified**; no payment sandbox, webhook, refund, subscription activation or real money movement was attempted. Do not substitute production payment credentials.
- Distinct database projects do not certify that external Firebase, analytics, storage, FCM or Paymob endpoints are isolated; verify those explicitly before any credentialed staging tests.
- No staging/production schema or customer-data mutation, app deployment, APK release or `main` merge was part of this documentation/guard batch.

**Task 59.08 acceptance boundary:** written proof of isolation and non-use of real customer data **in the enumerated automated test workflows**, coupled with an exact-target fail-closed staging guard. Wider credentialed staging journeys and third-party environment isolation stay open; this document does **not** claim full staging readiness or production equivalence.
