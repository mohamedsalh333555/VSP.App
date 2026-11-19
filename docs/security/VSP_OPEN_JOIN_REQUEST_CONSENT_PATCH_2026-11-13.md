# Open-join approval: P1 consent/idempotency patch (branch only)

2026-11-13. Source inspected in **Staging** with `pg_get_functiondef('public.accept_join_request(text,text)')`. No real bookings, players, phone numbers or invitation codes were read; no RPC invocation on Staging or production.

Observed code issue: `accept_join_request` accepts a caller-supplied user UUID and appends it to `bookings.joined_user_ids` while incrementing `current_players`, **without verifying `pending_user_ids` contains that user and without deduplicating already joined users**. When `owner_id` is NULL, its `!=` authorization check can evaluate to SQL NULL rather than TRUE, potentially allowing a different authenticated caller through. This proves a missing guard in deployed code, **not an exploited live incident**.

New, **unapplied** migration `20261113171000_guard_open_join_acceptance_consent.sql` validates UUID formats, locks the booking row, checks owner/creator permission with NULL-safe `IS DISTINCT FROM`, requires an explicit pending request, rejects cancelled/expired/full bookings and returns idempotently on repeated acceptance. Public/anon RPC execution is revoked in the migration; authenticated/service roles retain intentional access, subject to the internal authorization.

A local PostgreSQL contract with synthetic IDs compares the original deployed function (must **fail** negative test) against the new definition (must pass all cases): no consent, unauthorised caller with NULL owner, legitimate consent, repeated idempotent join, capacity, cancellation, malformed ID and missing JWT. It runs in a disposable database with fake `auth.uid/role` and no Supabase/Paymob network, then deletes the database. CI status must be verified on the exact commit.

**Hold deployment** until role-isolated Staging fixtures confirm existing producer writes pending IDs, trigger protections, response compatibility, payment/booking status semantics and a real cross-account join journey. Do not merge main or run on production automatically. This does not assert a complete 28.06/79.04 E2E fix.
