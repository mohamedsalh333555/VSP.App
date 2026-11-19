# VSP — Source implementation batch: activation funnels and local dashboard

**Date:** 2026-11-17. **Branch:** `uxlp-44-implementation`. **PR:** #35 (Draft).

## Why this batch

The existing `docs/CONVERSION_ANALYTICS.md` documents event triggers and privacy constraints but does not offer an auditable, distinct-account activation funnel. The checked 55.04 privacy item also had two **legacy event wrappers** that forwarded team/venue identifiers and price to Firebase, contrary to the stated contract. This is a verified source discrepancy, **not evidence that any real identifier was delivered**; hosted telemetry has not been inspected.

## Implemented in source

1. **Privacy regression fix (55.04 follow-up, no new acceptance):**
   - `AnalyticsService.privacySafeParameters` now only accepts explicitly allowed categorical properties (`role`, `plan_code`, `payment_method`, `sport_type`, `type`, `message_type`) and bounded integer rank values; arbitrary fields and free text are discarded.
   - The existing `stadium_booked` and `challenge_sent` event names remain in use, but their legacy wrappers no longer send venue identifiers, team identifiers or price. Signatures remain unchanged for callers. This narrows analytics dimensions and should be reviewed against existing dashboard expectations.
   - Regression tests cover raw IDs, arbitrary properties and values disguised as categories.

2. **50.04 — offline, privacy-preserving funnel computation (implementation pending verification):**
   - `VSPActivationFunnels.build` computes unique-account, ordered transitions for `player_booking`, `player_match`, `owner_activation` and `owner_subscription`.
   - Input must be consented, authenticated, role-scoped, have a stable account key, and fall before the supplied UTC observation cutoff. Only the ordered, already-defined events count. An owner checkout cannot be treated as a confirmed paid subscription.
   - Individual account keys remain in memory solely for deduplication; `VSPFunnelReport.toJson()` exports **aggregate fields only**. A first-stage group below five accounts returns no report. Intermediate groups and drop-offs of 1–4 are suppressed rather than misreported as zero.
   - The **offline HTML viewer** at `scripts/vsp_activation_dashboard.html` accepts locally selected aggregate JSON and renders funnels without using network requests or storing identifiers. It is deliberately outside the publicly served `web/` tree.

3. **50.05 — chronological dropout calculation (implementation pending verification):**
   - Stage-to-stage drop-off is calculated from distinct accounts that actually progressed in order. Small deltas and the associated percentage are suppressed. The report does not claim causal explanation for drop-off.

4. **54.06 and 55.06 — prepared display, NOT accepted:**
   - The local HTML can display already aggregated D1/D7/D30 cohort metrics. It does **not** run or export a live Firebase retention query, reconcile reporting windows/consent withdrawal, or validate an authenticated analytics console. No retention percentages or conversion uplift are claimed.

## How to inspect

1. Run `flutter test test/core/services/analytics_service_test.dart test/core/services/activation_funnel_contract_test.dart` and `flutter analyze` on the development branch. Full CI must pass before counting any source-level acceptance.
2. Provide a **consented, authorization-approved, aggregated-only** `VSPFunnelReport.toJson()` output as JSON; open `scripts/vsp_activation_dashboard.html` from the local working copy and select that file. The viewer never fetches customer records.
3. Confirm role, UTC cutoff, stage sequence, small-group suppression and that there are no account IDs or detailed event timelines in the export.
4. For production-grade 50.04/50.05/54.06/55.06 acceptance: integrate a permissioned source, verify consent revocation/exclusion, review aggregate disclosure risk, compare to the provider console, and perform D1/D7/D30 validation on a lawful complete dataset.

## Safety and accounting

No external system, database, Paymob workflow, production setting, public site, or main branch was modified. No APK or merge. The live task counter at the start of this batch was **633 total / 279 accepted / 354 open**. Source additions are *implemented pending verification*; do not decrement the outstanding count without linked passing CI and scoped acceptance. Neither synthetic metrics nor source inspection count as live proof.

## Continuation — source privacy regression and runnable viewer checks

- **Complementary disclosure corrected:** showing consecutive funnel stage counts of 10 and 6 indirectly revealed a suppressed four-account drop-off. `VSPActivationFunnels.build` now masks the count and every downstream stage after a small/suppressed transition, not just the separate exit column. `toJson()` exports the masked result.
- The offline HTML importer independently rejects a leaked 10→6 count difference, an exposed stage after a suppressed one, invalid cross-stage arithmetic, and unsafe cohort combinations. It never uses network APIs or external scripts.
- `VSPRetentionCohortSegment.toPrivacySafeJson()` now provides a restricted D1/D7/D30 export. Small active, eligible, or complementary inactive counts are masked. Use this method rather than serializing the segment fields directly.
- Added seven Node-based HTML viewer regression scenarios (valid and invalid imports, small groups, masks, corrupted/oversized JSON), plus Dart regression scenarios for account counts, cohort suppression and export privacy.
- `.github/workflows/activation-analytics-contracts.yml` includes an offline Node test job and a scoped Flutter source/test gate. These are evidence for implementation correctness, **not live cohort validity**.

**Boundary:** no production identities, actual first-value cohorts, consent-withdrawal history, Firebase export, dashboard publication, conversion change or cross-cohort re-identification audit was performed. Do not publish this viewer as a production analytics dashboard or count 50.04/50.05/54.06/55.06 complete without their full acceptance evidence. The latest confirmed counter at the beginning of this continuation was **280 accepted / 353 open of 633**, unchanged by these source-only changes.
