# VSP Visual Audit Matrix (All 58 Screens + Shared Components + Web & Admin)

**Date:** 2026-11-27  
**Branch:** `feat/unify-commission-paymob-fees`  
**Canonical Token Source:** `VSP.App/design-tokens.json` (synced via `scripts/sync_design_tokens.mjs`)

## 1. Per-Screen Audit Matrix (58 `*_screen.dart` Files)
| # | Screen File | SafeArea / VSPScaffold | Token / Colors Check | Visual / Live Device Status |
|---:|---|---|---|---|
| 1 | `lib/core/navigation/offline_error_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 2 | `lib/core/navigation/root_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 3 | `lib/core/navigation/suspended_account_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 4 | `lib/features/auth/screens/create_account_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 5 | `lib/features/auth/screens/login_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 6 | `lib/features/auth/screens/owner_onboarding_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 7 | `lib/features/auth/screens/player_onboarding_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 8 | `lib/features/auth/screens/select_role_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 9 | `lib/features/auth/screens/set_new_password_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 10 | `lib/features/auth/screens/signup_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 11 | `lib/features/auth/screens/splash_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 12 | `lib/features/auth/screens/verify_email_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 13 | `lib/features/auth/screens/welcome_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 14 | `lib/features/dev/design_system_showcase_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Widget test (AR/EN, 1.6x, error/long text) |
| 15 | `lib/features/owner/screens/facility_onboarding_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 16 | `lib/features/owner/screens/owner_account_management_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 17 | `lib/features/owner/screens/owner_bookings_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 18 | `lib/features/owner/screens/owner_cup_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 19 | `lib/features/owner/screens/owner_dashboard_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 20 | `lib/features/owner/screens/owner_inbox_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 21 | `lib/features/owner/screens/owner_ledger_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited + Fixed; Live device: Not Tested |
| 22 | `lib/features/owner/screens/owner_main_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 23 | `lib/features/owner/screens/owner_profile_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 24 | `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 25 | `lib/features/owner/screens/tournament_brackets_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 26 | `lib/features/player/screens/all_stadiums_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 27 | `lib/features/player/screens/booking_confirmation_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 28 | `lib/features/player/screens/booking_success_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited + Fixed; Live device: Not Tested |
| 29 | `lib/features/player/screens/bookings_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 30 | `lib/features/player/screens/challenge_select_team_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 31 | `lib/features/player/screens/champion_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 32 | `lib/features/player/screens/championship_checkout_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 33 | `lib/features/player/screens/championship_details_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 34 | `lib/features/player/screens/chat_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 35 | `lib/features/player/screens/faq_and_support_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 36 | `lib/features/player/screens/global_search_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 37 | `lib/features/player/screens/manage_tournament_roster_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 38 | `lib/features/player/screens/match_details_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 39 | `lib/features/player/screens/matchup_live_dashboard_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 40 | `lib/features/player/screens/notifications_center_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited + Fixed; Live device: Not Tested |
| 41 | `lib/features/player/screens/payment_gateway_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited + Fixed; Live device: Not Tested |
| 42 | `lib/features/player/screens/paymob_web_view_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 43 | `lib/features/player/screens/player_booking_details_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited + Fixed; Live device: Not Tested |
| 44 | `lib/features/player/screens/player_home_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 45 | `lib/features/player/screens/profile_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 46 | `lib/features/player/screens/profile_subscreens/blocked_users_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 47 | `lib/features/player/screens/profile_subscreens/edit_profile_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 48 | `lib/features/player/screens/profile_subscreens/favorites_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 49 | `lib/features/player/screens/profile_subscreens/language_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 50 | `lib/features/player/screens/profile_subscreens/my_team_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 51 | `lib/features/player/screens/profile_subscreens/notifications_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 52 | `lib/features/player/screens/stadium_details_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 53 | `lib/features/player/screens/support_ticket_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 54 | `lib/features/player/screens/support_tickets_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 55 | `lib/features/player/screens/team_dashboard_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 56 | `lib/features/player/screens/team_profile_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 57 | `lib/features/player/screens/terms_and_privacy_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |
| 58 | `lib/features/player/screens/tournament_registration_success_screen.dart` | Yes | 0 hex, 0 raw Colors.* | Code audited; Live device: Not Tested |

## 2. Shared Component & Cross-Platform Matrix
| Surface / Component | Tokens & Typography | States & RTL/LTR | Verification Evidence |
|---|---|---|---|
| `VSPPaymentSummaryCard` | `VSPDSSemanticColors`, `VSPDSSpacing`, `VSPDSRadius` | AR/RTL + EN/LTR (`320-800px` @ `1.5x`) | Golden (`Linux CI`) + Widget tests |
| `PrimaryButton` | `VSPDSSemanticColors.accent`, `56dp >= 48dp` | Normal / Loading / Disabled | Golden (`Linux CI`) + Touch target test |
| `VSPStateView` / `VSPEmptyState` / `VSPErrorState` | `VSPDSTypography`, `VSPDSSemanticColors` | All 8 `VSPUiState` states | Golden (`Linux CI`) + AR/EN widget tests |
| `OwnerDigitalBalanceCard` | `VSPColors`, `VSPRadius.card` | `Expanded` overflow fix | AR/EN widget tests (`360px` @ `1.3x`) |
| `StadiumCard` | `VSPColors.textSecondary/Muted`, `VSPRadius.xs` | Amenities + pending badge | Code audited + unified |
| `ChampionshipStandingsTable` | `VSPColors.textPrimary/Secondary` | Ranks + W/D/L semantic colors | Code audited + unified |
| `OwnerGlanceableTimeline` | `VSPColors.textSecondary/Muted` | Empty + ongoing + call/WhatsApp | Code audited + unified |
| `vsp_website` (17 routes) | `VSP_GENERATED_TOKENS` (`generated_tokens.ts`) | RTL/LTR CSS | `tsc` + `27/27` tests + `lint` + `next build` |
| `vsp_admin_panel` | `generated_tokens.json` -> `tailwind.config.js` | Tailwind RTL | `54/54` tests + `vite build` |
