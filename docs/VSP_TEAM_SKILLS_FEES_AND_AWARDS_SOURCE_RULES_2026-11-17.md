# VSP Team Skills Cup — current fee, awards and award eligibility (44.01–44.03)

**Date:** 17 November 2026. **Acceptance type:** source-backed documentation only, for Team Skills Cup. This does not change a price, authorize an award/payment, prove a payout, or complete a production release.

## 44.01 — Fees that currently exist
- `public.team_skills_cups.hospitality_fee` is `numeric(10,2)`, nonnegative and defaults to **50 EGP per team**, but is configurable for each cup; 50 EGP must not be promised as a universal charge.
- A team has `hospitality_payment_status='unpaid'` until an admin confirms physical cash collection (`verified`) or grants a documented waiver (`waived`). The latest `team_skills_confirm_hospitality` source only allows an **approved** team in an open/live cup, denies duplicated collection, and requires a reason at least 10 characters long for a waiver.
- This is not a Paymob checkout or a per-booking commission. Venue owner revenue remains **subscription-based, zero per-booking commission**.
- Source: `20261116030000_team_skills_cup_foundation.sql`, `20261116096000_team_skills_hospitality_approved_only.sql`, and Admin `TeamSkillsCupPage.jsx`. Read-only staging catalog verified the 50 default and approved-only guard.

## 44.02 — Recorded awards
- The cup can hold a `prizes` JSON array (default `[]`), without any universal monetary/prize-delivery schema. The `team_skills_awards` table recognizes **three** distinct award types: `team_champion`, `one_v_one_champion`, and `best_goalkeeper`.
- Award entries have a unique `(cup_id, award_type)` key and keep `announced_by` and `announced_at`. The admin-only award RPC also writes an audit. These are titles/recognition, **not verified payment or prize fulfilment**.
- Source: `20261116030000_team_skills_cup_foundation.sql` and `20261116040000_team_skills_cup_officials_and_awards.sql`. Staging catalog confirmed both award-type constraints.

## 44.03 — Eligibility rules
- **Skills team champion:** cup completed, 4–8 approved teams, all teams have all 12 skill stages approved, and the champion is the single highest-scoring eligible team. A first-place tie must be resolved explicitly before crowning.
- **1v1 champion:** an approved knockout final names the winning registration; the announced player must be that registration's selected 1v1 representative on the matching team.
- **Best goalkeeper:** an approved team goalkeeper with approved trials totalling at least five shots on target; highest save rate then save count, with an unresolved tie requiring documented playoff rather than arbitrary winner selection.
- The actual `team_skills_announce_award` requires an unblocked platform-admin caller and completed cup. Active trigger guards `guard_team_champion_finality` and `guard_goalkeeper_award` protect objective results. [SQL contracts pass](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44006227132).
- Sources: `20261116040000_team_skills_cup_officials_and_awards.sql`, `20261116083000_team_skills_goalkeeper_award_tie_guard.sql`, `20261116099000_team_skills_champion_finality_uuid_fix.sql`, `20261116098000_team_skills_champion_finality.sql`. Staging SELECT-only checks found both triggers enabled.

**Still open:** 44.04–44.08 (amounts due, withdrawals, ledgers, disputed payouts, premature prize withdrawals), 43.* independent 1v1 tournaments and all real money/account/device/release tests.

**Exactly three documentation IDs accepted: 44.01, 44.02, 44.03.**
