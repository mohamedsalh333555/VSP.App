# VSP — Retention role/first-value cohort segmentation (54.02)

Date 2026-11-17. Branch `uxlp-44-implementation`.

## Scope shipped in source

The new pure Dart `VSPRetentionCohorts.segment` groups analytics-consented authenticated accounts by **role (player/owner)**, earliest eligible **first confirmed value event** and **UTC day**. It deduplicates the same account within a role, regardless of repeated actions/devices, and computes only D1, D7 and D30 **matured** denominators and distinct active-return counts using the existing `54.01` meaningful-event contract. Future events and passive launches cannot inflate a return.

- Never returns a raw account key, token, event payload, payment amount or user timeline.
- Suppresses cohorts with **fewer than 5 unique eligible accounts**. This is an elementary safeguard, not a substitute for analytics governance or a complete re-identification review.
- Observation end is a supplied timestamp, not an inferred current date. UTC comparisons avoid Egypt DST boundary distortions.
- Different owner/player identities and event sets cannot mix; a role must never be invented from an event name.

## Verification

New `test/core/services/retention_cohort_contract_test.dart` covers six-account D1/D7/D30 dedup, owner/player split, anonymous and non-consented suppression, earliest-first-value regardless of input order, group-size suppression, future events and cross-offset UTC day boundaries. New source/tests are included in both push and PR scoped Flutter CI workflow paths.

**Acceptance limit:** Implements 54.02 as a **pure, privacy-preserving cohort segmentation algorithm only**, pending CI on the exact SHA. It does **not** deploy a live analytics pipeline, validate consent record retention, compute actual VSP customer cohorts or fulfill 54.06 live measurement. No Supabase schema or production changes; 54.03–54.08 stay open until separately validated.
