# UXLP-44 Screen Coverage Register

This register is the inventory of Dart files whose names indicate screens, pages, dialogs, sheets, modals, or popups in the current repository tree. It is a starting inventory, not proof that every UI surface is represented: embedded widgets and state variants must also be discovered from call sites.

- Base: current branch `uxlp-44-implementation` (inventory refreshed 2026-11-01)
- Registered Dart screen/surface and embedded-component paths: 338 unique paths
- Additional shared navigation component entry: 1
- Table data rows: 366, including 28 repeated paths that document separate embedded-component findings (recounted from the current register table on 2026-11-01)
- Current status: inventory updated; detailed per-rule and per-state inspection remains incomplete.
- Current global UXLP-44 matrix: 39 rules are source-reviewed/runtime-pending and 5 rules (25, 31, 38, 39, 41) are classified as `needs product decision`; no rule has a runtime pass. The full per-screen/per-state matrix remains incomplete.
- Historical static source scan: 128 candidate files were fetched and scanned for legacy/V2 token imports, raw color and text-style declarations, hard-coded motion durations, SafeArea/useSafeArea markers, and modal entry points. That scan covered 128 of the 215 paths registered at the time; it has not been rerun across the current 338-path register.
- Current static triage — 2026-11-01: the PR diff additions were scanned across **356 changed Dart files**; 304 of the 338 registered paths are now changed by this PR. At the time of the initial full-file sweep, 69 registered paths were unchanged and all 69 were fetched/scanned in full; 35 have since been modified by the resulting fixes, leaving 34 registered paths unchanged. The initial full-file sweep found 28 raw-color files, six physical left/right geometry occurrences across five files, and ten inline duration/delay values across seven files; these were corrected. A targeted full-file review of eight additional high-traffic screens found four more raw-color paths, one inline 200ms duration, and one Arabic-only retry label; all were corrected. Nineteen additional changed surfaces had raw color references corrected. The post-fix diff scan found no raw Flutter color literals or physical left/right geometry in Dart additions; remaining literal Text matches are dynamic numeric/data labels, not hardcoded UI copy.
- Static-scan limitation: the 356-file diff scan covers changed hunks/additions, not every unchanged line in the 304 registered paths touched by the PR. The 69 full-file checks provide deeper coverage for those paths but do not turn the diff scan into a full-file review of all 338 paths. This is not runtime proof. The per-screen/per-state 44-rule mapping and device validation remain incomplete.
- Static scan is triage evidence only. No screen has been marked pass from source heuristics; parent route behavior, modal constraints, runtime overflow, Arabic/English rendering, and actual state coverage still require direct verification.
- Status values: not yet inspected / source reviewed—runtime pending / pass / fail / needs product decision / not applicable.
- Do not mark a file complete until Arabic and English, role, loading/empty/error/success states, keyboard, safe area, and navigation have been considered where applicable.

