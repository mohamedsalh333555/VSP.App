# Staging privileged RPC triage and execution owner — 2026-11-13

**Scope:** read-only `public.pg_proc` metadata and function-definition **marker checks** on `vsp-staging`, not production. The 200 selected entries are callable by the PostgreSQL `authenticated` role and carry `SECURITY DEFINER`. This is a *review queue*, **NOT** a vulnerability list or permission-change authorization.

## 77.03 — Effective function execution identity

- **200 of 200** selected routine overloads have `execution_owner = postgres` in staging. Their `SECURITY DEFINER` code executes under the owning role's privileges, not the caller's table-level privileges; each must separately enforce appropriate caller ownership/role when required.
- This is distinct from **invoking identity**: the functions are executable by `authenticated`; it is not proof their guards authorize any operation. `anon` execution on the subset was 0 in the previous [inventory](VSP_STAGING_PRIVILEGED_RPC_INVENTORY_2026-11-13.md).

## 77.02 — Preliminary risk triage by business operation

Classification is a conservative **name-based review priority** with static `auth.uid()/auth.jwt()` textual markers, **not** an exploit finding. Confirm actual consumers, internal helpers, role checks, grants and effects before changing permissions. High priority = review first, not confirmed P0 defect.

| Review group | Function overloads | No direct auth.uid()/auth.jwt() marker |
|---|---:|---:|
| Other / P2 manual review | 77 | 4 |
| Financial / P0 manual review | 21 | 3 |
| Sports-write / P1 manual review | 66 | 4 |
| Admin-identity / P0 manual review | 36 | 1 |

**12 signatures lack a direct caller-token marker in their own function bodies** (some may correctly delegate authorization to helper functions, SQL triggers or validated prerequisites):

- `admin_update_support_ticket_atomic(uuid,text,text,uuid)` — Admin-identity / P0 manual review
- `cancel_booking_with_refund_atomic(uuid,text)` — Financial / P0 manual review
- `cancel_booking_with_refund_atomic(uuid,uuid,text)` — Financial / P0 manual review
- `confirm_1v1_payment_atomic(text,text,numeric)` — Financial / P0 manual review
- `get_platform_business_rules()` — Other / P2 manual review
- `get_server_timestamp()` — Other / P2 manual review
- `get_team_league_standings(uuid)` — Sports-write / P1 manual review
- `global_search(text)` — Other / P2 manual review
- `is_admin_or_cofounder(uuid)` — Other / P2 manual review
- `remove_tournament_team_atomic(uuid,uuid)` — Sports-write / P1 manual review
- `vsp_enforce_booking_operating_window()` — Sports-write / P1 manual review
- `vsp_user_is_tournament_participant(uuid,uuid)` — Sports-write / P1 manual review

## Grouped inventory for follow-up

### Other / P2 manual review (77)

