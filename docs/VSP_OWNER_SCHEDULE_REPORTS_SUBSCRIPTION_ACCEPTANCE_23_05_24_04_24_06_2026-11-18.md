# VSP — Owner booking filters, subscription status and reporting periods

**18 November 2026 (Cairo)** · Branch `uxlp-44-implementation` · Target PR #35.

**Exact tested code SHA:** [4f4a271](https://github.com/mohamedsalh333555/VSP.App/commit/4f4a271591c81f1dea7eff33dd1a22c2b70b222a).

**Passing focused CI:**
- [VSP Owner Reporting and Booking Filters — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44194293882) — Flutter Analyze, owner booking operational-day filtering and owner finance/calendar window tests.
- [VSP Owner Plans and Funnel Contracts — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44194294060) — Flutter Analyze, localized paid/Free/trial/expired status and existing upgrade/Paymob/analytics contracts.

## Narrow acceptance of three existing open IDs

### 23.05 — Filter owner bookings (UI/contract only)

- `OwnerBookingScheduleFilter.select` filters the already authenticated owner's booking feed by selected stadium ID (case/whitespace normalized), selected operational day and non-cancelled status.
- Bookings after midnight remain assigned to the actual venue's previous shift when that is the recorded or calculated operational date.
- Empty stadium IDs and invalid opening-hour configuration fail closed rather than displaying every booking.
- `OwnerBookingsScreen` uses the shared helper after role gating and booking-load checks. Automated tests simulate separate venues, cancelled rows, different dates, overnight shifts and server-stored operational dates.
- **Not proven:** server-side RLS and data isolation across two authenticated owners, owner-initiated status transitions, staging calendar parity or a physical Android UI trial. Existing 23.07/23.08/79.xx remain open.

### 24.04 — Display current owner plan status (UI/contract only)

- `OwnerSubscriptionStatusPresentation` distinguishes **paid Pro**, **active trial**, **Free**, **trial expired**, **paid Pro expired** and **unavailable/unknown**. Exact expiry boundaries and non-owner roles have dedicated tests.
- `OwnerDashboardHeader` renders the resulting Arabic/English label rather than treating `isProPlan` (which includes trial access) as a paid Pro subscription.
- Removed the unsupported hard-coded **1000 EGP** amount, stale pricing claims and unverified 24/7 entitlement promises from the Copilot upsell. The user opens the existing subscription screen, which loads pricing and features from `public_subscription_plans`.
- **Not proven:** live subscription renewal or active backend enforcement for a trial/paid owner. The status is explicitly display-only, and it does not grant privileges or activate payments.

### 24.06 — Test report period filters (local/client contract only)

- The dashboard previously returned **all bookings** for `custom` local finance summaries and for `year`; those branches now honor the selected inclusive-start/exclusive-end period and calendar-year bounds.
- `OwnerFinancialCalculator` is supplied the same `DashboardFilter` selected for the server analytics request, including the explicit court selection. A custom period with no verified bounds fails closed rather than being interpreted as all time.
- `DashboardFilter.copyWith(clearCourtId: true)` fixes changing from one pitch back to **All venues**, which otherwise retained the old court ID in server queries while displaying the all-venues label.
- Calendar-day end bounds are constructed as civil dates, not elapsed 24-hour intervals across DST. Owner dashboard cache keys include date/court filter and booking date, stadium, payment state and amount to prevent stale summaries after changes.
- Automated tests cover custom inclusive dates, excluded outside dates, cancelled bookings, court reset, day/year/month/week aliases, UTC-serialized operational days, no-bound fail-closed behavior and date-window construction.
- **Not proven:** parity against hosted analytics RPC on two independent real owners, Supabase actuals/revenue reconciliation, timezone behavior on a real Egypt-configured device, large-data performance or final release acceptance. 24.05 and relevant P0 finance/RLS tasks remain open.

## Accounting and safeguards

Three pre-existing IDs accepted **narrowly** after passing the above CI: **633 unique tasks / 292 accepted / 341 open (46.13%)**. No new task IDs. No DB migration, payment transfer, Paymob Sandbox operation, production deployment, APK publication or `main` merge.
