# Staging — Rate limit and booking QR authorization guard fixes

Date: 2026-11-07. Staging Supabase `vtwgqyxglevcsxwdmhop`. Related issue #38, tracker item 77.

## Applied migration

`secure_rate_limit_and_booking_qr_caller_identity`

- `public.check_rate_limit(uuid,text,integer,integer)` no longer trusts `current_user` (SECURITY DEFINER owner) to determine whether caller identity must be checked. Uses `auth.role()` to distinguish service role from ordinary JWT requests. For ordinary callers, the effective user is `auth.uid()` rather than supplied `p_user_id`.
- `public.generate_booking_qr_token(uuid)` no longer trusts `current_user` to skip authentication or booking participant authorization. Both guards use `auth.role()`; existing participant checks remain intact.

## Verified staging tests

- Catalog: both functions contain **no `current_user`** after migration.
- `BEGIN; SET LOCAL ROLE authenticated; SELECT public.check_rate_limit('00000000-0000-0000-0000-000000000000'::uuid,'security_probe',10,60); ROLLBACK;` -> **false** without JWT.
- `BEGIN; SET LOCAL ROLE authenticated; SELECT public.generate_booking_qr_token('00000000-0000-0000-0000-000000000000'::uuid); ROLLBACK;` -> `{success:false,error:'Authentication required'}` without JWT.

These are negative role-level tests only. Need authenticated player/owner/admin JWT positive and cross-account tests, concurrency tests for rate limiting, and QR creation/scan flow E2E. Do not close item 77 yet. No production or main changes.

Cumulative fixes in this batch: cancellation authorization, 1v1 payment confirmation, 1v1 admin finalization, cash-debt admin settlement, rate limiting, booking QR generation = **6 functions**.
