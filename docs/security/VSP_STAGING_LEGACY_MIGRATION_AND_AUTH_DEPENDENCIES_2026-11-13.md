# VSP staging — legacy relations, migration execution and Auth provider requirements

Observed 2026-11-13 UTC, **read-only staging** project `vtwgqyxglevcsxwdmhop`; sources: Postgres `information_schema.columns`, `pg_constraint`, `pg_proc`, deployed Supabase migration history and official Supabase Auth docs. No production query, schema/auth modification, sensitive player data, or data migration.

## 69.02–69.03 — Legacy 1v1 relationship and modern comparison

| | `vsp_1vs1_players` (legacy) | `vsp_1v1_tournament_players` (active/newer model) |
|---|---|---|
| Rows in staging (aggregate only) | **0** | **16** |
| Identity | `id uuid`, `name text` | `id uuid`, `tournament_id uuid`, `user_id uuid` |
| Referential constraints | No FK relationship returned for the legacy table | `tournament_id → vsp_1v1_tournaments(id)` ON DELETE CASCADE; `user_id → users(id)` ON DELETE SET NULL |
| Metrics and metadata | `total_points`, `skill_points`, `goals`, `tackles`, `titles`, `trend`, `round_reached` | `tackles`, `goals`, `skills`, `total_points`, `rounds_played` |
| Payment fields | No `payment_status` or `payment_order_id` in observed columns | `payment_status`, `payment_order_id`, `paid_amount`, `registered_at` |

The tables represent different identities and lifecycles; no direct legacy-to-modern relation can be assumed. See earlier [source/migration 1v1 inventory](../VSP_LEGACY_1V1_AND_CHALLENGE_RESULT_INVENTORY.md). This completes **69.02/69.03** as an explicit staging schema relationship and model comparison; **not** a paid-player migration or reconciliation proof. 69.04–69.07 remain open.

## 70.03 — Challenge-results references

Current `challenge_results`: `id uuid` primary key, `challenge_id text` with **no declared FK**, `team1_score`, `team2_score`, `submitted_by`, `confirmed_by`, timestamps and `status`. **0 rows** in staging. This is a separate key space from `bookings.id`; the challenge-result-to-booking link is **not database-enforced by a foreign key**. The active challenge mutual-result flow references booking result/status fields, as documented in [original source inventory](../VSP_LEGACY_1V1_AND_CHALLENGE_RESULT_INVENTORY.md). **70.03** accepted for mapping existing and absent references. No join/merge, orphan or duplicate conclusions are supported by empty staging rows.

## 71.03–71.05 / 72.03 — Actual staging migration ordering versus repository collisions

Supabase staging migration history currently has **379 entries with distinct applied version identifiers**. Several source filenames historically share a numeric prefix (see [collision source inventory](../VSP_MIGRATION_COLLISIONS_AND_NOTIFICATION_INVENTORY.md)); deployed staging history records disambiguated timestamp versions and may have empty or source-derived names. **Source filename order cannot prove applied function version**.

Relevant actual staging history (ascending applied versions):

| Applied staging version | Migration name |
|---|---|
| `20260925220341` | `remove_matchup_extra_team_fee_rule` |
| `20260925220915` | `fix_matchup_extra_team_fee_column_reference` |
| `20260925221249` | `remove_legacy_matchup_extra_team_fee` |
| `20260925230129` | `20260926170000_tournament_registration_payment_gate` |
| `20260925230223` | `20260926170000_official_user_lifecycle_write_paths` |
| `20260930112556` | `20260930030000_fix_persist_copilot_turn_service_role` |
| `20260930112724` | `20260930030000_fix_persist_copilot_turn_service_role` |
| `20261001110000` | empty migration name (ambiguous; do not guess the SQL body) |

The deployed `public.add_team_to_matchup_by_code(uuid,text)` currently is a `SECURITY DEFINER` routine; its **inspected function definition contains `MATCHUP_TEAM_LIMIT_REACHED` and does not contain `matchup_extra_teams_fee`**. This supports the effective no-sixth-team-fee/limit-5 variant at staging at this snapshot, **not** proof of all fee paths, access controls, or production deployment.

**Accepted scope:** 71.03 sequencing review, 71.04 targeted staging-history/current-RPC verification, 71.05 documented source-versus-applied-version differences; 72.03 review of the three relevant applied fee migrations and deployed current function signature/markers. No migration was applied, renamed, removed or replayed. 71.06–71.07 and 72.04–72.07 remain open; do not alter payment business rules or the database based on a filename alone.

## 73.02 — Supabase Auth leaked-password requirement

Official reference: https://supabase.com/docs/guides/auth/password-security

- Supabase Auth supports password minimum length (docs recommend **at least 8 characters**) and character classes configured in project Auth settings.
- Leaked-password checks use **Have I Been Pwned / Pwned Passwords API** and are available on **Supabase Pro plan and above**; check this project's actual plan entitlement before enabling.
- Staging Security Advisor currently warns `auth_leaked_password_protection`, i.e. do not assume leaked-password checks are turned on.
- When implemented in a reviewed staging change, test registration, password reset/change and weak/leaked-password rejection with **safe controlled test passwords**, without logging credentials or weakening login compatibility. Existing users' password policy transitions require consideration.
- No Auth settings changed. 73.03–73.06 remain open until provider capability/plan verified and safe staged testing performed.

Scope explicitly excludes raw customer data and production changes. No `main` merge.
