# UXLP-44 Screen Coverage Register

This register is the inventory of Dart files whose names indicate screens, pages, dialogs, sheets, modals, or popups in the current repository tree. It is a starting inventory, not proof that every UI surface is represented: embedded widgets and state variants must also be discovered from call sites.

- Base: current branch `uxlp-44-implementation` (inventory refreshed 2026-11-01)
- Registered Dart screen/surface paths: 208 unique paths
- Additional shared navigation component entry: 1
- Table records: 234, including 26 repeated paths that document separate embedded-component findings
- Current status: inventory updated; detailed per-rule and per-state inspection remains incomplete.
- Historical static source scan (before the latest inventory expansion): 128 candidate files were fetched and scanned for legacy/V2 token imports, raw color and text-style declarations, hard-coded motion durations, SafeArea/useSafeArea markers, and modal entry points. This is not a scan of all 208 currently registered paths.
- Static scan is triage evidence only. No screen has been marked pass from source heuristics; parent route behavior, modal constraints, runtime overflow, Arabic/English rendering, and actual state coverage still require direct verification.
- Status values: not yet inspected / source reviewed—runtime pending / pass / fail / needs product decision / not applicable.
- Do not mark a file complete until Arabic and English, role, loading/empty/error/success states, keyboard, safe area, and navigation have been considered where applicable.

