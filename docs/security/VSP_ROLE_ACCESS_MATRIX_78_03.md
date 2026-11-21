# VSP — 78.03 Intended allow/deny role matrix

Date: 2026-11-11. **Policy design / acceptance contract, not deployed authorization evidence.** See [role definitions](VSP_ROLE_DEFINITIONS_78_01.md) and [resource/operation inventory](VSP_RESOURCE_OPERATION_INVENTORY_78_02.md).

**Legend:** A = intended allow subject to ownership/relationship and server validation; D = intended deny; P = public sanitized read only; S = privileged service/server flow only; C = conditional on admin role *and* active-account status. Neither `authenticated` nor possession of a team/booking identifier alone grants access.

| Operation | Anonymous | Player | Stadium owner | Active admin/founder | Server service |
|---|---|---|---|---|---|
| Read public verified stadium listing / public plan | P | P | P | P | A |
| Read/edit own profile | D | A | A | C | A |
| Change own role to admin / edit another user's role | D | D | D | C | S |
| Read own booking details | D | A | A | C | A |
| Read another user's unrelated booking | D | D | D | C (audited) | S |
| Create booking / challenge booking | D | A (eligible actor) | A (authorized flow) | C | S |
| Edit stadium owned by another owner | D | D | D | C | S |
| Edit own stadium / manage its bookings | D | D | A (ownership checked) | C | S |
| Create/manage own team and invitations | D | A (captain/recipient rules) | A (if eligible member) | C | S |
| Accept invitation addressed to another user | D | D | D | D | S (internal only) |
| Read own notifications / mark own read | D | A | A | C | A |
| Read unrelated private notifications | D | D | D | C (audited) | S |
| Owner subscription trial/checkout | D | D | A (own owner ID) | C (if eligible) | S |
| Settle payment / execute webhook/refund reconciliation | D | D | D | D (unless dedicated audited flow) | S |
| Read another owner's private financial report | D | D | D | C (audited) | S |
| Upload/delete another user's private files | D | D | D | C (audited and scoped) | S |

## Required enforcement and test criteria

1. Enforce permissions in database RLS/RPC and server functions; Flutter visibility/filtering is UX defense in depth only.
2. Test *allowed* own-account/owner/captain actions as well as *denied* unrelated-account, blocked-admin, anonymous and cross-owner actions.
3. Keep public views sanitized; prohibit `service_role` secrets in clients; verify webhook signatures and server-derived payment amounts.
4. Record policy exceptions, exact deployed role aliases, resource ownership joins, bucket policies and RPC execute grants before 78.04–78.07 or 79.* can close.
5. This is a **target access matrix**, not a statement that the current deployed schema matches it. Some roles/operations are conditional and require product and server-specific verification. No migrations, grants, or production state changed.

## Evidence pointers
- `lib/features/auth/screens/select_role_screen.dart`
- `lib/core/repositories/booking/booking_creation_coordinator.dart`
- `lib/core/repositories/team_repository.dart`
- `lib/core/repositories/stadium_repository.dart`
- `lib/core/repositories/notification_repository.dart`
- `lib/core/repositories/owner_subscription_repository.dart`
- `supabase/functions/create_paymob_intention/index.ts`
- `supabase/tests/account_security_manifest.json`
