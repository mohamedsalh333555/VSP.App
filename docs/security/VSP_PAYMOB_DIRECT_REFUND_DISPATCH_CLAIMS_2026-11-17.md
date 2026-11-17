# VSP Phase 8 — replay-safe direct Paymob refunds for legacy 1v1 and cancelled bookings

**Date:** 17 November 2026 | **Branch:** `uxlp-44-implementation`

**Safety boundary:** GitHub source and disposable CI PostgreSQL only. No Staging/production DB mutation, Paymob external charge/refund, hosted secret inspection, `main` merge or release.

## Confirmed source weakness

The signed `paymob_webhook` previously made direct Paymob Refund API calls on two paths that are **not** owned by the tournament refund worker: legacy `TOURN_1V1_` over-capacity orders and successfully charged bookings whose existing state was `cancelled`. HMAC authentication ensures a genuine provider event, **not** one-time delivery. Repeated valid callbacks or a worker crash after sending the request could trigger a second outbound refund attempt, even when later accounting RPCs were idempotent.

A new server-only persistent dispatch claim closes that specific code path. It does not establish end-to-end exactly-once money movement for all Paymob methods.

## Source-level implementation

- [Unique refund dispatch migration](https://github.com/mohamedsalh333555/VSP.App/commit/aba61c3fc8ec62b96ae75fd1e167c3e2b8b2698c): creates `public.paymob_refund_dispatch_claims` with `paymob_transaction_id` PRIMARY KEY, strict numeric ID/amount/context/status checks, RLS enabled and no anon/authenticated policies or privileges. Server `service_role` alone can insert/read/update the claims. The table does **not exist** in the inspected production or Staging catalogs yet.
- [Shared claim helper](https://github.com/mohamedsalh333555/VSP.App/blob/uxlp-44-implementation/supabase/functions/_shared/paymob_direct_refund_claim.ts): no upsert; returns false for missing database table, duplicate key, mismatched row or malformed input; never retries outbound Paymob.
- [Signed Webhook hooks](https://github.com/mohamedsalh333555/VSP.App/blob/uxlp-44-implementation/supabase/functions/paymob_webhook/index.ts): both direct paths require a successful unique INSERT **after** HMAC/integration/currency/amount and provider authentication, **before** calling the external refund endpoint. A duplicate or failed claim returns `requires_reconciliation` and HTTP 200 **without dispatching**, rather than triggering a second refund. Claims persist across process crashes. Explicit provider acknowledgements mark `gateway_acknowledged`; other results require manual reconciliation.
- [Release security HOLD update](https://github.com/mohamedsalh333555/VSP.App/commit/802d60dffe06d35a532782fd5fb0d4199e582bac): requires the direct refund claim migration **and** prior Team League CHECK migration to be verified in hosted Staging before Edge Function rollout. Release remains blocked by other original P0 conditions. The gate tests a reviewed declaration, **not** the live security advisor.
- [Actual SQL role-denial negative tests](https://github.com/mohamedsalh333555/VSP.App/commit/861a1b414a1d12fb07be69d517386164e4838172): add attempts to INSERT as anon, SELECT/UPDATE as authenticated, and INSERT as service_role on a disposable CI database.

## Verified isolated tests

- [Deno and focused Flutter financial regressions — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44116142495) at commit `aba61c3`, including duplicate replay mock and fail-closed missing-table behavior.
- [Disposable PostgreSQL 17 schema and access contract — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44116142761) at `aba61c3`: primary-key duplicate, invalid refund context, RLS and grants. The subsequent [actual-role negative CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44116637117) is **SUCCESS**, including actual failed attempts under anon/authenticated roles and a successful service_role insert on disposable PostgreSQL.
- [VSP release-gate isolated CI — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44116461595) at `802d60df`, with financial migration dependencies named as current P0 blockers.
- No real Paymob Sandbox refund, database privilege check with genuine signed user JWT, storage compliance test or hosted migration was performed.

## Remaining blockers before Staging or production rollout

1. **Required migration ordering:** deploy and verify `20261117174500_paymob_webhook_direct_refund_dispatch_claims.sql` on isolated Staging before the modified `paymob_webhook`; independently apply/check `20261117173000_align_team_league_payment_refund_states.sql` before the modified team-withdrawal Edge Function.
2. **Historical reconciliation:** reconcile any previously sent refunds before the new claim table starts empty; do not assume an empty table proves older transactions were never refunded. Obtain provider-signed/official settlement evidence rather than automatically retrying.
3. **Provider idempotency:** exercise duplicated valid Paymob Sandbox callbacks, unknown/timeout responses, parallel event delivery, and an injected crash between claim INSERT and Refund POST. Observe only one external refund call and confirm ledger operations through independent staging sessions.
4. **Monitoring:** expose held `claimed`/unverified records to authorized operations, no player access; establish an explicit human reconciliation action without deleting the unique claim.
5. **Broader release gates:** legacy 1v1 retirement, direct refund paths, SEC-06 payment integrity, SEC-10 secrets, hosted Storage advisories 85.01–85.03, role-based negative tests, Paymob credentials and live callback wiring still need verification.

## Unique-task counter (strict)

| Metric | Value |
| --- | ---: |
| Total unique tasks | **633** |
| Previously accepted | **267** |
| Newly accepted in this batch | **0** |
| Newly added unique task IDs | **0** |
| Remaining | **366** |
| Accepted percentage | **42.18%** |
| Production-deployed fixes in this batch | **0** |

These safeguards implement *parts* of existing SEC-06/10, 30.*, 31.*, 63.* and 80.* requirements; they are **not** proof that broader acceptance criteria are met. The venue owner revenue model is still subscriptions, without per-booking commission.
