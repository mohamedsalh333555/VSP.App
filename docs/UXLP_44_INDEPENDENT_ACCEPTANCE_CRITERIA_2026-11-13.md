# UXLP-44 — independent acceptance criteria for all 44 rules

**Date:** 2026-11-13. **Branch:** `uxlp-44-implementation`. **Scope:** task **01.07** only — write one independent, testable acceptance criterion for each of the 44 UXLP rules. This is **not** completion of the 44 UX rules, a screen-by-screen audit, device verification or source implementation.

Source of canonical names: [UXLP-44 VSP standard](UXLP_44_VSP_STANDARD.md). Register of applicable screens: [UXLP-44 screen inventory](UXLP_44_SCREEN_REGISTER.md); known source status: [UXLP-44 rule audit](UXLP_44_RULE_AUDIT.md).

## Required evidence template for every rule

Record the exact **screen/widget path**, **role** (player/owner/admin if applicable), **state** (loading/empty/error/stale/success), **locale** (Arabic RTL / English LTR), **device viewport** (320dp minimum, representative large display, keyboard/landscape if applicable), **observation or screenshot**, **automated test IDs**, **result** (pass/fail/not applicable), **risk and issue**, **commit SHA**, and **date**. Verify actual screen behavior and server authority where the rule concerns business/security data. Historical source reviews are not runtime passes.

## Rule-by-rule acceptance matrix

