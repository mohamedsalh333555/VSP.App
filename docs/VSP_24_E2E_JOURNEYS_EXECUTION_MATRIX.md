# VSP — 24 end-to-end journey inventory, prerequisites and account matrix

Status: **test design only**. This is the executable scope for 56.01, 56.02 and 56.09. None of the journeys below is marked passed. Do not use production users, live cards or real charges.

## Staging identity and data fixtures

- `PLAYER_A`: unique verified staging player, no venue ownership; `PLAYER_B`: second player and team captain; `PLAYER_C`: another player for cross-account checks.
- `CAPTAIN_A` / `CAPTAIN_B`: distinct captains of `TEAM_A` / `TEAM_B`; never use one identity for both approvals.
- `OWNER_A`: owner of `VENUE_A` in Aswan; `OWNER_B`: separate owner of `VENUE_B` for cross-tenant denial.
- `ADMIN_A`: dedicated admin identity; `WEB_VISITOR`: unauthenticated web user.
- Fixtures: venue slots (free/occupied/closed), two teams, invitation pending/accepted/rejected, booking pending/confirmed/cancelled, tournament 1v1 and venue championship, payment sandbox success/failure, free/paid subscription states.
- Store account identifiers and test credentials only in a secret manager or staging test environment, **not** in Git, CI logs or this document.
- Every scenario requires a clean fixture reset, stable request id, expected DB before/after snapshot, role-specific read/write assertions and redacted logs.

## Journey-to-prerequisite map

| ID | Role | Journey | Required accounts/data | Expected success invariant |
|---|---|---|---|---|
| P01 | Player | Register/login | fresh player email; verified OTP | player session only |
| P02 | Player | Complete profile | player account; optional avatar | profile persists after relogin |
| P03 | Player | Discover venues | player; Aswan venue dataset | correct filters and public data |
| P04 | Player | Venue details and availability | venue with opening hours and slots | no closed slot shown bookable |
| P05 | Player | Create booking | player; available venue slot | single booking and slot reserved |
| P06 | Player | Cancel/reschedule booking | owned booking; cancellation policy | correct state and refund policy |
| P07 | Player | Booking history and status | paid and unpaid bookings | only own records visible |
| P08 | Player | Payment success | sandbox payment instrument; owned booking | verified webhook and one settlement |
| P09 | Player | Payment failed/retry | sandbox declined payment | no duplicate charge or booking |
| P10 | Player | Create/join team | player; captain; invitation | membership authorized and persisted |
| P11 | Player | Accept/reject team invitation | invited player; second team | correct membership and idempotency |
| P12 | Player | Select active team | player with two teams | correct active team after relogin |
| P13 | Player | Create team challenge | two captains; eligible teams | pending request only; no implicit consent |
| P14 | Player | Accept/reject challenge | two captains; venue/slot | both approvals and no conflict |
| P15 | Player | Team challenge code rotation | two captains; current code | rotates only on confirmed match; replay denied |
| P16 | Player | 1v1 championship registration | player; eligible event | one registration; no duplicate entry |
| P17 | Player | Championship progression/standings | organizer; scheduled matches | correct standings and winner after approval |
| P18 | Player | Pickup match participation | player; open match with capacity | capacity enforced and cancellation handled |
| V19 | Venue owner | Register and create venue | owner account; Aswan venue details | owner owns venue; public page accurate |
| V20 | Venue owner | Edit venue pricing/hours | owned venue; future booking | correct public availability; no past corruption |
| V21 | Venue owner | Manage booking accept/reject | owner; booking requests | correct status and player notification |
| V22 | Venue owner | Free vs paid entitlements | owner free plan; staging subscription | no unauthorized paid features; no booking commission |
| A23 | System admin | Moderation and role restrictions | admin; player; owner | admin-only actions denied to non-admins |
| W24 | Website/admin | Web auth and public venue page | web session; venue published | no dashboard redirect loop; role-scoped data |

## Mandatory assertions for **each** of the 24 journeys

1. **Success path:** verify UI, API and persisted state agree after relaunch/relogin.
2. **Failure path:** invalid input, denied permission, cancelled flow and expired session have safe localized feedback.
3. **Authorization:** repeat with another user/owner; cross-account reads/writes must be denied by server-side policies, not merely hidden UI.
4. **Network:** disconnect before and during mutation; retry must not create duplicates, leave spinners stuck or misrepresent payment state.
5. **Idempotency and concurrency:** replay request IDs and send simultaneous requests for booking, payment, invitation, team challenge and enrollment.
6. **Database impact:** capture redacted before/after snapshots; validate no leaked user details, duplicate bookings, double charges or orphaned rows.
7. **Regression:** re-run affected prior journeys and check both Arabic RTL and English LTR, small Android viewport and text scaling.
8. **Evidence:** record build SHA, Android device/API, staging environment, test account alias, UTC time, sanitized screenshots/logs, test result and issue reference.

## Run order and release gate

- Gate 0: confirm staging-only endpoints, isolated test accounts, no production payment keys and fixture reset.
- Gate 1: P01–P09 (identity, venues, bookings and payment), then V19–V22 (owner lifecycle and subscriptions).
- Gate 2: P10–P18 (teams, challenges, 1v1 and tournaments), then A23 and W24.
- Any security bypass, double charge, double booking or unconsented match confirmation is **P0** and blocks release.
- A test is complete only when the success path, failure path, authorization, network, repeat/replay, DB impact and regression evidence are attached. This matrix does **not** claim 56.03–56.08 complete.
