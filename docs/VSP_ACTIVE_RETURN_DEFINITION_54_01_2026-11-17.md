# 54.01 — Definition of meaningful active return (VSP)

**Date:** 2026-11-17. **Type:** Product analytics metric contract only. No live cohort data, notifications, marketing delivery or cross-device analytics changes.

## Distinguish visits from active value
- The existing `docs/CONVERSION_ANALYTICS.md` D7/D30 rule based on `app_opened` is **visit retention**. Do not present it as meaningful engagement or player retention.
- **Active return** is when the **same consented, stably identified, authenticated account** triggers an eligible *meaningful action* on calendar D1, D7 or D30, relative to its **first confirmed value** event. This must be a different UTC date from D0.
- Use UTC calendar-day cohorts, not elapsed 24-hour windows; Cairo daylight saving changes must not drift the boundaries. Count **one account at most once per day** regardless of repeated events, navigation rebuilds or device count.
- Denominator: eligible unique consented authenticated accounts with a confirmed first-value event on cohort D0 and observation coverage through the target day. Separate player from owner cohorts, never mix their behavior in a denominator.
- Numerator: those same accounts with at least one eligible active return event exactly on the target UTC date. No inference from mere app launches, push opens, impressions, signup forms or checkout starts on D0.

## Canonical event eligibility (current source)
- **Player first value:** `booking_completed`, `match_joined`, `team_created`.
- **Player active return:** `venue_viewed`, `booking_started`, `booking_completed`, `match_viewed`, `match_joined`, `team_created`.
- **Owner first value:** `owner_dashboard_viewed` (operational entry) or `subscription_activated` (only when provider-verified; this event is currently not wired).
- **Owner active return:** `owner_dashboard_viewed`, `subscription_viewed`, `subscription_activated`.
- Avoid using `signup_completed`, `onboarding_started`, `app_opened` or `booking_started` as *first confirmed value*.
- Corrected/removed events must not create extra unique accounts. Require identity/consent scoping; no raw IDs, phone numbers or payment details in the metric report.

## Code and verification
`VSPActiveReturnContract` is a **pure Dart definition and validator**, not a Firebase uploader, retention dashboard or identity joiner. Unit tests cover D1/D7/D30 boundaries, cross-role activity, missing consent/identity, app opens and timezone offsets.

**Acceptance limit for 54.01:** source-only metric definition can be accepted after exact commit Flutter CI. **54.02–54.08 stay open:** actual segmentation, consent implementation, delivery frequency and D7/D30 cohort measurement require real privacy-approved data governance and tooling. No claim of current VSP retention rate or uplift.

## Verified acceptance (2026-11-17)

**54.01 ACCEPTED as an executable metric definition only:** [Flutter Analyze plus 30 focused tests SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44144855159) on source SHA `bc293e3`. No live Firebase retention report, consented identities or active cohorts were measured. **54.02–54.08 remain open**. Current project count 633 / 274 accepted / 359 open.