- `accept_join_request(text,text)`
- `advance_groups_to_knockout_atomic(uuid)`
- `apply_no_show_penalty(uuid)`
- `are_users_blocked(uuid,uuid)`
- `cancel_incomplete_registration_atomic(uuid)`
- `check_extension_available(uuid,timestamp with time zone)`
- `check_owner_stadium_limit(uuid)`
- `check_rate_limit(uuid,text,integer,integer)`
- `close_owner_daily_shift(uuid,uuid,date)`
- `complete_user_registration(uuid,text,text,text,text,text,text,text,text)`
- `confirm_owner_onboarding(uuid)`
- `create_direct_chat_atomic(uuid,text,uuid)`
- `create_owner_on_behalf(text,text,text,text,text)`
- `create_report_atomic(text,uuid,text,text,text,uuid,uuid,uuid)`
- `create_support_ticket_atomic(text,text,text,uuid,uuid,text)`
- `crown_individual_1v1_champion(uuid,uuid,numeric)`
- `delete_chat_for_user_atomic(uuid,uuid)`
- `delete_chat_for_user(uuid,uuid)`
- `delete_stadium_for_owner(uuid)`
- `delete_user_permanently(uuid)`
- `dismiss_no_show_penalty(uuid,uuid)`
- `dispute_no_show_with_gps(text,text,numeric,numeric,numeric)`
- `edit_chat_message_atomic(uuid,text)`
- `evaluate_owner_stadium_capacity(uuid,uuid)`
- `generate_regular_group_fixtures_atomic(uuid)`
- `get_admin_metrics()`
- `get_admin_quick_metrics()`
- `get_collective_invite_credentials(uuid)`
- `get_owner_ai_operational_insights(uuid,text)`
- `get_owner_ai_stadium_comparison(uuid,text)`
- `get_owner_dashboard_analytics(uuid,timestamp with time zone,timestamp with time zone,uuid)`
- `get_owner_financial_summary(uuid)`
- `get_owner_trial_state()`
- `get_platform_business_rules()` — **no direct caller marker**
- `get_player_match_details(uuid)`
- `get_private_collective_invite_by_code(text)`
- `get_private_collective_invite_details(text)`
- `get_private_collective_match_details(uuid)`
- `get_public_match_details(uuid)`
- `get_server_timestamp()` — **no direct caller marker**
- `global_search(text)` — **no direct caller marker**
- `increment_banner_clicks(uuid)`
- `increment_banner_views(uuid)`
- `increment_chat_unread_count(text,text,text)`
- `is_admin_or_cofounder(uuid)` — **no direct caller marker**
- `join_private_collective_match_atomic(text,uuid)`
- `leave_private_collective_match_atomic(uuid,uuid)`
- `leave_public_match_atomic(uuid,uuid)`
- `mark_1v1_prize_delivered_atomic(uuid,text)`
- `mark_chat_messages_as_read(uuid,uuid)`
- `mark_support_ticket_whatsapp_escalation(uuid)`
- `owner_extend_match_atomic(uuid,integer)`
- `owner_lock_slot_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text)`
- `owner_record_no_show_atomic(uuid,uuid,text)`
- `pay_rehabilitation_fine(uuid)`
- `persist_copilot_turn(uuid,uuid,text,text,jsonb,jsonb,jsonb)`
- `provision_registration_profile(text)`
- `publish_1v1_final_standings_atomic(uuid)`
- `record_match_result_and_advance_atomic(uuid,integer,integer,integer,integer,uuid,text,jsonb)`
- `reject_join_request(text,text)`
- `remove_private_collective_participant_atomic(uuid,uuid)`
- `remove_public_match_participant_atomic(uuid,uuid)`
- `request_emergency_stadium_closure(uuid,uuid,text,integer)`
- `request_join_public_match(text,text)`
- `send_chat_message_atomic(uuid,text)`
- `send_support_ticket_message_atomic(uuid,text)`
- `start_owner_trial()`
- `submit_owner_verification(uuid,jsonb)`
- `submit_stadium_review_atomic(uuid,uuid,integer,text,text,text)`
- `update_collective_manual_players_atomic(uuid,uuid,integer)`
- `update_host_spots_atomic(uuid,uuid,integer)`
- `update_onboarding_confirmed_atomic(uuid,boolean)`
- `update_owner_onboarding_atomic(uuid,jsonb)`
- `update_owner_verification_document(uuid,text,text)`
- `verify_match_played(uuid,boolean,text)`
- `vsp_chat_write_allowed(uuid,uuid)`
- `vsp_is_admin_actor()`

### Financial / P0 manual review (21)

- `activate_championship_competition_atomic(uuid)`
- `activate_vsp_pro(text,text,integer)`
- `admin_record_payout_settlement_atomic(uuid,numeric,text,text)`
- `admin_set_owner_subscription_atomic(uuid,text,integer)`
- `admin_settle_owner_cash_debt_atomic(uuid,numeric,text)`
- `admin_upgrade_owner_subscription_atomic(uuid,text,integer)`
- `approve_payout_settlement_atomic(uuid,text)`
- `cancel_1v1_payment_order_atomic(text)`
- `cancel_1v1_tournament_with_refund_requests(uuid,text)`
- `cancel_booking_with_refund_atomic(uuid,text)` — **no direct caller marker**
- `cancel_booking_with_refund_atomic(uuid,uuid,text)` — **no direct caller marker**
- `cancel_tournament_payment_order_atomic(text)`
- `claim_owner_web_subscription()`
- `confirm_1v1_payment_atomic(text,text,numeric)` — **no direct caller marker**
- `create_1v1_payment_order_atomic(uuid)`
- `create_owner_subscription_order(text,text)`
- `get_team_league_payment_status(uuid,uuid)`
- `get_tournament_payment_order_status(text)`
- `prepare_team_league_payment(uuid,uuid)`
- `reject_payout_settlement_atomic(uuid,text)`
- `request_owner_payout_settlement_atomic(uuid,numeric,text,text)`

