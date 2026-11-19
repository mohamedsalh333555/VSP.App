# Staging — all four flagged SECURITY DEFINER views hardened

Date 2026-11-07. Staging project `vtwgqyxglevcsxwdmhop`. Related #38.

## Applied staging migrations

1. `secure_courts_view_with_invoker_rls`: `ALTER VIEW public.courts SET (security_invoker=true);`
2. `secure_public_catalog_and_clean_sheets_views`: `ALTER VIEW public.public_subscription_plans SET (security_invoker=true); ALTER VIEW public.tournament_clean_sheets SET (security_invoker=true);`
3. `secure_owner_subscription_status_invoker_and_restrict_anon`: `ALTER VIEW public.owner_subscription_status SET (security_invoker=true); REVOKE SELECT ON public.owner_subscription_status FROM anon;`

## Why the last view is private

`owner_subscription_status` selects owner name, phone, fee totals, subscription dates and other sensitive fields. Its `is_admin_or_cofounder(uuid)` helper is SECURITY DEFINER, executable by `authenticated` but **not** by `anon`. Previously anonymous querying raised permission denied. The new view uses invoker RLS and anonymous SELECT is revoked. Do not grant anon execute on the helper to work around that error.

## Verified checks

- Catalog: `owner_subscription_status` has `security_invoker=true`, `anon_select=false`, `auth_select=true`.
- SQL role `authenticated` with no JWT: `SELECT count(*) FROM public.owner_subscription_status` -> 0 rows, no SQL error.
- Security advisor: `security_definer_view` finding absent, **4 -> 0**.
- Previous tests: anon `courts` 17 -> 2, anon/authenticated public plan view 2, clean sheets view 0.

## Completion gate (NOT yet done)

- [ ] JWT-authenticated owner A/B and admin positive/negative tests for all four views.
- [ ] Confirm app/API consumers still function and service role behavior is appropriate.
- [ ] Run CI and targeted E2E for changed data paths.
- [ ] Review production deployment and rollback separately; production untouched.

No user data changed; no main merge or production deploy.
