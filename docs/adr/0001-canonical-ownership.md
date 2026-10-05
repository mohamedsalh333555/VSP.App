# ADR-0001: Canonical Ownership Rules

## Status
Accepted

## Context
VSP has multiple domains with asynchronous writes, realtime updates, financial state, and a Flutter presentation layer.

## Decision
Each business fact must have exactly one canonical owner.

| Fact | Canonical owner |
|---|---|
| Authentication identity | Supabase Auth |
| User role/profile | `public.users` |
| Booking participant membership | `bookings.joined_user_ids` |
| Booking-player read projection | `booking_players` trigger projection |
| Booking conflict | PostgreSQL exclusion/atomic booking RPC |
| Payment reconciliation | PostgreSQL payment-reconciliation trigger/state |
| Subscription entitlement | server-side subscription authority |
| Direct-chat eligibility/write window | server RPC |
| Support state | `support_tickets` |
| Reports | `reports` + administrative workflow |
| UI-derived lists | Provider selectors |
| Cache | non-authoritative projection |
| Error presentation | centralized application error handler |

## Consequences
New features must connect to the existing owner instead of introducing a second copy of the same fact.
