# Staging P0 Authorization & Security Remediation Verification Evidence

- **Target Environment:** `vsp-staging` (`vtwgqyxglevcsxwdmhop`, `eu-west-2`) — NEVER Production (`mktqkddbcddrxjxabdua`)
- **Timestamp (UTC):** 2026-11-28T06:49Z
- **Migration Applied:** `supabase/migrations/20261128090000_p0_security_definer_auth_hardening.sql`
- **Test Discipline:** Temporary QA auth users created via Supabase Admin API inside isolated run and permanently deleted in `finally`. SQL mutation tests wrapped in `BEGIN ... ROLLBACK`. Zero secrets, JWTs, or user PII stored.

---

## 1. Root Cause Confirmed & Closed Across Database

Previously, `import_paymob_reconciliation_row` (and 26 additional `SECURITY DEFINER` functions/triggers owned by `postgres`) checked `current_user NOT IN ('postgres', 'supabase_admin')`. Because inside a `SECURITY DEFINER` routine `current_user` always resolves to the function owner (`postgres`), that condition always evaluated false and bypassed caller role verification even when `authenticated` held `EXECUTE`.

**Fix Applied (`20261128090000_p0_security_definer_auth_hardening.sql`):**
1. Introduced `public.vsp_is_service_or_db_owner()` inspecting `auth.jwt()->>'role' = 'service_role'` or unproxied `session_user IN ('postgres', 'supabase_admin')` with empty `request.jwt.claims` and non-downgraded SQL `role`.
2. Hardened `import_paymob_reconciliation_row` via `PERFORM public.require_active_admin_actor();`.
3. Eliminated `current_user` across ALL remaining `SECURITY DEFINER` RPCs and triggers (`create_booking_atomic`, `create_challenge_booking_atomic`, `owner_create_manual_booking_atomic`, `request_owner_payout_settlement_atomic`, `get_owner_dashboard_analytics`, `get_owner_financial_summary`, `get_owner_ai_operational_insights`, `check_owner_stadium_limit`, `claim_paid_web_subscription_for_user`, `persist_copilot_turn`, `increment_banner_clicks`, `increment_banner_views`, `prevent_late_cancellation`, `protect_booking_payment_fields`, `protect_championship_sensitive_fields`, `protect_stadium_sensitive_fields`, `protect_team_sensitive_fields`, `vsp_guard_direct_booking_mutation`, and all internal `service_role` payment/refund/season RPCs).
4. Post-migration verification on Staging confirmed **0** executable `SECURITY DEFINER` logic branches still inspect `current_user` (the only 2 substring hits in `pg_proc` are a code comment in `confirm_tournament_order_atomic` and the function name `get_current_user_role`).
5. Fixed pre-login `public.get_server_timestamp()` (`SECURITY INVOKER`, `GRANT EXECUTE TO anon, authenticated, service_role`), converted 3 views (`admin_pending_refunds`, `admin_stadium_settlements`, `v_financial_reconciliation`) to `security_invoker = true`, and fixed argument order in `admin_cancel_booking_atomic`.

---

## 2. Live PostgREST HTTP Matrix Results (35 / 35 Passed, 0 Failed)

