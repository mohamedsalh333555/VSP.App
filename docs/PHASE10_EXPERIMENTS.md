# Phase 10 Controlled Experiments

Status: **BASELINE INSTRUMENTED / NOT RUN** · 2026-11-09

VSP does not yet have a verified experiment-assignment framework or a statistically adequate, consented cohort in this execution environment. No A/B uplift is claimed. Functional and usability validation precede controlled rollout.

| Experiment | Hypothesis | Primary metric | Guardrails | Current decision |
|---|---|---|---|---|
| A — onboarding friction | Clearer value and fewer unnecessary early fields improve registration | `signup_completed / onboarding_started` | verification, age, role and privacy rules unchanged | baseline events wired; do not remove required identity fields without product/legal review |
| B — venue trust | Honest real venue data improves booking starts | `booking_started / venue_viewed` | no fake verification/reviews/scarcity; price/deposit shown | honest empty-rating state implemented; usability and runtime regression pending |
| C — owner value/pricing | Server-backed Free/Pro comparison improves qualified interest | checkout start / `subscription_viewed` | no decoy, fake discount, commission claim or guaranteed ROI | preserve live-plan rendering; activation event waits for authoritative payment |
| D — real remaining capacity | Clear server-derived capacity improves match joins | `match_joined / match_viewed` | never use cached/fake scarcity; privacy preserved | view/join events wired; capacity experiment deferred until journey 07/19 server acceptance |

## Requirements before A/B testing

- stable anonymous assignment that survives rebuilds without exposing PII;
- mutually exclusive variants and documented allocation;
- consent/privacy review;
- predeclared minimum sample, duration and stopping rule;
- no simultaneous change that contaminates the tested funnel;
- server-authoritative outcome events;
- rollback, accessibility and performance checks;
- analytics dashboard validation before reading results.

Until these exist, use task-based usability sessions and automated functional tests. Record observations as qualitative evidence, not conversion uplift.
