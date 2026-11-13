# VSP — legacy 1v1 participant and challenge result evidence / retention decisions

Date: 2026-11-13. Environment: **Staging** (\`vtwgqyxglevcsxwdmhop\`). All SQL in this review was SELECT-only, returned counts or schema metadata and never included usernames, player identifiers, payments, records, auth tokens or contact data.

## 69.04 — Staging 1v1 data review (scoped)

The deployed tables are \`vsp_1v1_registrations\` (older registration ledger), \`vsp_1v1_tournament_players\` (current per-tournament entries), and \`vsp_1v1_tournaments\`.

| Check | Staging result |
|---|---:|
| \`vsp_1v1_registrations\` rows | 0 |
| \`vsp_1v1_tournament_players\` rows | 16 |
| \`vsp_1v1_tournaments\` rows | 2 |
| Repeated \`(tournament_id,user_id)\` in current players | 0 |
| Repeated \`user_id\` in legacy registrations | 0 |
| Shared users between the two systems | 0 |

A **unique index** \`uq_1v1_tournament_user\` already enforces \`(tournament_id,user_id)\` in the active table. The legacy \`vsp_1v1_registrations\` table has a *partial unique* \`idx_unique_active_registration\` over \`user_id\` where status IN ('pending','approved'), not the same identity semantics. Empty old registration table does not imply it is safe to remove from production. All real-data claims above are staging only.

## 69.05–69.06 — Retain, do not merge automatically

**Decision:** keep historical \`vsp_1v1_registrations\` and continue using \`vsp_1v1_tournament_players\` as the confirmed, per-tournament live participant roster. Do not merge registrations by user alone: a user can participate in separate tournaments and payment statuses/orders may differ. Preserve the existing partial-unique legacy state key, and treat \`(tournament_id,user_id)\` as the current unique participant identity.

Future migration, if required: (1) inventory source lineage, references, payment status and order IDs on a disposable staging clone; (2) compare legacy active rows to current rows by verified tournament and user relationships; (3) quarantine any ambiguity; (4) backfill through an idempotent \`INSERT ... ON CONFLICT (tournament_id,user_id) DO NOTHING\` **only when existing payment and eligibility invariants have been checked**, never silently mark a free or pending player paid; (5) compare per-tournament participant counts, paid amounts, duplicates, RLS visibility and refund claims; (6) retain originals and rollback/cutover switch until a reviewed production rollout. No such data migration has been executed. 69.07 stays open.

## 70.02 — Read-only legacy result duplicate review

\`challenge_results\` has a UUID \`id\` primary key, text \`challenge_id\`, a nonunique index on \`challenge_id\`, legacy team score columns and review status. Staging **0** legacy rows, **0** duplicated nonblank \`challenge_id\`, **0** blank \`challenge_id\`, **0** confirmed legacy results. There are **20** current \`bookings\` with \`match_result_status='confirmed'\`. Neither a zero-row legacy sample nor the UUID primary key proves that historical legacy \`challenge_id\` references are globally unique or linked to the current booking ID in production.

## 70.05–70.06 — Original-result identity and safe correction plan

**Decision:** \`bookings.id\` with confirmed score/status is the active challenge result authority in the current app; \`challenge_results.id\` and text \`challenge_id\` remain legacy records. Do not cast \`challenge_results.challenge_id\` directly to UUID or silently map it to \`bookings.id\` without a validated crosswalk and team/date confirmation. The legacy table currently has revoked client access; do not reopen RLS policies.

Before any future cleanup: create a read-only identity mapping \`(legacy_result_id,legacy_challenge_id,booking_id,matched_by,review_status)\` in a controlled staging review environment, detect repeated legacy IDs and conflicting results, independently review unmatchable rows, verify team identity and timestamps, and require one-to-one result lineage before any backfill. If conflicts exist, mark manual-review rather than choosing the last result or overwriting confirmed scores. Retain originals for audit and rollback. Protect ELO/points from being reawarded on historical replay and run role-specific negative tests. 70.04 and 70.07 are still OPEN.

## Status and prohibited shortcuts

**Scoped acceptance only**: 69.04/69.05/69.06 (data sample + keep/migrate plan), 70.02/70.05/70.06 (legacy duplicates sample + preservation plan). Neither production correctness, all historical imports, a successful migration, nor real paid-transaction reconciliation is established. No existing records edited, no secret values read, no data migration, no production or main deployment.

Related evidence: \`docs/VSP_LEGACY_1V1_AND_CHALLENGE_RESULT_INVENTORY.md\`, \`docs/security/VSP_STAGING_LEGACY_MIGRATION_AND_AUTH_DEPENDENCIES_2026-11-13.md\`, Issue #38.
