# VSP Phase 8 — signed Paymob lifecycle, refund replay and checkout correlation

**Date:** 17 November 2026 (Africa/Cairo)  
**Scope:** development branch `uxlp-44-implementation`, source-controlled TypeScript/Deno/Flutter contracts, read-only Supabase catalog review. No Paymob charge/refund, Staging/production write, secrets inspection, deployment or `main` merge.

## Confirmed source-code behaviors and bounded fixes

| Source behavior before change | Status and remediation | Relevant evidence |
| --- | --- | --- |
| A signed Paymob callback with `pending=true` yielded `isSuccess=false` and could take the booking failure branch, cancelling a pending booking while payment was still unresolved | **Fixed in branch / tests pass; NOT DEPLOYED.** `classifyPaymobWebhookOutcome` preserves pending, and the failure UPDATE only runs for a terminal `failed` outcome | `supabase/functions/paymob_webhook/index.ts`, `_shared/paymob_webhook_outcome.ts`; [lifecycle commit](https://github.com/mohamedsalh333555/VSP.App/commit/c48e2ec53c438720b57016c6cdcc25b3aae5142c) |
| A signed `success=true,pending=false` callback also qualified as success when `is_refunded`, `is_voided`, authorization-only, or error flags showed an unsettled/reversed transaction; currency was not checked against EGP | **Fixed in branch / tests pass; NOT DEPLOYED.** Reversed/ambiguous events never credit payment. EGP is validated only **after HMAC**. Signed booking refund callbacks still enter their separate server accounting path; reversed tournaments require further reconciliation review | Same lifecycle commit |
| Duplicate signed booking refund events could return `already_recorded=true` from `record_booking_gateway_refund_atomic`, yet the handler still sent another success notification | **Fixed in branch / tests pass; NOT DEPLOYED.** Return `already_processed` before notification for previously recorded refund events; server's existing refund ledger remains authoritative | Same lifecycle commit; [refund notice regression test](https://github.com/mohamedsalh333555/VSP.App/commit/33a778dbffd11b9a95a442a3187284ff45f10f45) |
| Paymob Intention API could respond with a client checkout secret even when the subsequent PostgREST `UPDATE` matched **zero** rows (PostgREST treats zero matches as non-error), leaving the provider order ID unbound from the intended server order | **Fixed in branch / tests pass; NOT DEPLOYED.** All five sources (booking, subscription, 1v1, team tournament, league) now `UPDATE...select(id, paymob_order_id).maybeSingle()` and require a matching persisted row. Unknown order types and stale/changed states fail closed **before returning client_secret** | `supabase/functions/create_paymob_intention/index.ts`, `_shared/paymob_order_binding.ts`; [binding fix](https://github.com/mohamedsalh333555/VSP.App/commit/b2c42d4e96c0bebda2770cbb0c2519860f14e636) |

The above are **confirmed local source behaviors**, not demonstrated exploitation, data exposure or active provider breach. No new billing model or commission was added.

## Tests and actual results

- [Financial Paymob regression run **44103800758 — SUCCESS**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44103800758) on code SHA `b2c42d4e96c0bebda2770cbb0c2519860f14e636`: synthetic 20-field HMAC and altered signature, fixed-time comparator, event flags and outcome matrix, reject malformed/voided/refunded/pending and ambiguous callback outcomes, refund-notification replay guard and five checkout-order binding paths. Both Deno and focused Flutter financial jobs passed.
- [Isolated PostgreSQL security run **44103816555 — SUCCESS**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44103816555), [owner-checkout security run **44103816707 — SUCCESS**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44103816707), [task-accounting run **44103816614 — SUCCESS**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44103816614), same source SHA.
- [Earlier failing Paymob run **44102503781**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44102503781) was due to stale literal-code source assertions after the new outcome branch. The assertions were updated and the subsequent finance CI passed. This old run is **not** reported as a runtime security exploit.
- No actual server-to-server Paymob Sandbox event, verified transaction settlement, external refund, multi-account JWT test, hosted-Storage authorization exercise, production smoke or provider currency/integration certification was run. Do not turn these focused CI results into a production-ready claim.

## Read-only infrastructure cross-check

- `public.webhook_logs` has no check constraints or non-internal triggers in the two queried catalogs restricting the new `pending`/`reversed`/`unresolved` status values; existing verified-success log status remains `success` for downstream receipts. This does **not** prove all external consumers tolerate the new values.
- Both Staging and production currently expose `id` and `paymob_order_id` columns in `bookings`, `owner_subscription_orders`, `vsp_1v1_tournament_orders`, `team_league_payments`, and `tournament_orders`. No customer/order rows were read or altered.
- The old `public.process_paymob_webhook` privileged SQL function was read as metadata in both environments: `SECURITY DEFINER` but **neither `anon` nor `authenticated` has EXECUTE** and it includes a separate caller-role check. It is **not evidenced as a directly callable unprivileged HMAC bypass**; other privileged functions remain under [issue #38](https://github.com/mohamedsalh333555/VSP.App/issues/38).
- Production `paymob_webhook` v45 predates this branch patch and Staging has no deployed `paymob_webhook` per the last Edge Function inventory. This is **code-level validation only**.

## Still open / release gates

1. Actual Paymob HMAC + callback integration, provider `integration_id` allow-list config, external signed replay/late/out-of-order scenarios, refund idempotency **before outbound gateway API**, and exact amount/order/transaction/currency validation across all payment types.
2. Refund and booking RPC concurrency tests with two isolated sessions, confirming duplicate side effects cannot occur even under parallel callbacks. A source guard alone is not a database guarantee.
3. Full `webhook_logs.payload` PII-retention/consumer assessment; avoid silently removing fields relied on by accepted SQL receipts.
4. Integration/release authorization for deployment to Staging first, verification of actual deployed handler, then separate approval before production deployment/secret rotation; `main` remains untouched.
5. Official Storage provider patch/version and JWT role issuer/Auth hooks; three existing advisory tasks `85.01–85.03` remain **Needs Verification**, not assumed vulnerabilities. See [Storage and Paymob intake](VSP_SUPABASE_STORAGE_PAYMOB_SECURITY_INTAKE_2026-11-17.md).

## Unique-task accounting

These are implementations of existing `30.02–30.08`, `30.03`/`30.04`/`30.05`, `63.*`, `SEC-06` and `SEC-10`, **not new unique IDs**. None of those broad acceptance criteria includes verified hosted Paymob operation yet. All remain **OPEN** despite source fixes and successful CI.

| Metric | Value |
| --- | ---: |
| Unique task total | **633** |
| Accepted before this source batch | **266** |
| Newly accepted in this source batch | **0** |
| Newly added unique tasks in this source batch | **0** |
| Remaining | **367** |
| Distinct corrected local source-behavior categories (CI verified) | **4** |
| Newly production-deployed and verified fixes | **0** |
| Storage advisory applicability checks open | **3** |
| P0 new advisory audits open (existing project-wide P0 count unverified) | **3** |

No sales model change: venue revenue remains owner subscriptions; no per-booking platform commission is introduced by this batch.
