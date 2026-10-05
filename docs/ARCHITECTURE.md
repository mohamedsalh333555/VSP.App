# VSP Architecture

## System shape

VSP is a Flutter client over Supabase Auth/Postgres/Storage/Realtime/Edge Functions. Firebase is used only for FCM, Analytics, and Crashlytics.

```
UI
  -> Provider / presentation state
  -> Coordinator / use-case orchestration
  -> Repository
  -> Supabase RPC / Edge Function / query
  -> PostgreSQL
```

## Canonical ownership

- Supabase Auth owns authentication identity.
- `public.users` owns persisted application profile and role.
- Server-side RPCs own authorization and business mutations.
- PostgreSQL owns booking conflicts, payment/reconciliation state, and lifecycle constraints.
- `bookings.joined_user_ids` is the canonical participant projection currently used by the booking state machine; `booking_players` is synchronized from it by trigger and is a read projection.
- Provider state is presentation state only; derived lists are selectors.
- Cache and Realtime are transport/projection mechanisms, never authoritative business truth.
- `go_router` owns route definitions; shell screens must not become a second business authorization layer.
- App errors are converted at the application boundary and rendered by the centralized error presenter.

## Product boundaries

### Player
Booking, joining public matches, teams, tournaments, support, reports.

### Stadium Owner
Stadium operations, bookings, tournaments, financial operations, subscription/entitlement, owner-only Copilot.

### Admin
Moderation, reports, support tickets, financial review, account controls.

## Database change policy

Every schema change must be committed as a timestamped SQL migration. Production changes must never exist only as ad-hoc SQL.

## New feature path

1. Define the business owner and source of truth.
2. Add/extend the domain model only when the existing model cannot represent the fact.
3. Put persistence in a repository.
4. Put orchestration in a coordinator/use case.
5. Expose presentation state through Provider.
6. Add localized copy to ARB.
7. Use an existing Design System component/token.
8. Add unit/integration coverage for the business rule.
9. Verify CI before merge.

## Non-goals

Do not create parallel state stores, duplicate database writes, or UI-level authorization rules.
