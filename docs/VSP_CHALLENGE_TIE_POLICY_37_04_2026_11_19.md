# VSP — 37.04 Challenge ranking tie policy

**Date:** 19 November 2026. **Scope:** only the VSP player Team Ranking display for confirmed challenge/team points; policy definition and Flutter presentation, NOT league standings, Team Skills judging, migration or production validation.

## Authorized results

Confirmed team challenges use `3 × wins + draws` points, as traced in [37.01's approved formula](VSP_CHALLENGE_POINTS_FORMULA_37_01.md). An **unconfirmed, contested, missing or unverified score cannot legitimately grant points**. The correct source for these points and updates remains separately gated by **37.02/37.03/37.05–37.07 and 84.***; this document does not claim that they are all implemented.

## Tie rules (definition, not an invented winner)

1. Sort descending by confirmed points. Teams with **equal verified points share the same competition position** (competition ranking: ranks 1, 1, 3, 3, 5).
2. A stable, ascending team-ID comparison **only makes the UI list deterministic**, it is **not** a tie-breaker and does not create a higher rank, a champion or a prize recipient.
3. If points tie within the top three or across the third/fourth boundary, do **not** display an arbitrary winners' podium. Show a list with shared ranks instead. A prize or final winner requires a competition-specific, authoritative admin-approved rule/result.
4. Do not automatically use wins, head-to-head history, goal difference or alphabetical team names to force unique ranks: the challenge points contract has not validated any of those as an official tie-breaker.
5. League tournaments and Team Skills Cup follow their own official result/advancement rules; this challenge policy must not override those systems.

## Evidence and acceptance boundary

The production Flutter list uses `TeamsRankingTab.sortForDisplay`, `rankAt`, and `podiumIsAmbiguous`. Focused Flutter widget/unit tests confirm shared positions, deterministic same-points visual ordering, and suppression of unverified podiums. The existing `VSP Teams Ranking Tie Integrity` GitHub Actions workflow gates them.

**37.04 can be accepted only as the definition and verified Flutter display contract for challenge standings**, not as a claim of complete standings computation, server reconciliation, real-account checks, payout entitlement or live league decisions. No Supabase or financial write, APK, `main` merge or production deploy.
