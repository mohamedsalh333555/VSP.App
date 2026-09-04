-- Migration: 202609050002_phase1_revoke_anon_and_cron_permissions.sql
-- Lock down all internal, admin, and authenticated routines from anon/PUBLIC.

REVOKE EXECUTE ON FUNCTION public."accept_join_request"(p_booking_id text, p_user_id text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."accept_join_request"(p_booking_id text, p_user_id text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."add_team_to_matchup_by_code"(p_booking_id uuid, p_invite_code text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."add_team_to_matchup_by_code"(p_booking_id uuid, p_invite_code text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."admin_record_payout_settlement_atomic"(p_owner_id uuid, p_amount numeric, p_payment_method text, p_reference text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."admin_record_payout_settlement_atomic"(p_owner_id uuid, p_amount numeric, p_payment_method text, p_reference text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."admin_resolve_dispute_atomic"(p_booking_id uuid, p_final_outcome text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."admin_resolve_dispute_atomic"(p_booking_id uuid, p_final_outcome text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."admin_upgrade_owner_subscription_atomic"(p_owner_id uuid, p_plan text, p_days integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."admin_upgrade_owner_subscription_atomic"(p_owner_id uuid, p_plan text, p_days integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."approve_payout_settlement_atomic"(p_settlement_id uuid, p_admin_notes text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."approve_payout_settlement_atomic"(p_settlement_id uuid, p_admin_notes text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."cancel_booking_with_refund_atomic"(p_booking_id uuid, p_user_id uuid, p_reason text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."cancel_booking_with_refund_atomic"(p_booking_id uuid, p_user_id uuid, p_reason text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."check_1v1_registration_capacity"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."check_1v1_registration_capacity"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."check_owner_stadium_limit"(p_owner_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."check_owner_stadium_limit"(p_owner_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."check_owner_stadium_limit"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."check_owner_stadium_limit"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."check_team_membership_limit"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."check_team_membership_limit"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."close_matchup_atomic"(p_booking_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."close_matchup_atomic"(p_booking_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."close_owner_daily_shift"(p_owner_id uuid, p_stadium_id uuid, p_operational_date date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."close_owner_daily_shift"(p_owner_id uuid, p_stadium_id uuid, p_operational_date date) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."complete_user_registration"(p_user_id uuid, p_phone text, p_name text, p_position text, p_governorate text, p_date_of_birth timestamp with time zone, p_p2p_instapay text, p_p2p_vodafone text, p_p2p_bank text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."complete_user_registration"(p_user_id uuid, p_phone text, p_name text, p_position text, p_governorate text, p_date_of_birth timestamp with time zone, p_p2p_instapay text, p_p2p_vodafone text, p_p2p_bank text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."confirm_cash_booking_atomic"(p_booking_id uuid, p_owner_id uuid, p_total_price numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."confirm_cash_booking_atomic"(p_booking_id uuid, p_owner_id uuid, p_total_price numeric) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."confirm_matchup_atomic"(p_booking_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."confirm_matchup_atomic"(p_booking_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."create_booking_atomic"(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text, p_stadium_image_url text, p_is_private boolean, p_rent_ball boolean, p_needs_deposit boolean, p_deposit_amount numeric, p_payment_method text, p_payment_status text, p_player_team_id text, p_player_team_name text, p_opponent_team_id text, p_opponent_team_name text, p_platform_fee numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."create_booking_atomic"(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text, p_stadium_image_url text, p_is_private boolean, p_rent_ball boolean, p_needs_deposit boolean, p_deposit_amount numeric, p_payment_method text, p_payment_status text, p_player_team_id text, p_player_team_name text, p_opponent_team_id text, p_opponent_team_name text, p_platform_fee numeric) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."create_tournament_order_atomic"(p_championship_id uuid, p_team_id uuid, p_player_ids uuid[], p_guest_names text[], p_amount numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."create_tournament_order_atomic"(p_championship_id uuid, p_team_id uuid, p_player_ids uuid[], p_guest_names text[], p_amount numeric) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."crown_tournament_champion_atomic"(p_championship_id uuid, p_champion_team_id uuid, p_champion_team_name text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."crown_tournament_champion_atomic"(p_championship_id uuid, p_champion_team_id uuid, p_champion_team_name text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."delete_chat_for_user"(p_conversation_id uuid, p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."delete_chat_for_user"(p_conversation_id uuid, p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."delete_chat_for_user_atomic"(p_booking_id uuid, p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."delete_chat_for_user_atomic"(p_booking_id uuid, p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."delete_user_permanently"(p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."delete_user_permanently"(p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."dispute_no_show_with_gps"(p_booking_id text, p_player_id text, p_lat numeric, p_lng numeric, p_accuracy numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."dispute_no_show_with_gps"(p_booking_id text, p_player_id text, p_lat numeric, p_lng numeric, p_accuracy numeric) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."enforce_real_sender_name"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."enforce_real_sender_name"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."generate_team_invite_code"(p_team_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."generate_team_invite_code"(p_team_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."get_admin_metrics"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."get_admin_metrics"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."get_admin_quick_metrics"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."get_admin_quick_metrics"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."get_operational_date"(p_timestamp timestamp with time zone, p_shift_start_hour integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."get_operational_date"(p_timestamp timestamp with time zone, p_shift_start_hour integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."get_owner_booked_hours"(p_owner_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."get_owner_booked_hours"(p_owner_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."get_owner_revenue"(p_owner_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."get_owner_revenue"(p_owner_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."is_admin_or_cofounder"(p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."is_admin_or_cofounder"(p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."join_championship_atomic"(p_championship_id uuid, p_team_id uuid, p_is_paid boolean, p_player_ids uuid[], p_guest_names text[], p_total_paid_amount numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."join_championship_atomic"(p_championship_id uuid, p_team_id uuid, p_is_paid boolean, p_player_ids uuid[], p_guest_names text[], p_total_paid_amount numeric) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."leave_championship_atomic"(p_championship_id uuid, p_team_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."leave_championship_atomic"(p_championship_id uuid, p_team_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."leave_public_match_atomic"(p_booking_id uuid, p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."leave_public_match_atomic"(p_booking_id uuid, p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."lock_sensitive_user_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."lock_sensitive_user_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."mark_chat_messages_as_read"(p_conversation_id uuid, p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."mark_chat_messages_as_read"(p_conversation_id uuid, p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."owner_create_manual_booking_atomic"(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text, p_notes text, p_total_price numeric, p_collected_amount numeric, p_current_players integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."owner_create_manual_booking_atomic"(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text, p_notes text, p_total_price numeric, p_collected_amount numeric, p_current_players integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."owner_lock_slot_atomic"(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_reason text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."owner_lock_slot_atomic"(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_reason text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."prepare_tournament_bracket"(p_championship_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."prepare_tournament_bracket"(p_championship_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."prepare_tournament_bracket_atomic"(p_championship_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."prepare_tournament_bracket_atomic"(p_championship_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."prevent_unauthorized_role_change"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."prevent_unauthorized_role_change"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_booking_payment_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_booking_payment_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_booking_sensitive_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_booking_sensitive_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_championship_sensitive_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_championship_sensitive_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_completed_match_scores"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_completed_match_scores"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_stadium_sensitive_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_stadium_sensitive_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_team_sensitive_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_team_sensitive_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_user_sensitive_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_user_sensitive_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."protect_user_verification_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."protect_user_verification_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."record_match_result_and_advance_atomic"(p_match_id uuid, p_home_score integer, p_away_score integer, p_home_penalties integer, p_away_penalties integer, p_winner_id uuid, p_winner_name text, p_goal_details jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."record_match_result_and_advance_atomic"(p_match_id uuid, p_home_score integer, p_away_score integer, p_home_penalties integer, p_away_penalties integer, p_winner_id uuid, p_winner_name text, p_goal_details jsonb) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."record_matchup_result_atomic"(p_booking_id uuid, p_team_a_id uuid, p_team_b_id uuid, p_outcome text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."record_matchup_result_atomic"(p_booking_id uuid, p_team_a_id uuid, p_team_b_id uuid, p_outcome text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."reject_join_request"(p_booking_id text, p_user_id text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."reject_join_request"(p_booking_id text, p_user_id text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."release_booking_lock"(p_booking_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."release_booking_lock"(p_booking_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."request_emergency_stadium_closure"(p_stadium_id uuid, p_owner_id uuid, p_reason text, p_duration_hours integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."request_emergency_stadium_closure"(p_stadium_id uuid, p_owner_id uuid, p_reason text, p_duration_hours integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."request_join_public_match"(p_booking_id text, p_user_id text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."request_join_public_match"(p_booking_id text, p_user_id text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."request_owner_payout_settlement_atomic"(p_owner_id uuid, p_amount numeric, p_method text, p_destination text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."request_owner_payout_settlement_atomic"(p_owner_id uuid, p_amount numeric, p_method text, p_destination text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."reset_fair_play_score_annually"() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."reset_fair_play_score_annually"() TO service_role;

REVOKE EXECUTE ON FUNCTION public."sanitize_user_phone"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sanitize_user_phone"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."set_user_role_on_signup"(p_role text, p_user_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."set_user_role_on_signup"(p_role text, p_user_id uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."submit_owner_verification"(p_owner_id uuid, p_additional_data jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."submit_owner_verification"(p_owner_id uuid, p_additional_data jsonb) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."submit_stadium_review_atomic"(p_stadium_id uuid, p_user_id uuid, p_user_name text, p_user_image_url text, p_rating integer, p_comment text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."submit_stadium_review_atomic"(p_stadium_id uuid, p_user_id uuid, p_user_name text, p_user_image_url text, p_rating integer, p_comment text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_booking_players_table"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_booking_players_table"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_booking_user_ids"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_booking_user_ids"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_head_to_head_on_result_insert"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_head_to_head_on_result_insert"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_notification_message_body"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_notification_message_body"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_owner_has_stadium"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_owner_has_stadium"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_owner_has_stadium_on_soft_delete"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_owner_has_stadium_on_soft_delete"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."sync_owner_pro_features"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."sync_owner_pro_features"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."trg_protect_bookings_payment_fields"() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."trg_protect_bookings_payment_fields"() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public."update_host_spots_atomic"(p_booking_id uuid, p_user_id uuid, p_new_host_spots integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public."update_host_spots_atomic"(p_booking_id uuid, p_user_id uuid, p_new_host_spots integer) TO authenticated, service_role;
