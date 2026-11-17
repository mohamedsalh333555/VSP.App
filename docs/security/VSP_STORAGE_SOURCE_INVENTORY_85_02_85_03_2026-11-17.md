# VSP Phase 8 — Automated Storage upload source inventory

**Scope:** 85.02 / 85.03 partial source inventory; review-only, not P0 closure.

The new source scanner `scripts/audit_storage_upload_routes.py` locates explicit AWS S3/SigV4 presigned-upload indicators and signed resumable/TUS route indicators across the Flutter client, Edge Functions, Firebase Functions, web app and relevant native/platform source. It excludes documentation, test fixtures and generated sources, and emits paths, line numbers and risk categories **only**; no source snippets, secrets, object names or user data.

The GitHub workflow runs synthetic offline scanner tests and stores a bounded JSON evidence artifact. It is **advisory inventory**, not a security proof: zero matches cannot establish absence of runtime-generated URLs, third-party libraries, externally managed clients, native compiled dependencies, out-of-repo admin services, or hosted Storage service version/patch level. The scan does not contact Supabase.

Relevant advisories (official): 
- https://github.com/supabase/storage/security/advisories/GHSA-3m3f-pjv4-x2fp (S3 SigV4 presigned PUT / CopyObject)
- https://github.com/supabase/storage/security/advisories/GHSA-8rrf-w776-x75g (signed TUS/resumable upload routes)
- https://github.com/supabase/storage/security/advisories/GHSA-fgvp-cqg6-q8h2 (role none Storage RLS)

No hosted runtime version was measured. `supabase/.temp/storage-version` is a local CLI cache, not proof of cloud Storage. **85.01, 85.02 and 85.03 remain OPEN** pending provider-verified hosted patch and real two-account tests, as documented in `VSP_SUPABASE_STORAGE_PAYMOB_SECURITY_INTAKE_2026-11-17.md`.

Branch `uxlp-44-implementation`. No production mutation, new roles, schema changes, keys or deployment. Task inventory still 633 unique / 272 accepted / 361 open until evidence-led promotion.
