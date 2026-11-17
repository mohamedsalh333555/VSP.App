# VSP — Additional protection against small-group inference in retention reports

**18 November 2026 · `uxlp-44-implementation` · PR #35 draft**

**Verified source SHA:** [cc2e4f0](https://github.com/mohamedsalh333555/VSP.App/commit/cc2e4f0b00ecef590f9e60c743e2fab9ec440231).
**Focused CI:** [VSP Offline Activation Analytics Contracts — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44188773549), including Flutter Analyze, cohort/funnel Dart tests and the isolated Node-based local dashboard checks.

## Privacy regression and fix

The earlier aggregate exporter suppressed groups with 1–4 active members, but a report could still show a cohort of 10 accounts alongside `eligibleD1 = 6`. Subtraction reveals **four not-yet-eligible members**, despite a minimum reporting cell size of five. Likewise, successive `eligibleD1 = 20` and `eligibleD7 = 16` reveal a small ineligible subgroup.

Changes:

1. `VSPRetentionCohortSegment.toPrivacySafeJson()` now masks an eligible-day count whenever its difference from the previously visible cohort/eligibility count is in 1–4. Later eligible-day columns remain masked once an earlier comparison is suppressed. Active/inactive complementary suppression remains in effect.
2. The pure export helper refuses direct serialization of segments with fewer than five accounts, inconsistent D1/D7/D30 denominators, or an unrecognized role/first-value event. Input account identifiers are never serialized.
3. `scripts/vsp_activation_dashboard.html` separately rejects an imported aggregate that would reveal a small eligible subgroup, or that exposes a later eligible count after an earlier suppressed stage. The viewer remains local/offline and does not make network calls.
4. Flutter and Node tests cover both above subtraction examples, forged small cohorts, invalid monotonically ordered eligibility and safe rows.

## Explicit limits

This is **not** differential privacy, not an authorization-reviewed Firebase production export and not proof against all statistical differencing attacks across multiple reports, date windows or repeated queries. A future live dashboard must implement access control, query budgets, cohort-release policy, consent withdrawal handling and a separate privacy review. No real account records or event streams were loaded.

This is a **follow-up privacy correction** for already documented 54.02 / 55.04 and the still-open 50.04/50.05/54.06/55.06. **No previously open task was accepted on this change alone**. Current total stays **633 / 289 accepted / 344 open (45.66%)**. No database, FCM, Paymob, production deployment, APK or `main` merge.
