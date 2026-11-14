# Staging security fix: cancellation SECURITY DEFINER guard

Date 2026-11-07. Project `vtwgqyxglevcsxwdmhop`. Related issue #38; 80-item tracker privileged RPC review.

## Audit findings

Public-schema function catalog: 306 `SECURITY DEFINER` functions, 198 executable by `authenticated`, **0 executable by `anon`**. 11 authenticated-executable functions do not directly mention `auth.uid`, `auth.role`, or `current_setting` in their own definitions; many delegate checks, so this is **triage, not 11 proven vulnerabilities**.

The privileged `cancel_booking_with_refund_atomic_impl(uuid,text)` used:

```sql
IF coalesce(auth.role(), '') <> 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
```

Since this function is `SECURITY DEFINER` owned by `postgres`, checking `current_user` could skip the caller authorization block entirely. The public wrapper `cancel_booking_with_refund_atomic(uuid,text)` delegates to this implementation. The implementation itself is not executable by `authenticated`.

## Staging change

Applied staging migration `fix_cancellation_definer_current_user_auth_bypass` which surgically replaces the guard in the existing function definition with:

```sql
IF coalesce(auth.role(), '') <> 'service_role' THEN
```

The rest of the function definition was preserved. This keeps the explicit service-role path and enforces identity/ownership checks for ordinary JWT callers. Static verification: `old_bypass_present=false`, `guarded_by_jwt_role=true`, `impl_auth_executable=false`.

## Behavioral negative test

Using an existing **confirmed** booking UUID fetched by an admin query (UUID omitted from report), execute `BEGIN; SET LOCAL ROLE authenticated; SELECT public.cancel_booking_with_refund_atomic('<existing booking UUID>'::uuid,'security_rollback_probe'); ROLLBACK;` without JWT identity. Response: `{success:false, code:'unauthorized'}`. This confirms the wrapper now reaches the authorization block. Transaction rolled back. A read-only transaction cannot run this test because the function starts with `SELECT ... FOR UPDATE`.

## Still required

- [ ] Real JWT owner/player/admin positive and cross-account negative tests.
- [ ] Confirm service_role-only backend cancellation still succeeds when authorized.
- [ ] Test refund and cancellation workflows in Flutter E2E.
- [ ] Review remaining privileged RPCs for delegation and role bypasses.
- [ ] Production remains untouched; separate review and approval needed.