| File | Role | Status |
|---|---|---|
| `lib/core/navigation/offline_error_screen.dart` | player/owner | source reviewed—runtime pending (safe-area + primary action updated) |
| `lib/core/navigation/root_screen.dart` | player/owner | source updated—runtime pending (profile-loading timeout now starts/cancels with authenticated user identity, including sign-in after RootScreen mount; stale timer cannot mark a different account; runtime transition verification pending) |
| `lib/core/navigation/suspended_account_screen.dart` | player/owner | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/auth/screens/create_account_screen.dart` | player/owner | source updated—runtime pending (safe-area protected scroll layout; decorative glow now uses directional end positioning for RTL/LTR) |
| `lib/features/auth/screens/login_screen.dart` | player/owner | source reviewed—runtime pending (keyboard-aware SafeArea scroll layout; removed duplicate bottom system inset; forgot-password alignment follows RTL/LTR direction) |
| `lib/features/auth/screens/owner_onboarding_screen.dart` | player/owner | source reviewed—runtime pending (safe-area form and sticky footer; async location/date callbacks guarded against disposal) |
|| `lib/features/auth/screens/player_onboarding_screen.dart` | auth | source reviewed—runtime pending (scrollable exit dialog; continue/cancel actions minimum 48dp; onboarding content protected by SafeArea) |
| `lib/features/auth/screens/select_role_screen.dart` | player/owner | source reviewed—runtime pending (localized, scroll-safe, accessible role cards) |
| `lib/features/auth/screens/set_new_password_screen.dart` | player/owner | source reviewed—runtime pending (app-bar body avoids duplicate top safe inset) (safe-area protected form scroll layout) |
| `lib/features/auth/screens/signup_screen.dart` | auth | source reviewed—runtime pending (system bottom safe-area wrapper; GPS auto-detect 48dp target with localized tooltip) |
| `lib/features/auth/screens/splash_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected) |
| `lib/features/auth/screens/verify_email_screen.dart` | player/owner | source reviewed—runtime pending (safe-area protected responsive OTP row; duplicate verify guarded; verify/resend exceptions restore controls with localized retry feedback; successful verification is not masked by local email-cleanup failure) |
| `lib/features/auth/screens/welcome_screen.dart` | auth | source reviewed—runtime pending (top/bottom controls protected by SafeArea; Skip target minimum 48dp; next-page control 54dp) |
| `lib/features/auth/widgets/forgot_password_dialog.dart` | player/owner | source updated—runtime pending (scrollable on compact/keyboard layouts; cancel and submit actions meet 48dp minimum height) (explicit showDialog SafeArea enabled; keyboard/layout still needs runtime check) |
|| `lib/features/auth/widgets/owner_onboarding/owner_onboarding_exit_dialog.dart` | auth | source updated—runtime pending (scrollable exit dialog; continue/cancel actions minimum 48dp; default showDialog safe-area protection) |
| `lib/features/copilot/screens/copilot_test_playground.dart` | shared | source reviewed—runtime pending (body bottom safe-area protected) |
| `lib/features/copilot/screens/vsp_copilot_screen.dart` | shared | source reviewed—runtime pending (owner-only screen gate; chat body and composer safe-area protected) |
| `lib/features/copilot/screens/vsp_copilot_sheet.dart` | shared | source reviewed—runtime pending (bottom sheet useSafeArea enabled; content handles keyboard insets; assistant loading bubble and stadium navigation cue now mirror directionally and have Arabic/English copy) |
| `lib/features/owner/screens/add_stadium_wizard.dart` | owner | source reviewed—runtime pending (app-bar body no longer double-counts the top safe inset; wizard scrolling, fixed action-bar insets, form lifecycle, and screen-state layout reviewed) |
| `lib/features/owner/screens/create_tournament_wizard.dart` | owner | source reviewed—runtime pending (wizard layout reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/screens/facility_onboarding_screen.dart` | owner | source updated—runtime pending (SafeArea wraps onboarding states; Supabase auth ID reads corrected to User.id; initial stadium-stream failure shows localized retry instead of a false empty state; stale loaded stadiums remain visible with retry warning; shared VSPErrorState import added after monitored compile diagnostic; runtime pending) |
| `lib/features/owner/screens/owner_account_management_screen.dart` | owner | source reviewed—runtime pending (form lifecycle reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/screens/owner_bookings_screen.dart` | owner | source reviewed—runtime pending (stadium, booking, and owner-scope loading branches use shared bilingual VSPStateView; streams distinguish loading/error from empty/free; owner stream reloads on authenticated owner-scope changes) |
| `lib/features/owner/widgets/bookings/owner_bookings_filter_bar.dart` | owner | source reviewed—runtime pending (horizontal day-strip spacing now uses directional end margin so the calendar spacing mirrors in RTL/LTR; 60×80dp day targets remain comfortably above minimum) |
| `lib/features/owner/screens/owner_cup_screen.dart` | owner | source reviewed—runtime pending (cup list uses shared bottom-navigation scroll padding; auth ID read corrected to User.id) |
| `lib/features/owner/screens/owner_dashboard_screen.dart` | owner | source reviewed—runtime pending (nested under OwnerMainScreen SafeArea; dashboard does not repeat the parent top inset and retains its own bottom system protection; bottom nav owns system bottom inset) (analytics errors localized with retry; stale responses invalidated by request generation; tab switcher meets 48dp minimum height) |
| `lib/features/owner/screens/owner_documentation_wizard.dart` | owner | source reviewed—runtime pending (wizard flow and safe-area layout reviewed; body below app bar no longer double-counts the top safe inset; Supabase auth ID reads corrected to User.id; upload failures show localized retry guidance instead of raw exceptions; cancel-upload and under-review dialogs are scrollable on compact/large-text screens) |
| `lib/features/owner/screens/owner_inbox_screen.dart` | owner | source reviewed—runtime pending (initial conversation stream failure or error after an empty snapshot now shows localized retry instead of false empty state; refresh failure preserves loaded conversations with stale-data warning; shared bottom-navigation scroll padding) |
| `lib/features/owner/screens/owner_ledger_screen.dart` | owner | source reviewed—runtime pending (system safe-area wrapper; initial transaction-stream failure has localized retry; refresh preserves loaded transactions with stale-data warning; financial-summary failure no longer throws unhandled or presents an unverified zero balance; retry reloads summary) |
| `lib/features/owner/screens/owner_main_screen.dart` | owner | source reviewed—runtime pending (top safe-area protected; floating nav preserved; account-verification dialog scroll-safe; deferred celebration listener now guards disposal lifecycle) |
| `lib/features/owner/screens/owner_profile_screen.dart` | owner | source reviewed—runtime pending (profile/role flow reviewed; Supabase auth ID access corrected to User.id) |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | source reviewed—runtime pending (wizard scrolling, fixed action-bar insets, form lifecycle, and screen-state layout reviewed) |
| `lib/features/owner/screens/subscription_plans_screen.dart` | owner | source reviewed—runtime pending (plan prices, trial days, stadium limits, descriptions, and feature flags now load from public_subscription_plans; monthly/annual choices use server billing periods; retry state on read failure) |
| `lib/features/owner/screens/tournament_brackets_screen.dart` | owner | source updated—runtime pending (system safe-area wrapper; initial bracket load error is bilingual with retry; previously loaded brackets/standings remain visible with localized stale-data warning and retry after stream failure) |
| `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart` | owner | source reviewed—runtime pending (sheet now uses safe-area, keyboard-aware scroll container, and bottom inset) (preferred 88% content cap now relies on route keyboard-safe constraints instead of subtracting system/keyboard insets twice) |
| `lib/features/owner/widgets/add_stadium/add_stadium_location_picker_sheet.dart` | owner | source reviewed—runtime pending (manual-address controller lifecycle and keyboard/bottom safe area; GPS lookup failure is localized and sheet-state updates are guarded after disposal) (manual-address sheet no longer adds keyboard viewInset twice; system bottom inset retained) |
| `lib/features/owner/widgets/add_stadium/stadium_wizard_dialogs.dart` | owner | source updated—runtime pending (explicit showDialog SafeArea on discard and stadium-hide confirmations; scrollable content and 48dp actions retained; runtime deferred) |
| `lib/features/owner/widgets/add_stadium/stadium_wizard_steps_pager.dart` | owner | source reviewed—runtime pending (step pager and page composition reviewed; child steps are independently scrollable) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_action_panels.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | source reviewed—runtime pending (reschedule request now shows backend failure; confirmation/destructive actions and safe-area remain runtime pending) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_cancel_dialog.dart` | owner | source updated—runtime pending (owner cancellation dialogs now explicitly use SafeArea; existing 48dp action targets retained; runtime/keyboard verification pending)  (48dp action targets added; refund/penalty decision semantics unchanged) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_details_form.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_duration_selector.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_form_fields.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_header.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_time_stadium_card.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_whatsapp_utils.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/booking_sheet/owner_booking_modal.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_service.dart` | owner | source reviewed—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/goal_scorers_section.dart` | owner | source updated—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/penalty_shootout_section.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/roster_list_viewer.dart` | owner | source updated—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/score_modal/score_counter_column.dart` | owner | source updated—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/brackets/tournament_auto_schedule_modal_sheet.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) (preferred 88% content cap respects route viewport; removed duplicate keyboard/system inset subtraction and unsafe 240dp minimum) |
| `lib/features/owner/widgets/brackets/tournament_round_auto_schedule_sheet.dart` | owner | source updated—runtime pending (confirmation AlertDialog uses standard safe-area route) |
| `lib/features/owner/widgets/brackets/tournament_score_modal.dart` | owner | source reviewed—runtime pending (score submission has a handler-level duplicate-submit guard and logs diagnostics and retains localized recovery copy; score title and fields are width-bounded) |
| `lib/features/owner/widgets/documentation/doc_image_source_sheet.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/documentation/doc_under_review_dialog.dart` | owner | source updated—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/documentation/doc_wizard_dialogs.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/documentation/doc_wizard_steps_pager.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/facility_onboarding/facility_upgrade_bottom_sheet.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/ledger/owner_payout_dialog.dart` | owner | source updated—runtime pending (explicit SafeArea for both payout dialogs; scrollable keyboard-aware content retained; cancel/submit controls now minimum 48dp; runtime/keyboard verification deferred) |
| `lib/features/owner/widgets/owner_booking_sheet.dart` | owner | source updated—runtime pending (owner booking actions, form composition, duration constraints, controller lifecycle, and safe-area handling reviewed) |
| `lib/features/owner/widgets/quick_booking/quick_booking_receipt_sheet.dart` | owner | source reviewed—runtime pending (score-entry components, document upload states, tournament preview, and invite surfaces reviewed) |
| `lib/features/owner/widgets/quick_phone_booking_modal.dart` | owner | source reviewed—runtime pending (metadata is width-bounded; unknown save failures use safe localized copy and diagnostic logging) |
| `lib/features/owner/widgets/tournament/cups/owner_cup_format_modal.dart` | owner | source reviewed—runtime pending (format selection sheet now has viewport-bounded scrollable content; tournament preview and invite surfaces remain runtime pending) |
| `lib/features/owner/widgets/tournament/tournament_bracket_preview_dialog.dart` | owner | source updated—runtime pending (both bracket preview/live-draw dialogs now constrain content height to compact viewports and keep primary actions at 48dp; showDialog default safe-area behavior retained) |
| `lib/features/owner/widgets/tournament/tournament_dashboard_dialogs.dart` | owner | source reviewed—runtime pending (dialog/sheet constraints, action state, async lifecycle, and controller ownership reviewed) |
| `lib/features/owner/widgets/tournament/tournament_manual_team_sheet.dart` | owner | source reviewed—runtime pending (manual-team section label uses directional start padding for correct Arabic/English mirroring) (manual registration errors are localized; technical failures logged; Supabase auth ID uses User.id) |
| `lib/features/owner/widgets/tournament/tournament_prize_delivery_dialog.dart` | owner | source updated—runtime pending (notes controller is disposed after modal close; prize-handover failure copy is localized and technical details stay in diagnostics) |
| `lib/features/player/screens/all_stadiums_screen.dart` | player | source reviewed—runtime pending (bottom safe-area; stadium list distinguishes loading/empty/error/stale data; sort action now uses a 48dp minimum target; filter sheet is scrollable, keyboard-aware, and safe-area protected) |
| `lib/features/player/screens/booking_confirmation_screen.dart` | player | source reviewed—runtime pending (AppBar and sticky booking bottom bar; verify bottom bar safe inset at runtime) |
| `lib/features/player/widgets/booking/booking_date_selector.dart` | player | source reviewed—runtime pending (horizontal date-strip start padding and inter-item spacing now use directional insets for RTL/LTR; 60×70dp date targets) |
| `lib/features/player/screens/booking_success_screen.dart` | player | source reviewed—runtime pending (success receipt scrolls inside SafeArea; booking-reference copy control has a localized tooltip and 48×48dp hit target; primary/secondary actions exceed 48dp) |
| `lib/features/player/screens/bookings_screen.dart` | player | source reviewed—runtime pending (initial load uses bilingual shared loading state; error/empty states retained; AppBar owns top system inset without duplicate body padding; refresh awaits server response and preserves cached list with localized retry warning) |
| `lib/features/player/screens/challenge_select_team_screen.dart` | player | source reviewed—runtime pending (team/challenge loading, empty and error states; lookup handler guards duplicate submissions; challenge-code lookup action now meets 48dp minimum height; create-team sheet safe-area protected; generated challenge-code sheet is viewport-bounded, scrollable, bottom-safe, and has 48dp copy/share actions) |
| `lib/features/player/screens/champion_screen.dart` | player | source reviewed—runtime pending (championship/teams/1v1 tabs and RTL indicator; governorate and sport filter controls meet 48dp minimum height) |
| `lib/features/player/screens/championship_checkout_screen.dart` | player | source reviewed—runtime pending (scroll body avoids duplicate system insets; sticky VSPBottomActionBar owns bottom safe inset) (checkout layout and insets reviewed; Supabase auth ID reads corrected to User.id) |
| `lib/features/player/widgets/championship_checkout/checkout_financial_card.dart` | player | source reviewed—runtime pending (fee-transparency sheet uses SafeArea and scrollable content; long bilingual title is width-bounded and acknowledgement action meets 48dp minimum height) |
| `lib/features/player/screens/championship_details_screen.dart` | player | source reviewed—runtime pending (strict team lookup; live championship and matches streams can be recreated on retry; stale header data now shows a warning/retry banner) |
| `lib/features/player/screens/chat_screen.dart` | player | source updated—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/faq_and_support_screen.dart` | player | source reviewed—runtime pending (wizard scrolling, fixed action-bar insets, form lifecycle, and screen-state layout reviewed) |
| `lib/features/player/screens/global_search_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area and keyboard-aware scroll layout; shared bilingual loading state; failed searches show localized retry instead of endless loading/no-results; request generations prevent older query results overwriting newer searches) |
| `lib/features/player/screens/manage_tournament_roster_screen.dart` | player | source reviewed—runtime pending (roster load failure now distinct from empty roster with retry; save disabled until verified; raw backend errors hidden) |
| `lib/features/player/screens/match_details_screen.dart` | player | source reviewed—runtime pending (initial match-detail fetch failure now shows a localized retryable error instead of incorrectly presenting “match not found”; loading and error views are safe-area protected; realtime stream failures now preserve loaded match data, show a localized stale-data warning, and recreate the stream on retry; report/join actions remain lifecycle-gated) |
| `lib/features/player/screens/matchup_live_dashboard_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper applied) |
| `lib/features/player/screens/notifications_center_screen.dart` | player | source reviewed—runtime pending (SafeArea list; stream errors now distinct from empty state with retry; informational AlertDialog scroll-safe) |
| `lib/features/player/screens/payment_gateway_screen.dart` | player | source updated—runtime pending (fee policy fails closed; server-created booking is authoritative; account-bound checkout; initialization errors localized without raw backend text) |
| `lib/features/player/screens/paymob_web_view_screen.dart` | player | source reviewed—runtime pending (SafeArea wraps payment web view content) |
| `lib/features/player/screens/player_booking_details_screen.dart` | player | source reviewed—runtime pending (report dialog scroll-safe; report success/failure feedback correct; booking lifecycle statuses localized in Arabic/English) |
| `lib/features/player/screens/player_home_screen.dart` | player | source updated—runtime pending (post-match prompts require participating captain, eligible booking state, and independent opposing captain for second review) |
| `lib/features/player/widgets/home/home_stadiums_section.dart` | player | source reviewed—runtime pending (horizontal home-stadium carousel inter-card spacing now uses directional end margin for RTL/LTR consistency) |
| `lib/features/player/widgets/home/home_feed_sections.dart` | player | source reviewed—runtime pending (match/championship carousels use directional spacing and preserve loaded cards on stream errors; notification badge rebinds on account change, surfaces unread-count failures with a directional warning indicator, and uses localized tooltip) |
| `lib/features/player/screens/profile_screen.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout and safe-area; team-card initial load uses shared bilingual state and verified error/retry; team-card image capture validates render/encoding and disposes the temporary image; controller lifecycle, action states, and consistent profile-avatar fallback across header/no-team card) |
| `lib/features/player/screens/profile_subscreens/edit_profile_screen.dart` | player | source reviewed—runtime pending (app-bar body avoids duplicate top safe inset; bottom inset handled once by scroll padding) (screen/sheet/dialog layout, safe-area, controller lifecycle, and action states reviewed) |
| `lib/features/player/screens/profile_subscreens/favorites_screen.dart` | player | source reviewed—runtime pending (system bottom safe-area wrapper; favorites request is cached by selected IDs, initial fetch errors show localized retry instead of a false empty state) |
| `lib/features/player/screens/profile_subscreens/language_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/screens/profile_subscreens/my_team_screen.dart` | player | source reviewed—runtime pending (team actions reviewed; Supabase auth ID reads corrected to User.id) |
| `lib/features/player/widgets/my_team/team_members_section.dart` | player | source reviewed—runtime pending (captain/member trophy badges and remove-member action spacing now use directional insets for RTL/LTR consistency) |
| `lib/features/player/screens/profile_subscreens/notifications_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/screens/stadium_details_screen.dart` | player | source updated—runtime pending (stadium live stream preserves last known details with retry warning; information/pitch/rating tabs now fill a 48dp row and use InkWell semantics; bottom booking bar applies SafeArea; route-state reuse now refreshes the stadium stream when the stadium ID changes and rebuilds the image gallery from the new stadium metadata; runtime pending) |
| `lib/features/player/screens/support_ticket_screen.dart` | player | source updated—runtime pending (reply and closed-ticket footer controls are bottom SafeArea protected; ticket and message streams distinguish loading/error/empty and expose retry) |
| `lib/features/player/screens/support_tickets_screen.dart` | player | source updated—runtime pending (new-ticket sheet constrains complete padded content including bottom safe-area inside keyboard-safe viewport; scrollable form and single-flight submit; ticket list distinguishes loading/error/empty) (new-ticket sheet no longer double-subtracts keyboard viewInsets; viewport remains scrollable and SafeArea protected) |
| `lib/features/player/screens/team_dashboard_screen.dart` | player | source reviewed—runtime pending (strict team-membership fetch; account-scoped async refresh; separate loading/error/retry from no-team state) |
| `lib/features/player/screens/team_profile_screen.dart` | player | source reviewed—runtime pending (strict team/roster fetches with retry; captain identified by `captain_id`; invite modal opens only after a non-empty successful RPC code) |
| `lib/features/player/screens/terms_and_privacy_screen.dart` | player | source reviewed—runtime pending (system safe-area wrapper applied to screen body) |
| `lib/features/player/screens/tournament_registration_success_screen.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/widgets/add_player_sheet.dart` | player | source reviewed—runtime pending (scrollable content constrained to keyboard/safe-area viewport; responsive two-line title and localized close tooltip; auth ID read corrected to User.id; caller verified: isScrollControlled and useSafeArea enabled; found-player Add action meets 48dp) (modal route owns keyboard-safe viewport; duplicate system/keyboard inset subtraction removed; Add action meets 48dp) |
| `lib/features/player/widgets/all_stadiums/all_stadiums_filter_sheet.dart` | player | source reviewed—runtime pending (success states, roster form, language/notification settings, and modal constraints reviewed) |
| `lib/features/player/widgets/booking/booking_calendar_modal.dart` | player | source updated—runtime pending (explicit showDialog SafeArea; viewport-clamped scrollable calendar retained; keyboard/device runtime deferred) |
| `lib/features/player/widgets/booking/booking_payment_method_sheet.dart` | player | source reviewed—runtime pending (screen/sheet/dialog layout, safe-area, controller lifecycle, and action states reviewed) |
| `lib/features/player/widgets/booking_type_modal.dart` | player | source reviewed—runtime pending (challenge creation now uses strict team lookup; failed membership read shows retry-safe error rather than falsely prompting team creation) |
| `lib/features/player/widgets/championship_details/championship_governorate_dialog.dart` | player | source updated—runtime pending (explicit showDialog SafeArea enabled; cancel action minimum 48×48dp; runtime/keyboard verification intentionally deferred) |
| `lib/features/player/widgets/championship_details/championship_squad_builder_sheet.dart` | player | source reviewed—runtime pending (incomplete-squad bridge and nested add-team sheet use scroll control and SafeArea; team lookup/runtime pending) |
| `lib/features/player/widgets/chat/chat_dialogs.dart` | player | source updated—runtime pending (both dialogs explicitly use SafeArea; all cancel/submit targets at least 48dp; controller lifecycle retained; runtime/keyboard verification deferred) |
| `lib/features/player/widgets/collective_match_invite_sheet.dart` | player | source updated—runtime pending (invite actions reviewed; Supabase auth ID reads corrected to User.id)  (close action has localized tooltip and 48dp target; manual player counters increased to 48dp) |
| `lib/features/player/widgets/create_team_sheet.dart` | player | source reviewed—runtime pending (Arabic/English helper copy, keyboard behavior, async lifecycle, and premature success feedback corrected; auth ID reads use User.id) |
| `lib/features/player/widgets/filter_bottom_sheet.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/home/book_tonight_sheet.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/home/home_governorate_modal.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/home/home_match_outcome_dialogs.dart` | player | source reviewed—runtime pending (captain-scoped team IDs; accurate alternate-result copy; both result dialogs lock during submission and preserve retry on failure) |
| `lib/features/player/widgets/league/team_league_match_dialog.dart` | player | source updated—runtime pending (result/dispute sheets are keyboard-safe and scrollable; visible copy is bilingual; long team labels are bounded; failures use localized recovery copy; result submission is single-flight and result choices are locked while saving) |
| `lib/features/player/widgets/match_result_modal.dart` | player | source reviewed—runtime pending (awaited boolean result; closes only on success; failed submission preserves form for retry; duplicate taps/dismissal guarded) |
| `lib/features/player/widgets/my_team/team_dialogs.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/payment/payment_cancel_dialog.dart` | player | source updated—runtime pending (explicit showDialog SafeArea; existing scrollable copy and 48dp actions retained; runtime deferred)  (48dp dialog actions added; localized copy and checkout callback preserved) |
| `lib/features/player/widgets/payment/payment_verification_modal.dart` | player | source updated—runtime pending (explicit showDialog SafeArea; custom content scrolls and maxHeight clamps to available viewport without unsafe 240dp minimum; runtime check deferred) |
| `lib/features/player/widgets/payment/paymob_still_waiting_dialog.dart` | player | source updated—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/team_profile/team_matchup_invite_modal.dart` | player | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart` | player | source updated—runtime pending (refund amount is not guessed from total_price; distinguishes unpaid, confirmed, and pending server calculation) |
| `lib/shared/dialogs/vsp_terms_and_privacy_modal.dart` | shared | source reviewed—runtime pending (filtering, home booking, match outcome, team lifecycle, payment status, and legal modal flows reviewed) |
| `lib/shared/widgets/match_card/manage_participants_modal.dart` | shared | source reviewed—runtime pending (keyboard-safe height; retryable load error; localized action errors with technical diagnostics; 48dp labeled controls; correct player-facing acceptance notification) |
| `lib/shared/widgets/refund_tracking_sheet.dart` | shared | source reviewed—runtime pending (unknown amount shows server-confirmation state; long timeline is bounded/scrollable and close action includes bottom system inset) |
| `lib/shared/widgets/vsp_date_picker_dialog.dart` | shared | source reviewed—runtime pending (date-picker header padding uses directional start/end values for Arabic/English mirroring) (Dialog safe-area, bounded height, internally scrollable year/day steps) |
| `lib/core/widgets/shimmer_image.dart` | shared | source reviewed—runtime pending (shared shimmer image placeholder; image loading/error caller behavior remains to verify) |
| `lib/core/widgets/skeleton_loader.dart` | shared | source reviewed—runtime pending (CardSkeleton trailing margin uses directional end spacing for RTL/LTR mirroring) |
| `lib/features/auth/widgets/login_social_auth_row.dart` | auth | source reviewed—runtime pending (social sign-in row; provider availability, locale and touch-target verification pending) |
| `lib/features/auth/widgets/owner_onboarding/owner_payout_info_card.dart` | owner | source updated—runtime pending (payout information card; data/locale rendering verification pending) |
| `lib/features/auth/widgets/signup/signup_name_fields.dart` | auth | source reviewed—runtime pending (responsive first/last-name fields; narrow-width behavior source-reviewed) |
| `lib/features/auth/widgets/signup_governorate_dropdown.dart` | auth | source reviewed—runtime pending (localized governorate labels preserve canonical stored values) |
| `lib/features/auth/widgets/social_auth_buttons_row.dart` | auth | source reviewed—runtime pending (shared social-auth controls; provider state and error recovery verification pending) |
| `lib/features/auth/widgets/welcome/scale_animated_button.dart` | auth | source updated—runtime pending (welcome CTA animation and touch target verification pending) |
| `lib/features/auth/widgets/welcome/welcome_language_button.dart` | auth | source reviewed—runtime pending (welcome language selector; RTL and locale-switch behavior pending) |
| `lib/features/auth/widgets/welcome/welcome_onboarding_slide.dart` | auth | source reviewed—runtime pending (onboarding slide layout and localized text overflow verification pending) |
| `lib/features/copilot/widgets/copilot_chat_bubble.dart` | owner | source updated—runtime pending (assistant message/loading bubbles; role gate, localized copy and message overflow verification pending) |
| `lib/features/copilot/widgets/copilot_conversations_drawer.dart` | owner | source updated—runtime pending (conversation drawer; navigation, empty/loading/error and compact-height behavior pending) |
| `lib/features/owner/widgets/account/owner_avatar_header.dart` | owner | source updated—runtime pending (owner avatar/header; profile image fallback and layout verification pending) |
| `lib/features/owner/widgets/account/owner_delete_account_card.dart` | owner | source reviewed—runtime pending (destructive account action; confirmation and consequence copy verification pending) |
| `lib/features/owner/widgets/account/owner_payout_settings_card.dart` | owner | source reviewed—runtime pending (payout settings labels now use directional start padding; locale and form behavior pending) |
| `lib/features/owner/widgets/account/owner_profile_form.dart` | owner | source reviewed—runtime pending (profile labels/help text use directional start padding; field validation and locale verification pending) |
| `lib/features/owner/widgets/account/owner_stadiums_carousel.dart` | owner | source reviewed—runtime pending (stadium carousel item spacing now uses directional end padding; scroll/RTL verification pending) |
| `lib/features/owner/widgets/add_stadium/add_stadium_step1_details.dart` | owner | source reviewed—runtime pending (note-template chip spacing now uses directional end padding; form/keyboard behavior pending) |
| `lib/features/owner/widgets/add_stadium/add_stadium_step1_hours_section.dart` | owner | source updated—runtime pending (opening-hours editor; validation, locale and responsive behavior pending) |
| `lib/features/owner/widgets/add_stadium/add_stadium_step1_location_field.dart` | owner | source reviewed—runtime pending (stadium location input; geolocation, permissions and error recovery verification pending) |
| `lib/features/owner/widgets/add_stadium/add_stadium_step2_features.dart` | owner | source reviewed—runtime pending (feature/amenity selection; amenities heading now uses directional start alignment; responsive option layout and locale behavior pending) |
| `lib/features/owner/widgets/add_stadium/add_stadium_step3_images.dart` | owner | source reviewed—runtime pending (stadium image selection/upload; permission, progress and failure recovery pending) |
| `lib/features/owner/widgets/add_stadium/add_stadium_step_indicator.dart` | owner | source reviewed—runtime pending (stadium wizard step indicator; localized label and narrow-width behavior pending) |
| `lib/features/owner/widgets/brackets/tournament_champion_banner.dart` | owner | source reviewed—runtime pending (champion outcome banner; result data and long team-name rendering pending) |
| `lib/features/owner/widgets/dashboard/insights/insights_booking_types_card.dart` | owner | source reviewed—runtime pending (booking-type insight visualization; source data and empty-state mapping pending) |
| `lib/features/owner/widgets/dashboard/insights/insights_radial_hero_card.dart` | owner | source updated—runtime pending (radial KPI visualization; data bounds and compact-layout verification pending) |
| `lib/features/owner/widgets/dashboard/insights/insights_revenue_sources_card.dart` | owner | source updated—runtime pending (revenue-source metrics; currency/locale and zero-data behavior pending) |
| `lib/features/owner/widgets/dashboard/insights/insights_strategic_kpis_grid.dart` | owner | source updated—runtime pending (strategic KPI grid; responsive density and metric-state verification pending) |
| `lib/features/owner/widgets/dashboard/insights/insights_top_filters_row.dart` | owner | source reviewed—runtime pending (dropdown selected values now align to `AlignmentDirectional.centerEnd`; RTL/LTR and filter behavior pending) |
| `lib/features/owner/widgets/dashboard/owner_basic_financial_glance.dart` | owner | source reviewed—runtime pending (financial summary card; actual Supabase values and zero/error state verification pending) |
| `lib/features/owner/widgets/dashboard/owner_glanceable_timeline.dart` | owner | source reviewed—runtime pending (ongoing marker spacing now uses directional end margin; timeline time/state mapping pending) |
| `lib/features/owner/widgets/dashboard/owner_operational_finance_card.dart` | owner | source reviewed—runtime pending (operational finance card and locked-money preview; actual data/entitlement state verification pending) |
| `lib/features/owner/widgets/dashboard/owner_pro_insights_view.dart` | owner | source reviewed—runtime pending (PRO insights surface; subscription gating and real-data state mapping pending) |
| `lib/features/owner/widgets/dashboard/owner_pro_overview_card.dart` | owner | source reviewed—runtime pending (PRO overview card; plan state and KPI source verification pending) |
| `lib/features/owner/widgets/dashboard/owner_pro_segmented_tabs.dart` | owner | source reviewed—runtime pending (PRO segmented tabs; selected state, keyboard and touch behavior pending) |
| `lib/features/owner/widgets/dashboard/owner_time_period_dropdown.dart` | owner | source reviewed—runtime pending (selected period now uses directional trailing alignment; locale and selection behavior pending) |
| `lib/features/owner/widgets/dashboard/owner_today_pitch_schedule_card.dart` | owner | source updated—runtime pending (today schedule card; time zone, empty and stale-data states pending) |
| `lib/features/owner/widgets/dashboard/owner_venue_filter_chips.dart` | owner | source reviewed—runtime pending (venue filter chips; selection state and scroll behavior pending) |
| `lib/features/owner/widgets/dashboard/owner_verification_banner.dart` | owner | source updated—runtime pending (verification/subscription/grace-period banners; status-specific copy and actions pending) |
| `lib/features/owner/widgets/documentation/doc_explanation_card.dart` | owner | source updated—runtime pending (document-step explanation card; localized instructions and responsive text pending) |
| `lib/features/owner/widgets/documentation/doc_step_commercial_register.dart` | owner | source reviewed—runtime pending (commercial-register document capture; image/file error and permission states pending) |
| `lib/features/owner/widgets/documentation/doc_step_national_id.dart` | owner | source reviewed—runtime pending (national-ID document capture; image/file error and permission states pending) |
| `lib/features/owner/widgets/documentation/doc_step_tax_card.dart` | owner | source reviewed—runtime pending (tax-card document capture; image/file error and permission states pending) |
| `lib/features/owner/widgets/documentation/doc_wizard_step_indicator.dart` | owner | source updated—runtime pending (document wizard progress indicator; locale and narrow-width behavior pending) |
| `lib/features/owner/widgets/ledger/owner_ledger_balance_cards.dart` | owner | source updated—runtime pending (digital balance and pitch-cash cards; real balance source and zero/error state pending) |
| `lib/features/owner/widgets/quick_booking/quick_booking_customer_fields.dart` | owner | source reviewed—runtime pending (quick-booking customer fields; phone validation and optional WhatsApp receipt copy pending) |
| `lib/features/owner/widgets/quick_booking/quick_booking_duration_section.dart` | owner | source reviewed—runtime pending (duration-chip gaps now use directional start spacing in both compact and horizontal layouts) |
| `lib/features/owner/widgets/quick_booking/quick_booking_payment_section.dart` | owner | source reviewed—runtime pending (quick-booking payment section; amount/fee data and state-dependent actions pending) |
| `lib/features/owner/widgets/tournament/cups/owner_cup_card.dart` | owner | source updated—runtime pending (team avatar stack now uses directional start positioning; tournament status/actions and long-title rendering still need runtime review) |
| `lib/features/owner/widgets/tournament/cups/owner_cup_empty_view.dart` | owner | source reviewed—runtime pending (owner cup empty state; neutral icon styling and CTA relevance pending) |
| `lib/features/owner/widgets/tournament/draw_room_matchup_tile.dart` | owner | source reviewed—runtime pending (draw-room matchup tile; team-name overflow and draw-state behavior pending) |
| `lib/features/owner/widgets/tournament/tournament_manual_team_options_section.dart` | owner | source reviewed—runtime pending (section labels and color-option gaps now use directional start/end geometry) |
| `lib/features/owner/widgets/tournament/tournament_manual_team_roster_section.dart` | owner | source reviewed—runtime pending (manual tournament roster section; capacity, duplicate-player and validation feedback pending) |
| `lib/features/owner/widgets/tournament/tournament_overview_card.dart` | owner | source reviewed—runtime pending (tournament overview card; status, dates and action relevance pending) |
| `lib/features/owner/widgets/tournament/tournament_team_card.dart` | owner | source reviewed—runtime pending (tournament team card; roster/registration state and long-name rendering pending) |
| `lib/features/player/widgets/booking/booking_financial_summary.dart` | player | source reviewed—runtime pending (booking financial summary; authoritative server totals, fees and deposit states pending) |
| `lib/features/player/widgets/championship_checkout/checkout_guest_players_section.dart` | player | source reviewed—runtime pending (guest-player checkout section; roster limits, validation and saved data behavior pending) |
| `lib/features/player/widgets/chat/chat_app_bar_title.dart` | player | source reviewed—runtime pending (chat title/participant header; participant state and long-name rendering pending) |
| `lib/features/player/widgets/chat/chat_system_banner.dart` | player | source updated—runtime pending (chat system status banner; lifecycle copy and locale behavior pending) |
| `lib/features/player/widgets/filter/filter_amenities_panel.dart` | player | source updated—runtime pending (amenity filter panel; selected-state and applied-filter consistency pending) |
| `lib/features/player/widgets/filter/filter_category_sidebar.dart` | player | source updated—runtime pending (filter category navigation; active state and RTL order pending) |
| `lib/features/player/widgets/filter/filter_location_panel.dart` | player | source updated—runtime pending (location/governorate filter; localized values and server-filter consistency pending) |
| `lib/features/player/widgets/filter/filter_price_panel.dart` | player | source updated—runtime pending (price/deposit filter; currency, range bounds and query mapping pending) |
| `lib/features/player/widgets/filter/filter_specs_panel.dart` | player | source updated—runtime pending (pitch specification filter; selected state and query mapping pending) |
| `lib/features/player/widgets/filter/filter_sports_panel.dart` | player | source updated—runtime pending (sport filter; option availability and query mapping pending) |
| `lib/features/player/widgets/home/book_tonight_card.dart` | player | source updated—runtime pending (home booking CTA card; eligibility, time-window and navigation behavior pending) |
| `lib/features/player/widgets/home/home_feed_content.dart` | player | source updated—runtime pending (home feed composition; empty/loading/error and source-data mapping pending) |
| `lib/features/player/widgets/matchup/matchup_record_result_card.dart` | player | source reviewed—runtime pending (matchup result card; participant/result state and action visibility pending) |
| `lib/features/player/widgets/my_team/team_achievements_section.dart` | player | source reviewed—runtime pending (team achievements section; actual result source and empty-state behavior pending) |
| `lib/features/player/widgets/my_team/team_action_buttons.dart` | player | source reviewed—runtime pending (team invite/leave/captaincy actions are localized; role/state eligibility and destructive confirmation pending) |
| `lib/features/player/widgets/my_team/team_profile_form.dart` | player | source reviewed—runtime pending (team profile edit fields; validation, image upload and persistence states pending) |
| `lib/features/player/widgets/my_team/team_stats_header.dart` | player | source reviewed—runtime pending (team statistics header; actual result source and empty-data behavior pending) |
| `lib/features/player/widgets/payment/paymob_web_fallback_view.dart` | player | source reviewed—runtime pending (web payment fallback instructions; return/deep-link and paid-state reconciliation pending) |
| `lib/features/player/widgets/roster/roster_capacity_card.dart` | player | source updated—runtime pending (roster capacity indicator; min/max and over-capacity state mapping pending) |
| `lib/features/player/widgets/roster/roster_team_members_section.dart` | player | source reviewed—runtime pending (team-member roster; role labels, guest/member distinction and overflow pending) |
| `lib/features/player/widgets/roster/roster_tournament_header.dart` | player | source reviewed—runtime pending (tournament roster header; registration and payment state mapping pending) |
| `lib/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart` | player | source updated—runtime pending (stadium booking action bar; availability/price state and safe-area reachability pending) |
| `lib/features/player/widgets/stadium_details/stadium_pitch_conditions_tab.dart` | player | source reviewed—runtime pending (pitch condition details; data source, empty state and locale behavior pending) |
| `lib/features/player/widgets/stadium_details/stadium_ratings_tab.dart` | player | source reviewed—runtime pending (review stream now has shared bilingual loading/error states and retry by recreating the stream; stale loaded reviews remain visible with a localized warning and retry action after refresh failure; runtime verification pending) |
| `lib/features/player/widgets/team_profile/team_profile_achievements_section.dart` | player | source reviewed—runtime pending (team achievement list; source result mapping and empty state pending) |
| `lib/features/player/widgets/team_profile/team_profile_action_bar.dart` | player | source reviewed—runtime pending (captain/player action visibility and invite-code loading feedback reviewed; role/state runtime verification pending) |
| `lib/features/player/widgets/team_profile/team_profile_captain_card.dart` | player | source reviewed—runtime pending (captain identity/contact card; privacy and data permission verification pending) |
| `lib/features/player/widgets/team_profile/team_profile_head_to_head_section.dart` | player | source reviewed—runtime pending (head-to-head results; match source and empty/error mapping pending) |
| `lib/features/player/widgets/team_profile/team_profile_hero_header.dart` | player | source reviewed—runtime pending (team hero/header; logo fallback and long-name layout pending) |
| `lib/features/player/widgets/team_profile/team_profile_roster_section.dart` | player | source reviewed—runtime pending (roster loading/error/empty branches and retry callback present; device verification pending) |
| `lib/features/player/widgets/team_profile/team_profile_stats_grid.dart` | player | source reviewed—runtime pending (team stats grid; zero-data and actual-result consistency pending) |
| `lib/features/player/widgets/user_bookings/reschedule_action_banner.dart` | player | source reviewed—runtime pending (reschedule action banner; loading and eligibility copy reviewed; state-driven action runtime verification pending) |
| `lib/features/owner/widgets/inbox/owner_chat_item_card.dart` | owner | source reviewed—runtime pending (conversation preview/time overflow constrained; unread badge and navigation behavior pending) |
| `lib/features/owner/widgets/inbox/user_search_delegate.dart` | owner | source reviewed—runtime pending (user search delegate; query, empty/error and keyboard behavior pending) |
| `lib/features/owner/widgets/ledger/owner_ledger_transaction_item.dart` | owner | source reviewed—runtime pending (ledger transaction row; locale-aware timestamp source and amount formatting pending) |
| `lib/features/owner/widgets/tournament/bracket_preview_canvas.dart` | owner | source reviewed—runtime pending (interactive bracket canvas; pan/zoom, compact viewport and RTL verification pending) |
| `lib/features/owner/widgets/tournament/cups/cups_filter_dropdowns.dart` | owner | source reviewed—runtime pending (cup filters; selection/query mapping and locale behavior pending) |
| `lib/features/owner/widgets/tournament/cups/cups_tab_selector.dart` | owner | source reviewed—runtime pending (cup tab selector; selected-state and RTL navigation pending) |
| `lib/features/player/widgets/championship_checkout/checkout_team_members_list.dart` | player | source reviewed—runtime pending (checkout roster list; team membership, guest distinction and capacity mapping pending) |
| `lib/features/player/widgets/payment/payment_background_glow.dart` | player | source reviewed—runtime pending (payment background decoration; contrast and reduced-motion review pending) |
| `lib/shared/widgets/date_picker/vsp_date_picker_step_chip.dart` | shared | source reviewed—runtime pending (date-picker step chip; accessible selected/disabled state and RTL order pending) |
| `lib/widgets/refund_badge_widget.dart` | shared/player | source updated—runtime pending (refund badge uses localized status/ETA copy; actual refund lifecycle and theme contrast verification pending) |
| `lib/widgets/refund_notice_widget.dart` | shared/player | source reviewed—runtime pending (refund notice uses localized amount/status copy; fee/amount and lifecycle consistency pending) |

