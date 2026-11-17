# VSP — Booking availability audit and truthful owner-finance indicators

**18 November 2026** · Branch `uxlp-44-implementation` only · no production, no main merge.

**Exact tested source SHA:** [2a8811b](https://github.com/mohamedsalh333555/VSP.App/commit/2a8811b5112e1da03d1d72d593b4efc8b8a0f1b6).

**Passing focused CI for that SHA:**
- [VSP Booking Availability Accuracy — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44195557335): Flutter Analyze, simulated booking overlaps, pending holds, cancelled/expired releases, wrong/normalized venue identifiers, stale selection eviction, source availability state assertions, stream/date checks, Cairo DST skipped slot, server operating-hour precedence and split-shift failures.
- [VSP Owner Reporting and Booking Filters — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44195557149): Flutter Analyze, widget checks for verified-versus-pending owner money, failed-refresh nonzero masking, all-venues and custom reporting boundaries, owner booking time/venue filters.
- Earlier [booking truth and synthetic scarcity test suite — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44183845285) covered booking receipt statuses and hardcoded scarcity checks. Its findings are only additive evidence; tests in the two runs above cover the new source SHA.

## Narrow acceptance

### 53.01 — Audit correctness of displayed availability (client/offline)

- Verified a 60-minute confirmed booking blocks both overlapping half-hour slots but does not block earlier/later adjacent slots. Pending holds remain unavailable. Cancelled and expired booking locks are excluded. A booking from another venue cannot block the selected pitch.
- Fixed a source inconsistency: booking and selected-stadium identifiers are now normalized for whitespace/case before overlap checks, matching the owner schedule's normalized IDs. This prevents a booked slot appearing available from differently formatted identifiers.
- Confirmed UI waits for a fresh stream snapshot on account/date changes, shows explicit error state on stream failure/missing data, distinguishes closed/past/fully booked/unavailable schedule states and never uses fabricated urgency copy. Selection is invalidated when a fresh booking conflicts.
- This passes **source and synthetic client-audit acceptance only**. Real-time server data, RLS and double-booking prevention remain governed by backend transaction and live two-account staging tests; no claim of end-to-end booking availability accuracy under load.

### 03.05 — Prevent misleading state/financial indicators (scoped critical surfaces)

- `OwnerOperationalFinanceCard` now explicitly receives `revenueVerified` and `revenueLoading`. Until the current selected owner/venue/date analytics RPC finishes successfully, the card masks total, cash, online, uncollected, held and upcoming values rather than showing fake zeros or values from a previously loaded filter. Withdrawal balance remains independently gated by its own verified financial-summary RPC.
- `OwnerDashboardScreen` sends the current analytics verification flag into both the owner finance card and Pro Insights, including on a refresh, court switch, date switch or network failure. Pro Insights now shows loading/error instead of presenting the previous query as the newly selected period.
- Dedicated English widget tests verify unavailable and loading financial states for both Pro and Free, redacted old financial amounts and legitimate ledger/balance messaging. Prior booking receipt, no-fabricated-scarcity, and server-plan-claim tests support critical high-risk surfaces.
- This is **scoped code-level prevention** in high-risk booking, pricing and owner-finance UI, not a guarantee that *all* screens, staging behavior, or real hosted financial numbers are correct. Tasks 03.02/03.06/03.07 and owner finance source-parity task 24.05 remain open.

## Accounting and limitations

Two **pre-existing** IDs accepted narrowly; no new task IDs. New verified status **633 unique / 294 accepted / 339 open (46.45%)**. Payment reconciliation, 24.05, booking concurrency, RLS tests, 53.06 real-message test and real Android acceptance remain open. No Supabase writes, money transfer, real Paymob transaction, production deployment, APK publication or `main` merge.
