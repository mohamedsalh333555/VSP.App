# VSP — Task 12.01: Review player profile display (source audit, 19 November 2026)

**Decision:** Close 12.01 as a **source review only**. This is not a runtime visual acceptance, privacy clearance, new feature implementation, or server integration. Branch: `uxlp-44-implementation`, PR #35 Draft.

## Reviewed source
- [Player profile screen](../lib/features/player/screens/profile_screen.dart): header displays scoped `auth.userModel` image, player name and position, with translated fallback for unconfigured position; preference/governorate display and selection; team card loads via strict active user-team lookup.
- [Profile edit screen](../lib/features/player/screens/profile_subscreens/edit_profile_screen.dart): editable name and phone; player-only football position; image preview/pick; saving requires valid inputs and uses account identity recheck on async completions.
- [Team profile screen](../lib/features/player/screens/team_profile_screen.dart): shared team hero, roster, standings, achievements and captain information are separate from the personal profile. Team member data retrieval and incomplete/error paths deserve role/permission review.
- [Profile editing regression tests](../test/features/player/edit_profile_position_validation_widget_test.dart): player and owner editing, valid/invalid position, phone, error, double submit and account-change simulations in Arabic and English. [CI PASS at code revision](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44436426000).

## Observed display and boundaries
1. The personal profile is authenticated-user scoped: `currentUser?.id` identifies the team lookup, and a changed identity resets the pending team future. Team lookup failure displays retry/error rather than implying the user has no team.
2. Profile avatar, player name and position come from the hydrated user model; empty position has explicit Arabic/English fallbacks. Uploaded avatar handling is not proven on a real storage bucket.
3. Edit UI contains player-only position selection; it is not an administrative role editor. Locale-specific widget tests verified the edit data model, but not every device or the read-after-write hosted result.
4. Team achievements and captain details have separate source surfaces. Their official-result publishing rights and captain-contact privacy **must** be independently verified on staging.
5. **Outstanding legacy UX:** `ProfileScreen` still references `Vsp1v1UserTrophyBadge`. Approved replacement of current 1v1 surfaces by Team Skills Cup remains tracked under 86.04; this audit does not remove historical records or declare 86.04 completed.

## Open follow-up tasks
- **12.02** client edit validation separately accepted (not server persistence), **12.03** avatar/storage flow, **12.04** field/privacy authorization, **12.06** upload failure/retry and **12.07** two-device conflicts retain independent scope.
- UXLP/86.04 and cross-user team permissions remain release blockers until verified.
- No updates to source UI, Supabase, Paymob, `main`, APK or production were made for this audit.
