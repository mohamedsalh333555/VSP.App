# VSP — Master Remediation Task / Product Integrity Lock

Status: active remediation
Scope: Flutter app + Supabase production + GitHub main
Rule: Do not close this task because CI is green. Every item requires source/runtime/server evidence.

## Product terminology — immutable

User-facing subscription names:
- مجاني
- Pro

Never expose:
- Basic
- Basic Plan
- الباقة الأساسية
- الباقة المجانية
- free_trial as UI copy

Internal compatibility identifiers such as `basic` may remain only where removing them would break backend compatibility. They must never leak into user-facing UI.

## Commercial model

### مجاني
Must be a genuinely useful product:
- one stadium
- stadium operation
- bookings
- cash payments
- online payments
- tournaments
- core owner management

Do NOT block normal operation merely to force upgrade.

### Pro
Solves the owner's financial visibility/control problem:
- cash not collected
- online not collected
- held online funds
- collection intelligence
- advanced analytics
- reports
- Copilot
- expanded operating capabilities / additional stadiums

The Free user should feel: "the product works."
The Pro user should feel: "Pro solves the money/operations problems that appear when my business grows."

### Owner dashboard finance — Pro
The paid owner home must have a visually obvious finance area with at least:
1. Cash collected
2. Cash not collected
3. Online collected
4. Online not collected
5. Online collected but held / unavailable for withdrawal
6. Withdrawable balance

Free must retain basic operational/collected visibility, while uncollected-money intelligence and collection intelligence are Pro. Do not turn the dashboard into repeated lock/upgrade ads.

## P0 — server authority

### Booking operating-hours enforcement
Server must reject any booking mutation when:
- booking starts before opening
- booking ends after closing
- booking overlaps split-shift break
- booking overlaps maintenance closure

Apply consistently to:
- create_booking_atomic
- challenge booking RPC
- reschedule
- owner/manual booking
- every server mutation that changes start_time/end_time

Validation must support overnight schedules such as 15:00 → 02:00.

## Deposit
The cash-deposit bypass has already been fixed in production by migration 20261005234540 / enforce_cash_booking_deposit_ssot.
Do not duplicate or regress this fix.
Server remains authoritative:
needs_deposit=true + deposit_amount>0 + cash => reject unless the required online deposit is actually satisfied.

## Bottom Navigation — exact visual rule

Selected:
- actual Iconsax Bold glyph
- Accent color
- slightly larger
- Bold label

Unselected:
- actual Iconsax Outline glyph
- Secondary color
- slightly smaller
- Regular label

Changing only icon size is NOT sufficient. Runtime screenshot must prove Bold vs Outline glyphs.

There must be one geometry source:
- VSPBottomNavMetrics

Remove/retire duplicate geometry sources such as VSPBottomNavBarMetrics vs VSPDSBottomNavMetrics.
FAB clearance, bottom padding, scroll clearance and action-bar clearance must derive from the same source.

## Design System — one source of truth

Unify:
- vsp_tokens.dart
- vsp_design_tokens.dart
- VSPColors / VSPDSSemanticColors
- VSPSpacing / VSPDSSpacing

No duplicate token meanings with different values.

Create canonical shared components:
- primary button
- secondary button
- tertiary button
- destructive button
- segmented control
- filter control
- bottom action bar
- owner finance card

Remove/retire parallel implementations after usages are migrated.

## Layout / visual QA

Fix:
- BookingConfirmationScreen fixed bottom padding 140px
- StadiumCard fixed heights that can clip dynamic content
- StadiumCard amenities Row → Wrap/flexible layout
- TeamCardHero fixed-height/28px/900/letter-spacing overflow risk
- owner tournament FAB/nav occlusion
- any bottom action bar/nav overlap
- any clipping/overflow at narrow widths
- Arabic long text
- enlarged text accessibility

Use shared safe-area / bottom-action clearance instead of magic numbers.

## Owner finance component cleanup

Retire duplicate parallel implementations:
- OwnerBasicFinancialGlance
- OwnerProOverviewCard
- OwnerOperationalFinanceCard

One canonical finance surface; entitlement changes the content, not the underlying financial truth.

Financial concepts must never be conflated:
- booking_value
- collected
- cash_uncollected
- online_collected
- online_pending/uncollected
- online_held
- withdrawable_balance

