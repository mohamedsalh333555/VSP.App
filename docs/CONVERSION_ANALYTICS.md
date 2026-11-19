# VSP Conversion Analytics Contract

Updated 2026-11-09 · Phase 10 · Branch `uxlp-44-implementation`

## Privacy and reliability rules

- Use the existing Firebase Analytics integration; do not add another SDK.
- Analytics is auxiliary: failure must never block registration, booking, payment or navigation.
- Do not send names, email addresses, phone numbers, addresses, tokens, passwords, free-form messages or payment credentials.
- Screen/rebuild events use an in-process session dedupe key. Distinct successful operations may repeat.
- Venue, match and booking IDs are used only for local deduplication; Phase 10 helpers do not transmit them.
- Only categorical parameters are sent: `role`, `payment_method`, `sport_type`, `type` and `plan_code`.
- Respect the consent/privacy configuration enforced by the app and store policy. This document does not claim legal consent adequacy.

## Canonical event schema

`VSPAnalyticsEvents` is the executable dictionary. Its conversion set is regression-tested for exact membership, uniqueness and Firebase-safe lowercase names.

| Event | Authoritative trigger | Dedupe | Parameters | State |
|---|---|---|---|---|
| `app_opened` | startup reaches `runApp` | once/session | none | wired |
| `onboarding_started` | Welcome screen begins | once/session | none | wired |
| `signup_completed` | player/owner profile completion succeeds | operation | `role` | wired |
| `venue_viewed` | stadium details initializes or changes venue | venue/session | none | wired |
| `booking_started` | user taps the real booking CTA | venue/session | none | wired |
| `booking_completed` | confirmed booking success screen initializes | booking/session | `payment_method` | wired |
| `match_viewed` | match details initializes | match/session | none | wired |
| `match_joined` | repository confirms successful public/private join | booking/session | `type` | wired |
| `team_created` | team creation operation succeeds | operation | `sport_type` | wired |
| `owner_registration_started` | owner onboarding begins | once/session | none | wired |
| `owner_registration_completed` | owner profile completion succeeds | operation | none | wired |
| `subscription_viewed` | server-backed pricing screen begins | once/session | none | wired |
| `subscription_activated` | authoritative paid activation/webhook | operation | `plan_code` | intentionally unwired |

`subscription_activated` must remain unwired from checkout initiation. Creating an order or opening Paymob is not financial confirmation.

## Funnel definitions

### Player

`app_opened → onboarding_started → signup_completed → venue_viewed/match_viewed → booking_started → booking_completed/match_joined/team_created`

A booking CTA is not a completion. A join is counted only after the repository reports success.

### Venue owner

`app_opened → onboarding_started → owner_registration_started → owner_registration_completed → subscription_viewed → subscription_activated`

Adding a stadium still needs a separate event at the server-confirmed wizard success point; it must not be inferred from screen entry. Subscription activation waits for server-authoritative payment state.

### Retention

- D0: first `app_opened`.
- First value: first authoritative `booking_completed`, `match_joined`, team creation, stadium approval or owner operational action.
- D7/D30: a later `app_opened` in the applicable day window.

Retention requires consented longitudinal data and stable identity semantics. No D7/D30 result or conversion uplift is claimed.

## Offline activation funnel and dashboard (2026-11-17 source batch)

- `VSPActivationFunnels` computes distinct-account **chronological** player booking, player match, owner activation and owner subscription funnels using previously defined event names. It requires authenticated, consented, stable identities and a supplied UTC observation cutoff. Conversion and drop-off are suppressed for small groups; no raw identifiers appear in JSON export.
- Local visualization: `scripts/vsp_activation_dashboard.html` accepts aggregate JSON exported by `VSPFunnelReport.toJson()` without remote network calls. It is not publicly served and contains no fabricated sample metrics.
- Legacy `stadium_booked` and `challenge_sent` wrappers preserve the event names but now omit stadium, team and price dimensions. `privacySafeParameters` explicitly allowlists categorical or bounded-rank fields, rejecting unknown identifiers and free text.
- No live Firebase export, cohort identification, analytics console validation, D1/D7/D30 observation or before/after measurement was performed. Tasks 50.04/50.05 remain pending verification and authorization for a real source; 54.06/55.06 remain open.
- See [implementation evidence and acceptance limitations](VSP_ANALYTICS_FUNNEL_LOCAL_DASHBOARD_2026-11-17.md).

## Automated validation

- `test/core/services/analytics_service_test.dart`: privacy filtering, exact event dictionary, uniqueness and name format.
- `test/architecture/phase10_analytics_contract_test.dart`: funnel hooks stay at real journey boundaries; booking completion is absent from pre-success confirmation; paid subscription activation is absent from checkout initiation.

Firebase DebugView/device delivery, analytics console dashboards, cohort integrity and statistical lift remain runtime/data acceptance steps.
