# Staging — 3 of 4 SECURITY DEFINER views hardened

Date: 2026-11-07. Staging Supabase project `vtwgqyxglevcsxwdmhop`. Related issue #38, 80-item tracker security item.

## Applied migrations (staging only)

1. `secure_courts_view_with_invoker_rls`: `ALTER VIEW public.courts SET (security_invoker = true);`
2. `secure_public_catalog_and_clean_sheets_views`:
   - `ALTER VIEW public.public_subscription_plans SET (security_invoker = true);`
   - `ALTER VIEW public.tournament_clean_sheets SET (security_invoker = true);`

## Tests

- Anonymous `courts` count: **17 before**, **2 after** (matching base-table RLS visibility).
- Anonymous `public_subscription_plans`: **2** rows after; authenticated database role: **2** rows after.
- Anonymous `tournament_clean_sheets`: **0** rows after; authenticated database role: **0** rows after; both queries succeed.
- Supabase security advisor `security_definer_view` ERROR count: **4 before**, **1 after**; remaining view is `public.owner_subscription_status`.

These are database-role checks; **authenticated checks did not include a real user JWT**. App consumer and owner/admin authenticated regression tests are still required. No production or main changes.

## Outstanding

- [ ] Investigate and safely fix `owner_subscription_status`, including its `is_admin_or_cofounder` function permission failure for anon.
- [ ] Test owner A/owner B/admin with authenticated JWT and check Flutter/REST/RPC consumers.
- [ ] Verify no other security regression; review privileged RPCs separately.

Reference: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view