Server is the financial SSOT. Client must not independently redefine financial truth.

## Booking / payment realism

Fix and verify:
- payment method UI cannot promise a path the server rejects
- disabled/unavailable payment methods must have true disabled affordance
- deposit state is server-authoritative
- cash/online payment status names are consistent
- collected != booked gross value
- held != withdrawable

## Error / loading / empty state contract

Every data section must have distinct:
- Loading
- Success + non-empty
- Success + empty
- Error

Never:
- server error → empty state
- stream error → SizedBox.shrink()
- raw exception → user UI

Replace:
- "Failed to fetch stadiums: <exception>"
- "Error: <snapshot.error>"

with localized, user-safe messages + retry where appropriate.

## Stadiums / amenities

One canonical amenity schema.
No parallel interpretation of:
- shower
- changing room
- garage
- parking
- seats
- cafe

Server filtering must happen before pagination.
Do not paginate first and then filter amenities client-side.

## Filters

Multi-select must remain multi-select end-to-end:
- Football + Padel
- 5v5 + 7v7

Never send only `first`.

Reset must clear ALL filter state including quick filters:
- night_shift
- no_deposit
- every future quick filter

Active filter count must include quick filters.

One FilterState should own:
- selected sports
- sizes
- amenities
- quick filter
- all other filters

## Analytics

One date semantics / SSOT.
Do not mix:
- server start_time
- client operationalDate
- local conversions

Define operational date explicitly and use it everywhere.

Do not count Team as Challenge.

Maintenance closures must not inflate:
- capacity
- occupancy denominator
- availability
- demand metrics
- financial metrics
unless explicitly intended by a named business rule.

Do not cache owner metrics using only the first 50 bookings.

Revenue labels must be semantically correct:
- Booking Value / Gross Booked
- Collected
- Pending / Uncollected
- Held
- Withdrawable

## Navigation / root state

- Update SCREENS_MAP.md to actual navigation.
- Remove dead loading-timeout state or make it real behavior.
- Prevent Player/Owner shell flicker before user model is loaded.
- Maintenance screen must be fully localized.

## Premium UX

Avoid repeated premium gates for the same capability.
For a Pro feature:
Feature/context → concise explanation → one clear upgrade CTA.

Do not simultaneously show:
- lock icon
- upgrade teaser
- repeated modal
- header premium marketing

unless each has a distinct purpose.

Owner Copilot marketing claims must match actual server-side tools and capabilities exactly.
No fake player Copilot; Copilot is Owner-only.

## Visual Regression / QA

CI success is not visual success.

Add runtime/golden coverage for:
- 320 / 360 / 390 / 412 px widths
- Arabic / English
- normal / enlarged text
- Free / Pro
- player / owner

Priority screens:
- bottom navigation
- owner home
- owner finance
- bookings
- booking confirmation
- filters
- stadium cards
- tournaments
- team cards
- auth
- bottom action bars / FABs

Explicitly verify:
- Bold vs Outline glyphs
- no clipping
- no occlusion
- no hidden last content
- no accidental empty states
- no raw exceptions
- no Basic wording
- finance hierarchy
- correct selected/unselected states

## Backend security/performance

Review intentionally:
- SECURITY DEFINER functions callable by authenticated
- permissive RLS policy overlaps
- auth.<function>() init-plan warnings
- leaked-password protection
- duplicate indexes

Do not classify every advisor warning as an exploit automatically. Each sensitive RPC must have explicit authorization ownership and a documented intended caller.

## Source / production drift

Production migrations must be reproducible from GitHub main.
Every production migration applied manually must also exist under:
supabase/migrations/

Never close this task while:
production schema != main migration history.

## Current verified remediation
### Operating-window migration provenance clarification — 2026-10-31

