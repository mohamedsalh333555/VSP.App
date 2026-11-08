# 34.01 — Challenge status inventory and state ownership

## Stored challenge states

The checked-in constraint in `supabase/migrations/20261001130000_challenge_roster_and_status_constraint_fix.sql` explicitly allows `bookings.challenge_status` to be NULL or one of:

| Value | Meaning in the challenge booking lifecycle |
|---|---|
| `NULL` | No challenge-specific status recorded |
| `none` | Historical explicit absence of a challenge status |
| `ready` | Challenge set up and ready for the next workflow stage |
| `confirmed` | Challenge confirmed |
| `completed` | Challenge completed |
| `cancelled` | Challenge cancelled |
| `expired` | Challenge expired |

The migration removes the old default and sets the default to NULL. The `create_challenge_booking_atomic` RPC requires a challenge code and checks both participating teams. The Flutter `BookingCreationCoordinator` routes `BookingType.challenge` to that RPC and does not use ordinary `create_booking_atomic` for a challenge.

## Separate dimensions — do not conflate

- `bookings.status` describes the booking/slot lifecycle (pending, confirmed, completed, etc.).
- `bookings.challenge_status` describes the challenge workflow.
- Challenge invitation/code state may live in separate tables or RPCs; it is **not** equivalent to `challenge_status`.
- `match_result_status` and match outcome are separate from booking/challenge confirmation.

## Transition and enforcement boundaries

The allowed **values** above are proven by the checked-in SQL constraint; the constraint alone does **not** define every permitted transition or role authorization. The server must prevent an expired/cancelled challenge from being confirmed, validate both captains and teams, and atomically protect venue availability. Do not assume the client is the authority.

## Remaining work

Tasks 34.02–34.13 remain open for invitation creation, acceptance/rejection, cancellation, idempotency, eligibility, notifications and concurrent two-team end-to-end verification. Confirm the deployed constraint and any later migration overrides before changing production.
