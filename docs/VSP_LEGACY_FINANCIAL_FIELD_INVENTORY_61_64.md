# VSP — Legacy financial and championship field inventory (61.01–64.01)

**Scope:** checked-in source inventory only, not live database schema inspection. No schema migration, data update, financial reconciliation or field deprecation is authorized by this inventory.

## 61.01 — Championship winner field inventory

`supabase/migrations/20260926120000_championship_sensitive_fields.sql` references both `championships.champion_team_id` and `championships.winner_team_id` in its sensitive-field mutation guard. It also references `champion_user_id` (individual winner), `is_approved` and `paid_teams`, which are separate concepts. **Risk:** two team winner identifiers can disagree. Neither can be chosen as canonical merely from this guard. Next: trace all read/write paths and winner display queries (61.02), then select a canonical source (61.03); do not drop either column without a data migration and compatibility plan.

## 62.01 — Booking payment state field inventory

`public.bookings` has three payment-state representations explicitly used by `supabase/migrations/20261001230000_booking_payment_ssot_state_machine_and_matrix.sql`:
- `is_paid`: legacy boolean; cannot express partial payment or refunds.
- `payment_status`: string including `paid`, `fully_paid`, `partially_paid`, `refund_pending`, `refunded`, `refund_failed`.
- `payment_reconcile_state`: normalized state derived/preserved by `sync_payment_reconcile_state()`, including `unpaid`, `partially_paid`, `fully_paid` and refund states.

Related but distinct: `bookings.status` (slot lifecycle), `deposit_paid` and `total_price` (amounts), `payment_source` (channel). The SQL trigger enforces a booking/payment matrix and derives payment source; Flutter `lib/data/models/booking_mapper.dart` currently reads `payment_status`, `is_paid` and `payment_reconcile_state` separately. **Risk:** stale booleans or partial payments misrepresented as paid. Next: define conflict precedence and reconcile live records (62.02–62.07).

## 63.01 — Paymob transaction identifier inventory

`supabase/migrations/20261001100000_booking_journey_batch1_ssot_and_challenge_codes.sql` explicitly guards mutations of `bookings.payment_transaction_id`, `bookings.paymob_txn_id`, `bookings.paymob_order_id` and `bookings.paymob_transaction_id`. They are **not** interchangeable: a Paymob order is not a transaction, and a generic payment transaction reference may be a manual marker. `supabase/functions/paymob_webhook/index.ts` passes Paymob transaction IDs to payment confirmation RPCs; `lib/data/models/booking_mapper.dart` maps generic `payment_transaction_id` to the Booking model. **Risk:** different aliases can refer to different attempts; choosing a unique canonical ID requires checking webhook writes and live uniqueness constraints (63.02–63.07). No alias was silently unified.

## 64.01 — Payment method/source inventory

`supabase/migrations/20261001230000_booking_payment_ssot_state_machine_and_matrix.sql` contains `bookings.payment_method` (user/payment instrument) and `bookings.payment_source` (server-inferred channel). `sync_payment_reconcile_state()` maps:
- `cash` or a generic transaction ID beginning `MANUAL` → `cash`;
- `paymob`, `card`, `online`, `wallet`, `visa`, `mastercard`, `meeza` → `paymob`;
- `instapay` → `instapay`;
- `vodafone_cash` → `vodafone_cash`;
- `bank_transfer` → `bank_transfer`;
- anything else → `unknown`.

`lib/data/models/booking_mapper.dart` reads `payment_method` and `payment_source`, with a client-side inference fallback. **Risk:** the UI must not override a trusted server source, and legacy values must not be counted as electronic revenue without reconciliation. Follow-up 64.02–64.07 will validate normalization, queries and cash-vs-online reporting.

## Evidence boundaries

All four **inventory** deliverables are complete as source analysis. The rest of items 61–64 remain open. Live deployed schema, actual field counts, conflicting historical rows, webhook transaction uniqueness, and migration order were not verified. No production changes made.
