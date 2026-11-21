# Staging RLS permissive-policy overlap and exposed-role triage

Date: 2026-11-13. Staging project `vtwgqyxglevcsxwdmhop`. **Read-only PostgreSQL catalog, role-scoped aggregate SELECTs and Supabase Advisor**. No user/phone/invitation code values were fetched and no policy, grant or schema was changed.

## Grounded counts (scope explained)

- Performance Advisor: **50** `multiple_permissive_policies` warnings. Official remediation: https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies
- `pg_policies` exact same tablename/command/role/USING/WITH CHECK definition: **0 duplicated expression groups**.
- Same *literal* role + *literal* SELECT command overlap: **5 tables** (`financial_audit_logs`, `support_ticket_messages`, `support_tickets`, `teams`, `transactions`).
- Expanding `FOR ALL` to each CRUD action and grouping per literal role/action yields **27 overlapping policy-action groups on 17 tables**, including **13 SELECT, 6 INSERT, 4 UPDATE, 4 DELETE**.
- These three numbers measure different things and cannot be treated as exact equivalents. Advisor grouping also considers role applicability/inheritance. Some policies are intentionally OR'd to allow owners, administrators and public team directory consumers; no blind policy deletion or automatic merging.

## Concrete policy permission review

`teams_public_directory_select` has a TRUE predicate for `authenticated`, and there are additional owner/team-member SELECT policies. This does **not** by itself prove sensitive columns are exposed:
- Current Staging `authenticated` role has no table-wide SELECT on `public.teams`; it has column-scoped SELECT for directory fields, but **no SELECT on `captain_phone` or `active_invite_code`**.
- `anon` currently has broad column/table grants, but the transaction-scoped `SET LOCAL ROLE anon; SELECT count(*) FROM public.teams` returned **0 visible team rows** under RLS.
- Neither a role-scoped authenticated end-user JWT session nor production grants were checked; future grant or policy drift can change the result. Do not remove the private columns' protections or assume existing exposed columns are privacy-reviewed.

Other observed overlaps:
- `financial_audit_logs`: admin ALL plus owner/user SELECT paths. Collapsing these carelessly could grant broader financial read/write privileges.
- `support_tickets` and `support_ticket_messages`: staff and requester/user SELECT rules have different scopes, including `is_internal` message handling.
- `transactions`: admin SELECT plus owner/participant-specific SELECT (financial data, P0 if widened).
- `teams`: directory-wide and member/captain SELECT policies, requiring explicit column grants and role tests.

## Advisor baseline / connection to broader work

Security Advisor on this staging snapshot: **200** authenticated-executable SECURITY DEFINER functions (not 200 proven exploits), 4 extensions in public and 1 leaked-password protection warning. Performance Advisor: **44** auth RLS initplan warnings, **50** multiple permissive policy warnings, 1 unindexed foreign key and 135 unused-index observations.

Selected RPC source inspections: `activate_vsp_pro` and `admin_create_owner_with_stadium_atomic` contain active admin gates; legacy `add_team_member_atomic` rejects direct member insertion; `accept_join_request` and `reject_join_request` have NULL-sensitive authorization logic (plus acceptance lacks pending consent and idempotency), with **unapplied** branch fixes and isolated CI negative/positive checks. Risks: [Issue #38](https://github.com/mohamedsalh333555/VSP.App/issues/38) and [Issue #40](https://github.com/mohamedsalh333555/VSP.App/issues/40).

**Scoped acceptance:** only 75.03 — identify and classify the actual overlapping policies using read-only metadata. Tasks 75.04–75.07 remain OPEN. The security impact of all 200 definer RPCs and equivalence of any RLS policy merge are not established. All schema, production data and main branch remain unchanged.
