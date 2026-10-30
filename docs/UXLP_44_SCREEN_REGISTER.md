# UXLP-44 Screen Coverage Register

This register is the inventory of Dart files whose names indicate screens, pages, dialogs, sheets, modals, or popups in the current repository tree. It is a starting inventory, not proof that every UI surface is represented: embedded widgets and state variants must also be discovered from call sites.

- Base: main at d91a3f1a607043d878f6f5d86abb1b49b54136c4
- Candidate files: 128
- Current status: inventory generated; detailed per-rule inspection not yet completed.
- Static source scan: all 128 candidate files were fetched and scanned for legacy/V2 token imports, raw color and text-style declarations, hard-coded motion durations, SafeArea/useSafeArea markers, and modal entry points.
- Static scan is triage evidence only. No screen has been marked pass from source heuristics; parent route behavior, modal constraints, runtime overflow, Arabic/English rendering, and actual state coverage still require direct verification.
- Status values: not yet inspected / source reviewed—runtime pending / pass / fail / needs product decision / not applicable.
- Do not mark a file complete until Arabic and English, role, loading/empty/error/success states, keyboard, safe area, and navigation have been considered where applicable.

| File | Role | Status |
|---|---|---|
| `lib/core/navigation/offline_error_screen.dart` | player/owner | source reviewed—runtime pending (safe-area + primary action updated) |
| `lib/core/navigation/root_screen.dart` | player/owner | source reviewed—runtime pending (maintenance content safe-area/scroll updated) |
| `lib/core/navigation/suspended_account_screen.dart` | player/owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/auth/screens/create_account_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/screens/login_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/screens/owner_onboarding_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/screens/player_onboarding_screen.dart` | player/owner | source reviewed—runtime pending (async location lookup and post-frame callback now guard against disposal) |
| `lib/features/auth/screens/select_role_screen.dart` | player/owner | source reviewed—runtime pending (localized, scroll-safe, accessible role cards) |
| `lib/features/auth/screens/set_new_password_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/screens/signup_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/screens/splash_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected) |
| `lib/features/auth/screens/verify_email_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/screens/welcome_screen.dart` | player/owner | not yet inspected |
| `lib/features/auth/widgets/forgot_password_dialog.dart` | player/owner | source reviewed—runtime pending (showDialog default safe-area behavior; keyboard/layout still needs runtime check) |
| `lib/features/auth/widgets/owner_onboarding/owner_onboarding_exit_dialog.dart` | player/owner | source reviewed—runtime pending (showDialog default safe-area behavior; keyboard/layout still needs runtime check) |
| `lib/features/copilot/screens/copilot_test_playground.dart` | shared | source reviewed—runtime pending (body bottom safe-area protected) |
| `lib/features/copilot/screens/vsp_copilot_screen.dart` | shared | not yet inspected |
| `lib/features/copilot/screens/vsp_copilot_sheet.dart` | shared | source reviewed—runtime pending (bottom sheet useSafeArea enabled; content handles keyboard insets) |
| `lib/features/owner/screens/add_stadium_wizard.dart` | owner | not yet inspected |
| `lib/features/owner/screens/create_tournament_wizard.dart` | owner | not yet inspected |
| `lib/features/owner/screens/facility_onboarding_screen.dart` | owner | not yet inspected |
| `lib/features/owner/screens/owner_account_management_screen.dart` | owner | not yet inspected |
| `lib/features/owner/screens/owner_bookings_screen.dart` | owner | source reviewed—runtime pending (booking list uses shared bottom-navigation scroll padding) |
| `lib/features/owner/screens/owner_cup_screen.dart` | owner | source reviewed—runtime pending (cup list uses shared bottom-navigation scroll padding) |
| `lib/features/owner/screens/owner_dashboard_screen.dart` | owner | not yet inspected |
| `lib/features/owner/screens/owner_documentation_wizard.dart` | owner | not yet inspected |
| `lib/features/owner/screens/owner_inbox_screen.dart` | owner | source reviewed—runtime pending (inbox list uses shared bottom-navigation scroll padding) |
| `lib/features/owner/screens/owner_ledger_screen.dart` | owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/owner/screens/owner_main_screen.dart` | owner | source reviewed—runtime pending (top safe-area protected; floating nav preserved) |
| `lib/features/owner/screens/owner_profile_screen.dart` | owner | not yet inspected |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | not yet inspected |
| `lib/features/owner/screens/subscription_plans_screen.dart` | owner | not yet inspected |
| `lib/features/owner/screens/tournament_brackets_screen.dart` | owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart` | owner | source reviewed—runtime pending (sheet now uses safe-area, keyboard-aware scroll container, and bottom inset) |
| `lib/features/owner/widgets/add_stadium/add_stadium_location_picker_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/add_stadium/stadium_wizard_dialogs.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/add_stadium/stadium_wizard_steps_pager.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_action_panels.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_cancel_dialog.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_details_form.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_duration_selector.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_form_fields.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_header.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_time_stadium_card.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_whatsapp_utils.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/owner_booking_modal.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_service.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/score_modal/goal_scorers_section.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/score_modal/penalty_shootout_section.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/score_modal/roster_list_viewer.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/score_modal/score_counter_column.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/tournament_auto_schedule_modal_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/tournament_round_auto_schedule_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/brackets/tournament_score_modal.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/documentation/doc_image_source_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/documentation/doc_under_review_dialog.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/documentation/doc_wizard_dialogs.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/documentation/doc_wizard_steps_pager.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/facility_onboarding/facility_upgrade_bottom_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/ledger/owner_payout_dialog.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/owner_booking_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/quick_booking/quick_booking_receipt_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/quick_phone_booking_modal.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/tournament/cups/owner_cup_format_modal.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/tournament/tournament_bracket_preview_dialog.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/tournament/tournament_dashboard_dialogs.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/tournament/tournament_manual_team_sheet.dart` | owner | not yet inspected |
| `lib/features/owner/widgets/tournament/tournament_prize_delivery_dialog.dart` | owner | not yet inspected |
| `lib/features/player/screens/all_stadiums_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/booking_confirmation_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/booking_success_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/bookings_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/challenge_select_team_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/champion_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/championship_checkout_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/championship_details_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/chat_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/faq_and_support_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/global_search_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/manage_tournament_roster_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/match_details_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/matchup_live_dashboard_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/notifications_center_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/payment_gateway_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/paymob_web_view_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/player_booking_details_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/player_home_screen.dart` | player | source reviewed—runtime pending (top safe-area protected; floating nav preserved) |
| `lib/features/player/screens/profile_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/profile_subscreens/edit_profile_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/profile_subscreens/favorites_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/profile_subscreens/language_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/profile_subscreens/my_team_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/profile_subscreens/notifications_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/stadium_details_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/support_ticket_screen.dart` | player | source reviewed—runtime pending (reply and closed-ticket footer controls are bottom SafeArea protected) |
| `lib/features/player/screens/support_tickets_screen.dart` | player | source reviewed—runtime pending (new-ticket sheet uses useSafeArea, keyboard insets, and scrollable content) |
| `lib/features/player/screens/team_dashboard_screen.dart` | player | not yet inspected |
| `lib/features/player/screens/team_profile_screen.dart` | player | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/player/screens/terms_and_privacy_screen.dart` | player | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/player/screens/tournament_registration_success_screen.dart` | player | not yet inspected |
| `lib/features/player/widgets/add_player_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/all_stadiums/all_stadiums_filter_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/booking/booking_calendar_modal.dart` | player | not yet inspected |
| `lib/features/player/widgets/booking/booking_payment_method_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/booking_type_modal.dart` | player | not yet inspected |
| `lib/features/player/widgets/championship_details/championship_governorate_dialog.dart` | player | not yet inspected |
| `lib/features/player/widgets/championship_details/championship_squad_builder_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/chat/chat_dialogs.dart` | player | not yet inspected |
| `lib/features/player/widgets/collective_match_invite_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/create_team_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/filter_bottom_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/home/book_tonight_sheet.dart` | player | not yet inspected |
| `lib/features/player/widgets/home/home_governorate_modal.dart` | player | not yet inspected |
| `lib/features/player/widgets/home/home_match_outcome_dialogs.dart` | player | not yet inspected |
| `lib/features/player/widgets/league/team_league_match_dialog.dart` | player | not yet inspected |
| `lib/features/player/widgets/match_result_modal.dart` | player | not yet inspected |
| `lib/features/player/widgets/my_team/team_dialogs.dart` | player | not yet inspected |
| `lib/features/player/widgets/payment/payment_cancel_dialog.dart` | player | not yet inspected |
| `lib/features/player/widgets/payment/payment_verification_modal.dart` | player | not yet inspected |
| `lib/features/player/widgets/payment/paymob_still_waiting_dialog.dart` | player | not yet inspected |
| `lib/features/player/widgets/team_profile/team_matchup_invite_modal.dart` | player | not yet inspected |
| `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart` | player | not yet inspected |
| `lib/shared/dialogs/vsp_terms_and_privacy_modal.dart` | shared | not yet inspected |
| `lib/shared/widgets/match_card/manage_participants_modal.dart` | shared | not yet inspected |
| `lib/shared/widgets/refund_tracking_sheet.dart` | shared | not yet inspected |
| `lib/shared/widgets/vsp_date_picker_dialog.dart` | shared | not yet inspected |

## Non-screen UI surfaces still requiring discovery

| Surface | Status |
|---|---|
| `VspBottomNavBar` and `OwnerBottomNavBar` | Source reviewed: active/inactive icon variants, selected/unselected typography, semantic selected state, 48dp+ touch height, and bottom SafeArea are present; runtime pending |

- Shared widgets and reusable cards
- Navigation bars, drawers, app bars, tabs, and action menus
- Notification delivery and notification persistence behavior
- Backend-driven state transitions and permission-dependent actions
- Flutter Web/PWA layout behavior
- Device-level rendering and touch interaction

## Audit acceptance criteria

A screen passes only when its actual call sites and relevant states have been checked against all applicable rules in docs/UXLP_44_VSP_STANDARD.md. Source inspection alone cannot establish runtime visual correctness. One consolidated automated validation pass and a device-level UX pass are required after grouped fixes.
