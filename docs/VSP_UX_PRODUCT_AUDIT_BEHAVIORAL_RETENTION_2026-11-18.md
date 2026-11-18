# VSP — Behavioral UX & Product Audit
**Date:** 2026-11-18  
**Branch inspected:** uxlp-44-implementation  
**Scope:** Player lifecycle, team/challenge/competition UX, booking, referrals, owner trust, retention measurement.  
**Status:** Source-level product/UX audit COMPLETE; runtime usability, hosted analytics and deployment verification NOT performed.

## Decision and evidence rules
- Preserve VSP identity and the charcoal/neutral design tokens already in code. Avoid adding screens simply to increase engagement.
- Separate **SOURCE PRESENT**, **PARTIAL/CONFLICT**, **DOCUMENTED ONLY**, **LIVE NOT VERIFIED**. A widget, backend migration, green unit test, or tracking hook is not evidence of real user retention.
- Only truthful server-authoritative scores, capacity, deadlines, reviews, prices and awards. No synthetic streaks, pressure notifications, decoy pricing, fabricated proof, or hidden charges.
- Owner monetization remains **venue-owner subscriptions, not per-booking commission**.
- This audit **does not** change Flutter, Supabase, Paymob, notifications, production, GitHub main or a released build. Audit IDs below are **findings, not newly counted original delivery tasks**.
- Existing phase: [Phase 10 behavioral UX](PHASE10_BEHAVIORAL_UX.md), [Phase 10 report](PHASE10_FINAL_REPORT.md), [Experiments](PHASE10_EXPERIMENTS.md). Deduplicate implementation work against those and the 633-task register.

## Executive summary
**Strengths:** booking and venue-details flow, team and challenge features, leaderboard, genuine achievements, share links, event definitions and privacy-conscious analytics contracts already exist in source.

**Principal weaknesses:** a cohesive post-match -> verified outcome -> progress -> next-match loop is not fully demonstrated in the inspected UI; the requested permanent challenge-consent code is only specified while the existing profile UI generates a one-hour invitation code; old 1v1 trophies remain in visible player/team profiles; Team Skills Cup is feature-gated; and live D1/D7/D30 retention is not measured.

**Evidence boundary:** This is not a device review, an end-to-end acceptance, a code-wide absence proof, a production Supabase audit, or proof of improved emotions/conversion. Where a feature was not found in the inspected screens, mark it **needs discovery or validation**, not conclusively absent everywhere.

## Nine principles — existing behavior and direction
| Principle | Current source evidence | Audit judgment | Focused change / guardrail | Success indicator |
| --- | --- | --- | --- | --- |
| Pain relief | Stadium discovery/details, bookings, statuses, payment/price flows | Source present; runtime pending | Fewer steps to trustworthy availability, transparent total and error recovery; don't alter server price authority | Qualified booking completion; time to booking; error/drop-off |
| Emotional experience | Result flow, team profile, booking success confetti, tournaments | Partial emotional loop | Earned post-match moment only after approved results; graceful handling of losses and disputed results | Post-match meaningful return and player-reported satisfaction |
| Belonging | Teams, roster, invites, match sharing, chat | Present, dependencies open | Reliable captain invitations and team coordination, no public private codes | First team join, second team-organized match |
| Achievement | Team badges, win streak and Team Skills history | Partial/provenance review | Show official badges from verified results; correct old 1v1 UI | Verified achievement views and opt-in sharing |
| Social proof | Stadium ratings, public team standings and profiles | Present but not live-validated | Show genuine counts/reviews and their freshness, honest zero-review state | Venue-view -> booking-start by trust condition |
| FOMO / scarcity | Registration/capacity and event dates | Conditional | Only accurate server-derived registration seats/deadlines; no fabricated timers | Eligible tournament joins; cancellation rate |
| Habit formation | Booking history, reminders, notifications, teams | Unproven | Helpful weekly play loop, rebooking, valid reminders by opt-in/frequency | Meaningful D7/D30 return, 30-day repeat participation |
| Progress | Team points/standings, head-to-head, history | Partial | Verified season/period comparison and progress; no fictitious levels | Returning teams with second/third matches |
| Advocacy/referrals | Match/team/championship sharing/deep links | Share function present, attribution unverified | Reduce invite acceptance friction and instrument qualified acceptances | Accepted invites / qualified invite opens |