| File | Role | Status |
|---|---|---|
| `lib/core/navigation/offline_error_screen.dart` | player/owner | source reviewed—runtime pending (safe-area + primary action updated) |
| `lib/core/navigation/root_screen.dart` | player/owner | source reviewed—runtime pending (maintenance + forced-update dialogs scroll-safe; offline banner overlay still needs runtime check) |
| `lib/core/navigation/suspended_account_screen.dart` | player/owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/auth/screens/create_account_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected scroll layout) |
| `lib/features/auth/screens/login_screen.dart` | player/owner | source reviewed—runtime pending (keyboard-aware safe-area scroll layout) |
| `lib/features/auth/screens/owner_onboarding_screen.dart` | player/owner | source reviewed—runtime pending (safe-area form and sticky footer; async location/date callbacks guarded against disposal) |
| `lib/features/auth/screens/player_onboarding_screen.dart` | player/owner | source reviewed—runtime pending (async location lookup and post-frame callback now guard against disposal) |
| `lib/features/auth/screens/select_role_screen.dart` | player/owner | source reviewed—runtime pending (localized, scroll-safe, accessible role cards) |
| `lib/features/auth/screens/set_new_password_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected form scroll layout) |
| `lib/features/auth/screens/signup_screen.dart` | player/owner | source reviewed—runtime pending (keyboard-aware safe-area scroll layout) |
| `lib/features/auth/screens/splash_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected) |
| `lib/features/auth/screens/verify_email_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected OTP flow with scrollable content) |
| `lib/features/auth/screens/welcome_screen.dart` | player/owner | source reviewed—runtime pending (top and bottom controls individually safe-area protected) |
| `lib/features/auth/widgets/forgot_password_dialog.dart` | player/owner | source reviewed—runtime pending (showDialog default safe-area behavior; keyboard/layout still needs runtime check) |
| `lib/features/auth/widgets/owner_onboarding/owner_onboarding_exit_dialog.dart` | player/owner | source reviewed—runtime pending (showDialog default safe-area behavior; keyboard/layout still needs runtime check) |
| `lib/features/copilot/screens/copilot_test_playground.dart` | shared | source reviewed—runtime pending (body bottom safe-area protected) |
| `lib/features/copilot/screens/vsp_copilot_screen.dart` | shared | source reviewed—runtime pending (owner-only screen gate; chat body and composer safe-area protected) |
| `lib/features/copilot/screens/vsp_copilot_sheet.dart` | shared | source reviewed—runtime pending (bottom sheet useSafeArea enabled; content handles keyboard insets) |
| `lib/features/owner/screens/add_stadium_wizard.dart` | owner | source reviewed—runtime pending (wizard scrolling, fixed action-bar insets, form lifecycle, and screen-state layout reviewed) |
| `lib/features/owner/screens/create_tournament_wizard.dart` | owner | source reviewed—runtime pending (wizard layout reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/screens/facility_onboarding_screen.dart` | owner | source reviewed—runtime pending (SafeArea wraps onboarding states; Supabase auth ID reads corrected to User.id) |
| `lib/features/owner/screens/owner_account_management_screen.dart` | owner | source reviewed—runtime pending (form lifecycle reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/screens/owner_bookings_screen.dart` | owner | source reviewed—runtime pending (stadium/booking streams distinguish loading/error from empty/free; owner stream reloads on authenticated owner-scope changes) |
| `lib/features/owner/screens/owner_cup_screen.dart` | owner | source reviewed—runtime pending (cup list uses shared bottom-navigation scroll padding; auth ID read corrected to User.id) |
| `lib/features/owner/screens/owner_dashboard_screen.dart` | owner | source reviewed—runtime pending (analytics errors localized with retry; stale responses invalidated by request generation; tab switcher meets 48dp minimum height) |
| `lib/features/owner/screens/owner_documentation_wizard.dart` | owner | source reviewed—runtime pending (wizard flow reviewed; Supabase auth ID reads corrected to User.id) |
| `lib/features/owner/screens/owner_inbox_screen.dart` | owner | source reviewed—runtime pending (inbox list uses shared bottom-navigation scroll padding) |
| `lib/features/owner/screens/owner_ledger_screen.dart` | owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/owner/screens/owner_main_screen.dart` | owner | source reviewed—runtime pending (top safe-area protected; floating nav preserved; account-verification dialog scroll-safe) |
| `lib/features/owner/screens/owner_profile_screen.dart` | owner | source reviewed—runtime pending (profile/role flow reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | source reviewed—runtime pending (wizard scrolling, fixed action-bar insets, form lifecycle, and screen-state layout reviewed) |
| `lib/features/owner/screens/subscription_plans_screen.dart` | owner | source reviewed—runtime pending (plan prices, trial days, stadium limits, descriptions, and feature flags now load from public_subscription_plans; monthly/annual choices use server billing periods; retry state on read failure) |
| `lib/features/owner/screens/tournament_brackets_screen.dart` | owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart` | owner | source reviewed—runtime pending (sheet now uses safe-area, keyboard-aware scroll container, and bottom inset) |
| `lib/features/owner/widgets/add_stadium/add_stadium_location_picker_sheet.dart` | owner | source reviewed—runtime pending (manual-address controller lifecycle and keyboard/bottom safe area; GPS lookup failure is localized and sheet-state updates are guarded after disposal) |
| `lib/features/owner/widgets/add_stadium/stadium_wizard_dialogs.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints and lifecycle reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/widgets/add_stadium/stadium_wizard_steps_pager.dart` | owner | source reviewed—runtime pending (step pager and page composition reviewed; child steps are independently scrollable) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_action_panels.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | source reviewed—runtime pending (reschedule request now shows backend failure; confirmation/destructive actions and safe-area remain runtime pending) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_cancel_dialog.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_details_form.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_duration_selector.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_form_fields.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_header.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_time_stadium_card.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_whatsapp_utils.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/owner_booking_modal.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_service.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/goal_scorers_section.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/penalty_shootout_section.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/roster_list_viewer.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/score_counter_column.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/tournament_auto_schedule_modal_sheet.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/brackets/tournament_round_auto_schedule_sheet.dart` | owner | source reviewed—runtime pending (confirmation AlertDialog uses standard safe-area route) |
| `lib/features/owner/widgets/brackets/tournament_score_modal.dart` | owner | source reviewed—runtime pending (score submission logs diagnostics and retains localized recovery copy; score title and fields are width-bounded) |
| `lib/features/owner/widgets/documentation/doc_image_source_sheet.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/documentation/doc_under_review_dialog.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/documentation/doc_wizard_dialogs.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/documentation/doc_wizard_steps_pager.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/facility_onboarding/facility_upgrade_bottom_sheet.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/ledger/owner_payout_dialog.dart` | owner | source reviewed—runtime pending (AlertDialog safe-area and scrollable payout form) |
| `lib/features/owner/widgets/owner_booking_sheet.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/quick_booking/quick_booking_receipt_sheet.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/quick_phone_booking_modal.dart` | owner | source reviewed—runtime pending (metadata is width-bounded; unknown save failures use safe localized copy and diagnostic logging) |
| `lib/features/owner/widgets/tournament/cups/owner_cup_format_modal.dart` | owner | source reviewed—runtime pending (format selection sheet now has viewport-bounded scrollable content; tournament preview and invite surfaces remain runtime pending) |
| `lib/features/owner/widgets/tournament/tournament_bracket_preview_dialog.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/tournament/tournament_dashboard_dialogs.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/tournament/tournament_manual_team_sheet.dart` | owner | source reviewed—runtime pending (manual registration errors are localized; technical failures logged; Supabase auth ID uses User.id) |
| `lib/features/owner/widgets/tournament/tournament_prize_delivery_dialog.dart` | owner | source reviewed—runtime pending (notes controller is disposed after modal close; prize-handover failure copy is localized and technical details stay in diagnostics) |
| `lib/features/player/screens/all_stadiums_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/booking_confirmation_screen.dart` | player | source reviewed—runtime pending (AppBar and sticky booking bottom bar; verify bottom bar safe inset at runtime) |
| `lib/features/player/screens/booking_success_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/screens/bookings_screen.dart` | player | source reviewed—runtime pending (dedicated loading state; refresh awaits server response; cached list stays visible on refresh failure with localized retry warning) |
| `lib/features/player/screens/challenge_select_team_screen.dart` | player | source reviewed—runtime pending (strict account-scoped team lookup; loading/empty/error/retry states; create-team recovery; challenge continuation re-verifies team and blocks duplicate/stale actions) |
| `lib/features/player/screens/champion_screen.dart` | player | source reviewed—runtime pending (championship/teams/1v1 tabs and RTL indicator; governorate and sport filter controls meet 48dp minimum height) |
| `lib/features/player/screens/championship_checkout_screen.dart` | player | source reviewed—runtime pending (checkout layout and insets reviewed; Supabase auth ID reads corrected to User.id) |
| `lib/features/player/screens/championship_details_screen.dart` | player | source reviewed—runtime pending (strict team lookup; live championship and matches streams can be recreated on retry; stale header data now shows a warning/retry banner) |
| `lib/features/player/screens/chat_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/faq_and_support_screen.dart` | player | source reviewed—runtime pending (wizard scrolling, fixed action-bar insets, form lifecycle, and screen-state layout reviewed) |
| `lib/features/player/screens/global_search_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/manage_tournament_roster_screen.dart` | player | source reviewed—runtime pending (roster load failure now distinct from empty roster with retry; save disabled until verified; raw backend errors hidden) |
| `lib/features/player/screens/match_details_screen.dart` | player | source reviewed—runtime pending (match report submission guarded; join failures mapped to localized safe copy; actions remain lifecycle-gated) |
| `lib/features/player/screens/matchup_live_dashboard_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/notifications_center_screen.dart` | player | source reviewed—runtime pending (SafeArea list; stream errors now distinct from empty state with retry; informational AlertDialog scroll-safe) |
| `lib/features/player/screens/payment_gateway_screen.dart` | player | source reviewed—runtime pending (fee policy fails closed; server-created booking is authoritative; account-bound checkout; initialization errors localized without raw backend text) |
| `lib/features/player/screens/paymob_web_view_screen.dart` | player | source reviewed—runtime pending (SafeArea wraps payment web view content) |
| `lib/features/player/screens/player_booking_details_screen.dart` | player | source reviewed—runtime pending (report dialog scroll-safe; report success/failure feedback correct; booking lifecycle statuses localized in Arabic/English) |
| `lib/features/player/screens/player_home_screen.dart` | player | source reviewed—runtime pending (post-match prompts require participating captain, eligible booking state, and independent opposing captain for second review) |
| `lib/features/player/screens/profile_screen.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout, safe-area, controller lifecycle, action states, and consistent profile-avatar loading/error fallback across header and no-team card) |
| `lib/features/player/screens/profile_subscreens/edit_profile_screen.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout, safe-area, controller lifecycle, and action states reviewed) |
| `lib/features/player/screens/profile_subscreens/favorites_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/profile_subscreens/language_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/screens/profile_subscreens/my_team_screen.dart` | player | source reviewed—runtime pending (team actions reviewed; Supabase auth ID reads corrected to User.id) |
| `lib/features/player/screens/profile_subscreens/notifications_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/screens/stadium_details_screen.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout, safe-area, controller lifecycle, and action states reviewed) |
| `lib/features/player/screens/support_ticket_screen.dart` | player | source reviewed—runtime pending (reply and closed-ticket footer controls are bottom SafeArea protected; ticket and message streams distinguish loading/error/empty and expose retry) |
| `lib/features/player/screens/support_tickets_screen.dart` | player | source reviewed—runtime pending (new-ticket sheet constrains complete padded content including bottom safe-area inside keyboard-safe viewport; scrollable form and single-flight submit; ticket list distinguishes loading/error/empty) |
| `lib/features/player/screens/team_dashboard_screen.dart` | player | source reviewed—runtime pending (strict team-membership fetch; account-scoped async refresh; separate loading/error/retry from no-team state) |
| `lib/features/player/screens/team_profile_screen.dart` | player | source reviewed—runtime pending (strict team/roster fetches with retry; captain identified by `captain_id`; invite modal opens only after a non-empty successful RPC code) |
| `lib/features/player/screens/terms_and_privacy_screen.dart` | player | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/player/screens/tournament_registration_success_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/widgets/add_player_sheet.dart` | player | source reviewed—runtime pending (scrollable content constrained to keyboard/safe-area viewport; responsive two-line title and localized close tooltip; auth ID read corrected to User.id; caller sheet configuration still to verify) |
| `lib/features/player/widgets/all_stadiums/all_stadiums_filter_sheet.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/widgets/booking/booking_calendar_modal.dart` | player | source reviewed—runtime pending (Dialog safe-area defaults; fixed-height calendar needs small-screen runtime check) |
| `lib/features/player/widgets/booking/booking_payment_method_sheet.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout, safe-area, controller lifecycle, and action states reviewed) |
| `lib/features/player/widgets/booking_type_modal.dart` | player | source reviewed—runtime pending (challenge creation now uses strict team lookup; failed membership read shows retry-safe error rather than falsely prompting team creation) |
| `lib/features/player/widgets/championship_details/championship_governorate_dialog.dart` | player | source reviewed—runtime pending (cross-governorate registration confirmation; dialog dismissal and localized copy pending) |
| `lib/features/player/widgets/championship_details/championship_squad_builder_sheet.dart` | player | source reviewed—runtime pending (incomplete-squad bridge and nested add-team sheet use scroll control and SafeArea; team lookup/runtime pending) |
| `lib/features/player/widgets/chat/chat_dialogs.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout, safe-area, controller lifecycle, and action states reviewed) |
| `lib/features/player/widgets/collective_match_invite_sheet.dart` | player | source reviewed—runtime pending (invite actions reviewed; Supabase auth ID reads corrected to User.id) |
| `lib/features/player/widgets/create_team_sheet.dart` | player | source reviewed—runtime pending (Arabic/English helper copy, keyboard behavior, async lifecycle, and premature success feedback corrected; auth ID reads use User.id) |
| `lib/features/player/widgets/filter_bottom_sheet.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/home/book_tonight_sheet.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/home/home_governorate_modal.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/home/home_match_outcome_dialogs.dart` | player | source reviewed—runtime pending (captain-scoped team IDs; accurate alternate-result copy; both result dialogs lock during submission and preserve retry on failure) |
| `lib/features/player/widgets/league/team_league_match_dialog.dart` | player | source reviewed—runtime pending (result/dispute sheets are keyboard-safe and scrollable; visible copy is bilingual; long team labels are bounded; failures use localized recovery copy) |
| `lib/features/player/widgets/match_result_modal.dart` | player | source reviewed—runtime pending (awaited boolean result; closes only on success; failed submission preserves form for retry; duplicate taps/dismissal guarded) |
| `lib/features/player/widgets/my_team/team_dialogs.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/payment/payment_cancel_dialog.dart` | player | source reviewed—runtime pending (exit copy distinguishes unsubmitted payment from a submitted attempt awaiting server confirmation) |
| `lib/features/player/widgets/payment/payment_verification_modal.dart` | player | source reviewed—runtime pending (showDialog safe-area route; centered custom content needs short-screen runtime check) |
| `lib/features/player/widgets/payment/paymob_still_waiting_dialog.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/team_profile/team_matchup_invite_modal.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart` | player | source reviewed—runtime pending (refund amount is not guessed from total_price; distinguishes unpaid, confirmed, and pending server calculation) |
| `lib/shared/dialogs/vsp_terms_and_privacy_modal.dart` | shared | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/shared/widgets/match_card/manage_participants_modal.dart` | shared | source reviewed—runtime pending (keyboard-safe height; retryable load error; localized action errors with technical diagnostics; 48dp labeled controls; correct player-facing acceptance notification) |
| `lib/shared/widgets/refund_tracking_sheet.dart` | shared | source reviewed—runtime pending (unknown amount shows server-confirmation state; long timeline is bounded/scrollable and close action includes bottom system inset) |
| `lib/shared/widgets/vsp_date_picker_dialog.dart` | shared | source reviewed—runtime pending (Dialog safe-area, bounded height, internally scrollable year/day steps) |

## Non-screen UI surfaces still requiring discovery

| Surface path | Role | Status |
|---|---|---|
| `lib/shared/widgets/custom_text_field.dart` | shared | source reviewed—runtime pending (V2 text-field token migration documented; actual call-site states and locale runtime pending) |
| `lib/shared/widgets/primary_button.dart` | shared | source reviewed—runtime pending (canonical VSPPrimaryButton adapter, haptics and debounce documented; call-site/runtime pending) |
| `lib/shared/widgets/social_auth_button.dart` | shared | source reviewed—runtime pending (V2 semantic button state and 48dp target documented; provider/auth error runtime pending) |
| `lib/shared/widgets/stadium_card.dart` | shared | source reviewed—runtime pending (V2 semantic color/radius migration documented; content-density and locale runtime pending) |
| `lib/shared/widgets/team_card_hero.dart` | shared | source reviewed—runtime pending (responsive minimum-height and flexible stat/footer correction documented; large-text runtime pending) |
| `lib/shared/widgets/vsp_animated_button.dart` | shared | source reviewed—runtime pending (disabled state and finally-based cooldown correction documented; repeat-action runtime pending) |
| `lib/shared/widgets/vsp_back_button.dart` | shared | source reviewed—runtime pending (48dp hit area and semantic interaction documented; navigation/back-stack runtime pending) |
| `lib/shared/widgets/vsp_bottom_nav_bar.dart` | shared | source reviewed—runtime pending (canonical V2 navigation metrics, semantics, SafeArea, selected/unselected glyphs; optional warning indicator for unavailable badge data) |
| `lib/shared/widgets/vsp_empty_state.dart` | shared | source reviewed—runtime pending (shared state/empty pattern documented; every screen usage and state runtime pending) |
| `lib/shared/widgets/vsp_error_state.dart` | shared | source reviewed—runtime pending (shared error/retry pattern used by route/state recovery; caller-by-caller verification pending) |
| `lib/shared/widgets/vsp_fade_in_item.dart` | shared | source reviewed—runtime pending (animation lifecycle/disposal reviewed; caller-specific motion and reduced-motion behavior pending) |
| `lib/shared/widgets/vsp_icon_badge.dart` | shared | source reviewed—runtime pending (canonical badge dimensions/background documented; glyph/contrast runtime pending) |
| `lib/shared/widgets/vsp_network_banner.dart` | shared | source reviewed—runtime pending (V2 semantic token migration documented; offline/online overlay placement runtime pending) |
| `lib/shared/widgets/vsp_position_selector.dart` | shared | source reviewed—runtime pending (V2 token migration and 48dp interactive height documented; focus/selection runtime pending) |
| `lib/core/ui/components/vsp_button.dart` | shared | source reviewed—runtime pending (canonical VSPPrimaryButton component source documented; caller/runtime pending) |
| `lib/core/ui/components/vsp_card.dart` | shared | source reviewed—runtime pending (canonical VSPCard and low-performance blur fallback documented; actual card usage/runtime pending) |
| `lib/features/owner/widgets/owner_bottom_nav_bar.dart` | owner | source reviewed—runtime pending (owner navigation selection/semantics/touch height; unread-stream failures now surface a localized warning instead of appearing as zero unread) |
| `lib/shared/widgets/banner_slider_widget.dart` | shared | source reviewed—runtime pending (REST and realtime banner sources, autoplay/pointer lifecycle, image fallback; optional banner fetch failure hides the carousel without blocking the screen) |
| `lib/shared/widgets/copyable_phone_text.dart` | shared | source reviewed—runtime pending (long-press copy now has semantic label, localized clipboard failure feedback, and a 48dp minimum hit area; call-site runtime pending) |
| `lib/shared/widgets/public_match_card.dart` | player | source reviewed—runtime pending (cancelled/ended states override host badge and route to booking details, not active invite sheet) (join/leave/request/share failures are localized; backend details are logged; request result is checked; share action retains 48dp target) |
| `lib/shared/widgets/vsp_ai_spark_icon.dart` | shared | source reviewed—runtime pending (custom unequal four-point spark geometry; visual identity and contrast runtime pending) |
| `lib/shared/widgets/vsp_ambient_background.dart` | shared | source reviewed—runtime pending (shared ambient decoration uses the compatibility token facade; contrast and low-performance rendering pending) |
| `lib/shared/widgets/vsp_auth_header.dart` | shared | source reviewed—runtime pending (shared auth title/back affordance; parent safe-area and keyboard layout pending) |
| `lib/shared/widgets/vsp_countdown_timer.dart` | shared | source reviewed—runtime pending (timer stops at zero, cancels on disposal, and recalculates when targetDate changes; locale/large-text runtime pending) |
| `lib/shared/widgets/vsp_terms_checkbox.dart` | shared | source reviewed—runtime pending (48dp checkbox hit area, checked semantics, and separate terms/privacy link actions; keyboard/focus runtime pending) |
| `lib/shared/widgets/vsp_upload_widgets.dart` | shared | source reviewed—runtime pending (upload card disabled state and uploaded-item delete action; caller permission/error/confirmation behavior pending) |
| `lib/core/ui/components/vsp_menu_item.dart` | shared | source reviewed—runtime pending (canonical V2 menu component; minimum hit area and focus/semantics runtime pending) |
| `lib/core/ui/components/vsp_section_title.dart` | shared | source reviewed—runtime pending (canonical V2 section heading component; long Arabic/English title wrapping pending) |
| `lib/features/player/widgets/championship_card.dart` | player | source reviewed—runtime pending (open/full/ongoing/cancelled/completed/unknown states no longer appear joinable; countdown only for open state; dynamic fee/prize and 48dp share action) |
| `lib/features/player/widgets/collective_match_invite_route.dart` | player | source reviewed—runtime pending (opens invite sheet once after first frame and returns from route after sheet closes; invalid/expired token runtime pending) |
| `lib/features/player/widgets/create_team_logo_picker_row.dart` | player | source reviewed—runtime pending (logo selection action and preview; picker permission/cancel/error states pending) |
| `lib/features/player/widgets/create_team_members_section.dart` | player | source reviewed—runtime pending (paste label is already simplified to “لصق” / “Paste”; member names bounded with ellipsis and localized blank-name fallback; add/remove actions remain runtime-pending) |
| `lib/features/player/widgets/vsp_1v1_trophy_badge.dart` | player | source reviewed—runtime pending (presentation-only trophy badge variants; contrast and semantics pending) |
| `lib/features/owner/widgets/owner_notification_button.dart` | owner | source reviewed—runtime pending (unread stream errors now show a warning indicator and localized tooltip rather than appearing as zero unread) |
| `lib/features/owner/widgets/radial_tick_gauge_painter.dart` | owner | source reviewed—runtime pending (custom painter has no direct interaction; gauge scale/contrast and parent semantics pending) |

- Shared widgets and reusable cards
- Navigation bars, drawers, app bars, tabs, and action menus
- Notification delivery and notification persistence behavior
- Backend-driven state transitions and permission-dependent actions
- Flutter Web/PWA layout behavior
- Device-level rendering and touch interaction

## Audit acceptance criteria

A screen passes only when its actual call sites and relevant states have been checked against all applicable rules in docs/UXLP_44_VSP_STANDARD.md. Source inspection alone cannot establish runtime visual correctness. One consolidated automated validation pass and a device-level UX pass are required after grouped fixes.
### Embedded booking and match components inspected in this batch

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/user_bookings/pending_booking_card.dart` | player | source reviewed—runtime pending (server-confirmed payment predicate; duplicate-checkout guard while payment awaits confirmation; refreshed status guidance; cancellation confirmation; 48dp cancel target) |
| `lib/features/player/widgets/user_bookings/player_booking_card.dart` | player | source reviewed—runtime pending (booking lifecycle badges now use actual status; channel-neutral refund-pending copy) |
| `lib/features/player/widgets/match_result_modal.dart` | player | source reviewed—runtime pending (awaited callback, submission lock, disabled dismissal/editing while submitting; close control has localized tooltip and 48dp target) |
| `lib/features/player/widgets/home/home_match_outcome_dialogs.dart` | player | source reviewed—runtime pending (success/failure feedback reflects repository result for submit/confirm/dispute) |
| `lib/features/player/widgets/booking/booking_payment_method_sheet.dart` | player | source reviewed—runtime pending (collective full-online-payment guard; localized failure copy; cash-booking exceptions logged; bounded scroll-safe sheet) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | source reviewed—runtime pending (reschedule failure feedback; destructive closure confirmation) |
| `lib/core/providers/booking/booking_sync_coordinator.dart` | shared | source reviewed—runtime pending (awaited authoritative player booking snapshot; realtime merge behavior preserved) |
| `lib/core/providers/booking/booking_sync_coordinator.dart` | shared | source reviewed—runtime pending (owner/player streams are cancelled before changing scope; owner empty snapshots and direct-fetch errors are delivered explicitly) |
| `lib/core/repositories/team_repository.dart` | shared | source reviewed—runtime pending (added lookup for all teams captained by the current user to support multi-team result eligibility) |
| `lib/core/providers/booking_provider.dart` | shared | source reviewed—runtime pending (dedicated player/owner loading states; owner empty/error snapshot handling; concurrent refresh counters) |


