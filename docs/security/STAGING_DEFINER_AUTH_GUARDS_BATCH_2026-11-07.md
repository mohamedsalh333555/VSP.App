# Staging: SECURITY DEFINER caller-authorization fixes (batch)

Date 2026-11-07. Supabase staging project `vtwgqyxglevcsxwdmhop`. Tracker item 77 (198 callable SECURITY DEFINER functions). Issue #38.

## Changes

Surgically replaced the `current_user = 'postgres'` exception in the authorization guard of these functions, preserving other code:

1. `public.cancel_booking_with_refund_atomic_impl(uuid,text)` — migration `fix_cancellation_definer_current_user_auth_bypass`.
2. `public.confirm_1v1_payment_atomic(text,text,numeric)` — migration `fix_1v1_payment_confirmation_definer_auth_bypass`.
3. `public.admin_finalize_1v1_tournament_atomic(uuid,uuid)` — migration `fix_admin_1v1_finalization_and_cash_settlement_definer_guards`.
4. `public.admin_settle_owner_cash_debt_atomic(uuid,numeric,text)` — same migration.

**Reason:** in SECURITY DEFINER functions, `current_user` resolves to the function owner (typically `postgres`) rather than the requesting user, so a `current_user != 'postgres'` check can bypass the intended authorization branch. New checks rely on `auth.role()` / caller identity, not `current_user`.

## Verified negative tests (staging)

Using `SET LOCAL ROLE authenticated` with no user JWT, each test was wrapped in `BEGIN ... ROLLBACK`:

- Booking cancellation with an existing confirmed booking: `success=false`, `code=unauthorized`.
- 1v1 payment confirmation with nonexistent order reference: `success=false`, `error=UNAUTHORIZED`, before order lookup.
- Admin 1v1 tournament finalization with placeholder UUIDs: `success=false`, `error=Unauthorized`.
- Admin cash-debt settlement with placeholder UUID: `success=false`, `error=Unauthorized: Admin privileges required`.

No persistent user/booking/payment changes were made by these probes. All four fixes applied only to staging.

## Wider audit inventory

306 SECURITY DEFINER functions in public; 198 executable by `authenticated`, 0 by `anon`; 11 authenticated-callable functions without direct `auth.uid`, `auth.role`, or `current_setting` in their own bodies require call-chain analysis, not automatic revocation. Further `current_user` patterns were found in `check_rate_limit`, `generate_booking_qr_token` and other functions; these are **not yet remediated**.

## Remaining gates

- [ ] Authenticated real JWT owner/player/admin and service_role positive tests, including Paymob webhook, refund, cash-debt settlement, 1v1 finalization.
- [ ] Review `check_rate_limit` and QR token creation for analogous bypasses.
- [ ] Run application CI/E2E for payment, bookings and competitions.
- [ ] Audit the rest of 198 callable functions, document safe/unsafe outcomes.

Do not close tracker item 77 until the full review and tests are complete. Production and `main` untouched.