## Non-screen UI surfaces still requiring discovery

| Surface path | Role | Status |
|---|---|---|
| `lib/shared/widgets/custom_text_field.dart` | shared | source updated—runtime pending (V2 text-field token migration documented; actual call-site states and locale runtime pending) |
| `lib/shared/widgets/primary_button.dart` | shared | source reviewed—runtime pending (canonical VSPPrimaryButton adapter, haptics and debounce documented; call-site/runtime pending) |
| `lib/shared/widgets/social_auth_button.dart` | shared | source reviewed—runtime pending (V2 semantic button state and 48dp target documented; provider/auth error runtime pending) |
| `lib/shared/widgets/stadium_card.dart` | shared | source reviewed—runtime pending (V2 semantic color/radius migration documented; content-density and locale runtime pending) |
| `lib/shared/widgets/team_card_hero.dart` | shared | source reviewed—runtime pending (responsive minimum-height and flexible stat/footer correction documented; large-text runtime pending) |
| `lib/shared/widgets/vsp_animated_button.dart` | shared | source reviewed—runtime pending (disabled state and finally-based cooldown correction documented; repeat-action runtime pending) |
| `lib/shared/widgets/vsp_back_button.dart` | shared | source updated—runtime pending (48dp hit area and semantic interaction documented; navigation/back-stack runtime pending) |
| `lib/shared/widgets/vsp_bottom_nav_bar.dart` | shared | source reviewed—runtime pending (canonical V2 navigation metrics, semantics, SafeArea, selected/unselected glyphs; optional warning indicator for unavailable badge data) |
| `lib/shared/widgets/vsp_empty_state.dart` | shared | source reviewed—runtime pending (delegates to canonical VSPStateView; bounded scroll-safe layout, charcoal tile, shared typography/spacing, and optional 48dp primary action) |
| `lib/shared/widgets/vsp_error_state.dart` | shared | source reviewed—runtime pending (shared error/retry pattern used by route/state recovery; caller-by-caller verification pending) (connectivity changes update visible offline/server state reactively; live-region announcement) |
| `lib/shared/widgets/vsp_fade_in_item.dart` | shared | source updated—runtime pending (animation lifecycle/disposal reviewed; caller-specific motion and reduced-motion behavior pending) |
| `lib/shared/widgets/vsp_icon_badge.dart` | shared | source reviewed—runtime pending (canonical badge dimensions/background documented; glyph/contrast runtime pending) |
| `lib/shared/widgets/vsp_network_banner.dart` | shared | source reviewed—runtime pending (V2 semantic token migration documented; offline/online overlay placement runtime pending) |
| `lib/shared/widgets/vsp_position_selector.dart` | shared | source reviewed—runtime pending (V2 token migration and 48dp interactive height documented; focus/selection runtime pending) |
| `lib/core/ui/components/vsp_button.dart` | shared | source reviewed—runtime pending (canonical VSPPrimaryButton component source documented; caller/runtime pending) |
| `lib/core/ui/components/vsp_card.dart` | shared | source reviewed—runtime pending (canonical VSPCard and low-performance blur fallback documented; actual card usage/runtime pending) |
| `lib/features/owner/widgets/owner_bottom_nav_bar.dart` | owner | source reviewed—runtime pending (owner navigation selection/semantics/touch height; unread-stream failures now surface a localized warning instead of appearing as zero unread) |
| `lib/shared/widgets/banner_slider_widget.dart` | shared | source updated—runtime pending (REST and realtime banner sources, autoplay/pointer lifecycle, image fallback; optional banner fetch failure hides the carousel without blocking the screen) |
| `lib/shared/widgets/copyable_phone_text.dart` | shared | source updated—runtime pending (long-press copy now has semantic label, localized clipboard failure feedback, and a 48dp minimum hit area; call-site runtime pending) |
| `lib/shared/widgets/public_match_card.dart` | player | source reviewed—runtime pending (cancelled/ended states override host badge and route to booking details, not active invite sheet; join/leave/request/share failures are localized; backend details are logged; RPC JSONB success is now honored so false server results are not shown as success; self-cancel request remains blocked by the current host-only reject RPC and requires an approved caller-owned server RPC; share action retains 48dp target) |
| `lib/shared/widgets/vsp_ai_spark_icon.dart` | shared | source reviewed—runtime pending (custom unequal four-point spark geometry; visual identity and contrast runtime pending) |
| `lib/shared/widgets/vsp_ambient_background.dart` | shared | source updated—runtime pending (shared ambient decoration uses the compatibility token facade; contrast and low-performance rendering pending) |
| `lib/shared/widgets/vsp_auth_header.dart` | shared | source reviewed—runtime pending (shared auth title/back affordance; parent safe-area and keyboard layout pending) |
| `lib/shared/widgets/vsp_countdown_timer.dart` | shared | source reviewed—runtime pending (timer stops at zero, cancels on disposal, and recalculates when targetDate changes; locale/large-text runtime pending) |
| `lib/shared/widgets/vsp_terms_checkbox.dart` | shared | source reviewed—runtime pending (48dp checkbox hit area, checked semantics, and separate terms/privacy link actions; keyboard/focus runtime pending) |
| `lib/shared/widgets/vsp_upload_widgets.dart` | shared | source updated—runtime pending (upload card disabled state and uploaded-item delete action; caller permission/error/confirmation behavior pending) |
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
| `lib/features/player/widgets/user_bookings/pending_booking_card.dart` | player | source reviewed—runtime pending (server-confirmed payment predicate; duplicate-checkout guard; cancel action is hidden while payment confirmation or refund is unresolved, then returns through the confirmed-booking cancellation/refund flow; refreshed status guidance; 48dp cancel target and 48dp check-status/resume-payment actions) |
| `lib/features/player/widgets/user_bookings/player_booking_card.dart` | player | source reviewed—runtime pending (booking lifecycle badges now use actual status; channel-neutral refund-pending copy) |
| `lib/features/player/widgets/match_result_modal.dart` | player | source reviewed—runtime pending (awaited callback, submission lock, disabled dismissal/editing while submitting; close control has localized tooltip and 48dp target) |
| `lib/features/player/widgets/home/home_match_outcome_dialogs.dart` | player | source reviewed—runtime pending (success/failure feedback reflects repository result for submit/confirm/dispute) |
| `lib/features/player/widgets/booking/booking_payment_method_sheet.dart` | player | source reviewed—runtime pending (collective full-online-payment guard; localized failure copy; cash-booking exceptions logged; bounded scroll-safe sheet) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | source reviewed—runtime pending (reschedule failure feedback; destructive closure confirmation) |
| `lib/core/providers/booking/booking_sync_coordinator.dart` | shared | source reviewed—runtime pending (awaited authoritative player booking snapshot; realtime merge behavior preserved) |
| `lib/core/providers/booking/booking_sync_coordinator.dart` | shared | source reviewed—runtime pending (owner/player streams are cancelled before changing scope; owner empty snapshots and direct-fetch errors are delivered explicitly) |
| `lib/core/repositories/team_repository.dart` | shared | source reviewed—runtime pending (H2H query returns null on failure instead of fabricated zero-match statistics) (added lookup for all teams captained by the current user to support multi-team result eligibility) |
| `lib/core/providers/booking_provider.dart` | shared | source reviewed—runtime pending (dedicated player/owner loading states; owner empty/error snapshot handling; concurrent refresh counters) |