### Additional embedded league surface inspected

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/league/team_league_tab.dart` | player | source reviewed—runtime pending (creation/join/payment/stadium/cancel flows bilingual; both modal controllers disposed; join dialog scrolls with keyboard; safe-area handling; configured fee labels; cancellation copy excludes non-refundable administrative fees; raw errors replaced with localized recovery) |


### Additional payment surfaces inspected

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/payment/payment_breakdown_card.dart` | player | source reviewed—runtime pending (server-matching fee policy; no false zero; localized retry; fee-info action has 48dp touch target) |
| `lib/features/player/widgets/payment/payment_countdown_header.dart` | player | source reviewed—runtime pending (base amount is not labeled as final total when fee policy is unavailable) |
| `lib/features/player/widgets/payment/payment_security_footer.dart` | player | source reviewed—runtime pending (checkout disabled until fee policy is valid; accurate Paymob checkout guidance) |


| `lib/features/player/widgets/championship_details/championship_bottom_bar.dart` | player | source reviewed—runtime pending (only open championships expose registration; ongoing/completed/cancelled/full states route to view/disabled actions) |
| `lib/features/player/widgets/championship_details/championship_details_header.dart` | player | source reviewed—runtime pending (live championship status, date, prize, fee, and registration metrics; text wrapping/locale pending) |
| `lib/features/player/widgets/championship_details/championship_matches_tab.dart` | player | source reviewed—runtime pending (waits for first stream event; separates empty/error/stale-data states; retry recreates stream and preserves last good matches) |
| `lib/features/player/widgets/championship_details/championship_pill_tab_bar.dart` | player | source reviewed—runtime pending (selected-tab semantics and tap handling; Arabic/English width and keyboard focus pending) |
| `lib/features/player/widgets/championship_details/championship_rules_tab.dart` | player | source reviewed—runtime pending (long rules content is scrollable; localized headings and long-text rendering pending) |
| `lib/features/player/widgets/championship_details/championship_standings_table.dart` | player | source reviewed—runtime pending (cached per-group FutureBuilder; parent refresh version invalidates cache; loading/error/empty states with retry; group index bounded) |
| `lib/features/player/widgets/championship_details/championship_top_scorers_tab.dart` | player | source reviewed—runtime pending (FutureBuilder loading/error/empty states with retry; scorer rank and goals presentation) |

