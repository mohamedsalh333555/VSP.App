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
