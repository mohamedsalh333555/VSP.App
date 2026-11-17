# VSP — Supabase Security Advisor read-only verification (2026-11-17, evening)

Scope: `mohamedsalh333555/VSP.App`, branch `uxlp-44-implementation`. Queried **security advisors only** for the VSP staging and production Supabase projects; no SQL, migration, auth setting, Storage, Edge Function or payment change was made.

| Supabase environment | ERROR findings | WARN findings | Grouped details |
| --- | ---: | ---: | --- |
| vsp-staging | 0 | **229** | 224 authenticated-callable SECURITY DEFINER function findings; 4 public-schema extension findings; 1 leaked-password-protection-disabled finding |
| VSP production | 0 | **198** | 197 authenticated-callable SECURITY DEFINER function findings; 1 leaked-password-protection-disabled finding |

The counts above are individual **advisor findings**, not confirmed security vulnerabilities; in particular, a callable privileged function is not necessarily exploitable. These are a point-in-time observation, not an exploit test, a release approval or evidence that newer Storage advisories do not apply.

Sources / remediation:
- [Supabase executable SECURITY DEFINER RPC advisory](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Supabase public extension advisory](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)
- [Supabase leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

## What remains open

1. Verify privileged RPC caller authorization with real isolated staging identities, especially booking, subscription, refund and admin paths, before changing any EXECUTE grant. Issue #38 is **not closed**.
2. Confirm project-level password protection setting/appropriate mitigation before changing any authentication configuration.
3. Confirm hosted Storage service versions and signed-upload paths, JWT hooks and two-user Storage permission tests for tasks 85.01–85.03. PostgreSQL engine version alone does **not** prove the hosted Storage version or patch status.
4. Keep production, live Paymob, `main`, and any data-destructive operation unchanged. `RELEASE HOLD` remains in effect.

## Related code-only notification work

Commits `ce3ccf4`, `2a4ef2c`, and `80fefcc` add best-effort local opt-out rechecks while scheduling reminders and protect booking-confirmation inbox writes against an account switch, with scoped Flutter tests. This is **not** a server-side FCM opt-out, marketing consent source of truth, or device delivery verification. Tasks 54.04/54.07/54.08 must not be silently closed by this read-only advisor review.
