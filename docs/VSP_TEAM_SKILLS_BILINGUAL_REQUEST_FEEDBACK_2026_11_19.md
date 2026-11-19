# Team Skills Cup bilingual request lifecycle feedback — 19 November 2026

Branch: `uxlp-44-implementation`, PR #35 remains Draft.

The player-side Team Skills Cup request flow contained Arabic-only feedback for registration, waitlist, confirmed/ambiguous responses, roster edits and withdrawal, even in the English locale. Those are now centralized in `TeamSkillsRequestMessages` with 19 explicit Arabic/English messages. The withdrawal confirmation dialog also follows the active locale. Ambiguous network outcomes remain explicitly unconfirmed, **not** failed or auto-retried. No registration status logic, write calls, server authorization, booking, billing, prize eligibility, Home, historical 1v1 data or feature flag changed.

A dedicated test checks every enum case has nonempty genuine Arabic and English output and verifies that network-ambiguous registration/withdrawal wording never asserts a failed transaction. The focused Team Skills workflow analyzes and tests the new module and continues to run existing published-data and scoring regressions.

This is partial language coverage under 04.06 / 04.07; the whole-app localization and Android screen matrix remain OPEN. Counter stays **640 total / 343 accepted / 297 open** until acceptance requirements are satisfied. No production deployment or merge.