## Latest grouped source remediation — 2026-10-31

| Surface | Source change | Status |
|---|---|---|
| `lib/features/owner/widgets/ledger/owner_payout_dialog.dart` | Async payout failure feedback now checks `context.mounted` before reusing the dialog context. | source reviewed—runtime pending |
| `lib/features/player/widgets/add_player_sheet.dart` | Dynamic localized invite label is non-const; its static TextStyle is const to satisfy the analyzer. | source reviewed—runtime pending |
| `lib/features/player/widgets/all_stadiums/all_stadiums_filter_sheet.dart` | Restored the missing close delimiter in the nested safe-area/scroll container. | source reviewed—runtime pending |
| `lib/features/player/screens/challenge_select_team_screen.dart` | Retry guard now uses an explicit block. | source reviewed—runtime pending |
| `lib/core/providers/auth_provider.dart` | Removed the write-only user-fetch flag and assignments. | source reviewed—runtime pending |
| `lib/shared/widgets/date_picker/vsp_date_picker_step_views.dart` | Simplified the day semantic label without changing the displayed day value. | source reviewed—runtime pending |
| `lib/features/owner/screens/owner_dashboard_screen.dart` | Removed the hardcoded Pro monthly price from the upgrade teaser; live price remains on the plan-catalog screen. | source reviewed—runtime pending |