| Target RPC | Actor | Expected | HTTP Status | Observed Result | Pass |
|---|---|---|---|---|---|
| `import_paymob_reconciliation_row` | `anon` | REJECTED | `401` | `42501 permission denied` | YES |
| `import_paymob_reconciliation_row` | `authenticated_without_public_user` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `import_paymob_reconciliation_row` | `player` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `import_paymob_reconciliation_row` | `owner_non_admin` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `import_paymob_reconciliation_row` | `blocked_admin` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `import_paymob_reconciliation_row` | `active_admin` | AUTH_ALLOWED | `200` | `transaction_not_found` (reaches business check) | YES |
| `import_paymob_reconciliation_row` | `service_role` | AUTH_ALLOWED | `200` | `transaction_not_found` (reaches business check) | YES |
| `request_owner_payout_settlement_atomic(victim)` | `anon` | REJECTED | `401` | `42501 permission denied` | YES |
| `request_owner_payout_settlement_atomic(victim)` | `authenticated_without_public_user` | REJECTED | `200` | `{success:false, error:"Unauthorized payout request"}` | YES |
| `request_owner_payout_settlement_atomic(victim)` | `player` | REJECTED | `200` | `{success:false, error:"Unauthorized payout request"}` | YES |
| `request_owner_payout_settlement_atomic(victim)` | `owner_non_admin` | REJECTED | `200` | `{success:false, error:"Unauthorized payout request"}` | YES |
| `request_owner_payout_settlement_atomic(victim)` | `blocked_admin` | REJECTED | `200` | `{success:false, error:"Unauthorized payout request"}` | YES |
| `request_owner_payout_settlement_atomic(victim)` | `active_admin` | AUTH_ALLOWED | `200` | Auth passed (reached payout destination validation) | YES |
| `request_owner_payout_settlement_atomic(victim)` | `service_role` | AUTH_ALLOWED | `200` | Auth passed (reached payout destination validation) | YES |
| `get_owner_dashboard_analytics(victim)` | `anon` | REJECTED | `401` | `42501` | YES |
| `get_owner_dashboard_analytics(victim)` | `authenticated_without_public_user` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_dashboard_analytics(victim)` | `player` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_dashboard_analytics(victim)` | `owner_non_admin` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_dashboard_analytics(victim)` | `blocked_admin` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_dashboard_analytics(victim)` | `active_admin` | AUTH_ALLOWED | `200` | `analytics_ok` | YES |
| `get_owner_dashboard_analytics(victim)` | `service_role` | AUTH_ALLOWED | `200` | `analytics_ok` | YES |
| `get_owner_financial_summary(victim)` | `anon` | REJECTED | `401` | `42501` | YES |
| `get_owner_financial_summary(victim)` | `authenticated_without_public_user` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_financial_summary(victim)` | `player` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_financial_summary(victim)` | `owner_non_admin` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_financial_summary(victim)` | `blocked_admin` | REJECTED | `403` | `42501 ADMIN_ACCESS_REQUIRED` | YES |
| `get_owner_financial_summary(victim)` | `active_admin` | AUTH_ALLOWED | `200` | `summary_ok` | YES |
| `get_owner_financial_summary(victim)` | `service_role` | AUTH_ALLOWED | `200` | `summary_ok` | YES |
| `get_owner_financial_summary(self)` | `owner_self` | AUTH_ALLOWED | `200` | `success: true` | YES |
| `owner_create_manual_booking_atomic(victim)` | `anon` | REJECTED | `401` | `42501 permission denied` | YES |
| `owner_create_manual_booking_atomic(victim)` | `authenticated_without_public_user` | REJECTED | `200` | `{success:false, error:"UNAUTHORIZED"}` | YES |
| `owner_create_manual_booking_atomic(victim)` | `player` | REJECTED | `200` | `{success:false, error:"UNAUTHORIZED"}` | YES |
| `owner_create_manual_booking_atomic(victim)` | `owner_non_admin` | REJECTED | `200` | `{success:false, error:"UNAUTHORIZED"}` | YES |
| `owner_create_manual_booking_atomic(victim)` | `blocked_admin` | REJECTED | `200` | `{success:false, error:"UNAUTHORIZED"}` | YES |
| `get_server_timestamp` | `anon` | AUTH_ALLOWED | `200` | UTC timestamp returned cleanly | YES |

---

## 3. SQL Transaction Rollback Verification

- `sql_set_local_role_authenticated` (`SET LOCAL ROLE authenticated` inside `postgres` session): `REJECTED_AS_EXPECTED` (`ADMIN_ACCESS_REQUIRED`).
- `sql_positive_recon_matched` (synthetic completed transaction, `gateway_fee_collected = 3.00`, `p_actual_fee = 3.02`): `ALLOWED_AND_MATCHED` (`success = true`, `reconciliation_diff = -0.02`, `reconciliation_status = "matched"`, rolled back cleanly).

---

## 4. Additional Security Remediation Status

- **Private Storage (`lib/core/services/no_show_dispute_service.dart`):** Updated selfie upload path to `${currentUid}/disputes/selfie_${bookingId}_<ts>.jpg` inside private bucket `owner_documents` (matching `owner_documents_owner_manage` RLS folder rule) and removed `.getPublicUrl(...)`, storing the private object key instead. Verified no UI screen directly calls `NoShowDisputeService` beyond legacy `NotificationHandler` forwarding methods.
- **Website Hardcoded Prod URL (`vsp_website/src/app/pricing/PricingClient.tsx` & `server.ts`):** Verified `/pricing` redirects to `/` (`page.tsx`) because owner subscriptions are retired (`create_paymob_intention` returns `410`). Removed hardcoded `https://mktqkddbcddrxjxabdua.supabase.co/...` from `PricingClient.tsx` (now fails closed with retired notice unless explicitly opted in with env URL) and `server.ts` fallback.
- **Supabase Auth HIBP (Leaked Password Protection):** Documented as **BLOCKED — PLAN ENTITLEMENT REQUIRED** (`entitlement_required` on current free/non-Pro tier). Not upgraded/purchased without explicit owner authorization.
