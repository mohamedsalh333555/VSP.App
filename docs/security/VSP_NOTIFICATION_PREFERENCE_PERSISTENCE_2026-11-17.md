# VSP — Account-scoped notification setting persistence guard

Date: 2026-11-17; branch: `uxlp-44-implementation`.

## Confirmed UI issue
The 10 switches in `NotificationsScreen` previously called `setState` before awaiting `SharedPreferences.setBool`. If storage failed, the screen showed an opted-out preference even though the write was not confirmed. After account switching, an old asynchronous save could also race with the new user's screen.

## Implementation
- Each of the ten preference switches now awaits an explicitly successful `Future<bool> _saveSetting` before updating visible state.
- Failed or thrown writes display the existing bilingual error and do not show a false successful change.
- Both the save and follow-up UI commit check the user ID active at the time of the tap, in addition to `mounted`.
- Preserves the existing per-user keys, notifications default behavior, and owner/player role-specific categories; no DB or cloud changes.

## Verification and boundaries
The new `test/architecture/notification_preferences_commit_guard_test.dart` asserts ten save-before-commit paths and account-change guards. Existing Flutter tests cover category mapping and two-account opt-outs. Acceptance of task **49.04** is pending exact-commit Flutter CI and remains narrow to local setting persistence; this does **not** prevent native push messages server-side or prove production opt-out behavior. Tasks 54.04/07/08 and 79.08 remain open pending server/provider tests. No real data, Paymob, Supabase migration, APK or main merge.

Baseline 633 total / 272 accepted / 361 open until CI proof.
