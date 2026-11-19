# 27.02 — Booking status transition contract

Scope: permitted **logical** transitions for the seven Dart booking states in `lib/data/models/booking_enums.dart`. This is a contract for implementation and review, **not** a claim that server RPCs already enforce it.

## Canonical states

`upcoming` is an alias of `confirmed` and is normalized before evaluating transitions. `cancelled`, `expired`, `completed`, and `noShow` are terminal states.

| Current state | Allowed next state(s) | Rationale |
|---|---|---|
| pending | confirmed, cancelled, expired | Successful confirmation, cancellation, or lock timeout |
| confirmed / upcoming | completed, noShow, cancelled | Match finished, attendance recorded, or eligible cancellation |
| completed | none | Terminal result |
| noShow | none | Terminal attendance outcome |
| cancelled | none | Terminal cancellation |
| expired | none | Terminal timeout |

A request that repeats the *same canonical state* is an idempotent no-op, not a new transition. Any transition out of a terminal state is invalid. `pending -> completed` and `expired -> confirmed` are invalid.

## Non-status gates

The table describes only the state graph; it does **not** authorize callers. Each state change must separately enforce booking ownership/role, cancellation deadlines, payment source of truth, valid timestamps, concurrency/idempotency, and auditable history. Payment completion cannot be inferred from client-side state. `maintenance` booking types may require a separate policy and must not bypass server checks.

## Acceptance for 27.02

- All declared booking states appear in the table.
- `upcoming` normalization and same-state requests are defined.
- Terminal states and disallowed edges are explicit.
- Role/payment/time restrictions are explicitly separated from graph rules.

Task 27.03 (enforcement) remains open until all mutation paths, especially server-side entry points, use this contract.
