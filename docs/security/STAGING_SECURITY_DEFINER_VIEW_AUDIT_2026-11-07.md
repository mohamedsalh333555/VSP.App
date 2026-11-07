# VSP Staging — SECURITY DEFINER views: evidence and validation gate

Date: 2026-11-07. Project: staging `vtwgqyxglevcsxwdmhop`. Related: GitHub issues #37, #38. **Read-only findings; no production changes.**

## Verified schema facts
Supabase Security Advisor reports four `security_definer_view` ERROR findings. A direct catalog check found `reloptions = NULL` for all four and `has_table_privilege('anon', ..., 'SELECT') = true`, `has_table_privilege('authenticated', ..., 'SELECT') = true`.

| View | Source | Notable observation |
|---|---|---|
| `public.courts` | `stadiums` | Exposes owner_id, location, coordinates, operating times and other stadium columns |
| `public.owner_subscription_status` | `users` | Exposes owner name, phone, subscription plan, fee totals, trial and expiry dates; definition contains `id = auth.uid() OR is_admin_or_cofounder(auth.uid()) OR CURRENT_USER IN ('postgres','service_role')` |
| `public.public_subscription_plans` | `subscription_plans` | Active subscription plan catalog; likely intentionally public, but invoker behavior must be checked |
| `public.tournament_clean_sheets` | `tournament_matches` | Aggregates clean sheets from completed tournament matches |

All four underlying tables (`stadiums`, `users`, `subscription_plans`, `tournament_matches`) have RLS enabled. **A view's default execution privileges may bypass those base-table RLS rules; RLS enabled on a base table is not proof that a default view is safe.** The explicit `CURRENT_USER` condition in `owner_subscription_status` requires careful testing under the view owner and caller roles.

## Required before remediation
- [ ] Identify app/RPC consumers and intended public access for each view.
- [ ] Use **role-authenticated** test sessions to verify cross-owner access, especially owner phone/fee fields. Do not assume that catalog grants alone prove leakage.
- [ ] Inspect base-table RLS and underlying grants. Assess whether `security_invoker=true` will break intended access or whether a restricted API/view is needed.
- [ ] Add negative tests for anonymous, player, owner A, owner B, admin, and service role; confirm authorized positive cases.
- [ ] Implement a reviewed staging migration, verify with tests and advisors, and document rollback. **No bulk privilege revocation, production changes, or main merge.**

Other staging advisor results: 198 callable authenticated `SECURITY DEFINER` function WARN findings (not necessarily exploitable); 44 `auth_rls_initplan` performance findings.

References:
- https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