## Confirmed source findings and prioritized backlog
**AUD-01 — P1 — Distinguish permanent challenge code from temporary membership invite.** Team profile shows an action labeled `Create temporary invite code (1 hour)` and binds it to `_generateMatchupInviteCode`. [action bar](../lib/features/player/widgets/team_profile/team_profile_action_bar.dart), [team profile](../lib/features/player/screens/team_profile_screen.dart). The user's desired **stable challenge-consent code until confirmed challenge** is [specified only](VSP_TEAM_CHALLENGE_CODE_CONSENT_SPEC.md), explicitly not deployed and distinct from `generate_team_invite_code`. **Acceptance:** separate labels/flows; captain-only visibility; 8-digit policy and throttling; code unchanged on view/share/reject, rotated atomically on one confirmed match; 2 real staging accounts, concurrency and stale-code tests. **No silent code permission.**

**AUD-02 — P1 — Finish legacy 1v1 presentation transition.** Visible legacy widgets exist in [player profile](../lib/features/player/screens/profile_screen.dart), [team profile](../lib/features/player/screens/team_profile_screen.dart), [Team Skills history](../lib/features/player/widgets/champion/team_skills_history_section.dart). **Acceptance:** new Team Skills results/badges appear only from approved official data, no old 1v1 award advertised as a current tournament; preserve/resolve historical data and paid legacy dependencies before removal. See [legacy inventory](VSP_LEGACY_1V1_AND_CHALLENGE_RESULT_INVENTORY.md).

**AUD-03 — P1 — Verify Team Skills Cup runtime readiness.** [tab](../lib/features/player/widgets/champion/team_skills_cup_tab.dart) is conditional on `AppEnv.teamSkillsCupEnabled`; [env](../lib/core/config/app_env.dart) defaults to false and restricts by Supabase project. **Acceptance:** do not switch on broadly until staging registration, admin publication, scores, role separation, rankings, medals and real client view succeed; ensure disabled state describes preparation accurately.

**AUD-04 — P1 — Close team/match journey dependencies.** [Phase 10](PHASE10_BEHAVIORAL_UX.md) explicitly calls out team invite acceptance and challenge-flow mismatch; [invitation staging evidence](VSP_TEAM_INVITES_AND_VERIFIED_CHALLENGE_NOTICES_2026-11-17.md) is scoped to in-app SQL/staging, not device push. **Acceptance:** complete user-to-user staging match invite, consent/accept/reject, appropriate notice and safe account switch. Do not count SQL trigger presence as user delivery.

**AUD-05 — P1 — Post-match -> approved result -> team progress -> next action.** [Player home](../lib/features/player/screens/player_home_screen.dart) has post-match challenge result handling; [team profile](../lib/features/player/screens/team_profile_screen.dart) has head-to-head and achievements, but source inspection doesn't establish one clear player-facing post-match next-action journey. **Acceptance:** for one genuine confirmed challenge, player can see result status, eventual approved result, exact progress delta and suitable next match/challenge CTA; disputes/pending/cancelled matches cannot produce winner celebration or stats.

**AUD-06 — P1 — Review badge authority and source consistency.** [Achievements widget](../lib/features/player/widgets/team_profile/team_profile_achievements_section.dart) accepts optional `verifiedSummary`, but current [team profile](../lib/features/player/screens/team_profile_screen.dart) passes only the `team` object, while general unlocked badges depend on `team.unlockedBadges`. **Acceptance:** trace how badges are earned/verified for every visible claim; provide verified summaries where appropriate; stale/loading/dispute cases must not imply authoritative wins. Preserve genuinely earned historical badges.

**AUD-07 — P1 — Establish privacy-safe, real retention baseline.** [Analytics service](../lib/core/services/analytics_service.dart), [active-return contract](../lib/core/services/retention_event_contract.dart), [cohort logic](../lib/core/services/retention_cohort_contract.dart), [local analytics report](VSP_ANALYTICS_FUNNEL_LOCAL_DASHBOARD_2026-11-17.md) exist. Live Firebase export, consented cohort verification and D1/D7/D30 rates remain unverified. **Acceptance:** real authorized event capture, consent/delete semantics, privacy threshold/small-group suppression, account/role identity reconciliation, dashboard comparison, meaningful D7/D30 (not app opens), no invented uplift.

**AUD-08 — P2 — Offer easy repeat booking without stale price/availability.** [Booking history card](../lib/features/player/widgets/user_bookings/player_booking_card.dart) shows share, chat, cancel, match status; a direct repeat-booking control is not visible in the inspected card. **Acceptance:** 5-player usability exercise to confirm demand; if useful, preselect past venue/preferences but always fetch fresh slots, price, deposit and policy; new booking requires explicit confirmation, never duplicate charge; no extra standalone page required.

**AUD-09 — P2 — Measure referrals rather than share taps alone.** [SharingService](../lib/core/services/sharing_service.dart) generates match/team/tournament links, and booking success supports WhatsApp sharing. **Acceptance:** test deep-link -> authenticated/unauthenticated handling -> consented join, dedupe inviter attribution without exposing identifiers, measure accepted participants rather than sheet opens. Don't auto-enroll.

