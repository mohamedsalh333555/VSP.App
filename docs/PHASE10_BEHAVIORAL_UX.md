# Phase 10 — Behavioral UX, Conversion Optimization & Retention

Status: **IN PROGRESS** · Branch: `uxlp-44-implementation` · Updated 2026-11-05

Phase 10 extends the existing 24 end-to-end journeys and Phases 8–9. It does not restart completed work, change the owner-subscription business model, bypass authentication, or authorize a merge to `main`.

## Evidence standard

- **Implemented** means source is committed on the working branch.
- **Tested** means the relevant automated or staging path passed.
- **Measured** means real usage data demonstrates an outcome.
- **Pending Data** means instrumentation exists but conversion impact is not yet statistically known.
- **Blocked** means a required external service, credential, legal/commercial decision, or real user cohort is unavailable.

Technical completion is not proof of higher conversion or retention.

## Baseline findings

1. Public unauthenticated routes are intentionally limited by `AppRouter.redirectLogic` to auth/onboarding routes. Player and venue content currently require authentication. Expanding anonymous discovery needs an explicit public-data/privacy design; Phase 10 does not weaken those guards.
2. Welcome onboarding already explains three value propositions, supports Arabic/English, separates Player and Owner entry, and provides Skip/Login. The Android device journey is the active runtime check.
3. Venue details already show real images, location, price/deposit, amenities, conditions and ratings from the current stadium record, plus retry behavior for refresh failure.
4. Empty rating data was rendered as `0.0 (0)`, which can look like negative/fabricated social proof. It now renders “لسه مفيش تقييمات / No ratings yet”.
5. Owner pricing is loaded from `public_subscription_plans`; stale fallback prices are deliberately not shown. Free/Pro features, monthly/annual prices, trial duration, limits and real computed annual saving use server data. The commercial copy states subscription—not booking commission.
6. Firebase Analytics existed with several ad-hoc events, but the requested conversion funnel was incomplete and rebuild-sensitive screen events had no central deduplication/privacy filter.
7. Existing Phase 8/9 blockers remain authoritative: Paymob sandbox, real email delivery, FCM/device delivery, admin UI, team invitation acceptance and challenge-flow mismatch.

## Task register

| ID | Priority | Status | Current result / next evidence |
|---|---:|---|---|
| UX-01 New player | P1 | IN PROGRESS | Onboarding funnel entry instrumented; anonymous discovery deferred pending public-data design; Android onboarding/login regression rerun in progress |
| UX-02 Booking | P1 | IN PROGRESS | Real venue view and booking-start events added; existing price/deposit presentation retained; full failure/alternative-slot runtime evidence remains |
| UX-03 Venue trust | P1 | IMPLEMENTED / TEST PENDING | Empty ratings no longer impersonate a score; real location, media, prices and amenities retained |
| UX-04 Matches/teams | P2 | BLOCKED/PARTIAL | Real participant/capacity UI exists; journey 14 lacks invite acceptance and journey 08 differs from requested acceptance flow |
| UX-05 Tournaments/leagues | P2 | BLOCKED/PARTIAL | Existing rules/results retained; paid completion and legitimate winner evidence remain blocked |
| UX-06 Owner journey | P1 | IN PROGRESS | Registration start/completion and subscription-view events added; server-priced Free/Pro presentation retained |
| UX-07 Pricing | P3 | IMPLEMENTED / TEST PENDING | No decoy plan added; no invented discount; annual saving appears only when computed from positive live prices |
| UX-08 Retention/progress | P2 | REVIEWED/PARTIAL | Existing bookings, teams, tournament and trial progress retained; 7/30-day cohorts need real data |
| UX-09 Egyptian localization | P2 | IN PROGRESS | Empty-rating Arabic improved; broad copy replacement intentionally avoided; RTL/device matrix still required |
| UX-10 Analytics | P1 | IMPLEMENTED / TEST PENDING | Privacy filter, session dedupe and core funnel events added |
| UX-11 Funnels | P1 | IMPLEMENTED / PENDING DATA | Event map documented; retention cohorts require timestamps/user consent and real usage |
| UX-12 Experiments | P3 | NOT STARTED | Baseline and hypotheses documented; no A/B result claimed |
| UX-13 Quality/safety | P0/P1 | IN PROGRESS | No fake scarcity, reviews, discounts, fees or guarantees introduced; CI and Android smoke remain gates |

## Implemented source changes

- `AnalyticsService`: privacy-safe parameters, session deduplication and typed conversion events.
- `main.dart`: one `app_opened` event per process session.
- Welcome onboarding: one `onboarding_started` event per session.
- Stadium details: one `venue_viewed` event per venue per session.
- Booking CTA: one `booking_started` event per venue per session.
- Owner onboarding: registration start and successful completion events.
- Subscription plans: one plan-view event per session.
- Venue information: honest no-rating empty state instead of `0.0 (0)`.
- Regression test: analytics parameters remove direct personal/credential-like fields.

## Behavioral principles applied

- Reciprocity/foot-in-the-door: preserve value explanation and direct Player/Owner paths before asking for detailed onboarding data.
- Truthful social proof: only show rating/count when reviews exist.
- Anchoring/decoy: no synthetic reference price or decoy plan; show only real Free/Pro values.
- Truthful scarcity/loss aversion: no new scarcity copy; existing capacity/deadline claims must stay server-derived.
- Endowed progress: preserve genuine onboarding/trial/team/tournament state; no synthetic progress.
- Similarity: concise Egyptian Arabic where appropriate, formal language for policies.
- Authority: no “verified” badge added unless backed by the existing approval/verification state.

## Explicit deferrals

- Anonymous venue/match browsing: requires a public-safe route and field-level disclosure review; current auth redirect is not bypassed.
- New reviews/loyalty/rewards: moderation, fraud, privacy and commercial rules are not defined.
- Push re-engagement: FCM delivery remains blocked; notification consent/frequency policy must precede campaigns.
- Conversion uplift claims: pending real consented cohort data.
- New plan, discount, prize, fee or guarantee: requires owner approval and authoritative commercial data.
