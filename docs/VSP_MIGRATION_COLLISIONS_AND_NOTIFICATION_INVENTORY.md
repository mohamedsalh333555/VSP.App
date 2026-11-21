# Migration collisions, matchup extra-team fee and notification aliases — source inventory

Checked-in source review only. No live database inspection, migrations applied or production changes.

## 71.01 — Duplicate migration version inventory

Multiple distinct SQL files share identical numeric migration prefixes, which can cause migration ordering, version collision or partial deployment issues depending on the migration runner. Confirmed examples:

| Numeric prefix | Colliding SQL files |
|---|---|
| `20260925292000` | `harden_legacy_tournament_refund.sql`; `protect_booking_core_fields.sql` |
| `20260925293000` | `harden_cash_confirmation_atomic.sql`; `harden_owner_manual_booking_update.sql` |
| `20260925296000` | `restore_admin_payout_rpc_execute.sql`; `secure_financial_record_reads.sql` |
| `20260926040000` | `financial_ledger_cash_completion_coherence.sql`; `harden_tournament_orders_rls.sql` |
| `20260926060000` | `fix_matchup_extra_team_fee_column_reference.sql`; `lock_direct_financial_mutations.sql`; `lock_legacy_challenge_results.sql`; `remove_legacy_matchup_extra_team_fee.sql` |
| `20260926170000` | `official_user_lifecycle_write_paths.sql`; `tournament_registration_payment_gate.sql` |
| `20261001110000` | `booking_journey_batch2_historical_gross_refund.sql`; `phase0_phase1_ssot_reconciliation_and_security.sql` |

Earlier day-only migration prefixes (`20260823`, `20260824`, etc.) are also reused extensively. Rollback companions (`.rollback.sql`) are separate artifacts, not necessarily duplicate forward migrations. **71.01 complete as inventory**; content diff, applied migration history, staging order and replay safety are not verified (71.02–71.07). Never rename already-applied migration versions without an explicit reconciliation plan.

## 72.01 — Matchup extra-team fee migration inventory

Two distinct checked-in SQL files share the same numeric version `20260926060000` and both replace `public.add_team_to_matchup_by_code(uuid,text)`:
- `supabase/migrations/20260926060000_fix_matchup_extra_team_fee_column_reference.sql`: permits adding a sixth team after a paid `transactions.type='matchup_extra_teams_fee'` fee; error mentions **25 EGP**.
- `supabase/migrations/20260926060000_remove_legacy_matchup_extra_team_fee.sql`: explicitly removes the sixth-team fee and enforces **at most five teams**, with `MATCHUP_TEAM_LIMIT_REACHED` for the sixth.

These definitions are mutually incompatible. Which function is live depends on actual migration execution; file naming or alphabetical order is **not** proof of production state. Product direction in the latter source is five teams with **no extra-team fee**. **72.01 complete as inventory**; dependency sequencing, deployment state and reconciliation remain 72.02–72.07. Do not collect the legacy fee or apply either migration without owner-approved payment/schema changes.

## 67.01 — Notification body/message alias inventory

`lib/data/models/notification_models.dart` defines `AppNotification.body`, serializes the canonical `body` field, and now reads legacy `message` when `body` is absent or blank (commit `7c06e0a`). `test/data/models/notification_models_legacy_test.dart` covers the fallback, preference for `body` and whitespace-only `body`. This is **client display compatibility**, not a claim that the database schema has been migrated. **67.01 complete as client field inventory**; 67.02–67.07 remain open until other consumers, legacy templates and actual stored records are checked.

## Risks / acceptance boundary

This inventory does not authorize renaming migrations, dropping columns, changing production fees or modifying notification RLS. Source-only evidence cannot establish applied migration order or the exact deployed RPC definition.