**AUD-10 — P2 — Create verified progress summaries in existing team cards.** [Standings](../lib/features/player/widgets/champion/teams_ranking_tab.dart) sort by points; [team profile](../lib/features/player/screens/team_profile_screen.dart) shows verified/pending results and history. **Acceptance:** compact last 5 verified match outcomes and rank changes for the same eligible ruleset, clear pending state, no invented ELO or cross-competition ranking. Reuse current components.

**AUD-11 — P2 — Respectfully use notifications and real scarcity.** [notifications center](../lib/features/player/screens/notifications_center_screen.dart) exists; [local reminder cap](VSP_LOCAL_REMINDER_FREQUENCY_54_05_2026-11-17.md) covers local 3-per-day constraints but not verified cross-device FCM. **Acceptance:** transactional vs marketing consent separated, cancellations stop obsolete reminders, true deadlines/seat numbers, verified device receipt and opt-out, no engagement-only pressure.

**AUD-12 — P2 — Maintain visual consistency and owner confidence.** Current [token code](../lib/core/ui/tokens/vsp_design_tokens.dart) aliases `voltGreen` to neutral `zinc400` and `glassGlow` to charcoal, while [design prose](../DESIGN.md) still says Volt Green. **Acceptance:** update prose/evidence after audit; do not reintroduce neon. Owner value is reliable schedule, controls, subscription transparency and reporting—not sports gamification. Do not add commission.

**AUD-13 — P2 — Usability testing before new screens.** Test the real booking, invite, match, results and repeat loop with representative player and captain accounts; test owner separately. Record error/hesitation, comprehension, no-show cases and perception of emotional value. **Acceptance:** evidence log with problem severity, screen/path and proposed minimal fix; avoid untested UX success claims.

## Implementation order (not a delivery commitment)
1. **Gate A — Trust/reliability:** verify booking price/status/staging regressions, invitations, legacy 1v1 compatibility and cup release gates. Avoid UI changes that obscure failure states.
2. **Batch B — Core play loop:** refine *existing* team and bookings UI (AUD-01, AUD-04, AUD-05, AUD-08) using server-authoritative state. Do not create unneeded tabs.
3. **Batch C — Outcome and identity:** official achievements, progress, Team Skills gating (AUD-02, AUD-03, AUD-06, AUD-10).
4. **Batch D — Evidence and growth:** real funnels/cohorts, opt-in notifications, invitation conversion and user testing (AUD-07, AUD-09, AUD-11, AUD-13).
5. **Cross-cutting:** responsive/RTL/accessibility, neutral tokens, owner operations and performance are release checks in every batch.

## Acceptance journeys to test on staging/device
| Journey | Positive outcome | Critical negative case |
| --- | --- | --- |
| Venue discovery -> booking -> sharing | One verified booking, correct receipt and invite link | Concurrent slot/price change must be rejected or requoted |
| Captain creates/invites team | Member explicitly accepts and sees correct team | Wrong user, expired invite and account switching denied |
| Captain issues challenge code | One confirmed match rotates code exactly once | Rejection/pending/replay cannot rotate or accept |
| Match ends -> result -> achievements | Approved score updates standings and earned badges | Disputed/unauthorized/pending scores cannot produce awards |
| Returning player -> next match | Returning to a real upcoming game or a deliberate repeat booking | No duplicate payment, no fake slots, no unsolicited re-engagement |

## Measurement plan
- **Activation:** first successful confirmed booking, actual match join or team creation; not registration alone.
- **Reliability:** confirmed bookings, paid/failed state agreement, duplicate booking prevention, time to successful booking, rate of real invite acceptance.
- **Emotion/value:** post-match opt-in survey ("Was this a useful and enjoyable experience?"), qualitative interviews, share of users who view genuine progress.
- **Retention:** consented D1/D7/D30 meaningful active return by player/owner role and first-value cohort; weekly team re-participation; repeat booking 30d.
- **Referrals:** qualified invites accepted / valid invitation opens (privacy-safe aggregate), not raw copied links.
- **Experiment guardrails:** explicit hypothesis, sample, stopping rules, accessibility and no negative impact on core booking. Do not claim lifts until measured.

## Handoff and task-accounting boundary
- Current [task counter](VSP_CURRENT_TASK_COUNTER.md) at audit time: **633 unique originals / 328 accepted / 305 open** (18 Nov 2026); this AUD list is a *deduplication and triage sheet*, not 13 new original tasks. **Count unchanged**; nothing accepted by this audit alone.
- Existing Phase 10 tasks and original issue IDs take precedence. Verify overlap before planning work. Current-head CI and real staging gates are still required for closure.
- **Changes made by this audit:** documentation only on working branch; no code, Supabase database, payment, admin deployment or main merge.
