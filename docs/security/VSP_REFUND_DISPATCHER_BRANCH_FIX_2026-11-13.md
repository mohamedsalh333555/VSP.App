# Branch-only refund dispatcher hardening proposal (#39)

Date: 2026-11-13. Proposed on `uxlp-44-implementation`. Not deployed.

The deployed Staging cron function currently targets a **production** Edge Function URL and only triggers for two queues, not the team league queue. The Staging `refund_worker` credential name is currently absent (count-only audit), so the worker is not ready. This is a P1 environment isolation and refund liveness risk, not evidence that anyone's money was lost.

## Candidate function

The new migration `20261113160000_guard_refund_dispatcher_project_isolation.sql` contains **no fixed project URL**. It requires a trusted database-local `vsp.refund_worker_project_ref` configuration and constructs the exact HTTPS Supabase Edge Function URL from this value. When the GUC is missing/malformed or the dedicated `refund_worker` credential is missing, it returns without making an HTTP request. A caller-supplied arbitrary URL is never accepted. It dispatches when *any* of the three queues has pending rows or a stale/expired processing lease; no queue rows are changed by the dispatcher. Execute privileges remain restricted to service roles and Postgres cron.

**Critical deployment prerequisite:** the DB's actual project identity is not automatically available as a trusted setting, and the custom GUC is admin-configured, not cryptographically bound to the host. An operations owner must independently verify that the configured value matches the **current database's** project and credential and cannot point to the other environment. Never copy production ref/credentials into Staging. Do not insert secrets or activate this cron until that review is complete. This migration deliberately fails closed when not configured.

## Isolated proof plan

`scripts/test_refund_dispatcher_isolated.py` runs in the existing local-only PostgreSQL CI service. The test stubs `net.http_post` with a local capture table: it performs **no network calls**, does **not store authentication headers**, reads no real data, and wraps all fixture tables/functions in a transaction that is rolled back.

Test scenarios: empty queues, missing project ref, arbitrary URL rejection, missing credential, league-only pending, regular-only pending, 1v1-only pending, mixed queues (single dispatch), active processing lease (no dispatch), expired lease and old abandoned lease (dispatch), completed rows (no dispatch). Separate unit tests reject non-loopback database hosts. CI status must be verified on the exact commit.

**Not yet accepted as 65.02 or any production financial task.** A passing local fake-network test cannot prove a real Paymob refund, timeout idempotency, authorized edge worker behavior, transaction reconciliation or Staging deployment. No `main` merge, no actual staging/prod DB changes. Further acceptance requires environment owner review, staging-only dry-run and rollback.
