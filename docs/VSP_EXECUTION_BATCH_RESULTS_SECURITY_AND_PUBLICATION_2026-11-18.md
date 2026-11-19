# VSP — 18 November 2026: verified-public-result integrity continuation

**Branch:** `uxlp-44-implementation` (PR #35 draft). No merge, APK, production deployment, payment mutation, or SQL mutation.

## Code delivered

- Flutter team profile: explicitly distinguish verified empty history, loading, and failed refresh. A failed read no longer exposes cached scores as current. Unplayed 0/0/0 opponent rows do not advertise a win.
- Flutter Team Skills: enforce exactly one verified award per cup/award type, refuse contradictory recipients, and never attach an individual player to the team-champion trophy. Reject malformed, duplicate-inconsistent or unpublished cup cards and preserve retryable error states.
- Admin Panel: mirror official award uniqueness/recipient invariants across individual pages and paginated history. A contradictory pair is not shown as an official winner.
- Public Website: suppress final scores when team identity, outcome and declared winner are inconsistent; remove duplicate or cross-event fixtures before Next.js server-to-client serialization. No Home layout change.
- Public Team Skills website publication remains blocked until an independently verified public-only data projection is authorized. The marketing website uses a publishable anon client, while the current Team Skills history views require authenticated role.

## Commits

- App Flutter: `f6645b439273a50edf7fad42aad4b52d20141449`, `4050f11c6c7367a8f63909a9c24cf496bfbcb4c1`, `6775c0858def3795edee43eec49d8e22fe9305e9`, `805e338df18627bb30ff77bbbd2ee87d4d249e33`, `ddf99cf6647f0667e2dfca1fc13492e7f5bf7c5f` (clean source restoration following CI analyzer rejection).
- Admin: `ae77d440bd01001f73943dc7c426d7f6fe5c94db`.
- Public Website: `626c18d202835f3093bd74d4f7474b8243b3bc52`, `0094ceeb0850c35d8e159037298029cccd800c5e`.

## Live Staging read-only evidence (not production)

Supabase Staging project `vtwgqyxglevcsxwdmhop`: verified by metadata-only SQL (no user-data read, no writes), 18 November 2026.

- `team_skills_team_history`, `team_skills_player_history`, `team_skills_cups`, and `team_skills_awards` exist.
- `anon` has **no SELECT grant** to either history view or to cups/awards tables. `authenticated` has SELECT to the history views. Cups and awards tables have RLS enabled.
- 24 `public.team_skills_%` SECURITY DEFINER functions exist; **none grants EXECUTE to anon**. Authenticated access still requires function-body authorization checks and real two-user JWT actor tests; grant shape alone is not proof of permission safety.
- Security advisor flags SECURITY DEFINER functions callable by signed-in users and extensions in public; not classified as confirmed vulnerabilities without actor testing. Four sampled sensitive admin/subscription RPCs visibly include explicit administrative authorization checks, not yet separate-session verified.

## Evidence and acceptance gate

- Targeted Team Skills and Team Profile Flutter workflows passed after restoring correct source.
- Admin `npm test` and `npm run build` succeeded in its targeted workflow.
- Website tests/lint/typecheck/build succeeded in the verified-results workflow.
- Broad Flutter CI was still in progress at the time of this snapshot. Full staging multi-actor tests, devices, user-facing Website parity and final QA remain open.

**Do not close original tasks 86.03, 86.04 or 86.05** from these source-only changes: real last-five verified per-match history and competition-scoped rank delta are not yet sourced, legacy-current retirement must be proven cross-platform, and Website public results have no approved anon-safe projection.

**Official counter unchanged:** 640 active unique tasks, 328 accepted, 312 open (51.25%). A source-level fix and a passing focused workflow are not equivalent to production acceptance.
