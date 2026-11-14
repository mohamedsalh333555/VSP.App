# Phase 10 — Behavioral UX, Conversion Optimization & Retention

Status: **IN PROGRESS** · Branch: `uxlp-44-implementation` · Updated 2026-11-09

Phase 10 extends the 24 end-to-end journeys and Phases 8–9. It does not restart completed work, change the owner-subscription business model, bypass authentication, or authorize a merge to `main`.

## Evidence standard

- **Implemented**: source is committed on the working branch.
- **Tested**: the relevant automated or staging path passed.
- **Measured**: real usage data demonstrates an outcome.
- **Pending Data**: instrumentation exists but conversion impact is not statistically known.
- **Blocked**: an external service, credential, legal/commercial decision or real cohort is unavailable.

Technical completion is not proof of higher conversion or retention.

## Baseline findings

1. Public unauthenticated routes are intentionally limited by `AppRouter.redirectLogic`. Anonymous venue/match discovery needs an explicit public-data/privacy design; the phase does not weaken authentication guards.
2. Welcome onboarding already explains value, supports Arabic/English, separates Player and Owner entry, and provides Skip/Login.
3. Venue details already show real images, location, price/deposit, amenities, conditions and ratings from the current record, with retry behavior.
4. Empty rating data previously appeared as `0.0 (0)`; it now displays “لسه مفيش تقييمات / No ratings yet”.
5. Owner pricing is loaded from `public_subscription_plans`; stale fallback prices are not shown. Free/Pro features, prices, trial duration, limits and computed annual saving use server data. Commercial copy states subscription, not booking commission.
6. Firebase Analytics existed with ad-hoc events. Phase 10 now provides a centralized event dictionary, privacy filtering, session deduplication and verified journey-boundary placement.
7. Existing blockers remain authoritative: Paymob sandbox/authoritative paid activation, real email delivery, FCM/device delivery, admin gaps, team invitation acceptance and the challenge-flow mismatch.

## Task register

| ID | Priority | Status | Current result / remaining evidence |
|---|---:|---|---|
| UX-01 New player | P1 | IMPLEMENTED / TEST PENDING | onboarding and successful player signup instrumented; anonymous discovery deferred pending public-safe design |
| UX-02 Booking | P1 | IMPLEMENTED / TEST PENDING | venue view, booking start and confirmed booking completion instrumented; alternative-slot/network runtime evidence remains |
| UX-03 Venue trust | P1 | IMPLEMENTED / TEST PENDING | honest no-rating state; existing location, media, price and amenities retained |
| UX-04 Matches/teams | P2 | PARTIAL / BLOCKED | real match view/join and team-create events exist; journey 14 invite acceptance and journey 08 flow mismatch remain |
| UX-05 Tournaments/leagues | P2 | PARTIAL / BLOCKED | existing rules/results retained; legitimate completion/winner evidence remains |
| UX-06 Owner journey | P1 | IMPLEMENTED / TEST PENDING | registration start/success and subscription view instrumented; no commission claim introduced |
| UX-07 Pricing | P3 | IMPLEMENTED / TEST PENDING | no decoy or invented discount; only live plan data and computed saving displayed |
| UX-08 Retention/progress | P2 | REVIEWED / PENDING DATA | existing genuine booking/team/tournament/trial progress retained; D7/D30 needs real data |
| UX-09 Egyptian localization | P2 | IN PROGRESS | targeted Arabic copy improved; broad rewrite avoided; RTL/device matrix remains |
| UX-10 Analytics | P1 | IMPLEMENTED / TEST PENDING | canonical schema, privacy filter, dedupe and funnel hooks covered by automated contracts |
| UX-11 Funnels | P1 | IMPLEMENTED / PENDING DATA | player/owner/retention definitions documented; dashboards and real cohorts remain |
| UX-12 Experiments | P3 | PENDING DATA | hypotheses documented; no A/B lift claimed without infrastructure and sample size |
| UX-13 Quality/safety | P0/P1 | IN PROGRESS | no dark patterns introduced; current-head CI and Android smoke remain gates |

## Implemented source changes

- Central `VSPAnalyticsEvents` dictionary for all 13 requested conversion events.
- Privacy-safe analytics parameters and per-session deduplication for rebuild-sensitive events.
- App open, onboarding, successful player/owner signup, venue view, booking start/completion, match view/join, team creation, owner registration and subscription view hooks.
- Booking completion uses the booking ID only as an in-process dedupe key and sends only the categorical payment method.
- Paid subscription activation stays unwired until authoritative payment/webhook confirmation.
- Honest venue no-rating state instead of a fabricated-looking zero score.
- Automated privacy, schema, uniqueness, event-name and journey-boundary regression contracts.

## Behavioral principles applied

- Reciprocity/foot-in-the-door: preserve value explanation and direct Player/Owner paths before detailed onboarding.
- Truthful social proof: show rating/count only when reviews exist.
- Anchoring/decoy: no synthetic reference price or decoy plan; show only real Free/Pro values.
- Truthful scarcity/loss aversion: no new scarcity copy; capacity/deadline claims remain data-derived.
- Endowed progress: preserve genuine onboarding/trial/team/tournament state; no synthetic progress.
- Similarity: concise Egyptian Arabic where appropriate and formal language for policies.
- Authority: no “verified” badge without a real approval/verification state.

## Explicit deferrals

- Anonymous discovery: requires public-safe routes and field-level disclosure review.
- Reviews/loyalty/rewards: moderation, fraud, privacy and commercial rules are undefined.
- Push re-engagement: delivery and consent/frequency acceptance are incomplete.
- Analytics dashboards, D7/D30 cohorts and conversion lift: require consented real usage data.
- New plans, discounts, prizes, fees, guarantees or ROI claims: require owner approval and authoritative commercial data.
- APK/release: remains outside this phase until the final review gate.
