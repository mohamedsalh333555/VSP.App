# VSP — isolated booking SQL checks and staging view hardening acceptance

2026-11-13, development branch `uxlp-44-implementation`. **Scoped acceptance, not release readiness.**

## 22.06, 22.07 — Function-level operating-window conflict and midnight tests

GitHub Actions [Account SQL security contracts run #43440144002](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43440144002) succeeded at commit `45a45e7e12491f32d2009c6f50e656c2689a3f9e`. The step `Verify booking maintenance and overnight split-break SQL on isolated Postgres` completed successfully.

The isolated PostgreSQL 17.6 runner extracts the original function and demonstrates the SQL contract **fails** with the old expired-maintenance predicate, then installs the proposed function inside another rolled-back transaction and requires all contract cases to **pass**: a normal slot, active/expired emergency closure, exact boundary, partial closure overlap, daytime split break, overnight opening, 3 overlapping midnight split breaks, valid pre-break overnight slot, after-hours slot and invalid/null timestamps.

The result is a *function-level test* for conflict (22.06) and crossing midnight (22.07). It is not evidence that a direct unauthorized insert, all owner manual booking RPCs, exact DST transitions or physical devices are safe. The SQL migration remains **unapplied** outside CI. Tasks 22.04, 22.05, 66.07 and server booking integration acceptance remain open.

## 76.03, 76.06 — Staging-only view protection and record

Earlier staging migrations (documented in [four-view hardening](STAGING_ALL_FOUR_VIEWS_HARDENED_2026-11-07.md)) changed the four historically SECURITY DEFINER public views to `security_invoker=true`. The sensitive `owner_subscription_status` view also explicitly revokes anonymous SELECT.

A fresh **read-only** `pg_class` / `has_table_privilege` query confirms:

| View | Invoker | anon SELECT | authenticated SELECT |
|---|---|---|---|
| `courts` | true | yes | yes |
| `public_subscription_plans` | true | yes | yes |
| `tournament_clean_sheets` | true | yes | yes |
| `owner_subscription_status` | true | **no** | yes |

Two transaction-scoped role checks (both rolled back) returned only aggregate counts:
- `SET LOCAL ROLE anon`: `courts=2`, `public_subscription_plans=2`, `tournament_clean_sheets=0`.
- `SET LOCAL ROLE authenticated` with no JWT identity: `owner_subscription_status=0`.

This establishes current staging view configuration and limited anonymous/no-identity read behavior; it does **not** prove owner A vs owner B isolation, administrative authorization, underlying grants/RLS correctness for every source, or production deployment. Items 76.04, 76.05, 76.07, Issue #38's privileged RPC review and release hardening remain open.

## Totals and limits

**Four newly scoped accepted tasks:** 22.06, 22.07, 76.03, 76.06. Canonical ledger **128 VERIFIED / 490 open / 618 total**. No fixtures, user rows, identity records, bookings, payments or schemas changed in staging or production. The isolated CI database is ephemeral. No `main` merge.