| # | Rule | Independent acceptance criterion — must be demonstrated in each applicable flow | Evidence status |
|---:|---|---|---|
| 1 | Clear hierarchy | Every audited screen has one dominant task/header; first screen-reader heading precedes secondary actions. | **Pending per-screen/runtime verification** |
| 2 | Consistent grouping | Inputs and actions sharing a decision have one bounded section; unrelated data is visibly separated at 320dp. | **Pending per-screen/runtime verification** |
| 3 | Contrast first | Selected/disabled/error/help text and icons remain distinguishable on their actual charcoal backgrounds at both language settings. | **Pending per-screen/runtime verification** |
| 4 | Typography roles | Every title/section/body/metadata text maps to named type roles, including Arabic and x2 text scaling. | **Pending per-screen/runtime verification** |
| 5 | One icon language | Selected navigation icons use the bold variant and inactive siblings use outline, with consistent meaning across both role shells. | **Pending per-screen/runtime verification** |
| 6 | Color semantics | Success, error, warning, selection and disabled states each use the canonical tokens, without neon-green regressions. | **Pending per-screen/runtime verification** |
| 7 | Stable alignment | Repeated card fields/actions align and use directional spacing in both LTR and RTL; IDs/phone stay readable LTR. | **Pending per-screen/runtime verification** |
| 8 | Scan-friendly density | First glance reveals primary content and action without expanding dense explanation; 320dp layout is unclipped. | **Pending per-screen/runtime verification** |
| 9 | State visibility | Loading, stale, empty, unavailable, selected and complete states are unambiguously distinct in every relevant flow. | **Pending per-screen/runtime verification** |
| 10 | Bilingual visual integrity | Arabic/English copy fits, reorders directionally, and preserves numeric/timestamp legibility at x2 text scale. | **Pending per-screen/runtime verification** |
| 11 | Responsive legibility | 320dp/large phone/landscape and keyboard-visible screenshots have no clipped text, actions or unsafe inset overlap. | **Pending per-screen/runtime verification** |
| 12 | Recognition over recall | Selected pitch, date, teammates, plan and required context are visible at the relevant action without navigating backward. | **Pending per-screen/runtime verification** |
| 13 | Plain language | Every user-facing failure and constraint uses recognizable local-language copy rather than RPC, stack trace or internal keys. | **Pending per-screen/runtime verification** |
| 14 | One primary decision | Each confirmation/dialog/card has a visually prioritized and clearly labelled primary action and distinct secondary exit. | **Pending per-screen/runtime verification** |
| 15 | Progressive disclosure | Advanced filters, optional extras and terms stay collapsed until needed and return to the same user state. | **Pending per-screen/runtime verification** |
| 16 | Decision context | Confirmation displays the selected resource, consequence, schedule and relevant participants before final action. | **Pending per-screen/runtime verification** |
| 17 | Transparent cost | Before any pay/confirm action the exact fee, extras, deposit and remaining balance agree with authoritative server amounts. | **Pending per-screen/runtime verification** |
| 18 | No misleading promises | A success state appears only after its server-confirmed action, including payment, booking, refund and team membership. | **Pending per-screen/runtime verification** |
| 19 | Meaningful defaults | Default sport, location, date, privacy and plan values can be explained and never silently overwrite user intent. | **Pending per-screen/runtime verification** |
| 20 | Choice economy | No duplicate booking-type/payment-plan options; alternatives differ by a documented user need. | **Pending per-screen/runtime verification** |
| 21 | Chunk complex tasks | Onboarding/tournament/venue wizard has explicit step progression, back navigation and draft preservation. | **Pending per-screen/runtime verification** |
| 22 | Explain constraints | Capacity, age, role, limits and why a disabled action is unavailable are announced before submission. | **Pending per-screen/runtime verification** |
| 23 | Comparable information | Plans and booking alternatives use the same currency, unit, period and feature labels; savings math reconciles. | **Pending per-screen/runtime verification** |
| 24 | Contextual help | Every non-obvious fee, eligibility term or sensitive input exposes relevant nearby guidance without a detour. | **Pending per-screen/runtime verification** |
| 25 | Error prevention | Invalid fields, ownership, unavailable slots and inconsistent states cannot be submitted; server rejects client bypass. | **Pending per-screen/runtime verification** |
| 26 | Decision reversibility | Cancellation, irreversible update and paid commitment explain effects and expose cancel/back where permitted. | **Pending per-screen/runtime verification** |
| 27 | Affordance clarity | Every tappable card, link, switch or button signals its interaction and disabled surfaces have no onTap handler. | **Pending per-screen/runtime verification** |
| 28 | Immediate feedback | Submit/tap produces loading, progress or result feedback tied to its real async operation without artificial success delays. | **Pending per-screen/runtime verification** |
| 29 | No duplicate submission | Rapid repeated taps, retries and concurrent requests produce a single logical server action or explicit conflict. | **Pending per-screen/runtime verification** |
| 30 | Predictable navigation | Back, tab, deep link and account switch preserve allowed state and never expose previous-account content. | **Pending per-screen/runtime verification** |
| 31 | State-driven actions | Available buttons match confirmed payment/booking/team/tournament lifecycle; contradictory actions are absent. | **Pending per-screen/runtime verification** |
| 32 | Safe destructive actions | Delete, leave, cancel or replace operations require clear intent and identify the records or consequences affected. | **Pending per-screen/runtime verification** |
| 33 | Touch ergonomics | Primary touch controls expose at least 48dp targets, separate adjacent actions and work with a screen reader. | **Pending per-screen/runtime verification** |
| 34 | Form resilience | Fields have suitable keyboard, autofill, focus, inline validation and remain reachable when keyboard is open. | **Pending per-screen/runtime verification** |
| 35 | Scroll and modal safety | Scrollable dialogs/sheets keep a reachable primary action within safe areas at 320dp and x2 type scale. | **Pending per-screen/runtime verification** |
| 36 | Feedback recovery | Failures show a localized retry that genuinely creates a fresh request without discarding confirmed user input. | **Pending per-screen/runtime verification** |
| 37 | Consistent gestures | Swipe/long-press behavior is documented and discoverable; a non-gesture alternative exists for critical actions. | **Pending per-screen/runtime verification** |
| 38 | Single source of truth | All displayed booking, price, result and subscription claims are sourced from fresh server state, or clearly marked stale. | **Pending per-screen/runtime verification** |
| 39 | Role-based relevance | Player, venue owner and admin cannot read or mutate another role/account resource, including direct RPC access. | **Pending per-screen/runtime verification** |
| 40 | Lifecycle consistency | Status labels and transitions are consistent between player, venue, dashboard and notifications after real actions. | **Pending per-screen/runtime verification** |
| 41 | Persistent communication | Reading an alert never deletes unrelated events and important history follows tested retention/privacy rules. | **Pending per-screen/runtime verification** |
| 42 | Design-system governance | Common buttons/cards/spacing/colors use central tokens/components; each exception has a registered rationale. | **Pending per-screen/runtime verification** |
| 43 | Operational observability | Every failed critical operation has a traceable internal event without logging credentials, personal data or secret values. | **Pending per-screen/runtime verification** |
| 44 | Optimal cognitive load | No artificial countdown/urgency; motion and detail fit the task and respect reduced-motion preference. | **Pending per-screen/runtime verification** |

## Scope and action

- **Task 01.07 (matrix creation)** can be accepted once this 44-row independent-criteria document is committed and its row count and canonical rule names are checked. This acceptance **does not** mark tasks 01.01–01.06, the 44 rules themselves, the 338 registered surfaces, or any release gate as complete.
- Rule 17 (financial truth), 25/31 (permissions and booking state), 38/39 (data source and roles) and 41 (notification retention) require explicit server/role evidence and may remain blocked on outstanding API and security work. Do not infer success from a green Flutter build alone.
- Source reviews and screenshots should be migrated into per-screen entries only after that screen/state is actually evaluated. The existing audit lists source-reviewed/pending states; it is *not* a comprehensive pass/fail dataset.
