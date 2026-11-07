# Phase 10 Controlled Experiments

Status: **BASELINE DEFINED / NOT RUN** · 2026-11-05

VSP currently lacks a verified experiment-assignment framework and a statistically adequate, consented cohort in this execution environment. Therefore no A/B uplift is claimed. Functional/usability validation precedes controlled rollout.

| Experiment | Hypothesis | Primary metric | Guardrails | Current decision |
|---|---|---|---|---|
| A — onboarding friction | Clearer value and fewer mandatory early fields improve completed registration | `signup_completed / onboarding_started` | verification, age, role and privacy rules unchanged | Instrument baseline first; do not remove required identity fields without product/legal review |
| B — venue trust | Honest real venue data improves booking starts | `booking_started / venue_viewed` | no fake verification/reviews/scarcity; price/deposit shown | Implemented honest empty rating; usability + regression pending |
| C — owner value/pricing | Server-backed Free/Pro comparison improves qualified subscription interest | checkout start / `subscription_viewed` | no decoy, fake discount, commission claim or guaranteed ROI | Preserve current live-plan rendering; add activation only after authoritative payment |
| D — real remaining capacity | Clear server-derived capacity improves match joins | `match_joined / match_viewed` | never use cached/fake scarcity; privacy preserved | Deferred until match screen/server capacity contract and journey 07/19 blockers are resolved |

## Assignment requirements before A/B testing

- stable anonymous assignment that survives rebuilds without exposing PII;
- mutually exclusive variants and documented allocation;
- consent/privacy review;
- minimum sample and duration decided before reading outcomes;
- no simultaneous change that contaminates the tested funnel;
- server-authoritative outcome events;
- rollback and accessibility checks.

Until these exist, use task-based usability sessions and automated functional tests. Record observations as qualitative evidence, not conversion uplift.
