# VSP Phase 8 — live Supabase Security Advisor integration checkpoint

**17 November 2026 — Branch:** `uxlp-44-implementation`. Read-only audits and repository source changes only. No Supabase DDL, migration deployment, Paymob payment, storage access, production write, release, or `main` merge.

## Current direct MCP Security Advisor snapshot (read-only)

- Hosted staging `vtwgqyxglevcsxwdmhop`: **229 WARN / 0 ERROR**, comprising **224** authenticated-executable SECURITY DEFINER routines, **4** public-schema extensions, **1** leaked-password-protection setting.
- Hosted production `mktqkddbcddrxjxabdua`: **198 WARN / 0 ERROR**, comprising **197** authenticated-executable SECURITY DEFINER routines and **1** leaked-password-protection setting.
- The staging and production warning counts differ. They do **not** prove exploitability, live JWT isolation, or identical schemas. Role grants and in-function guards must be inspected before any revoke or function rewrite. Leaked password protection remains explicitly deferred by the project owner.
- This read-only snapshot is not evidence that the new CI workflow has authenticated to Supabase or that production release has passed.

## New source-level integration

- `scripts/check_supabase_security_advisor.py` uses the documented experimental `GET /v1/projects/{ref}/advisors/security` Management API with a **read-only** `advisors_read`-authorized token (OAuth `database:read`), rejects missing/invalid responses, HTTP failures, unknown severities, and unavailable-advisor findings; outputs rule/count summaries without sensitive metadata.
- `test/tooling/test_supabase_security_advisor.py` exercises missing credentials, malformed responses, WARN/ERROR classification, strict release denial, metadata redaction, GET-only transport, and workflow order, offline.
- `.github/workflows/vsp-supabase-security-advisor.yml` validates contract tests on branch pushes and provides an **explicit manual** read-only staging or production check. No live call on every push. A missing fine-grained GitHub secret named `SUPABASE_ADVISORS_READ_TOKEN` fails closed.
- The manual signed APK workflow calls the **live production** Security Advisor `--strict-warnings` after its existing reviewed-security declaration, before signing. Existing HOLD remains. All present warnings block that release unless individually resolved and a future reviewed policy is authorized; no warning is silently ignored.
- Supabase's Management API advisor endpoint is experimental: https://supabase.com/docs/reference/api/v1-get-security-advisors

## Acceptance policy and open work

- Do **not** mark 80.05 accepted until the GitHub Actions live workflow successfully authenticates and validates actual hosted report(s) with approved warning disposition. A passing mocked test cannot prove that.
- **80.04 ACCEPTED narrowly** after the source-unit CI [SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44126115477) on commit `5c6aabc` and the direct hosted MCP read-only snapshots above. Release-gate CI [SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44126114428). The GitHub **live-advisor job is SKIPPED**, so 80.05 and 80.06 stay open.
- Current baseline **633 unique / 269 accepted / 364 open** after exact source CI; +1 existing ID, +0 new task IDs. Not a signed release or live CI Advisor check.
