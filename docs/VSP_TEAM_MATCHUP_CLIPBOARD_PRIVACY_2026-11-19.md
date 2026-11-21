# Team matchup invite clipboard failure and revocation hardening — 19 Nov 2026

Branch: `uxlp-44-implementation` / Draft PR #35. Task IDs: 82.03 client-side partial evidence, NOT accepted.

Changes:
- Clipboard failure is caught and a localized Arabic/English retry error appears without exposing platform details or closing a valid captain's sheet.
- After an asynchronous clipboard call returns, the modal checks captain/team/account authorization a second time. It never shows a success toast to a switched account or removed captain.
- Widget regressions cover rejected clipboard calls and a pending clipboard call concurrent with captain revocation; pre-existing tests cover revocation before copying and open-sheet account changes.
- No changes to Supabase RPCs, persistent eight-digit challenge-consent codes, team results, bookings, payments, Home, production, or historical legacy data.

Acceptance remains OPEN until the relevant Flutter tests pass and the separate eight-digit stable consent-code lifecycle and real two-account staging access checks are verified. The legacy one-hour matchup invitation RPC is NOT the new stable team challenge-consent code; do not mark 82.02–82.09 complete based on this client fix.

Counter unchanged: 640 total / 343 accepted / 297 remaining.
