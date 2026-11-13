# VSP — source tracing, financial legacy fields, Paymob indexes and refund-worker readiness

Date: 2026-11-13 UTC. Sources: checked-in `uxlp-44-implementation` files and **read-only** metadata/aggregate SELECTs against `vsp-staging` (`vtwgqyxglevcsxwdmhop`). No customer/booking/payment row details, private credentials or secrets were returned; no functions invoked except metadata inspection; no writes or migrations applied.

## 61.02–61.03 — Team championship champion/winner sources

- `public.crown_tournament_champion_atomic(uuid,uuid,text)` updates `championships.status='completed'`, `champion_team_id` and `champion_team_name`. It does **not** set `winner_team_id`.
- `public.get_team_active_league` emits `champion_team_id/name`, `mark_championship_prize_delivered_atomic` uses these for prize handover metadata and `transition_championship_status_atomic` requires `champion_team_id` before completion.
- `lib/data/models/tournament_models.dart` parses and serializes `champion_team_id/name` as `championTeamId/Name`. The presentation banner takes a resolved `championName`. `protect_championship_sensitive_fields` guards mutations of **both** `champion_team_id` and `winner_team_id`.
- **Canonical decision for new team championships:** use already-established `champion_team_id/name`; retain `winner_team_id/name` unmodified for compatibility pending production-data reconciliation. This does not merge historical fields or claim all consumers have been migrated.
- Staging: 2 championships; 0 non-null `champion_team_id`, 0 non-null `winner_team_id`, 0 conflicting IDs. Empty winner sample means neither historical correctness nor migration feasibility is established.

## 62.03 — Payment state disagreements: staging sample only

- Read `public.bookings` aggregate counts, not individual records: 24 rows; 0 `is_paid=true` with `payment_status` in unpaid/pending/failed and 0 `is_paid=false` with status paid/fully_paid. This is a **narrow conflict scan**, not a complete reconciliation and does not assert correctness of `payment_reconcile_state` or Paymob gateway settlement.
- Semantics and the three-field precedence remain as recorded in `docs/VSP_PAYMENT_STATE_SEMANTICS_62_02.md`. Do not coalesce or rewrite payment fields based on zero counts.

## 63.02–63.04 — Webhook call chain, canonical unique key, duplicates

- `supabase/functions/paymob_webhook/index.ts` verifies the Paymob payload then sends `p_paymob_transaction_id` to server RPCs. The booking branch calls `record_booking_payment_atomic` (see webhook near lines 890–913).
- Deployed `record_booking_payment_atomic` assigns both `bookings.paymob_txn_id` and `bookings.paymob_transaction_id` to the Paymob transaction ID, and stores a generic prefixed `payment_transaction_id`; `process_paymob_webhook` has legacy idempotency lookup by `paymob_txn_id`. Do not confuse order IDs and transaction IDs.
- On staging, `public.transactions` has partial unique index `ux_transactions_paymob_transaction_id` on nonblank `paymob_transaction_id`; `public.bookings.idx_bookings_paymob_txn_id` is **non-unique**. Thus uniqueness of transaction identifiers is enforced at the ledger index, not by the booking alias index. Whether each historical booking maps to a unique payment attempt remains untested.
- Aggregates: 0 mismatched populated aliases in bookings, 0 repeated nonblank booking `paymob_txn_id`, 0 repeated nonblank `transactions.paymob_transaction_id`. No transaction values, user identities or booking IDs displayed. These are staging-only counts; the staging sample may have few or no online payments.

## 65.02 — Refund producer, worker and cron trace (NOT ACCEPTED)

| Queue | Deployed producers/claim | Edge-worker consumer |
|---|---|---|
| `cancellation_refund_queue` | `cancel_championship_atomic`, `confirm_tournament_order_atomic`; `claim_next_cancellation_refund_atomic` | `process_tournament_refund/index.ts` processes the regular queue |
| `team_league_cancellation_refund_queue` | `cancel_team_league`; `claim_next_team_league_cancellation_refund_atomic` | Same worker explicitly processes league queue |
| `vsp_1v1_cancellation_refund_queue` | `cancel_1v1_tournament_with_refund_requests`, `leave_1v1_tournament_atomic`; `claim_next_1v1_cancellation_refund_atomic` | Same worker explicitly processes 1v1 queue |

- All 3 queues had **0 rows** in staging at previous audit; this shows code consumers, **not proven successful real refund execution**.
- Deployed `reconcile_cancellation_refund_queue()` scans only normal and 1v1 pending/expired-lease rows before posting to the Edge worker. **League-only pending refunds would not trigger this scheduled dispatcher.**
- Staging `cron.job`: job `vsp_job_10`, active, `*/10 * * * *` with reconciliation call. An aggregate check returned **0** records named `refund_worker` in `public.internal_function_secrets`, so the deployed function exits before attempting the HTTP call. **No secret value read.**
- The function's literal `v_url` is for the production Supabase project (`mktqkddbcddrxjxabdua`) rather than the staging project. This is a cross-environment endpoint **risk** if someone later sets the secret; it does not establish that any financial transfer occurred. **Do not add a secret or invoke the worker until the host isolation and release process are fixed.**
- 65.02 remains open because actual auto-processing cannot be verified. Do not consolidate queues, force retry, alter financial data or silently activate job.

## 68.02–68.03 — Legacy user-debt fields are NOT unused

- Deployed `delete_user_permanently` checks `accumulated_cash_debt` before deleting a user.
- `get_owner_financial_summary` and `get_owner_ai_operational_insights` read `accumulated_cash_debt`, `debt_limit` and `is_debt_blocked`; `join_1v1_tournament_atomic` and `confirm_1v1_payment_atomic` check `is_debt_blocked`.
- `apply_no_show_penalty`, `dismiss_no_show_penalty`, `dispute_no_show_with_gps` and `pay_rehabilitation_fine` modify `cash_booking_banned`; `trg_fn_protect_user_sensitive_fields` protects legacy financial/security fields.
- Staging aggregate counts: **117 users**, 0 positive `accumulated_cash_debt`, 0 `cash_booking_banned=true`, 0 `is_debt_blocked=true`, **117 nonzero `debt_limit`**. This is a data-presence review; records/amounts were not retrieved. Removing these fields would risk breaking live authorization/reporting even with zero positive staging debt.

## Security scope, blockers and acceptance

**Scoped VERIFIED:** 61.02, 61.03, 62.03, 63.02, 63.03, 63.04, 68.02, 68.03 = eight source/staging-only audit or canonical-decision subtasks. No migration, payment patch, refund delivery, production audit or live user exercise was validated. Related 61.04–61.07, 62.04–62.07, 63.05–63.07, 65.02–65.08 and 68.04–68.07 stay open.

For the urgent refund discovery, require a reviewed project-local URL resolver, environment-specific worker-secret provisioning procedure (without exposing values), full three-queue dispatcher predicate, dry-run/staging-only authorized worker tests, lease/idempotency checks and rollback. **Do not activate Staging cron against the production endpoint.** All work here is read-only.