The source fixes above are not runtime passes. The 199 unique registered paths still require the complete applicable-rule/state mapping and one final device/runtime validation pass.


### Additional shared upload surface inspected

| Component | Role | Source finding / status |
|---|---|---|
| `lib/shared/widgets/vsp_upload_widgets.dart` | shared | source reviewed—runtime pending (upload action semantics/ink response; localized 48dp delete action; blank thumbnail URLs treated as absent) |


### Additional booking surface source review

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/user_bookings/open_join_booking_card.dart` | player | source reviewed—runtime pending (zero-capacity state now displays Full rather than Open to join; terminal-state, host, joined, and pending status precedence reviewed) |

### Team-league embedded surfaces reviewed in this continuation

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/league/team_league_onboarding_card.dart` | player | source reviewed—runtime pending (bilingual onboarding/features/actions; team-entry fee comes from configured value) |
| `lib/features/player/widgets/league/team_league_gathering_card.dart` | player | source reviewed—runtime pending (bilingual gathering/progress/share copy; fee text uses configured entry-fee value) |
| `lib/features/player/widgets/league/team_league_standings_view.dart` | player | source reviewed—runtime pending (bilingual league detail/standings labels; long title and metadata rows bounded) |
| `lib/features/player/widgets/league/team_league_fixtures_view.dart` | player | source reviewed—runtime pending (bilingual fixture/status copy; dates use active locale; result entry waits for booking and scheduled kickoff; server-side gate remains approval-required) |

