# VSP — Master System Reconciliation & Production Readiness Audit

- **Date:** 2026-11-28
- **Target Audit Environment:** `vsp-staging` (`vtwgqyxglevcsxwdmhop`, `eu-west-2`)
- **Production Environment:** `mktqkddbcddrxjxabdua` (`eu-west-1`) — strictly UNTOUCHED (`READ-ONLY`)
- **Active Review Branches (Never Merged to `main`):**
  - `VSP.App`: `feat/vsp-recovery-gamification-ds` (PR #47)
  - `vsp_website`: `feat/unify-commission-paymob-fees` (PR #5)
  - `vsp-admin-panel`: `feat/unify-commission-paymob-fees` (PR #11)

---

## 1. Financial Commission & Paymob Reconciliation Alignment

| Layer | Verified State | Evidence / Notes |
|---|---|---|
| **DB Commission SSOT (`platform_fee_config id=1`)** | `DONE` on Staging | `player_vsp_rate = 0.0500` (5%), `owner_vsp_rate = 0.0500` (5%), `booking_paymob_local_rate = 0.0240`, `booking_paymob_wallet_rate = 0.0240`, `booking_paymob_foreign_rate = 0.0260`, `booking_paymob_fixed_fee = 3.00`, `fee_version = v2026_11_paymob_24_26`, `gateway_fee_mode = gross_up`. |
| **Atomic Pricing & Ledger RPCs** | `DONE` on Staging | `calculate_booking_pricing_v2`, `record_booking_payment_atomic`, `import_paymob_reconciliation_row`, `get_owner_financial_summary`, `request_owner_payout_settlement_atomic` verified and P0-hardened in `20261128090000_p0_security_definer_auth_hardening.sql`. |
| **Admin Payout & Reconciliation UI (`PayoutSettlementsPage.jsx`)** | `DONE` & Built | Includes Player Fee (5%), Owner Fee (5%), Owner Net, Paymob Gateway Collected, Actual Fee / Diff, and `reconciliation_status` (`matched` / mismatch / `pending_reconciliation`). |
| **Retired Subscriptions Alignment** | `DONE` | `create_paymob_intention` returns HTTP `410` (`Owner subscriptions have been retired`), `/pricing` redirects to `/`, and `PricingClient.tsx` no longer points to Production. |

---

## 2. Edge Functions Deployment Parity Gap (Honest Finding)

Inspecting `supabase/functions/` in repo vs `npx supabase functions list --project-ref vtwgqyxglevcsxwdmhop` on Staging reveals:
- **Present in Repo (`VSP.App/supabase/functions/`):** `create_paymob_intention`, `paymob_webhook`, `process_paymob_refund`, `process_tournament_refund`, `fcm_push`, `fcm_queue_worker`.
- **Currently Deployed on `vsp-staging` (`vtwgqyxglevcsxwdmhop`):** ONLY `create_owner_web_checkout`, `get_owner_web_checkout_status`, `process_tournament_refund`.
- **Status (`PARTIAL` / `DEPLOYMENT_GAP`):** `create_paymob_intention`, `paymob_webhook`, `process_paymob_refund`, `fcm_push`, and `fcm_queue_worker` exist cleanly in PR #47 source code but are NOT yet deployed onto `vsp-staging` (`vtwgqyxglevcsxwdmhop`), and `create_owner_web_checkout` on Staging is a legacy deployed artifact. Live Paymob webhook/intention/refund Edge Function execution on Staging cannot be claimed verified until those Edge Functions + Staging secrets (`PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, etc.) are deployed.

---

## 3. Gamification & Competitive Season Readiness (`vsp-staging`)

- **Database State Verified:** `competition_seasons` (`active_seasons = 1`), `team_xp_ledger` (`98` entries), `immortal_reward_entitlements` (`4` records), `competitive_reward_periods` (`0` rows), `season_reward_entitlements` (`0` rows).
- **Operational Note:** Because `competitive_reward_periods` is currently empty on Staging (`0` rows), admin period reward generation UI can render empty states, while schema, `admin_generate_period_snapshot_and_entitlements`, `admin_approve_cash_reward_atomic`, and `admin_mark_cash_reward_paid_atomic` are verified present and P0-hardened.

---

## 4. `supabase db lint --linked` Known Legacy Findings

Running `supabase db lint --linked --level warning` surfaced remaining pre-existing SQL lint issues in legacy/auxiliary functions outside P0 financial auth (e.g. `owner_record_no_show_atomic` referencing non-existent `fair_play_score` column, `leave_championship_atomic` / `transfer_team_captaincy_atomic` `uuid[]` vs `text[]` coalesce, `link_league_match_booking` discarded query). `admin_cancel_booking_atomic` argument-order bug was fixed in `20261128090000_p0_security_definer_auth_hardening.sql`.
