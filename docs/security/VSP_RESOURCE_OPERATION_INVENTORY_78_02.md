# VSP — 78.02 Resource and operation inventory

Date: 2026-11-11. **Source-level inventory of major resource families and operations** for authorization-matrix design. This is not an exhaustive RPC enumeration, database grant audit, or proof of enforcement.

| Resource | Operations to authorize | Observed source consumer / implementation | Principal boundary to verify next |
|---|---|---|---|
| User account/profile | read own profile, register, edit own profile, role changes, deletion | `lib/core/providers/auth_provider.dart`; `supabase/migrations/20260829_harden_auth_roles_and_registration.sql` | own user vs admin/service_role; prevent role escalation |
| Stadiums and owner data | public discovery, owner create/edit, operating hours, verification | `lib/core/repositories/stadium_repository.dart` | public verified fields vs owner-only mutation |
| Booking and availability | create atomic booking, read player/owner booking, cancel, reconcile | `lib/core/repositories/booking/booking_creation_coordinator.dart`; `booking_query_coordinator.dart` | booking participant vs venue owner; atomic collision checks |
| Teams and membership | create, view, update, delete, invite, accept/reject, challenge code | `lib/core/repositories/team_repository.dart` | captain/member/recipient/other-team separation |
| Tournaments and leagues | register, roster, fixture, result, approval, standings | `lib/core/repositories/tournament_repository.dart`; `lib/core/repositories/league_repository.dart` | organizer/participant/approver roles |
| Notifications | read own, insert, mark read | `lib/core/repositories/notification_repository.dart` | recipient isolation and permitted event producers |
| Owner subscriptions | list public plans, view trial, start trial, checkout | `lib/core/repositories/owner_subscription_repository.dart` | owner identity, entitlement, server-authoritative payment |
| Payments and refunds | create intention, webhook reconciliation, refund | `supabase/functions/create_paymob_intention/index.ts`; `paymob_webhook/index.ts`; `process_paymob_refund/index.ts` | verified user/owner, trusted webhook, service-only settlement |
| Administration and reports | approve, audit, account controls, owner reports | `supabase/tests/account_security_manifest.json`; `supabase/migrations/20261111045628_require_active_admin_actor_for_sensitive_rpcs.sql` | active privileged actor, least privilege |
| Private files/storage | upload, read, delete owned objects, admin access | `supabase/migrations/20261111055255_restrict_blocked_admin_table_and_storage_privileges.sql` | owner/path/bucket-specific RLS |

## Inventory acceptance and exclusions

This task identifies **resource families, operation types, and implementation entry points** so that task 78.03 can define allowed/denied access per actor. It does not claim complete coverage of all 198 historically flagged privileged RPCs, storage buckets, SQL grants, or dynamic app consumers. Those are separately tracked in 77.*, 78.07, and 79.*. Existing tests in `supabase/tests/` cover only a scoped subset, per `account_security_manifest.json`. Do not interpret client-side filters as authorization. No SQL or production permissions were changed.
