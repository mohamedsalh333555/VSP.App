# VSP Conversion Analytics Contract

Updated 2026-11-05 · Phase 10 · Branch `uxlp-44-implementation`

## Privacy and reliability rules

- Use the existing Firebase Analytics integration; do not add another SDK.
- Analytics is auxiliary: failure must never block registration, booking, payment or navigation.
- Do not send names, email addresses, phone numbers, addresses, tokens, passwords, free-form messages or payment credentials.
- Screen/rebuild events use a session dedupe key. User actions that represent genuinely distinct completed operations may repeat.
- IDs may be used only as an in-process dedupe key; new Phase 10 screen events do not transmit venue/match IDs.
- Respect the consent/privacy configuration already enforced by the app and store policy. This document does not establish legal consent adequacy.

## Implemented event contract

| Event | Trigger | Dedupe | Parameters |
|---|---|---|---|
| `app_opened` | app reaches `runApp` after required startup | once/session | none |
| `onboarding_started` | WelcomeScreen begins | once/session | none |
| `signup_completed` | typed helper available; wire only at authoritative successful registration point | operation | `role` |
| `venue_viewed` | stadium details initialized/changes stadium | venue/session | none |
| `booking_started` | user taps real Book Now CTA | venue/session | none |
| `booking_completed` | typed helper available; wire only after server-authoritative success | operation | `payment_method` |
| `match_viewed` | typed helper available; wire after screen contract is verified | match/session | none |
| `match_joined` | existing successful join integration | operation | existing booking/type compatibility parameters |
| `team_created` | pending authoritative success hook | operation | none planned |
| `owner_registration_started` | owner onboarding begins | once/session | none |
| `owner_registration_completed` | owner profile completion succeeds | operation | none |
| `subscription_viewed` | real server-backed pricing screen begins | once/session | none |
| `subscription_activated` | typed helper available; wire only after authoritative paid activation/webhook | operation | `plan_code` |

Events intentionally left unwired are safer than firing early and overstating completion.

## Funnel definitions

### Player

`app_opened → onboarding_started → signup_completed → venue_viewed/match_viewed → booking_started → booking_completed/match_joined`

A funnel stage is counted only from its authoritative event. A booking CTA is not a booking completion.

### Venue owner

`app_opened → onboarding_started → owner_registration_started → owner_registration_completed → subscription_viewed → subscription_activated`

Adding a stadium remains a product event to add at the server-confirmed wizard success point; it must not be inferred from screen entry.

### Retention

- D0: first `app_opened`.
- First value: first authoritative `booking_completed`, `match_joined`, team creation, stadium approval or owner operational action.
- D7/D30: a later `app_opened` in the applicable day window.

Retention requires consented longitudinal data and stable anonymous/user identity semantics. No D7/D30 result is claimed yet.

## Validation

`test/core/services/analytics_service_test.dart` verifies direct personal/credential-like parameters are stripped. Full Firebase DebugView/device delivery and duplicate-event inspection remain runtime acceptance steps. No conversion lift has been measured.
