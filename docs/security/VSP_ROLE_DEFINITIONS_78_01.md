# VSP — 78.01 Role definitions (source-level acceptance)

Date: 2026-11-11. Scope: **definition of roles only**, not permission-matrix or runtime authorization acceptance.

## User-facing roles
- **Player (`player`)**: regular player account; selectable on the role selection screen.
- **Stadium owner (`owner`)**: venue owner account; selectable on the role selection screen.
- **Administrator (`admin`)**: privileged operational account; **not** selectable through public signup.
- **Founder/admin variants (`co_founder`, `cofounder`, `super_admin`)**: recognized by the historical central admin helper. These are compatibility/privileged labels, not self-service signup options.

## Technical principals (not application account types)
- **`anon`**: unauthenticated Supabase database/API principal.
- **`authenticated`**: signed-in Supabase database/API principal. Authentication alone does not grant owner/admin privileges.
- **`service_role`**: server-only privileged service principal. Must never be exposed to Flutter/web clients.

## Source evidence
1. `lib/features/auth/screens/select_role_screen.dart`: public UI offers only `player` and `owner`.
2. `lib/core/providers/auth_provider.dart`: app distinguishes `isPlayer`, `isOwner`, and `isAdmin`.
3. `supabase/migrations/20260829_harden_auth_roles_and_registration.sql`: public signup role restricted to player/owner; sensitive-role escalation checks include admin/co_founder and service_role.
4. `supabase/migrations/20260926132000_central_admin_role_helper.sql`: helper recognizes admin/co_founder/cofounder/super_admin; execute grants distinguish authenticated/service_role from anon.

## Explicit limitations
This closes **78.01 (define roles)** only. It does **not** certify that every deployed environment has these exact migrations, nor that RLS, RPCs, storage, or admin-dashboard authorization is secure. Tasks 78.02–78.07 and 79.* remain open. Privileged role aliases require reconciliation against current deployed data before any access-policy changes. No production changes, credentials, or privileged API calls were performed.