The live `supabase_migrations.schema_migrations` history confirms these exact applied versions:
- `20261006005321` — `20261006010000_enforce_booking_operating_hours_and_breaks` (the migration's display/name label differs from its version timestamp)
- `20261006005714` — `enforce_booking_operating_window_all_mutations`
- `20261006005740` — `harden_operating_window_function_and_remove_duplicate_audit_indexes`

The matching SQL files exist under `supabase/migrations/` on this branch. Read-only inspection of `public.bookings` triggers confirms `trg_bookings_operating_window` fires BEFORE INSERT and BEFORE UPDATE OF `start_time,end_time`; it calls `vsp_enforce_booking_operating_window`, which calls the shared Cairo-local validator. This covers RPCs/direct mutations that actually insert a booking or change its time fields, including manual booking and reschedule updates, without relying on each client path to repeat the rule. Maintenance rows are intentionally excluded because they represent closures rather than customer bookings.

This is source/schema evidence, not a replacement for the final mutation matrix/runtime pass. No SQL was applied during this review.


Production migration applied:
20261006010000_enforce_booking_operating_hours_and_breaks

Verified:
- outside operating hours → OUTSIDE_OPERATING_HOURS
- normal operating interval → allowed by validator
- overnight operating interval → supported
- break overlap → rejected
- maintenance overlap → rejected

GitHub main migration file created with the same migration:
supabase/migrations/20261006010000_enforce_booking_operating_hours_and_breaks.sql

## Definition of done

This task is NOT complete until:
1. P0 server booking rules are enforced across every booking mutation.
2. Free/Pro entitlement and UI are consistent.
3. Basic is absent from all user-facing surfaces.
4. Owner finance hierarchy matches the commercial model.
5. Bottom nav Bold/Outline is proven in runtime.
6. Design system has one source of truth.
7. Shared buttons/segmented/filter/action-bar components are canonical.
8. Error/empty/loading states are distinct.
9. Filters are truthful end-to-end.
10. Analytics uses one server-authoritative semantic model.
11. Layouts pass narrow Arabic/English/enlarged-text checks.
12. Security/RLS advisor findings are intentionally reviewed.
13. GitHub main can reproduce production schema.
14. Flutter analyze/tests/CI are green.
15. Visual runtime regression matrix passes.

Do not declare "done" based on CI alone.
## Latest source remediation — 2026-10-31

Source work continued on `uxlp-44-implementation`:

- Repaired the malformed booking-query coordinator tail and restored missing booking slot, location-picker, league, payment, and result-action code paths implicated by the previous analyzer log.
- Reworked stadium discovery so query failures are not converted into empty results; added localized error/retry behavior and preserved loaded results during refresh.
- Moved sports, pitch-size, amenities, quick filters, floor type, search, sorting, price and governorate filters ahead of database pagination, using the live `public.stadiums` schema.
- Removed first-page-dependent sport filter choices and included active quick filters in the filter count/reset behavior.
- Made owner withdrawal balance display fail closed when the server summary is missing or invalid.
- Consolidated bottom-navigation geometry naming and deprecated parallel finance widgets.
- Removed the 50-booking truncation from the owner metrics cache key and improved team hero text/layout resilience.

### Remaining gates (not yet complete)

1. Finish source review and explicit rule-to-screen mapping for every registered player/owner screen, embedded widget, popup, and state variant.
2. Complete Arabic/English copy and RTL/LTR review across all registered surfaces.
3. Review all remaining data queries against the live Supabase schema and verify that failures cannot masquerade as empty/zero states.
4. Resolve product/domain decisions documented in the audit before changing their behavior (including team authorization edge cases, multi-team selection semantics, notification retention, and refund notification reconciliation/outbox).
5. Complete safe-area, keyboard, compact-screen, large-text, modal, and real-device visual review.
6. Only after all source work and the above gates are closed, perform one consolidated test pass; then build and verify one test APK.

No final test pass or APK build was intentionally started as part of this source-remediation batch.


## Phase 10 — Behavioral UX, conversion and retention

Phase 10 is active and additive. Its task register, analytics contract, experiment gates and delivery status are maintained in:

- [PHASE10_BEHAVIORAL_UX.md](PHASE10_BEHAVIORAL_UX.md)
- [CONVERSION_ANALYTICS.md](CONVERSION_ANALYTICS.md)
- [PHASE10_EXPERIMENTS.md](PHASE10_EXPERIMENTS.md)
- [PHASE10_FINAL_REPORT.md](PHASE10_FINAL_REPORT.md)

No behavioral change may invent social proof, scarcity, pricing, discounts, verification, prizes or financial outcomes. Conversion events must represent authoritative stages and must not weaken the 24 journeys, Phase 8 security controls or Phase 9 reliability work.
