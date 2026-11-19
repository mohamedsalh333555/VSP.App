# 69.01 / 70.01 — Legacy 1v1 and challenge-result table inventory

**Evidence is limited to checked-in migrations and application source, not live database contents.** Neither migration nor permission change is applied here.

## 69.01 — 1v1 participant records

The checked-in table is `public.vsp_1v1_tournament_players` (not an independently verified table literally named `1v1_players`). Evidence:
- `supabase/migrations/20260906_harden_1v1_players_rls_paid_only.sql` drops permissive SELECT policies and creates a read policy on `vsp_1v1_tournament_players` that allows paid rows, service role or privileged admin/co-founder reads.
- `supabase/migrations/20260906_add_1v1_atomic_functions.sql` checks participant registrations and payment status.
- `supabase/migrations/20261001270000_player_and_1v1_journey_ssot.sql` and `20261001280000_finalize_player_and_1v1_ssot.sql` query registrations by `tournament_id`, `user_id` and `payment_status='paid'`, including idempotency checks.

**Identity key to investigate:** `(tournament_id, user_id)` for paid registration. It is a logical lookup, **not proof of a unique database constraint**. Historical unpaid attempts and paid records must not be collapsed without transaction reconciliation. 69.02–69.07 remain open.

## 70.01 — Legacy challenge-result records

`supabase/migrations/20260926060000_lock_legacy_challenge_results.sql` references `public.challenge_results`, revokes all table access for `anon` and `authenticated`, enables RLS, and drops old insert/update/select policies. This is explicit evidence of a **locked legacy result table**, not proof of its current deployed row count or identifier type.

Current challenge scoring in `supabase/migrations/20261003193000_challenge_mutual_result_agreement_and_points.sql` uses booking fields `match_result_status`, `final_outcome` and `elo_processed` to update teams, rather than trusting a client edit of the legacy table. `bookings.id` is the challenge booking identifier; do not equate it to a `challenge_results` row ID without checking table DDL and foreign keys.

**IDs and duplicates:** the legacy result table is named and its access policy identified; its actual primary key, foreign-key relationships, duplicated IDs, orphan records and original result links are **unverified**. Tasks 70.02–70.07 remain open.

## Safety boundary

Do not delete legacy tables, change RLS, merge result rows, or rewrite paid 1v1 participants until live table definitions, referencing foreign keys, deployed migrations and financial dependencies are verified.
