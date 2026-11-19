# VSP staging — anonymous view access regression evidence

Date: 2026-11-07. Project: `vtwgqyxglevcsxwdmhop`. Related: #38. **Read-only role-based tests** using `BEGIN READ ONLY; SET LOCAL ROLE anon; SELECT count(*) ...; ROLLBACK;` executed individually.

| Object | Anonymous result |
|---|---|
| `public.stadiums` base table | 2 rows visible through RLS |
| `public.courts` view | 17 rows visible |
| `public.owner_subscription_status` view | ERROR 42501: permission denied for function `is_admin_or_cofounder` |
| `public.public_subscription_plans` view | 2 rows visible |
| `public.tournament_clean_sheets` view | 0 rows visible |

## Finding
**Confirmed read-scope mismatch:** the `courts` view exposes 15 more stadium rows to `anon` than direct `stadiums` SELECT. The view definition selects from `stadiums` without filtering and lacks `security_invoker=true`. This is evidence of bypassing the base-table RLS visibility constraint, **not** proof that personal data was exfiltrated. `owner_subscription_status` is currently unusable by `anon` due to function permissions; do not assume it leaks owner data from this test.

## Next safe change gate
- [ ] Identify Flutter, REST, RPC and migration consumers of `courts` and determine whether any rely on viewing unverified, blocked, or deleted stadiums.
- [ ] Verify authorized owner access, including owned unverified stadiums, under a real authenticated JWT and admin/service roles.
- [ ] Design minimal correction (`security_invoker=true` is a candidate), run regression tests and review before applying on staging; do not apply blindly to all views.
- [ ] Re-run role matrix and security advisor after any approved schema change.

No schema, data, permissions or production changes were made during these tests.
