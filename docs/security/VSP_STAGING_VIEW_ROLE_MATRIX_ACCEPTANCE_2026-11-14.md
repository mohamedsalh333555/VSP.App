# Staging view role matrix — 76.04, 76.05, 76.07

On 14 November 2026, read-only SQL on the **vsp-staging** database checked the current definitions and role behavior of `courts`, `public_subscription_plans`, `tournament_clean_sheets` and `owner_subscription_status`. All four reported `security_invoker=true`. Each simulated role/JWT claim was scoped to `BEGIN READ ONLY` and ended with `ROLLBACK`. Owner IDs, contact data and view rows were not returned; only aggregate counts were collected.

| Role case | Courts | Active plans | Clean sheets | Owner subscription rows | Foreign owner rows |
|---|---:|---:|---:|---:|---:|
| Anonymous | 2 | 2 | 0 | SELECT denied by privilege | — |
| Authenticated, no identity | — | — | — | 0 | — |
| Player | 2 | 2 | 0 | 0 | 0 |
| First owner | — | — | — | 1 | 0 |
| Second distinct owner | — | — | — | 1 | 0 |
| Admin | 17 | 2 | 0 | 12 | 12 (expected administrative access) |

An additional anonymous aggregate over `courts` reported 0 blocked or owner-deleted rows among 2 visible. The owner view includes phone and fee-related columns, making its `anon` denial and cross-owner isolation especially relevant. The four view definitions and privileges were inspected from `pg_class`, `pg_get_viewdef` and role-scoped SELECTs; this validates the **current staging snapshot**, not merely the migration file.

**Acceptance boundary:** 76.04 covers allowed public reads and owner/admin subscription access; 76.05 covers the sensitive owner view's tested anonymous/player/other-owner denials; 76.07 covers observable behavior across anonymous, player, two owner identities and admin. The SQL role and claim simulation does not prove that the application's login issues genuine JWTs with those identities. `tournament_clean_sheets` contained no matching rows, so its positive per-row access remains unproven. This is not blanket proof for all view columns, all stadium rows, RPCs, storage, production RLS or the 79.xx real-account journeys. No schema or data was changed.