### Additional embedded league surface inspected

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/league/team_league_tab.dart` | player | source reviewed—runtime pending (creation/join/payment/stadium/cancel flows bilingual; both modal controllers disposed; join dialog scrolls with keyboard; safe-area handling; configured fee labels; cancellation copy excludes non-refundable administrative fees; raw errors replaced with localized recovery) |


### Additional payment surfaces inspected

| Component | Role | Source finding / status |
|---|---|---|
| `lib/features/player/widgets/payment/payment_breakdown_card.dart` | player | source updated—runtime pending (server-matching fee policy; no false zero; localized retry; fee-info action has 48dp touch target) |
| `lib/features/player/widgets/payment/payment_countdown_header.dart` | player | source updated—runtime pending (base amount is not labeled as final total when fee policy is unavailable) |
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
| `lib/features/player/widgets/add_player_sheet.dart` | Dynamic localized invite label is non-const; its static TextStyle is const to satisfy the analyzer. | source reviewed—runtime pending (modal route owns keyboard-safe viewport; duplicate system/keyboard inset subtraction removed; Add action meets 48dp) |
| `lib/features/player/widgets/all_stadiums/all_stadiums_filter_sheet.dart` | Restored the missing close delimiter in the nested safe-area/scroll container. | source reviewed—runtime pending |
| `lib/features/player/screens/challenge_select_team_screen.dart` | Retry guard now uses an explicit block. | source reviewed—runtime pending (challenge H2H query failure is now distinct from a genuine zero-match history and shows a localized error state) |
| `lib/core/providers/auth_provider.dart` | Removed the write-only user-fetch flag and assignments. | source reviewed—runtime pending |
| `lib/shared/widgets/date_picker/vsp_date_picker_step_views.dart` | Simplified the day semantic label without changing the displayed day value. | source reviewed—runtime pending |
| `lib/features/owner/screens/owner_dashboard_screen.dart` | Removed the hardcoded Pro monthly price from the upgrade teaser; live price remains on the plan-catalog screen. | source reviewed—runtime pending (nested under OwnerMainScreen SafeArea; dashboard does not repeat the parent top inset and retains its own bottom system protection; bottom nav owns system bottom inset) |

The source fixes above are not runtime passes. The 199 unique registered paths still require the complete applicable-rule/state mapping and one final device/runtime validation pass.


### Additional shared upload surface inspected

| Component | Role | Source finding / status |
|---|---|---|
| `lib/shared/widgets/vsp_upload_widgets.dart` | shared | source updated—runtime pending (upload action semantics/ink response; localized 48dp delete action; blank thumbnail URLs treated as absent) |


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
| `lib/features/auth/widgets/owner_onboarding/owner_onboarding_exit_dialog.dart` | owner | source updated—runtime pending (exit confirmation scrollable) |
| `lib/features/owner/screens/owner_ledger_screen.dart` | owner | source reviewed—runtime pending (export failure copy no longer exposes platform exception) |
| `lib/features/owner/screens/owner_profile_screen.dart` | owner | source reviewed—runtime pending (sign-out confirmation scrollable) |
| `lib/features/player/screens/profile_screen.dart` | player | source reviewed—runtime pending (sign-out confirmation scrollable; existing profile avatar source retained) |
| `lib/features/player/screens/championship_checkout_screen.dart` | player | source reviewed—runtime pending (scroll body avoids duplicate system insets; sticky VSPBottomActionBar owns bottom safe inset) (roster validation and paste feedback bilingual; post-dialog mounted guard; registration errors sanitized) |
| `lib/features/player/screens/championship_details_screen.dart` | player | source reviewed—runtime pending (error dialog scrollable) |
| `lib/features/player/screens/match_details_screen.dart` | player | source reviewed—runtime pending (match-leave exception localized and sanitized) |
| `lib/features/player/screens/matchup_live_dashboard_screen.dart` | player | source reviewed—runtime pending (load failure distinct from empty state with retry; bilingual result/closure feedback; scrollable close confirmation) |
| `lib/features/owner/screens/create_tournament_wizard.dart` | owner | source reviewed—runtime pending (creation exception localized and sanitized) |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | source reviewed—runtime pending (team-list failure distinct from empty roster with retry; kickoff async lifecycle guard and scrollable confirmation) |
| `lib/features/player/screens/profile_subscreens/edit_profile_screen.dart` | player | source reviewed—runtime pending (app-bar body avoids duplicate top safe inset; bottom inset handled once by scroll padding) (profile save/delete errors are localized and sanitized; delete confirmation scrollable) |
| `lib/features/owner/screens/owner_tournament_dashboard_screen.dart` | owner | source reviewed—runtime pending (participating-team lookup failure has retry; kickoff async state guarded) |
`lib/features/owner/widgets/account/owner_delete_account_card.dart` | owner | source reviewed—runtime pending (scrollable password-confirmed deletion dialog; password controller disposed; reauthentication/delete failures recover safely) |
| `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart` | owner | source reviewed—runtime pending (emergency closure confirmation scrollable; success states 24-hour closure without implying immediate refund; failures localized) |
`lib/features/player/widgets/matchup/matchup_record_result_card.dart` | player | source reviewed—runtime pending (result entry card bilingual; heading bounded) |
| `lib/features/player/widgets/matchup/matchup_results_timeline.dart` | player | source reviewed—runtime pending (empty state, fallbacks, and outcome labels bilingual; row labels bounded) |
| `lib/features/player/widgets/matchup/matchup_standings_table.dart` | player | source updated—runtime pending (standings and points explanation bilingual; stats constrained on narrow rows) |
| `lib/features/player/services/matchup_dashboard_service.dart` | player | source reviewed—runtime pending (validation and outcome presentation localized; scoring values unchanged) |
`lib/features/owner/widgets/brackets/score_modal/penalty_shootout_section.dart` | owner | source reviewed—runtime pending (penalty labels and fallback team names localized)
`lib/features/owner/widgets/brackets/tournament_round_auto_schedule_sheet.dart` | owner | source reviewed—runtime pending (reset confirmation scrollable; Arabic copy corrected; reset failure now has localized feedback)
`lib/features/player/widgets/championship_checkout/checkout_guest_players_section.dart` | player | source reviewed—runtime pending (clipboard import action labeled “Paste/لصق”; no WhatsApp-specific dependency implied) |
| `lib/features/player/widgets/roster/roster_guest_players_section.dart` | player | source reviewed—runtime pending (clipboard import action labeled “Paste/لصق”; no WhatsApp-specific dependency implied) |
`lib/core/utils/roster_parser_utils.dart` | shared/player | source reviewed—runtime pending (manual import dialog disposes its text controller; dialog remains scrollable)
`lib/features/player/widgets/stadium_details/stadium_image_carousel.dart` | player | source reviewed—runtime pending (fullscreen gallery page indicator now respects bottom system inset; top controls already use SafeArea) |

## Newly discovered embedded UI components — 2026-11-01

| `lib/features/owner/widgets/tournament/tournament_dashboard_bottom_bar.dart` | player/owner | source reviewed—runtime pending (status-gated owner actions, nullable kickoff callback, fixture navigation disabled during async actions, champion summary, bottom inset) |
| `lib/features/owner/widgets/tournament/wizard/tournament_basics_step.dart` | player/owner | source updated—runtime pending (editable-field gates, sport/format selection, bilingual labels, controller ownership external) |
| `lib/features/owner/widgets/tournament/wizard/tournament_scheduling_step.dart` | player/owner | source updated—runtime pending (date/duration/prize edit gates, numeric input direction, scroll handled by parent wizard) |
| `lib/features/owner/widgets/tournament/wizard/tournament_step_indicator.dart` | player/owner | source reviewed—runtime pending (three-step progress semantics and bilingual labels; narrow-width text fit still needs device review) |
| `lib/features/owner/widgets/tournament/wizard/tournament_system_step.dart` | player/owner | source updated—runtime pending (team/group/qualifier/legs controls gated by editable policy; static option values) |
| `lib/features/owner/widgets/tournament/wizard/tournament_wizard_bottom_bar.dart` | player/owner | source reviewed—runtime pending (back and next/save actions disabled during async save; bottom system inset reviewed) |
| `lib/features/player/widgets/booking/booking_bottom_bar.dart` | player/owner | source reviewed—runtime pending (collective booking displays full total without deposit-only hint; currency suffix normalized to EGP; player counter +/- controls enforce 48dp minimum targets; optional ball and confirm disabled without slot/loading; compact-width runtime review pending) |
| `lib/features/player/widgets/champion/champion_empty_state.dart` | player/owner | source reviewed—runtime pending (championship/team/1v1 empty variants now delegate to VSPEmptyState; Arabic/English and explicit locale override preserved; optional return action retained) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_empty_states.dart` | player/owner | source reviewed—runtime pending (missing-governorate and no-tournament states use VSPEmptyState; localized profile navigation action and directional governorate banner preserved) |
| `lib/features/player/widgets/champion/champion_podium_components.dart` | player | source updated—runtime pending (localized governorate/sport filter labels, podium rank and team identity presentation, network-image fallback) |
| `lib/features/player/widgets/champion/championships_list_tab.dart` | player | source reviewed—runtime pending (championship stream loading/error/empty states; preserves last data and shows retry warning on realtime failure; All locations no longer triggers a false other-governorate banner; Arabic governorate banner and empty-state labels use the shared locale translator) |
| `lib/features/player/widgets/champion/teams_ranking_tab.dart` | player | source reviewed—runtime pending (team ranking filter and podium/list states; preserves last ranking snapshot and surfaces retry warning after stream failure) |
| `lib/features/player/widgets/champion/vsp_1v1_league_tab.dart` | player | source reviewed—runtime pending (1v1 tournament and roster stream loading/error/stale states; payment and cancellation lifecycle unchanged) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_hero_card.dart` | player | source reviewed—runtime pending (localized tournament name and governorate, capacity counts, and bounded progress value) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_prize_card.dart` | player | source updated—runtime pending (entry fee and prize values displayed from supplied server data with EGP localization) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_registration_action_card.dart` | player | source reviewed—runtime pending (registration/refund/location states; 48dp cancel/switch actions and disabled join action with loading feedback while payment is processing) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_roster_list.dart` | player | source updated—runtime pending (server-confirmed roster presentation, localized player-name fallback, and empty state; avatar loading/network failures render the player's initial) |
| `lib/features/player/widgets/champion/league_1v1/league_1v1_standings_view.dart` | player | source reviewed—runtime pending (standings loading/error/empty states; uses parent retry and preserves last data with stale warning) |


| `lib/features/auth/widgets/owner_onboarding/owner_onboarding_location_section.dart` | owner | source reviewed—runtime pending (governorate selector; GPS auto-detect hit target 48dp with localized tooltip) |


### Newly inventoried owner embedded surfaces — 2026-11-01

| `lib/features/owner/widgets/bookings/owner_slot_card.dart` | owner | source reviewed—runtime pending (booking/payment states are bilingual; payment status uses booking values; trailing detail chevron mirrors in RTL) |
| `lib/features/owner/widgets/bookings/owner_time_slot_row.dart` | owner | source updated—runtime pending (tap and long-press booking actions preserved; tap now uses keyboard-focusable InkWell semantics and feedback) |
| `lib/features/owner/widgets/dashboard/owner_dashboard_header.dart` | owner | source reviewed—runtime pending (profile-photo action has localized tooltip and focus semantics; verified-account tooltip bilingual; role/plan gates unchanged) |


### Newly inventoried player challenge surface — 2026-11-01

| `lib/features/player/widgets/challenge/challenge_team_card.dart` | player | source updated—runtime pending (team selection uses keyboard-focusable InkWell; selected-state animation and H2H states retained; long names bounded to two lines) |


### Newly inventoried owner tournament/dashboard surfaces — 2026-11-01

| `lib/features/owner/widgets/brackets/tournament_match_card.dart` | owner | source updated—runtime pending (localized 48dp schedule action; schedule text bounded; date/time defaults use VSPTimeService) |
| `lib/features/owner/widgets/dashboard/owner_pending_actions_bar.dart` | owner | source reviewed—runtime pending (cash action count scoped to selected stadium and current app-local day via VSPTimeService; direction-aware arrow; InkWell action) |


### Newly inventoried player home/chat/payment surfaces — 2026-11-01

| `lib/features/player/widgets/home/home_top_bar.dart` | player | source updated—runtime pending (profile/search/filter controls have focusable targets and localized tooltips; profile image has loading and error fallback; filter result remains bound to StadiumProvider) |
| `lib/features/player/widgets/chat/chat_input_bar.dart` | player | source updated—runtime pending (message input remains localized/direction-aware; send action has a localized tooltip and focusable 48dp target; send remains disabled while sending) |
| `lib/features/player/widgets/payment/payment_method_selector.dart` | player | source reviewed—runtime pending (accepted payment methods are explained bilingually; gateway label is factual and no longer claims absolute 100% security) |


### Newly inventoried player booking/result surfaces — 2026-11-01

| `lib/features/player/widgets/booking/booking_slot_card.dart` | player | source updated—runtime pending (available slots use focusable InkWell; booked/past slots stay disabled; selection and status visuals preserved) |
| `lib/features/player/widgets/booking/booking_slot_stream_section.dart` | player | source reviewed—runtime pending (initial loading/error/empty states separated; current-day and slot lifecycle calculations use VSPTimeService) |
| `lib/features/player/widgets/user_bookings/challenge_result_actions.dart` | player | source reviewed—runtime pending (captain/result lifecycle and localized feedback retained; submit-result time gate uses VSPTimeService) |


### Newly inventoried championship checkout embedded surfaces — 2026-11-01

| `lib/features/player/widgets/championship_checkout/checkout_championship_header.dart` | player | source reviewed—runtime pending (championship title and governorate/team metadata are bounded for long names and compact widths) |
| `lib/features/player/widgets/championship_checkout/checkout_squad_requirement_card.dart` | player | source reviewed—runtime pending (roster heading yields to the count badge; min/max requirement copy remains localized) |


### Newly inventoried stadium information surface — 2026-11-01

| `lib/features/player/widgets/stadium_details/stadium_information_tab.dart` | player | source updated—runtime pending (map-location action is focusable/localized; address is bounded; external launch failure has localized feedback) |


### Newly inventoried stadium gallery surface — 2026-11-01

| `lib/features/player/widgets/stadium_details/stadium_image_carousel.dart` | player | source updated—runtime pending (share/favorite actions have localized tooltips and focusable 48dp targets; image and indicator open the accessible full-screen gallery) |


### Newly inventoried owner quick-cash surface — 2026-11-01

| `lib/features/owner/widgets/dashboard/owner_quick_cash_card.dart` | owner | source updated—runtime pending (date-sensitive cash actions use VSPTimeService unless an explicit currentTime is injected; success/failure feedback retained) |


### Newly inventoried player chat message surface — 2026-11-01

| `lib/features/player/widgets/chat/chat_message_bubble.dart` | player | source reviewed—runtime pending (message edit custom action is localized for assistive technology; sender names bounded; timestamps use active locale) |


### Newly inventoried signup and email-verification surfaces — 2026-11-01

| `lib/features/auth/widgets/signup/signup_date_of_birth_field.dart` | auth | source updated—runtime pending (date-of-birth field has focusable InkWell and localized label tooltip) |
| `lib/features/auth/widgets/verify_email/otp_box.dart` | auth | source reviewed—runtime pending (keyboard event listener no longer creates an undisposed FocusNode in build; numeric LTR input retained) |
| `lib/features/auth/widgets/verify_email/otp_resend_section.dart` | auth | source reviewed—runtime pending (resend is a 48dp TextButton and remains disabled during countdown/resend; change-email action retained) |


### Newly inventoried signup/verification feedback surfaces — 2026-11-01

| `lib/features/auth/widgets/signup/signup_password_strength_bar.dart` | auth | source reviewed—runtime pending (strength progress exposes accessible label and percentage semantics) |
| `lib/features/auth/widgets/verify_email/verify_email_header.dart` | auth | source reviewed—runtime pending (masked email is LTR, centered, and bounded for narrow screens) |


### Newly inventoried owner upgrade surface — 2026-11-01

| `lib/features/owner/widgets/dashboard/owner_pro_upgrade_teaser.dart` | owner | source updated—runtime pending (upgrade action is focusable, at least 48dp high, and supports two-line localized copy) |


### Newly inventoried login role-selection surface — 2026-11-01

| `lib/features/auth/widgets/login_footer.dart` | auth | source updated—runtime pending (sign-up action is focusable; role sheet is safe-area aware/scrollable, bilingual, and RTL-aware) |


## Signup governorate display localization — 2026-11-01

- `lib/features/auth/widgets/signup_governorate_dropdown.dart`: dropdown values remain canonical English identifiers for AuthProvider/database consistency, while visible option labels now use `EgyptGovernorates.getLocalizedName` according to the active locale and are bounded to one line. This fixes English governorate names appearing in Arabic signup without changing stored values.
- Source commit: `f30af5466d6d7c1fe073cde0b7c43b72e8b7589e`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Team management action copy localization — 2026-11-01

- `lib/features/player/widgets/my_team/team_action_buttons.dart`: WhatsApp team-invitation message and leave-team/captaincy-transfer action now follow the active Arabic/English locale instead of displaying Arabic-only copy in English mode. Team name interpolation, WhatsApp launch, and captaincy handoff callback remain unchanged.
- Source commit: `84a0b126eec4f7c2e331cad1204b7463f42216b1`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner cash collection controls and receipt sheet — 2026-11-01

- `lib/features/owner/widgets/dashboard/owner_quick_cash_card.dart`: cash confirmation and phone-call controls now meet a 48dp minimum target (previously 36dp); the post-confirmation receipt bottom sheet is scrollable and respects the device safe area, including short-height screens and bottom system insets. Payment eligibility, `updatePaymentStatus` call, receipt content, and WhatsApp action are unchanged.
- Source commit: `55c3992dd9bf091fea1d29b55effc710a9212554`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Stadium image gallery lifecycle and navigation target — 2026-11-01

- `lib/features/player/widgets/stadium_details/stadium_image_carousel.dart`: the full-screen gallery's temporary `PageController` is now disposed when the dialog closes (previously allocated for each opening and never disposed); the top back action hit area is raised from 40dp to 48dp. Image paging, zoom, hero transition, and navigation destination are unchanged.
- Source commit: `3d3a696719a7e939b5eee8ec8c7977747ed71618`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner inbox preview overflow protection — 2026-11-01

- `lib/features/owner/widgets/inbox/owner_chat_item_card.dart`: the conversation time label is constrained to a 76dp maximum width and one line; the latest-message preview is also one line with ellipsis. This prevents long localized timestamps/previews from pushing the unread badge or shrinking the conversation title on narrow devices.
- Source commit: `a5f8310c26dbd44238ced22b2c57e002fd40bd79`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Owner ledger locale-aware date/time — 2026-11-01

- `lib/features/owner/widgets/ledger/owner_ledger_transaction_item.dart`: transaction timestamps now use locale-aware `yMMMd + jm` formatting instead of a fixed numeric `yyyy/MM/dd — hh:mm a` pattern, so month/date order and time conventions follow Arabic or English locale.
- Source commit: `6190c0c85d55ef17aa3ed555752cbf84cbbc2157`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Signup name-field narrow-screen layout — 2026-11-01

- `lib/features/auth/widgets/signup/signup_name_fields.dart`: first/last-name inputs now stack vertically when the available field width is below 360dp, while retaining the two-column layout on wider screens. This avoids cramped text fields and label/input collisions on compact phones and under larger text scaling. Input controllers, labels, validation ownership, and submission order are unchanged.
- Source commit: `53dbbea2a3a5bea13615403e40041669433ebb8d`. No tests, analyzer, CI, runtime checks, migrations, or APK build were run.


## Authentication and owner onboarding component review — 2026-11-01

- Reviewed the social sign-in row, owner payout information card, and responsive signup name fields. The social buttons already use the shared `SocialAuthButton` semantic Material target at 56dp and the owner payout fields use localized labels from generated app localizations. Signup name fields already switch to a vertical layout below 360dp and use localized labels/hints. No source change was made where the existing implementation already met the inspected criterion; device/large-text verification remains pending.


| `lib/features/player/widgets/collective_match_invite_sheet.dart` | player | source updated—runtime pending (collective booking/invite sheet has 48dp close/counter controls and localized close tooltip; sheet/dialog safe-area behavior remains runtime pending) |
| `lib/features/player/widgets/championship_details/championship_governorate_dialog.dart` | player | source updated—runtime pending (governorate confirmation primary action is 48dp; literal square brackets removed from interpolated Arabic/English copy) |
| `lib/features/owner/widgets/account/owner_payout_otp_dialog.dart` | owner | source updated—runtime pending (payout password sheet has a 48dp cancel action and duplicate re-auth guard; scroll/keyboard behavior remains runtime pending) |


## Grouped narrow-screen and touch-target remediation — 2026-11-01

- `lib/features/owner/widgets/tournament/wizard/tournament_step_indicator.dart`: step labels are constrained to one third of the available width, centered, and limited to two lines with ellipsis. This prevents long Arabic/English step names from expanding the three-step row on narrow screens. Source commit: `b2f29f2d6814c17d2a426e2869b0acf0e0e398ce`.
- `lib/features/owner/widgets/booking_sheet/booking_sheet_actions.dart`: the ongoing-match Extend (+30m) action no longer uses a shrink-wrapped tap target; its minimum interactive size is 48×48dp. Source commit: `052d25e47478a78b69a2eb82102d60b623c47cea`.
- `lib/features/player/widgets/booking/booking_bottom_bar.dart`: collective-booking player-count labels now use the available row width, wrap to at most two lines, and ellipsize excess text so they cannot push the 48dp increment/decrement controls off-screen on compact devices. Source commit: `348d69664fe6e7d52f502ff114c2c41f8605b620`.
- These are source-level remediations only. Per the agreed batch process, no test/analyzer/CI/device pass or APK build was run. Both surfaces remain runtime pending until the consolidated validation stage.


## Root account-state and owner-flow lifecycle remediation — 2026-11-01

- `lib/core/navigation/root_screen.dart`: the authenticated-profile resolution state now uses the canonical `VSPStateView` loading presentation, bilingual Arabic/English copy, and `SafeArea` instead of an unlabeled bare spinner. Existing five-second timeout and offline recovery destination remain unchanged. Source commit: `55eaf75c5c8b7c8820a2c94c449eb8c0daf20944`.
- `lib/features/owner/screens/owner_main_screen.dart`: the deferred post-frame celebration subscription now checks `mounted` before reading Provider and checks it again before handling late stream events, preventing use of a disposed screen context. Source commit: `9f9d96d2fdbfeaa025f55719d22aa24d6fa7eb49`.
- These are source-level changes; no analyzer, tests, CI, device run, or APK build was executed.

## Supabase live review — production project `mktqkddbcddrxjxabdua` — 2026-11-01

- Project status: `ACTIVE_HEALTHY`; PostgreSQL 17.6.1.127. Public schema inventory returned 66 tables; all 66 report RLS enabled.
- The six sensitive operational tables previously flagged for missing policies now have policies: refund queues and challenge results expose admin read + service-role full access; internal function secrets have service-role-only access; team-league payments have service-role full access plus users' own-payment read access. No client policy was added to internal secrets or refund worker queues.
- Active Edge Function inventory: `create_paymob_intention` v33 (JWT required), `process_paymob_refund` v20 (JWT required), `paymob_webhook` v45 (JWT disabled, expected webhook entrypoint), `vsp_copilot` v123 (JWT required), `fcm_push` v20 (JWT disabled; webhook/token validation requires separate code review), `process_tournament_refund` v16 (JWT required), `create_owner_web_checkout` v10 (JWT required), `get_owner_web_checkout_status` v7 (JWT required).
- Security advisor findings: one ERROR for `public.teams_public` being a SECURITY DEFINER view; 198 WARN findings for authenticated execution of SECURITY DEFINER functions; one WARN for leaked-password protection being disabled. Performance advisor findings: 44 auth-RLS initplan findings, 50 multiple-permissive-policy findings, and 79 unused-index findings.
- `teams_public` currently selects team-directory fields from `public.teams`, grants SELECT to authenticated (not anon), and has no `security_invoker` option. The base `teams` SELECT policy limits rows to captain/member/admin. Changing this view to invoker semantics without first designing a public-safe discovery policy could hide other teams from player discovery; bulk-revoking the 198 SECURITY DEFINER RPC grants could break intended atomic app workflows. These are not changed blindly. Required next remediation is function-by-function authorization review and an explicit decision on intended public team discovery, followed by a migration and advisor re-check.
- No production database DDL, RLS policy, RPC grant, or Edge Function deployment was changed during this review.

- `lib/features/player/widgets/collective_match_invite_sheet.dart`: initial private-invite load now uses the shared bilingual loading state; modal route retains `useSafeArea` and scroll-controlled layout.

- `lib/features/player/screens/global_search_screen.dart`: active search now uses the shared localized loading state rather than a bare spinner; existing request-generation protection and retryable error state remain intact.

- `lib/features/auth/screens/verify_email_screen.dart`: OTP verification and resend now recover from unexpected exceptions with localized messages and restore their in-flight controls; local email-cleanup failure no longer masks successful server verification.

- `lib/features/player/screens/profile_screen.dart`: the profile team-card initial fetch now uses the shared localized loading state instead of an unlabeled spinner; existing explicit error/retry behavior remains unchanged.


### Loading-state implementation additions — 2026-11-01

The following registered screens now use `VSPStateView` with localized Arabic/English titles and contextual messages for full-page/stream loading: `facility_onboarding_screen.dart`, `owner_cup_screen.dart`, `owner_inbox_screen.dart`, `subscription_plans_screen.dart`, `tournament_brackets_screen.dart`, `match_details_screen.dart`, `matchup_live_dashboard_screen.dart`, `support_ticket_screen.dart` (ticket + messages streams), `support_tickets_screen.dart`, `team_profile_screen.dart`, `profile_subscreens/my_team_screen.dart`, and `profile_subscreens/notifications_screen.dart`. Existing error/retry/empty and data-fetch logic was retained. Compact button and image placeholders were not expanded into page-level states.


### Additional discovery and action-integrity refinements — 2026-11-01

- `lib/features/player/widgets/collective_match_invite_route.dart`, `lib/features/player/widgets/champion/vsp_1v1_league_tab.dart`, and `lib/features/player/widgets/champion/championships_list_tab.dart`: replaced bare full-surface/stream loading spinners with localized shared loading states.
- `lib/core/repositories/match_repository.dart`: `acceptJoinRequest` and `rejectJoinRequest` now return success only when the server JSONB explicitly reports `success: true`; transport exceptions are logged. This prevents UI success messages/local participant updates after a server-side rejection.
- `lib/features/owner/widgets/tournament/tournament_dashboard_dialogs.dart`: all eight explicitly 44dp primary actions raised to 48dp.

- Player league/ranking follow-up: `league/team_league_tab.dart`, `champion/teams_ranking_tab.dart`, and `champion/league_1v1/league_1v1_standings_view.dart` now use localized shared loading states for initial data reads.

- Dialog touch-target pass: owner document-upload, stadium discard/delete, Paymob still-waiting, and tournament dashboard dialogs now use explicit 48dp minimum action heights/tap targets where their previous dimensions were below the standard.

- Chat dialog follow-up: `player/widgets/chat/chat_dialogs.dart` report form is keyboard-scrollable and all report/delete actions use explicit 48dp hit targets.

- `lib/features/owner/widgets/tournament/tournament_prize_delivery_dialog.dart`: prize handover dialog actions now use explicit 48dp minimum targets.


## Supporting logic files excluded from the UI-surface count

The recursive `lib/**/{screens,widgets}/**.dart` tree contains 356 paths: 325 are registered visual screens/embedded UI components and the remaining 31 were inspected as non-standalone UI support code (services, controllers, calculators, data models, parsers, payload builders, or compatibility exports) and are intentionally not counted as separate visible surfaces:

- `lib/features/owner/widgets/add_stadium/stadium_location_geocoder.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_controllers.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_data_loader.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_features_state.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_image_service.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_location_coordinator.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_media_coordinator.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_payload_builder.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_submit_service.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_time_coordinator.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_time_utils.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_validator.dart`
- `lib/features/owner/widgets/bookings/owner_schedule_slots_builder.dart`
- `lib/features/owner/widgets/brackets/tournament_round_schedule_calculator.dart`
- `lib/features/owner/widgets/documentation/doc_wizard_hydrator.dart`
- `lib/features/owner/widgets/tournament/tournament_bracket_builder.dart`
- `lib/features/owner/widgets/tournament/tournament_manual_team_service.dart`
- `lib/features/owner/widgets/tournament/wizard/tournament_wizard_coordinator.dart`
- `lib/features/owner/widgets/tournament/wizard/tournament_wizard_draft_service.dart`
- `lib/features/player/widgets/booking/booking_confirmation_handler.dart`
- `lib/features/player/widgets/booking/booking_slot_calculator.dart`
- `lib/features/player/widgets/booking/booking_slot_models.dart`
- `lib/features/player/widgets/chat/chat_call_utils.dart`
- `lib/features/player/widgets/my_team/my_team_controller.dart`
- `lib/features/player/widgets/my_team/team_management_service.dart`
- `lib/features/player/widgets/payment/paymob_callback_url_parser.dart`
- `lib/features/player/widgets/user_bookings/refund_badge_widget.dart`
- `lib/features/player/widgets/user_bookings/refund_notice_widget.dart`
- `lib/shared/widgets/date_picker/vsp_date_picker_calculator.dart`
- `lib/shared/widgets/match_card/public_match_card_formatter.dart`

The 338 unique register paths also include 13 cross-cutting core/navigation/design-system/provider/service files outside that recursive screen/widget glob. The 31 support files above still affect behavior and data integrity through their callers; excluding them from the visual-surface count does not exclude them from code-flow or business-rule review.


## 2026-11-01 source corrections

- `lib/features/owner/widgets/add_stadium/stadium_wizard_submit_service.dart`: stadium persistence is now treated separately from post-save owner-profile synchronization. If the stadium write succeeds but profile refresh fails, the UI no longer reports that the stadium save itself failed; it surfaces a localized account-sync warning and closes the completed wizard. The default stadium usage note is localized in Arabic and English, and blocked/auth-expired feedback is bilingual.
- `lib/features/player/widgets/payment/paymob_callback_url_parser.dart`: payment callback decisions now require an HTTP(S) URL on an exact trusted payment domain or its subdomain, a recognized payment endpoint, and an explicit success/failure status parameter. Path-only `/payment-status`, arbitrary `standalone` substrings, and untrusted hosts no longer produce a success callback. Bank/3DS domains remain pending and rely on server-side payment-status polling.


## Additional booking and tournament integrity fixes — 2026-11-01

- `lib/features/player/widgets/booking/booking_slot_calculator.dart`: availability generation now excludes every configured `breakTimes` interval, while retaining backward compatibility with legacy `breakTime` records.
- `lib/features/owner/widgets/tournament/tournament_manual_team_service.dart`: manual team creation now rejects an empty captain identity and empty team name; it no longer inserts a hard-coded placeholder UUID into `memberUids`.


- `lib/features/owner/widgets/add_stadium/stadium_wizard_media_coordinator.dart` and its image loaders: persisted stadium images are distinguished from newly uploaded draft images. Removing an existing image during an edit no longer deletes its Storage object before the edit is saved; upload progress callbacks also avoid invoking widget state updates after the owning context is disposed.


- `lib/features/owner/widgets/bookings/owner_schedule_slots_builder.dart`: owner schedule slots now honor every configured stadium `breakTimes` interval and mark any overlapping 30-minute slot as a break, matching player-side availability; legacy single-break fields remain supported.
- `lib/features/player/widgets/my_team/my_team_controller.dart`: team updates now require a verified signed-in user instead of attempting logo uploads under a synthetic `unknown` storage path. Manual tournament team names are trimmed before persistence.


- `lib/features/owner/widgets/tournament/wizard/tournament_wizard_coordinator.dart`: tournament creation/edit validation now rejects non-numeric, non-finite, or negative entry-fee and prize values instead of allowing invalid text to silently become zero in the payload.


- `lib/features/player/widgets/booking/booking_confirmation_handler.dart`: the active-cash-booking payment gate now uses the strict booking-history query and stops with localized retry guidance if the query fails, rather than treating a failed read as an empty history and potentially allowing a cash booking.


- `lib/features/owner/widgets/brackets/tournament_round_schedule_calculator.dart`: a round is now locked when any match has a recorded home/away score or winner, or its scheduled kickoff time has passed; the optional `now` argument keeps the time boundary deterministic for validation.


- `lib/features/player/screens/manage_tournament_roster_screen.dart`: initial roster loading now uses the shared bilingual `VSPStateView`; the existing retryable load-error and empty/loaded roster branches are preserved.


- `lib/features/player/widgets/booking/booking_slot_calculator.dart`: slot generation now emits only complete 30-minute slots that finish at or before the stadium closing time; a partial final interval can no longer extend a booking past closing.


- `lib/features/owner/widgets/bookings/owner_schedule_slots_builder.dart`: owner schedule generation now starts on the exact configured opening minute and stops before any incomplete 30-minute interval beyond the exact closing minute, including overnight and 24-hour schedules.


- `lib/features/owner/widgets/booking_sheet/booking_sheet_duration_selector.dart`, `lib/features/player/widgets/collective_match_invite_sheet.dart`, `lib/shared/dialogs/vsp_terms_and_privacy_modal.dart`, and `lib/shared/widgets/match_card/manage_participants_modal.dart`: corrected physical right/left spacing and alignment to directional equivalents so the booking chips, invite header, legal modal header, and participant section headings mirror correctly in Arabic RTL.


- `lib/features/player/widgets/my_team/my_team_controller.dart` now opens the scroll-controlled Add Player sheet with `useSafeArea: true`, protecting its header from status-bar/notch overlap while retaining the sheet's existing keyboard and bottom-inset handling.


- `lib/features/owner/widgets/add_stadium/stadium_wizard_validator.dart` and `add_stadium_wizard.dart`: hourly price, ball-rental price, and deposit values now reject invalid/non-finite values before payload creation; the image-upload-in-progress validation message is localized in Arabic and English.


- `lib/features/player/widgets/my_team/my_team_controller.dart`: team creation success is no longer reported as a failure if the subsequent list refresh fails; it now reports that the team was created and the view needs reopening. Selected team-logo uploads are required to succeed before create/update continues.


- `lib/features/auth/services/signup_validation_service.dart`: password-strength scoring now evaluates five distinct signals (minimum length, lowercase, uppercase, digit, and special character); the duplicated minimum-length check no longer inflates the score.
- `lib/features/owner/controllers/owner_dashboard_controller.dart`: dashboard requests now use a monotonically increasing request token; late responses from an older date/court filter are ignored, and pending responses are invalidated when the controller is disposed.


- `lib/features/player/services/payment_checkout_coordinator.dart`: both booking and tournament fallback pollers now serialize async status reads and latch confirmed completion, preventing overlapping timer ticks from issuing duplicate requests or invoking success callbacks more than once.


- `lib/features/player/widgets/home/book_tonight_sheet.dart`: failed slot discovery now exits loading into a bilingual retryable error state instead of leaving the sheet spinning indefinitely; the loader also prevents overlapping retries.


- `lib/features/auth/widgets/signup/signup_password_strength_bar.dart` and `lib/features/auth/services/signup_validation_service.dart`: password-strength labels (Weak/Medium/Strong) now follow the active Arabic/English locale; the score still uses five distinct strength signals.


- `lib/features/auth/screens/signup_screen.dart`: unexpected auth exceptions and secure-storage failures are now handled separately; the loading lock is released, and a post-creation storage failure is not misreported as a failed account creation or an instruction to register again.


- `lib/features/player/services/payment_checkout_coordinator.dart`: payment poll generations are invalidated when polling is replaced or cancelled, so an already-running network request from an old checkout cannot report success into a newer/abandoned checkout.


- `lib/features/owner/screens/owner_dashboard_screen.dart`: overlapping owner-championship refreshes now use a request generation; results and errors from an earlier refresh are ignored, and changing the active owner scope invalidates pending refreshes.


| `lib/features/owner/screens/owner_dashboard_screen.dart` | owner | source updated — approval-notice claim responses are owner-ID/generation scoped; runtime account-switch verification pending |


### Safe-area follow-up — 2026-11-01

- Added explicit `useSafeArea: true` to owner no-show confirmation, tournament round reset, owner onboarding exit, document-under-review, both tournament bracket dialogs, tournament prize handover, Paymob waiting, player booking cancellation, and team-league match dialogs.
- Removed the redundant nested `SingleChildScrollView` behavior from the prize-handover `AlertDialog` while retaining its scrollable content, avoiding competing dialog/content scroll containers.
- These are source-level changes only; runtime validation remains pending by the agreed no-tests/no-build instruction.

- `lib/features/player/widgets/collective_match_invite_sheet.dart`: explicit safe-area protection added to all three booking/invite action dialogs; the two entry bottom sheets already use `useSafeArea: true`.


## Monitored compiler diagnostics — 2026-11-01

- Existing workflow run [41286819423](https://github.com/mohamedsalh333555/VSP.App/actions/runs/41286819423), on older commit `6eb50fdd2c4e6879a4c8a95a5a0de1415af4a5aa`, reached the Release compile step and failed with two Dart source diagnostics: an unmatched widget-tree delimiter in `stadium_details_screen.dart` and an unresolved `VSPErrorState` reference in `facility_onboarding_screen.dart`.
- Corrected the missing `Material`/outer `Expanded` closure and added the explicit shared error-state import on the current branch. These fixes are recorded in commits `82f5e687f019adf986455a4eb56126f3f08902a1` and `8e76fea76083ca6eb3900f37690958cf1eddfffc`.
- The failed run predates those commits; it is root-cause evidence only, not verification of the fixes. No artifact was produced and no new build was started.


## Semantic color cleanup — 2026-11-01

- Replaced remaining raw black/white/transparent UI color literals with VSP Design System aliases in: `welcome_screen.dart`, `forgot_password_dialog.dart`, `create_tournament_wizard.dart`, `owner_dashboard_screen.dart`, `owner_tournament_dashboard_screen.dart`, `subscription_plans_screen.dart`, `tournament_brackets_screen.dart`, `owner_bookings_screen.dart`, `owner_bookings_filter_bar.dart`, `owner_profile_screen.dart`, `owner_payout_otp_dialog.dart`, `booking_sheet_time_stadium_card.dart`, `owner_booking_modal.dart`, `tournament_auto_schedule_modal_sheet.dart`, `tournament_round_auto_schedule_sheet.dart`, `tournament_score_modal.dart`, `owner_payout_dialog.dart`, `owner_booking_sheet.dart`, `add_stadium_location_picker_sheet.dart`, `stadium_wizard_dialogs.dart`, `booking_sheet_actions.dart`, and `booking_sheet_cancel_dialog.dart`.
- Added canonical opacity primitives `black26`, `black45`, `black87`, and `white70` to the V2 palette and exposed compatibility aliases. Also migrated `quick_booking_receipt_sheet.dart`, `quick_phone_booking_modal.dart`, `owner_cup_format_modal.dart`, `tournament_bracket_preview_dialog.dart`, `tournament_dashboard_dialogs.dart`, `tournament_manual_team_sheet.dart`, `tournament_prize_delivery_dialog.dart`, `all_stadiums_screen.dart`, and `booking_date_selector.dart` to canonical color aliases. The four dialogs in `tournament_dashboard_dialogs.dart` now explicitly set `useSafeArea: true`. The player challenge-selection, checkout financial, championship details, match details, live matchup, and notifications surfaces were also migrated to canonical color aliases; all six dialogs across championship details, match details, live matchup, and notifications now explicitly use `useSafeArea: true`. The payment gateway, player booking details, home stadiums, profile, edit-profile, favorites, language, my-team, team-member, and profile-notifications surfaces were also migrated; payment-verification, account-deletion, player-booking details, and profile confirmation dialogs now explicitly use `useSafeArea: true`. The stadium details, team dashboard/profile, tournament registration success, all-stadium filter, booking calendar/payment method/type, championship governorate, and championship squad-builder surfaces were also migrated to canonical colors; the team-card dialog now explicitly uses `useSafeArea: true`. Collective-match invitations, create-team, home match-outcome dialogs, Team League match, match-result, team dialogs, payment-cancel, payment-verification, Paymob waiting, and team-matchup invite surfaces were also migrated to canonical color aliases; all five home/team dialogs now explicitly use `useSafeArea: true`. The shared manage-participants modal and auth signup-governorate, welcome-language, and onboarding-slide widgets were also migrated to canonical semantic colors. The owner stadium carousel, Add Stadium location/features/images/step-indicator components, and tournament champion banner were also migrated to canonical color aliases. Quick-booking customer, duration, and payment sections plus draw-room matchup, manual-team options, and manual-team roster components were also aligned; explicit red/blue/amber/white/black swatches in manual-team options remain feature-specific jersey choices, not semantic UI colors. The tournament team card, booking financial summary, championship guest-player section, matchup result card, team achievements/actions/stats, Paymob web fallback, and roster team-member section were also migrated; the tournament team-card dialog now explicitly uses `useSafeArea: true`. The roster tournament header, stadium ratings tab, team-profile captain card, and team-profile head-to-head section were also migrated to canonical color aliases. The reschedule action banner, bracket preview canvas, cups tab selector, championship checkout team-member list, payment background glow, shared social-auth button, and shared stadium card were also aligned with the canonical palette. Shared public-match and championship cards, owner notification button, and player pending/active booking cards were also migrated; the public-match and pending-booking dialogs now explicitly use `useSafeArea: true`. The team-league tab, payment breakdown/countdown/security components, and championship bottom bar/matches/pill-tab components were also migrated; two team-league dialogs and the fee-transparency sheet now explicitly use `useSafeArea: true`. All changes are source-level only; they do not establish contrast or runtime pass, and affected entries remain runtime-pending.

## Additional Design System token remediation — 2026-11-01

- Added canonical alpha primitives in `VSPDSColors` and exposed them through the compatibility facade: `white02`, `white04`, `white06`, `white50`, `white54`, `black15`, `black55`, and `black60`. Existing alpha values were preserved exactly; this is token centralization, not a color redesign.
- Replaced raw Flutter `Colors.black`, `Colors.white`, and `Colors.transparent` references with VSP semantic/primitive aliases in 19 registered surfaces: owner quick-cash, tournament match card, support tickets, 1v1 roster, chat input, matchup standings, stadium gallery/information, filter price/category, home top bar, login footer, signup DOB, owner time-slot row, owner PRO teaser, booking slot card, challenge team card, shared back button, and upload widgets.
- Added the canonical `VSPDSMotion.microInteraction` (160ms) token and exposed `VSPDSMotion` through the compatibility facade; replaced inline 160ms/180ms animation durations in quick-booking payment, stadium filter, filter category, and terms-checkbox surfaces.
- `CopyablePhoneText` now aligns from the locale-aware start edge while explicitly keeping the phone-number glyph sequence LTR.
- These are source-level Design System/RTL corrections only. Contrast, Arabic/English rendering, touch behavior, and animation timing still require the single consolidated runtime validation; no screen or UXLP rule is marked pass from these edits.

## Current source triage and grouped remediation — 2026-11-01

- Full-file heuristic review initially covered 69 registered paths that were untouched by the PR at that point; 35 of those paths have since been changed by the resulting fixes, while 34 remain unchanged. It found raw color literals in 28 paths; a later targeted full-file review of eight high-traffic screens found four additional raw-color paths. The sweep also found six physical left/right layout occurrences across five paths and ten inline duration/delay values across seven paths. All findings were corrected using canonical semantic tokens, directional geometry, and `VSPDSMotion`.
- Changed-hunk review now covers 356 changed Dart files. Nineteen additional registered UI surfaces had raw black/white/transparent references centralized. Post-fix diff review found no raw Flutter color literals or physical left/right geometry in Dart additions.
- Added exact palette tokens for white/black alpha variants and warning soft/border states; added motion tokens for press, selection, micro-interaction, standard, indicator, fade-in, and banner transitions. Existing timings and rendered alpha values were preserved.
- `CopilotLoadingBubble` now uses directional placement and bilingual status copy. `AddStadiumStep1HoursSection` and tournament wizard padding now use directional geometry. `HomeFeedContent` refresh now awaits the actual `StadiumProvider.fetchStadiums` future instead of waiting an arbitrary 800ms delay.
- Source changes remain runtime pending. No UXLP rule or screen is marked pass from static analysis.

## Bilingual financial-identifier input correction — 2026-11-01

- `CustomTextField` now accepts an explicit `textDirection` override while preserving its existing automatic LTR behavior for email, phone, URL, and numeric keyboard types.
- Owner onboarding Instapay input now uses the email keyboard; bank IBAN input explicitly uses LTR direction so Arabic locale does not reverse or misplace the identifier.
- The 35 registered paths that were unchanged at the time of the literal-copy sweep were checked for direct hardcoded Text/placeholder/tooltip candidates. The only candidates were three payout-format examples (`username@instapay`, phone format, and IBAN prefix), not user-facing copy; the two identifier fields are now explicitly LTR. One registered path has since changed, leaving 34 registered paths currently unchanged.
- This is source-level bilingual-input evidence only. Keyboard display, cursor movement, paste behavior, and Arabic/English runtime rendering remain pending.


## Full-file re-scan of the 34 paths unchanged by PR #35 — 2026-11-01

All 34 unique registered paths not changed by PR #35 were re-fetched from `uxlp-44-implementation` and scanned as complete files for raw Flutter palette references (`Colors.black/white/transparent/amber/redAccent/blue`), physical `left:`/`right:` positioning, literal numeric `Duration` values, modal entry-point calls, SafeArea markers, TextStyle declarations, and direct V2-token imports.

- Raw palette references: **0** across these 34 files.
- Physical positioning: four occurrences across three files. The create-account decorative glow and owner-cup team avatar stack were changed to `PositionedDirectional`; the two fixed positions in `VSPAiSparkIcon` are intentional brand-mark geometry and are documented as non-directional.
- Numeric Duration heuristic: 11 matches, all `Duration(seconds: 1)` date-boundary comparisons in `owner_pro_insights_view.dart`; none is an animation/motion duration.
- Modal entry-point calls: 0 in this unchanged-path subset. This is not a claim that the app has no modal routes; their callers are registered and reviewed separately.
- These are source-level heuristic results only. They do not establish runtime layout, contrast, keyboard, locale, or state passes. The remaining 304 changed registered paths have diff-level scan evidence and targeted full-file reviews, not a current full-file scan of all 338 paths.

Paths re-fetched and scanned:
- `lib/features/auth/screens/create_account_screen.dart`
- `lib/features/owner/widgets/add_stadium/stadium_wizard_steps_pager.dart`
- `lib/features/owner/widgets/booking_sheet/booking_sheet_details_form.dart`
- `lib/features/owner/widgets/booking_sheet/booking_sheet_header.dart`
- `lib/features/owner/widgets/booking_sheet/owner_booking_sheet_service.dart`
- `lib/features/owner/widgets/documentation/doc_wizard_steps_pager.dart`
- `lib/core/widgets/shimmer_image.dart`
- `lib/features/auth/widgets/social_auth_buttons_row.dart`
- `lib/features/owner/widgets/dashboard/insights/insights_booking_types_card.dart`
- `lib/features/owner/widgets/dashboard/owner_pro_insights_view.dart`
- `lib/features/owner/widgets/documentation/doc_step_commercial_register.dart`
- `lib/features/owner/widgets/documentation/doc_step_national_id.dart`
- `lib/features/owner/widgets/documentation/doc_step_tax_card.dart`
- `lib/features/owner/widgets/tournament/cups/owner_cup_card.dart`
- `lib/features/owner/widgets/tournament/cups/owner_cup_empty_view.dart`
- `lib/features/owner/widgets/tournament/tournament_overview_card.dart`
- `lib/features/player/widgets/chat/chat_app_bar_title.dart`
- `lib/features/player/widgets/my_team/team_profile_form.dart`
- `lib/features/player/widgets/stadium_details/stadium_pitch_conditions_tab.dart`
- `lib/features/player/widgets/team_profile/team_profile_achievements_section.dart`
- `lib/features/player/widgets/team_profile/team_profile_action_bar.dart`
- `lib/features/player/widgets/team_profile/team_profile_hero_header.dart`
- `lib/features/player/widgets/team_profile/team_profile_stats_grid.dart`
- `lib/features/owner/widgets/inbox/user_search_delegate.dart`
- `lib/features/owner/widgets/tournament/cups/cups_filter_dropdowns.dart`
- `lib/widgets/refund_notice_widget.dart`
- `lib/shared/widgets/vsp_ai_spark_icon.dart`
- `lib/shared/widgets/vsp_auth_header.dart`
- `lib/core/ui/components/vsp_menu_item.dart`
- `lib/core/ui/components/vsp_section_title.dart`
- `lib/features/player/widgets/create_team_logo_picker_row.dart`
- `lib/features/player/widgets/vsp_1v1_trophy_badge.dart`
- `lib/features/owner/widgets/radial_tick_gauge_painter.dart`
- `lib/features/player/widgets/championship_details/championship_details_header.dart`



### Stadium details route-reuse correction — 2026-11-02

- **Rules 9, 38, 40, 42 — player stadium details:** added `didUpdateWidget` handling so a reused route state switches its live stream when the stadium ID changes and rebuilds the gallery when stadium image metadata changes. This prevents stale stadium data/images from the previously displayed stadium remaining attached to the new route state.
- This is a source-level lifecycle correction only. Stream transitions, same-ID metadata refresh, tab state, image ordering, Arabic/English layout, and device behavior remain runtime-pending; no pass is claimed.


### Stadium gallery pager route-reuse correction — 2026-11-02

- **Rules 9, 38, 40, 42 — player stadium details / image carousel:** when a reused carousel receives a different image collection, its retained page index is reset to zero after the widget update. This prevents a stale page index from referencing an item outside the replacement collection or continuing to show the prior stadium's image.
- The reset is guarded by widget lifecycle and PageController attachment checks. This is source-level evidence only; changing stadiums with shorter/empty galleries, image-list replacement during navigation, swipe behavior, and Arabic/English device rendering remain runtime-pending. No pass is claimed.


### Live stadium gallery data-source correction — 2026-11-02

- **Rules 9, 28, 38, 40:** the stadium details gallery is now derived from the resolved stadium object in the active StreamBuilder snapshot, the same data source used by the information tabs. A live database update to stadium images can therefore reach the carousel without requiring the route widget argument to be replaced.
- Source-only status: verify realtime image additions/removals, stream errors and fallback to route data, route reuse, and pager reset on device. No runtime pass is claimed.


### Stadium detail tab state reset — 2026-11-02

- **Rules 9, 38, 40:** when the route State is reused for a different stadium ID, the details screen now switches its live stream and resets the selected tab to the default information tab. This avoids carrying navigation state from the previously viewed stadium.
- Source-only evidence. Verify route reuse, stream replacement, selected-tab indicator, and swipe/tap behavior on device; no runtime pass is claimed.


### Stadium gallery metadata validation — 2026-11-02

- **Rules 6, 9, 28, 40:** gallery parsing now ignores non-string values in the optional `features.allImages` metadata instead of converting malformed values (for example null/maps) into invalid image URLs. Valid non-empty strings remain trimmed and de-duplicated.
- Source-only status; malformed metadata, image loading failures, and live updates still require runtime verification. No pass is claimed.
