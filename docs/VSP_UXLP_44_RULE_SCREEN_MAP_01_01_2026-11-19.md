# UXLP-44 — Screen-to-rule source inventory (task 01.01, 19 Nov 2026)

**Goal:** establish 44 uniquely numbered design rules and at least two concrete, traceable player/owner/auth source surfaces per rule. **This document is a source inventory, not UX approval.**

**Inputs:** [44-rule audit](UXLP_44_RULE_AUDIT.md), [338-path screen register](UXLP_44_SCREEN_REGISTER.md). All 44 rule names and source audit states are cross-checked. The two links below are prioritized **representative entry points** per rule, not exhaustive coverage across 338 screens, variants, languages or devices.

| Rule | Rule name | Player/auth example | Owner/auth example | Source inspection focus | Prior audit state |
|---:|---|---|---|---|---|
| 01 | Clear hierarchy | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_dashboard_screen.dart` | primary action / visual hierarchy | source reviewed—runtime pending |
| 02 | Consistent grouping | `lib/features/player/screens/match_details_screen.dart` | `lib/features/owner/screens/add_stadium_wizard.dart` | information grouping | source reviewed—runtime pending |
| 03 | Contrast first | `lib/features/player/screens/profile_screen.dart` | `lib/features/owner/screens/subscription_plans_screen.dart` | foreground/background contrast | source reviewed—runtime pending |
| 04 | Typography roles | `lib/features/player/screens/championship_checkout_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | semantic typography | source reviewed—runtime pending |
| 05 | One icon language | `lib/features/player/screens/player_home_screen.dart` | `lib/features/owner/screens/owner_main_screen.dart` | selected/outline icon states | source reviewed—runtime pending |
| 06 | Color semantics | `lib/features/player/screens/player_booking_details_screen.dart` | `lib/features/owner/screens/owner_ledger_screen.dart` | status and brand color semantics | source reviewed—runtime pending |
| 07 | Stable alignment | `lib/features/player/screens/champion_screen.dart` | `lib/features/owner/screens/add_stadium_wizard.dart` | directional alignment | source reviewed—runtime pending |
| 08 | Scan-friendly density | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_documentation_wizard.dart` | information density / modal fit | source reviewed—runtime pending |
| 09 | State visibility | `lib/features/player/screens/all_stadiums_screen.dart` | `lib/features/owner/screens/owner_dashboard_screen.dart` | loading/error/empty distinction | source reviewed—runtime pending |
| 10 | Bilingual visual integrity | `lib/features/auth/screens/signup_screen.dart` | `lib/features/auth/screens/owner_onboarding_screen.dart` | Arabic-English labels and RTL | source reviewed—runtime pending |
| 11 | Responsive legibility | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_documentation_wizard.dart` | text scale and keyboard layout | source reviewed—runtime pending |
| 12 | Recognition over recall | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | selected options remain visible | source reviewed—runtime pending |
| 13 | Plain language | `lib/features/auth/screens/login_screen.dart` | `lib/features/owner/screens/owner_documentation_wizard.dart` | localized user-facing copy | source reviewed—runtime pending |
| 14 | One primary decision | `lib/features/player/screens/challenge_select_team_screen.dart` | `lib/features/owner/widgets/booking_sheet/owner_booking_modal.dart` | one dominant call-to-action | source reviewed—runtime pending |
| 15 | Progressive disclosure | `lib/features/player/screens/stadium_details_screen.dart` | `lib/features/owner/screens/create_tournament_wizard.dart` | detail disclosure | source reviewed—runtime pending |
| 16 | Decision context | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/widgets/booking_sheet/owner_booking_modal.dart` | decision consequences | source reviewed—runtime pending |
| 17 | Transparent cost | `lib/features/player/screens/championship_checkout_screen.dart` | `lib/features/owner/screens/owner_ledger_screen.dart` | verified totals versus deposits | source reviewed—runtime pending |
| 18 | No misleading promises | `lib/features/player/screens/player_booking_details_screen.dart` | `lib/features/owner/screens/subscription_plans_screen.dart` | no unverifiable promises | source reviewed—runtime pending |
| 19 | Meaningful defaults | `lib/features/player/widgets/create_team_sheet.dart` | `lib/features/owner/screens/add_stadium_wizard.dart` | safe defaults | source reviewed—runtime pending |
| 20 | Choice economy | `lib/features/player/widgets/booking_type_modal.dart` | `lib/features/owner/screens/subscription_plans_screen.dart` | limited choices | source reviewed—runtime pending |
| 21 | Chunk complex tasks | `lib/features/player/screens/champion_screen.dart` | `lib/features/auth/screens/owner_onboarding_screen.dart` | steps and progress | source reviewed—runtime pending |
| 22 | Explain constraints | `lib/features/player/screens/team_profile_screen.dart` | `lib/features/owner/screens/create_tournament_wizard.dart` | registration and entitlement constraints | source reviewed—runtime pending |
| 23 | Comparable information | `lib/features/player/screens/stadium_details_screen.dart` | `lib/features/owner/screens/subscription_plans_screen.dart` | comparable options | source reviewed—runtime pending |
| 24 | Contextual help | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_documentation_wizard.dart` | adjacent policy help | source reviewed—runtime pending |
| 25 | Error prevention | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | prevent invalid transitions | needs product decision |
| 26 | Decision reversibility | `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart` | `lib/features/owner/widgets/booking_sheet/booking_sheet_cancel_dialog.dart` | reversible confirmation | source reviewed—runtime pending |
| 27 | Affordance clarity | `lib/features/player/screens/player_home_screen.dart` | `lib/features/owner/screens/owner_dashboard_screen.dart` | tappable affordances | source reviewed—runtime pending |
| 28 | Immediate feedback | `lib/features/player/screens/player_home_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | feedback on async action | source reviewed—runtime pending |
| 29 | No duplicate submission | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/widgets/booking_sheet/owner_booking_modal.dart` | duplicate-submit guards | source reviewed—runtime pending |
| 30 | Predictable navigation | `lib/features/player/screens/player_home_screen.dart` | `lib/features/owner/screens/owner_main_screen.dart` | route and back-stack | source reviewed—runtime pending |
| 31 | State-driven actions | `lib/features/player/screens/bookings_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | server-driven action states | needs product decision |
| 32 | Safe destructive actions | `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart` | `lib/features/owner/widgets/booking_sheet/booking_sheet_cancel_dialog.dart` | destructive-action confirmation | source reviewed—runtime pending |
| 33 | Touch ergonomics | `lib/features/auth/screens/login_screen.dart` | `lib/features/owner/screens/owner_dashboard_screen.dart` | touch targets | source reviewed—runtime pending |
| 34 | Form resilience | `lib/features/auth/screens/signup_screen.dart` | `lib/features/auth/screens/owner_onboarding_screen.dart` | input lifecycle/error recovery | source reviewed—runtime pending |
| 35 | Scroll and modal safety | `lib/features/player/screens/notifications_center_screen.dart` | `lib/features/owner/screens/owner_documentation_wizard.dart` | safe scrolling and overlays | source reviewed—runtime pending |
| 36 | Feedback recovery | `lib/features/player/screens/all_stadiums_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | retry after failure | source reviewed—runtime pending |
| 37 | Consistent gestures | `lib/features/player/screens/notifications_center_screen.dart` | `lib/features/owner/screens/owner_dashboard_screen.dart` | gesture consistency | source reviewed—runtime pending |
| 38 | Single source of truth | `lib/features/player/screens/bookings_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | one authoritative booking source | needs product decision |
| 39 | Role-based relevance | `lib/features/player/screens/team_profile_screen.dart` | `lib/features/owner/screens/owner_main_screen.dart` | player/owner access boundaries | needs product decision |
| 40 | Lifecycle consistency | `lib/features/player/screens/player_booking_details_screen.dart` | `lib/features/owner/screens/owner_bookings_screen.dart` | booking status lifecycle | source reviewed—runtime pending |
| 41 | Persistent communication | `lib/features/player/screens/notifications_center_screen.dart` | `lib/features/owner/screens/owner_inbox_screen.dart` | notification persistence | needs product decision |
| 42 | Design-system governance | `lib/features/player/screens/profile_screen.dart` | `lib/features/owner/screens/owner_dashboard_screen.dart` | shared tokens and components | source reviewed—runtime pending |
| 43 | Operational observability | `lib/features/player/screens/booking_confirmation_screen.dart` | `lib/features/owner/screens/owner_ledger_screen.dart` | safe operational trace | source reviewed—runtime pending |
| 44 | Optimal cognitive load | `lib/features/player/screens/champion_screen.dart` | `lib/features/owner/screens/add_stadium_wizard.dart` | limit cognitive load | source reviewed—runtime pending |

## Scope, verification and next steps

- **44/44** rule IDs are mapped to **88** relevant path assignments, each resolved against the existing screen register. These are sample source surfaces, not a claim of 88 independent screen passes.
- **39** rules remain source-reviewed/runtime-pending; **5** (25, 31, 38, 39, 41) require unresolved decisions. **Zero** rules have an all-screens, all-states runtime PASS.
- Extend the inventory to the full 338-path × role × state × locale × device matrix under separate tasks **01.02 / 01.04–01.06**. Validate critical user journeys, TalkBack, Arabic/English, high text scaling, network and entitlement state.
- Running `node --test scripts/test_uxlp_rule_screen_map.cjs` independently verifies ordering, names, referenced source paths and unchanged honest audit-state declarations.
- No production/DB changes, app UI refactor, server claims, main merge or APK; this closes only **01.01 (rule inventory and screen linkage)** once the dedicated CI passes.
