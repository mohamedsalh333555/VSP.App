# VSP — legacy 1v1 participant and challenge result evidence / retention decisions

Date: 2026-11-13. Environment: **Staging** (\`vtwgqyxglevcsxwdmhop\`). All SQL in this review was SELECT-only, returned counts or schema metadata and never included usernames, player identifiers, payments, records, auth tokens or contact data.

## 69.04 — Actual legacy 1v1 data (corrected)

The **actual legacy standalone player table** is \`public.vsp_1vs1_players\` (note **1vs1**, not \`1v1\`), previously identified by \`VSP_STAGING_LEGACY_MIGRATION_AND_AUTH_DEPENDENCIES_2026-11-13.md\`. A separate older workflow table \`vsp_1v1_registrations\` is also present; **these are NOT the same table**.

| Table / check | Staging |
|---|---:|
| \`vsp_1vs1_players\` standalone legacy player profiles | **0** |
| \`vsp_1v1_registrations\` older status ledger | **0** |
| \`vsp_1v1_tournament_players\` current per-tournament records | **16** |
| \`vsp_1v1_tournaments\` | **2** |
| Duplicate active \`(tournament_id,user_id)\` keys | **0** |
| Duplicate old registration \`user_id\` keys | **0** |

The actual legacy \`vsp_1vs1_players\` has \`id\`, \`name\`, avatar and stat columns, **but no \`tournament_id\`, \`user_id\` or \`payment_status\`**; it must not be interpreted as an unpaid registration or merged into a paid roster. The modern table's \`uq_1v1_tournament_user\` index enforces current per-tournament identity. The separate \`vsp_1v1_registrations\` table has \`idx_unique_active_registration\` on \`user_id\` with pending/approved states.

## 69.05–69.06 — Retain standalone legacy players and payment records

**Decision:** retain all three schemas. \`vsp_1vs1_players\` represents historical standalone player statistics, \`vsp_1v1_registrations\` the historical registration workflow, and \`vsp_1v1_tournament_players\` the canonical current per-tournament entries. No direct FK/crosswalk from legacy standalone profile ID to \`users.id\` or current tournament ID is shown by staging metadata. Never join by display name or assign \`payment_status='paid'\` to a legacy stats profile.

Any future migration requires an owner-reviewed identity crosswalk, financial order confirmation, profile ownership proof, uniqueness and team/tournament role tests. Preserve original stat totals for audit without recrediting medals or prizes. Quarantine ambiguous data, run isolated/test migration and reversible shadow-read, then decide whether historical players should remain archive-only. No backfill or merge was run. 69.07 stays open.

## 70.02 — Read-only legacy result duplicate review

\`challenge_results\` has a UUID \`id\` primary key, text \`challenge_id\`, a nonunique index on \`challenge_id\`, legacy team score columns and review status. Staging **0** legacy rows, **0** duplicated nonblank \`challenge_id\`, **0** blank \`challenge_id\`, **0** confirmed legacy results. There are **20** current \`bookings\` with \`match_result_status='confirmed'\`. Neither a zero-row legacy sample nor the UUID primary key proves that historical legacy \`challenge_id\` references are globally unique or linked to the current booking ID in production.

## 70.05–70.06 — Original-result identity and safe correction plan

**Decision:** \`bookings.id\` with confirmed score/status is the active challenge result authority in the current app; \`challenge_results.id\` and text \`challenge_id\` remain legacy records. Do not cast \`challenge_results.challenge_id\` directly to UUID or silently map it to \`bookings.id\` without a validated crosswalk and team/date confirmation. The legacy table currently has revoked client access; do not reopen RLS policies.

Before any future cleanup: create a read-only identity mapping \`(legacy_result_id,legacy_challenge_id,booking_id,matched_by,review_status)\` in a controlled staging review environment, detect repeated legacy IDs and conflicting results, independently review unmatchable rows, verify team identity and timestamps, and require one-to-one result lineage before any backfill. If conflicts exist, mark manual-review rather than choosing the last result or overwriting confirmed scores. Retain originals for audit and rollback. Protect ELO/points from being reawarded on historical replay and run role-specific negative tests. 70.04 and 70.07 are still OPEN.

## Status and prohibited shortcuts

**Scoped acceptance only**: 69.04/69.05/69.06 (data sample + keep/migrate plan), 70.02/70.05/70.06 (legacy duplicates sample + preservation plan). Neither production correctness, all historical imports, a successful migration, nor real paid-transaction reconciliation is established. No existing records edited, no secret values read, no data migration, no production or main deployment.

Related evidence: \`docs/VSP_LEGACY_1V1_AND_CHALLENGE_RESULT_INVENTORY.md\`, \`docs/security/VSP_STAGING_LEGACY_MIGRATION_AND_AUTH_DEPENDENCIES_2026-11-13.md\`, Issue #38.
