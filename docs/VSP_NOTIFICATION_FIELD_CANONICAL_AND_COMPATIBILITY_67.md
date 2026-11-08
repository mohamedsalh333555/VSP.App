# Notifications — canonical field and backward-compatibility decision (67.03 / 67.05)

## 67.03 — Canonical field

Use **`body`** as the canonical application notification content field. `lib/data/models/notification_models.dart` defines `AppNotification.body`, writes `body` in `toFirestore()/toMap()`, and displays it through the model. Do not make new notification producers write `message` instead of `body`.

`message` is a legacy read alias, not a second independent user-facing message or an authorization bypass. No database column is dropped or renamed by this decision.

## 67.05 — Compatibility plan

1. **Read:** when `body` is present and not whitespace, prefer it. Otherwise read legacy `message`. If both are absent, use an empty string. This is implemented in `AppNotification.fromFirestore()` (`7c06e0a`).
2. **Write:** continue emitting `body` as the canonical key from the app. Do not emit duplicate fields on new writes solely to accommodate old readers.
3. **Tests:** `test/data/models/notification_models_legacy_test.dart` checks old-only `message`, both fields, and blank `body` fallback (`5be5b84`); these tests were added but **not run**.
4. **Rollout:** before changing notification SQL templates, push workers or other client consumers, inventory all producers/readers (67.02), sample historical records and test actual notification UI rendering (67.04, 67.07).
5. **Rollback:** client fallback is non-destructive; rolling back the app may restore blank historical notifications. No data rewrite is required to roll back this compatibility layer.

**Scope:** 67.03 and 67.05 define a complete client field decision and non-destructive compatibility plan. They do not claim old notification templates or production records have been verified.
