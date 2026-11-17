# 54.07 — Account-scoped local notification opt-out acceptance

Date: 17 November 2026. Branch: `uxlp-44-implementation`. **Status: accepted with a narrow local/foreground test scope**, not accepted for server-side FCM opt-out or physical-device delivery.

## Tested code and regression coverage

- [Commit ce3ccf4](https://github.com/mohamedsalh333555/VSP.App/commit/ce3ccf4585432c51dafd11fbe9ae0f7f0754664f): local match reminder scheduler rechecks the same account's saved `notif_general` and `notif_match_reminders` values after the native OS scheduling await and again after the async reminder registry write. If consent is revoked or the account changes, cancel the scheduled ID and clear its local registry marker. Reject a failed registry persistence result rather than leaving a reminder untracked.
- The same code change captures the account before a local booking confirmation and refuses a notification-inbox write when the current account changes before persistence; it never substitutes a different account ID for the target.
- [Commit 2a4ef2c](https://github.com/mohamedsalh333555/VSP.App/commit/2a4ef2c23e35fe4e3e6c5710de87db2a32d5983a): source-order contract tests cover opt-out during native scheduling and registration, and booking-confirmation account isolation.
- [Commit 80fefcc](https://github.com/mohamedsalh333555/VSP.App/commit/80fefccbea1a79770eb12872e76519b00b3d18ea): mocked SharedPreferences test proves persisted master opt-out rejects `reengagement`, `marketing`, `match_reminder` and `booking_confirmed` foreground categories for the opted-out account while another account is not affected, until explicit opt-in.
- Preexisting logout and settings-screen opt-out cancellation guards remain covered by the targeted suite.

**Verification:** [Notification preferences and active retention contracts — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44178671321), triggered by code commit `80fefcc`. This workflow runs `flutter analyze --no-fatal-infos` and the focused Flutter tests that include the two edited test files.

## Hard limits and remaining acceptance

- This does not prove that a native OS alert was not delivered on a real device under an actual race; SharedPreferences is local/cached, so cross-isolate and multi-device timing is not atomic.
- Settings are currently stored locally; the Supabase/FCM server does **not** have a verified authoritative marketing opt-in/opt-out source and can deliver background notifications independently. **54.04 remains open**.
- End-to-end suppression of re-engagement (including server-initiated pushes on all devices) is not established; **54.08 remains open**.
- No notification was sent and no Staging/Production database, permission, payment, user data, live FCM or `main` change was made.
- This acceptance closes **only existing task 54.07**, with scope recorded here. It does not add a new task to the 633-task plan or change release hold.
