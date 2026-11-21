# VSP 86.01 — Player Home preserved (bounded acceptance; 19 Nov 2026)

**Status:** ACCEPTED, source and Flutter-widget regression boundary only. **Branch:** `uxlp-44-implementation`, Draft PR #35; no `main` merge.

## Existing product surfaces protected

- `HomeFeedContent` keeps `HomeTopBar` then the sponsor banner (`home_slider`), stadium discovery, matches, and competitions, with a working pull-to-refresh. No private achievement, individual rank, repeat-booking or personal progress card added to Home.
- `PlayerHomeScreen` retains its five destinations in `IndexedStack`: Home, Teams, Competitions, Bookings, Profile. Selected icons remain filled/bold and inactive ones outline. Business logic, sponsor placement, search, filters and Home hierarchy are unchanged.
- `test/architecture/player_home_information_architecture_contract_test.dart` checks section order, uniqueness, navigation, exclusions and icon combinations.
- `test/features/player/home_layout_navigation_widget_test.dart` renders Arabic RTL and English LTR at 320×720 dp and verifies all five destinations, labels and active/inactive state after switching to Competitions.
- **Verified CI:** [VSP Player Home Structure and Navigation Contract — success on prior code head 6b970b3](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44456758008). This acceptance did not require a Home UI code change.

## Explicit non-claims

This proves a *bounded non-regression contract*, not screenshot pixel parity, real-device RTL accessibility, all routes deep-linking, sponsor delivery, 338-screen review, or actual funnel conversion. Those are separate open tasks. No new achievement or ranking card was introduced on Home.

## Concurrent engineering work — not part of the accepted count

The team-profile captain challenge code has a separate [source fix](https://github.com/mohamedsalh333555/VSP.App/commit/c22ac8d0894eaf1020557706589b5dc64fef7e9a) against disclosing stale async responses after switching teams/accounts or losing captain status. New `TeamMatchupInviteGuard` tests cover valid captain, changed team, changed user, lost captain, stale request and invalid IDs. Server authorization, current 8-digit code contract and real two-account staging are **not verified** and remain OPEN.

**Counter:** 640 total, **343 accepted**, **297 open**, 53.59%. No production payment, data, release, APK or `main` merge.
