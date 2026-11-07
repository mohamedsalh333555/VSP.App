# VSP Supabase runtime review — 2026-11-01

Project: `mktqkddbcddrxjxabdua`  
Review type: read-only advisor, schema, Edge Function inventory, and log inspection. No SQL, policy, migration, or function deployment was performed.

## Confirmed findings

### 1. `public.teams_public` view — security advisor ERROR

- Supabase security advisor reports one `security_definer_view` error for `public.teams_public`.
- Live catalog inspection confirms `pg_class.reloptions IS NULL`, so the view has no `security_invoker=true` option and currently uses PostgreSQL's default SECURITY DEFINER view behavior.
- `authenticated` has SELECT on the view; `anon` does not.
- The underlying `public.teams` table has RLS enabled policies restricting SELECT to the captain, team members, and admins/co-founders.
- The view projects public-facing team fields (including captain identity/name, stats, governorate, bio, and team presentation fields). Because it is SECURITY DEFINER, it can bypass the base-table RLS boundary for authenticated callers.

**Proposed remediation for product-owner decision:** confirm whether all teams should be discoverable by every signed-in user. If yes, keep the explicit public projection but convert the view to `WITH (security_invoker = true)` and add a narrowly scoped SELECT policy that exposes only the intended public team rows/columns through the supported data model. If no, revoke authenticated SELECT and route team discovery through a scoped RPC/repository. Do not apply either option until the intended visibility contract is confirmed, because changing it can break player team discovery.

### 2. SECURITY DEFINER RPC advisor warnings

- Security advisor reports 198 SECURITY DEFINER functions executable by `authenticated`.
- This count is not proof that all 198 are exploitable: several inspected examples contain explicit role/ownership checks, and the advisor flags the EXECUTE surface regardless of the function body's authorization.
- Sample review:
  - `accept_join_request`: verifies caller is the booking creator or stadium owner; anon EXECUTE is false.
  - `admin_register_owner_on_behalf`: verifies the caller's database role is admin/co_founder (or service_role); anon EXECUTE is false.
  - `admin_set_admin_role_atomic`: checks founder role, blocked state, protected targets, and self-change; anon EXECUTE is false.
- Required next step is a function-by-function inventory of grants and in-body authorization. Do not mass-revoke EXECUTE or change SECURITY DEFINER to INVOKER without dependency and authorization review.

### 3. Other advisor results

- Auth leaked-password protection: one warning; currently not enabled.
- RLS initplan: 44 warnings.
- Unused indexes: 79 informational findings.
- Multiple permissive policies: 50 warnings.
- These require grouped, evidence-based remediation; duplicate permissive policies are not automatically a vulnerability when predicates are intentionally additive.

### 4. Last-24-hour log review

- PostgREST logs: 136 error-like events; 79 are explicitly `Warp server error: Thread killed by timeout manager`.
- Postgres logs: 5,377 events; no ERROR/FATAL/PANIC/WARNING severity rows were returned by the severity query.
- Edge logs: 314 events; no error-like messages were returned by the message scan.
- The Warp timeout entries contain only the generic root path `/` and system runtime metadata; they do not identify a request route, RPC, table, or SQL statement. Therefore the exact caller/root query cannot be attributed from these log records alone. This is a gateway/request timeout signal, not evidence of a Postgres ERROR.
- The first aggregate query used an unsupported `level` column and was discarded; the final queries used the observed `event_message`, `source`, and `log_attributes` fields.

## Edge Function inventory

All listed functions are ACTIVE:
- `fcm_push` v20 — `verify_jwt=false`
- `create_paymob_intention` v33 — `verify_jwt=true`
- `process_paymob_refund` v20 — `verify_jwt=true`
- `paymob_webhook` v45 — `verify_jwt=false`
- `vsp_copilot` v123 — `verify_jwt=true`
- `process_tournament_refund` v16 — `verify_jwt=true`
- `create_owner_web_checkout` v10 — `verify_jwt=true`
- `get_owner_web_checkout_status` v7 — `verify_jwt=true`

The unauthenticated JWT setting on webhook/push endpoints is not changed based on inventory alone; those endpoints require endpoint-specific signature/secret verification review.

## Change gate

No database changes were made. The `teams_public` visibility contract and any RPC grant changes need explicit approval of the exact SQL before implementation. The Warp timeout root cause remains unproven until request-level telemetry or a correlated client/RPC trace identifies the caller.
