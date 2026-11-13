# VSP — notification legacy display fixes (branch-only)

Date: 2026-11-13. Changes committed to uxlp-44-implementation; no database mutation.

The player notification center now invokes a testable NotificationDisplayTextResolver to choose title/body text. It continues to prefer explicitly localized title_ar/body_ar/title_en/body_en metadata, then falls back to canonical body or the AppNotification model's legacy message alias. Both snake_case notification rows and historic body/message data remain read compatible. English UI continues to normalize only historical date/time tokens.

Tests cover old message-only rows, empty new body/metadata, canonical body priority, locale-specific metadata, old Arabic month tokens and rendering through a real Flutter Text widget. Architecture test ties the actual card's displayed text to the tested resolver. This is limited to the in-app read path; FCM payload rendering, live account inbox and older producer templates still need staging/device verification. Do not count 67.04/67.07 until Flutter CI passes.
