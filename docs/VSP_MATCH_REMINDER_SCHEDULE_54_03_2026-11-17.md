# 54.03 — Match reminders at kickoff minus two hours

Date: 2026-11-17. Working branch: `uxlp-44-implementation`.

## Verified source bug
`scheduleMatchReminder` computed kickoff minus 2 hours but used `_localNotifications.show`, immediately displaying the reminder. It also used process-dependent `bookingId.hashCode` and a click payload that did not name `bookingId`.

## Source fix
- Use Flutter Local Notifications 17.2.4 `zonedSchedule` at the **absolute UTC instant** of kickoff minus two hours, inexact Android alarm (does not request exact-alarm permission), `timezone` 0.9.4 direct dependency with pinned lockfile.
- Use stable positive per-account + booking ID; store the scheduled IDs by account in local preferences.
- Verify active account again after native scheduling; cancel if account changed mid-operation; on normal sign-out cancel scheduled IDs **before revoking the account session**.
- Use validated `bookingId` and `recipientUserId` notification payload for safe navigation.

## Verification and limits
Unit/source contract tests cover DST absolute times, future-only trigger, stable IDs, zoned scheduling, identity check and logout cleanup. Flutter CI must pass before a task is accepted.

**Limits:** Android inexact scheduling can fire late under idle modes; no physical-device reliability proof, no forced-kill cleanup, no backward cleanup of old-version notifications; concurrent local settings writes and rare 31-bit hash collisions remain possible. Existing scheduled reminders may still fire after user disables a preference until cancellation is additionally wired into the settings UI. This does not implement global notification frequency rules. No production notification was sent or new device permission requested.

## Follow-on opt-out hardening
Both `notif_general` and `notif_match_reminders` switch handlers now cancel the account's scheduled native reminders **only after local opt-out persistence succeeded**. A failed save does not report a successful switch; a cancellation failure is caught to avoid reversing an already saved opt-out. The active-account scope is retained. The specialized Flutter CI now includes both new focused tests and their source dependency paths.

## Focused acceptance evidence, 17 November 2026

**54.03 ACCEPTED, narrowly scoped** to fixing the existing local match reminder timing and lifecycle, not broad engagement messaging. [Specialized Flutter Analyze and focused tests SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44161802294) on [8e431bf](https://github.com/mohamedsalh333555/VSP.App/commit/8e431bfe5cbe6c9ad6e14e5a6edbae15b9fbe2f0). No physical Android/iOS delivery or exact idle timing claimed. Current project accounting: 633 total, 278 accepted, 355 open.
