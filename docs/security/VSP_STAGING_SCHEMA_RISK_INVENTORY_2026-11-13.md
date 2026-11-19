# VSP staging — schema, refund and auth inventory

Date: 2026-11-13 (UTC). **Read-only inspection of `vsp-staging` project `vtwgqyxglevcsxwdmhop`**, not production. Source: Supabase SQL metadata catalog (`pg_class`, `pg_attribute`, `pg_constraint`, `information_schema.columns`, `has_table_privilege`) and Supabase Security Advisor. No customer/identity rows, function bodies, passwords, payment details, or secrets were retrieved.

## 65.01 and 65.03 — Three distinct refund queues; schema comparison

| Public table | Observed rows in staging | Key columns | FK relationships | Constraints |
|---|---:|---|---|---|
| `cancellation_refund_queue` | 0 | `id` uuid, `championship_id`, `order_id`, `registration_id`, `paymob_transaction_id`, `amount`, `status`, `retry_count`, `locked_until`, `processing_started_at`, `processed_at`, `failure_reason` | championship, tournament order, registration | `amount > 0`; `status` in pending/processing/completed/failed_manual_review; unique `order_id` |
| `team_league_cancellation_refund_queue` | 0 | `id` uuid, `championship_id`, `payment_id`, `paymob_transaction_id`, `amount`, `status`, `retry_count`, `locked_until`, `processing_started_at`, `processed_at`, `failure_reason`, `error_message` | championship, team league payment, user | PK and FK constraints; no status CHECK returned by `pg_constraint` |
| `vsp_1v1_cancellation_refund_queue` | 0 | `id` uuid, `tournament_id`, `order_id`, `paymob_transaction_id`, `amount`, `status`, `retry_count`, `locked_until`, `processing_started_at`, `processed_at`, `failure_reason` | 1v1 tournament, 1v1 order, user | PK, FK and same four-value status CHECK |

The queues are **not interchangeable**: they refer to different event/payment entities and have different FK deletion behavior and checks. The column/constraint comparison completes inventory **65.01** and schema comparison **65.03**; it does **not** establish which queue receives live events, whether idempotency is correct, or whether consolidation is safe. Keep 65.02, 65.04–65.08 open.

## 66.01 — Stadium versus court operating-hour schema

- `public.stadiums` is a base table (17 staging rows), with `opening_time`, `closing_time`, `break_start_time`, `break_end_time` (time without timezone) and `features` jsonb.
- `public.courts` is a **view**, not a separate base table; it exposes the same basic time and `features` fields.
- `public.court_operating_hours` is a base table (0 staging rows) with `court_id` uuid, `day_of_week` 0–6, `open_time`, `close_time`, `is_closed`, and a FK `court_id → stadiums(id)` with ON DELETE CASCADE.
- No `public.stadium_operating_hours` relation was returned in the inspected catalog.

These sources may disagree. Source precedence in Flutter/RPC and runtime closure/booking enforcement remain **unverified**; tasks 66.02–66.07 stay open.

## 68.01 — Legacy cash-debt columns (schema inventory)

- `public.users`: `accumulated_cash_debt` numeric, `cash_booking_banned` boolean, `debt_limit` numeric, `is_debt_blocked` boolean.
- `public.platform_business_rules`: `default_cash_debt_limit` numeric.
- `public.v_financial_reconciliation`: `accumulated_cash_debt`, `debt_limit`, `is_debt_blocked`.

These are **existing fields**, not evidence that the current booking workflow uses them. No financial amounts or user rows read. Remaining 68.02–68.07 require consumer analysis, data review and retention decision.

## 70.01 — challenge_results identifier inventory

`public.challenge_results` has `id` uuid **PRIMARY KEY** and `challenge_id` text without a declared foreign key in the inspected constraints; other fields: scores, submitted/confirmed-by text, status text, created/confirmed timestamps. **0 staging rows.** No duplicate challenge IDs were found, but zero rows cannot establish production cleanliness or validate migration. 70.02–70.07 remain open.

## 73.01 — Leaked-password protection status

Supabase **Security Advisor (staging)** currently reports one `auth_leaked_password_protection` warning. Official guidance: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

This completes the **current status inspection** only. Do not claim protection enabled or change Auth settings without a controlled staging plan. Tasks 73.02–73.06 remain open.

## 76.02 — View read privileges at staging

The four historically flagged public views are presently configured with `security_invoker=true`:

| View | `anon` SELECT privilege | `authenticated` SELECT privilege |
|---|---|---|
| `courts` | yes | yes |
| `owner_subscription_status` | no | yes |
| `public_subscription_plans` | yes | yes |
| `tournament_clean_sheets` | yes | yes |

Supabase Security Advisor produced **0** `security_definer_view` warnings in the same snapshot. These are effective table privileges and view configuration, **not proof** that underlying RLS and sensitive data are safely isolated. Tasks 76.03–76.07 (role-level positive/negative tests and final security validation) remain open.

## Linked RLS and privileged function audits

- [Current 44 initplan / 50 multiple-permissive warnings and per-table classification](VSP_STAGING_RLS_ADVISOR_INVENTORY_2026-11-13.md).
- [Exact inventory of 200 `authenticated`-executable SECURITY DEFINER RPC signatures](VSP_STAGING_PRIVILEGED_RPC_INVENTORY_2026-11-13.md). There are 308 `public` SECURITY DEFINER routines in total, 200 executable by `authenticated` and **0** of those 200 executable by `anon` at this snapshot.
- Both numbers may change with migrations and permissions. Warnings are review signals, not evidence of actual vulnerabilities or authorization bypass.

**Acceptance scope:** metadata inventory and classification only (65.01, 65.03, 66.01, 68.01, 70.01, 73.01, 74.01, 74.02, 75.01, 75.02, 76.02, 77.01). Do not consider server-side authorization verified, try to bulk revoke functions, alter staging data, or merge `main`.
