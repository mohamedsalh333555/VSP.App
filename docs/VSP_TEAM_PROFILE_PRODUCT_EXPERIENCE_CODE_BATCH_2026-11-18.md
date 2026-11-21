# VSP — Team Profile & Product Experience source-level continuation

**18 November 2026.** Branch: `uxlp-44-implementation`; PR #35 remains Draft.

## Changes committed to this branch
1. Team Profile refuses unrelated/self-play/invalid head-to-head aggregates and keeps missing counts unknown.
2. Team Skills award history now requires known award type, cup ID and parseable announcement timestamp, and deduplicates repeated rows; official publication still depends on the existing secure view and rollout gate.
3. Player and team legacy 1v1 medals are labeled *historical* in English/Arabic; old records are preserved. Player badge reads are cached by account and stale account values are hidden.
4. Team match-history OR filter accepts only canonical UUIDs, preventing untrusted filter-expression interpolation. Raw invalid IDs are not echoed in exceptions.
5. Owned-team realtime/roster logs redact server errors/stack traces.
6. Team Profile and My Team distinguish activity badges from official competition results. No new unverified title count is introduced.

## Tests authored
- `test/features/player/team_profile_official_awards_history_test.dart`: award announcement/deduplication, foreign rows, invalid team identifier.
- `test/features/player/team_achievement_badges_test.dart`: historical 1v1 semantics.
- `test/vsp_1v1_trophy_badge_test.dart`: historical Arabic accessible label, per-account cache, account switch.
- `test/architecture/player_home_information_architecture_contract_test.dart`: owned-team diagnostics privacy.
- `test/features/player/team_activity_achievement_provenance_test.dart`: bilingual source/UI distinction and verified-only official counter.

## Acceptance and boundaries
**Task counter unchanged: 640 total, 328 accepted, 312 open.** These are code/test contributions, not accepted full tasks. Flutter CI on the final SHA, staging two-account tests, official results publishing, ranking delta, full last-five verified matches, Admin/Website parity and device UX remain unverified. Never infer retention uplift or production readiness from source changes.

No change to Home, payments, pricing, team challenge code lifecycle, Supabase production, Team Skills rollout flag, historical records, `main` or APK. No production deployment or merge.
