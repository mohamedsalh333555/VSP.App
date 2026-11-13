# VSP — compatibility and safety decisions for legacy finance / tournaments

Date: 2026-11-13. Sources: checked-in Flutter/Edge Functions/SQL and read-only staging catalog/aggregate evidence in:
- \`docs/VSP_LEGACY_FINANCIAL_FIELD_INVENTORY_61_64.md\`
- \`docs/VSP_PAYMENT_STATE_SEMANTICS_62_02.md\`
- \`docs/security/VSP_STAGING_FINANCIAL_AND_REFUND_AUDIT_2026-11-13.md\`
- \`docs/security/VSP_STAGING_SCHEMA_RISK_INVENTORY_2026-11-13.md\`
- \`docs/security/VSP_REFUND_DISPATCHER_BRANCH_FIX_2026-11-13.md\`

These are **11 acceptance decisions / compatibility plans**, not deployed financial migrations or resolved gateway bugs. No staging/production writes or customer financial details were retrieved.

## 61.06 — Canonical team winner compatibility documented

Team tournament winner SSOT for **new confirmed championships** remains \`championships.champion_team_id\` and \`champion_team_name\`, as written by \`crown_tournament_champion_atomic\` and consumed by \`get_team_active_league\`, \`transition_championship_status_atomic\` and Flutter \`tournament_models.dart\`. The legacy \`winner_team_id/name\` must be retained under the sensitive-field guard until an audited historical migration. Never equate the separate 1v1 individual winner with a team champion. Staging 2 team championships currently have neither winner ID set; this sample cannot establish migration safety. **61.04, 61.05, 61.07 remain open.**

## 62.04 and 62.06 — Booking payment reference and compatibility

\`bookings.payment_reconcile_state\` is the server-derived **display/state-machine reference** where populated; \`payment_status\` is the historical lifecycle signal with refund outcomes, and \`is_paid\` is a historical full-payment boolean that cannot represent partial/refund states. Flutter \`Booking.effectivePaymentState\` prioritizes nonempty server reconciliation state, falling back only for older rows. Gateway-confirmed transactions, Paymob webhooks and \`transactions\` ledger remain the **settlement evidence**, not a client-provided reconciliation flag. Preserve all three fields for historical read/write compatibility. Do not bulk overwrite financial values. Any data migration must first classify conflicts, replay on staging fixtures, verify refunds and bank settlement independently. **62.03 is only a narrow staging conflict scan, not full reconciliation; 62.05 and 62.07 stay open.**

## 63.06 — Paymob identifier decision

\`transactions.paymob_transaction_id\` is the ledger's unique *nonblank* Paymob transaction identity (staging partial unique index \`ux_transactions_paymob_transaction_id\`). \`bookings.paymob_txn_id\` and \`bookings.paymob_transaction_id\` are retained compatibility aliases written together by deployed \`record_booking_payment_atomic\`; the booking alias index is nonunique. \`payment_transaction_id\` can hold a generic \`PAYMOB_\` prefix or a manual marker; \`paymob_order_id\` is an **order**, not a payment transaction. Never merge distinct attempts or use one Paymob ID across multiple bookings without a negative test of server ownership. Zero staging duplicates in the present aggregate sample do not prove production uniqueness. **63.05 and 63.07 remain open.**

## 64.03 and 64.06 — Instrument versus server payment source

\`payment_method\` captures the selected instrument/requested route; \`payment_source\` is server-inferred channel (e.g., \`cash\`, \`paymob\`, \`instapay\`, \`vodafone_cash\`, \`bank_transfer\`, \`unknown\`) under \`sync_payment_reconcile_state\`. Keep \`unknown\` separate from online-collected revenue; never infer gateway success from \`payment_method\` alone. The Flutter read-side fallback is compatibility-only and must not write privileged server financial columns. Cash-versus-online reporting needs dedicated fixtures to establish actual correctness. **64.02, 64.04, 64.05, 64.07 remain open.** This decision does not introduce a booking commission; venue monetization stays subscription-based.

## 65.04 — Canonical refund design selection

**Keep three distinct producer/queue tables as source-of-truth for their payment domains for now:**
1. \`cancellation_refund_queue\`: ordinary team championship orders and registrations.
2. \`team_league_cancellation_refund_queue\`: team league payments.
3. \`vsp_1v1_cancellation_refund_queue\`: 1v1 tournament orders.

They have different foreign keys, status constraints and historical payment sources. A single Edge worker may claim from all three using distinct claim RPCs, but the three tables must **not** be collapsed in place. The branch-only dispatcher patch covers all three, but it is not deployed; staging lacks a configured worker secret. Thus the selected design is a compatibility/architecture decision, **not proven refund liveness**. Keep **65.02, 65.06 and 65.08 open**.

## 65.05 — Lossless migration plan if a future unified refund ledger is approved

There is **no automatic merge authorized now**. If consolidation becomes necessary, use this staged, reversible protocol:

1. Freeze the field/schema mappings **without** changing workers: write a row-level crosswalk of \`source_queue_kind\`, \`source_queue_id\`, original payment order, owner, currency, principal, processing lease, retry count, Paymob transaction ID and refund status.
2. Create a **read-only union reporting view** first. Preserve the source kind and ID; avoid \`UNION\` deduplication and never sum the gross charge as refundable principal.
3. Before migration, snapshot per-queue counts, statuses, sum of principal, failed/manual reviews, null transaction IDs and all foreign-key references in a controlled staging test database. No direct production account data export.
4. Only in a later reviewed migration, insert into a shadow unified table with a **unique (\`source_queue_kind\`, \`source_queue_id\`) key** and an additional gateway-transaction/idempotency review. Keep original source rows immutable during dual-read; do not automatically send a second Paymob refund.
5. Validate one-to-one lineage, monetary subtotals, refunds/leases, actor isolation and late webhook replay. A duplicated Paymob transaction across distinct source kinds must pause for manual reconciliation, not auto-deduplicate.
6. Roll out read-side compatibility first, then worker claiming/settlement behind a monitored flag after dry runs. Keep a reversible switch to the original three-queue claims. Never delete old tables until production reconciliation and retention/legal signoff.
7. If any check fails, stop dispatch, preserve originals, revert the consumer flag and reconcile manual-review states. Do not replay a refund externally simply because a row was retried.

This is a plan deliverable, **not an executed data merge, reconciliation, migration or feature flag implementation**.

## 65.07 — Refund queue decision recorded

Record the decision: three separate queue schemas remain canonical; a single, controlled environment-local dispatcher is the integration layer. The existing hardcoded production endpoint in staging and missing worker credential are a **P1 HOLD** (Issue #39). The proposed patch is fail-closed; never add a worker credential in staging without ensuring the DB's true project reference, tenant/environment isolation, worker authorization and idempotency. Release remains blocked.

## 68.04 and 68.06 — Debt-field retention decision

Retain \`users.accumulated_cash_debt\`, \`users.cash_booking_banned\`, \`users.debt_limit\` and \`users.is_debt_blocked\` intact; they are **actively referenced** by deployed user-deletion, owner reporting, 1v1 eligibility, penalty and user-sensitive-field protection paths. Zero positive debt rows in staging do not make them unused: all 117 staging users have a nonzero configured \`debt_limit\`. Do not remove or rename any of these without an independent financial-authority redesign, consumer inventory, staging backfill and owner-approved production migration. **68.05 and 68.07 remain open.**

## Verification and acceptance boundary

**11 scoped source/decision items accepted:** 61.06, 62.04, 62.06, 63.06, 64.03, 64.06, 65.04, 65.05, 65.07, 68.04, 68.06. No gateway calls, live financial test, account mutations, production changes or \`main\` merge. All operational release blockers, staging role tests, real refunds and cleanup migrations remain open.
