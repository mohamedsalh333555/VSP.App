# VSP — Team Skills published details, award notification recipients and mobile achievement badge tests

Date: 17 November 2026, Egypt. Working branches: VSP.App `uxlp-44-implementation` and Admin `feat/team-skills-cup`.
**Bounded acceptance, not general production/release/real JWT acceptance.**

## 38.05 — Publish actual Team Skills competition details (bounded app + admin + SQL)

- The canonical `public.team_skills_set_status` function, published cup SELECT/RLS and audit were exercised with actual source SQL in `supabase/tests/team_skills_published_details_isolated_contract.sql`. Players cannot see a draft, and only an active VSP platform admin can publish; a published cup is subsequently readable. [SQL CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44010432162).
- Flutter `TeamSkillsCupRepository.listCups/getCupById` exposes registration/live/completed cups, never draft. Its details screen re-fetches live cup state; registration actions are shown **only** for freshly verified registration status and the captain's team, with a second server preflight before request submission. Server RPC remains final authority.
- Newly implemented `lib/features/player/widgets/champion/team_skills_published_details.dart` displays governorate, selected stadium name (or truthful unavailable notice), local start/end, max team count, per-cup hospitality fee, and prizes from configured JSON (`award`, `title_ar`, `name`, etc.) with a safe label fallback rather than raw metadata. `getVenueName` checks actual stadium read privileges and fails to a neutral placeholder, not an invented venue. Widget tests cover published Aswan details, variable fee, configured prize labels, empty/unavailable cases.
- The separate Admin branch adds `src/services/teamSkillsPublishedDetails.js`, `test/teamSkillsPublishedDetails.test.js` and an explicit **draft preview** in `src/pages/TeamSkillsCupPage.jsx` showing exactly the publication fields, without leaking raw prize object/internal IDs or labeling drafts published. [Admin CI npm tests + build success](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/44010028754); [admin commit](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/18a0d5ea3cce8b6e2673c6191fbf1d73c6bb916c).
- [App Flutter analyze+tests passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44010432025). [Android public/auth smoke passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44010432073), [unsigned iOS device build passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44010432165). These do **not** test the feature-enabled competition flow on real multiple devices and accounts.

## 46.07 — Protected award-notification recipients (bounded Team Skills ONLY)

- Read-only staging discovery found `vsp_skills_private.notify_award()` used all roster rows and could include **inactive withdrawn/former players** when an award was announced.
- The new additive migration `supabase/migrations/20261117033000_team_skills_award_notification_active_roster_guard.sql` restricts announcements to an `approved` registration of the actual awarded cup/team, active rows of that exact competition roster, plus that registration's captain (one notice per unique user). No manual client-controlled recipient IDs, booking/payment changes or historical notification replay.
- The actual SQL fixture `supabase/tests/team_skills_award_notification_recipients_isolated_contract.sql` verifies recipient set against an approved winning team, a removed inactive player, a withdrawn registration, a different team in the same cup and a same-team record in another cup. Exactly three active recipients get scoped notices and the captain is not duplicated. [SQL CI run passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44010432162).
- Reviewed migration deployed to **vsp-staging only** as Supabase version **`20261117032927`** (`team_skills_award_notification_active_roster_guard_20261117`). Read-only post-deployment catalog confirms `roster.active=true`, approved-only, cup-scoped body, trigger enabled, no `anon` or `authenticated` direct EXECUTE; the staging DB had zero Team Skills awards and no customer award row changed.
- This acceptance is for **award notifications only**. Team invitation notifications across all VSP features and genuine cross-account JWT/FCM delivery remain open under 46/48/59/79.

## 81.10 — Small-screen, RTL, accessible verified badges (bounded widget acceptance)

- `lib/features/player/widgets/my_team/team_achievement_badges.dart` exposes separately labeled team-owner-championship and verified 1v1-champion-player counts with a single semantic accessible announcement; counts are supplied only from separately verified results. A Wrap provides constrained small-device layout and no data is invented when a verified summary is absent.
- Flutter widget tests in `test/features/player/team_achievement_badges_test.dart` verify Arabic zero-state accessible semantics, English counts on 320px layout, **280px phone width + Arabic RTL + text scaling 1.8x**, accessible labels and absence of framework exceptions. [Flutter CI passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44010432025).
- This does **not** certify real-screen-reader navigation on physical Android/iPhone, full player profile E2E, or dynamic badge source update from new membership, which remain addressed by 81.07/81.09 and device acceptance groups.

## Release and evidence boundary

- App full CI on code SHA `80a50f7db9f2ec931c33e5d933e4e7ee64f221b9`: Flutter, Android smoke, unsigned iOS, owner checkout, SQL and accounting successful. Admin feature branch CI successful separately.
- Supabase security advisors were re-run after staging-only award fix: preexisting **4** `extension_in_public`, **224** executable definer function warnings and **1** leaked-password protection warning; these are not declared resolved by this batch.
- No `main` merge, production migration, official Play/App Store publication, signed installable release APK, new venue booking commission, sponsor payout or genuine cross-account JWT/FCM acceptance.

Exactly **3 additional existing task IDs** accepted with limited evidence: **38.05, 46.07, 81.10**.