### Additional player/owner/authentication surfaces reviewed and refined — 2026-10-31

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/auth/screens/signup_screen.dart` | auth | source reviewed—runtime pending (removed raw auth-error debug logging; localized validation feedback retained) |
| `lib/features/auth/screens/player_onboarding_screen.dart` | player | source reviewed—runtime pending (exit confirmation scrollable; form already SafeArea/scroll bounded) |
| `lib/features/auth/widgets/owner_onboarding/owner_onboarding_exit_dialog.dart` | owner | source reviewed—runtime pending (exit confirmation scrollable) |
| `lib/features/owner/screens/owner_ledger_screen.dart` | owner | source reviewed—runtime pending (export failure copy no longer exposes platform exception) |
| `lib/features/owner/screens/owner_profile_screen.dart` | owner | source reviewed—runtime pending (sign-out confirmation scrollable) |
| `lib/features/player/screens/profile_screen.dart` | player | source reviewed—runtime pending (sign-out confirmation scrollable; existing profile avatar source retained) |
| `lib/features/player/screens/championship_checkout_screen.dart` | player | source reviewed—runtime pending (roster validation and paste feedback bilingual; post-dialog mounted guard; registration errors sanitized) |
| `lib/features/player/screens/championship_details_screen.dart` | player | source reviewed—runtime pending (error dialog scrollable) |
| `lib/features/player/screens/match_details_screen.dart` | player | source reviewed—runtime pending (match-leave exception localized and sanitized) |
| `lib/features/player/screens/matchup_live_dashboard_screen.dart` | player | source reviewed—runtime pending (load failure distinct from empty state with retry; bilingual result/closure feedback; scrollable close confirmation) |
| `lib/features/owner/screens/create_tournament_wizard.dart` | owner | source reviewed—runtime pending (creation exception localized and sanitized) |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | source reviewed—runtime pending (team-list failure distinct from empty roster with retry; kickoff async lifecycle guard and scrollable confirmation) |
| `lib/features/player/screens/profile_subscreens/edit_profile_screen.dart` | player | source reviewed—runtime pending (profile save/delete errors are localized and sanitized; delete confirmation scrollable) |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | source reviewed—runtime pending (participating-team lookup failure has retry; kickoff async state guarded)
`lib/features/owner/widgets/account/owner_delete_account_card.dart` | owner | source reviewed—runtime pending (scrollable password-confirmed deletion dialog; password controller disposed; reauthentication/delete failures recover safely) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | source reviewed—runtime pending (emergency closure confirmation scrollable; success states 24-hour closure without implying immediate refund; failures localized)
`lib/features/player/widgets/matchup/matchup_record_result_card.dart` | player | source reviewed—runtime pending (result entry card bilingual; heading bounded) |
| `lib/features/player/widgets/matchup/matchup_results_timeline.dart` | player | source reviewed—runtime pending (empty state, fallbacks, and outcome labels bilingual; row labels bounded) |
| `lib/features/player/widgets/matchup/matchup_standings_table.dart` | player | source reviewed—runtime pending (standings and points explanation bilingual; stats constrained on narrow rows) |
| `lib/features/player/services/matchup_dashboard_service.dart` | player | source reviewed—runtime pending (validation and outcome presentation localized; scoring values unchanged)
`lib/features/owner/widgets/brackets/score_modal/penalty_shootout_section.dart` | owner | source reviewed—runtime pending (penalty labels and fallback team names localized)
`lib/features/owner/widgets/brackets/tournament_round_auto_schedule_sheet.dart` | owner | source reviewed—runtime pending (reset confirmation scrollable; Arabic copy corrected; reset failure now has localized feedback)
`lib/features/player/widgets/championship_checkout/checkout_guest_players_section.dart` | player | source reviewed—runtime pending (clipboard import action labeled “Paste/لصق”; no WhatsApp-specific dependency implied) |
| `lib/features/player/widgets/roster/roster_guest_players_section.dart` | player | source reviewed—runtime pending (clipboard import action labeled “Paste/لصق”; no WhatsApp-specific dependency implied)
`lib/core/utils/roster_parser_utils.dart` | shared/player | source reviewed—runtime pending (manual import dialog disposes its text controller; dialog remains scrollable)
`lib/features/player/widgets/stadium_details/stadium_image_carousel.dart` | player | source reviewed—runtime pending (fullscreen gallery page indicator now respects bottom system inset; top controls already use SafeArea) |

## Newly discovered embedded UI components — 2026-11-01

| `lib/features/owner/widgets/tournament/tournament_dashboard_bottom_bar.dart` | player/owner | source reviewed—runtime pending (status-gated owner actions, nullable kickoff callback, fixture navigation disabled during async actions, champion summary, bottom inset) |
| `lib/features/owner/widgets/tournament/wizard/tournament_basics_step.dart` | player/owner | source reviewed—runtime pending (editable-field gates, sport/format selection, bilingual labels, controller ownership external) |
| `lib/features/owner/widgets/tournament/wizard/tournament_scheduling_step.dart` | player/owner | source reviewed—runtime pending (date/duration/prize edit gates, numeric input direction, scroll handled by parent wizard) |
| `lib/features/owner/widgets/tournament/wizard/tournament_step_indicator.dart` | player/owner | source reviewed—runtime pending (three-step progress semantics and bilingual labels; narrow-width text fit still needs device review) |
| `lib/features/owner/widgets/tournament/wizard/tournament_system_step.dart` | player/owner | source reviewed—runtime pending (team/group/qualifier/legs controls gated by editable policy; static option values) |
| `lib/features/owner/widgets/tournament/wizard/tournament_wizard_bottom_bar.dart` | player/owner | source reviewed—runtime pending (back and next/save actions disabled during async save; bottom system inset reviewed) |
| `lib/features/player/widgets/booking/booking_bottom_bar.dart` | player/owner | source reviewed—runtime pending (collective booking displays full total without deposit-only hint; currency suffix normalized to EGP; player counter +/- controls enforce 48dp minimum targets; optional ball and confirm disabled without slot/loading; compact-width runtime review pending) |
| `lib/features/player/widgets/champion/champion_empty_state.dart` | player/owner | source reviewed—runtime pending (shared charcoal square icon tile, scrollable content, localized empty-state copy with optional explicit locale override, optional return action with RTL-aware directional spacing) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_empty_states.dart` | player/owner | source reviewed—runtime pending (charcoal empty-state tile, governorate prompt, banner hit target; fixed broken edit-profile navigation by registering route and using GoRouter; 1v1 empty-state copy now passes its explicit locale input through to the shared empty-state renderer and the home-governorate banner localizes the governorate label) |
| `lib/features/player/widgets/champion/champion_podium_components.dart` | player | source reviewed—runtime pending (localized governorate/sport filter labels, podium rank and team identity presentation, network-image fallback) |
| `lib/features/player/widgets/champion/championships_list_tab.dart` | player | source reviewed—runtime pending (championship stream loading/error/empty states; preserves last data and shows retry warning on realtime failure; All locations no longer triggers a false other-governorate banner) |
| `lib/features/player/widgets/champion/teams_ranking_tab.dart` | player | source reviewed—runtime pending (team ranking filter and podium/list states; preserves last ranking snapshot and surfaces retry warning after stream failure) |
| `lib/features/player/widgets/champion/vsp_1v1_league_tab.dart` | player | source reviewed—runtime pending (1v1 tournament and roster stream loading/error/stale states; payment and cancellation lifecycle unchanged) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_hero_card.dart` | player | source reviewed—runtime pending (localized tournament name and governorate, capacity counts, and bounded progress value) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_prize_card.dart` | player | source reviewed—runtime pending (entry fee and prize values displayed from supplied server data with EGP localization) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_registration_action_card.dart` | player | source reviewed—runtime pending (registration/refund/location states; 48dp cancel/switch actions and disabled join action with loading feedback while payment is processing) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_roster_list.dart` | player | source reviewed—runtime pending (server-confirmed roster presentation, localized player-name fallback, and empty state; avatar loading/network failures render the player's initial) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_standings_view.dart` | player | source reviewed—runtime pending (standings loading/error/empty states; uses parent retry and preserves last data with stale warning) |

