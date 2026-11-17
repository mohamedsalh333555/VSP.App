# VSP — Foreground FCM recipient and account-scoped notification preferences

**17 November 2026, `uxlp-44-implementation`.** Source-only; no Edge Function deployment, no real notification or Supabase schema change.

## Confirmed source issues
1. Notification settings write `vsp_user_<uid>_notif_general`, `vsp_user_<uid>_notif_chat` etc. Foreground `NotificationUiHelper.showInAppAlert` used unrelated **legacy device-global** keys via `NotificationFilterService.shouldShowNotification` and unscoped `notif_sound`. A player's opt-out could be ignored.
2. Foreground FCM `data` did not contain the intended recipient, so a device re-used after account switching could show a sensitive snackbar for an old user.
3. An invalid FCM token cleanup queried `user_device_tokens` by token only; scope it to the actual recipient user to avoid affecting another user's row.

## Source changes
- New user-scoped `shouldShowNotificationForUser` reading exact current account settings, with no import of old device global keys; foreground UI checks active account before/after asynchronous preference reads.
- New FCM `recipientUserId` data field on server-origin pushes; client **fails closed** on missing/mismatched IDs for foreground snackbars.
- FCM invalid token deletion requires matching `user_id`.
- Flutter widget and unit tests cover two account settings, opt-out, untrusted/missing recipient and real widget suppression, plus source-level sender contract.
- Known compatibility limit: older pushes missing `recipientUserId` no longer display a foreground in-app snackbar. The native/system push may still appear; full shared-device security requires clearing stale FCM tokens on sign-out and server-side delivery controls. Deploy sender first, validate on Staging, then roll out app; don't enable code paths out of order.

## Task accounting and acceptance
Candidate scope: `49.04` user preferences and `79.08` cross-account notification isolation. **Do not mark either accepted solely from source changes.** Flutter CI must pass, and `79.08` requires a production-equivalent two-account RLS/push test beyond widget simulation. No task counted as completed from code alone. Existing 633/272/361 baseline stays unchanged until verified.

## Second batch: cover the actual foreground notification service and Realtime callbacks

- Audited `lib/core/services/notification_service.dart`: previously it could call `_showLocalNotification` **before** the helper's protected snackbar check, so only guarding `NotificationUiHelper` left a foreground local-notification exposure. Realtime callbacks were also using legacy global settings and could continue when a different user signed in.
- Added checks against the active user and target `recipientUserId` **before** local FCM display, then recheck after asynchronous preferences reads. Realtime callbacks check the subscribed user ID, row owner ID and current signed-in account before any notification display.
- Local match reminders and booking confirmation now consult their account-scoped notification toggles. Existing schedule timing behavior is **not** changed in this batch.
- Notification click handling now refuses missing/wrong recipient ID, validates route ID segments and suppresses raw booking/team identifiers from diagnostic logs; Realtime-generated local payloads carry the recipient ID.
- Source assertions cover all four entry points, plus user-scoped Flutter unit/widget tests. No hosted JWT or cross-account real-device proof; 79.08 remains open.

## Token-owner reconciliation (read-only hosted evidence)

- Aggregated read-only database query of both production and Staging: **0 users** currently have a nonempty `users.fcm_token`; no owner mismatch or unmatched legacy values were found. No individual token, user row or PII was read or exported.
- Removed fallback push delivery from `users.fcm_token`: that column can remain stale after a shared-device account switch. FCM now selects only `user_device_tokens` entries for `user_id` and checks the owner a second time before sending. Token cleanup was already constrained to the same `user_id`.
- Defensive failure: device-token lookup errors return 503 rather than incorrectly classifying the user as having no devices. No database columns, policies or schema were changed.
- Added isolated Deno tests for two accounts with a shared device, invalid rows, deduplication, and missing recipient. Source-only; production FCM sender deployment is separate and remains on HOLD until Staging real-account tests.