### Sports-write / P1 manual review (66)

- `add_team_member_atomic(uuid,uuid)`
- `add_team_to_matchup_by_code(uuid,text)`
- `cancel_championship_atomic(uuid,text)`
- `cancel_team_league(uuid)`
- `claim_owner_championship_approval_home_notice(uuid)`
- `cleanup_stale_pending_bookings_atomic(uuid,uuid)`
- `close_matchup_atomic(uuid)`
- `confirm_cash_booking_atomic(uuid,uuid,numeric,numeric)`
- `confirm_matchup_atomic(uuid)`
- `confirm_team_league_match_result(uuid,text)`
- `confirm_tournament_order_atomic(text,text)`
- `create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer)`
- `create_challenge_booking_atomic(text,text,timestamp with time zone,timestamp with time zone,text,boolean,text)`
- `create_championship_atomic(text,uuid,text,text,numeric,numeric,integer,integer,integer,timestamp with time zone,timestamp with time zone,timestamp with time zone,text,text,text,jsonb)`
- `create_team_league(text,uuid,text,integer,integer,text,integer)`
- `create_team_with_consent(jsonb,uuid[])`
- `create_tournament_order_atomic(uuid,uuid,uuid[],text[],text)`
- `crown_tournament_champion_atomic(uuid,uuid,text)`
- `delete_championship_atomic(uuid)`
- `delete_team_atomic(uuid)`
- `generate_booking_qr_token(uuid)`
- `generate_regular_league_fixtures_atomic(uuid)`
- `generate_team_challenge_code(uuid)`
- `generate_team_invite_code(uuid)`
- `generate_tournament_bracket_atomic(uuid)`
- `get_championship_actions(uuid)`
- `get_player_my_bookings_atomic(uuid)`
- `get_team_active_league(uuid)`
- `get_team_invite_code(uuid)`
- `get_team_league_standings(uuid)` — **no direct caller marker**
- `get_team_member_profiles(uuid)`
- `get_tournament_financial_summary(uuid)`
- `invite_team_member(uuid,uuid)`
- `join_1v1_tournament_atomic(uuid)`
- `join_championship_atomic(uuid,uuid,uuid[],text[])`
- `join_team_league(uuid,uuid)`
- `leave_1v1_tournament_atomic(uuid)`
- `leave_championship_atomic(uuid,uuid)`
- `link_league_match_booking(uuid,uuid,timestamp with time zone,text)`
- `lookup_challenge_code(text)`
- `mark_championship_prize_delivered_atomic(uuid,text)`
- `owner_cancel_manual_booking_atomic(uuid,uuid,boolean)`
- `owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer)`
- `owner_update_manual_booking_atomic(uuid,timestamp with time zone,text,text,text,integer,numeric)`
- `prepare_tournament_bracket_atomic(uuid)`
- `record_matchup_result_atomic(uuid,uuid,uuid,text)`
- `release_booking_lock(uuid)`
- `remove_team_member_atomic(uuid,uuid)`
- `remove_tournament_team_atomic(uuid,uuid)` — **no direct caller marker**
- `request_booking_reschedule_atomic(uuid,timestamp with time zone,timestamp with time zone)`
- `respond_booking_reschedule_atomic(uuid,boolean)`
- `respond_team_membership_invitation(uuid,boolean)`
- `save_and_publish_1v1_tournament_atomic(uuid,jsonb,uuid)`
- `start_championship_atomic(uuid)`
- `submit_challenge_result_atomic(uuid,uuid,text)`
- `submit_team_league_match_result(uuid,uuid,text)`
- `transfer_team_captaincy_atomic(uuid,uuid)`
- `transition_championship_status_atomic(uuid,text)`
- `update_championship_atomic(uuid,jsonb)`
- `update_championship_roster_atomic(uuid,uuid,uuid[],text[])`
- `update_team_atomic(uuid,jsonb)`
- `update_tournament_match_schedule_atomic(uuid,timestamp with time zone)`
- `verify_booking_qr_atomic(uuid,text)`
- `vsp_enforce_booking_operating_window()` — **no direct caller marker**
- `vsp_user_is_tournament_participant(uuid,uuid)` — **no direct caller marker**
- `withdraw_team_from_championship_atomic(uuid,uuid,text)`

