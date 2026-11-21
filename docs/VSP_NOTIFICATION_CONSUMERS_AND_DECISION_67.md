# Notification consumers and legacy compatibility decision — 67.02 / 67.06

## Actual read/write chain

1. `lib/core/repositories/notification_repository.dart`: `getUserNotifications(userId)` subscribes to Supabase `notifications`, orders by `created_at`, maps database snake_case into model camelCase and invokes `AppNotification.fromFirestore`. Its mapper now forwards both `body` and legacy `message` (`ceee2c9`), preventing legacy content loss before it reaches the model.
2. `lib/data/models/notification_models.dart`: `AppNotification.fromFirestore` prefers nonblank `body`, falls back to `message`, then empty text. `toFirestore` emits canonical `body` only (`7c06e0a`).
3. `lib/features/player/screens/notifications_center_screen.dart`: receives the notification stream and renders `notification.body`. This is the main in-app display consumer of the model.
4. `lib/core/services/notification_service.dart`: handles Firebase and local notifications and delegates persisted notifications to the repository; FCM payload shape and background presentation are separate from the Supabase row-to-model path.
5. `lib/features/player/screens/profile_subscreens/notifications_screen.dart`: notification preferences UI backed by local SharedPreferences, not the notification-message rendering screen.
6. `lib/core/repositories/notification_repository.dart`: `sendNotification` and `restoreNotification` write canonical `body` to Supabase. No legacy duplicate write introduced.

## Canonical decision (67.06)

The canonical persisted notification text field is **`body`**. `message` is accepted as a **read-only legacy alias** for old records. The repository must preserve both values until the model chooses the preferred one. This decision is backward-compatible, reversible at the app layer and does not require altering RLS or production notification tables.

**Evidence:** `docs/VSP_NOTIFICATION_FIELD_CANONICAL_AND_COMPATIBILITY_67.md`, `test/data/models/notification_models_legacy_test.dart` (3 model tests), `test/architecture/notification_repository_legacy_mapping_test.dart` (source contract). Tests have been written, **not executed**.

**Boundary:** 67.02 is a traced *primary* client read/write chain, not a claim that every server-side producer or FCM template was exhaustively audited. 67.04 and 67.07 (old template and rendered UI integration testing) remain open.
