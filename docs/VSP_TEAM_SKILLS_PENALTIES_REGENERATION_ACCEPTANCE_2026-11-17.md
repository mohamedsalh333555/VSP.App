# VSP Team Skills Cup — 40.05 and 40.06 bounded acceptance

Date: 2026-11-17, Africa/Cairo. Original counter: **228 accepted / 402 open**.
After accepting two distinct existing original task IDs: **230 accepted / 400 open**, total **630**.

## 40.05 — معالجة التعادل

**Accepted for Team Skills knockout only.** A tied regulation match can now
be adjudicated using explicit, decisive, nonnegative integer penalty totals
in the administrator interface. The server never guesses a winner or silently
breaks a tie.

- Source migration:
  `supabase/migrations/20261117021000_team_skills_knockout_penalty_tie_break.sql`.
  Adds nullable recorded `first_penalties` and `second_penalties` with
  a constraint requiring actual tied regulation scores and unequal penalty
  totals whenever populated.
- New authenticated-only, admin-authorized
  `public.team_skills_approve_knockout_penalties(uuid,int,int,int,int)`
  locks the match row, checks active/completed non-cancelled event and a
  scheduled match with both teams, validates all scores, chooses the winner
  solely from authoritative penalty totals, advances the winner into the
  correct next-round slot, and writes an explicit `method:penalties` audit.
- The existing non-draw 3-argument approval RPC is **unchanged** and
  continues rejecting a tie without penalties.
- Disposable actual-SQL contract:
  `scripts/test_team_skills_knockout_advancement_isolated.py` injects the
  checked-in migration into
  `supabase/tests/team_skills_knockout_advancement_isolated_contract.sql`.
  Tests tied semifinal/final, next-round advancement, stored scoring evidence,
  one audit per approved match, and denied tied/negative/irrelevant/duplicate
  penalty attempts.
- Dashboard branch `feat/team-skills-cup`:
  `TeamSkillsOperations.jsx` displays penalty fields only for a regulation
  draw and displays saved penalty totals. `teamSkillsService` uses only
  the new server RPC, not direct table writes. Pure UI guards and
  `test/teamSkillsKnockoutPenalty.test.js` reject ambiguous values.

## 40.06 — إعادة توليد آمنة

**Accepted for unplayed Team Skills knockout brackets only.** This is an
actual supported in-place re-generation operation, not the previously
accepted refusal of duplicate generation (`40.08`).

- Source migration:
  `supabase/migrations/20261117022000_team_skills_knockout_safe_regeneration.sql`.
- New authenticated-only, admin-authorized
  `public.team_skills_regenerate_knockout(uuid)` takes the same advisory
  transaction lock used by initial seeding, then locks existing bracket
  rows before checking played status.
- A live cup, unplayed bracket, completed 12 skills stages and valid
  4–8-team bracket are required. It rejects already played matches,
  recorded penalty totals, announced awards, completed/cancelled cups and
  mismatched bracket shape. It does **not DELETE or INSERT** knockout rows:
  every match UUID remains stable, current seed order is reconstructed,
  first-round byes are promoted correctly, and an audit records the action.
- Disposable actual-SQL contract:
  `scripts/test_team_skills_final_seeding_isolated.py` injects the new
  regeneration function into the existing 4–8-team fixture. It verifies
  that each allowable number regenerates without losing match identities
  or bye count, preserves approved skills results, and rejects regeneration
  of played, awarded and completed cups. This explicitly goes beyond
  the duplicate-generation denial test already counted under `40.08`.
- The admin UI shows a guarded *regenerate before play* button only for
  a live cup with an unplayed bracket and no announced award;
  the server rechecks everything. Unit tests:
  `test/teamSkillsBracketRegeneration.test.js`.

## Evidence

- [App SQL security contracts — **success**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43996014424)
  at SHA `679c09531cbf915163b59af4d97a9cbb6333ee71`.
  Exact receipts:
  - `PASS: knockout progression and decisive penalties for tied semifinals/final, saved goals, correct winner, single audit; ambiguous/negative/repeat denied`
  - `PASS: 4-8 team brackets regenerated safely in place, all match IDs/byes preserved; played, awarded and completed cups protected; skills scores frozen`
- [Admin Panel CI — **131/131 tests and build successful**](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43995936875),
  SHA `c84e96b72c49aacab0652353e397cca0b78652ca`.
  [Admin Dashboard CI — successful](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43995936754).
- Staging project `vtwgqyxglevcsxwdmhop` only: read-only preflight showed
  **zero** existing knockout matches, then the two migrations applied
  successfully. Read-only catalog check verified both `SECURITY DEFINER`
  RPCs, `is_admin` guards, `anon` EXECUTE denied and `authenticated`
  EXECUTE granted. Recorded migration versions:
  - `20261117013105` — `team_skills_knockout_penalty_tie_break_20261117`;
  - `20261117013112` — `team_skills_knockout_safe_regeneration_20261117`.
  GitHub source-to-staging mapping is in
  `docs/team_skills_staging_migration_lineage.json` (37 entries).

## Not claimed or closed

- **No production deployment**, APK, store approval, main merge or
  payment integration was performed.
- PostgreSQL fixture authentication is simulated claim/roles, **not**
  separate signed-in real JWT sessions; staging end-to-end management and
  judges/players with actual accounts, plus Android/iOS device tests,
  remain outstanding under their already-open IDs (42.08, 59.*, 77/79.*).
- This task acceptance is **limited to the Team Skills Cup**. It does not
  imply equivalent behavior in other general tournaments/challenges.
- No live staging match was actually started, approved or cancelled;
  staging deployment and catalog verification do not replace real
  authorized-user browser acceptance.
- Existing 24 retired E2E journey group 56 remains excluded.

## Accounting
- 2 distinct original IDs newly accepted: **40.05**, **40.06**.
- `228 + 2 = 230`; `630 - 230 = 400`.
- Update all four counter sources and require
  `scripts/verify_task_accounting.py` success.
