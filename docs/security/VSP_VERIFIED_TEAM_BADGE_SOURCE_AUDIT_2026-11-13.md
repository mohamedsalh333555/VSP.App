# VSP verified team badge source inventory — Staging read-only, 2026-11-13

## 81.02: stadium-owner-organized approved team championships

The deployed `create_championship_atomic` sets `championships.owner_id = auth.uid()` and a linked `stadium_id`. To distinguish actual stadium-owner competitions from player-made or unrelated events, require:
- `championships.stadium_id = stadiums.id` and `championships.owner_id = stadiums.owner_id`;
- approved, completed championship with a non-null canonical `champion_team_id`;
- winner team equals current profile team, and each distinct championship ID is counted at most once.

The legacy `winner_team_id` is a compatibility alias; never count it separately. Staging has **0 approved completed team titles** and **0 matching stadium-owner titles**. No production conclusion is justified.

## 81.05: current members who have completed approved 1v1 titles

Current member source = `team_members(team_id,user_id)` UNION `teams(id,captain_id)` (deduplicate the captain). Candidate official source = `vsp_1v1_tournaments.status='completed'` with non-null `champion_user_id`, additionally requiring tournament-admin winner finality before publicly labeling verified.

Count *distinct current champion users*, not distinct tournaments or cached badges. Staging aggregates: **0 completed individual 1v1 champions**, **0 champion/current-team membership matches**, **12 teams**.

Deployed `check_team_has_1v1_champion` is NOT a sufficient canonical verified counter. It returns cached team flags, may trust unlocked_badges and published (not completed) tournaments, only checks the latest tournament and contains a legacy-player fallback. These can be stale or misleading.

## Important implementation gap

`TeamAchievementSummary.fromVerifiedResults` supports deduplicated official results, but the current `MyTeamScreen` calls `TeamAchievementsSection(team: team, isArabic: isArabic)` without supplying `verifiedSummary`. The official badge is therefore **not yet connected to live source data**. Retain 81.07 (refresh on membership change/title revocation), 81.09 (authorization and accuracy tests) and 81.10 (actual mobile RTL/accessibility) as OPEN. Also verify winner certification, role and RLS on real staging test accounts before wiring.

**Accepted scope: two source-inventory tasks only, 81.02/81.05.** No player identifiers, membership rows, raw title records, names or PII were returned. No Staging/production DML, schema, Flutter UI or main branch changes.
