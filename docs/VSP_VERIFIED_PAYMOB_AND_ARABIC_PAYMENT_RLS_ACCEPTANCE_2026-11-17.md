# VSP — Verified Paymob notifications, payment-source truth and client-safe notification edits

**Acceptance date:** 17 November 2026, Africa/Cairo. **Scope:** `uxlp-44-implementation`, isolated PostgreSQL, source-level Paymob webhook and financial Flutter regression tests; Staging database project `vtwgqyxglevcsxwdmhop` only. Original unique tracker total remains **630**, previously **254 accepted / 376 open**.

## Real source migrations applied to Staging

| Source migration | Staging migration version | What is verified |
| --- | --- | --- |
| `20261117070000_paymob_verified_booking_payment_notification.sql` | `20261117041136` | In-app receipt requires a matching completed booking ledger transaction, signed successful Paymob log, same booking/order/transaction/gross amount; one receipt per recipient and ledger transaction |
| `20261117071000_notifications_reserved_financial_events_rls.sql` | `20261117042825` | Restrictive INSERT RLS blocks normal clients forging payment, refund and official Team Skills events while preserving ordinary messages |
| `20261117072000_normalize_arabic_payment_methods_and_block_unpaid_wallet.sql` | `20261117043325` | Canonical server-side Arabic and English venue cash, wallets, cards, InstaPay/bank transfer; refuse confirmed unpaid electronic payments, including payment-method-only edits |
| `20261117073000_notifications_client_edit_read_flag_only.sql` | `20261117043328` | An authenticated user may mark their own notice read/unread but cannot change recipient, title, message, type, booking link, metadata or timestamp |

Read-only Staging post-apply checks confirmed all four migration records; `trigger_sync_payment_reconcile` and `trg_guard_client_notification_edits` are enabled. The SQL catalog contains Arabic-wallet classification and a digital-payment confirmation guard. The new private notification-edit trigger function is not directly executable by `authenticated`. **24 existing bookings and 6 existing notifications remained unchanged in count**; no backfill or commercial fee change.

## Actual tests and provenance

- **[Latest isolated SQL contract CI — success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44018523821)**: `scripts/test_paymob_verified_payment_notification_isolated.py`, `scripts/test_paymob_transaction_booking_binding_isolated.py`, `scripts/test_notifications_reserved_events_rls_isolated.py`, `scripts/test_booking_arabic_payment_reconcile_isolated.py`, `scripts/test_notifications_read_flag_only_isolated.py`. Tests source-inject the actual migration/function into newly created local PostgreSQL databases, refuse remote DB targets, and verify positive and denied paths.
- **[Focused Flutter financial/Paymob CI — success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44018518263)**: `test/core/utils/owner_financial_calculator_test.dart`, `test/unit/financial_calculator_test.dart`, `test/architecture/paymob_verified_notification_contract_test.dart`, `test/architecture/paymob_refund_accounting_notification_guard_test.dart`. This is now an automatic dedicated workflow `.github/workflows/financial-payment-regressions.yml`.
- Actual Staging `public.record_booking_payment_atomic` server function was captured read-only at `docs/security/sql/record_booking_payment_atomic_staging_source_2026-11-17.sql` and tested in isolated PostgreSQL against replay, cross-booking transaction reuse, wrong user, and mismatched gross amount. The Staging `transactions` table additionally has a **unique partial index** on non-empty Paymob transaction IDs, blocking simultaneous duplicate inserts.
- Source `supabase/functions/paymob_webhook/index.ts` no longer sends booking payment-success notices by a direct post-RPC `notifications.insert`. It now delegates this to the verified database event and handles an idempotent response. Refund response `id` by itself is no longer treated as refund success, and the auto-refund branch does not claim a refund completed if the authoritative server accounting refuses it.
- The security advisor still reports existing warnings (four extensions in public, 224 callable security-definer functions, one leaked-password-protection warning). Those are **not** cleared and this acceptance does not imply a full-security pass.

## Eight original task IDs accepted — bounded scope

| Original task | Acceptance evidence and explicit limit |
| --- | --- |
| **45.04** — Payment notification | Verified transaction-specific **in-app SQL** booking receipt after a successful signed Paymob event and completed ledger row, correct amount/order/owner/booker; no push delivery or live Paymob settlement proven |
| **45.07** — No fake payment notification before server confirmation | Negative SQL cases for no webhook, false HMAC, wrong booking/order, bad amount, failed callback and forged client INSERT/UPDATE; no false paid/refund-success event |
| **62.07** — Legacy inconsistent payment-state behavior | Real server payment matrix and Flutter-domain tests reject confirmed unpaid electronic wallet and legacy contradictory source while retaining valid cash confirmation and refund-pending precedence; not an exhaustive historical production-data cleanup |
| **63.05** — Payment transaction linkage test | Isolated real Staging ledger RPC proves initial booking/transaction record plus replay idempotency; signed receipt must match ledger booking, payment order and gross amount |
| **63.07** — Reject transaction ID linked to another booking | Staging ledger function explicitly denies transaction ID reuse across bookings, including wrong user/gross cases; authoritative unique Paymob transaction index separately exists |
| **64.02** — Normalize method values | New Staging booking trigger canonicalizes Arabic/English venue cash vs Vodafone Cash, InstaPay, Paymob cards/wallets and bank transfer without changing existing rows; Flutter fallback matches these values |
| **64.04** — Test payment-method conversion | Real-source isolated PostgreSQL matrix tests 14 synthetic records including wallet, Arabic venue cash, card, method-only swap, partially paid and refund pending |
| **64.07** — Test reporting cash vs digital | Dedicated Flutter CI verifies venue cash stays cash, Vodafone Cash/Meeza/card stay digital, bank transfer distinct, unknown/contradictory legacy source not counted as cash; pure owner finance aggregates tested with 5 synthetic bookings |

## Strict release boundaries

- **No signed real Paymob checkout, payout or refund was run**; no Paymob provider secrets, cards or money were used in these isolated tests. Staging has **zero Paymob transaction ledger rows and zero Paymob webhook log rows** during this audit; it also lacks a deployed `paymob_webhook` Edge Function in the last Staging function listing, so this report does not claim live end-to-end Paymob success.
- **No FCM push, SMS/email delivery, signed APK, installed-device payment scenario, multi-user JWT E2E, production deployment or app-store approval** is certified by this batch.
- Existing venue-owner revenue remains subscription-based; no per-booking commission was introduced, and payment fee configuration was not rewritten. Legacy fee-policy code is a separate audit item.
- The user-facing checkout and operational cancellation flows outside the verified SQL/Flutter boundary still need complete QA. Other task IDs remain open; no retired group 56 tasks were counted.
- **No merge to `main` and no production database change.**

**Accounting delta: +8 unique bounded accepted IDs. 254/376 → 262 accepted / 368 open from 630 total (41.59%).**