### Admin-identity / P0 manual review (36)

- `admin_add_1v1_cash_player_atomic(uuid,text,uuid,numeric)`
- `admin_approve_1v1_registration_atomic(uuid,text,text)`
- `admin_approve_championship_atomic(uuid)`
- `admin_approve_owner_atomic(uuid)`
- `admin_cancel_booking_atomic(uuid,text)`
- `admin_create_1v1_tournament_atomic(text,integer,numeric,timestamp with time zone,text,numeric)`
- `admin_create_owner_with_stadium_atomic(text,text,text,text,text,numeric)`
- `admin_finalize_1v1_tournament_atomic(uuid,uuid)`
- `admin_get_1v1_round_scores(uuid,integer)`
- `admin_publish_legacy_1v1_standings_atomic(jsonb)`
- `admin_register_owner_on_behalf(text,text,text,text,text)`
- `admin_reject_1v1_registration_atomic(uuid)`
- `admin_reject_championship_atomic(uuid,text)`
- `admin_reject_owner_atomic(uuid,text)`
- `admin_reset_1v1_round_atomic()`
- `admin_reset_no_show_count_atomic(uuid)`
- `admin_resolve_dispute_atomic(uuid,text,integer,integer,text)`
- `admin_resolve_report_atomic(uuid,text,text)`
- `admin_save_1v1_tournament_players_atomic(uuid,jsonb)`
- `admin_send_broadcast_notification_atomic(text,text,text,text)`
- `admin_set_1v1_registration_open_atomic(boolean)`
- `admin_set_admin_role_atomic(uuid,text)`
- `admin_set_maintenance_mode_atomic(boolean)`
- `admin_toggle_user_block(uuid,boolean)`
- `admin_update_1v1_player_stats_atomic(uuid,integer,integer,integer,integer,integer,text)`
- `admin_update_1v1_tournament_atomic(uuid,text,integer,numeric,timestamp with time zone,text,numeric)`
- `admin_update_1v1_tournament_status_atomic(uuid,text)`
- `admin_update_1v1_tournament_status(uuid,text,uuid)`
- `admin_update_booking_safe_atomic(uuid,jsonb)`
- `admin_update_championship_status_atomic(uuid,text,text)`
- `admin_update_support_ticket_atomic(uuid,text,text,uuid)` — **no direct caller marker**
- `admin_wipe_1v1_data_atomic()`
- `block_user_atomic(uuid)`
- `get_current_user_role(uuid)`
- `set_user_role_on_signup(text,uuid)`
- `unblock_user_atomic(uuid)`

## Safety and next validation

1. For financial/admin operations: inspect the full stored function body and chained helpers, compare grants and negative RLS role tests, and confirm parameter ownership. An absent text marker is **not** proof of an authorization bypass.
2. Review sports-write RPCs with two isolated staging users and controlled fixture records; assert denial for cross-team/cross-owner access.
3. Never run real payment/refund side effects or modify production; follow the existing Issue #38 security-audit workflow.
4. **Accepted:** 77.02 review priority classification and 77.03 execution owner census only. **Not accepted:** 77.04–77.11 exploitation/authorization/grant remediation work.

Source is the 2026-11-13 staging `pg_proc` catalog snapshot, not an assertion of current production permissions.
