# Batch08 — web deletion request and dependency security

2026-11-11. Private website PR4 merged at32b3f3ce8c858670767d9a97f2ecc54c024f8b4a after source c81e55ef531038fc7a2ef84eeec3a7c738d0411e passed [CI42968160243](https://github.com/mohamedsalh333555/vsp_website/actions/runs/42968160243). Vercel commit status subsequently SUCCESS.

Implemented: bounded/abortable deletion-request submission; synchronous/per-form duplicate prevention; strict confirmed HTTP receipt; generic transport errors and accessible labels. Receipt does not mean account deletion. Ownership verification remains manual. No customer request was submitted and no account deleted by verification.

Original npm audit:11 findings (1critical,9high,1moderate). Final audit:0. Next14.2.35 to supported maintenance15.5.29, React/DOM19.2.6, React19 types/Next ESLint config, patched PostCSS8.5.32 and scoped minimatch11.0.1. Existing Supabase2.112.4 unchanged and pinned. Node22 hosting/CI; audit and lint now mandatory. Exact versions/lock committed in the private repo. No forced peer install.

Validation:28 tests (19 behavioral+9 existing), full ESLint (one existing image-performance warning), typecheck and production build (15 static pages) pass locally on Node24 and in CI on Node22. First CI failed an old single-file test-command assertion; fixed to include all test files. No false success claim for that run.

Limitations: client deduplication is per form, not distributed anti-abuse; real ownership verification/deletion fulfillment and full legal retention/store disclosure review remain open. No model/prices changed. Core remains81/620 accepted,539 pending.

Primary references checked2026-11-11: https://nextjs.org/blog/nextjs-security-update-october-14-2026 (14Oct2026), https://nextjs.org/support-policy (Next15 maintenance through31Jan2027), https://nextjs.org/docs/app/guides/upgrading/version-15 , https://github.com/isaacs/minimatch/security/advisories/GHSA-g3hv-75wg-m249 (27Oct2026;fixed11.0.1). Package findings are dependency exposure, not proof every exploit applies to this hosted deployment. No production exploitation attempted.
