-- ==========================================================================
-- VSP SUPABASE SCHEMA REFERENCE BACKUP - PHASE 0
-- Project Ref: mktqkddbcddrxjxabdua
-- Exported automatically via Supabase Management API
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. EXTENSIONS
-- --------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH VERSION '1.11';
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH VERSION '1.1';
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH VERSION '1.3';
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH VERSION '0.3.1';
CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH VERSION '1.6.4';
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH VERSION '0.20.3';
CREATE EXTENSION IF NOT EXISTS "http" WITH VERSION '1.6';
CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH VERSION '1.7';
CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH VERSION '1.6';


-- --------------------------------------------------------------------------
-- 2. CUSTOM TYPES / ENUMS
-- --------------------------------------------------------------------------


-- --------------------------------------------------------------------------
-- 3. TABLES DEFINITION
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public."account_deletion_requests" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "details" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "processed_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."ai_copilot_audit_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "request_id" UUID NOT NULL,
    "conversation_id" UUID,
    "user_id" UUID,
    "user_role" TEXT NOT NULL,
    "event_type" TEXT NOT NULL,
    "capability_id" TEXT,
    "tool_name" TEXT,
    "action_type" TEXT,
    "status" TEXT NOT NULL,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "verification_source" TEXT,
    "error_code" TEXT,
    "request_hash" TEXT,
    "latency_ms" INTEGER,
    "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."app_config" (
    "id" INTEGER NOT NULL DEFAULT nextval('app_config_id_seq'::regclass),
    "is_maintenance" BOOLEAN DEFAULT false,
    "min_version" TEXT DEFAULT '1.0.0'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "vsp_1v1_is_open" BOOLEAN DEFAULT false,
    "vsp_1v1_link" TEXT
);

CREATE TABLE IF NOT EXISTS public."app_settings" (
    "id" UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    "support_phone" TEXT DEFAULT '01100229462'::text,
    "whatsapp_number" TEXT DEFAULT '+201100229462'::text,
    "support_email" TEXT DEFAULT 'support@vspapp.com'::text,
    "vodafone_cash_number" TEXT DEFAULT '01100229462'::text,
    "instapay_handle" TEXT DEFAULT 'vsp@instapay'::text,
    "cash_booking_enabled" BOOLEAN DEFAULT true,
    "online_payment_enabled" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."banners" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title" TEXT NOT NULL,
    "description" TEXT,
    "image_url" TEXT NOT NULL,
    "target_url" TEXT,
    "placement" TEXT NOT NULL DEFAULT 'home_slider'::text,
    "duration_seconds" INTEGER NOT NULL DEFAULT 5,
    "start_date" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    "end_date" TIMESTAMP WITH TIME ZONE,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "priority_order" INTEGER NOT NULL DEFAULT 0,
    "clicks_count" INTEGER NOT NULL DEFAULT 0,
    "views_count" INTEGER NOT NULL DEFAULT 0,
    "created_by" UUID,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."booking_players" (
    "booking_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "joined_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."booking_public_feed" (
    "id" UUID NOT NULL,
    "stadium_id" UUID,
    "stadium_name" TEXT,
    "stadium_image_url" TEXT,
    "start_time" TIMESTAMP WITH TIME ZONE NOT NULL,
    "end_time" TIMESTAMP WITH TIME ZONE NOT NULL,
    "operational_date" DATE,
    "booking_type" TEXT,
    "player_team_id" UUID,
    "player_team_name" TEXT,
    "player_team_logo_url" TEXT,
    "host_name" TEXT,
    "host_avatar_url" TEXT,
    "opponent_team_id" UUID,
    "opponent_team_name" TEXT,
    "opponent_team_logo_url" TEXT,
    "is_private" BOOLEAN NOT NULL DEFAULT false,
    "rent_ball" BOOLEAN NOT NULL DEFAULT false,
    "total_price" NUMERIC NOT NULL DEFAULT 0,
    "currency" TEXT NOT NULL DEFAULT 'EGP'::text,
    "status" TEXT NOT NULL,
    "match_result_status" TEXT DEFAULT 'noResult'::text,
    "home_score" INTEGER,
    "away_score" INTEGER,
    "final_outcome" TEXT,
    "current_players" INTEGER NOT NULL DEFAULT 1,
    "players_per_team" INTEGER NOT NULL DEFAULT 5,
    "total_field_capacity" INTEGER NOT NULL DEFAULT 10,
    "matchup_mode" TEXT,
    "matchup_closed_at" TIMESTAMP WITH TIME ZONE,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS public."bookings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "stadium_id" UUID,
    "stadium_name" TEXT,
    "stadium_image_url" TEXT,
    "owner_id" UUID,
    "created_by_user_id" UUID,
    "start_time" TIMESTAMP WITH TIME ZONE NOT NULL,
    "end_time" TIMESTAMP WITH TIME ZONE NOT NULL,
    "booking_type" TEXT,
    "player_team_id" UUID,
    "player_team_name" TEXT,
    "player_team_logo_url" TEXT,
    "host_name" TEXT,
    "host_avatar_url" TEXT,
    "opponent_team_id" UUID,
    "opponent_team_name" TEXT,
    "opponent_team_logo_url" TEXT,
    "is_private" BOOLEAN DEFAULT true,
    "rent_ball" BOOLEAN DEFAULT false,
    "total_price" NUMERIC NOT NULL,
    "currency" TEXT DEFAULT 'EGP'::text,
    "payment_method" TEXT DEFAULT 'cash'::text,
    "payment_transaction_id" TEXT,
    "status" TEXT NOT NULL DEFAULT 'confirmed'::text,
    "is_paid" BOOLEAN DEFAULT false,
    "payment_status" TEXT DEFAULT 'pending'::text,
    "player_phone" TEXT,
    "notes" TEXT,
    "home_score" INTEGER,
    "away_score" INTEGER,
    "result_submitted_by_team_id" UUID,
    "match_result_status" TEXT DEFAULT 'noResult'::text,
    "pending_outcome" TEXT,
    "final_outcome" TEXT,
    "requires_admin_intervention" BOOLEAN DEFAULT false,
    "current_players" INTEGER DEFAULT 1,
    "max_players" INTEGER DEFAULT 10,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "deposit_receipt_url" TEXT,
    "receipt_url" TEXT,
    "elo_processed" BOOLEAN DEFAULT false,
    "deposit_paid" NUMERIC DEFAULT 0.0,
    "is_deposit_paid" BOOLEAN DEFAULT false,
    "joined_user_ids" uuid[] DEFAULT '{}'::uuid[],
    "paymob_order_id" TEXT,
    "paymob_transaction_id" TEXT,
    "payment_gateway_logs" JSONB DEFAULT '{}'::jsonb,
    "is_verified_by_owner" BOOLEAN,
    "absent_team_id" TEXT,
    "is_dispute_approved" BOOLEAN,
    "dispute_photo_url" TEXT,
    "payment_hold_released" BOOLEAN DEFAULT false,
    "result_submitted_at" TIMESTAMP WITH TIME ZONE,
    "pending_user_ids" text[] DEFAULT '{}'::text[],
    "user_id" UUID,
    "platform_fee" NUMERIC DEFAULT 0.0,
    "is_official_match" BOOLEAN DEFAULT true,
    "operational_date" DATE,
    "unread_counts" JSONB DEFAULT '{}'::jsonb,
    "last_message" TEXT,
    "last_message_time" TIMESTAMP WITH TIME ZONE,
    "deleted_for_users" text[] DEFAULT '{}'::text[],
    "cancelled_at" TIMESTAMP WITH TIME ZONE,
    "refund_amount" NUMERIC DEFAULT NULL::numeric,
    "payment_reference" TEXT,
    "initial_players_count" INTEGER DEFAULT 1,
    "total_field_capacity" INTEGER DEFAULT 10,
    "challenge_status" TEXT,
    "paymob_txn_id" TEXT,
    "webhook_processed_at" TIMESTAMP WITH TIME ZONE,
    "webhook_verified" BOOLEAN DEFAULT false,
    "deposit_amount" NUMERIC DEFAULT 0,
    "needs_deposit" BOOLEAN DEFAULT false,
    "reschedule_status" TEXT DEFAULT 'none'::text,
    "proposed_start_time" TIMESTAMP WITH TIME ZONE,
    "proposed_end_time" TIMESTAMP WITH TIME ZONE,
    "emergency_cancel_status" TEXT DEFAULT 'none'::text,
    "emergency_reason" TEXT,
    "emergency_downtime_hours" INTEGER,
    "cancellation_reason" TEXT,
    "locked_until" TIMESTAMP WITH TIME ZONE,
    "matchup_mode" TEXT,
    "matchup_closed_at" TIMESTAMP WITH TIME ZONE,
    "refund_transaction_id" TEXT,
    "refunded_at" TIMESTAMP WITH TIME ZONE,
    "refund_payment_method" TEXT,
    "vsp_commission" NUMERIC NOT NULL DEFAULT 0.00,
    "gateway_fee" NUMERIC NOT NULL DEFAULT 0.00,
    "qr_hash" TEXT,
    "qr_expires_at" TIMESTAMP WITH TIME ZONE,
    "qr_scanned_at" TIMESTAMP WITH TIME ZONE,
    "payment_reconcile_state" TEXT NOT NULL DEFAULT 'unpaid'::text,
    "payment_source" TEXT NOT NULL DEFAULT 'pending'::text,
    "idempotency_key" TEXT,
    "gross_amount_charged" NUMERIC,
    "manual_player_count" INTEGER NOT NULL DEFAULT 0,
    "collective_invite_token" TEXT,
    "collective_invite_code" TEXT,
    "collective_invite_active" BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public."cancellation_refund_queue" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "championship_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "registration_id" UUID NOT NULL,
    "paymob_transaction_id" TEXT,
    "amount" NUMERIC NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'EGP'::text,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "retry_count" INTEGER NOT NULL DEFAULT 0,
    "failure_reason" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "processed_at" TIMESTAMP WITH TIME ZONE,
    "processing_started_at" TIMESTAMP WITH TIME ZONE,
    "locked_until" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."challenge_results" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "challenge_id" TEXT NOT NULL,
    "team1_score" INTEGER NOT NULL DEFAULT 0,
    "team2_score" INTEGER NOT NULL DEFAULT 0,
    "submitted_by" TEXT NOT NULL,
    "confirmed_by" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "confirmed_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."championship_registrations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "championship_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "captain_id" UUID,
    "captain_snapshot" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "registration_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "payment_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "base_amount" NUMERIC NOT NULL DEFAULT 0.00,
    "gross_amount" NUMERIC NOT NULL DEFAULT 0.00,
    "currency" TEXT NOT NULL DEFAULT 'EGP'::text,
    "notes" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."championship_roster_guests" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "roster_id" UUID,
    "guest_name" TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public."championship_roster_players" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "roster_id" UUID,
    "player_id" UUID
);

CREATE TABLE IF NOT EXISTS public."championship_rosters" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "championship_id" UUID,
    "team_id" UUID,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "guest_names" JSONB DEFAULT '[]'::jsonb,
    "registration_id" UUID,
    "is_frozen" BOOLEAN NOT NULL DEFAULT false,
    "frozen_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."championships" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "sport_type" TEXT DEFAULT 'Football'::text,
    "logo_url" TEXT,
    "start_date" TIMESTAMP WITH TIME ZONE NOT NULL,
    "end_date" TIMESTAMP WITH TIME ZONE NOT NULL,
    "entry_fee" NUMERIC NOT NULL,
    "grand_prize" NUMERIC NOT NULL,
    "max_teams" INTEGER DEFAULT 16,
    "owner_id" UUID NOT NULL,
    "governorate" TEXT NOT NULL,
    "rules" TEXT,
    "payment_methods" text[] DEFAULT '{cash}'::text[],
    "max_players_per_team" INTEGER DEFAULT 11,
    "min_players_per_team" INTEGER DEFAULT 5,
    "winning_points" INTEGER DEFAULT 3,
    "draw_points" INTEGER DEFAULT 1,
    "loss_points" INTEGER DEFAULT 0,
    "match_duration" INTEGER DEFAULT 30,
    "is_back_and_forth" BOOLEAN DEFAULT false,
    "trophy_medals" BOOLEAN DEFAULT true,
    "red_card_suspension" BOOLEAN DEFAULT true,
    "fair_play_scoring" BOOLEAN DEFAULT false,
    "status" TEXT DEFAULT 'open'::text,
    "champion_team_id" UUID,
    "champion_team_name" TEXT,
    "paid_teams" text[] DEFAULT '{}'::uuid[],
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "joined_teams" text[] DEFAULT '{}'::text[],
    "is_approved" BOOLEAN DEFAULT false,
    "winner_team_id" UUID,
    "winner_team_name" TEXT,
    "number_of_groups" INTEGER DEFAULT 1,
    "qualifying_per_group" INTEGER DEFAULT 2,
    "is_two_legs" BOOLEAN DEFAULT false,
    "creation_payment_id" TEXT,
    "creation_fee_paid" BOOLEAN DEFAULT false,
    "champion_user_id" UUID,
    "settings" JSONB DEFAULT '{}'::jsonb,
    "prize_pool" NUMERIC NOT NULL DEFAULT 0.00,
    "prize_delivered" BOOLEAN NOT NULL DEFAULT false,
    "prize_delivered_at" TIMESTAMP WITH TIME ZONE,
    "prize_delivered_by" UUID,
    "prize_delivery_notes" TEXT,
    "template_type" TEXT,
    "registration_locked_at" TIMESTAMP WITH TIME ZONE,
    "match_interval_days" INTEGER DEFAULT 7,
    "paid_by_creator_count" INTEGER DEFAULT 1,
    "stadium_id" UUID,
    "registration_closes_at" TIMESTAMP WITH TIME ZONE,
    "currency" TEXT NOT NULL DEFAULT 'EGP'::text,
    "rejection_reason" TEXT,
    "rejected_at" TIMESTAMP WITH TIME ZONE,
    "rejected_by" UUID,
    "owner_approval_home_seen_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."chat_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "booking_id" UUID,
    "sender_id" UUID NOT NULL,
    "sender_name" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "is_read" BOOLEAN DEFAULT false,
    "is_edited" BOOLEAN DEFAULT false,
    "deleted_for_users" uuid[] DEFAULT '{}'::uuid[],
    "conversation_id" UUID
);

CREATE TABLE IF NOT EXISTS public."conversations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "type" TEXT NOT NULL DEFAULT 'direct'::text,
    "booking_id" UUID,
    "participant_ids" uuid[] NOT NULL DEFAULT '{}'::uuid[],
    "title" TEXT,
    "last_message" TEXT,
    "last_message_time" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "unread_counts" JSONB DEFAULT '{}'::jsonb,
    "deleted_for_users" uuid[] DEFAULT '{}'::uuid[],
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "context_type" TEXT,
    "context_id" UUID
);

CREATE TABLE IF NOT EXISTS public."copilot_conversations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "title" TEXT NOT NULL DEFAULT 'محادثة جديدة'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "context_snapshot" JSONB DEFAULT '{}'::jsonb,
    "is_initialized" BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public."copilot_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "conversation_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "stadium_results" JSONB DEFAULT '[]'::jsonb,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "ui_metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "message_sequence" BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public."court_operating_hours" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "court_id" UUID NOT NULL,
    "day_of_week" INTEGER NOT NULL,
    "open_time" TIME WITHOUT TIME ZONE NOT NULL DEFAULT '16:00:00'::time without time zone,
    "close_time" TIME WITHOUT TIME ZONE NOT NULL DEFAULT '02:00:00'::time without time zone,
    "is_closed" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."financial_audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "booking_id" UUID,
    "user_id" UUID,
    "owner_id" UUID,
    "amount" NUMERIC NOT NULL,
    "fee" NUMERIC NOT NULL,
    "action_type" TEXT NOT NULL,
    "payment_method" TEXT NOT NULL,
    "transaction_ref" TEXT,
    "metadata" JSONB DEFAULT '{}'::jsonb,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."internal_function_secrets" (
    "name" TEXT NOT NULL,
    "secret" TEXT NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."league_settings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "setting_key" TEXT NOT NULL,
    "setting_value" TEXT NOT NULL,
    "description" TEXT,
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."match_score_edits" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "championship_id" UUID NOT NULL,
    "old_score_home" INTEGER,
    "old_score_away" INTEGER,
    "old_penalties_home" INTEGER,
    "old_penalties_away" INTEGER,
    "new_score_home" INTEGER NOT NULL,
    "new_score_away" INTEGER NOT NULL,
    "new_penalties_home" INTEGER,
    "new_penalties_away" INTEGER,
    "edited_by" UUID NOT NULL,
    "edit_reason" TEXT NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."matchup_results" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "booking_id" UUID NOT NULL,
    "team_a_id" UUID NOT NULL,
    "team_b_id" UUID NOT NULL,
    "outcome" TEXT NOT NULL,
    "recorded_by" UUID,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."matchup_teams" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "booking_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "added_by_user_id" UUID,
    "joined_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "booking_id" UUID,
    "metadata" JSONB,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "message" TEXT
);

CREATE TABLE IF NOT EXISTS public."owner_documents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID NOT NULL,
    "document_type" TEXT NOT NULL DEFAULT 'commercial_registry'::text,
    "file_url" TEXT NOT NULL,
    "storage_path" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "rejection_reason" TEXT,
    "metadata" JSONB DEFAULT '{}'::jsonb,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."owner_subscription_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID,
    "plan_code" TEXT NOT NULL,
    "billing_period" TEXT NOT NULL,
    "amount" NUMERIC NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "paymob_order_id" TEXT,
    "paymob_transaction_id" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "paid_at" TIMESTAMP WITH TIME ZONE,
    "checkout_email" TEXT,
    "checkout_phone" TEXT,
    "payment_source" TEXT NOT NULL DEFAULT 'app'::text,
    "paymob_intention_id" TEXT,
    "claim_expires_at" TIMESTAMP WITH TIME ZONE,
    "checkout_name" TEXT,
    "duration_days" INTEGER,
    "vsp_fee_amount" NUMERIC,
    "paymob_fee_amount" NUMERIC,
    "gross_amount" NUMERIC
);

CREATE TABLE IF NOT EXISTS public."owner_trial_ledger" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "user_id" UUID,
    "first_trial_started_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "original_trial_ends_at" TIMESTAMP WITH TIME ZONE NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."payout_settlements" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID,
    "amount" NUMERIC NOT NULL,
    "method" TEXT NOT NULL,
    "destination" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "admin_notes" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."platform_business_rules" (
    "id" BIGINT NOT NULL,
    "booking_min_duration_minutes" INTEGER NOT NULL,
    "booking_max_duration_hours" NUMERIC NOT NULL,
    "manual_booking_max_duration_hours" NUMERIC NOT NULL,
    "payment_lock_minutes" INTEGER NOT NULL,
    "booking_past_grace_minutes" INTEGER NOT NULL,
    "cash_no_show_limit" INTEGER NOT NULL,
    "default_cash_debt_limit" NUMERIC NOT NULL,
    "player_cancellation_grace_minutes" INTEGER NOT NULL,
    "player_cancellation_cutoff_hours" NUMERIC NOT NULL,
    "late_cancellation_cutoff_hours" NUMERIC NOT NULL,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."platform_fee_config" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "booking_vsp_rate" NUMERIC NOT NULL,
    "booking_paymob_rate" NUMERIC NOT NULL,
    "booking_paymob_fixed_fee" NUMERIC NOT NULL,
    "vsp_applies_to_cash" BOOLEAN NOT NULL DEFAULT false,
    "paymob_applies_to_electronic" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "booking_paymob_local_rate" NUMERIC NOT NULL DEFAULT 0.024000,
    "booking_paymob_foreign_rate" NUMERIC NOT NULL DEFAULT 0.026000,
    "booking_paymob_wallet_rate" NUMERIC NOT NULL DEFAULT 0.024000,
    "subscription_vsp_rate" NUMERIC NOT NULL DEFAULT 0.020000,
    "subscription_paymob_rate" NUMERIC NOT NULL DEFAULT 0.027500,
    "subscription_paymob_fixed_fee" NUMERIC NOT NULL DEFAULT 3.00
);

CREATE TABLE IF NOT EXISTS public."player_trophies" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "championship_id" UUID,
    "title" TEXT NOT NULL,
    "prize_won" NUMERIC DEFAULT 0,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "tournament_1v1_id" UUID
);

CREATE TABLE IF NOT EXISTS public."promotions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title" TEXT NOT NULL,
    "image_url" TEXT NOT NULL,
    "deep_link" TEXT,
    "type" TEXT DEFAULT 'info'::text,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."rate_limit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "action" TEXT NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."reports" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "reporter_id" UUID,
    "target_id" TEXT NOT NULL,
    "target_type" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "details" TEXT,
    "status" TEXT DEFAULT 'pending'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "context_type" TEXT,
    "context_id" UUID,
    "booking_id" UUID,
    "conversation_id" UUID
);

CREATE TABLE IF NOT EXISTS public."reviews" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "stadium_id" UUID NOT NULL,
    "user_id" UUID,
    "rating" INTEGER,
    "review_text" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "user_name" TEXT,
    "user_image_url" TEXT
);

CREATE TABLE IF NOT EXISTS public."stadium_custom_rates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "stadium_id" UUID NOT NULL,
    "day_of_week" INTEGER,
    "specific_date" DATE,
    "start_time" TIME WITHOUT TIME ZONE NOT NULL,
    "end_time" TIME WITHOUT TIME ZONE NOT NULL,
    "price_per_hour" NUMERIC NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."stadiums" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "governorate" TEXT NOT NULL,
    "price_per_hour" NUMERIC NOT NULL,
    "base_price" NUMERIC NOT NULL,
    "seats_capacity" INTEGER DEFAULT 0,
    "image_url" TEXT,
    "images" text[] DEFAULT '{}'::text[],
    "rating" NUMERIC DEFAULT 4.5,
    "reviews_count" INTEGER DEFAULT 0,
    "notes" TEXT,
    "is_verified" BOOLEAN DEFAULT true,
    "is_featured" BOOLEAN DEFAULT false,
    "is_blocked" BOOLEAN DEFAULT false,
    "opening_time" TIME WITHOUT TIME ZONE DEFAULT '08:00:00'::time without time zone,
    "closing_time" TIME WITHOUT TIME ZONE DEFAULT '00:00:00'::time without time zone,
    "is_split_shift" BOOLEAN DEFAULT false,
    "break_start_time" TIME WITHOUT TIME ZONE,
    "break_end_time" TIME WITHOUT TIME ZONE,
    "lat" NUMERIC,
    "lng" NUMERIC,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "needs_deposit" BOOLEAN DEFAULT false,
    "deposit_amount" NUMERIC DEFAULT 0.0,
    "city" TEXT,
    "description" TEXT,
    "features" JSONB DEFAULT '{}'::jsonb,
    "players_per_team" INTEGER DEFAULT 5,
    "total_field_capacity" INTEGER DEFAULT 10,
    "is_deleted_by_owner" BOOLEAN DEFAULT false,
    "maintenance_until" TIMESTAMP WITH TIME ZONE,
    "maintenance_reason" TEXT,
    "last_emergency_closure_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."subscription_plans" (
    "code" TEXT NOT NULL,
    "name_ar" TEXT NOT NULL,
    "name_en" TEXT NOT NULL,
    "description_ar" TEXT,
    "description_en" TEXT,
    "monthly_price" NUMERIC NOT NULL,
    "yearly_price" NUMERIC NOT NULL,
    "trial_days" INTEGER NOT NULL DEFAULT 0,
    "max_stadiums" INTEGER NOT NULL DEFAULT 1,
    "features" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."support_ticket_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ticket_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "is_internal" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."support_tickets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "requester_id" UUID NOT NULL,
    "subject" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'open'::text,
    "priority" TEXT NOT NULL DEFAULT 'normal'::text,
    "context_type" TEXT,
    "context_id" UUID,
    "booking_id" UUID,
    "conversation_id" UUID,
    "assigned_to" UUID,
    "source" TEXT NOT NULL DEFAULT 'in_app'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "last_message_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "resolved_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."system_audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "table_name" TEXT NOT NULL,
    "record_id" UUID NOT NULL,
    "action" TEXT NOT NULL,
    "changed_by" UUID DEFAULT auth.uid(),
    "changed_by_role" TEXT,
    "old_data" JSONB,
    "new_data" JSONB,
    "changed_fields" text[],
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."team_challenge_codes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "team_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active'::text,
    "used_in_booking_id" UUID,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "used_at" TIMESTAMP WITH TIME ZONE,
    "expires_at" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."team_head_to_head" (
    "team_a_id" UUID NOT NULL,
    "team_b_id" UUID NOT NULL,
    "team_a_wins" INTEGER NOT NULL DEFAULT 0,
    "team_b_wins" INTEGER NOT NULL DEFAULT 0,
    "draws" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."team_league_cancellation_refund_queue" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "championship_id" UUID NOT NULL,
    "payment_id" UUID NOT NULL,
    "user_id" UUID,
    "paymob_transaction_id" TEXT,
    "amount" NUMERIC NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "retry_count" INTEGER NOT NULL DEFAULT 0,
    "error_message" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    "currency" TEXT DEFAULT 'EGP'::text,
    "failure_reason" TEXT,
    "processed_at" TIMESTAMP WITH TIME ZONE,
    "processing_started_at" TIMESTAMP WITH TIME ZONE,
    "locked_until" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."team_league_match_submissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "submitted_by" UUID NOT NULL,
    "result" TEXT NOT NULL,
    "submitted_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "submission_version" INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS public."team_league_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "championship_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "user_id" UUID,
    "amount" NUMERIC NOT NULL DEFAULT 30,
    "payment_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "order_reference" TEXT NOT NULL,
    "paymob_transaction_id" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "paid_at" TIMESTAMP WITH TIME ZONE,
    "paid_teams_count" INTEGER DEFAULT 1,
    "gross_amount" NUMERIC,
    "paymob_order_id" TEXT
);

CREATE TABLE IF NOT EXISTS public."team_league_result_audits" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "championship_id" UUID NOT NULL,
    "team_id" UUID,
    "actor_id" UUID NOT NULL,
    "action" TEXT NOT NULL,
    "payload" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."team_members" (
    "team_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "joined_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."teams" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "captain_id" UUID NOT NULL,
    "logo_url" TEXT,
    "points" INTEGER DEFAULT 0,
    "wins" INTEGER DEFAULT 0,
    "draws" INTEGER DEFAULT 0,
    "losses" INTEGER DEFAULT 0,
    "matches_played" INTEGER DEFAULT 0,
    "current_winning_streak" INTEGER DEFAULT 0,
    "championships_won" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "last_reset_year" INTEGER DEFAULT 2026,
    "primary_color" TEXT DEFAULT '#FFFFFF'::text,
    "secondary_color" TEXT DEFAULT '#000000'::text,
    "captain_phone" TEXT,
    "captain_image_url" TEXT DEFAULT ''::text,
    "beaten_opponents" text[] DEFAULT '{}'::text[],
    "played_opponents" text[] DEFAULT '{}'::text[],
    "unlocked_badges" text[] DEFAULT '{explorer}'::text[],
    "governorate" TEXT DEFAULT 'Cairo'::text,
    "sport_type" TEXT DEFAULT 'Football'::text,
    "price_per_person" DOUBLE PRECISION DEFAULT 50.0,
    "date" TEXT DEFAULT 'Upcoming'::text,
    "stadium" TEXT DEFAULT 'TBD'::text,
    "captain_name" TEXT DEFAULT 'Captain'::text,
    "is_official" BOOLEAN DEFAULT false,
    "attendance_score" NUMERIC DEFAULT 100.0,
    "verified_badge" BOOLEAN DEFAULT true,
    "active_invite_code" TEXT,
    "invite_code_expires_at" TIMESTAMP WITH TIME ZONE,
    "has_1v1_champion" BOOLEAN DEFAULT false,
    "bio" TEXT
);

CREATE TABLE IF NOT EXISTS public."tournament_matches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "championship_id" UUID NOT NULL,
    "round_index" INTEGER NOT NULL,
    "match_index" INTEGER NOT NULL,
    "home_team_id" UUID,
    "home_team_name" TEXT,
    "away_team_id" UUID,
    "away_team_name" TEXT,
    "home_score" INTEGER,
    "away_score" INTEGER,
    "winner_id" UUID,
    "next_match_id" UUID,
    "scheduled_time" TIMESTAMP WITH TIME ZONE,
    "goal_details" JSONB DEFAULT '[]'::jsonb,
    "clean_sheets" JSONB DEFAULT '[]'::jsonb,
    "mvp_player" TEXT,
    "status" TEXT DEFAULT 'pending'::text,
    "is_completed" BOOLEAN DEFAULT false,
    "winner_name" TEXT,
    "group_name" TEXT,
    "week_number" INTEGER,
    "stage" TEXT DEFAULT 'knockout'::text,
    "home_penalties" INTEGER,
    "away_penalties" INTEGER,
    "submitted_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "booking_id" UUID,
    "stadium_name" TEXT,
    "is_forfeit" BOOLEAN DEFAULT false,
    "forfeit_team_id" UUID,
    "result_status" TEXT DEFAULT 'pending'::text,
    "result_confirmed_at" TIMESTAMP WITH TIME ZONE,
    "result_locked_at" TIMESTAMP WITH TIME ZONE,
    "dispute_created_at" TIMESTAMP WITH TIME ZONE,
    "dispute_resolved_at" TIMESTAMP WITH TIME ZONE,
    "dispute_resolved_by" UUID,
    "confirmed_outcome" TEXT,
    "match_day" DATE
);

CREATE TABLE IF NOT EXISTS public."tournament_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_reference" TEXT NOT NULL,
    "championship_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "captain_user_id" UUID,
    "amount" NUMERIC NOT NULL,
    "payment_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "player_ids" uuid[] DEFAULT ARRAY[]::uuid[],
    "guest_names" text[] DEFAULT ARRAY[]::text[],
    "paymob_transaction_id" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "registration_id" UUID,
    "idempotency_key" TEXT,
    "base_amount" NUMERIC,
    "platform_fee_amount" NUMERIC DEFAULT 0.00,
    "gateway_fee_amount" NUMERIC DEFAULT 0.00,
    "gross_amount" NUMERIC,
    "currency" TEXT DEFAULT 'EGP'::text,
    "fee_policy_version" TEXT,
    "paymob_order_id" TEXT
);

CREATE TABLE IF NOT EXISTS public."transactions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "type" TEXT NOT NULL,
    "amount" NUMERIC NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "booking_id" UUID,
    "championship_id" UUID,
    "payment_method" TEXT,
    "metadata" JSONB DEFAULT '{}'::jsonb,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "description" TEXT,
    "reference_number" TEXT,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "paymob_transaction_id" TEXT,
    "gross_amount" NUMERIC
);

CREATE TABLE IF NOT EXISTS public."user_blocks" (
    "blocker_id" UUID NOT NULL,
    "blocked_user_id" UUID NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."user_device_tokens" (
    "token" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "platform" TEXT NOT NULL DEFAULT 'android'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."user_public_profiles" (
    "id" UUID NOT NULL,
    "name" TEXT,
    "profile_image_url" TEXT,
    "position" TEXT,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."users" (
    "id" UUID NOT NULL,
    "email" TEXT,
    "role" TEXT DEFAULT 'player'::text,
    "name" TEXT,
    "phone" TEXT,
    "profile_image_url" TEXT,
    "position" TEXT,
    "governorate" TEXT,
    "is_registration_complete" BOOLEAN DEFAULT false,
    "is_email_verified" BOOLEAN DEFAULT false,
    "has_stadium" BOOLEAN DEFAULT false,
    "is_identity_verified" BOOLEAN DEFAULT false,
    "favorite_stadiums" uuid[] DEFAULT '{}'::uuid[],
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "is_blocked" BOOLEAN NOT NULL DEFAULT false,
    "verification_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "last_warning" TEXT,
    "date_of_birth" TEXT,
    "p2p_instapay" TEXT,
    "p2p_vodafone" TEXT,
    "p2p_bank" TEXT,
    "additional_data" JSONB DEFAULT '{}'::jsonb,
    "cash_booking_banned" BOOLEAN DEFAULT false,
    "completed_online_bookings_count" INTEGER DEFAULT 0,
    "no_show_count" INTEGER DEFAULT 0,
    "subscription_plan" TEXT DEFAULT 'free_trial'::text,
    "trial_ends_at" TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + '365 days'::interval),
    "subscription_expires_at" TIMESTAMP WITH TIME ZONE,
    "total_platform_fees" NUMERIC DEFAULT 0,
    "fcm_token" TEXT,
    "last_seen" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "terms_accepted_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    "is_onboarding_confirmed" BOOLEAN NOT NULL DEFAULT false,
    "accumulated_cash_debt" NUMERIC NOT NULL DEFAULT 0.00,
    "debt_limit" NUMERIC NOT NULL DEFAULT 500.00,
    "is_debt_blocked" BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public."vsp_1v1_cancellation_refund_queue" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tournament_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "user_id" UUID,
    "paymob_transaction_id" TEXT,
    "amount" NUMERIC NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'EGP'::text,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "retry_count" INTEGER NOT NULL DEFAULT 0,
    "failure_reason" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    "processed_at" TIMESTAMP WITH TIME ZONE,
    "processing_started_at" TIMESTAMP WITH TIME ZONE,
    "locked_until" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public."vsp_1v1_registrations" (
    "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
    "user_id" UUID,
    "status" TEXT DEFAULT 'pending'::text,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."vsp_1v1_tournament_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tournament_id" UUID NOT NULL,
    "user_id" UUID,
    "amount" NUMERIC NOT NULL,
    "order_reference" TEXT NOT NULL,
    "payment_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "paymob_transaction_id" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "refund_retry_count" INTEGER DEFAULT 0,
    "refund_last_attempt_at" TIMESTAMP WITH TIME ZONE,
    "refund_next_retry_at" TIMESTAMP WITH TIME ZONE,
    "expires_at" TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + '00:30:00'::interval),
    "gross_amount" NUMERIC,
    "paymob_order_id" TEXT
);

CREATE TABLE IF NOT EXISTS public."vsp_1v1_tournament_players" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tournament_id" UUID NOT NULL,
    "user_id" UUID,
    "player_name" TEXT NOT NULL,
    "avatar_url" TEXT,
    "tackles" INTEGER NOT NULL DEFAULT 0,
    "goals" INTEGER NOT NULL DEFAULT 0,
    "skills" INTEGER NOT NULL DEFAULT 0,
    "total_points" INTEGER,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "registered_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    "payment_status" TEXT NOT NULL DEFAULT 'unpaid'::text,
    "payment_order_id" UUID,
    "paid_amount" NUMERIC DEFAULT 0,
    "rounds_played" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public."vsp_1v1_tournaments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "target_player_count" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'draft'::text,
    "created_by" UUID,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "published_at" TIMESTAMP WITH TIME ZONE,
    "scheduled_at" TIMESTAMP WITH TIME ZONE,
    "champion_user_id" UUID,
    "entry_fee" NUMERIC NOT NULL DEFAULT 0,
    "prize_pool" NUMERIC NOT NULL DEFAULT 0,
    "prize_delivered" BOOLEAN NOT NULL DEFAULT false,
    "prize_delivered_at" TIMESTAMP WITH TIME ZONE,
    "prize_delivered_by" UUID,
    "prize_delivery_notes" TEXT,
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    "governorate" TEXT NOT NULL DEFAULT 'Cairo'::text,
    "prize_delivery_details" TEXT,
    "prize_delivery_scheduled_at" TIMESTAMP WITH TIME ZONE,
    "prize_amount" NUMERIC NOT NULL DEFAULT 0,
    "champion_player_id" UUID
);

CREATE TABLE IF NOT EXISTS public."vsp_1vs1_players" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "avatar_url" TEXT DEFAULT ''::text,
    "total_points" INTEGER DEFAULT 0,
    "skill_points" INTEGER DEFAULT 0,
    "goals" INTEGER DEFAULT 0,
    "tackles" INTEGER DEFAULT 0,
    "titles" INTEGER DEFAULT 0,
    "trend" TEXT DEFAULT 'stable'::text,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "round_reached" TEXT
);

CREATE TABLE IF NOT EXISTS public."webhook_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "provider" TEXT NOT NULL DEFAULT 'paymob'::text,
    "event_type" TEXT NOT NULL,
    "txn_id" TEXT,
    "order_id" TEXT,
    "booking_id" UUID,
    "payload" JSONB NOT NULL,
    "signature_verified" BOOLEAN DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'received'::text,
    "error_message" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- --------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY STATUS
-- --------------------------------------------------------------------------
ALTER TABLE public."account_deletion_requests" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ai_copilot_audit_events" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."app_config" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."app_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."banners" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."booking_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."booking_public_feed" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."bookings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."cancellation_refund_queue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."challenge_results" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_registrations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_roster_guests" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_roster_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_rosters" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championships" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."chat_messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."copilot_conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."copilot_messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."court_operating_hours" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."financial_audit_logs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."internal_function_secrets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."league_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."match_score_edits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."matchup_results" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."matchup_teams" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."owner_documents" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."owner_subscription_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."owner_trial_ledger" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."payout_settlements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."platform_business_rules" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."platform_fee_config" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."player_trophies" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."promotions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."rate_limit_logs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."reports" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."reviews" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."stadium_custom_rates" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."stadiums" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."subscription_plans" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."support_ticket_messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."support_tickets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."system_audit_logs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_challenge_codes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_head_to_head" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_league_cancellation_refund_queue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_league_match_submissions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_league_payments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_league_result_audits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."teams" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tournament_matches" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tournament_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."transactions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."user_blocks" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."user_device_tokens" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."user_public_profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1v1_cancellation_refund_queue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1v1_registrations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1v1_tournament_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1v1_tournament_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1v1_tournaments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1vs1_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."webhook_logs" ENABLE ROW LEVEL SECURITY;


-- --------------------------------------------------------------------------
-- 5. CONSTRAINTS (PK, FK, UNIQUE, CHECK)
-- --------------------------------------------------------------------------
ALTER TABLE account_deletion_requests DROP CONSTRAINT IF EXISTS "account_deletion_requests_pkey";
ALTER TABLE account_deletion_requests ADD CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY (id);

ALTER TABLE account_deletion_requests DROP CONSTRAINT IF EXISTS "account_deletion_requests_details_check";
ALTER TABLE account_deletion_requests ADD CONSTRAINT "account_deletion_requests_details_check" CHECK (details IS NULL OR length(details) <= 2000);

ALTER TABLE account_deletion_requests DROP CONSTRAINT IF EXISTS "account_deletion_requests_email_check";
ALTER TABLE account_deletion_requests ADD CONSTRAINT "account_deletion_requests_email_check" CHECK (length(TRIM(BOTH FROM email)) >= 3 AND length(TRIM(BOTH FROM email)) <= 320);

ALTER TABLE account_deletion_requests DROP CONSTRAINT IF EXISTS "account_deletion_requests_phone_check";
ALTER TABLE account_deletion_requests ADD CONSTRAINT "account_deletion_requests_phone_check" CHECK (length(TRIM(BOTH FROM phone)) >= 8 AND length(TRIM(BOTH FROM phone)) <= 20);

ALTER TABLE account_deletion_requests DROP CONSTRAINT IF EXISTS "account_deletion_requests_status_check";
ALTER TABLE account_deletion_requests ADD CONSTRAINT "account_deletion_requests_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'verified'::text, 'completed'::text, 'rejected'::text]));

ALTER TABLE ai_copilot_audit_events DROP CONSTRAINT IF EXISTS "ai_copilot_audit_events_pkey";
ALTER TABLE ai_copilot_audit_events ADD CONSTRAINT "ai_copilot_audit_events_pkey" PRIMARY KEY (id);

ALTER TABLE ai_copilot_audit_events DROP CONSTRAINT IF EXISTS "ai_copilot_audit_events_conversation_id_fkey";
ALTER TABLE ai_copilot_audit_events ADD CONSTRAINT "ai_copilot_audit_events_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES copilot_conversations(id) ON DELETE SET NULL;

ALTER TABLE ai_copilot_audit_events DROP CONSTRAINT IF EXISTS "ai_copilot_audit_events_user_id_fkey";
ALTER TABLE ai_copilot_audit_events ADD CONSTRAINT "ai_copilot_audit_events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE ai_copilot_audit_events DROP CONSTRAINT IF EXISTS "ai_copilot_audit_events_event_type_check";
ALTER TABLE ai_copilot_audit_events ADD CONSTRAINT "ai_copilot_audit_events_event_type_check" CHECK (event_type = ANY (ARRAY['request_started'::text, 'tool_completed'::text, 'security_rejected'::text, 'action_emitted'::text, 'response_completed'::text, 'request_failed'::text, 'processing_stage'::text, 'gemini_error'::text, 'function_error'::text]));

ALTER TABLE ai_copilot_audit_events DROP CONSTRAINT IF EXISTS "ai_copilot_audit_events_latency_ms_check";
ALTER TABLE ai_copilot_audit_events ADD CONSTRAINT "ai_copilot_audit_events_latency_ms_check" CHECK (latency_ms IS NULL OR latency_ms >= 0);

ALTER TABLE app_config DROP CONSTRAINT IF EXISTS "app_config_pkey";
ALTER TABLE app_config ADD CONSTRAINT "app_config_pkey" PRIMARY KEY (id);

ALTER TABLE app_settings DROP CONSTRAINT IF EXISTS "app_settings_pkey";
ALTER TABLE app_settings ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY (id);

ALTER TABLE banners DROP CONSTRAINT IF EXISTS "banners_pkey";
ALTER TABLE banners ADD CONSTRAINT "banners_pkey" PRIMARY KEY (id);

ALTER TABLE banners DROP CONSTRAINT IF EXISTS "banners_created_by_fkey";
ALTER TABLE banners ADD CONSTRAINT "banners_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE booking_players DROP CONSTRAINT IF EXISTS "booking_players_pkey";
ALTER TABLE booking_players ADD CONSTRAINT "booking_players_pkey" PRIMARY KEY (booking_id, user_id);

ALTER TABLE booking_players DROP CONSTRAINT IF EXISTS "booking_players_booking_id_fkey";
ALTER TABLE booking_players ADD CONSTRAINT "booking_players_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE booking_players DROP CONSTRAINT IF EXISTS "booking_players_user_id_fkey";
ALTER TABLE booking_players ADD CONSTRAINT "booking_players_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE booking_public_feed DROP CONSTRAINT IF EXISTS "booking_public_feed_pkey";
ALTER TABLE booking_public_feed ADD CONSTRAINT "booking_public_feed_pkey" PRIMARY KEY (id);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "exclude_overlapping_stadium_bookings";
ALTER TABLE bookings ADD CONSTRAINT "exclude_overlapping_stadium_bookings" EXCLUDE USING gist (stadium_id WITH =, tstzrange(start_time, end_time) WITH &&) WHERE (status <> 'cancelled'::text);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_pkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_pkey" PRIMARY KEY (id);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_created_by_user_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_opponent_team_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_opponent_team_id_fkey" FOREIGN KEY (opponent_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_owner_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_player_team_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_player_team_id_fkey" FOREIGN KEY (player_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_result_submitted_by_team_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_result_submitted_by_team_id_fkey" FOREIGN KEY (result_submitted_by_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_stadium_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_stadium_id_fkey" FOREIGN KEY (stadium_id) REFERENCES stadiums(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_booking_type_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_booking_type_check" CHECK (booking_type = ANY (ARRAY['personal'::text, 'open_join'::text, 'challenge'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_challenge_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_challenge_status_check" CHECK (challenge_status IS NULL OR (challenge_status = ANY (ARRAY['ready'::text, 'confirmed'::text, 'completed'::text, 'cancelled'::text, 'expired'::text])));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_final_outcome_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_final_outcome_check" CHECK (final_outcome = ANY (ARRAY['homeWin'::text, 'draw'::text, 'awayWin'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_match_result_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_match_result_status_check" CHECK (match_result_status = ANY (ARRAY['noResult'::text, 'waitingOpponent'::text, 'confirmed'::text, 'disputed'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_matchup_mode_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_matchup_mode_check" CHECK ((matchup_mode = ANY (ARRAY['duo'::text, 'winner_stays'::text])) OR matchup_mode IS NULL);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_payment_method_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_payment_method_check" CHECK (payment_method IS NULL OR (lower(payment_method) = ANY (ARRAY['cash'::text, 'card'::text, 'wallet'::text, 'online'::text, 'paymob'::text, 'instapay'::text, 'vodafone_cash'::text, 'mastercard'::text, 'visa'::text, 'meeza'::text])));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_payment_reconcile_state_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_payment_reconcile_state_check" CHECK (payment_reconcile_state = ANY (ARRAY['unpaid'::text, 'partially_paid'::text, 'fully_paid'::text, 'refunded'::text, 'refund_pending'::text, 'refund_failed'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_payment_source_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_payment_source_check" CHECK (payment_source = ANY (ARRAY['cash'::text, 'paymob'::text, 'instapay'::text, 'vodafone_cash'::text, 'bank_transfer'::text, 'pending'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_payment_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_payment_status_check" CHECK (payment_status = ANY (ARRAY['pending'::text, 'unpaid'::text, 'paid'::text, 'fully_paid'::text, 'partially_paid'::text, 'refunded'::text, 'failed'::text, 'refund_pending'::text, 'refund_failed'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_pending_outcome_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_pending_outcome_check" CHECK (pending_outcome = ANY (ARRAY['homeWin'::text, 'draw'::text, 'awayWin'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_refund_payment_method_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_refund_payment_method_check" CHECK ((refund_payment_method = ANY (ARRAY['card'::text, 'wallet'::text, 'cash'::text, 'bank_transfer'::text])) OR refund_payment_method IS NULL);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'completed'::text, 'cancelled'::text, 'expired'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_bookings_gateway_fee_non_negative";
ALTER TABLE bookings ADD CONSTRAINT "check_bookings_gateway_fee_non_negative" CHECK (gateway_fee >= 0::numeric);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_bookings_vsp_commission_non_negative";
ALTER TABLE bookings ADD CONSTRAINT "check_bookings_vsp_commission_non_negative" CHECK (vsp_commission >= 0::numeric);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_deposit_valid";
ALTER TABLE bookings ADD CONSTRAINT "check_deposit_valid" CHECK (deposit_paid >= 0::numeric AND deposit_paid <= total_price);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_positive_price";
ALTER TABLE bookings ADD CONSTRAINT "check_positive_price" CHECK (total_price >= 0::numeric AND deposit_paid >= 0::numeric);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_refund_amount_valid";
ALTER TABLE bookings ADD CONSTRAINT "check_refund_amount_valid" CHECK (refund_amount IS NULL OR refund_amount >= 0::numeric AND refund_amount <= total_price);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_total_price_positive";
ALTER TABLE bookings ADD CONSTRAINT "check_total_price_positive" CHECK (total_price > 0::numeric);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "valid_booking_duration";
ALTER TABLE bookings ADD CONSTRAINT "valid_booking_duration" CHECK (end_time > start_time);

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "uq_refund_queue_order";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "uq_refund_queue_order" UNIQUE (order_id);

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "cancellation_refund_queue_pkey";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "cancellation_refund_queue_pkey" PRIMARY KEY (id);

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "cancellation_refund_queue_championship_id_fkey";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "cancellation_refund_queue_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE RESTRICT;

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "cancellation_refund_queue_order_id_fkey";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "cancellation_refund_queue_order_id_fkey" FOREIGN KEY (order_id) REFERENCES tournament_orders(id) ON DELETE RESTRICT;

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "cancellation_refund_queue_registration_id_fkey";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "cancellation_refund_queue_registration_id_fkey" FOREIGN KEY (registration_id) REFERENCES championship_registrations(id) ON DELETE RESTRICT;

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "cancellation_refund_queue_amount_check";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "cancellation_refund_queue_amount_check" CHECK (amount > 0::numeric);

ALTER TABLE cancellation_refund_queue DROP CONSTRAINT IF EXISTS "cancellation_refund_queue_status_check";
ALTER TABLE cancellation_refund_queue ADD CONSTRAINT "cancellation_refund_queue_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed_manual_review'::text]));

ALTER TABLE challenge_results DROP CONSTRAINT IF EXISTS "challenge_results_pkey";
ALTER TABLE challenge_results ADD CONSTRAINT "challenge_results_pkey" PRIMARY KEY (id);

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "uq_champ_reg_composite";
ALTER TABLE championship_registrations ADD CONSTRAINT "uq_champ_reg_composite" UNIQUE (id, championship_id, team_id);

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "uq_champ_reg_team";
ALTER TABLE championship_registrations ADD CONSTRAINT "uq_champ_reg_team" UNIQUE (championship_id, team_id);

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "championship_registrations_pkey";
ALTER TABLE championship_registrations ADD CONSTRAINT "championship_registrations_pkey" PRIMARY KEY (id);

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "championship_registrations_captain_id_fkey";
ALTER TABLE championship_registrations ADD CONSTRAINT "championship_registrations_captain_id_fkey" FOREIGN KEY (captain_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "championship_registrations_championship_id_fkey";
ALTER TABLE championship_registrations ADD CONSTRAINT "championship_registrations_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE RESTRICT;

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "championship_registrations_team_id_fkey";
ALTER TABLE championship_registrations ADD CONSTRAINT "championship_registrations_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE RESTRICT;

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "championship_registrations_payment_status_check";
ALTER TABLE championship_registrations ADD CONSTRAINT "championship_registrations_payment_status_check" CHECK (payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'exempt'::text, 'refund_pending'::text, 'refunded'::text, 'refund_failed_manual_review'::text]));

ALTER TABLE championship_registrations DROP CONSTRAINT IF EXISTS "championship_registrations_registration_status_check";
ALTER TABLE championship_registrations ADD CONSTRAINT "championship_registrations_registration_status_check" CHECK (registration_status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'cancelled'::text, 'cancelled_unpaid'::text, 'rejected'::text]));

ALTER TABLE championship_roster_guests DROP CONSTRAINT IF EXISTS "championship_roster_guests_pkey";
ALTER TABLE championship_roster_guests ADD CONSTRAINT "championship_roster_guests_pkey" PRIMARY KEY (id);

ALTER TABLE championship_roster_guests DROP CONSTRAINT IF EXISTS "championship_roster_guests_roster_id_fkey";
ALTER TABLE championship_roster_guests ADD CONSTRAINT "championship_roster_guests_roster_id_fkey" FOREIGN KEY (roster_id) REFERENCES championship_rosters(id) ON DELETE CASCADE;

ALTER TABLE championship_roster_players DROP CONSTRAINT IF EXISTS "championship_roster_players_roster_id_player_id_key";
ALTER TABLE championship_roster_players ADD CONSTRAINT "championship_roster_players_roster_id_player_id_key" UNIQUE (roster_id, player_id);

ALTER TABLE championship_roster_players DROP CONSTRAINT IF EXISTS "championship_roster_players_pkey";
ALTER TABLE championship_roster_players ADD CONSTRAINT "championship_roster_players_pkey" PRIMARY KEY (id);

ALTER TABLE championship_roster_players DROP CONSTRAINT IF EXISTS "championship_roster_players_player_id_fkey";
ALTER TABLE championship_roster_players ADD CONSTRAINT "championship_roster_players_player_id_fkey" FOREIGN KEY (player_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE championship_roster_players DROP CONSTRAINT IF EXISTS "championship_roster_players_roster_id_fkey";
ALTER TABLE championship_roster_players ADD CONSTRAINT "championship_roster_players_roster_id_fkey" FOREIGN KEY (roster_id) REFERENCES championship_rosters(id) ON DELETE CASCADE;

ALTER TABLE championship_rosters DROP CONSTRAINT IF EXISTS "championship_rosters_championship_id_team_id_key";
ALTER TABLE championship_rosters ADD CONSTRAINT "championship_rosters_championship_id_team_id_key" UNIQUE (championship_id, team_id);

ALTER TABLE championship_rosters DROP CONSTRAINT IF EXISTS "championship_rosters_pkey";
ALTER TABLE championship_rosters ADD CONSTRAINT "championship_rosters_pkey" PRIMARY KEY (id);

ALTER TABLE championship_rosters DROP CONSTRAINT IF EXISTS "championship_rosters_championship_id_fkey";
ALTER TABLE championship_rosters ADD CONSTRAINT "championship_rosters_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE championship_rosters DROP CONSTRAINT IF EXISTS "championship_rosters_team_id_fkey";
ALTER TABLE championship_rosters ADD CONSTRAINT "championship_rosters_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE championship_rosters DROP CONSTRAINT IF EXISTS "fk_champ_roster_registration";
ALTER TABLE championship_rosters ADD CONSTRAINT "fk_champ_roster_registration" FOREIGN KEY (registration_id, championship_id, team_id) REFERENCES championship_registrations(id, championship_id, team_id) ON DELETE RESTRICT;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_pkey";
ALTER TABLE championships ADD CONSTRAINT "championships_pkey" PRIMARY KEY (id);

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_champion_team_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_champion_team_id_fkey" FOREIGN KEY (champion_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_champion_user_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_champion_user_id_fkey" FOREIGN KEY (champion_user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_owner_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_prize_delivered_by_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_prize_delivered_by_fkey" FOREIGN KEY (prize_delivered_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_rejected_by_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_rejected_by_fkey" FOREIGN KEY (rejected_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_stadium_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_stadium_id_fkey" FOREIGN KEY (stadium_id) REFERENCES stadiums(id) ON DELETE RESTRICT;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_status_check";
ALTER TABLE championships ADD CONSTRAINT "championships_status_check" CHECK (status = ANY (ARRAY['open'::text, 'ongoing'::text, 'completed'::text, 'cancelled'::text]));

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_template_type_check";
ALTER TABLE championships ADD CONSTRAINT "championships_template_type_check" CHECK ((template_type = ANY (ARRAY['quick_cup_8'::text, 'ramadan_cup_16'::text, 'league_challenge_8'::text, 'custom'::text, 'team_league'::text])) OR template_type IS NULL);

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_type_check";
ALTER TABLE championships ADD CONSTRAINT "championships_type_check" CHECK (type = ANY (ARRAY['cup'::text, 'league'::text, 'tournament'::text, 'groups'::text, 'knockout'::text, '1v1'::text]));

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "chk_championship_open_deadline";
ALTER TABLE championships ADD CONSTRAINT "chk_championship_open_deadline" CHECK (status <> 'open'::text OR registration_closes_at IS NOT NULL AND registration_closes_at <= start_date);

ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS "chat_messages_pkey";
ALTER TABLE chat_messages ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY (id);

ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS "chat_messages_booking_id_fkey";
ALTER TABLE chat_messages ADD CONSTRAINT "chat_messages_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS "chat_messages_conversation_id_fkey";
ALTER TABLE chat_messages ADD CONSTRAINT "chat_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;

ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS "chat_messages_sender_id_fkey";
ALTER TABLE chat_messages ADD CONSTRAINT "chat_messages_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE conversations DROP CONSTRAINT IF EXISTS "conversations_pkey";
ALTER TABLE conversations ADD CONSTRAINT "conversations_pkey" PRIMARY KEY (id);

ALTER TABLE conversations DROP CONSTRAINT IF EXISTS "conversations_booking_id_fkey";
ALTER TABLE conversations ADD CONSTRAINT "conversations_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE copilot_conversations DROP CONSTRAINT IF EXISTS "copilot_conversations_pkey";
ALTER TABLE copilot_conversations ADD CONSTRAINT "copilot_conversations_pkey" PRIMARY KEY (id);

ALTER TABLE copilot_conversations DROP CONSTRAINT IF EXISTS "copilot_conversations_user_id_fkey";
ALTER TABLE copilot_conversations ADD CONSTRAINT "copilot_conversations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE copilot_messages DROP CONSTRAINT IF EXISTS "copilot_messages_pkey";
ALTER TABLE copilot_messages ADD CONSTRAINT "copilot_messages_pkey" PRIMARY KEY (id);

ALTER TABLE copilot_messages DROP CONSTRAINT IF EXISTS "copilot_messages_conversation_id_fkey";
ALTER TABLE copilot_messages ADD CONSTRAINT "copilot_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES copilot_conversations(id) ON DELETE CASCADE;

ALTER TABLE copilot_messages DROP CONSTRAINT IF EXISTS "copilot_messages_user_id_fkey";
ALTER TABLE copilot_messages ADD CONSTRAINT "copilot_messages_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE copilot_messages DROP CONSTRAINT IF EXISTS "copilot_messages_role_check";
ALTER TABLE copilot_messages ADD CONSTRAINT "copilot_messages_role_check" CHECK (role = ANY (ARRAY['user'::text, 'assistant'::text]));

ALTER TABLE court_operating_hours DROP CONSTRAINT IF EXISTS "court_operating_hours_pkey";
ALTER TABLE court_operating_hours ADD CONSTRAINT "court_operating_hours_pkey" PRIMARY KEY (id);

ALTER TABLE court_operating_hours DROP CONSTRAINT IF EXISTS "court_operating_hours_court_id_fkey";
ALTER TABLE court_operating_hours ADD CONSTRAINT "court_operating_hours_court_id_fkey" FOREIGN KEY (court_id) REFERENCES stadiums(id) ON DELETE CASCADE;

ALTER TABLE court_operating_hours DROP CONSTRAINT IF EXISTS "court_operating_hours_day_of_week_check";
ALTER TABLE court_operating_hours ADD CONSTRAINT "court_operating_hours_day_of_week_check" CHECK (day_of_week >= 0 AND day_of_week <= 6);

ALTER TABLE financial_audit_logs DROP CONSTRAINT IF EXISTS "financial_audit_logs_pkey";
ALTER TABLE financial_audit_logs ADD CONSTRAINT "financial_audit_logs_pkey" PRIMARY KEY (id);

ALTER TABLE financial_audit_logs DROP CONSTRAINT IF EXISTS "financial_audit_logs_booking_id_fkey";
ALTER TABLE financial_audit_logs ADD CONSTRAINT "financial_audit_logs_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE internal_function_secrets DROP CONSTRAINT IF EXISTS "internal_function_secrets_pkey";
ALTER TABLE internal_function_secrets ADD CONSTRAINT "internal_function_secrets_pkey" PRIMARY KEY (name);

ALTER TABLE league_settings DROP CONSTRAINT IF EXISTS "league_settings_setting_key_key";
ALTER TABLE league_settings ADD CONSTRAINT "league_settings_setting_key_key" UNIQUE (setting_key);

ALTER TABLE league_settings DROP CONSTRAINT IF EXISTS "league_settings_pkey";
ALTER TABLE league_settings ADD CONSTRAINT "league_settings_pkey" PRIMARY KEY (id);

ALTER TABLE match_score_edits DROP CONSTRAINT IF EXISTS "match_score_edits_pkey";
ALTER TABLE match_score_edits ADD CONSTRAINT "match_score_edits_pkey" PRIMARY KEY (id);

ALTER TABLE match_score_edits DROP CONSTRAINT IF EXISTS "match_score_edits_edited_by_fkey";
ALTER TABLE match_score_edits ADD CONSTRAINT "match_score_edits_edited_by_fkey" FOREIGN KEY (edited_by) REFERENCES auth.users(id);

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_pkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_pkey" PRIMARY KEY (id);

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_booking_id_fkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_recorded_by_fkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_recorded_by_fkey" FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_team_a_id_fkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_team_a_id_fkey" FOREIGN KEY (team_a_id) REFERENCES teams(id);

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_team_b_id_fkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_team_b_id_fkey" FOREIGN KEY (team_b_id) REFERENCES teams(id);

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_check";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_check" CHECK (team_a_id <> team_b_id);

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_outcome_check";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_outcome_check" CHECK (outcome = ANY (ARRAY['team_a_win'::text, 'team_b_win'::text, 'draw'::text]));

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_booking_id_team_id_key";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_booking_id_team_id_key" UNIQUE (booking_id, team_id);

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_pkey";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_pkey" PRIMARY KEY (id);

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_added_by_user_id_fkey";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_added_by_user_id_fkey" FOREIGN KEY (added_by_user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_booking_id_fkey";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_team_id_fkey";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS "notifications_pkey";
ALTER TABLE notifications ADD CONSTRAINT "notifications_pkey" PRIMARY KEY (id);

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS "notifications_user_id_fkey";
ALTER TABLE notifications ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE owner_documents DROP CONSTRAINT IF EXISTS "owner_documents_pkey";
ALTER TABLE owner_documents ADD CONSTRAINT "owner_documents_pkey" PRIMARY KEY (id);

ALTER TABLE owner_documents DROP CONSTRAINT IF EXISTS "owner_documents_owner_id_fkey";
ALTER TABLE owner_documents ADD CONSTRAINT "owner_documents_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE owner_documents DROP CONSTRAINT IF EXISTS "owner_documents_status_check";
ALTER TABLE owner_documents ADD CONSTRAINT "owner_documents_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_pkey";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_pkey" PRIMARY KEY (id);

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_owner_id_fkey";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_plan_code_fkey";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_plan_code_fkey" FOREIGN KEY (plan_code) REFERENCES subscription_plans(code);

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_amount_check";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_amount_check" CHECK (amount > 0::numeric);

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_billing_period_check";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_billing_period_check" CHECK (billing_period = ANY (ARRAY['monthly'::text, 'annual'::text]));

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_payment_source_check";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_payment_source_check" CHECK (payment_source = ANY (ARRAY['app'::text, 'web'::text]));

ALTER TABLE owner_subscription_orders DROP CONSTRAINT IF EXISTS "owner_subscription_orders_status_check";
ALTER TABLE owner_subscription_orders ADD CONSTRAINT "owner_subscription_orders_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'cancelled'::text]));

ALTER TABLE owner_trial_ledger DROP CONSTRAINT IF EXISTS "owner_trial_ledger_pkey";
ALTER TABLE owner_trial_ledger ADD CONSTRAINT "owner_trial_ledger_pkey" PRIMARY KEY (id);

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_pkey";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_pkey" PRIMARY KEY (id);

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_owner_id_fkey";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_amount_check";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_amount_check" CHECK (amount > 0::numeric);

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_method_check";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_method_check" CHECK (method = ANY (ARRAY['instapay'::text, 'wallet'::text, 'vodafone_cash'::text, 'bank'::text, 'bank_transfer'::text, 'unknown'::text]));

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_status_check";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'completed'::text]));

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_pkey";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_pkey" PRIMARY KEY (id);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_booking_max_duration_hours_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_booking_max_duration_hours_check" CHECK (booking_max_duration_hours > 0::numeric);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_booking_min_duration_minutes_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_booking_min_duration_minutes_check" CHECK (booking_min_duration_minutes > 0);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_booking_past_grace_minutes_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_booking_past_grace_minutes_check" CHECK (booking_past_grace_minutes >= 0);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_cash_no_show_limit_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_cash_no_show_limit_check" CHECK (cash_no_show_limit >= 0);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_default_cash_debt_limit_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_default_cash_debt_limit_check" CHECK (default_cash_debt_limit >= 0::numeric);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_id_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_id_check" CHECK (id = 1);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_late_cancellation_cutoff_hours_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_late_cancellation_cutoff_hours_check" CHECK (late_cancellation_cutoff_hours >= 0::numeric);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_manual_booking_max_duration_hours_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_manual_booking_max_duration_hours_check" CHECK (manual_booking_max_duration_hours > 0::numeric);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_payment_lock_minutes_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_payment_lock_minutes_check" CHECK (payment_lock_minutes > 0);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_player_cancellation_cutoff_hours_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_player_cancellation_cutoff_hours_check" CHECK (player_cancellation_cutoff_hours >= 0::numeric);

ALTER TABLE platform_business_rules DROP CONSTRAINT IF EXISTS "platform_business_rules_player_cancellation_grace_minutes_check";
ALTER TABLE platform_business_rules ADD CONSTRAINT "platform_business_rules_player_cancellation_grace_minutes_check" CHECK (player_cancellation_grace_minutes >= 0);

ALTER TABLE platform_fee_config DROP CONSTRAINT IF EXISTS "platform_fee_config_pkey";
ALTER TABLE platform_fee_config ADD CONSTRAINT "platform_fee_config_pkey" PRIMARY KEY (id);

ALTER TABLE platform_fee_config DROP CONSTRAINT IF EXISTS "platform_fee_config_booking_paymob_fixed_fee_check";
ALTER TABLE platform_fee_config ADD CONSTRAINT "platform_fee_config_booking_paymob_fixed_fee_check" CHECK (booking_paymob_fixed_fee >= 0::numeric);

ALTER TABLE platform_fee_config DROP CONSTRAINT IF EXISTS "platform_fee_config_booking_paymob_rate_check";
ALTER TABLE platform_fee_config ADD CONSTRAINT "platform_fee_config_booking_paymob_rate_check" CHECK (booking_paymob_rate >= 0::numeric AND booking_paymob_rate <= 1::numeric);

ALTER TABLE platform_fee_config DROP CONSTRAINT IF EXISTS "platform_fee_config_booking_vsp_rate_check";
ALTER TABLE platform_fee_config ADD CONSTRAINT "platform_fee_config_booking_vsp_rate_check" CHECK (booking_vsp_rate >= 0::numeric AND booking_vsp_rate <= 1::numeric);

ALTER TABLE platform_fee_config DROP CONSTRAINT IF EXISTS "platform_fee_config_id_check";
ALTER TABLE platform_fee_config ADD CONSTRAINT "platform_fee_config_id_check" CHECK (id = 1);

ALTER TABLE platform_fee_config DROP CONSTRAINT IF EXISTS "platform_fee_config_vsp_rate_check";
ALTER TABLE platform_fee_config ADD CONSTRAINT "platform_fee_config_vsp_rate_check" CHECK (booking_vsp_rate >= 0::numeric AND booking_vsp_rate <= 1::numeric) NOT VALID;

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_pkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_pkey" PRIMARY KEY (id);

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_championship_id_fkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_tournament_1v1_id_fkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_tournament_1v1_id_fkey" FOREIGN KEY (tournament_1v1_id) REFERENCES vsp_1v1_tournaments(id) ON DELETE SET NULL;

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_user_id_fkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE promotions DROP CONSTRAINT IF EXISTS "promotions_pkey";
ALTER TABLE promotions ADD CONSTRAINT "promotions_pkey" PRIMARY KEY (id);

ALTER TABLE rate_limit_logs DROP CONSTRAINT IF EXISTS "rate_limit_logs_pkey";
ALTER TABLE rate_limit_logs ADD CONSTRAINT "rate_limit_logs_pkey" PRIMARY KEY (id);

ALTER TABLE reports DROP CONSTRAINT IF EXISTS "reports_pkey";
ALTER TABLE reports ADD CONSTRAINT "reports_pkey" PRIMARY KEY (id);

ALTER TABLE reports DROP CONSTRAINT IF EXISTS "reports_reporter_id_fkey";
ALTER TABLE reports ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE reports DROP CONSTRAINT IF EXISTS "reports_target_type_check_v2";
ALTER TABLE reports ADD CONSTRAINT "reports_target_type_check_v2" CHECK (target_type = ANY (ARRAY['user'::text, 'booking'::text, 'match'::text]));

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS "unique_user_stadium_review";
ALTER TABLE reviews ADD CONSTRAINT "unique_user_stadium_review" UNIQUE (user_id, stadium_id);

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS "reviews_pkey";
ALTER TABLE reviews ADD CONSTRAINT "reviews_pkey" PRIMARY KEY (id);

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS "reviews_user_id_fkey";
ALTER TABLE reviews ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS "reviews_rating_check";
ALTER TABLE reviews ADD CONSTRAINT "reviews_rating_check" CHECK (rating >= 1 AND rating <= 5);

ALTER TABLE stadium_custom_rates DROP CONSTRAINT IF EXISTS "stadium_custom_rates_pkey";
ALTER TABLE stadium_custom_rates ADD CONSTRAINT "stadium_custom_rates_pkey" PRIMARY KEY (id);

ALTER TABLE stadium_custom_rates DROP CONSTRAINT IF EXISTS "stadium_custom_rates_stadium_id_fkey";
ALTER TABLE stadium_custom_rates ADD CONSTRAINT "stadium_custom_rates_stadium_id_fkey" FOREIGN KEY (stadium_id) REFERENCES stadiums(id) ON DELETE CASCADE;

ALTER TABLE stadium_custom_rates DROP CONSTRAINT IF EXISTS "stadium_custom_rates_day_of_week_check";
ALTER TABLE stadium_custom_rates ADD CONSTRAINT "stadium_custom_rates_day_of_week_check" CHECK (day_of_week >= 0 AND day_of_week <= 6);

ALTER TABLE stadium_custom_rates DROP CONSTRAINT IF EXISTS "valid_rate_duration";
ALTER TABLE stadium_custom_rates ADD CONSTRAINT "valid_rate_duration" CHECK (end_time > start_time);

ALTER TABLE stadiums DROP CONSTRAINT IF EXISTS "stadiums_pkey";
ALTER TABLE stadiums ADD CONSTRAINT "stadiums_pkey" PRIMARY KEY (id);

ALTER TABLE stadiums DROP CONSTRAINT IF EXISTS "stadiums_owner_id_fkey";
ALTER TABLE stadiums ADD CONSTRAINT "stadiums_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE stadiums DROP CONSTRAINT IF EXISTS "check_deposit_amount_non_negative";
ALTER TABLE stadiums ADD CONSTRAINT "check_deposit_amount_non_negative" CHECK (deposit_amount >= 0::numeric);

ALTER TABLE stadiums DROP CONSTRAINT IF EXISTS "check_price_per_hour_positive";
ALTER TABLE stadiums ADD CONSTRAINT "check_price_per_hour_positive" CHECK (price_per_hour > 0::numeric);

ALTER TABLE subscription_plans DROP CONSTRAINT IF EXISTS "subscription_plans_pkey";
ALTER TABLE subscription_plans ADD CONSTRAINT "subscription_plans_pkey" PRIMARY KEY (code);

ALTER TABLE subscription_plans DROP CONSTRAINT IF EXISTS "subscription_plans_max_stadiums_check";
ALTER TABLE subscription_plans ADD CONSTRAINT "subscription_plans_max_stadiums_check" CHECK (max_stadiums > 0);

ALTER TABLE subscription_plans DROP CONSTRAINT IF EXISTS "subscription_plans_monthly_price_check";
ALTER TABLE subscription_plans ADD CONSTRAINT "subscription_plans_monthly_price_check" CHECK (monthly_price >= 0::numeric);

ALTER TABLE subscription_plans DROP CONSTRAINT IF EXISTS "subscription_plans_trial_days_check";
ALTER TABLE subscription_plans ADD CONSTRAINT "subscription_plans_trial_days_check" CHECK (trial_days >= 0 AND trial_days <= 3650);

ALTER TABLE subscription_plans DROP CONSTRAINT IF EXISTS "subscription_plans_yearly_price_check";
ALTER TABLE subscription_plans ADD CONSTRAINT "subscription_plans_yearly_price_check" CHECK (yearly_price >= 0::numeric);

ALTER TABLE support_ticket_messages DROP CONSTRAINT IF EXISTS "support_ticket_messages_pkey";
ALTER TABLE support_ticket_messages ADD CONSTRAINT "support_ticket_messages_pkey" PRIMARY KEY (id);

ALTER TABLE support_ticket_messages DROP CONSTRAINT IF EXISTS "support_ticket_messages_sender_id_fkey";
ALTER TABLE support_ticket_messages ADD CONSTRAINT "support_ticket_messages_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE support_ticket_messages DROP CONSTRAINT IF EXISTS "support_ticket_messages_ticket_id_fkey";
ALTER TABLE support_ticket_messages ADD CONSTRAINT "support_ticket_messages_ticket_id_fkey" FOREIGN KEY (ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE;

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_pkey";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_pkey" PRIMARY KEY (id);

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_assigned_to_fkey";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_assigned_to_fkey" FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_booking_id_fkey";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_conversation_id_fkey";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE SET NULL;

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_requester_id_fkey";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_requester_id_fkey" FOREIGN KEY (requester_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_context_type_check";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_context_type_check" CHECK (context_type IS NULL OR (context_type = ANY (ARRAY['booking'::text, 'match'::text, 'challenge'::text, 'tournament'::text, 'report'::text, 'refund'::text])));

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_priority_check";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_priority_check" CHECK (priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text]));

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_source_check";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_source_check" CHECK (source = ANY (ARRAY['in_app'::text, 'whatsapp_escalation'::text]));

ALTER TABLE support_tickets DROP CONSTRAINT IF EXISTS "support_tickets_status_check";
ALTER TABLE support_tickets ADD CONSTRAINT "support_tickets_status_check" CHECK (status = ANY (ARRAY['open'::text, 'in_progress'::text, 'waiting_user'::text, 'resolved'::text, 'closed'::text]));

ALTER TABLE system_audit_logs DROP CONSTRAINT IF EXISTS "system_audit_logs_pkey";
ALTER TABLE system_audit_logs ADD CONSTRAINT "system_audit_logs_pkey" PRIMARY KEY (id);

ALTER TABLE team_challenge_codes DROP CONSTRAINT IF EXISTS "team_challenge_codes_code_key";
ALTER TABLE team_challenge_codes ADD CONSTRAINT "team_challenge_codes_code_key" UNIQUE (code);

ALTER TABLE team_challenge_codes DROP CONSTRAINT IF EXISTS "team_challenge_codes_pkey";
ALTER TABLE team_challenge_codes ADD CONSTRAINT "team_challenge_codes_pkey" PRIMARY KEY (id);

ALTER TABLE team_challenge_codes DROP CONSTRAINT IF EXISTS "team_challenge_codes_team_id_fkey";
ALTER TABLE team_challenge_codes ADD CONSTRAINT "team_challenge_codes_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_challenge_codes DROP CONSTRAINT IF EXISTS "team_challenge_codes_used_in_booking_id_fkey";
ALTER TABLE team_challenge_codes ADD CONSTRAINT "team_challenge_codes_used_in_booking_id_fkey" FOREIGN KEY (used_in_booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE team_challenge_codes DROP CONSTRAINT IF EXISTS "team_challenge_codes_status_check";
ALTER TABLE team_challenge_codes ADD CONSTRAINT "team_challenge_codes_status_check" CHECK (status = ANY (ARRAY['active'::text, 'used'::text, 'expired'::text]));

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_pkey";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_pkey" PRIMARY KEY (team_a_id, team_b_id);

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_team_a_id_fkey";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_team_a_id_fkey" FOREIGN KEY (team_a_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_team_b_id_fkey";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_team_b_id_fkey" FOREIGN KEY (team_b_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_check";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_check" CHECK (team_a_id < team_b_id);

ALTER TABLE team_league_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "team_league_cancellation_refund_queue_pkey";
ALTER TABLE team_league_cancellation_refund_queue ADD CONSTRAINT "team_league_cancellation_refund_queue_pkey" PRIMARY KEY (id);

ALTER TABLE team_league_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "team_league_cancellation_refund_queue_championship_id_fkey";
ALTER TABLE team_league_cancellation_refund_queue ADD CONSTRAINT "team_league_cancellation_refund_queue_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE team_league_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "team_league_cancellation_refund_queue_payment_id_fkey";
ALTER TABLE team_league_cancellation_refund_queue ADD CONSTRAINT "team_league_cancellation_refund_queue_payment_id_fkey" FOREIGN KEY (payment_id) REFERENCES team_league_payments(id) ON DELETE CASCADE;

ALTER TABLE team_league_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "team_league_cancellation_refund_queue_user_id_fkey";
ALTER TABLE team_league_cancellation_refund_queue ADD CONSTRAINT "team_league_cancellation_refund_queue_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE team_league_match_submissions DROP CONSTRAINT IF EXISTS "uq_team_league_match_submission";
ALTER TABLE team_league_match_submissions ADD CONSTRAINT "uq_team_league_match_submission" UNIQUE (match_id, team_id);

ALTER TABLE team_league_match_submissions DROP CONSTRAINT IF EXISTS "team_league_match_submissions_pkey";
ALTER TABLE team_league_match_submissions ADD CONSTRAINT "team_league_match_submissions_pkey" PRIMARY KEY (id);

ALTER TABLE team_league_match_submissions DROP CONSTRAINT IF EXISTS "team_league_match_submissions_match_id_fkey";
ALTER TABLE team_league_match_submissions ADD CONSTRAINT "team_league_match_submissions_match_id_fkey" FOREIGN KEY (match_id) REFERENCES tournament_matches(id) ON DELETE CASCADE;

ALTER TABLE team_league_match_submissions DROP CONSTRAINT IF EXISTS "team_league_match_submissions_submitted_by_fkey";
ALTER TABLE team_league_match_submissions ADD CONSTRAINT "team_league_match_submissions_submitted_by_fkey" FOREIGN KEY (submitted_by) REFERENCES auth.users(id);

ALTER TABLE team_league_match_submissions DROP CONSTRAINT IF EXISTS "team_league_match_submissions_team_id_fkey";
ALTER TABLE team_league_match_submissions ADD CONSTRAINT "team_league_match_submissions_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_league_match_submissions DROP CONSTRAINT IF EXISTS "team_league_match_submissions_result_check";
ALTER TABLE team_league_match_submissions ADD CONSTRAINT "team_league_match_submissions_result_check" CHECK (result = ANY (ARRAY['win'::text, 'draw'::text, 'loss'::text]));

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_order_reference_key";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_order_reference_key" UNIQUE (order_reference);

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_pkey";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_pkey" PRIMARY KEY (id);

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_championship_id_fkey";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_team_id_fkey";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_user_id_fkey";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_amount_ck";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_amount_ck" CHECK (amount > 0::numeric AND (amount % 30::numeric) = 0::numeric);

ALTER TABLE team_league_payments DROP CONSTRAINT IF EXISTS "team_league_payments_status_ck";
ALTER TABLE team_league_payments ADD CONSTRAINT "team_league_payments_status_ck" CHECK (payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text]));

ALTER TABLE team_league_result_audits DROP CONSTRAINT IF EXISTS "team_league_result_audits_pkey";
ALTER TABLE team_league_result_audits ADD CONSTRAINT "team_league_result_audits_pkey" PRIMARY KEY (id);

ALTER TABLE team_league_result_audits DROP CONSTRAINT IF EXISTS "team_league_result_audits_actor_id_fkey";
ALTER TABLE team_league_result_audits ADD CONSTRAINT "team_league_result_audits_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id);

ALTER TABLE team_league_result_audits DROP CONSTRAINT IF EXISTS "team_league_result_audits_championship_id_fkey";
ALTER TABLE team_league_result_audits ADD CONSTRAINT "team_league_result_audits_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE team_league_result_audits DROP CONSTRAINT IF EXISTS "team_league_result_audits_match_id_fkey";
ALTER TABLE team_league_result_audits ADD CONSTRAINT "team_league_result_audits_match_id_fkey" FOREIGN KEY (match_id) REFERENCES tournament_matches(id) ON DELETE CASCADE;

ALTER TABLE team_league_result_audits DROP CONSTRAINT IF EXISTS "team_league_result_audits_team_id_fkey";
ALTER TABLE team_league_result_audits ADD CONSTRAINT "team_league_result_audits_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE team_members DROP CONSTRAINT IF EXISTS "team_members_pkey";
ALTER TABLE team_members ADD CONSTRAINT "team_members_pkey" PRIMARY KEY (team_id, user_id);

ALTER TABLE team_members DROP CONSTRAINT IF EXISTS "team_members_team_id_fkey";
ALTER TABLE team_members ADD CONSTRAINT "team_members_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_members DROP CONSTRAINT IF EXISTS "team_members_user_id_fkey";
ALTER TABLE team_members ADD CONSTRAINT "team_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE teams DROP CONSTRAINT IF EXISTS "teams_active_invite_code_key";
ALTER TABLE teams ADD CONSTRAINT "teams_active_invite_code_key" UNIQUE (active_invite_code);

ALTER TABLE teams DROP CONSTRAINT IF EXISTS "teams_name_key";
ALTER TABLE teams ADD CONSTRAINT "teams_name_key" UNIQUE (name);

ALTER TABLE teams DROP CONSTRAINT IF EXISTS "teams_pkey";
ALTER TABLE teams ADD CONSTRAINT "teams_pkey" PRIMARY KEY (id);

ALTER TABLE teams DROP CONSTRAINT IF EXISTS "teams_captain_id_fkey";
ALTER TABLE teams ADD CONSTRAINT "teams_captain_id_fkey" FOREIGN KEY (captain_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_pkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_pkey" PRIMARY KEY (id);

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_away_team_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_away_team_id_fkey" FOREIGN KEY (away_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_championship_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_dispute_resolved_by_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_dispute_resolved_by_fkey" FOREIGN KEY (dispute_resolved_by) REFERENCES auth.users(id);

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_home_team_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_home_team_id_fkey" FOREIGN KEY (home_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_next_match_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_next_match_id_fkey" FOREIGN KEY (next_match_id) REFERENCES tournament_matches(id) ON DELETE SET NULL;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_winner_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_winner_id_fkey" FOREIGN KEY (winner_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "chk_tm_result_status";
ALTER TABLE tournament_matches ADD CONSTRAINT "chk_tm_result_status" CHECK (result_status = ANY (ARRAY['scheduled'::text, 'awaiting_submissions'::text, 'awaiting_confirmation'::text, 'disputed'::text, 'confirmed'::text, 'locked'::text]));

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_order_reference_key";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_order_reference_key" UNIQUE (order_reference);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "uq_tourn_orders_idempotency_key";
ALTER TABLE tournament_orders ADD CONSTRAINT "uq_tourn_orders_idempotency_key" UNIQUE (idempotency_key);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_pkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_pkey" PRIMARY KEY (id);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_captain_user_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_captain_user_id_fkey" FOREIGN KEY (captain_user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_championship_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_registration_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_registration_id_fkey" FOREIGN KEY (registration_id) REFERENCES championship_registrations(id) ON DELETE RESTRICT;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_team_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_amount_check";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_amount_check" CHECK (amount >= 0::numeric);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_payment_status_check";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_payment_status_check" CHECK (payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'cancelled'::text, 'failed_over_capacity'::text, 'refund_pending'::text, 'refunded'::text, 'refund_failed_manual_review'::text]));

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_pkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_pkey" PRIMARY KEY (id);

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_booking_id_fkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_championship_id_fkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE SET NULL;

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_user_id_fkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS "user_blocks_pkey";
ALTER TABLE user_blocks ADD CONSTRAINT "user_blocks_pkey" PRIMARY KEY (blocker_id, blocked_user_id);

ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS "user_blocks_blocked_user_id_fkey";
ALTER TABLE user_blocks ADD CONSTRAINT "user_blocks_blocked_user_id_fkey" FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS "user_blocks_blocker_id_fkey";
ALTER TABLE user_blocks ADD CONSTRAINT "user_blocks_blocker_id_fkey" FOREIGN KEY (blocker_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS "user_blocks_check";
ALTER TABLE user_blocks ADD CONSTRAINT "user_blocks_check" CHECK (blocker_id <> blocked_user_id);

ALTER TABLE user_device_tokens DROP CONSTRAINT IF EXISTS "user_device_tokens_pkey";
ALTER TABLE user_device_tokens ADD CONSTRAINT "user_device_tokens_pkey" PRIMARY KEY (token);

ALTER TABLE user_device_tokens DROP CONSTRAINT IF EXISTS "user_device_tokens_user_id_fkey";
ALTER TABLE user_device_tokens ADD CONSTRAINT "user_device_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE user_device_tokens DROP CONSTRAINT IF EXISTS "user_device_tokens_platform_check";
ALTER TABLE user_device_tokens ADD CONSTRAINT "user_device_tokens_platform_check" CHECK (platform = ANY (ARRAY['android'::text, 'ios'::text]));

ALTER TABLE user_public_profiles DROP CONSTRAINT IF EXISTS "user_public_profiles_pkey";
ALTER TABLE user_public_profiles ADD CONSTRAINT "user_public_profiles_pkey" PRIMARY KEY (id);

ALTER TABLE user_public_profiles DROP CONSTRAINT IF EXISTS "user_public_profiles_id_fkey";
ALTER TABLE user_public_profiles ADD CONSTRAINT "user_public_profiles_id_fkey" FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_phone_unique";
ALTER TABLE users ADD CONSTRAINT "users_phone_unique" UNIQUE (phone);

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_pkey";
ALTER TABLE users ADD CONSTRAINT "users_pkey" PRIMARY KEY (id);

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_id_fkey";
ALTER TABLE users ADD CONSTRAINT "users_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE users DROP CONSTRAINT IF EXISTS "check_users_debt_limit_non_negative";
ALTER TABLE users ADD CONSTRAINT "check_users_debt_limit_non_negative" CHECK (debt_limit >= 0::numeric);

ALTER TABLE users DROP CONSTRAINT IF EXISTS "check_users_debt_non_negative";
ALTER TABLE users ADD CONSTRAINT "check_users_debt_non_negative" CHECK (accumulated_cash_debt >= 0::numeric);

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_role_check";
ALTER TABLE users ADD CONSTRAINT "users_role_check" CHECK (role = ANY (ARRAY['player'::text, 'owner'::text, 'admin'::text, 'cofounder'::text, 'co_founder'::text, 'super_admin'::text, 'pending_admin'::text]));

ALTER TABLE vsp_1v1_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "vsp_1v1_cancellation_refund_queue_pkey";
ALTER TABLE vsp_1v1_cancellation_refund_queue ADD CONSTRAINT "vsp_1v1_cancellation_refund_queue_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1v1_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "vsp_1v1_cancellation_refund_queue_order_id_fkey";
ALTER TABLE vsp_1v1_cancellation_refund_queue ADD CONSTRAINT "vsp_1v1_cancellation_refund_queue_order_id_fkey" FOREIGN KEY (order_id) REFERENCES vsp_1v1_tournament_orders(id) ON DELETE CASCADE;

ALTER TABLE vsp_1v1_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "vsp_1v1_cancellation_refund_queue_tournament_id_fkey";
ALTER TABLE vsp_1v1_cancellation_refund_queue ADD CONSTRAINT "vsp_1v1_cancellation_refund_queue_tournament_id_fkey" FOREIGN KEY (tournament_id) REFERENCES vsp_1v1_tournaments(id) ON DELETE CASCADE;

ALTER TABLE vsp_1v1_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "vsp_1v1_cancellation_refund_queue_user_id_fkey";
ALTER TABLE vsp_1v1_cancellation_refund_queue ADD CONSTRAINT "vsp_1v1_cancellation_refund_queue_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_cancellation_refund_queue DROP CONSTRAINT IF EXISTS "vsp_1v1_cancellation_refund_queue_status_check";
ALTER TABLE vsp_1v1_cancellation_refund_queue ADD CONSTRAINT "vsp_1v1_cancellation_refund_queue_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed_manual_review'::text]));

ALTER TABLE vsp_1v1_registrations DROP CONSTRAINT IF EXISTS "vsp_1v1_registrations_pkey";
ALTER TABLE vsp_1v1_registrations ADD CONSTRAINT "vsp_1v1_registrations_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1v1_registrations DROP CONSTRAINT IF EXISTS "vsp_1v1_registrations_user_id_fkey";
ALTER TABLE vsp_1v1_registrations ADD CONSTRAINT "vsp_1v1_registrations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE vsp_1v1_registrations DROP CONSTRAINT IF EXISTS "vsp_1v1_registrations_status_check";
ALTER TABLE vsp_1v1_registrations ADD CONSTRAINT "vsp_1v1_registrations_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));

ALTER TABLE vsp_1v1_tournament_orders DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_orders_order_reference_key";
ALTER TABLE vsp_1v1_tournament_orders ADD CONSTRAINT "vsp_1v1_tournament_orders_order_reference_key" UNIQUE (order_reference);

ALTER TABLE vsp_1v1_tournament_orders DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_orders_pkey";
ALTER TABLE vsp_1v1_tournament_orders ADD CONSTRAINT "vsp_1v1_tournament_orders_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1v1_tournament_orders DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_orders_tournament_id_fkey";
ALTER TABLE vsp_1v1_tournament_orders ADD CONSTRAINT "vsp_1v1_tournament_orders_tournament_id_fkey" FOREIGN KEY (tournament_id) REFERENCES vsp_1v1_tournaments(id) ON DELETE CASCADE;

ALTER TABLE vsp_1v1_tournament_orders DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_orders_user_id_fkey";
ALTER TABLE vsp_1v1_tournament_orders ADD CONSTRAINT "vsp_1v1_tournament_orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_tournament_orders DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_orders_amount_check";
ALTER TABLE vsp_1v1_tournament_orders ADD CONSTRAINT "vsp_1v1_tournament_orders_amount_check" CHECK (amount >= 0::numeric);

ALTER TABLE vsp_1v1_tournament_orders DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_orders_payment_status_check";
ALTER TABLE vsp_1v1_tournament_orders ADD CONSTRAINT "vsp_1v1_tournament_orders_payment_status_check" CHECK (payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'refund_requested'::text, 'refunded'::text, 'failed_over_capacity'::text, 'refund_failed_manual_review'::text, 'failed'::text, 'expired'::text]));

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "uq_1v1_tournament_user";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "uq_1v1_tournament_user" UNIQUE (tournament_id, user_id);

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_pkey";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_tournament_id_fkey";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_tournament_id_fkey" FOREIGN KEY (tournament_id) REFERENCES vsp_1v1_tournaments(id) ON DELETE CASCADE;

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_user_id_fkey";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_players_payment_status_check";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_players_payment_status_check" CHECK (payment_status = ANY (ARRAY['unpaid'::text, 'paid'::text, 'refund_requested'::text, 'refunded'::text, 'refund_failed_manual_review'::text]));

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_goals_check";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_goals_check" CHECK (goals >= 0);

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_rounds_played_check";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_rounds_played_check" CHECK (rounds_played >= 0);

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_skills_check";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_skills_check" CHECK (skills >= 0);

ALTER TABLE vsp_1v1_tournament_players DROP CONSTRAINT IF EXISTS "vsp_1v1_tournament_players_tackles_check";
ALTER TABLE vsp_1v1_tournament_players ADD CONSTRAINT "vsp_1v1_tournament_players_tackles_check" CHECK (tackles >= 0);

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_pkey";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_champion_player_id_fkey";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_champion_player_id_fkey" FOREIGN KEY (champion_player_id) REFERENCES vsp_1v1_tournament_players(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_champion_user_id_fkey";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_champion_user_id_fkey" FOREIGN KEY (champion_user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_created_by_fkey";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_created_by_fkey" FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_prize_delivered_by_fkey";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_prize_delivered_by_fkey" FOREIGN KEY (prize_delivered_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_status_check";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'registration_open'::text, 'in_progress'::text, 'completed'::text, 'published'::text, 'archived'::text]));

ALTER TABLE vsp_1v1_tournaments DROP CONSTRAINT IF EXISTS "vsp_1v1_tournaments_target_player_count_check";
ALTER TABLE vsp_1v1_tournaments ADD CONSTRAINT "vsp_1v1_tournaments_target_player_count_check" CHECK (target_player_count > 0);

ALTER TABLE vsp_1vs1_players DROP CONSTRAINT IF EXISTS "vsp_1vs1_players_pkey";
ALTER TABLE vsp_1vs1_players ADD CONSTRAINT "vsp_1vs1_players_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1vs1_players DROP CONSTRAINT IF EXISTS "vsp_1vs1_players_round_reached_check";
ALTER TABLE vsp_1vs1_players ADD CONSTRAINT "vsp_1vs1_players_round_reached_check" CHECK (round_reached IS NULL OR (round_reached = ANY (ARRAY['champion'::text, 'runner_up'::text, 'semi_final'::text, 'quarter_final'::text, 'round_16'::text, 'round_32'::text, 'group'::text, 'eliminated'::text])));

ALTER TABLE webhook_logs DROP CONSTRAINT IF EXISTS "webhook_logs_pkey";
ALTER TABLE webhook_logs ADD CONSTRAINT "webhook_logs_pkey" PRIMARY KEY (id);



-- --------------------------------------------------------------------------
-- 6. INDEXES
-- --------------------------------------------------------------------------
CREATE INDEX ai_copilot_audit_events_event_idx ON public.ai_copilot_audit_events USING btree (event_type, created_at DESC);
CREATE INDEX ai_copilot_audit_events_request_idx ON public.ai_copilot_audit_events USING btree (request_id, created_at);
CREATE INDEX ai_copilot_audit_events_user_idx ON public.ai_copilot_audit_events USING btree (user_id, created_at DESC);
CREATE INDEX idx_ai_copilot_audit_events_conversation_id ON public.ai_copilot_audit_events USING btree (conversation_id);
CREATE INDEX idx_banners_active_placement ON public.banners USING btree (is_active, placement, priority_order);
CREATE INDEX idx_banners_created_by ON public.banners USING btree (created_by);
CREATE INDEX idx_booking_players_user_id ON public.booking_players USING btree (user_id);
CREATE INDEX exclude_overlapping_stadium_bookings ON public.bookings USING gist (stadium_id, tstzrange(start_time, end_time)) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_bookings_conflict_check ON public.bookings USING btree (stadium_id, status, start_time, end_time);
CREATE INDEX idx_bookings_created_by_status ON public.bookings USING btree (created_by_user_id, status);
CREATE INDEX idx_bookings_created_by_status_start ON public.bookings USING btree (created_by_user_id, status, start_time DESC);
CREATE INDEX idx_bookings_created_by_user_id ON public.bookings USING btree (created_by_user_id);
CREATE INDEX idx_bookings_elo_reconcile ON public.bookings USING btree (booking_type, match_result_status, elo_processed) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_bookings_idempotency ON public.bookings USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);
CREATE INDEX idx_bookings_is_private ON public.bookings USING btree (is_private);
CREATE INDEX idx_bookings_joined_users_gin ON public.bookings USING gin (joined_user_ids);
CREATE INDEX idx_bookings_locked_until ON public.bookings USING btree (stadium_id, status, locked_until);
CREATE INDEX idx_bookings_op_date ON public.bookings USING btree (operational_date);
CREATE INDEX idx_bookings_opponent_team_id ON public.bookings USING btree (opponent_team_id) WHERE (opponent_team_id IS NOT NULL);
CREATE INDEX idx_bookings_opponent_team_status ON public.bookings USING btree (opponent_team_id, status);
CREATE INDEX idx_bookings_owner_id ON public.bookings USING btree (owner_id);
CREATE INDEX idx_bookings_owner_operational ON public.bookings USING btree (owner_id, operational_date, start_time DESC);
CREATE INDEX idx_bookings_owner_operational_date ON public.bookings USING btree (owner_id, operational_date);
CREATE INDEX idx_bookings_owner_shift ON public.bookings USING btree (stadium_id, owner_id, operational_date, is_paid) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_bookings_owner_status_created ON public.bookings USING btree (owner_id, status, created_at DESC);
CREATE INDEX idx_bookings_owner_user ON public.bookings USING btree (owner_id, created_by_user_id);
CREATE INDEX idx_bookings_payment_reconcile_created ON public.bookings USING btree (payment_reconcile_state, created_at DESC);
CREATE INDEX idx_bookings_payment_reconcile_state ON public.bookings USING btree (payment_reconcile_state, status);
CREATE INDEX idx_bookings_payment_source ON public.bookings USING btree (payment_source, status);
CREATE INDEX idx_bookings_paymob_txn_id ON public.bookings USING btree (paymob_txn_id);
CREATE INDEX idx_bookings_pending_cleanup ON public.bookings USING btree (created_by_user_id, stadium_id, status, is_paid);
CREATE INDEX idx_bookings_pending_users_gin ON public.bookings USING gin (pending_user_ids) WHERE (pending_user_ids IS NOT NULL);
CREATE INDEX idx_bookings_player_team_id ON public.bookings USING btree (player_team_id) WHERE (player_team_id IS NOT NULL);
CREATE INDEX idx_bookings_player_team_status ON public.bookings USING btree (player_team_id, status);
CREATE INDEX idx_bookings_public_feed ON public.bookings USING btree (is_private, status, start_time, end_time) WHERE (is_private = false);
CREATE INDEX idx_bookings_refund_status ON public.bookings USING btree (created_by_user_id, status, payment_status) WHERE ((status = 'cancelled'::text) AND (payment_status = 'refunded'::text));
CREATE INDEX idx_bookings_refund_txn ON public.bookings USING btree (refund_transaction_id) WHERE (refund_transaction_id IS NOT NULL);
CREATE INDEX idx_bookings_result_submitted_by_team_id ON public.bookings USING btree (result_submitted_by_team_id);
CREATE INDEX idx_bookings_stadium_operational ON public.bookings USING btree (stadium_id, start_time, status);
CREATE INDEX idx_bookings_stadium_operational_date ON public.bookings USING btree (stadium_id, operational_date);
CREATE INDEX idx_bookings_stadium_status ON public.bookings USING btree (stadium_id, status);
CREATE INDEX idx_bookings_stadium_time_active ON public.bookings USING btree (stadium_id, start_time, end_time) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_bookings_start_time ON public.bookings USING btree (start_time);
CREATE INDEX idx_bookings_status_created ON public.bookings USING btree (status, created_at DESC);
CREATE INDEX idx_bookings_status_endtime ON public.bookings USING btree (status, end_time);
CREATE INDEX idx_bookings_status_paid ON public.bookings USING btree (status, is_paid);
CREATE INDEX idx_bookings_status_payment ON public.bookings USING btree (status, payment_status, is_paid);
CREATE INDEX idx_bookings_status_start_time ON public.bookings USING btree (status, start_time);
CREATE INDEX idx_bookings_user_id ON public.bookings USING btree (user_id);
CREATE INDEX idx_bookings_user_live_radar ON public.bookings USING btree (user_id, start_time, end_time, status) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_bookings_user_status ON public.bookings USING btree (user_id, status);
CREATE INDEX idx_bookings_user_status_start ON public.bookings USING btree (user_id, status, start_time DESC);
CREATE INDEX idx_bookings_webhook_processed ON public.bookings USING btree (webhook_processed_at) WHERE (webhook_processed_at IS NOT NULL);
CREATE UNIQUE INDEX prevent_double_booking ON public.bookings USING btree (stadium_id, start_time) WHERE (status <> 'cancelled'::text);
CREATE UNIQUE INDEX uq_booking_idempotency ON public.bookings USING btree (idempotency_key) WHERE ((idempotency_key IS NOT NULL) AND (status <> 'cancelled'::text));
CREATE UNIQUE INDEX ux_bookings_collective_invite_code ON public.bookings USING btree (collective_invite_code) WHERE ((collective_invite_code IS NOT NULL) AND (btrim(collective_invite_code) <> ''::text));
CREATE UNIQUE INDEX ux_bookings_collective_invite_token ON public.bookings USING btree (collective_invite_token) WHERE ((collective_invite_token IS NOT NULL) AND (btrim(collective_invite_token) <> ''::text));
CREATE INDEX idx_cancellation_refund_queue_championship_id ON public.cancellation_refund_queue USING btree (championship_id);
CREATE INDEX idx_cancellation_refund_queue_registration_id ON public.cancellation_refund_queue USING btree (registration_id);
CREATE INDEX idx_refund_queue_status ON public.cancellation_refund_queue USING btree (status, created_at);
CREATE UNIQUE INDEX uq_refund_queue_order ON public.cancellation_refund_queue USING btree (order_id);
CREATE INDEX idx_challenge_results_challenge_id ON public.challenge_results USING btree (challenge_id);
CREATE INDEX idx_champ_reg_lookup ON public.championship_registrations USING btree (championship_id, team_id, registration_status);
CREATE INDEX idx_championship_registrations_captain_id ON public.championship_registrations USING btree (captain_id);
CREATE INDEX idx_championship_registrations_team_id ON public.championship_registrations USING btree (team_id);
CREATE UNIQUE INDEX uq_champ_reg_composite ON public.championship_registrations USING btree (id, championship_id, team_id);
CREATE UNIQUE INDEX uq_champ_reg_team ON public.championship_registrations USING btree (championship_id, team_id);
CREATE INDEX idx_championship_roster_guests_roster_id ON public.championship_roster_guests USING btree (roster_id);
CREATE UNIQUE INDEX championship_roster_players_roster_id_player_id_key ON public.championship_roster_players USING btree (roster_id, player_id);
CREATE INDEX idx_championship_roster_players_player_id ON public.championship_roster_players USING btree (player_id);
CREATE UNIQUE INDEX championship_rosters_championship_id_team_id_key ON public.championship_rosters USING btree (championship_id, team_id);
CREATE INDEX idx_champ_rosters_team_id ON public.championship_rosters USING btree (team_id);
CREATE INDEX idx_championship_rosters_championship ON public.championship_rosters USING btree (championship_id);
CREATE INDEX idx_championship_rosters_registration_championship_team ON public.championship_rosters USING btree (registration_id, championship_id, team_id);
CREATE UNIQUE INDEX uq_champ_roster_reg ON public.championship_rosters USING btree (registration_id);
CREATE INDEX idx_championships_champion_team_id ON public.championships USING btree (champion_team_id);
CREATE INDEX idx_championships_champion_user_id ON public.championships USING btree (champion_user_id);
CREATE INDEX idx_championships_created_at ON public.championships USING btree (created_at DESC);
CREATE INDEX idx_championships_governorate ON public.championships USING btree (governorate);
CREATE INDEX idx_championships_joined_teams_gin ON public.championships USING gin (joined_teams);
CREATE INDEX idx_championships_name_trgm ON public.championships USING gin (name gin_trgm_ops);
CREATE INDEX idx_championships_owner_id ON public.championships USING btree (owner_id);
CREATE INDEX idx_championships_owner_status ON public.championships USING btree (owner_id, status);
CREATE INDEX idx_championships_prize_delivered_by ON public.championships USING btree (prize_delivered_by);
CREATE INDEX idx_championships_rejected_by ON public.championships USING btree (rejected_by);
CREATE INDEX idx_championships_stadium_id ON public.championships USING btree (stadium_id);
CREATE INDEX idx_championships_status_sport ON public.championships USING btree (status, sport_type, governorate);
CREATE INDEX idx_chat_messages_booking_created ON public.chat_messages USING btree (booking_id, created_at DESC);
CREATE INDEX idx_chat_messages_conversation_created ON public.chat_messages USING btree (conversation_id, created_at DESC);
CREATE INDEX idx_chat_messages_sender_id ON public.chat_messages USING btree (sender_id);
CREATE INDEX idx_chat_msgs_booking_id ON public.chat_messages USING btree (booking_id);
CREATE INDEX idx_conversations_booking ON public.conversations USING btree (booking_id);
CREATE INDEX idx_conversations_direct_context ON public.conversations USING btree (type, context_type, context_id);
CREATE INDEX idx_conversations_participants_gin ON public.conversations USING gin (participant_ids);
CREATE INDEX idx_copilot_conversations_context ON public.copilot_conversations USING gin (context_snapshot);
CREATE INDEX idx_copilot_conversations_user ON public.copilot_conversations USING btree (user_id, updated_at DESC);
CREATE UNIQUE INDEX copilot_messages_conversation_sequence_uidx ON public.copilot_messages USING btree (conversation_id, message_sequence);
CREATE INDEX idx_copilot_messages_conv ON public.copilot_messages USING btree (conversation_id, created_at);
CREATE INDEX idx_copilot_messages_user ON public.copilot_messages USING btree (user_id, created_at DESC);
CREATE INDEX idx_court_operating_hours_court_id ON public.court_operating_hours USING btree (court_id);
CREATE INDEX idx_financial_logs_booking ON public.financial_audit_logs USING btree (booking_id);
CREATE INDEX idx_financial_logs_owner ON public.financial_audit_logs USING btree (owner_id, created_at);
CREATE INDEX idx_financial_logs_user ON public.financial_audit_logs USING btree (user_id, created_at);
CREATE UNIQUE INDEX league_settings_setting_key_key ON public.league_settings USING btree (setting_key);
CREATE INDEX idx_match_score_edits_edited_by ON public.match_score_edits USING btree (edited_by);
CREATE INDEX idx_matchup_results_booking_id ON public.matchup_results USING btree (booking_id);
CREATE INDEX idx_matchup_results_recorded_by ON public.matchup_results USING btree (recorded_by);
CREATE INDEX idx_matchup_results_team_a_id ON public.matchup_results USING btree (team_a_id);
CREATE INDEX idx_matchup_results_team_b_id ON public.matchup_results USING btree (team_b_id);
CREATE INDEX idx_matchup_teams_added_by_user_id ON public.matchup_teams USING btree (added_by_user_id);
CREATE INDEX idx_matchup_teams_team_id ON public.matchup_teams USING btree (team_id);
CREATE UNIQUE INDEX matchup_teams_booking_id_team_id_key ON public.matchup_teams USING btree (booking_id, team_id);
CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_id_unread ON public.notifications USING btree (user_id) WHERE (is_read = false);
CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, is_read);
CREATE INDEX idx_notifications_user_unread_perf ON public.notifications USING btree (user_id, is_read, created_at DESC);
CREATE INDEX idx_owner_documents_owner_id ON public.owner_documents USING btree (owner_id);
CREATE INDEX idx_owner_documents_status ON public.owner_documents USING btree (status);
CREATE INDEX idx_owner_sub_orders_claim_contact ON public.owner_subscription_orders USING btree (lower(checkout_email), checkout_phone) WHERE ((status = 'paid'::text) AND (owner_id IS NULL));
CREATE INDEX idx_owner_sub_orders_web_status_created ON public.owner_subscription_orders USING btree (payment_source, status, created_at DESC);
CREATE INDEX idx_owner_subscription_orders_checkout_identity ON public.owner_subscription_orders USING btree (lower(checkout_email), checkout_phone) WHERE ((checkout_email IS NOT NULL) AND (checkout_phone IS NOT NULL));
CREATE INDEX idx_owner_subscription_orders_owner ON public.owner_subscription_orders USING btree (owner_id, created_at DESC);
CREATE INDEX idx_owner_subscription_orders_paymob ON public.owner_subscription_orders USING btree (paymob_order_id);
CREATE INDEX idx_owner_subscription_orders_paymob_intention ON public.owner_subscription_orders USING btree (paymob_intention_id) WHERE (paymob_intention_id IS NOT NULL);
CREATE INDEX idx_owner_subscription_orders_plan_code ON public.owner_subscription_orders USING btree (plan_code);
CREATE UNIQUE INDEX idx_owner_trial_ledger_email ON public.owner_trial_ledger USING btree (lower(TRIM(BOTH FROM email)));
CREATE UNIQUE INDEX idx_owner_trial_ledger_phone ON public.owner_trial_ledger USING btree (phone) WHERE ((phone IS NOT NULL) AND (phone <> ''::text));
CREATE INDEX idx_payout_settlements_owner ON public.payout_settlements USING btree (owner_id, created_at DESC);
CREATE INDEX idx_payout_settlements_status ON public.payout_settlements USING btree (status, created_at DESC);
CREATE INDEX idx_player_trophies_championship_id ON public.player_trophies USING btree (championship_id);
CREATE INDEX idx_player_trophies_tournament_1v1_id ON public.player_trophies USING btree (tournament_1v1_id);
CREATE INDEX idx_player_trophies_user_id ON public.player_trophies USING btree (user_id);
CREATE INDEX idx_rate_limit_user_action ON public.rate_limit_logs USING btree (user_id, action, created_at);
CREATE INDEX idx_reports_booking ON public.reports USING btree (booking_id);
CREATE INDEX idx_reports_context ON public.reports USING btree (context_type, context_id, created_at DESC);
CREATE INDEX idx_reports_conversation ON public.reports USING btree (conversation_id);
CREATE INDEX idx_reports_reporter_id ON public.reports USING btree (reporter_id);
CREATE INDEX idx_reports_status ON public.reports USING btree (status);
CREATE INDEX idx_reports_status_created ON public.reports USING btree (status, created_at DESC);
CREATE INDEX idx_reports_target ON public.reports USING btree (target_type, target_id);
CREATE INDEX idx_reviews_stadium_created_at ON public.reviews USING btree (stadium_id, created_at DESC);
CREATE INDEX idx_reviews_stadium_id ON public.reviews USING btree (stadium_id);
CREATE UNIQUE INDEX idx_reviews_unique_stadium_user ON public.reviews USING btree (stadium_id, user_id);
CREATE INDEX idx_reviews_user_id ON public.reviews USING btree (user_id);
CREATE UNIQUE INDEX unique_user_stadium_review ON public.reviews USING btree (user_id, stadium_id);
CREATE INDEX idx_stadium_rates_stadium_dow ON public.stadium_custom_rates USING btree (stadium_id, day_of_week);
CREATE INDEX idx_stadiums_discovery ON public.stadiums USING btree (governorate, is_verified, is_blocked) WHERE (is_deleted_by_owner = false);
CREATE INDEX idx_stadiums_featured_search ON public.stadiums USING btree (is_featured DESC, is_verified, created_at DESC);
CREATE INDEX idx_stadiums_geo ON public.stadiums USING btree (lat, lng) WHERE ((is_verified = true) AND (is_blocked = false));
CREATE INDEX idx_stadiums_governorate ON public.stadiums USING btree (governorate);
CREATE INDEX idx_stadiums_name_trgm ON public.stadiums USING gin (name gin_trgm_ops);
CREATE INDEX idx_stadiums_owner_active ON public.stadiums USING btree (owner_id) WHERE (is_deleted_by_owner = false);
CREATE INDEX idx_stadiums_owner_deleted ON public.stadiums USING btree (owner_id, is_deleted_by_owner);
CREATE INDEX idx_stadiums_public_filter ON public.stadiums USING btree (is_verified, is_blocked, is_deleted_by_owner, governorate);
CREATE INDEX idx_stadiums_verified_blocked ON public.stadiums USING btree (is_verified, is_blocked);
CREATE INDEX idx_subscription_plans_active_order ON public.subscription_plans USING btree (is_active, display_order);
CREATE INDEX idx_support_ticket_messages_sender_id ON public.support_ticket_messages USING btree (sender_id);
CREATE INDEX idx_support_ticket_messages_ticket ON public.support_ticket_messages USING btree (ticket_id, created_at);
CREATE INDEX idx_support_tickets_assignee ON public.support_tickets USING btree (assigned_to, updated_at DESC);
CREATE INDEX idx_support_tickets_booking_id ON public.support_tickets USING btree (booking_id);
CREATE INDEX idx_support_tickets_conversation_id ON public.support_tickets USING btree (conversation_id);
CREATE INDEX idx_support_tickets_requester ON public.support_tickets USING btree (requester_id, updated_at DESC);
CREATE INDEX idx_support_tickets_status ON public.support_tickets USING btree (status, priority, updated_at DESC);
CREATE INDEX idx_audit_logs_changed_by ON public.system_audit_logs USING btree (changed_by);
CREATE INDEX idx_audit_logs_created_at ON public.system_audit_logs USING btree (created_at DESC);
CREATE INDEX idx_audit_logs_record ON public.system_audit_logs USING btree (table_name, record_id);
CREATE INDEX idx_system_audit_logs_action ON public.system_audit_logs USING btree (action);
CREATE INDEX idx_system_audit_logs_record_id ON public.system_audit_logs USING btree (record_id);
CREATE INDEX idx_challenge_codes_active_code ON public.team_challenge_codes USING btree (code) WHERE (status = 'active'::text);
CREATE INDEX idx_challenge_codes_team ON public.team_challenge_codes USING btree (team_id);
CREATE INDEX idx_team_challenge_codes_used_in_booking_id ON public.team_challenge_codes USING btree (used_in_booking_id);
CREATE UNIQUE INDEX team_challenge_codes_code_key ON public.team_challenge_codes USING btree (code);
CREATE INDEX idx_team_head_to_head_team_b_id ON public.team_head_to_head USING btree (team_b_id);
CREATE INDEX idx_team_league_cancellation_refund_queue_championship_id ON public.team_league_cancellation_refund_queue USING btree (championship_id);
CREATE INDEX idx_team_league_cancellation_refund_queue_payment_id ON public.team_league_cancellation_refund_queue USING btree (payment_id);
CREATE INDEX idx_team_league_cancellation_refund_queue_user_id ON public.team_league_cancellation_refund_queue USING btree (user_id);
CREATE INDEX idx_team_league_match_submissions_submitted_by ON public.team_league_match_submissions USING btree (submitted_by);
CREATE INDEX idx_team_league_match_submissions_team_id ON public.team_league_match_submissions USING btree (team_id);
CREATE INDEX idx_tl_submissions_match_team ON public.team_league_match_submissions USING btree (match_id, team_id);
CREATE UNIQUE INDEX uq_team_league_match_submission ON public.team_league_match_submissions USING btree (match_id, team_id);
CREATE INDEX idx_team_league_payments_lookup ON public.team_league_payments USING btree (championship_id, team_id, payment_status);
CREATE INDEX idx_team_league_payments_team_id ON public.team_league_payments USING btree (team_id);
CREATE INDEX idx_team_league_payments_user_id ON public.team_league_payments USING btree (user_id);
CREATE UNIQUE INDEX team_league_payments_order_reference_key ON public.team_league_payments USING btree (order_reference);
CREATE UNIQUE INDEX ux_team_league_payments_paymob_order_id ON public.team_league_payments USING btree (paymob_order_id) WHERE ((paymob_order_id IS NOT NULL) AND (btrim(paymob_order_id) <> ''::text));
CREATE INDEX idx_team_league_result_audits_actor_id ON public.team_league_result_audits USING btree (actor_id);
CREATE INDEX idx_team_league_result_audits_championship_id ON public.team_league_result_audits USING btree (championship_id);
CREATE INDEX idx_team_league_result_audits_team_id ON public.team_league_result_audits USING btree (team_id);
CREATE INDEX idx_tl_audits_match ON public.team_league_result_audits USING btree (match_id);
CREATE INDEX idx_team_members_user ON public.team_members USING btree (user_id);
CREATE INDEX idx_teams_captain_id ON public.teams USING btree (captain_id);
CREATE INDEX idx_teams_created_at ON public.teams USING btree (created_at DESC);
CREATE INDEX idx_teams_governorate ON public.teams USING btree (governorate);
CREATE INDEX idx_teams_governorate_sport ON public.teams USING btree (governorate, sport_type, points DESC);
CREATE INDEX idx_teams_ranking_points ON public.teams USING btree (points DESC, wins DESC, matches_played);
CREATE UNIQUE INDEX teams_active_invite_code_key ON public.teams USING btree (active_invite_code);
CREATE UNIQUE INDEX teams_name_key ON public.teams USING btree (name);
CREATE INDEX idx_tournament_matches_away_team_id ON public.tournament_matches USING btree (away_team_id) WHERE (away_team_id IS NOT NULL);
CREATE INDEX idx_tournament_matches_bracket ON public.tournament_matches USING btree (championship_id, round_index, match_index);
CREATE INDEX idx_tournament_matches_champ_round ON public.tournament_matches USING btree (championship_id, round_index);
CREATE INDEX idx_tournament_matches_championship_id ON public.tournament_matches USING btree (championship_id);
CREATE INDEX idx_tournament_matches_dispute_resolved_by ON public.tournament_matches USING btree (dispute_resolved_by);
CREATE INDEX idx_tournament_matches_home_team_id ON public.tournament_matches USING btree (home_team_id) WHERE (home_team_id IS NOT NULL);
CREATE INDEX idx_tournament_matches_next_match_id ON public.tournament_matches USING btree (next_match_id);
CREATE INDEX idx_tournament_matches_stage ON public.tournament_matches USING btree (championship_id, stage);
CREATE INDEX idx_tournament_matches_status_scheduled ON public.tournament_matches USING btree (status, scheduled_time);
CREATE INDEX idx_tournament_matches_winner_id ON public.tournament_matches USING btree (winner_id) WHERE (winner_id IS NOT NULL);
CREATE INDEX idx_tournament_orders_captain_user_id ON public.tournament_orders USING btree (captain_user_id);
CREATE INDEX idx_tournament_orders_champ_team ON public.tournament_orders USING btree (championship_id, team_id);
CREATE INDEX idx_tournament_orders_status ON public.tournament_orders USING btree (payment_status);
CREATE INDEX idx_tournament_orders_team_id ON public.tournament_orders USING btree (team_id);
CREATE UNIQUE INDEX tournament_orders_order_reference_key ON public.tournament_orders USING btree (order_reference);
CREATE UNIQUE INDEX uq_tourn_orders_active_pending ON public.tournament_orders USING btree (registration_id) WHERE ((registration_id IS NOT NULL) AND (payment_status = 'pending'::text));
CREATE UNIQUE INDEX uq_tourn_orders_idempotency_key ON public.tournament_orders USING btree (idempotency_key);
CREATE UNIQUE INDEX uq_tourn_orders_paid ON public.tournament_orders USING btree (registration_id) WHERE ((registration_id IS NOT NULL) AND (payment_status = 'paid'::text));
CREATE UNIQUE INDEX ux_tournament_orders_paymob_order_id ON public.tournament_orders USING btree (paymob_order_id) WHERE ((paymob_order_id IS NOT NULL) AND (btrim(paymob_order_id) <> ''::text));
CREATE INDEX idx_transactions_booking_id ON public.transactions USING btree (booking_id) WHERE (booking_id IS NOT NULL);
CREATE INDEX idx_transactions_booking_status ON public.transactions USING btree (booking_id, status);
CREATE INDEX idx_transactions_booking_status_created ON public.transactions USING btree (booking_id, status, created_at DESC) WHERE (booking_id IS NOT NULL);
CREATE INDEX idx_transactions_champ_created ON public.transactions USING btree (championship_id, created_at DESC) WHERE (championship_id IS NOT NULL);
CREATE INDEX idx_transactions_championship_id ON public.transactions USING btree (championship_id) WHERE (championship_id IS NOT NULL);
CREATE INDEX idx_transactions_created_at ON public.transactions USING btree (created_at DESC);
CREATE INDEX idx_transactions_owner_created ON public.transactions USING btree (user_id, type, created_at DESC);
CREATE INDEX idx_transactions_paymob_txn_id ON public.transactions USING btree (paymob_transaction_id);
CREATE INDEX idx_transactions_type_status ON public.transactions USING btree (type, status);
CREATE UNIQUE INDEX idx_transactions_unique_booking_refund ON public.transactions USING btree (booking_id) WHERE ((type = ANY (ARRAY['refund'::text, 'refund_card'::text, 'refund_wallet'::text, 'refund_cash'::text, 'refund_pending'::text])) AND (status = ANY (ARRAY['completed'::text, 'pending'::text])));
CREATE UNIQUE INDEX idx_transactions_unique_cash_settlement ON public.transactions USING btree (booking_id) WHERE ((type = 'cash_settlement'::text) AND (status = 'completed'::text));
CREATE INDEX idx_transactions_user_created ON public.transactions USING btree (user_id, created_at DESC);
CREATE INDEX idx_transactions_user_id ON public.transactions USING btree (user_id);
CREATE INDEX idx_transactions_user_status_created ON public.transactions USING btree (user_id, status, created_at DESC);
CREATE UNIQUE INDEX ux_transactions_paymob_transaction_id ON public.transactions USING btree (paymob_transaction_id) WHERE ((paymob_transaction_id IS NOT NULL) AND (btrim(paymob_transaction_id) <> ''::text));
CREATE INDEX idx_user_blocks_blocked_user_id ON public.user_blocks USING btree (blocked_user_id);
CREATE INDEX idx_user_device_tokens_user_id ON public.user_device_tokens USING btree (user_id);
CREATE INDEX idx_users_created_at ON public.users USING btree (created_at DESC);
CREATE INDEX idx_users_email ON public.users USING btree (email);
CREATE INDEX idx_users_owner_debt_blocked ON public.users USING btree (role, is_debt_blocked) WHERE ((role = 'owner'::text) AND (is_debt_blocked = true));
CREATE INDEX idx_users_phone ON public.users USING btree (phone);
CREATE INDEX idx_users_role ON public.users USING btree (role);
CREATE INDEX idx_users_role_status ON public.users USING btree (role, is_blocked, verification_status);
CREATE UNIQUE INDEX users_phone_unique ON public.users USING btree (phone);
CREATE INDEX idx_1v1_refund_queue_status_locked ON public.vsp_1v1_cancellation_refund_queue USING btree (status, locked_until);
CREATE INDEX idx_vsp_1v1_cancellation_refund_queue_order_id ON public.vsp_1v1_cancellation_refund_queue USING btree (order_id);
CREATE INDEX idx_vsp_1v1_cancellation_refund_queue_tournament_id ON public.vsp_1v1_cancellation_refund_queue USING btree (tournament_id);
CREATE INDEX idx_vsp_1v1_cancellation_refund_queue_user_id ON public.vsp_1v1_cancellation_refund_queue USING btree (user_id);
CREATE UNIQUE INDEX idx_unique_active_registration ON public.vsp_1v1_registrations USING btree (user_id) WHERE (status = ANY (ARRAY['pending'::text, 'approved'::text]));
CREATE INDEX idx_orders_pending_expires ON public.vsp_1v1_tournament_orders USING btree (expires_at) WHERE (payment_status = 'pending'::text);
CREATE INDEX idx_orders_pending_refund ON public.vsp_1v1_tournament_orders USING btree (refund_next_retry_at) WHERE ((payment_status = 'refund_failed_manual_review'::text) AND (refund_retry_count < 3));
CREATE INDEX idx_vsp_1v1_orders_ref ON public.vsp_1v1_tournament_orders USING btree (order_reference);
CREATE INDEX idx_vsp_1v1_orders_status ON public.vsp_1v1_tournament_orders USING btree (payment_status);
CREATE INDEX idx_vsp_1v1_orders_tournament ON public.vsp_1v1_tournament_orders USING btree (tournament_id);
CREATE INDEX idx_vsp_1v1_orders_user ON public.vsp_1v1_tournament_orders USING btree (user_id);
CREATE UNIQUE INDEX ux_1v1_pending_order_player_tournament ON public.vsp_1v1_tournament_orders USING btree (tournament_id, user_id) WHERE (payment_status = 'pending'::text);
CREATE UNIQUE INDEX ux_vsp_1v1_tournament_orders_paymob_order_id ON public.vsp_1v1_tournament_orders USING btree (paymob_order_id) WHERE ((paymob_order_id IS NOT NULL) AND (btrim(paymob_order_id) <> ''::text));
CREATE UNIQUE INDEX vsp_1v1_tournament_orders_order_reference_key ON public.vsp_1v1_tournament_orders USING btree (order_reference);
CREATE INDEX idx_1v1_tournament_players_tournament_id ON public.vsp_1v1_tournament_players USING btree (tournament_id);
CREATE INDEX idx_1v1_tournament_players_user_id ON public.vsp_1v1_tournament_players USING btree (user_id);
CREATE UNIQUE INDEX uq_1v1_tournament_user ON public.vsp_1v1_tournament_players USING btree (tournament_id, user_id);
CREATE UNIQUE INDEX idx_one_active_1v1_tournament_per_governorate ON public.vsp_1v1_tournaments USING btree (governorate) WHERE (status = ANY (ARRAY['registration_open'::text, 'in_progress'::text]));
CREATE INDEX idx_vsp_1v1_tournaments_champion_player_id ON public.vsp_1v1_tournaments USING btree (champion_player_id);
CREATE INDEX idx_vsp_1v1_tournaments_champion_user_id ON public.vsp_1v1_tournaments USING btree (champion_user_id);
CREATE INDEX idx_vsp_1v1_tournaments_created_by ON public.vsp_1v1_tournaments USING btree (created_by);
CREATE INDEX idx_vsp_1v1_tournaments_gov ON public.vsp_1v1_tournaments USING btree (governorate);
CREATE INDEX idx_vsp_1v1_tournaments_prize_delivered_by ON public.vsp_1v1_tournaments USING btree (prize_delivered_by);
CREATE INDEX idx_vsp1v1_ranking_points ON public.vsp_1vs1_players USING btree (total_points DESC, skill_points DESC, goals DESC);


-- --------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY POLICIES
-- --------------------------------------------------------------------------
CREATE POLICY "anon_can_submit_account_deletion_request" ON public."account_deletion_requests" AS PERMISSIVE FOR INSERT TO anon,authenticated WITH CHECK ((((length(TRIM(BOTH FROM email)) >= 3) AND (length(TRIM(BOTH FROM email)) <= 320)) AND ((length(TRIM(BOTH FROM phone)) >= 8) AND (length(TRIM(BOTH FROM phone)) <= 20)) AND ((details IS NULL) OR (length(details) <= 2000)) AND (status = 'pending'::text)));

CREATE POLICY "Admins can view AI Copilot audit" ON public."ai_copilot_audit_events" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "admin_manage_app_config" ON public."app_config" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "app_config_select_public" ON public."app_config" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "app_settings_admin_manage" ON public."app_settings" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "app_settings_public_read" ON public."app_settings" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "app_settings_select" ON public."app_settings" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "Admins have full access to banners" ON public."banners" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid))) WITH CHECK (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "Public and users can view active banners" ON public."banners" AS PERMISSIVE FOR SELECT TO public USING (((is_active = true) AND ((start_date IS NULL) OR (start_date <= timezone('utc'::text, now()))) AND ((end_date IS NULL) OR (end_date >= timezone('utc'::text, now())))));

CREATE POLICY "booking_players_select_policy" ON public."booking_players" AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = booking_players.booking_id) AND ((b.owner_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (b.created_by_user_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

CREATE POLICY "booking_public_feed_select" ON public."booking_public_feed" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins full access" ON public."bookings" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "bookings_delete_secure" ON public."bookings" AS PERMISSIVE FOR DELETE TO authenticated USING ((((status = 'pending'::text) AND ((auth.uid() = created_by_user_id) OR (auth.uid() = owner_id))) OR ((payment_transaction_id ~~ 'MANUAL%'::text) AND (auth.uid() = owner_id)) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "bookings_insert_admin_service" ON public."bookings" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "bookings_select_private_scope" ON public."bookings" AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = user_id) OR (auth.uid() = owner_id) OR (auth.uid() = created_by_user_id) OR (auth.uid() = ANY (COALESCE(joined_user_ids, ARRAY[]::uuid[]))) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "bookings_update_secure" ON public."bookings" AS PERMISSIVE FOR UPDATE TO authenticated USING (((auth.uid() = user_id) OR (auth.uid() = owner_id) OR (auth.uid() = created_by_user_id) OR is_admin_or_cofounder(auth.uid()))) WITH CHECK (((auth.uid() = user_id) OR (auth.uid() = owner_id) OR (auth.uid() = created_by_user_id) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "admins_view_booking_refund_queue" ON public."cancellation_refund_queue" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "service_role_booking_refund_queue_full" ON public."cancellation_refund_queue" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "admins_view_challenge_results" ON public."challenge_results" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "service_role_challenge_results_full" ON public."challenge_results" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "championship_registrations_select" ON public."championship_registrations" AS PERMISSIVE FOR SELECT TO authenticated USING (((captain_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM team_members tm
  WHERE ((tm.team_id = championship_registrations.team_id) AND (tm.user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_registrations.championship_id) AND (c.owner_id = auth.uid())))) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "roster_guests_manage_policy" ON public."championship_roster_guests" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_guests.roster_id) AND ((t.captain_id = ( SELECT auth.uid() AS uid)) OR (c.owner_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false))))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_guests.roster_id) AND ((t.captain_id = ( SELECT auth.uid() AS uid)) OR (c.owner_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false)))))))));

CREATE POLICY "roster_players_manage_policy" ON public."championship_roster_players" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_players.roster_id) AND ((t.captain_id = auth.uid()) OR (c.owner_id = auth.uid()) OR is_admin_or_cofounder(auth.uid())))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_players.roster_id) AND ((t.captain_id = auth.uid()) OR (c.owner_id = auth.uid()) OR is_admin_or_cofounder(auth.uid()))))));

CREATE POLICY "championship_rosters_manage_secure" ON public."championship_rosters" AS PERMISSIVE FOR ALL TO authenticated USING (((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = championship_rosters.team_id) AND (t.captain_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_rosters.championship_id) AND (c.owner_id = auth.uid())))) OR is_admin_or_cofounder(auth.uid()))) WITH CHECK (((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = championship_rosters.team_id) AND (t.captain_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_rosters.championship_id) AND (c.owner_id = auth.uid())))) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "championships_admin_manage_all" ON public."championships" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))))));

CREATE POLICY "championships_insert" ON public."championships" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id) AND (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['owner'::text, 'admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))))) AND ((is_approved IS NOT TRUE) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))))))));

CREATE POLICY "championships_select" ON public."championships" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "championships_update_own" ON public."championships" AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id)) WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id));

CREATE POLICY "chat_messages_insert_service_only" ON public."chat_messages" AS PERMISSIVE FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "chat_messages_select" ON public."chat_messages" AS PERMISSIVE FOR SELECT TO authenticated USING ((((EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = chat_messages.conversation_id) AND ((( SELECT ( SELECT auth.uid() AS uid) AS uid) = ANY (c.participant_ids)) OR ((c.type = 'support'::text) AND (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = chat_messages.booking_id) AND ((b.user_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (b.owner_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (b.created_by_user_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (( SELECT ( SELECT auth.uid() AS uid) AS uid) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))))))) AND (NOT (EXISTS ( SELECT 1
   FROM (conversations c
     CROSS JOIN LATERAL unnest(COALESCE(c.participant_ids, ARRAY[]::uuid[])) partner_id(partner_id))
  WHERE ((c.id = chat_messages.conversation_id) AND (partner_id.partner_id <> ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND are_users_blocked(( SELECT ( SELECT auth.uid() AS uid) AS uid), partner_id.partner_id)))))));

CREATE POLICY "chat_messages_update" ON public."chat_messages" AS PERMISSIVE FOR UPDATE TO authenticated USING ((sender_id = auth.uid())) WITH CHECK ((sender_id = auth.uid()));

CREATE POLICY "conversations_delete_participant" ON public."conversations" AS PERMISSIVE FOR DELETE TO authenticated USING ((auth.uid() = ANY (participant_ids)));

CREATE POLICY "conversations_select_unified" ON public."conversations" AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = ANY (participant_ids)) OR ((type = 'support'::text) AND vsp_is_admin_actor()) OR (auth.uid() = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id)))));

CREATE POLICY "copilot_conversations_user_policy" ON public."copilot_conversations" AS PERMISSIVE FOR ALL TO authenticated USING ((( SELECT ( SELECT auth.uid() AS uid) AS uid) = user_id)) WITH CHECK ((( SELECT ( SELECT auth.uid() AS uid) AS uid) = user_id));

CREATE POLICY "copilot_messages_user_policy" ON public."copilot_messages" AS PERMISSIVE FOR ALL TO authenticated USING ((( SELECT ( SELECT auth.uid() AS uid) AS uid) = user_id)) WITH CHECK ((( SELECT ( SELECT auth.uid() AS uid) AS uid) = user_id));

CREATE POLICY "owner_can_manage_hours" ON public."court_operating_hours" AS PERMISSIVE FOR ALL TO public USING ((court_id IN ( SELECT stadiums.id
   FROM stadiums
  WHERE (stadiums.owner_id = auth.uid()))));

CREATE POLICY "financial_logs_admin_all" ON public."financial_audit_logs" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(auth.uid())) WITH CHECK (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "financial_logs_owner_select" ON public."financial_audit_logs" AS PERMISSIVE FOR SELECT TO authenticated USING ((owner_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)));

CREATE POLICY "financial_logs_user_select" ON public."financial_audit_logs" AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)));

CREATE POLICY "service_role_internal_secrets_full" ON public."internal_function_secrets" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Allow admins to manage league_settings" ON public."league_settings" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))))));

CREATE POLICY "Allow public read on league_settings" ON public."league_settings" AS PERMISSIVE FOR SELECT TO anon,authenticated USING (true);

CREATE POLICY "owner_can_insert_edits" ON public."match_score_edits" AS PERMISSIVE FOR INSERT TO public WITH CHECK ((edited_by = auth.uid()));

CREATE POLICY "owner_can_read_own_edits" ON public."match_score_edits" AS PERMISSIVE FOR SELECT TO public USING (((championship_id IN ( SELECT championships.id
   FROM championships
  WHERE (championships.owner_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))));

CREATE POLICY "Anyone authenticated can view matchup results" ON public."matchup_results" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "Anyone authenticated can view matchup teams" ON public."matchup_teams" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "notifications_delete_owner" ON public."notifications" AS PERMISSIVE FOR DELETE TO authenticated USING (((user_id = auth.uid()) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "notifications_insert_secure" ON public."notifications" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((is_admin_or_cofounder(( SELECT auth.uid() AS uid)) OR (user_id = ( SELECT auth.uid() AS uid)) OR ((booking_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = notifications.booking_id) AND ((b.user_id = ( SELECT auth.uid() AS uid)) OR (b.owner_id = ( SELECT auth.uid() AS uid)) OR (b.created_by_user_id = ( SELECT auth.uid() AS uid)) OR (( SELECT auth.uid() AS uid) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))) AND ((notifications.user_id = b.user_id) OR (notifications.user_id = b.owner_id) OR (notifications.user_id = b.created_by_user_id) OR (notifications.user_id = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))))));

CREATE POLICY "notifications_select_owner" ON public."notifications" AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "notifications_update_owner" ON public."notifications" AS PERMISSIVE FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "owner_documents_admin_delete" ON public."owner_documents" AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])));

CREATE POLICY "owner_documents_admin_update" ON public."owner_documents" AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))) WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])));

CREATE POLICY "owner_documents_owner_insert" ON public."owner_documents" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((owner_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))));

CREATE POLICY "owner_documents_owner_select" ON public."owner_documents" AS PERMISSIVE FOR SELECT TO authenticated USING (((owner_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))));

CREATE POLICY "owner_documents_service_role" ON public."owner_documents" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "owner_subscription_orders_select_own" ON public."owner_subscription_orders" AS PERMISSIVE FOR SELECT TO authenticated USING (((owner_id = auth.uid()) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "service_role_only" ON public."owner_trial_ledger" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "payout_settlements_select_owner_or_admin" ON public."payout_settlements" AS PERMISSIVE FOR SELECT TO authenticated USING (((owner_id = auth.uid()) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "platform_business_rules_admin_write" ON public."platform_business_rules" AS PERMISSIVE FOR ALL TO authenticated USING ((COALESCE(( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))), ''::text) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))) WITH CHECK ((COALESCE(( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))), ''::text) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])));

CREATE POLICY "platform_business_rules_select_authenticated" ON public."platform_business_rules" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "platform_fee_config_public_read" ON public."platform_fee_config" AS PERMISSIVE FOR SELECT TO anon,authenticated USING (true);

CREATE POLICY "player_trophies_public_select" ON public."player_trophies" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "promotions_admin_manage" ON public."promotions" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(auth.uid())) WITH CHECK (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "promotions_public_read" ON public."promotions" AS PERMISSIVE FOR SELECT TO public USING ((is_active = true));

CREATE POLICY "rate_limit_admin_manage" ON public."rate_limit_logs" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "Admins full access" ON public."reports" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "reports_admin_delete" ON public."reports" AS PERMISSIVE FOR DELETE TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "reports_admin_select" ON public."reports" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "Admins full access" ON public."reviews" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid))) WITH CHECK (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "reviews_select" ON public."reviews" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "stadium_custom_rates_manage_own" ON public."stadium_custom_rates" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM stadiums s
  WHERE ((s.id = stadium_custom_rates.stadium_id) AND ((s.owner_id = auth.uid()) OR is_admin_or_cofounder(auth.uid())))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM stadiums s
  WHERE ((s.id = stadium_custom_rates.stadium_id) AND ((s.owner_id = auth.uid()) OR is_admin_or_cofounder(auth.uid()))))));

CREATE POLICY "stadium_custom_rates_select" ON public."stadium_custom_rates" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "stadiums_admin_manage_all" ON public."stadiums" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(auth.uid())) WITH CHECK (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "stadiums_delete_own" ON public."stadiums" AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id));

CREATE POLICY "stadiums_insert_own" ON public."stadiums" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id));

CREATE POLICY "stadiums_select_public" ON public."stadiums" AS PERMISSIVE FOR SELECT TO public USING ((((is_verified = true) AND (is_blocked = false) AND (is_deleted_by_owner = false)) OR (( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id)));

CREATE POLICY "stadiums_update_own" ON public."stadiums" AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id)) WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id));

CREATE POLICY "subscription_plans_public_read" ON public."subscription_plans" AS PERMISSIVE FOR SELECT TO anon,authenticated USING ((is_active = true));

CREATE POLICY "support_ticket_messages_staff_insert" ON public."support_ticket_messages" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (support_tickets t
     JOIN users u ON ((u.id = auth.uid())))
  WHERE ((t.id = support_ticket_messages.ticket_id) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false))))));

CREATE POLICY "support_ticket_messages_staff_select" ON public."support_ticket_messages" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (support_tickets t
     JOIN users u ON ((u.id = auth.uid())))
  WHERE ((t.id = support_ticket_messages.ticket_id) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false)))));

CREATE POLICY "support_ticket_messages_user_select" ON public."support_ticket_messages" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM support_tickets t
  WHERE ((t.id = support_ticket_messages.ticket_id) AND (t.requester_id = auth.uid()) AND (support_ticket_messages.is_internal = false)))));

CREATE POLICY "support_tickets_staff_select" ON public."support_tickets" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false)))));

CREATE POLICY "support_tickets_staff_update" ON public."support_tickets" AS PERMISSIVE FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'super_admin'::text, 'cofounder'::text, 'co_founder'::text])) AND (COALESCE(u.is_blocked, false) = false)))));

CREATE POLICY "support_tickets_user_select" ON public."support_tickets" AS PERMISSIVE FOR SELECT TO authenticated USING ((requester_id = auth.uid()));

CREATE POLICY "Admins can view audit logs" ON public."system_audit_logs" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "challenge_codes_service_only" ON public."team_challenge_codes" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Anyone authenticated can view team head to head" ON public."team_head_to_head" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "admins_view_league_refund_queue" ON public."team_league_cancellation_refund_queue" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "service_role_league_refund_queue_full" ON public."team_league_cancellation_refund_queue" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Allow team captains/members to view match submissions" ON public."team_league_match_submissions" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "service_role_team_league_payments_full" ON public."team_league_payments" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "users_view_own_team_league_payments" ON public."team_league_payments" AS PERMISSIVE FOR SELECT TO authenticated USING (((team_id IN ( SELECT team_members.team_id
   FROM team_members
  WHERE (team_members.user_id = auth.uid()))) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "Allow authenticated to view audits of their league" ON public."team_league_result_audits" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "team_members_delete" ON public."team_members" AS PERMISSIVE FOR DELETE TO authenticated USING (((user_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (EXISTS ( SELECT 1
   FROM teams
  WHERE ((teams.id = team_members.team_id) AND (teams.captain_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)))))));

CREATE POLICY "team_members_insert" ON public."team_members" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM teams
  WHERE ((teams.id = team_members.team_id) AND (teams.captain_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))))));

CREATE POLICY "team_members_select" ON public."team_members" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "teams_delete_own" ON public."teams" AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = captain_id));

CREATE POLICY "teams_insert" ON public."teams" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = captain_id));

CREATE POLICY "teams_select" ON public."teams" AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "teams_update_own" ON public."teams" AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = captain_id)) WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = captain_id));

CREATE POLICY "Admins full access" ON public."tournament_matches" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "tournament_matches_insert" ON public."tournament_matches" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_matches.championship_id) AND ((c.owner_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))))));

CREATE POLICY "tournament_matches_select" ON public."tournament_matches" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "tournament_orders_owner_select" ON public."tournament_orders" AS PERMISSIVE FOR SELECT TO authenticated USING (((captain_user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_orders.championship_id) AND (c.owner_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])))))));

CREATE POLICY "transactions_admin_select" ON public."transactions" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "transactions_insert_admin_service" ON public."transactions" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "transactions_select_owner_or_admin" ON public."transactions" AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = transactions.booking_id) AND (b.owner_id = auth.uid())))) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "user_blocks_delete_own" ON public."user_blocks" AS PERMISSIVE FOR DELETE TO authenticated USING ((blocker_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "user_blocks_insert_own" ON public."user_blocks" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((blocker_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (blocked_user_id <> ( SELECT ( SELECT auth.uid() AS uid) AS uid))));

CREATE POLICY "user_blocks_select_own" ON public."user_blocks" AS PERMISSIVE FOR SELECT TO authenticated USING ((blocker_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "Users can register own device token" ON public."user_device_tokens" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "Users can remove own device token" ON public."user_device_tokens" AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "Users can update own device token" ON public."user_device_tokens" AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "Users can view own device tokens" ON public."user_device_tokens" AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "user_public_profiles_select" ON public."user_public_profiles" AS PERMISSIVE FOR SELECT TO anon,authenticated USING (true);

CREATE POLICY "users_admin_manage_all" ON public."users" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid))) WITH CHECK (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "users_delete_policy" ON public."users" AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = id));

CREATE POLICY "users_insert_policy" ON public."users" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((id = auth.uid()));

CREATE POLICY "users_select_policy" ON public."users" AS PERMISSIVE FOR SELECT TO authenticated USING (((id = auth.uid()) OR is_admin_or_cofounder(auth.uid())));

CREATE POLICY "users_update_policy" ON public."users" AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = id)) WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = id));

CREATE POLICY "admins_view_1v1_refund_queue" ON public."vsp_1v1_cancellation_refund_queue" AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin_or_cofounder(auth.uid()));

CREATE POLICY "service_role_1v1_refund_queue_full" ON public."vsp_1v1_cancellation_refund_queue" AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Admins full access" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "vsp_1v1_registrations_insert" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = user_id));

CREATE POLICY "vsp_1v1_registrations_select" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "Service role and atomic functions manage 1v1 orders" ON public."vsp_1v1_tournament_orders" AS PERMISSIVE FOR ALL TO authenticated,service_role USING (((COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK (((COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

CREATE POLICY "Users and admins can view 1v1 orders" ON public."vsp_1v1_tournament_orders" AS PERMISSIVE FOR SELECT TO authenticated,service_role USING (((( SELECT ( SELECT auth.uid() AS uid) AS uid) = user_id) OR (COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

CREATE POLICY "Admins full access" ON public."vsp_1v1_tournament_players" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid))) WITH CHECK (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "Admins manage tournament players" ON public."vsp_1v1_tournament_players" AS PERMISSIVE FOR ALL TO public USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))) WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text])));

CREATE POLICY "Anyone can view tournament players" ON public."vsp_1v1_tournament_players" AS PERMISSIVE FOR SELECT TO anon,authenticated USING (((payment_status = 'paid'::text) OR ((( SELECT ( SELECT auth.uid() AS uid) AS uid) IS NOT NULL) AND (user_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) OR (COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

CREATE POLICY "Admins full access" ON public."vsp_1v1_tournaments" AS PERMISSIVE FOR ALL TO authenticated USING (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid))) WITH CHECK (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid)));

CREATE POLICY "Admins manage tournaments" ON public."vsp_1v1_tournaments" AS PERMISSIVE FOR ALL TO public USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))) WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text])));

CREATE POLICY "Anyone can view active or completed 1v1 tournaments" ON public."vsp_1v1_tournaments" AS PERMISSIVE FOR SELECT TO anon,authenticated USING ((status = ANY (ARRAY['registration_open'::text, 'in_progress'::text, 'completed'::text, 'published'::text, 'archived'::text])));

CREATE POLICY "Anyone can view published tournaments" ON public."vsp_1v1_tournaments" AS PERMISSIVE FOR SELECT TO public USING ((status = 'published'::text));

CREATE POLICY "admin_manage_1v1_players" ON public."vsp_1vs1_players" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "vsp_1vs1_players_select_unified" ON public."vsp_1vs1_players" AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "webhook_logs_admin_only" ON public."webhook_logs" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

CREATE POLICY "webhook_logs_admin_select" ON public."webhook_logs" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = 'admin'::text)))));



-- --------------------------------------------------------------------------
-- 8. FUNCTIONS & STORED PROCEDURES
-- --------------------------------------------------------------------------
-- Function: _generate_unique_challenge_code
CREATE OR REPLACE FUNCTION public._generate_unique_challenge_code()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_code text;
  v_try  int := 0;
BEGIN
  LOOP
    v_code := 'VSP-' || upper(
      translate(
        substring(md5(gen_random_uuid()::text), 1, 5),
        '01IOil', 'ABCDEF'
      )
    );
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.team_challenge_codes WHERE code = v_code AND status = 'active'
    );
    v_try := v_try + 1;
    IF v_try > 30 THEN RAISE EXCEPTION 'code_generation_exhausted'; END IF;
  END LOOP;
  RETURN v_code;
END;
$function$
;

-- Function: accept_join_request
CREATE OR REPLACE FUNCTION public.accept_join_request(p_booking_id text, p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_user_uuid UUID;
BEGIN
    IF p_user_id ~ '^[0-9a-fA-F-]{36}$' THEN
        v_user_uuid := p_user_id::uuid;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'معرف المستخدم غير صالح.');
    END IF;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    -- 🔒 التحقق من أن المتصل هو منشئ التحدي أو صاحب الملعب
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL OR (auth.uid() != v_booking.created_by_user_id AND auth.uid() != v_booking.owner_id) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: منشئ المباراة أو مالك الملعب فقط يمكنهما قبول اللاعبين.');
        END IF;
    END IF;

    IF v_booking.current_players >= COALESCE(v_booking.total_field_capacity, 10) THEN
        RETURN jsonb_build_object('success', false, 'message', 'اكتمل العدد المطلوب للمباراة بالفعل.');
    END IF;

    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids, ARRAY[]::text[]), p_user_id),
        joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::uuid[]), v_user_uuid),
        current_players = current_players + 1,
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'تم قبول اللاعب بنجاح.');
END;
$function$
;

-- Function: activate_championship_competition_atomic
CREATE OR REPLACE FUNCTION public.activate_championship_competition_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_matches_count INT;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  SELECT count(*)::INT INTO v_matches_count
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  IF v_champ.status != 'open' OR v_champ.registration_locked_at IS NULL OR v_matches_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_in_draw_ready_phase');
  END IF;

  UPDATE public.championships
  SET status = 'ongoing',
      updated_at = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'ongoing',
    'effective_phase', 'ongoing'
  );
END;
$function$
;

-- Function: activate_vsp_pro
CREATE OR REPLACE FUNCTION public.activate_vsp_pro(p_owner_id text, p_transaction_id text, p_days integer DEFAULT 30)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role text;
  v_owner_uuid uuid;
BEGIN
  -- التحقق من الصلاحيات الإدارية
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder') THEN
    RAISE EXCEPTION 'Security Alert: Only administrators can activate VSP Pro directly.';
  END IF;

  v_owner_uuid := p_owner_id::uuid;

  UPDATE public.users
  SET
    subscription_plan = 'pro',
    subscription_expires_at = NOW() + (p_days || ' days')::interval,
    updated_at = NOW()
  WHERE id = v_owner_uuid;

  RETURN true;
END;
$function$
;

-- Function: add_team_member_atomic
CREATE OR REPLACE FUNCTION public.add_team_member_atomic(p_team_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_exists boolean;
  v_captain_governorate text;
  v_player_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id
      AND (captain_id = auth.uid()
           OR v_role IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  PERFORM 1 FROM public.teams WHERE id = p_team_id FOR UPDATE;

  SELECT u.governorate
    INTO v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = p_team_id;

  SELECT governorate INTO v_player_governorate
  FROM public.users
  WHERE id = p_user_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'محافظة الكابتن غير محددة.'
    );
  END IF;

  IF v_player_governorate IS NULL OR btrim(v_player_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'PLAYER_GOVERNORATE_REQUIRED',
      'message', 'لا يمكن إضافة لاعب بدون محافظة محددة.'
    );
  END IF;

  IF lower(btrim(v_player_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TEAM_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن إضافة اللاعب لأن محافظته مختلفة عن محافظة كابتن الفريق.'
    );
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_user_id
  ) INTO v_exists;

  IF v_exists THEN
    RETURN jsonb_build_object('success', true, 'already_member', true);
  END IF;

  IF (SELECT count(*) FROM public.team_members WHERE team_id = p_team_id) >= 12 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team is full');
  END IF;

  IF (SELECT count(*) FROM public.team_members WHERE user_id = p_user_id) >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player reached maximum teams');
  END IF;

  INSERT INTO public.team_members(team_id, user_id)
  VALUES(p_team_id, p_user_id);

  RETURN jsonb_build_object('success', true);
END;
$function$
;

-- Function: add_team_to_matchup_by_code
CREATE OR REPLACE FUNCTION public.add_team_to_matchup_by_code(p_booking_id uuid, p_invite_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_caller_id uuid := auth.uid();
 v_booking record;
 v_target_team record;
 v_clean_code text := upper(trim(p_invite_code));
 v_current_count int;
 v_members int;
begin
 if v_caller_id is null then raise exception 'Unauthorized: User not authenticated'; end if;

 select id, created_by_user_id, user_id, status, matchup_closed_at, end_time
 into v_booking from public.bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if coalesce(v_booking.created_by_user_id,v_booking.user_id) <> v_caller_id then
   raise exception 'Forbidden: Only the booking creator can add teams to the matchup';
 end if;
 if v_booking.matchup_closed_at is not null or v_booking.status='cancelled'
    or v_booking.end_time <= timezone('utc',now()) then
   raise exception 'Cannot add teams to an ended or closed matchup';
 end if;
 if length(v_clean_code) < 4 then raise exception 'Invalid invite code provided'; end if;

 select id,name,logo_url,captain_id,invite_code_expires_at
 into v_target_team from public.teams where active_invite_code=v_clean_code for update;
 if not found then raise exception 'Invalid or expired invite code'; end if;
 if v_target_team.invite_code_expires_at is not null
    and v_target_team.invite_code_expires_at < timezone('utc',now()) then
   raise exception 'This invite code has expired';
 end if;

 select count(*) into v_members from public.team_members where team_id=v_target_team.id;
 if v_members < 5 then raise exception 'Team is incomplete (less than 5 members)'; end if;

 if exists(select 1 from public.matchup_teams where booking_id=p_booking_id and team_id=v_target_team.id) then
   raise exception 'Team is already added to this matchup';
 end if;

 select count(*) into v_current_count from public.matchup_teams where booking_id=p_booking_id;

 if v_current_count >= 5 then
   raise exception 'MATCHUP_TEAM_LIMIT_REACHED: A matchup can contain at most 5 teams';
 end if;

 insert into public.matchup_teams(booking_id,team_id,added_by_user_id,joined_at)
 values(p_booking_id,v_target_team.id,v_caller_id,timezone('utc',now()));

 update public.teams set active_invite_code=null, invite_code_expires_at=null where id=v_target_team.id;

 return jsonb_build_object(
   'success',true,
   'booking_id',p_booking_id,
   'team_id',v_target_team.id,
   'team_name',v_target_team.name,
   'logo_url',v_target_team.logo_url,
   'total_teams_now',v_current_count+1
 );
end $function$
;

-- Function: admin_add_1v1_cash_player_atomic
CREATE OR REPLACE FUNCTION public.admin_add_1v1_cash_player_atomic(p_tournament_id uuid, p_player_name text, p_user_id uuid DEFAULT NULL::uuid, p_paid_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role TEXT;
  v_tournament RECORD;
  v_name TEXT := NULLIF(TRIM(COALESCE(p_player_name,'')), '');
  v_amount NUMERIC;
  v_paid_count INTEGER;
  v_player_id UUID;
  v_now TIMESTAMPTZ := timezone('utc', now());
BEGIN
  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF COALESCE(auth.role(),'') <> 'service_role'
     AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RETURN jsonb_build_object('success',false,'error','Unauthorized');
  END IF;

  IF v_name IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','اسم اللاعب مطلوب.');
  END IF;

  SELECT * INTO v_tournament
  FROM public.vsp_1v1_tournaments
  WHERE id = p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','البطولة غير موجودة.');
  END IF;

  IF v_tournament.status NOT IN ('registration_open','in_progress') THEN
    RETURN jsonb_build_object('success',false,'error','لا يمكن إضافة لاعب يدويًا بعد إغلاق البطولة.');
  END IF;

  SELECT count(*) INTO v_paid_count
  FROM public.vsp_1v1_tournament_players
  WHERE tournament_id = p_tournament_id AND payment_status = 'paid';

  IF v_paid_count >= v_tournament.target_player_count THEN
    RETURN jsonb_build_object('success',false,'error','اكتملت مقاعد البطولة بالفعل.');
  END IF;

  IF p_user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.vsp_1v1_tournament_players
    WHERE tournament_id=p_tournament_id AND user_id=p_user_id
  ) THEN
    RETURN jsonb_build_object('success',false,'error','هذا اللاعب مسجل بالفعل في البطولة.');
  END IF;

  v_amount := COALESCE(p_paid_amount, v_tournament.entry_fee, 0);
  IF v_amount < 0 THEN
    RETURN jsonb_build_object('success',false,'error','المبلغ لا يمكن أن يكون سالبًا.');
  END IF;

  INSERT INTO public.vsp_1v1_tournament_players(
    tournament_id,user_id,player_name,avatar_url,tackles,goals,skills,
    total_points,rounds_played,payment_status,paid_amount,registered_at,updated_at
  )
  SELECT
    p_tournament_id,
    p_user_id,
    v_name,
    CASE WHEN p_user_id IS NOT NULL THEN (SELECT profile_image_url FROM public.users WHERE id=p_user_id) ELSE NULL END,
    0,0,0,0,0,'paid',v_amount,v_now,v_now
  RETURNING id INTO v_player_id;

  UPDATE public.vsp_1v1_tournaments
  SET prize_pool = COALESCE(prize_pool,0) + v_amount,
      updated_at = v_now
  WHERE id=p_tournament_id;

  INSERT INTO public.transactions(
    user_id, amount, type, payment_method, status, reference_number,
    metadata, description, created_at, updated_at
  ) VALUES (
    p_user_id,
    v_amount,
    'payment',
    'cash',
    'completed',
    '1V1-CASH-' || replace(v_player_id::text,'-',''),
    jsonb_build_object(
      'tournament_id',p_tournament_id,
      'player_id',v_player_id,
      'manual_registration',true,
      'recorded_by',auth.uid()
    ),
    'تسجيل يدوي نقدي في بطولة 1v1 - ' || COALESCE(v_tournament.name,''),
    v_now,
    v_now
  );

  RETURN jsonb_build_object(
    'success',true,
    'player_id',v_player_id,
    'paid_amount',v_amount,
    'payment_method','cash'
  );
END;
$function$
;

-- Function: admin_approve_1v1_registration_atomic
CREATE OR REPLACE FUNCTION public.admin_approve_1v1_registration_atomic(p_registration_id uuid, p_name text, p_avatar_url text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_reg record; v_name text; v_now timestamptz:=timezone('utc',now()); v_player_id uuid;
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  select * into v_reg from public.vsp_1v1_registrations where id=p_registration_id for update;
  if not found then return jsonb_build_object('success',false,'error','Registration not found'); end if;
  if v_reg.status='approved' then return jsonb_build_object('success',true,'idempotent',true); end if;
  v_name:=coalesce(nullif(trim(p_name),''),(select name from public.users where id=v_reg.user_id), '1v1 Player');
  insert into public.vsp_1vs1_players(name,avatar_url,total_points,skill_points,goals,tackles,titles,trend,created_at,updated_at)
  values(v_name,nullif(trim(coalesce(p_avatar_url,'')),''),0,0,0,0,0,'stable',v_now,v_now)
  returning id into v_player_id;
  update public.vsp_1v1_registrations set status='approved' where id=p_registration_id;
  return jsonb_build_object('success',true,'registration_id',p_registration_id,'player_id',v_player_id,'server_time',v_now);
exception when unique_violation then
  return jsonb_build_object('success',false,'error','Player already exists or registration has already been processed');
end $function$
;

-- Function: admin_approve_championship_atomic
CREATE OR REPLACE FUNCTION public.admin_approve_championship_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_champ RECORD;
  v_now timestamptz := NOW();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
  IF v_caller_role NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
    RAISE EXCEPTION 'Permission Denied';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  IF v_champ.is_approved = true AND v_champ.status = 'open' THEN
    RETURN jsonb_build_object('success', true, 'already_approved', true, 'message', 'Championship was already approved.');
  END IF;

  UPDATE public.championships
  SET is_approved = true,
      status = 'open',
      rejection_reason = NULL,
      rejected_at = NULL,
      updated_at = v_now
  WHERE id = p_championship_id;

  IF v_champ.owner_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, message, type, metadata, created_at)
    VALUES(
      v_champ.owner_id,
      'تمت الموافقة على بطولتك',
      'تم اعتماد بطولتك "' || COALESCE(v_champ.name, '') || '" وأصبحت متاحة للتسجيل.',
      'تمت موافقة على بطولتك.',
      'tournament_approval',
      jsonb_build_object('championship_id', p_championship_id, 'status', 'approved'),
      v_now
    );
  END IF;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_approve_championship',
    'championships',
    p_championship_id,
    jsonb_build_object('is_approved', v_champ.is_approved, 'status', v_champ.status),
    jsonb_build_object('is_approved', true, 'status', 'open'),
    v_caller_id,
    v_caller_role,
    v_now
  );

  RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'is_approved', true, 'status', 'open', 'server_time', v_now);
END;
$function$
;

-- Function: admin_approve_owner_atomic
CREATE OR REPLACE FUNCTION public.admin_approve_owner_atomic(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_caller_id uuid:=auth.uid(); v_caller_role TEXT; v_now timestamptz:=timezone('utc',now()); BEGIN IF COALESCE(auth.role(),'')<>'service_role' THEN SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller_id; IF COALESCE(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF; END IF; IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_owner_id) THEN RETURN jsonb_build_object('success',false,'error','Owner not found'); END IF; UPDATE public.users SET verification_status='approved',is_identity_verified=true,updated_at=v_now WHERE id=p_owner_id; UPDATE public.stadiums SET is_verified=true,updated_at=v_now WHERE owner_id=p_owner_id; INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(p_owner_id,'تهانينا! تم توثيق حسابك كصاحب ملعب رسمي','تمت مراجعة مستنداتك وتوثيق حسابك. ملاعبك أصبحت ظاهرة للاعبين. كل بطولة تنشئها تحتاج موافقة إدارية مستقلة.','stadium_approved',v_now); INSERT INTO public.system_audit_logs(action,table_name,record_id,new_data,changed_by,changed_by_role,created_at) VALUES('admin_approve_owner','users',p_owner_id,jsonb_build_object('verification_status','approved'),v_caller_id,v_caller_role,v_now); RETURN jsonb_build_object('success',true,'owner_id',p_owner_id,'server_time',v_now); END; $function$
;

-- Function: admin_cancel_booking_atomic
CREATE OR REPLACE FUNCTION public.admin_cancel_booking_atomic(p_booking_id uuid, p_reason text DEFAULT 'Cancelled by Admin'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_role text;
  v_is_blocked boolean;
  v_result jsonb;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    IF v_actor_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
    END IF;
    SELECT role, coalesce(is_blocked, false) INTO v_role, v_is_blocked FROM public.users WHERE id = v_actor_id;
    IF v_is_blocked THEN
      RETURN jsonb_build_object('success', false, 'error', 'Actor account is blocked');
    END IF;
    IF coalesce(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
    END IF;
  END IF;

  v_result := public.cancel_booking_with_refund_atomic(
    p_booking_id,
    coalesce(nullif(trim(p_reason), ''), 'Cancelled by Admin'),
    v_actor_id
  );
  RETURN v_result;
END;
$function$
;

-- Function: admin_create_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.admin_create_1v1_tournament_atomic(p_name text, p_target_player_count integer, p_entry_fee numeric, p_scheduled_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_governorate text DEFAULT NULL::text, p_prize_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role TEXT;
  v_id UUID;
  v_now TIMESTAMPTZ := timezone('utc',now());
  v_governorate TEXT := NULLIF(TRIM(p_governorate),'');
BEGIN
  IF COALESCE(auth.role(),'') <> 'service_role' THEN
    SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
    IF COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;
  IF NULLIF(TRIM(p_name),'') IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Tournament name is required');
  END IF;
  IF p_target_player_count IS NULL OR p_target_player_count < 2 THEN
    RETURN jsonb_build_object('success',false,'error','Target player count must be at least 2');
  END IF;
  IF p_entry_fee IS NULL OR p_entry_fee < 0 THEN
    RETURN jsonb_build_object('success',false,'error','Entry fee cannot be negative');
  END IF;
  IF COALESCE(p_prize_amount,0) < 0 THEN
    RETURN jsonb_build_object('success',false,'error','Prize amount cannot be negative');
  END IF;
  IF v_governorate IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Governorate is required');
  END IF;

  INSERT INTO public.vsp_1v1_tournaments(
    name,target_player_count,entry_fee,prize_pool,prize_amount,governorate,status,scheduled_at,created_by,created_at,updated_at
  )
  VALUES(
    TRIM(p_name),p_target_player_count,ROUND(p_entry_fee,2),0,ROUND(COALESCE(p_prize_amount,0),2),v_governorate,
    'registration_open',p_scheduled_at,COALESCE(auth.uid(),null),v_now,v_now
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'success',true,
    'id',v_id,
    'prize_amount',ROUND(COALESCE(p_prize_amount,0),2),
    'created_by',auth.uid(),
    'server_time',v_now
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success',false,'error','A conflicting active tournament already exists');
END;
$function$
;

-- Function: admin_create_owner_with_stadium_atomic
CREATE OR REPLACE FUNCTION public.admin_create_owner_with_stadium_atomic(p_name text, p_phone text, p_email text, p_stadium_name text, p_governorate text, p_price_per_hour numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_owner_id uuid;
  v_stadium_id uuid;
  v_now timestamptz := timezone('utc',now());
  v_governorate text := nullif(trim(p_governorate),'');
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
    IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;

  IF nullif(trim(p_name),'') IS NULL OR nullif(trim(p_phone),'') IS NULL
     OR nullif(trim(p_stadium_name),'') IS NULL OR v_governorate IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Required owner/stadium fields are missing');
  END IF;

  IF p_price_per_hour IS NULL OR p_price_per_hour <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','Stadium hourly price must be greater than zero');
  END IF;

  INSERT INTO public.users(
    name,phone,email,role,verification_status,is_identity_verified,governorate,is_blocked,created_at,updated_at
  )
  VALUES(
    trim(p_name),trim(p_phone),nullif(trim(p_email),''),'owner','approved',true,v_governorate,false,v_now,v_now
  )
  RETURNING id INTO v_owner_id;

  INSERT INTO public.stadiums(
    owner_id,name,governorate,price_per_hour,base_price,is_verified,is_blocked,created_at,updated_at
  )
  VALUES(
    v_owner_id,trim(p_stadium_name),v_governorate,round(p_price_per_hour,2),round(p_price_per_hour,2),true,false,v_now,v_now
  )
  RETURNING id INTO v_stadium_id;

  RETURN jsonb_build_object(
    'success',true,'owner_id',v_owner_id,'stadium_id',v_stadium_id,'server_time',v_now
  );
END;
$function$
;

-- Function: admin_finalize_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.admin_finalize_1v1_tournament_atomic(p_tournament_id uuid, p_champion_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_tournament record;
  v_player record;
  v_paid_count integer;
  v_now timestamptz := timezone('utc',now());
  v_team_id uuid;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' AND current_user <> 'postgres' THEN
    SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
    IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;

  SELECT * INTO v_tournament
  FROM public.vsp_1v1_tournaments
  WHERE id=p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Tournament not found');
  END IF;

  IF v_tournament.status <> 'in_progress' THEN
    RETURN jsonb_build_object('success',false,'error','Start the tournament first, then finalize the results after play is complete.');
  END IF;

  SELECT count(*)::integer INTO v_paid_count
  FROM public.vsp_1v1_tournament_players
  WHERE tournament_id=p_tournament_id AND payment_status='paid';

  IF v_paid_count < 2 THEN
    RETURN jsonb_build_object('success',false,'error','At least two paid players are required before finalizing');
  END IF;

  SELECT * INTO v_player
  FROM public.vsp_1v1_tournament_players
  WHERE tournament_id=p_tournament_id
    AND user_id=p_champion_user_id
    AND payment_status='paid'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Champion must be a registered paid player');
  END IF;

  UPDATE public.vsp_1v1_tournaments
  SET status='completed',
      published_at=coalesce(published_at,v_now),
      champion_user_id=p_champion_user_id,
      updated_at=v_now
  WHERE id=p_tournament_id;

  IF NOT EXISTS (
    SELECT 1 FROM public.player_trophies
    WHERE user_id=p_champion_user_id AND tournament_1v1_id=p_tournament_id
  ) THEN
    INSERT INTO public.player_trophies(
      id,user_id,tournament_1v1_id,title,prize_won,created_at
    ) VALUES (
      gen_random_uuid(),
      p_champion_user_id,
      p_tournament_id,
      'بطل تحدي 1v1 - ' || coalesce(v_tournament.name,'VSP 1v1') || ' (' || coalesce(v_tournament.governorate,'') || ')',
      coalesce(v_tournament.prize_pool,0),
      v_now
    );
  END IF;

  SELECT team_id INTO v_team_id
  FROM public.team_members
  WHERE user_id=p_champion_user_id
  LIMIT 1;

  IF v_team_id IS NOT NULL THEN
    UPDATE public.teams
    SET has_1v1_champion=true
    WHERE id=v_team_id;
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'tournament_id',p_tournament_id,
    'champion_user_id',p_champion_user_id,
    'status','completed',
    'trophy_awarded',true,
    'prize_pool',coalesce(v_tournament.prize_pool,0)
  );
END;
$function$
;

-- Function: admin_get_1v1_round_scores
CREATE OR REPLACE FUNCTION public.admin_get_1v1_round_scores(p_tournament_id uuid, p_round_number integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_target integer;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    select role into v_role from public.users where id=auth.uid();
    if coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
      return jsonb_build_object('success',false,'error','Unauthorized');
    end if;
  end if;

  select target_player_count into v_target from public.vsp_1v1_tournaments where id=p_tournament_id;
  return jsonb_build_object(
    'success',true,
    'target_player_count',v_target,
    'scores',coalesce((
      select jsonb_agg(to_jsonb(s) order by s.round_number,s.player_id)
      from public.vsp_1v1_player_round_scores s
      where s.tournament_id=p_tournament_id
        and (p_round_number is null or s.round_number=p_round_number)
    ),'[]'::jsonb)
  );
end;
$function$
;

-- Function: admin_publish_legacy_1v1_standings_atomic
CREATE OR REPLACE FUNCTION public.admin_publish_legacy_1v1_standings_atomic(p_players jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_count integer:=0; v_item jsonb; v_tackles integer; v_goals integer; v_skills integer; v_total integer; v_titles integer; v_trend text; v_name text; v_round text; v_now timestamptz:=timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  if jsonb_typeof(coalesce(p_players,'[]'::jsonb))<>'array' then
    return jsonb_build_object('success',false,'error','Players payload must be an array');
  end if;

  delete from public.vsp_1vs1_players;

  for v_item in select value from jsonb_array_elements(p_players)
  loop
    v_name:=nullif(trim(v_item->>'name'),'');
    if v_name is null then
      return jsonb_build_object('success',false,'error','Every player must have a name');
    end if;
    v_tackles:=greatest(0,coalesce((v_item->>'tackles')::integer,0));
    v_goals:=greatest(0,coalesce((v_item->>'goals')::integer,0));
    v_skills:=greatest(0,coalesce((v_item->>'skill_points')::integer,0));
    v_total:=v_tackles+v_goals+v_skills;
    v_titles:=greatest(0,coalesce((v_item->>'titles')::integer,0));
    v_round:=nullif(trim(v_item->>'round_reached'),'');
    v_trend:=coalesce(nullif(trim(v_item->>'trend'),''),case when v_round='champion' then 'up' else 'stable' end);

    insert into public.vsp_1vs1_players(name,avatar_url,tackles,goals,skill_points,total_points,titles,trend,round_reached,created_at,updated_at)
    values(v_name,nullif(trim(coalesce(v_item->>'avatar_url','')),''),v_tackles,v_goals,v_skills,v_total,v_titles,v_trend,v_round,v_now,v_now);
    v_count:=v_count+1;
  end loop;

  return jsonb_build_object('success',true,'count',v_count,'server_time',v_now);
exception when others then
  return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end;
$function$
;

-- Function: admin_record_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.admin_record_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_payment_method text, p_reference text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_caller_role text; v_owner record; v_summary jsonb; v_available numeric; v_reference text;
 v_tx_id uuid:=gen_random_uuid(); v_settlement_id uuid; v_destination text; v_now timestamptz:=timezone('utc',now());
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
   RETURN jsonb_build_object('success',false,'error','Unauthorized: Admin access required');
  END IF;
 END IF;
 IF p_amount IS NULL OR p_amount<=0 THEN RETURN jsonb_build_object('success',false,'error','Invalid payout amount'); END IF;
 SELECT * INTO v_owner FROM public.users WHERE id=p_owner_id AND role IN ('owner','admin','co_founder','cofounder','super_admin') FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Owner not found'); END IF;

 IF nullif(trim(coalesce(p_reference,'')),'') IS NOT NULL THEN
  SELECT t.reference_number,t.id INTO v_reference,v_tx_id
  FROM public.transactions t
  WHERE t.type IN ('payout','payout_disbursed') AND t.reference_number=trim(p_reference) AND t.status='completed'
  LIMIT 1;
  IF FOUND THEN
   IF EXISTS(SELECT 1 FROM public.transactions t2 WHERE t2.id=v_tx_id AND t2.user_id=p_owner_id AND round(t2.amount,2)=round(p_amount,2)) THEN
    RETURN jsonb_build_object('success',true,'idempotent',true,'transaction_id',v_tx_id,'reference_number',v_reference,'amount',p_amount);
   END IF;
   RETURN jsonb_build_object('success',false,'error','Payout reference already belongs to another transaction');
  END IF;
 END IF;

 v_summary:=public.get_owner_financial_summary(p_owner_id);
 IF coalesce((v_summary->>'success')::boolean,false) IS NOT TRUE THEN
  RETURN jsonb_build_object('success',false,'error',coalesce(v_summary->>'error','Owner financial summary unavailable'));
 END IF;
 v_available:=round(coalesce((v_summary->>'available_balance')::numeric,0),2);
 IF round(p_amount,2)>v_available+0.01 THEN
  RETURN jsonb_build_object('success',false,'error','Payout exceeds authoritative owner available balance','available_balance',v_available,'requested_amount',p_amount);
 END IF;

 v_reference:=coalesce(nullif(trim(p_reference),''),'PAYOUT_'||replace(v_tx_id::text,'-',''));
 v_destination:=CASE lower(coalesce(p_payment_method,''))
  WHEN 'vodafone_cash' THEN coalesce(v_owner.p2p_vodafone,'')
  WHEN 'instapay' THEN coalesce(v_owner.p2p_instapay,'')
  WHEN 'bank_transfer' THEN coalesce(v_owner.p2p_bank,'')
  ELSE coalesce(v_owner.p2p_vodafone,v_owner.p2p_instapay,v_owner.p2p_bank,'')
 END;
 IF nullif(trim(coalesce(v_destination,'')),'') IS NULL THEN RETURN jsonb_build_object('success',false,'error','Owner payout destination is missing'); END IF;

 INSERT INTO public.transactions(id,user_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
 VALUES(v_tx_id,p_owner_id,round(p_amount,2),'payout_disbursed','completed',lower(coalesce(p_payment_method,'vodafone_cash')),v_reference,
 'تسوية أرباح مالك ملعب من إدارة VSP',jsonb_build_object('server_recorded_at',v_now,'destination',v_destination),v_now,v_now);

 INSERT INTO public.payout_settlements(owner_id,amount,method,destination,status,admin_notes,created_at,updated_at)
 VALUES(p_owner_id,round(p_amount,2),lower(coalesce(p_payment_method,'vodafone_cash')),v_destination,'completed','Ref: '||v_reference,v_now,v_now)
 RETURNING id INTO v_settlement_id;

 UPDATE public.transactions SET metadata=metadata||jsonb_build_object('settlement_id',v_settlement_id) WHERE id=v_tx_id;

 INSERT INTO public.notifications(user_id,title,body,type,created_at)
 VALUES(p_owner_id,'تم تحويل أرباحك بنجاح! 💸','تم إرسال مبلغ '||round(p_amount,2)||' ج.م عبر '||
 lower(coalesce(p_payment_method,'vodafone_cash'))||' برقم مرجع: '||v_reference,'info',v_now);

 RETURN jsonb_build_object('success',true,'idempotent',false,'transaction_id',v_tx_id,'settlement_id',v_settlement_id,'reference_number',v_reference,'amount',round(p_amount,2),'server_time',v_now);
END;$function$
;

-- Function: admin_register_owner_on_behalf
CREATE OR REPLACE FUNCTION public.admin_register_owner_on_behalf(p_email text, p_password text, p_name text, p_phone text, p_governorate text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_caller_role TEXT;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RAISE EXCEPTION 'Unauthorized: Admin access required';
        END IF;
    END IF;

    INSERT INTO auth.users (instance_id, id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud, confirmation_token)
    VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        p_email,
        crypt(p_password, gen_salt('bf')),
        NOW(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        json_build_object('name', p_name, 'role', 'owner'),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        ''
    )
    RETURNING id INTO v_user_id;

    INSERT INTO public.users (id, email, role, name, phone, governorate, is_email_verified, is_registration_complete, created_at, updated_at)
    VALUES (
        v_user_id,
        p_email,
        'owner',
        p_name,
        p_phone,
        p_governorate,
        true,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = EXCLUDED.email,
        role = EXCLUDED.role,
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        governorate = EXCLUDED.governorate,
        is_email_verified = true,
        is_registration_complete = true,
        updated_at = NOW();

    RETURN v_user_id;
END;
$function$
;

-- Function: admin_reject_1v1_registration_atomic
CREATE OR REPLACE FUNCTION public.admin_reject_1v1_registration_atomic(p_registration_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_now timestamptz:=timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  update public.vsp_1v1_registrations set status='rejected' where id=p_registration_id;
  if not found then return jsonb_build_object('success',false,'error','Registration not found'); end if;
  return jsonb_build_object('success',true,'registration_id',p_registration_id,'server_time',v_now);
end $function$
;

-- Function: admin_reject_championship_atomic
CREATE OR REPLACE FUNCTION public.admin_reject_championship_atomic(p_championship_id uuid, p_reason text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_champ RECORD;
  v_now timestamptz := NOW();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
  IF v_caller_role NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
    RAISE EXCEPTION 'Permission Denied';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  -- Set status to 'cancelled' (valid SSOT status) with is_approved = false
  UPDATE public.championships
  SET status = 'cancelled',
      is_approved = false,
      rejection_reason = nullif(trim(p_reason), ''),
      rejected_at = v_now,
      rejected_by = v_caller_id,
      updated_at = v_now
  WHERE id = p_championship_id;

  IF v_champ.owner_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, message, type, metadata, created_at)
    VALUES(
      v_champ.owner_id,
      'تم رفض نشر البطولة',
      'نأسف، تم رفض نشر بطولتك "' || COALESCE(v_champ.name, '') || '"' ||
        CASE WHEN p_reason IS NOT NULL AND TRIM(p_reason) != '' THEN '. السبب: ' || p_reason ELSE '.' END,
      'رفض بطولتك "' || COALESCE(v_champ.name, '') || '"',
      'tournament_rejection',
      jsonb_build_object('championship_id', p_championship_id, 'reason', p_reason),
      v_now
    );
  END IF;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_reject_championship',
    'championships',
    p_championship_id,
    jsonb_build_object('status', v_champ.status, 'is_approved', v_champ.is_approved),
    jsonb_build_object('status', 'cancelled', 'is_approved', false, 'rejection_reason', p_reason),
    v_caller_id,
    v_caller_role,
    v_now
  );

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', p_championship_id,
    'status', 'cancelled',
    'message', 'Championship archived with cancelled status (record preserved).',
    'server_time', v_now
  );
END;
$function$
;

-- Function: admin_reject_owner_atomic
CREATE OR REPLACE FUNCTION public.admin_reject_owner_atomic(p_owner_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_caller_id uuid:=auth.uid(); v_caller_role TEXT; v_now timestamptz:=timezone('utc',now()); BEGIN IF COALESCE(auth.role(),'')<>'service_role' THEN SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller_id; IF COALESCE(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF; END IF; IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_owner_id) THEN RETURN jsonb_build_object('success',false,'error','Owner not found'); END IF; UPDATE public.users SET verification_status='rejected',updated_at=v_now WHERE id=p_owner_id; INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(p_owner_id,'رفض طلب التوثيق','نأسف، تم رفض طلب توثيق حسابك كصاحب ملعب.'||CASE WHEN p_reason IS NOT NULL AND trim(p_reason)<>'' THEN ' السبب: '||p_reason ELSE '.' END,'verification_rejected',v_now); INSERT INTO public.system_audit_logs(action,table_name,record_id,new_data,changed_by,changed_by_role,created_at) VALUES('admin_reject_owner','users',p_owner_id,jsonb_build_object('verification_status','rejected','rejection_reason',p_reason),v_caller_id,v_caller_role,v_now); RETURN jsonb_build_object('success',true,'owner_id',p_owner_id,'server_time',v_now); END; $function$
;

-- Function: admin_reset_1v1_round_atomic
CREATE OR REPLACE FUNCTION public.admin_reset_1v1_round_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_now timestamptz:=timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  update public.vsp_1v1_registrations set status='archived';
  return jsonb_build_object('success',true,'server_time',v_now);
end $function$
;

-- Function: admin_reset_no_show_count_atomic
CREATE OR REPLACE FUNCTION public.admin_reset_no_show_count_atomic(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_now timestamptz:=timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  if not exists(select 1 from public.users where id=p_user_id) then
    return jsonb_build_object('success',false,'error','User not found');
  end if;
  update public.users set no_show_count=0, updated_at=v_now where id=p_user_id;
  return jsonb_build_object('success',true,'user_id',p_user_id,'server_time',v_now);
end $function$
;

-- Function: admin_resolve_dispute_atomic
CREATE OR REPLACE FUNCTION public.admin_resolve_dispute_atomic(p_booking_id uuid, p_final_outcome text, p_home_score integer DEFAULT NULL::integer, p_away_score integer DEFAULT NULL::integer, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking RECORD;
  v_actor_id uuid := auth.uid();
  v_actor_role TEXT;
  v_actor_is_blocked boolean;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF v_actor_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    SELECT role, coalesce(is_blocked, false) INTO v_actor_role, v_actor_is_blocked FROM public.users WHERE id = v_actor_id;
    IF v_actor_is_blocked THEN
      RETURN jsonb_build_object('success', false, 'error', 'Actor account is blocked');
    END IF;
    IF COALESCE(v_actor_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin authorization required');
    END IF;
  ELSE
    v_actor_role := 'service_role';
  END IF;

  IF p_final_outcome NOT IN ('home_win', 'away_win', 'draw', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_OUTCOME', 'message', 'النتيجة غير صالحة. المقبول: home_win, away_win, draw, cancelled');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
  END IF;

  UPDATE public.bookings
  SET status = CASE WHEN p_final_outcome = 'cancelled' THEN 'cancelled' ELSE 'completed' END,
      final_outcome = p_final_outcome,
      match_result_status = 'confirmed',
      pending_outcome = NULL,
      requires_admin_intervention = false,
      home_team_score = COALESCE(p_home_score, home_team_score),
      away_team_score = COALESCE(p_away_score, away_team_score),
      host_score = COALESCE(p_home_score, host_score),
      away_score = COALESCE(p_away_score, away_score),
      dispute_notes = COALESCE(p_notes, dispute_notes),
      cancelled_at = CASE WHEN p_final_outcome = 'cancelled' THEN v_now ELSE cancelled_at END,
      cancellation_reason = CASE WHEN p_final_outcome = 'cancelled' THEN COALESCE('ملغي بقرار فض النزاع: ' || COALESCE(p_notes, ''), 'ملغي بقرار إدارة المنظومة') ELSE cancellation_reason END,
      updated_at = v_now
  WHERE id = p_booking_id;

  IF v_booking.player_team_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, type, created_at)
    SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية: ' || p_final_outcome, 'result_confirmation', v_now
    FROM public.teams WHERE id = v_booking.player_team_id;
  END IF;

  IF v_booking.opponent_team_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, type, created_at)
    SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية: ' || p_final_outcome, 'result_confirmation', v_now
    FROM public.teams WHERE id = v_booking.opponent_team_id;
  END IF;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_resolve_dispute', 'bookings', p_booking_id,
    jsonb_build_object('status', v_booking.status, 'final_outcome', v_booking.final_outcome),
    jsonb_build_object('final_outcome', p_final_outcome, 'home_score', p_home_score, 'away_score', p_away_score, 'notes', p_notes),
    v_actor_id, v_actor_role, v_now
  );

  RETURN jsonb_build_object('success', true, 'outcome', p_final_outcome, 'server_time', v_now);
END;
$function$
;

-- Function: admin_resolve_report_atomic
CREATE OR REPLACE FUNCTION public.admin_resolve_report_atomic(p_report_id uuid, p_status text, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_caller_is_blocked boolean;
  v_now timestamptz := timezone('utc', now());
  v_report record;
  v_status text := lower(trim(coalesce(p_status, '')));
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    SELECT role, coalesce(is_blocked, false) INTO v_caller_role, v_caller_is_blocked FROM public.users WHERE id = v_caller_id;
    IF v_caller_is_blocked THEN
      RETURN jsonb_build_object('success', false, 'error', 'Actor account is blocked');
    END IF;
    IF coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Permission denied');
    END IF;
  ELSE
    v_caller_role := 'service_role';
  END IF;

  IF v_status NOT IN ('pending', 'under_review', 'resolved', 'dismissed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid report status');
  END IF;

  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Report not found');
  END IF;

  UPDATE public.reports
  SET status = v_status,
      details = CASE 
        WHEN p_notes IS NOT NULL AND trim(p_notes) <> '' 
        THEN coalesce(details, '') || E'\n[إجراء الإدارة: ' || trim(p_notes) || ']'
        ELSE details
      END
  WHERE id = p_report_id;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_resolve_report', 'reports', p_report_id,
    jsonb_build_object('status', v_report.status),
    jsonb_build_object('status', v_status, 'notes', p_notes),
    v_caller_id, v_caller_role, v_now
  );

  RETURN jsonb_build_object('success', true, 'report_id', p_report_id, 'status', v_status, 'server_time', v_now);
END;
$function$
;

-- Function: admin_save_1v1_tournament_players_atomic
CREATE OR REPLACE FUNCTION public.admin_save_1v1_tournament_players_atomic(p_tournament_id uuid, p_players jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_role text; v_tournament record; v_count integer; v_index integer:=0;
  v_player jsonb; v_player_id uuid; v_user_id uuid; v_name text;
  v_now timestamptz:=timezone('utc',now()); v_existing_id uuid;
  v_tackles integer; v_goals integer; v_skills integer; v_rounds integer;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    select role into v_role from public.users where id=auth.uid();
    if coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
      return jsonb_build_object('success',false,'error','Unauthorized');
    end if;
  end if;

  if jsonb_typeof(p_players)<>'array' then
    return jsonb_build_object('success',false,'error','players must be a JSON array');
  end if;

  select * into v_tournament from public.vsp_1v1_tournaments
  where id=p_tournament_id for update;
  if not found then
    return jsonb_build_object('success',false,'error','Tournament not found');
  end if;

  v_count:=jsonb_array_length(p_players);
  if v_count>v_tournament.target_player_count then
    return jsonb_build_object('success',false,'error','Player list exceeds tournament capacity');
  end if;

  for v_player in select value from jsonb_array_elements(p_players) loop
    v_name:=trim(coalesce(v_player->>'player_name',v_player->>'name',''));
    if nullif(v_name,'') is null then
      return jsonb_build_object('success',false,'error','Every player must have a name');
    end if;

    v_player_id:=nullif(v_player->>'id','')::uuid;
    v_user_id:=nullif(v_player->>'user_id','')::uuid;
    v_existing_id:=null;

    if v_player_id is not null then
      select id into v_existing_id from public.vsp_1v1_tournament_players
      where id=v_player_id and tournament_id=p_tournament_id;
    end if;
    if v_existing_id is null and v_user_id is not null then
      select id into v_existing_id from public.vsp_1v1_tournament_players
      where tournament_id=p_tournament_id and user_id=v_user_id;
    end if;

    v_tackles:=greatest(coalesce((v_player->>'tackles')::integer,0),0);
    v_goals:=greatest(coalesce((v_player->>'goals')::integer,0),0);
    v_skills:=greatest(coalesce((v_player->>'skills')::integer,(v_player->>'skill_points')::integer,0),0);
    v_rounds:=greatest(coalesce((v_player->>'rounds_played')::integer,0),0);

    if v_existing_id is not null then
      update public.vsp_1v1_tournament_players
      set player_name=v_name,
          avatar_url=nullif(v_player->>'avatar_url',''),
          tackles=v_tackles,
          goals=v_goals,
          skills=v_skills,
          total_points=v_skills+v_goals+v_tackles,
          rounds_played=v_rounds,
          updated_at=v_now
      where id=v_existing_id;
    else
      insert into public.vsp_1v1_tournament_players(
        tournament_id,user_id,player_name,avatar_url,tackles,goals,skills,
        total_points,rounds_played,payment_status,updated_at,registered_at
      )
      values(
        p_tournament_id,v_user_id,v_name,nullif(v_player->>'avatar_url',''),
        v_tackles,v_goals,v_skills,v_tackles+v_goals+v_skills,
        v_rounds,'unpaid',v_now,v_now
      );
    end if;
    v_index:=v_index+1;
  end loop;

  update public.vsp_1v1_tournaments set updated_at=v_now where id=p_tournament_id;
  return jsonb_build_object('success',true,'tournament_id',p_tournament_id,
    'players_saved',v_index,'server_time',v_now);
end;
$function$
;

-- Function: admin_send_broadcast_notification_atomic
CREATE OR REPLACE FUNCTION public.admin_send_broadcast_notification_atomic(p_title text, p_body text, p_target_audience text DEFAULT 'all'::text, p_type text DEFAULT 'announcement'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_actor_is_blocked boolean;
  v_now timestamptz := timezone('utc', now());
  v_count int := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF v_actor_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    SELECT role, coalesce(is_blocked, false) INTO v_actor_role, v_actor_is_blocked FROM public.users WHERE id = v_actor_id;
    IF v_actor_is_blocked THEN
      RETURN jsonb_build_object('success', false, 'error', 'Actor account is blocked');
    END IF;
    IF COALESCE(v_actor_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
  ELSE
    v_actor_role := 'service_role';
  END IF;

  IF nullif(trim(coalesce(p_title, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Notification title is required');
  END IF;
  IF nullif(trim(coalesce(p_body, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Notification body is required');
  END IF;
  IF p_target_audience NOT IN ('all', 'players', 'owners') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid target audience');
  END IF;

  INSERT INTO public.notifications(user_id, title, body, message, type, is_read, created_at)
  SELECT u.id, p_title, p_body, p_body, p_type, false, v_now
  FROM public.users u
  WHERE COALESCE(u.is_blocked, false) = false
    AND CASE
      WHEN p_target_audience = 'players' THEN u.role IN ('player') OR u.role IS NULL
      WHEN p_target_audience = 'owners' THEN u.role = 'owner'
      ELSE true
    END;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_broadcast_notification', 'notifications', v_actor_id,
    jsonb_build_object('title', p_title, 'target_audience', p_target_audience, 'sent_count', v_count),
    v_actor_id, v_actor_role, v_now
  );

  RETURN jsonb_build_object('success', true, 'sent_count', v_count, 'target_audience', p_target_audience, 'server_time', v_now);
END;
$function$
;

-- Function: admin_set_1v1_registration_open_atomic
CREATE OR REPLACE FUNCTION public.admin_set_1v1_registration_open_atomic(p_is_open boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text; v_now timestamptz := timezone('utc', now());
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;
  UPDATE public.app_config SET vsp_1v1_is_open = p_is_open, updated_at = v_now WHERE id = 1;
  IF NOT FOUND THEN
    INSERT INTO public.app_config(id,vsp_1v1_is_open,updated_at) VALUES (1,p_is_open,v_now);
  END IF;
  RETURN jsonb_build_object('success',true,'vsp_1v1_is_open',p_is_open,'server_time',v_now);
END;
$function$
;

-- Function: admin_set_admin_role_atomic
CREATE OR REPLACE FUNCTION public.admin_set_admin_role_atomic(p_user_id uuid, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_actor_is_blocked boolean;
  v_target RECORD;
  v_new_role text := lower(trim(coalesce(p_role, '')));
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF v_actor_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Caller not authenticated');
    END IF;
    SELECT role, coalesce(is_blocked, false) INTO v_actor_role, v_actor_is_blocked FROM public.users WHERE id = v_actor_id;
    IF v_actor_is_blocked THEN
      RETURN jsonb_build_object('success', false, 'error', 'Actor account is blocked');
    END IF;
    IF COALESCE(v_actor_role, '') NOT IN ('co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Only system founders may change administrative roles');
    END IF;
  ELSE
    v_actor_role := 'service_role';
  END IF;

  IF v_new_role NOT IN ('admin', 'player', 'owner') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid role: allowed roles are admin, player, owner');
  END IF;

  SELECT id, role, email INTO v_target FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_target.role IN ('co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot modify protected founder accounts');
  END IF;

  IF v_actor_id = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot change your own role');
  END IF;

  UPDATE public.users SET role = v_new_role, is_blocked = false, updated_at = v_now WHERE id = p_user_id;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_role_change', 'users', p_user_id,
    jsonb_build_object('role', v_target.role, 'email', v_target.email),
    jsonb_build_object('role', v_new_role),
    v_actor_id, v_actor_role, v_now
  );

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'new_role', v_new_role, 'server_time', v_now);
END;
$function$
;

-- Function: admin_set_maintenance_mode_atomic
CREATE OR REPLACE FUNCTION public.admin_set_maintenance_mode_atomic(p_enabled boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text; v_now timestamptz := timezone('utc', now());
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;
  UPDATE public.app_config SET is_maintenance = p_enabled, updated_at = v_now WHERE id = 1;
  IF NOT FOUND THEN
    INSERT INTO public.app_config(id,is_maintenance,updated_at) VALUES (1,p_enabled,v_now);
  END IF;
  RETURN jsonb_build_object('success',true,'is_maintenance',p_enabled,'server_time',v_now);
END;
$function$
;

-- Function: admin_set_owner_subscription_atomic
CREATE OR REPLACE FUNCTION public.admin_set_owner_subscription_atomic(p_owner_id uuid, p_plan text, p_days integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role text;
  v_current_plan text;
  v_current_expires_at timestamptz;
  v_now timestamptz := timezone('utc', now());
  v_base_time timestamptz;
  v_new_expires_at timestamptz;
  v_normalized_plan text := lower(trim(coalesce(p_plan, '')));
  v_days integer;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.users
  WHERE id = auth.uid();

  IF current_user NOT IN ('postgres','service_role')
     AND coalesce(auth.role(),'') <> 'service_role'
     AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can alter owner subscriptions';
  END IF;

  IF v_normalized_plan NOT IN ('free_trial','basic','pro') THEN
    RAISE EXCEPTION 'Invalid subscription plan';
  END IF;

  IF v_normalized_plan = 'basic' THEN
    -- Basic is permanently free (1 stadium, perpetual)
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'basic',
      'subscription_expires_at', null,
      'trial_ends_at', null,
      'server_time', v_now
    );
  ELSIF v_normalized_plan = 'free_trial' THEN
    -- Pro 7-day trial
    v_days := 7;
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        trial_ends_at = v_now + make_interval(days => v_days),
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'basic',
      'subscription_expires_at', null,
      'trial_ends_at', v_now + make_interval(days => v_days),
      'server_time', v_now,
      'catalog_trial_days', v_days
    );
  ELSE
    -- 'pro' plan requires positive days
    v_days := coalesce(p_days, 30);
    IF v_days < 1 OR v_days > 3650 THEN
      RAISE EXCEPTION 'A valid subscription duration is required for paid plans';
    END IF;

    SELECT subscription_plan, subscription_expires_at
    INTO v_current_plan, v_current_expires_at
    FROM public.users
    WHERE id = p_owner_id
    FOR UPDATE;

    v_base_time := v_now;
    IF v_current_plan = 'pro'
       AND v_current_expires_at IS NOT NULL
       AND v_current_expires_at > v_now THEN
      v_base_time := v_current_expires_at;
    END IF;

    v_new_expires_at := v_base_time + make_interval(days => v_days);

    UPDATE public.users
    SET subscription_plan = 'pro',
        subscription_expires_at = v_new_expires_at,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'pro',
      'subscription_expires_at', v_new_expires_at,
      'trial_ends_at', null,
      'server_time', v_now
    );
  END IF;
END;
$function$
;

-- Function: admin_settle_owner_cash_debt_atomic
CREATE OR REPLACE FUNCTION public.admin_settle_owner_cash_debt_atomic(p_owner_id uuid, p_amount numeric, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    SELECT role INTO v_caller_role
    FROM public.users
    WHERE id = auth.uid();

    IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Unauthorized: Admin privileges required'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'CASH_DEBT_SYSTEM_RETIRED',
    'message', 'نظام مديونية العمولات النقدية متوقف. لا توجد عمولة أو مديونية على الحجوزات النقدية.'
  );
END;
$function$
;

-- Function: admin_toggle_user_block
CREATE OR REPLACE FUNCTION public.admin_toggle_user_block(p_user_id uuid, p_is_blocked boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_admin_id UUID:=auth.uid(); v_admin_role TEXT; v_target RECORD; BEGIN SELECT role INTO v_admin_role FROM public.users WHERE id=v_admin_id; IF COALESCE(auth.role(),'')<>'service_role' AND COALESCE(v_admin_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','UNAUTHORIZED'); END IF; SELECT id,role,is_blocked,email INTO v_target FROM public.users WHERE id=p_user_id; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','USER_NOT_FOUND'); END IF; IF v_target.role=ANY(ARRAY['co_founder','cofounder','super_admin']) THEN RETURN jsonb_build_object('success',false,'error','CANNOT_BLOCK_PROTECTED_ACCOUNT'); END IF; IF v_admin_id=p_user_id THEN RETURN jsonb_build_object('success',false,'error','CANNOT_BLOCK_SELF'); END IF; IF v_target.role='admin' AND COALESCE(v_admin_role,'') NOT IN ('co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','CANNOT_BLOCK_ADMIN'); END IF; UPDATE public.users SET is_blocked=p_is_blocked,updated_at=NOW() WHERE id=p_user_id; INSERT INTO public.system_audit_logs(action,table_name,record_id,old_data,new_data,changed_by,changed_by_role,created_at) VALUES(CASE WHEN p_is_blocked THEN 'admin_block_user' ELSE 'admin_unblock_user' END,'users',p_user_id,jsonb_build_object('is_blocked',v_target.is_blocked,'email',v_target.email),jsonb_build_object('is_blocked',p_is_blocked),v_admin_id,v_admin_role,NOW()); RETURN jsonb_build_object('success',true,'user_id',p_user_id,'is_blocked',p_is_blocked,'server_time',NOW()); END; $function$
;

-- Function: admin_update_1v1_player_stats_atomic
CREATE OR REPLACE FUNCTION public.admin_update_1v1_player_stats_atomic(p_player_id uuid, p_total_points integer, p_skill_points integer, p_goals integer, p_tackles integer, p_titles integer, p_trend text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_now timestamptz:=timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  update public.vsp_1vs1_players
  set total_points=greatest(0,p_total_points),skill_points=greatest(0,p_skill_points),
      goals=greatest(0,p_goals),tackles=greatest(0,p_tackles),titles=greatest(0,p_titles),
      trend=coalesce(nullif(trim(p_trend),''),'stable'),updated_at=v_now
  where id=p_player_id;
  if not found then return jsonb_build_object('success',false,'error','Player not found'); end if;
  return jsonb_build_object('success',true,'player_id',p_player_id,'server_time',v_now);
end $function$
;

-- Function: admin_update_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.admin_update_1v1_tournament_atomic(p_tournament_id uuid, p_name text DEFAULT NULL::text, p_target_player_count integer DEFAULT NULL::integer, p_entry_fee numeric DEFAULT NULL::numeric, p_scheduled_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_governorate text DEFAULT NULL::text, p_prize_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role TEXT;
  v_status TEXT;
  v_players_count INTEGER;
  v_paid_players INTEGER;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_name TEXT;
  v_target INTEGER;
  v_fee NUMERIC;
  v_prize NUMERIC;
  v_governorate TEXT;
BEGIN
  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF COALESCE(auth.role(),'') <> 'service_role'
     AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RETURN jsonb_build_object('success',false,'error','Unauthorized');
  END IF;

  SELECT status INTO v_status
  FROM public.vsp_1v1_tournaments
  WHERE id = p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Tournament not found');
  END IF;

  IF v_status IN ('completed','published','archived','cancelled') THEN
    RETURN jsonb_build_object('success',false,'error','لا يمكن تعديل بطولة نهائية أو ملغاة.');
  END IF;

  SELECT count(*), count(*) FILTER (WHERE COALESCE(payment_status,'') = 'paid')
  INTO v_players_count, v_paid_players
  FROM public.vsp_1v1_tournament_players
  WHERE tournament_id = p_tournament_id;

  v_name := NULLIF(TRIM(COALESCE(p_name,'')), '');
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','اسم البطولة مطلوب.');
  END IF;

  v_target := COALESCE(p_target_player_count,
    (SELECT target_player_count FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id));
  v_fee := COALESCE(p_entry_fee,
    (SELECT entry_fee FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id));
  v_prize := COALESCE(p_prize_amount,
    (SELECT prize_amount FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id),
    (SELECT prize_pool FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id),
    0);
  v_governorate := NULLIF(TRIM(COALESCE(p_governorate,'')), '');

  IF v_target < 2 THEN
    RETURN jsonb_build_object('success',false,'error','عدد اللاعبين يجب أن يكون 2 على الأقل.');
  END IF;
  IF v_fee < 0 THEN
    RETURN jsonb_build_object('success',false,'error','رسوم الاشتراك لا يمكن أن تكون سالبة.');
  END IF;
  IF v_prize < 0 THEN
    RETURN jsonb_build_object('success',false,'error','قيمة الجائزة لا يمكن أن تكون سالبة.');
  END IF;
  IF v_target < v_paid_players THEN
    RETURN jsonb_build_object('success',false,'error','لا يمكن تقليل عدد المقاعد عن عدد اللاعبين المسددين بالفعل.');
  END IF;

  IF v_players_count > 0 AND (
    p_target_player_count IS NOT NULL
    OR p_entry_fee IS NOT NULL
    OR p_governorate IS NOT NULL
  ) THEN
    RETURN jsonb_build_object(
      'success',false,
      'error','بعد تسجيل لاعبين في البطولة، يمكن تعديل الاسم والموعد وقيمة الجائزة فقط لحماية التسجيلات والمدفوعات.'
    );
  END IF;

  UPDATE public.vsp_1v1_tournaments
  SET name = v_name,
      target_player_count = v_target,
      entry_fee = v_fee,
      prize_amount = v_prize,
      scheduled_at = p_scheduled_at,
      governorate = COALESCE(v_governorate, governorate),
      updated_at = v_now
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success',true,
    'tournament_id',p_tournament_id,
    'prize_amount',v_prize,
    'server_time',v_now
  );
END;
$function$
;

-- Function: admin_update_1v1_tournament_status
CREATE OR REPLACE FUNCTION public.admin_update_1v1_tournament_status(p_tournament_id uuid, p_new_status text, p_admin_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid UUID;
  v_caller_role TEXT;
  v_current_status TEXT;
  v_allowed_transitions JSONB := '{
    "draft": ["registration_open"],
    "registration_open": ["in_progress", "draft"],
    "in_progress": ["completed"],
    "completed": ["published"],
    "published": ["archived"]
  }';
BEGIN
  -- Verify caller role: internal service_role/postgres OR authenticated admin/co_founder/super_admin
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'يجب تسجيل الدخول لتنفيذ هذه العملية.';
    END IF;

    SELECT role INTO v_caller_role 
    FROM public.users 
    WHERE id = v_uid;

    IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')) THEN
      RAISE EXCEPTION 'غير مصرح: هذه العملية مخصصة لمديري النظام فقط.';
    END IF;
  END IF;

  -- Lock the row to prevent race conditions
  SELECT status INTO v_current_status
  FROM public.vsp_1v1_tournaments
  WHERE id = p_tournament_id
  FOR UPDATE;

  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'البطولة غير موجودة.';
  END IF;

  -- Idempotency check
  IF v_current_status = p_new_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'old_status', v_current_status,
      'new_status', p_new_status,
      'message', 'البطولة بالفعل في هذه الحالة.'
    );
  END IF;

  -- Validate status transition
  IF NOT (v_allowed_transitions->v_current_status) @> to_jsonb(p_new_status) THEN
    RAISE EXCEPTION 'تحويل غير مسموح لحالة البطولة: من % إلى %', v_current_status, p_new_status;
  END IF;

  UPDATE public.vsp_1v1_tournaments
  SET status = p_new_status,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true,
    'old_status', v_current_status,
    'new_status', p_new_status
  );
END;
$function$
;

-- Function: admin_update_1v1_tournament_status_atomic
CREATE OR REPLACE FUNCTION public.admin_update_1v1_tournament_status_atomic(p_tournament_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_status text := lower(trim(coalesce(p_status,'')));
  v_current text;
  v_now timestamptz := timezone('utc',now());
BEGIN
  SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
  IF coalesce(auth.role(),'')<>'service_role'
     AND coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RETURN jsonb_build_object('success',false,'error','Unauthorized');
  END IF;

  IF v_status NOT IN ('draft','registration_open','in_progress','cancelled') THEN
    RETURN jsonb_build_object('success',false,'error','Use the dedicated finalization flow to complete/publish a tournament.');
  END IF;

  SELECT status INTO v_current
  FROM public.vsp_1v1_tournaments
  WHERE id=p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Tournament not found');
  END IF;

  IF v_current IN ('completed','published','archived') THEN
    RETURN jsonb_build_object('success',false,'error','A finalized tournament cannot be reopened or rewritten.');
  END IF;

  UPDATE public.vsp_1v1_tournaments
  SET status=v_status,updated_at=v_now
  WHERE id=p_tournament_id;

  RETURN jsonb_build_object('success',true,'tournament_id',p_tournament_id,'status',v_status,'server_time',v_now);
END;
$function$
;

-- Function: admin_update_booking_safe_atomic
CREATE OR REPLACE FUNCTION public.admin_update_booking_safe_atomic(p_booking_id uuid, p_updates jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_role text; v_actor_id uuid:=auth.uid(); b record; v_now timestamptz:=now(); v_np numeric; v_nd numeric; v_ns timestamptz; v_ne timestamptz; BEGIN SELECT role INTO v_role FROM public.users WHERE id=v_actor_id; IF auth.role()<>'service_role' AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF; SELECT * INTO b FROM public.bookings WHERE id=p_booking_id FOR UPDATE; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Booking not found'); END IF; IF p_updates IS NULL THEN RETURN jsonb_build_object('success',false,'error','No updates supplied'); END IF; v_np:=CASE WHEN p_updates?'total_price' THEN GREATEST(0,(p_updates->>'total_price')::numeric) ELSE b.total_price END; v_nd:=CASE WHEN p_updates?'deposit_paid' THEN GREATEST(0,(p_updates->>'deposit_paid')::numeric) ELSE b.deposit_paid END; v_ns:=CASE WHEN p_updates?'start_time' AND (p_updates->>'start_time') IS NOT NULL THEN (p_updates->>'start_time')::timestamptz ELSE b.start_time END; v_ne:=CASE WHEN p_updates?'end_time' AND (p_updates->>'end_time') IS NOT NULL THEN (p_updates->>'end_time')::timestamptz WHEN p_updates?'start_time' THEN (p_updates->>'start_time')::timestamptz+(b.end_time-b.start_time) ELSE b.end_time END; IF v_nd>v_np THEN RETURN jsonb_build_object('success',false,'error','deposit_exceeds_price','message','العربون لا يمكن أن يتجاوز السعر الإجمالي'); END IF; IF v_ne<=v_ns THEN RETURN jsonb_build_object('success',false,'error','invalid_time_range','message','وقت النهاية يجب أن يكون بعد وقت البداية'); END IF; PERFORM set_config('vsp.system_override','true',true); UPDATE public.bookings SET player_team_name=CASE WHEN p_updates?'player_team_name' THEN p_updates->>'player_team_name' ELSE player_team_name END,opponent_team_name=CASE WHEN p_updates?'opponent_team_name' THEN p_updates->>'opponent_team_name' ELSE opponent_team_name END,current_players=CASE WHEN p_updates?'current_players' THEN GREATEST(0,(p_updates->>'current_players')::integer) ELSE current_players END,is_private=CASE WHEN p_updates?'is_private' THEN (p_updates->>'is_private')::boolean ELSE is_private END,rent_ball=CASE WHEN p_updates?'rent_ball' THEN (p_updates->>'rent_ball')::boolean ELSE rent_ball END,player_phone=CASE WHEN p_updates?'player_phone' THEN nullif(trim(p_updates->>'player_phone'),'') ELSE player_phone END,notes=CASE WHEN p_updates?'notes' THEN p_updates->>'notes' ELSE notes END,home_score=CASE WHEN p_updates?'home_score' THEN (p_updates->>'home_score')::integer ELSE home_score END,away_score=CASE WHEN p_updates?'away_score' THEN (p_updates->>'away_score')::integer ELSE away_score END,total_price=v_np,deposit_paid=v_nd,start_time=v_ns,end_time=v_ne,updated_at=v_now WHERE id=p_booking_id; PERFORM set_config('vsp.system_override','',true); INSERT INTO public.system_audit_logs(action,table_name,record_id,old_data,new_data,changed_by,changed_by_role,created_at) VALUES('admin_update_booking','bookings',p_booking_id,jsonb_build_object('total_price',b.total_price,'deposit_paid',b.deposit_paid,'start_time',b.start_time),p_updates,v_actor_id,v_role,v_now); SELECT * INTO b FROM public.bookings WHERE id=p_booking_id; RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'booking',to_jsonb(b),'server_time',v_now); EXCEPTION WHEN others THEN PERFORM set_config('vsp.system_override','',true); RETURN jsonb_build_object('success',false,'error','BOOKING_UPDATE_FAILED','message',sqlerrm); END; $function$
;

-- Function: admin_update_championship_status_atomic
CREATE OR REPLACE FUNCTION public.admin_update_championship_status_atomic(p_championship_id uuid, p_status text DEFAULT NULL::text, p_new_status text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_role text;
  v_now timestamptz := timezone('utc', now());
  v_effective_status text := lower(trim(coalesce(p_new_status, p_status, '')));
  v_champ record;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    SELECT role INTO v_role FROM public.users WHERE id = v_caller_id;
    IF coalesce(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Permission denied');
    END IF;
  ELSE
    v_role := 'service_role';
  END IF;

  -- Strictly enforce SSOT: open, ongoing, completed, cancelled
  IF v_effective_status NOT IN ('open', 'ongoing', 'completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid championship status: ' || v_effective_status);
  END IF;

  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
  END IF;

  -- Protect terminal states
  IF v_champ.status = 'cancelled' AND v_effective_status <> 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transition out of cancelled status');
  END IF;

  IF v_champ.status = 'completed' AND v_effective_status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transition out of completed status');
  END IF;

  -- If status is identical, return success directly
  IF v_champ.status = v_effective_status THEN
    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'status', v_effective_status, 'message', 'Already in requested status');
  END IF;

  -- If cancelling, invoke cancel_championship_atomic logic to ensure refunds queue if any
  IF v_effective_status = 'cancelled' THEN
    RETURN public.cancel_championship_atomic(p_championship_id);
  END IF;

  -- Apply status transition
  UPDATE public.championships
  SET status = v_effective_status,
      is_approved = CASE WHEN v_effective_status IN ('open', 'ongoing', 'completed') THEN true ELSE is_approved END,
      updated_at = v_now
  WHERE id = p_championship_id;

  -- Audit log
  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_update_championship_status',
    'championships',
    p_championship_id,
    jsonb_build_object('status', v_champ.status, 'is_approved', v_champ.is_approved),
    jsonb_build_object('status', v_effective_status),
    v_caller_id,
    v_role,
    v_now
  );

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', p_championship_id,
    'previous_status', v_champ.status,
    'status', v_effective_status,
    'server_time', v_now
  );
END;
$function$
;

-- Function: admin_update_support_ticket_atomic
CREATE OR REPLACE FUNCTION public.admin_update_support_ticket_atomic(p_ticket_id uuid, p_status text DEFAULT NULL::text, p_priority text DEFAULT NULL::text, p_assigned_to uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ticket public.support_tickets%rowtype;
  v_status text := lower(trim(coalesce(p_status,'')));
  v_priority text := lower(trim(coalesce(p_priority,'')));
BEGIN
  IF NOT public.vsp_is_admin_actor() THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id=p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;

  IF v_status='' THEN v_status:=v_ticket.status; END IF;
  IF v_priority='' THEN v_priority:=v_ticket.priority; END IF;
  IF v_status NOT IN ('open','in_progress','waiting_user','resolved','closed') THEN RAISE EXCEPTION 'INVALID_TICKET_STATUS'; END IF;
  IF v_priority NOT IN ('low','normal','high','urgent') THEN RAISE EXCEPTION 'INVALID_TICKET_PRIORITY'; END IF;

  UPDATE public.support_tickets
  SET status=v_status,
      priority=v_priority,
      assigned_to=coalesce(p_assigned_to,assigned_to),
      resolved_at=CASE WHEN v_status IN ('resolved','closed') THEN timezone('utc',now()) ELSE NULL END,
      updated_at=timezone('utc',now())
  WHERE id=p_ticket_id
  RETURNING * INTO v_ticket;

  RETURN to_jsonb(v_ticket);
END;
$function$
;

-- Function: admin_upgrade_owner_subscription_atomic
CREATE OR REPLACE FUNCTION public.admin_upgrade_owner_subscription_atomic(p_owner_id uuid, p_plan text, p_days integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;
  RETURN public.admin_set_owner_subscription_atomic(p_owner_id,p_plan,p_days);
END;
$function$
;

-- Function: admin_wipe_1v1_data_atomic
CREATE OR REPLACE FUNCTION public.admin_wipe_1v1_data_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text;
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  delete from public.vsp_1vs1_players;
  delete from public.vsp_1v1_registrations;
  return jsonb_build_object('success',true);
end $function$
;

-- Function: advance_groups_to_knockout_atomic
CREATE OR REPLACE FUNCTION public.advance_groups_to_knockout_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_num_groups INTEGER;
  v_qualifiers INTEGER;
  v_pending INTEGER;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_group_idx INTEGER;
  v_group_name TEXT;
  v_group_rows JSONB;
  v_row RECORD;
  v_qualified UUID[] := '{}'::uuid[];
  v_qualified_names TEXT[] := '{}'::text[];
  v_total INTEGER;
  v_capacity INTEGER := 2;
  v_rounds INTEGER;
  v_start_round INTEGER;
  v_r INTEGER;
  v_m INTEGER;
  v_match_counts INTEGER;
  v_match_index INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_match_id UUID;
  v_next_id UUID;
BEGIN
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
  IF v_user_id IS NULL OR (v_champ.owner_id IS DISTINCT FROM v_user_id AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF v_champ.type <> 'groups' OR v_champ.template_type = 'team_league' THEN
    RETURN jsonb_build_object('success', false, 'error', 'wrong_tournament_format');
  END IF;

  SELECT count(*) INTO v_pending
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id
    AND stage = 'group_stage'
    AND COALESCE(is_completed, false) = false;

  IF v_pending > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'group_stage_not_completed', 'pending_matches', v_pending);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tournament_matches
    WHERE championship_id = p_championship_id
      AND stage = 'knockout'
  ) THEN
    RETURN jsonb_build_object('success', true, 'already_generated', true);
  END IF;

  v_num_groups := GREATEST(2, LEAST(COALESCE(v_champ.number_of_groups, 2), 8));
  v_qualifiers := GREATEST(1, LEAST(COALESCE(v_champ.qualifying_per_group, 2), 2));

  -- Preserve the existing Dart cross-group seeding:
  -- [A1,B2,B1,A2,C1,D2,D1,C2,...]
  FOR v_group_idx IN 0..(v_num_groups - 1) LOOP
    v_group_name := chr(65 + v_group_idx);
    IF v_group_idx % 2 = 0 AND v_group_idx + 1 < v_num_groups THEN
      FOR v_row IN
        SELECT team_id, team_name
        FROM public.get_championship_standings(p_championship_id, v_group_name)
        LIMIT v_qualifiers
      LOOP
        -- Temporarily stage rows below using ordered arrays.
        NULL;
      END LOOP;
    END IF;
  END LOOP;

  -- Build qualifier order explicitly from each pair of groups.
  FOR v_group_idx IN 0..(v_num_groups - 1) BY 2 LOOP
    IF v_group_idx + 1 < v_num_groups THEN
      -- A1 / B2
      SELECT team_id, team_name INTO v_row
      FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx))
      LIMIT 1;
      IF v_row.team_id IS NOT NULL THEN
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END IF;

      SELECT team_id, team_name INTO v_row
      FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx + 1))
      LIMIT v_qualifiers OFFSET 1;
      IF v_qualifiers > 1 AND v_row.team_id IS NOT NULL THEN
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END IF;

      -- B1 / A2
      SELECT team_id, team_name INTO v_row
      FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx + 1))
      LIMIT 1;
      IF v_row.team_id IS NOT NULL THEN
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END IF;

      SELECT team_id, team_name INTO v_row
      FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx))
      LIMIT v_qualifiers OFFSET 1;
      IF v_qualifiers > 1 AND v_row.team_id IS NOT NULL THEN
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END IF;
    ELSE
      FOR v_row IN
        SELECT team_id, team_name
        FROM public.get_championship_standings(p_championship_id, chr(65 + v_group_idx))
        LIMIT v_qualifiers
      LOOP
        v_qualified := array_append(v_qualified, v_row.team_id);
        v_qualified_names := array_append(v_qualified_names, v_row.team_name);
      END LOOP;
    END IF;
  END LOOP;

  v_total := COALESCE(array_length(v_qualified,1),0);
  IF v_total < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_qualified_teams');
  END IF;

  WHILE v_capacity < v_total LOOP
    v_capacity := v_capacity * 2;
  END LOOP;

  v_rounds := floor(log(v_capacity::numeric) / log(2::numeric))::integer;
  v_start_round := v_rounds - 1;

  -- Build all knockout rows in a temp table so next_match_id references exist.
  CREATE TEMP TABLE tmp_group_knockout (
    round_index integer,
    match_index integer,
    match_id uuid default gen_random_uuid(),
    next_match_id uuid,
    home_team_id uuid,
    home_team_name text,
    away_team_id uuid,
    away_team_name text,
    winner_id uuid,
    home_score integer,
    away_score integer,
    status text default 'scheduled',
    is_completed boolean default false
  ) ON COMMIT DROP;

  FOR v_r IN REVERSE v_start_round..0 LOOP
    v_match_counts := (1 << v_r);
    FOR v_m IN 0..(v_match_counts - 1) LOOP
      INSERT INTO tmp_group_knockout(round_index, match_index)
      VALUES (v_r, v_m);
    END LOOP;
  END LOOP;

  UPDATE tmp_group_knockout child
  SET next_match_id = parent.match_id
  FROM tmp_group_knockout parent
  WHERE child.round_index > 0
    AND parent.round_index = child.round_index - 1
    AND parent.match_index = child.match_index / 2;

  FOR v_m IN 0..((1 << v_start_round) - 1) LOOP
    v_home_id := CASE WHEN v_m * 2 + 1 <= v_total THEN v_qualified[v_m * 2 + 1] ELSE NULL END;
    v_away_id := CASE WHEN v_m * 2 + 2 <= v_total THEN v_qualified[v_m * 2 + 2] ELSE NULL END;
    v_home_name := CASE WHEN v_m * 2 + 1 <= v_total THEN v_qualified_names[v_m * 2 + 1] ELSE NULL END;
    v_away_name := CASE WHEN v_m * 2 + 2 <= v_total THEN v_qualified_names[v_m * 2 + 2] ELSE NULL END;

    UPDATE tmp_group_knockout
    SET home_team_id = v_home_id,
        home_team_name = v_home_name,
        away_team_id = v_away_id,
        away_team_name = v_away_name,
        winner_id = CASE
          WHEN v_home_id IS NOT NULL AND v_away_id IS NULL THEN v_home_id
          WHEN v_home_id IS NULL AND v_away_id IS NOT NULL THEN v_away_id
          ELSE NULL
        END,
        home_score = CASE WHEN (v_home_id IS NOT NULL) <> (v_away_id IS NOT NULL) THEN 0 ELSE NULL END,
        away_score = CASE WHEN (v_home_id IS NOT NULL) <> (v_away_id IS NOT NULL) THEN 0 ELSE NULL END,
        status = CASE WHEN (v_home_id IS NULL) <> (v_away_id IS NULL) THEN 'completed' ELSE 'scheduled' END,
        is_completed = ((v_home_id IS NULL) <> (v_away_id IS NULL))
    WHERE round_index = v_start_round
      AND match_index = v_m;

    IF v_home_id IS NOT NULL AND v_away_id IS NULL AND v_start_round > 0 THEN
      UPDATE tmp_group_knockout
      SET home_team_id = v_home_id, home_team_name = v_home_name
      WHERE round_index = v_start_round - 1 AND match_index = v_m / 2 AND v_m % 2 = 0;
      UPDATE tmp_group_knockout
      SET away_team_id = v_home_id, away_team_name = v_home_name
      WHERE round_index = v_start_round - 1 AND match_index = v_m / 2 AND v_m % 2 = 1;
    ELSIF v_home_id IS NULL AND v_away_id IS NOT NULL AND v_start_round > 0 THEN
      UPDATE tmp_group_knockout
      SET home_team_id = v_away_id, home_team_name = v_away_name
      WHERE round_index = v_start_round - 1 AND match_index = v_m / 2 AND v_m % 2 = 0;
      UPDATE tmp_group_knockout
      SET away_team_id = v_away_id, away_team_name = v_away_name
      WHERE round_index = v_start_round - 1 AND match_index = v_m / 2 AND v_m % 2 = 1;
    END IF;
  END LOOP;

  INSERT INTO public.tournament_matches (
    id, championship_id, round_index, match_index, next_match_id,
    home_team_id, home_team_name, away_team_id, away_team_name,
    home_score, away_score, winner_id, status, is_completed,
    stage, created_at, updated_at
  )
  SELECT
    match_id, p_championship_id, round_index, match_index, next_match_id,
    home_team_id, home_team_name, away_team_id, away_team_name,
    home_score, away_score, winner_id, status, is_completed,
    'knockout', v_now, v_now
  FROM tmp_group_knockout
  ORDER BY round_index ASC;

  UPDATE public.championships
  SET updated_at = v_now
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'format', 'groups_to_knockout',
    'qualified_teams', v_total,
    'matches_count', (SELECT count(*) FROM public.tournament_matches WHERE championship_id = p_championship_id AND stage = 'knockout')
  );
END;
$function$
;

-- Function: apply_no_show_penalty
CREATE OR REPLACE FUNCTION public.apply_no_show_penalty(p_player_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only administrators or authorized system services can apply penalties directly.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.users
  SET no_show_count = COALESCE(no_show_count, 0) + 1,
      cash_booking_banned = CASE 
          WHEN COALESCE(no_show_count, 0) + 1 >= 2 THEN true 
          ELSE false 
      END
  WHERE id = p_player_id;
END;
$function$
;

-- Function: approve_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.approve_payout_settlement_atomic(p_settlement_id uuid, p_admin_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE 
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_settlement      record; 
  v_now             timestamptz := timezone('utc', now()); 
  v_tx_id           uuid;
BEGIN
  -- Strict Admin Authorization Check
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF NOT public.is_admin_or_cofounder(v_caller_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_ADMIN_REQUIRED');
    END IF;
  END IF;

  SELECT * INTO v_settlement FROM public.payout_settlements WHERE id = p_settlement_id FOR UPDATE;
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found'); 
  END IF;

  IF v_settlement.status = 'completed' THEN 
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'settlement_id', p_settlement_id, 'amount', v_settlement.amount); 
  END IF;

  IF v_settlement.status NOT IN ('pending', 'approved') THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Settlement is not payable in its current state'); 
  END IF;

  UPDATE public.payout_settlements 
  SET status = 'completed', 
      admin_notes = COALESCE(p_admin_notes, admin_notes), 
      updated_at = v_now 
  WHERE id = p_settlement_id;

  SELECT id INTO v_tx_id FROM public.transactions 
  WHERE type = 'payout_pending' AND status = 'pending' AND (metadata->>'settlement_id') = p_settlement_id::text 
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF v_tx_id IS NOT NULL THEN
    UPDATE public.transactions 
    SET type = 'payout_disbursed', 
        status = 'completed', 
        description = 'صرف أرباح مالك ملعب بعد اعتماد الإدارة',
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('approved_by', v_caller_id, 'approved_at', v_now, 'admin_notes', p_admin_notes), 
        updated_at = v_now 
    WHERE id = v_tx_id;
  ELSE
    SELECT id INTO v_tx_id FROM public.transactions 
    WHERE type = 'payout_disbursed' AND status = 'completed' AND (metadata->>'settlement_id') = p_settlement_id::text 
    LIMIT 1;

    IF v_tx_id IS NULL THEN
      INSERT INTO public.transactions(user_id, amount, type, status, payment_method, reference_number, metadata, created_at, updated_at)
      VALUES(v_settlement.owner_id, v_settlement.amount, 'payout_disbursed', 'completed', v_settlement.method, 'SETTLEMENT_' || replace(p_settlement_id::text, '-', ''),
        jsonb_build_object('settlement_id', p_settlement_id, 'destination', v_settlement.destination, 'approved_by', v_caller_id, 'approved_at', v_now, 'admin_notes', p_admin_notes), v_now, v_now) 
      RETURNING id INTO v_tx_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'settlement_id', p_settlement_id, 'transaction_id', v_tx_id, 'amount', v_settlement.amount);
END;$function$
;

-- Function: are_users_blocked
CREATE OR REPLACE FUNCTION public.are_users_blocked(p_user_a uuid, p_user_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1 from public.user_blocks ub
    where (ub.blocker_id=p_user_a and ub.blocked_user_id=p_user_b)
       or (ub.blocker_id=p_user_b and ub.blocked_user_id=p_user_a)
  )
  and auth.uid() is not null
  and (auth.uid()=p_user_a or auth.uid()=p_user_b);
$function$
;

-- Function: auto_approve_tournament_matches_24h
CREATE OR REPLACE FUNCTION public.auto_approve_tournament_matches_24h()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'tournament_matches' 
      AND column_name = 'submitted_at'
  ) THEN
    UPDATE public.tournament_matches
    SET 
      status = 'approved',
      updated_at = NOW()
    WHERE 
      status = 'pending_confirmation'
      AND submitted_at <= NOW() - INTERVAL '24 hours';
  END IF;
END;
$function$
;

-- Function: auto_downgrade_expired_subscriptions
CREATE OR REPLACE FUNCTION public.auto_downgrade_expired_subscriptions()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Unfeature stadiums for owners whose Pro subscription or trial has expired
  UPDATE public.stadiums s
  SET is_featured = FALSE,
      updated_at = NOW()
  FROM public.users u
  WHERE s.owner_id = u.id
    AND s.is_featured = TRUE
    AND (
      (u.subscription_plan = 'pro' AND (u.subscription_expires_at IS NULL OR u.subscription_expires_at <= NOW()))
      AND (u.trial_ends_at IS NULL OR u.trial_ends_at <= NOW())
    );

  -- Downgrade expired Pro users to Basic Free
  UPDATE public.users
  SET subscription_plan = 'basic',
      trial_ends_at = NULL,
      subscription_expires_at = NULL,
      updated_at = NOW()
  WHERE role = 'owner'
    AND subscription_plan = 'pro'
    AND (subscription_expires_at IS NULL OR subscription_expires_at <= NOW())
    AND (trial_ends_at IS NULL OR trial_ends_at <= NOW());
END;
$function$
;

-- Function: auto_expire_matchups
CREATE OR REPLACE FUNCTION public.auto_expire_matchups()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_closed_count INT := 0;
BEGIN
    UPDATE public.bookings
    SET matchup_closed_at = timezone('utc'::text, now())
    WHERE matchup_mode IS NOT NULL 
      AND matchup_closed_at IS NULL
      AND (end_time + INTERVAL '48 hours') < timezone('utc'::text, now());
      
    GET DIAGNOSTICS v_closed_count = ROW_COUNT;
    RETURN v_closed_count;
END;
$function$
;

-- Function: auto_expire_pending_1v1_orders
CREATE OR REPLACE FUNCTION public.auto_expire_pending_1v1_orders()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count INT := 0;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    RAISE EXCEPTION 'غير مصرح: هذه العملية مخصصة للسيرفر فقط.';
  END IF;

  UPDATE public.vsp_1v1_tournament_orders
  SET payment_status = 'expired',
      updated_at = timezone('utc'::text, now())
  WHERE payment_status = 'pending'
    AND expires_at < timezone('utc'::text, now())
    AND expires_at IS NOT NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'expired_count', v_count);
END;
$function$
;

-- Function: auto_expire_pending_challenges
CREATE OR REPLACE FUNCTION public.auto_expire_pending_challenges()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.bookings
  SET status = 'cancelled',
      cancellation_reason = 'payment_timeout',
      updated_at = timezone('utc', now())
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND locked_until IS NOT NULL
    AND locked_until < timezone('utc', now());
END;
$function$
;

-- Function: auto_expire_pending_locks
CREATE OR REPLACE FUNCTION public.auto_expire_pending_locks()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_expired_count INT;
BEGIN
    WITH updated AS (
        UPDATE public.bookings
        SET status = 'cancelled',
            cancellation_reason = 'Payment session expired (8 minutes limit)',
            updated_at = NOW()
        WHERE status = 'pending'
          AND COALESCE(locked_until, created_at + INTERVAL '8 minutes') < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO v_expired_count FROM updated;

    RETURN v_expired_count;
END;
$function$
;

-- Function: auto_expire_stale_records
CREATE OR REPLACE FUNCTION public.auto_expire_stale_records()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Stage 0: self-healing. A booking that was actually PAID but stayed stuck at 'pending'
  UPDATE public.bookings
  SET
    status = 'confirmed',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'confirmed' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-promoted to confirmed - payment succeeded but status was stuck at pending]'
  WHERE status = 'pending'
    AND (is_paid = TRUE OR payment_status IN ('paid', 'fully_paid', 'completed'))
    AND created_at <= NOW() - INTERVAL '2 minutes';

  -- Stage 1: expire bookings whose temporary payment lock elapsed
  UPDATE public.bookings
  SET
    status = 'expired',
    payment_status = 'unpaid',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'expired' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired - payment window elapsed]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'fully_paid', 'completed')
    AND locked_until IS NOT NULL
    AND locked_until < NOW();

  -- Stage 2: safety net - expire any unpaid pending older than 10 minutes
  UPDATE public.bookings
  SET
    status = 'expired',
    payment_status = 'unpaid',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'expired' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to payment timeout]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'fully_paid', 'completed')
    AND created_at <= NOW() - INTERVAL '10 minutes';

  -- Stage 3: expire stale challenge pending reservations
  UPDATE public.bookings
  SET
    status = 'expired',
    payment_status = 'unpaid',
    challenge_status = 'expired',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Challenge expired automatically]'
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND (
      NOW() - created_at >= INTERVAL '4 hours' OR
      start_time - NOW() <= INTERVAL '12 hours'
    );

  -- Stage 4: Expire stale team challenge codes (Automated 7-day lifecycle worker)
  UPDATE public.team_challenge_codes
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at IS NOT NULL
    AND expires_at < timezone('utc', now());
END;
$function$
;

-- Function: auto_nudge_post_match_results
CREATE OR REPLACE FUNCTION public.auto_nudge_post_match_results()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_count integer := 0;
  r record;
begin
  for r in
    select b.id, b.created_by_user_id
    from public.bookings b
    where b.booking_type = 'challenge'
      and b.match_result_status = 'noResult'
      and b.status = 'confirmed'
      and b.end_time <= now() - interval '1 hour'
      and coalesce(b.notes,'') not like '%[NUDGED]%'
  loop
    insert into public.notifications(user_id,title,body,type,booking_id,created_at,is_read)
    values(
      r.created_by_user_id,
      'تسجيل نتيجة المباراة',
      'انتهت المباراة! سجّل النتيجة لضمان تحديث نقاط الفريق وسجل المباريات.',
      'action_required',
      r.id,
      now(),
      false
    );

    update public.bookings
    set notes = case
      when coalesce(notes,'') = '' then '[NUDGED]'
      else notes || ' [NUDGED]'
    end,
    updated_at = now()
    where id = r.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$
;

-- Function: auto_reconcile_all_past_bookings
CREATE OR REPLACE FUNCTION public.auto_reconcile_all_past_bookings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.bookings
  SET status = 'completed',
      updated_at = NOW()
  WHERE end_time < NOW()
    AND status = 'confirmed'
    AND is_verified_by_owner IS TRUE
    AND COALESCE(booking_type, 'personal') NOT IN ('challenge','matchup','team');
END;
$function$
;

-- Function: auto_reconcile_past_bookings
CREATE OR REPLACE FUNCTION public.auto_reconcile_past_bookings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.bookings
  SET
    status = 'completed',
    updated_at = NOW()
  WHERE
    end_time < NOW()
    AND status = 'confirmed';
END;
$function$
;

-- Function: auto_reconcile_single_entry_results
CREATE OR REPLACE FUNCTION public.auto_reconcile_single_entry_results()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Challenge results are mutually agreed only. No timeout, auto-approval,
  -- Fair-Play penalty, or Admin resolution is performed.
  RETURN;
END;
$function$
;

-- Function: auto_release_elo_lock
CREATE OR REPLACE FUNCTION public.auto_release_elo_lock()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking record;
    v_count int := 0;
BEGIN
    FOR v_booking IN 
        SELECT * FROM public.bookings 
        WHERE booking_type = 'challenge' 
          AND match_result_status = 'waitingOpponent'
          AND is_verified_by_owner IS NULL
          AND result_submitted_at < (now() - interval '24 hours')
    LOOP
        -- محاكاة تأكيد الحضور التلقائي لتجنب تعليق تصنيف الكباتن
        PERFORM public.verify_match_played(v_booking.id, true);
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$function$
;

-- Function: block_user_atomic
CREATE OR REPLACE FUNCTION public.block_user_atomic(p_blocked_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  end if;
  if p_blocked_user_id is null or p_blocked_user_id = v_uid then
    return jsonb_build_object('success',false,'error','INVALID_TARGET');
  end if;
  if not exists (select 1 from public.users where id = p_blocked_user_id) then
    return jsonb_build_object('success',false,'error','USER_NOT_FOUND');
  end if;

  insert into public.user_blocks(blocker_id, blocked_user_id)
  values(v_uid, p_blocked_user_id)
  on conflict (blocker_id, blocked_user_id) do nothing;

  return jsonb_build_object('success',true,'blocked_user_id',p_blocked_user_id);
end;
$function$
;

-- Function: calculate_championship_effective_phase
CREATE OR REPLACE FUNCTION public.calculate_championship_effective_phase(p_championship_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_fixtures_count INT := 0;
BEGIN
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  
  IF v_champ.status = 'cancelled' THEN RETURN 'cancelled';
  ELSIF v_champ.status = 'completed' THEN RETURN 'completed';
  ELSIF v_champ.status = 'ongoing' THEN RETURN 'ongoing';
  END IF;
  
  IF v_champ.status = 'open' THEN
    SELECT count(*)::INT INTO v_fixtures_count 
    FROM public.tournament_matches 
    WHERE championship_id = p_championship_id;
    
    IF v_champ.registration_locked_at IS NOT NULL AND v_fixtures_count > 0 THEN
      RETURN 'draw_ready';
    ELSIF v_champ.registration_locked_at IS NOT NULL 
       OR (v_champ.registration_closes_at IS NOT NULL AND now() >= v_champ.registration_closes_at)
       OR now() >= v_champ.start_date THEN
      RETURN 'registration_closed';
    ELSIF coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = false THEN
      RETURN 'draft';
    ELSIF coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = true THEN
      RETURN 'pending_approval';
    ELSE
      RETURN 'registration_open';
    END IF;
  END IF;
  
  RETURN 'unknown';
END;
$function$
;

-- Function: calculate_elo_on_match_completion
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  home_points int;
  away_points int;
BEGIN
  IF NEW.booking_type='challenge'
     AND NEW.match_result_status='confirmed'
     AND NEW.final_outcome IS NOT NULL
     AND COALESCE(NEW.elo_processed,false)=false THEN

    home_points := CASE WHEN NEW.final_outcome='homeWin' THEN 3
                        WHEN NEW.final_outcome='draw' THEN 1 ELSE 0 END;
    away_points := CASE WHEN NEW.final_outcome='awayWin' THEN 3
                        WHEN NEW.final_outcome='draw' THEN 1 ELSE 0 END;

    UPDATE public.teams
      SET points=COALESCE(points,0)+home_points,
          matches_played=COALESCE(matches_played,0)+1,
          wins=COALESCE(wins,0)+CASE WHEN home_points=3 THEN 1 ELSE 0 END,
          draws=COALESCE(draws,0)+CASE WHEN home_points=1 THEN 1 ELSE 0 END,
          losses=COALESCE(losses,0)+CASE WHEN home_points=0 THEN 1 ELSE 0 END,
          updated_at=timezone('utc',now())
      WHERE id=NEW.player_team_id;

    UPDATE public.teams
      SET points=COALESCE(points,0)+away_points,
          matches_played=COALESCE(matches_played,0)+1,
          wins=COALESCE(wins,0)+CASE WHEN away_points=3 THEN 1 ELSE 0 END,
          draws=COALESCE(draws,0)+CASE WHEN away_points=1 THEN 1 ELSE 0 END,
          losses=COALESCE(losses,0)+CASE WHEN away_points=0 THEN 1 ELSE 0 END,
          updated_at=timezone('utc',now())
      WHERE id=NEW.opponent_team_id;

    NEW.elo_processed:=true;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: calculate_tournament_checkout_amount_atomic
CREATE OR REPLACE FUNCTION public.calculate_tournament_checkout_amount_atomic(p_championship_id uuid)
 RETURNS TABLE(base_amount numeric, platform_fee_amount numeric, gateway_fee_amount numeric, gross_amount numeric, currency text, fee_policy_version text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_entry_fee NUMERIC;
  v_currency TEXT;
  v_fee RECORD;
  v_base NUMERIC;
  v_vsp NUMERIC;
  v_gw NUMERIC;
  v_gross NUMERIC;
  v_version TEXT;
BEGIN
  SELECT coalesce(c.entry_fee, 0), coalesce(c.currency, 'EGP')
  INTO v_entry_fee, v_currency
  FROM public.championships c
  WHERE c.id = p_championship_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found: %', p_championship_id;
  END IF;

  IF v_entry_fee <= 0 THEN
    RETURN QUERY SELECT 0.00::NUMERIC, 0.00::NUMERIC, 0.00::NUMERIC, 0.00::NUMERIC, v_currency, 'free_policy'::TEXT;
    RETURN;
  END IF;

  SELECT booking_vsp_rate,
         coalesce(booking_paymob_local_rate, booking_paymob_rate, 0.0275) AS gw_rate,
         coalesce(booking_paymob_fixed_fee, 3.00) AS gw_fixed,
         updated_at
  INTO v_fee
  FROM public.platform_fee_config
  WHERE id = 1;

  v_base := round(v_entry_fee, 2);
  v_vsp  := round(v_base * coalesce(v_fee.booking_vsp_rate, 0.02), 2);
  v_gw   := round(v_base * v_fee.gw_rate + v_fee.gw_fixed, 2);
  v_gross := round(v_base + v_vsp + v_gw, 2);
  v_version := 'pfc_1_' || to_char(coalesce(v_fee.updated_at, now()), 'YYYYMMDDHH24MISS');

  RETURN QUERY SELECT v_base, v_vsp, v_gw, v_gross, v_currency, v_version;
END;
$function$
;

-- Function: cancel_1v1_payment_order_atomic
CREATE OR REPLACE FUNCTION public.cancel_1v1_payment_order_atomic(p_order_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller uuid:=auth.uid();
  v_order record;
  v_tourney record;
begin
  if v_caller is null then
    return jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً.');
  end if;

  select * into v_order
  from public.vsp_1v1_tournament_orders
  where order_reference=p_order_reference
  for update;

  if not found then
    return jsonb_build_object('success',false,'error','طلب الدفع غير موجود.');
  end if;

  if v_order.user_id is distinct from v_caller
     and not public.is_admin_or_cofounder(v_caller) then
    return jsonb_build_object('success',false,'error','غير مصرح.');
  end if;

  if v_order.payment_status='paid' then
    return jsonb_build_object('success',false,'error','الطلب مدفوع بالفعل ولا يمكن إلغاؤه.');
  end if;

  if v_order.payment_status not in ('pending','refund_failed_manual_review','failed_over_capacity') then
    return jsonb_build_object('success',true,'already_cancelled',true,'status',v_order.payment_status);
  end if;

  update public.vsp_1v1_tournament_orders
  set payment_status='cancelled',updated_at=timezone('utc',now())
  where id=v_order.id;

  return jsonb_build_object('success',true,'status','cancelled','order_reference',p_order_reference);
end;
$function$
;

-- Function: cancel_1v1_tournament_with_refund_requests
CREATE OR REPLACE FUNCTION public.cancel_1v1_tournament_with_refund_requests(p_tournament_id uuid, p_reason text DEFAULT 'إلغاء البطولة'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_t RECORD;
  v_rec RECORD;
  v_count INT := 0;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_refund_amt NUMERIC;
  v_is_manual_review BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN 
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول'); 
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_uid;
  IF v_role NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: صلاحية الإلغاء للأدمن فقط');
  END IF;

  SELECT * INTO v_t FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة'); 
  END IF;
  
  IF v_t.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إلغاء بطولة منتهية أو ملغاة بالفعل');
  END IF;

  -- Process refund queue items for all paid players strictly using historical gross_amount
  FOR v_rec IN 
    SELECT * FROM public.vsp_1v1_tournament_orders
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid'
  LOOP
    v_count := v_count + 1;
    
    -- 🛡️ Gate 8 Rule: Automated refund strictly uses gross_amount. If NULL/<=0 -> manual review, NO fallback to base amount
    IF v_rec.gross_amount IS NULL OR v_rec.gross_amount <= 0
       OR v_rec.amount IS NULL OR v_rec.amount <= 0
       OR nullif(trim(v_rec.paymob_transaction_id),'') IS NULL THEN
      v_is_manual_review := TRUE;
      v_refund_amt := v_rec.amount; -- Keep base amount recorded for manual review reference

      UPDATE public.vsp_1v1_tournament_orders
      SET payment_status = 'refund_failed_manual_review',
          updated_at = v_now
      WHERE id = v_rec.id;

      INSERT INTO public.vsp_1v1_cancellation_refund_queue (
        tournament_id,
        order_id,
        user_id,
        paymob_transaction_id,
        amount,
        status,
        failure_reason,
        created_at,
        updated_at
      ) VALUES (
        p_tournament_id,
        v_rec.id,
        v_rec.user_id,
        v_rec.paymob_transaction_id,
        v_refund_amt,
        'failed_manual_review',
        'Missing historical gross_amount; manual refund review required',
        v_now,
        v_now
      );

      INSERT INTO public.transactions (
        user_id, amount, type, status, 
        payment_method, reference_number, paymob_transaction_id,
        metadata, description, created_at, updated_at
      ) VALUES (
        v_rec.user_id, v_refund_amt, 'refund_request', 'manual_review',
        'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
        jsonb_build_object(
          'order_reference', v_rec.order_reference,
          'paymob_transaction_id', v_rec.paymob_transaction_id,
          'tournament_id', p_tournament_id,
          'tournament_name', v_t.name,
          'principal_amount', v_rec.amount,
          'gross_amount', null,
          'requires_manual_review', true,
          'reason', coalesce(p_reason, 'إلغاء البطولة')
        ),
        'طلب استرداد رسوم بطولة 1v1 يتطلب مراجعة يدوية لغياب المبلغ التاريخي الإجمالي',
        v_now, v_now
      );

    ELSE
      v_is_manual_review := FALSE;
      v_refund_amt := round(v_rec.amount,2);

      UPDATE public.vsp_1v1_tournament_orders
      SET payment_status = 'refund_requested',
          updated_at = v_now
      WHERE id = v_rec.id;

      INSERT INTO public.vsp_1v1_cancellation_refund_queue (
        tournament_id,
        order_id,
        user_id,
        paymob_transaction_id,
        amount,
        status,
        created_at,
        updated_at
      ) VALUES (
        p_tournament_id,
        v_rec.id,
        v_rec.user_id,
        v_rec.paymob_transaction_id,
        v_refund_amt,
        'pending',
        v_now,
        v_now
      );

      INSERT INTO public.transactions (
        user_id, amount, type, status, 
        payment_method, reference_number, paymob_transaction_id,
        metadata, description, created_at, updated_at
      ) VALUES (
        v_rec.user_id, v_refund_amt, 'refund_request', 'pending',
        'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
        jsonb_build_object(
          'order_reference', v_rec.order_reference,
          'paymob_transaction_id', v_rec.paymob_transaction_id,
          'tournament_id', p_tournament_id,
          'tournament_name', v_t.name,
          'refund_amount', v_refund_amt,
          'principal_amount', v_rec.amount,
          'original_gross_amount', v_rec.gross_amount,
          'non_refundable_fee_amount', round(greatest(v_rec.gross_amount-v_refund_amt,0),2),
          'reason', coalesce(p_reason, 'إلغاء البطولة')
        ),
        'طلب استرداد رسوم بطولة 1v1 عبر باي موب لإلغاء الدورة بقرار الإدارة',
        v_now, v_now
      );
    END IF;

    INSERT INTO public.notifications (
      user_id, title, body, type, created_at
    ) VALUES (
      v_rec.user_id,
      'إلغاء البطولة وطلب استرداد الرسوم 💳',
      'تم إلغاء ' || coalesce(v_t.name, 'بطولة 1v1') || ' لظروف تنظيمية، وتم رفع طلب استرداد رسمي لمبلغ (' || v_refund_amt || ' ج.م) عبر باي موب لإعادتها إلى وسيلة الدفع الخاصة بك.',
      'tournament_refund',
      v_now
    );
  END LOOP;

  UPDATE public.vsp_1v1_tournaments
  SET status = 'cancelled',
      prize_pool = 0,
      updated_at = v_now
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إلغاء البطولة ومعالجة طلبات استرداد الرسوم بنجاح',
    'refunded_count', v_count
  );
END;
$function$
;

-- Function: cancel_booking_with_refund_atomic
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'إلغاء حجز من المستخدم'::text, p_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking               record;
  v_refund_amount         numeric(10,2) := 0;
  v_refund_gross          numeric(10,2) := 0;
  v_tx_id                 uuid          := null;
  v_caller_role           text;
  v_minutes_since_created numeric;
  v_now                   timestamptz   := timezone('utc', now());
  v_paid_cash             numeric       := 0;
  v_total_gateway_paid    numeric       := 0;
  v_total_gross_paid      numeric       := 0;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_completed_booking', 'message', 'لا يمكن إلغاء حجز مكتمل.');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', true, 'code', 'already_cancelled', 'already_cancelled', true,
      'booking_id', p_booking_id, 'refund_amount', coalesce(v_booking.refund_amount, 0));
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
    END IF;
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id
       AND auth.uid() IS DISTINCT FROM v_booking.user_id
       AND auth.uid() IS DISTINCT FROM v_booking.owner_id
       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: لا يمكنك إلغاء هذا الحجز.');
    END IF;
    IF auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id THEN
      v_minutes_since_created := extract(epoch FROM (v_now - coalesce(v_booking.created_at, v_now))) / 60.0;
      IF v_minutes_since_created > (SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id = 1)
         AND v_booking.start_time <= (v_now + ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id = 1) * interval '1 hour'))
      THEN
        RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_within_6_hours',
          'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات إلا خلال أول 20 دقيقة.');
      END IF;
    END IF;
  END IF;

  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    SELECT coalesce(sum(CASE WHEN t.type = 'refund_cash' THEN -abs(t.amount) ELSE abs(t.amount) END), 0)
    INTO v_paid_cash
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.payment_method = 'cash'
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit', 'cash_settlement', 'cash_collection_adjustment', 'refund_cash');
    v_refund_amount := round(greatest(v_paid_cash, 0), 2);
    v_refund_gross  := v_refund_amount;
  ELSE
    SELECT
      coalesce(sum(t.amount), 0),
      coalesce(sum(coalesce(t.gross_amount, t.amount)), 0)
    INTO v_total_gateway_paid, v_total_gross_paid
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit')
      AND lower(coalesce(t.payment_method, '')) <> 'cash';

    SELECT round(greatest(v_total_gateway_paid - coalesce(sum(t.amount), 0), 0), 2)
    INTO v_refund_amount
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    SELECT round(greatest(v_total_gross_paid - coalesce(sum(coalesce(t.gross_amount, t.amount)), 0), 0), 2)
    INTO v_refund_gross
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    v_refund_amount := coalesce(v_refund_amount, 0);
    v_refund_gross  := coalesce(v_refund_gross,  0);
  END IF;

  UPDATE public.bookings SET
    status              = 'cancelled',
    is_paid             = false,
    payment_status      = CASE
                            WHEN v_refund_amount > 0 AND lower(coalesce(payment_method, '')) <> 'cash' THEN 'refund_pending'
                            WHEN v_refund_amount > 0                                                   THEN 'refunded'
                            ELSE CASE
                              WHEN lower(coalesce(payment_method, '')) = 'cash' THEN 'cancelled'
                              ELSE payment_status
                            END
                          END,
    refund_amount       = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
    cancellation_reason = p_reason,
    cancelled_at        = v_now,
    updated_at          = v_now
  WHERE id = p_booking_id;

  IF v_refund_amount > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.transactions
       WHERE booking_id = p_booking_id
         AND type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending')
         AND status IN ('pending', 'completed')
     ) THEN
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(v_booking.created_by_user_id, v_booking.user_id),
      p_booking_id,
      v_refund_amount,
      v_refund_gross,
      'refund',
      CASE WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'completed' ELSE 'pending' END,
      coalesce(v_booking.payment_method, 'online'),
      CASE
        WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'استرداد نقدي بالملعب لإلغاء الحجز'
        ELSE 'طلب استرداد إلكتروني قيد المعالجة'
      END,
      jsonb_build_object(
        'refund_principal', v_refund_amount,
        'refund_gross',     v_refund_gross,
        'source',           'cancel_booking_with_refund_atomic',
        'cancelled_at',     v_now
      ),
      v_now, v_now
    ) RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success',        true,
    'message',        'تم إلغاء الحجز بنجاح.',
    'refund_amount',  v_refund_amount,
    'refund_gross',   v_refund_gross,
    'payment_status', CASE
                        WHEN v_refund_amount > 0 AND lower(coalesce(v_booking.payment_method, '')) <> 'cash' THEN 'refund_pending'
                        WHEN v_refund_amount > 0 THEN 'refunded'
                        ELSE 'cancelled'
                      END,
    'booking_id',     p_booking_id,
    'transaction_id', v_tx_id
  );
END;
$function$
;

-- Function: cancel_booking_with_refund_atomic
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'cancelled_by_user'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking               record;
  v_refund_amount         numeric(10,2) := 0;
  v_refund_gross          numeric(10,2) := 0;
  v_tx_id                 uuid          := null;
  v_caller_role           text;
  v_minutes_since_created numeric;
  v_now                   timestamptz   := timezone('utc', now());
  v_paid_cash             numeric       := 0;
  v_total_gateway_paid    numeric       := 0;
  v_total_gross_paid      numeric       := 0;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_completed_booking', 'message', 'لا يمكن إلغاء حجز مكتمل.');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', true, 'code', 'already_cancelled', 'already_cancelled', true,
      'booking_id', p_booking_id, 'refund_amount', coalesce(v_booking.refund_amount, 0));
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
    END IF;
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id
       AND auth.uid() IS DISTINCT FROM v_booking.user_id
       AND auth.uid() IS DISTINCT FROM v_booking.owner_id
       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: لا يمكنك إلغاء هذا الحجز.');
    END IF;
    IF auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id THEN
      v_minutes_since_created := extract(epoch FROM (v_now - coalesce(v_booking.created_at, v_now))) / 60.0;
      IF v_minutes_since_created > (SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id = 1)
         AND v_booking.start_time <= (v_now + ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id = 1) * interval '1 hour'))
      THEN
        RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_within_6_hours',
          'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات إلا خلال أول 20 دقيقة.');
      END IF;
    END IF;
  END IF;

  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    SELECT coalesce(sum(CASE WHEN t.type = 'refund_cash' THEN -abs(t.amount) ELSE abs(t.amount) END), 0)
    INTO v_paid_cash
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.payment_method = 'cash'
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit', 'cash_settlement', 'cash_collection_adjustment', 'refund_cash');
    v_refund_amount := round(greatest(v_paid_cash, 0), 2);
    v_refund_gross  := v_refund_amount;
  ELSE
    SELECT
      coalesce(sum(t.amount), 0),
      coalesce(sum(coalesce(t.gross_amount, t.amount)), 0)
    INTO v_total_gateway_paid, v_total_gross_paid
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit')
      AND lower(coalesce(t.payment_method, '')) <> 'cash';

    SELECT round(greatest(v_total_gateway_paid - coalesce(sum(t.amount), 0), 0), 2)
    INTO v_refund_amount
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    SELECT round(greatest(v_total_gross_paid - coalesce(sum(coalesce(t.gross_amount, t.amount)), 0), 0), 2)
    INTO v_refund_gross
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    v_refund_amount := coalesce(v_refund_amount, 0);
    v_refund_gross  := coalesce(v_refund_gross,  0);
  END IF;

  UPDATE public.bookings SET
    status              = 'cancelled',
    is_paid             = false,
    payment_status      = CASE
                            WHEN v_refund_amount > 0 AND lower(coalesce(payment_method, '')) <> 'cash' THEN 'refund_pending'
                            WHEN v_refund_amount > 0                                                   THEN 'refunded'
                            ELSE 'unpaid'
                          END,
    refund_amount       = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
    cancellation_reason = p_reason,
    cancelled_at        = v_now,
    updated_at          = v_now
  WHERE id = p_booking_id;

  IF v_refund_amount > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.transactions
       WHERE booking_id = p_booking_id
         AND type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending')
         AND status IN ('pending', 'completed')
     ) THEN
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(v_booking.created_by_user_id, v_booking.user_id),
      p_booking_id,
      v_refund_amount,
      v_refund_gross,
      'refund',
      CASE WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'completed' ELSE 'pending' END,
      coalesce(v_booking.payment_method, 'online'),
      CASE
        WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'استرداد نقدي بالملعب لإلغاء الحجز'
        ELSE 'طلب استرداد إلكتروني قيد المعالجة'
      END,
      jsonb_build_object(
        'refund_principal', v_refund_amount,
        'refund_gross',     v_refund_gross,
        'source',           'cancel_booking_with_refund_atomic',
        'cancelled_at',     v_now
      ),
      v_now, v_now
    ) RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success',        true,
    'message',        'تم إلغاء الحجز بنجاح.',
    'refund_amount',  v_refund_amount,
    'refund_gross',   v_refund_gross,
    'payment_status', CASE
                        WHEN v_refund_amount > 0 AND lower(coalesce(v_booking.payment_method, '')) <> 'cash' THEN 'refund_pending'
                        WHEN v_refund_amount > 0 THEN 'refunded'
                        ELSE 'unpaid'
                      END,
    'booking_id',     p_booking_id,
    'transaction_id', v_tx_id
  );
END;
$function$
;

-- Function: cancel_championship_atomic
CREATE OR REPLACE FUNCTION public.cancel_championship_atomic(p_championship_id uuid, p_reason text DEFAULT 'Cancelled by owner'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_order RECORD;
  v_refunds_count INT := 0;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  IF v_champ.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'terminal_status_cannot_cancel');
  END IF;

  -- 1. Lock and update status to cancelled
  UPDATE public.championships
  SET status = 'cancelled',
      prize_pool = 0,
      registration_locked_at = coalesce(registration_locked_at, now()),
      updated_at = now()
  WHERE id = p_championship_id;

  -- 2. Mark active registrations as cancelled/refund_pending
  UPDATE public.championship_registrations
  SET registration_status = 'cancelled',
      payment_status = CASE WHEN payment_status = 'paid' THEN 'refund_pending' ELSE payment_status END,
      updated_at = now()
  WHERE championship_id = p_championship_id;

  -- 3. Cancel all pending orders so no webhook can confirm them later
  UPDATE public.tournament_orders
  SET payment_status = 'cancelled',
      updated_at = now()
  WHERE championship_id = p_championship_id
    AND payment_status = 'pending';

  -- 4. Queue refunds for paid orders (gross_amount > 0 only)
  FOR v_order IN 
    SELECT o.id, o.registration_id, o.base_amount, o.gross_amount, o.currency, o.paymob_transaction_id
    FROM public.tournament_orders o
    WHERE o.championship_id = p_championship_id
      AND o.payment_status = 'paid'
      AND coalesce(o.gross_amount, 0) > 0
  LOOP
    UPDATE public.tournament_orders
    SET payment_status = CASE
          WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
          THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        updated_at = now()
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = CASE
          WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
          THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        updated_at = now()
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, failure_reason
    )
    VALUES (
      p_championship_id, v_order.id, v_order.registration_id, v_order.paymob_transaction_id,
      coalesce(nullif(v_order.base_amount,0), v_order.gross_amount), coalesce(v_order.currency, 'EGP'),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
           THEN 'pending' ELSE 'failed_manual_review' END,
      CASE WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
           THEN NULL ELSE 'Missing historical principal amount or Paymob transaction ID; manual review required' END
    )
    ON CONFLICT (order_id) DO NOTHING;

    v_refunds_count := v_refunds_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'cancelled',
    'effective_phase', 'cancelled',
    'queued_refunds_count', v_refunds_count
  );
END;
$function$
;

-- Function: cancel_expired_pending_bookings
CREATE OR REPLACE FUNCTION public.cancel_expired_pending_bookings()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cancelled_count int;
  v_now timestamptz := now();
BEGIN
  WITH expired_rows AS (
    UPDATE public.bookings
    SET
      status = 'expired',
      payment_status = 'unpaid',
      cancellation_reason = 'auto_expired_pending_payment',
      updated_at = v_now
    WHERE
      status = 'pending'
      AND payment_method IN ('paymob', 'card', 'wallet', 'online')
      AND is_paid = false
      AND coalesce(locked_until, created_at + INTERVAL '8 minutes') < v_now
    RETURNING id
  )
  SELECT count(*) INTO v_cancelled_count FROM expired_rows;

  RETURN jsonb_build_object(
    'success', true,
    'cancelled_count', v_cancelled_count,
    'ran_at', v_now
  );
END;
$function$
;

-- Function: cancel_team_league
CREATE OR REPLACE FUNCTION public.cancel_team_league(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE 
  v_uid UUID := auth.uid(); 
  v_owner UUID; 
  v_paid_count INT; 
  v_status TEXT;
  v_name TEXT;
  v_rec RECORD;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_queue_status TEXT;
  v_payment_status TEXT;
  v_tx_status TEXT;
  v_refund_amount NUMERIC;
  v_failure_reason TEXT;
  v_notif_body TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  
  SELECT owner_id, status, name, cardinality(coalesce(paid_teams, '{}'::text[]))
    INTO v_owner, v_status, v_name, v_paid_count
  FROM public.championships
  WHERE id = p_championship_id AND template_type = 'team_league'
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الدوري غير موجود'; END IF;
  IF v_owner <> v_uid THEN RAISE EXCEPTION 'فقط منشئ الدوري يستطيع إلغاءه'; END IF;
  IF v_status <> 'open' THEN RAISE EXCEPTION 'لا يمكن إلغاء الدوري بعد بدء المنافسات'; END IF;

  FOR v_rec IN 
    SELECT * FROM public.team_league_payments 
    WHERE championship_id = p_championship_id AND payment_status = 'paid'
  LOOP
    -- Determine refund eligibility and exact historical gross
    IF v_rec.paymob_transaction_id IS NULL OR trim(v_rec.paymob_transaction_id) = '' THEN
      v_queue_status := 'failed_manual_review';
      v_payment_status := 'refund_failed_manual_review';
      v_tx_status := 'manual_review';
      v_failure_reason := 'Missing paymob_transaction_id; manual review required';
      v_refund_amount := round(coalesce(v_rec.amount,0),2);
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وجارٍ مراجعة طلب استرداد الرسوم يدوياً من قِبل إدارة التطبيق.';
    ELSIF v_rec.gross_amount IS NULL OR v_rec.gross_amount <= 0
       OR v_rec.amount IS NULL OR v_rec.amount <= 0 THEN
      v_queue_status := 'failed_manual_review';
      v_payment_status := 'refund_failed_manual_review';
      v_tx_status := 'manual_review';
      v_failure_reason := 'Missing valid historical gross_amount; manual review required';
      v_refund_amount := v_rec.amount;
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وجارٍ مراجعة طلب استرداد الرسوم يدوياً من قِبل إدارة التطبيق.';
    ELSE
      v_queue_status := 'pending';
      v_payment_status := 'refund_requested';
      v_tx_status := 'pending';
      v_failure_reason := NULL;
      v_refund_amount := round(v_rec.amount,2);
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وتم رفع طلب استرداد رسمي لمبلغ (' || v_refund_amount || ' ج.م) عبر باي موب لإعادتها إلى وسيلة الدفع الخاصة بك.';
    END IF;

    UPDATE public.team_league_payments
    SET payment_status = v_payment_status,
        updated_at = v_now
    WHERE id = v_rec.id;

    INSERT INTO public.team_league_cancellation_refund_queue (
      championship_id,
      payment_id,
      user_id,
      paymob_transaction_id,
      amount,
      status,
      failure_reason,
      created_at,
      updated_at
    ) VALUES (
      p_championship_id,
      v_rec.id,
      v_rec.user_id,
      v_rec.paymob_transaction_id,
      v_refund_amount,
      v_queue_status,
      v_failure_reason,
      v_now,
      v_now
    );

    INSERT INTO public.transactions(
      user_id, championship_id, amount, type, status, 
      payment_method, reference_number, paymob_transaction_id,
      metadata, description, created_at, updated_at
    ) VALUES (
      v_rec.user_id, p_championship_id, v_refund_amount, 'refund_request', v_tx_status,
      'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
      jsonb_build_object(
        'order_reference', v_rec.order_reference,
        'paymob_transaction_id', v_rec.paymob_transaction_id,
        'reason', 'league_cancelled_before_completion',
        'league_name', v_name,
        'refund_principal', v_refund_amount,
        'original_gross_amount', v_rec.gross_amount,
        'non_refundable_fee_amount', round(greatest(coalesce(v_rec.gross_amount,v_rec.amount)-v_refund_amount,0),2),
        'requires_manual_review', (v_queue_status = 'failed_manual_review')
      ),
      CASE 
        WHEN v_queue_status = 'failed_manual_review' THEN 'طلب استرداد رسوم دوري الفرق (يتطلب مراجعة يدوية)'
        ELSE 'طلب استرداد رسوم دوري الفرق عبر باي موب لإلغاء الدوري لعدم اكتمال الفرق'
      END,
      v_now, v_now
    );

    INSERT INTO public.notifications(
      user_id, title, body, type, created_at
    ) VALUES (
      v_rec.user_id,
      'إلغاء الدوري وطلب استرداد الرسوم 💳',
      v_notif_body,
      'tournament_refund',
      v_now
    );
  END LOOP;

  UPDATE public.championships
  SET status = 'cancelled',
      updated_at = v_now
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إلغاء الدوري وتسجيل طلبات استرداد الرسوم بنجاح',
    'refund_requests_count', v_paid_count
  );
END;
$function$
;

-- Function: cancel_tournament_payment_order_atomic
CREATE OR REPLACE FUNCTION public.cancel_tournament_payment_order_atomic(p_order_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller uuid:=auth.uid();
  v_order record;
  v_found boolean:=false;
begin
  if v_caller is null then
    return jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً.');
  end if;

  select id,user_id,payment_status into v_order
  from public.tournament_orders
  where order_reference=p_order_reference
  for update;
  if found then
    v_found:=true;
  else
    select id,user_id,payment_status into v_order
    from public.team_league_payments
    where order_reference=p_order_reference
    for update;
    if found then v_found:=true; end if;
  end if;

  if not v_found then
    return jsonb_build_object('success',false,'error','طلب الدفع غير موجود.');
  end if;

  if v_order.user_id is distinct from v_caller
     and not public.is_admin_or_cofounder(v_caller) then
    return jsonb_build_object('success',false,'error','غير مصرح.');
  end if;

  if v_order.payment_status='paid' then
    return jsonb_build_object('success',false,'error','الطلب مدفوع بالفعل ولا يمكن إلغاؤه.');
  end if;

  if v_order.payment_status not in ('pending','cancelled') then
    return jsonb_build_object('success',true,'status',v_order.payment_status);
  end if;

  update public.tournament_orders
  set payment_status='cancelled',updated_at=now()
  where order_reference=p_order_reference and payment_status='pending';

  update public.team_league_payments
  set payment_status='cancelled',updated_at=now()
  where order_reference=p_order_reference and payment_status='pending';

  return jsonb_build_object('success',true,'status','cancelled','order_reference',p_order_reference);
end;
$function$
;

-- Function: check_1v1_registration_capacity
CREATE OR REPLACE FUNCTION public.check_1v1_registration_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.vsp_1v1_registrations
  WHERE status IN ('pending', 'approved');

  IF v_count >= 32 THEN
    RAISE EXCEPTION 'roster_full_32';
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: check_extension_available
CREATE OR REPLACE FUNCTION public.check_extension_available(p_booking_id uuid, p_new_end_time timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.bookings b
    where b.id=p_booking_id
      and (
        b.created_by_user_id=auth.uid()
        or b.user_id=auth.uid()
        or b.owner_id=auth.uid()
        or exists(select 1 from public.users u where u.id=auth.uid() and u.role in ('admin','co_founder','cofounder','super_admin'))
      )
  )
  and not exists (
    select 1 from public.bookings b2
    where b2.stadium_id=(select stadium_id from public.bookings where id=p_booking_id)
      and b2.id<>p_booking_id and b2.status<>'cancelled'
      and b2.start_time<p_new_end_time
      and b2.end_time>(select end_time from public.bookings where id=p_booking_id)
  );
$function$
;

-- Function: check_owner_stadium_limit
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval record;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id AND NOT public.vsp_is_admin() THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(p_owner_id);
  RETURN jsonb_build_object(
    'allowed', v_eval.allowed,
    'current_count', v_eval.current_count,
    'max_allowed', v_eval.max_allowed,
    'is_trial', v_eval.is_trial,
    'is_sub_active', v_eval.is_sub_active,
    'plan_code', v_eval.plan_code,
    'message', v_eval.message
  );
END;
$function$
;

-- Function: check_rate_limit
CREATE OR REPLACE FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_requests integer DEFAULT 10, p_window_seconds integer DEFAULT 60)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count INT;
  v_effective_user_id UUID;
BEGIN
  -- 🔒 حماية تزوير الهوية: إجبار استعلامات العملاء على استخدام auth.uid() الحقيقي
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.role(), '') != 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN FALSE; -- حظر الزوار مجهولي الهوية من استهلاك موارد الكوبيلوت
    END IF;
    v_effective_user_id := auth.uid();
  ELSE
    v_effective_user_id := COALESCE(p_user_id, auth.uid());
  END IF;

  IF v_effective_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 1. Transaction-scoped advisory lock لمنع تداخل الاستدعاءات المتزامنة لنفس المستخدم
  PERFORM pg_advisory_xact_lock(hashtext(v_effective_user_id::text), hashtext(p_action));

  -- 2. تنظيف السجلات القديمة المنتهية
  DELETE FROM public.rate_limit_logs
  WHERE user_id = v_effective_user_id
    AND action = p_action
    AND created_at < NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- 3. حساب عدد الطلبات داخل النافذة الزمنية
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limit_logs
  WHERE user_id = v_effective_user_id
    AND action = p_action
    AND created_at >= NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- 4. رفض الطلب في حال تجاوز الحد المسموح
  IF v_count >= p_max_requests THEN
    RETURN FALSE;
  END IF;

  -- 5. تسجيل الطلب
  INSERT INTO public.rate_limit_logs (user_id, action, created_at)
  VALUES (v_effective_user_id, p_action, NOW());

  RETURN TRUE;
END;
$function$
;

-- Function: check_roster_player_single_championship
CREATE OR REPLACE FUNCTION public.check_roster_player_single_championship()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_champ_id UUID;
  v_team_id UUID;
BEGIN
  SELECT championship_id, team_id INTO v_champ_id, v_team_id
  FROM public.championship_rosters
  WHERE id = NEW.roster_id;

  IF v_champ_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 
      FROM public.championship_roster_players crp
      JOIN public.championship_rosters cr ON cr.id = crp.roster_id
      WHERE cr.championship_id = v_champ_id
        AND cr.team_id <> v_team_id
        AND crp.player_id = NEW.player_id
    ) THEN
      RAISE EXCEPTION 'PLAYER_ALREADY_IN_ANOTHER_TEAM: Player % is already in another team roster in championship %', NEW.player_id, v_champ_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: check_team_and_member_limits
CREATE OR REPLACE FUNCTION public.check_team_and_member_limits()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_team_count int;
  v_owned_team_count int;
  v_joined_team_count int;
  v_new_team_captain uuid;
begin
  select count(*) into v_team_count
  from public.team_members
  where team_id = new.team_id;

  if v_team_count >= 12 then
    raise exception 'Team capacity reached: Maximum 12 players allowed per team.';
  end if;

  select captain_id into v_new_team_captain
  from public.teams
  where id = new.team_id;

  select count(*) into v_owned_team_count
  from public.teams
  where captain_id = new.user_id
    and id <> new.team_id;

  if new.user_id = v_new_team_captain then
    if v_owned_team_count >= 1 then
      raise exception 'Team ownership limit reached: A player can own only one team.';
    end if;
  else
    select count(*) into v_joined_team_count
    from public.team_members tm
    join public.teams t on t.id = tm.team_id
    where tm.user_id = new.user_id
      and tm.team_id <> new.team_id
      and t.captain_id is distinct from new.user_id;

    if v_joined_team_count >= 3 then
      raise exception 'Player team limit reached: A player can join up to 3 additional teams.';
    end if;
  end if;

  return new;
end;
$function$
;

-- Function: check_team_has_1v1_champion
CREATE OR REPLACE FUNCTION public.check_team_has_1v1_champion(p_team_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_has_champ BOOLEAN := false;
    v_latest_champ_user UUID;
BEGIN
    -- 0. Check persisted flag on team first (direct write-in column)
    SELECT COALESCE(has_1v1_champion, false) INTO v_has_champ
    FROM public.teams
    WHERE id = p_team_id;

    IF v_has_champ THEN
        RETURN true;
    END IF;

    -- 1. Check if unlocked_badges array contains 1v1_champion
    SELECT EXISTS (
        SELECT 1 FROM public.teams 
        WHERE id = p_team_id AND '1v1_champion' = ANY(COALESCE(unlocked_badges, ARRAY[]::text[]))
    ) INTO v_has_champ;

    IF v_has_champ THEN
        RETURN true;
    END IF;

    -- 2. Find champion of latest completed 1v1 tournament
    SELECT champion_user_id INTO v_latest_champ_user
    FROM public.vsp_1v1_tournaments
    WHERE status IN ('completed', 'published') AND champion_user_id IS NOT NULL
    ORDER BY published_at DESC NULLS LAST, created_at DESC
    LIMIT 1;

    IF v_latest_champ_user IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.teams WHERE id = p_team_id AND captain_id = v_latest_champ_user
            UNION ALL
            SELECT 1 FROM public.team_members WHERE team_id = p_team_id AND user_id = v_latest_champ_user
        ) INTO v_has_champ;

        IF v_has_champ THEN
            RETURN true;
        END IF;
    END IF;

    -- 3. Fallback check on legacy table if applicable
    SELECT EXISTS (
        SELECT 1
        FROM public.team_members tm
        JOIN public.vsp_1vs1_players p1v1 ON tm.user_id = p1v1.id
        WHERE tm.team_id = p_team_id AND p1v1.titles > 0
    ) INTO v_has_champ;

    RETURN COALESCE(v_has_champ, false);
END;
$function$
;

-- Function: check_team_membership_limit
CREATE OR REPLACE FUNCTION public.check_team_membership_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  membership_count int;
BEGIN
  -- حساب عدد الفرق التي ينتمي إليها اللاعب حالياً
  SELECT COUNT(*) INTO membership_count 
  FROM team_members 
  WHERE user_id = NEW.user_id;

  -- إذا كان مسجلاً في 3 فرق أو أكثر، نمنع الإدخال ونظهر رسالة خطأ صريحة
  IF membership_count >= 3 THEN
    RAISE EXCEPTION 'تنبيه: لقد وصلت للحد الأقصى للانضمام للفرق (3 فرق كحد أقصى).';
  END IF;
  
  RETURN NEW;
END;
$function$
;

-- Function: claim_booking_gateway_refund_atomic
CREATE OR REPLACE FUNCTION public.claim_booking_gateway_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'cancelled'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_existing_refund record;
  v_source_tx record;
  v_source_count integer := 0;
  v_now timestamptz := timezone('utc', now());
  v_lease_until timestamptz;
  v_refund_amount numeric(10,2);
  v_refund_gross numeric(10,2);
  v_source_paymob_id text;
  v_meta jsonb;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    RETURN jsonb_build_object('success', false, 'error', 'cash_booking_not_supported');
  END IF;

  SELECT count(*)
  INTO v_source_count
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND status = 'completed'
    AND type IN ('payment', 'deposit')
    AND lower(coalesce(payment_method, '')) <> 'cash'
    AND (paymob_transaction_id IS NOT NULL OR reference_number IS NOT NULL);

  IF v_source_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_refundable_paymob_payment');
  END IF;

  -- A booking may have deposit + final-payment transactions. Do not silently refund
  -- only the latest transaction; route multi-transaction cases to controlled review.
  IF v_source_count > 1 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'multiple_paymob_payments_require_manual_refund',
      'payment_count', v_source_count
    );
  END IF;

  SELECT *
  INTO v_source_tx
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND status = 'completed'
    AND type IN ('payment', 'deposit')
    AND lower(coalesce(payment_method, '')) <> 'cash'
    AND (paymob_transaction_id IS NOT NULL OR reference_number IS NOT NULL)
  ORDER BY created_at DESC
  LIMIT 1;

  v_source_paymob_id := coalesce(v_source_tx.paymob_transaction_id, v_source_tx.reference_number);
  IF nullif(trim(v_source_paymob_id), '') IS NULL OR coalesce(v_source_tx.amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_refundable_paymob_transaction');
  END IF;

  v_refund_amount := round(coalesce(v_source_tx.amount, 0), 2);
  v_refund_gross := round(coalesce(v_source_tx.gross_amount, v_source_tx.amount), 2);
  v_lease_until := v_now + interval '5 minutes';

  SELECT id, status, metadata
  INTO v_existing_refund
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND type = 'refund'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF FOUND AND v_existing_refund.status = 'completed' THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_refunded', true,
      'booking_id', p_booking_id
    );
  END IF;

  IF FOUND AND v_existing_refund.status = 'pending' THEN
    v_meta := coalesce(v_existing_refund.metadata, '{}'::jsonb);

    IF coalesce((v_meta->>'refund_lease_expires_at')::timestamptz, 'epoch'::timestamptz) > v_now THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'refund_in_progress',
        'booking_id', p_booking_id,
        'refund_transaction_id', v_existing_refund.id,
        'lease_expires_at', v_meta->>'refund_lease_expires_at'
      );
    END IF;

    UPDATE public.transactions
    SET amount = v_refund_amount,
        gross_amount = v_refund_gross,
        payment_method = coalesce(nullif(v_source_tx.payment_method, ''), payment_method),
        metadata = v_meta || jsonb_build_object(
          'source_transaction_id', v_source_tx.id,
          'paymob_transaction_id', v_source_paymob_id,
          'refund_principal', v_refund_amount,
          'refund_gross', v_refund_gross,
          'refund_reason', coalesce(p_reason, 'cancelled'),
          'refund_lease_expires_at', v_lease_until,
          'refund_claimed_at', v_now
        ),
        updated_at = v_now
    WHERE id = v_existing_refund.id;

    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = 'refund_pending',
        payment_reconcile_state = 'refund_pending',
        refund_amount = v_refund_amount,
        cancellation_reason = coalesce(p_reason, cancellation_reason),
        cancelled_at = coalesce(cancelled_at, v_now),
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'claimed', true,
      'refund_transaction_id', v_existing_refund.id,
      'source_transaction_id', v_source_tx.id,
      'paymob_transaction_id', v_source_paymob_id,
      'refund_amount', v_refund_amount,
      'refund_gross_amount', v_refund_gross,
      'lease_expires_at', v_lease_until
    );
  END IF;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, gross_amount, type, status,
    payment_method, reference_number, description, metadata, created_at, updated_at
  )
  VALUES (
    coalesce(v_booking.created_by_user_id, v_booking.user_id),
    p_booking_id,
    v_refund_amount,
    v_refund_gross,
    'refund',
    'pending',
    coalesce(nullif(v_source_tx.payment_method, ''), 'paymob'),
    'REFUND_CLAIM_' || p_booking_id::text,
    'استرداد Paymob قيد المعالجة',
    jsonb_build_object(
      'source_transaction_id', v_source_tx.id,
      'paymob_transaction_id', v_source_paymob_id,
      'refund_principal', v_refund_amount,
      'refund_gross', v_refund_gross,
      'refund_reason', coalesce(p_reason, 'cancelled'),
      'refund_lease_expires_at', v_lease_until,
      'refund_claimed_at', v_now
    ),
    v_now, v_now
  )
  RETURNING id INTO v_existing_refund.id;

  UPDATE public.bookings
  SET status = 'cancelled',
      payment_status = 'refund_pending',
      payment_reconcile_state = 'refund_pending',
      refund_amount = v_refund_amount,
      cancellation_reason = coalesce(p_reason, cancellation_reason),
      cancelled_at = coalesce(cancelled_at, v_now),
      updated_at = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'claimed', true,
    'refund_transaction_id', v_existing_refund.id,
    'source_transaction_id', v_source_tx.id,
    'paymob_transaction_id', v_source_paymob_id,
    'refund_amount', v_refund_amount,
    'refund_gross_amount', v_refund_gross,
    'lease_expires_at', v_lease_until
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'refund_already_claimed');
END;
$function$
;

-- Function: claim_next_1v1_cancellation_refund_atomic
CREATE OR REPLACE FUNCTION public.claim_next_1v1_cancellation_refund_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' AND current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_1v1_cancellation_refund_atomic is restricted to service_role';
  END IF;

  SELECT * INTO v_row
  FROM public.vsp_1v1_cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Escalate to manual review after 3 failed lease cycles
  IF v_row.retry_count >= 3 THEN
    UPDATE public.vsp_1v1_cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.vsp_1v1_tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.order_id;

    RETURN jsonb_build_object(
      'found', false,
      'escalated_to_manual_review', true,
      'queue_id', v_row.id
    );
  END IF;

  -- Transition to processing with 15-minute lease
  UPDATE public.vsp_1v1_cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'tournament_id', v_row.tournament_id,
      'order_id', v_row.order_id,
      'user_id', v_row.user_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', v_row.currency,
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$function$
;

-- Function: claim_next_cancellation_refund_atomic
CREATE OR REPLACE FUNCTION public.claim_next_cancellation_refund_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  -- Strict Access Control: ONLY service_role or postgres internal caller
  IF coalesce(auth.role(), '') <> 'service_role' AND current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_cancellation_refund_atomic is restricted to service_role';
  END IF;

  -- 1. Select pending row OR abandoned processing row whose 15-minute lease expired
  SELECT * INTO v_row
  FROM public.cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- 2. Max Retry Invariant: Escalate to failed_manual_review after 3 failed attempts
  IF v_row.retry_count >= 3 THEN
    UPDATE public.cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.order_id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.registration_id;

    RETURN jsonb_build_object(
      'found', false,
      'escalated_to_manual_review', true,
      'queue_id', v_row.id
    );
  END IF;

  -- 3. Atomically transition to processing with 15-minute lease
  UPDATE public.cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'championship_id', v_row.championship_id,
      'order_id', v_row.order_id,
      'registration_id', v_row.registration_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', v_row.currency,
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$function$
;

-- Function: claim_next_team_league_cancellation_refund_atomic
CREATE OR REPLACE FUNCTION public.claim_next_team_league_cancellation_refund_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' AND current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_team_league_cancellation_refund_atomic is restricted to service_role';
  END IF;

  SELECT * INTO v_row
  FROM public.team_league_cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Escalate to manual review after 3 failed lease cycles
  IF v_row.retry_count >= 3 THEN
    UPDATE public.team_league_cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.team_league_payments
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.payment_id;

    -- Update transaction to failed_manual_review as well to keep ledger coherent
    UPDATE public.transactions
    SET status = 'failed_manual_review',
        metadata = jsonb_set(coalesce(metadata, '{}'::jsonb), '{failure_reason}', '"Escalated to manual review: 3 failed lease cycles exceeded"'),
        updated_at = now()
    WHERE championship_id = v_row.championship_id
      AND type = 'refund_request'
      AND paymob_transaction_id = v_row.paymob_transaction_id;

    RETURN jsonb_build_object(
      'found', false,
      'escalated_to_manual_review', true,
      'queue_id', v_row.id
    );
  END IF;

  -- Transition to processing with 15-minute lease
  UPDATE public.team_league_cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'championship_id', v_row.championship_id,
      'payment_id', v_row.payment_id,
      'user_id', v_row.user_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', coalesce(v_row.currency, 'EGP'),
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$function$
;

-- Function: claim_owner_championship_approval_home_notice
CREATE OR REPLACE FUNCTION public.claim_owner_championship_approval_home_notice(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_owner_id uuid;
  v_is_approved boolean;
  v_creation_fee_paid boolean;
  v_seen_at timestamptz;
  v_now timestamptz := now();
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  end if;

  select owner_id, is_approved, creation_fee_paid, owner_approval_home_seen_at
    into v_owner_id, v_is_approved, v_creation_fee_paid, v_seen_at
  from public.championships
  where id = p_championship_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_NOT_FOUND');
  end if;

  if v_owner_id is distinct from v_uid then
    return jsonb_build_object('success', false, 'error', 'OWNER_ONLY');
  end if;

  if coalesce(v_is_approved, false) = false then
    return jsonb_build_object(
      'success', true,
      'state', case when coalesce(v_creation_fee_paid, false) then 'pending_approval' else 'draft' end,
      'seen_at', null,
      'seen_until', null
    );
  end if;

  if v_seen_at is null then
    v_seen_at := v_now;
    update public.championships
       set owner_approval_home_seen_at = v_seen_at,
           updated_at = v_now
     where id = p_championship_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'state', 'approved',
    'seen_at', v_seen_at,
    'seen_until', v_seen_at + interval '24 hours'
  );
end;
$function$
;

-- Function: claim_owner_web_subscription
CREATE OR REPLACE FUNCTION public.claim_owner_web_subscription()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_uid uuid := auth.uid(); v_user public.users%ROWTYPE; v_order public.owner_subscription_orders%ROWTYPE; v_now timestamptz := now(); v_expires timestamptz; BEGIN IF v_uid IS NULL THEN RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); END IF; SELECT * INTO v_user FROM public.users WHERE id=v_uid FOR UPDATE; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','USER_NOT_FOUND'); END IF; SELECT * INTO v_order FROM public.owner_subscription_orders WHERE status='paid' AND owner_id IS NULL AND lower(trim(checkout_email))=lower(trim(v_user.email)) AND nullif(trim(checkout_phone),'') IS NOT NULL AND nullif(trim(v_user.phone),'') IS NOT NULL AND regexp_replace(checkout_phone,'[^0-9+]','','g')=regexp_replace(v_user.phone,'[^0-9+]','','g') AND (claim_expires_at IS NULL OR claim_expires_at > v_now) ORDER BY paid_at DESC LIMIT 1 FOR UPDATE SKIP LOCKED; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','NO_MATCHING_PAID_WEB_SUBSCRIPTION'); END IF; v_expires := GREATEST(v_now,coalesce(v_user.subscription_expires_at,v_now)) + make_interval(days=>coalesce(v_order.duration_days,CASE WHEN v_order.billing_period='annual' THEN 365 ELSE 30 END)); UPDATE public.owner_subscription_orders SET owner_id=v_uid WHERE id=v_order.id AND owner_id IS NULL; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','SUBSCRIPTION_ALREADY_CLAIMED'); END IF; UPDATE public.users SET role='owner',subscription_plan=v_order.plan_code,subscription_expires_at=v_expires,trial_ends_at=NULL,updated_at=v_now WHERE id=v_uid; RETURN jsonb_build_object('success',true,'order_id',v_order.id,'plan_code',v_order.plan_code,'subscription_expires_at',v_expires); END; $function$
;

-- Function: claim_paid_web_subscription_for_user
CREATE OR REPLACE FUNCTION public.claim_paid_web_subscription_for_user(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user public.users%rowtype;
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz := now();
  v_expires timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_USER_ID');
  END IF;

  -- Caller ownership validation (prevents IDOR)
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id AND NOT public.vsp_is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  SELECT * INTO v_order
  FROM public.owner_subscription_orders
  WHERE status = 'paid'
    AND owner_id IS NULL
    AND lower(trim(checkout_email)) = lower(trim(v_user.email))
    AND nullif(trim(checkout_phone), '') IS NOT NULL
    AND nullif(trim(v_user.phone), '') IS NOT NULL
    AND regexp_replace(checkout_phone, '[^0-9+]', '', 'g') = regexp_replace(v_user.phone, '[^0-9+]', '', 'g')
    AND (claim_expires_at IS NULL OR claim_expires_at > v_now)
  ORDER BY paid_at DESC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_MATCHING_PAID_WEB_SUBSCRIPTION');
  END IF;

  v_expires := greatest(v_now, coalesce(v_user.subscription_expires_at, v_now))
    + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));

  UPDATE public.owner_subscription_orders
  SET owner_id = p_user_id
  WHERE id = v_order.id AND owner_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SUBSCRIPTION_ALREADY_CLAIMED');
  END IF;

  UPDATE public.users
  SET role = CASE WHEN role IN ('admin', 'co_founder') THEN role ELSE 'owner' END,
      subscription_plan = v_order.plan_code,
      subscription_expires_at = v_expires,
      trial_ends_at = NULL,
      updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.notifications(user_id, title, body, type, is_read, metadata, created_at)
  VALUES (
    p_user_id,
    'تم تفعيل اشتراك Pro',
    format('تم ربط اشتراك Pro المدفوع من الموقع بحسابك بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo', 'DD FMMonth YYYY')),
    'subscription_activated',
    false,
    jsonb_build_object('order_id', v_order.id, 'payment_source', v_order.payment_source, 'plan_code', v_order.plan_code, 'gross_amount', v_order.gross_amount),
    v_now
  );

  RETURN jsonb_build_object('success', true, 'order_id', v_order.id, 'plan_code', v_order.plan_code, 'subscription_expires_at', v_expires);
END;
$function$
;

-- Function: cleanup_stale_cron_logs
CREATE OR REPLACE FUNCTION public.cleanup_stale_cron_logs()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Purge execution logs older than 7 days to prevent unbounded table bloat
  DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '7 days';
END;
$function$
;

-- Function: cleanup_stale_pending_bookings_atomic
CREATE OR REPLACE FUNCTION public.cleanup_stale_pending_bookings_atomic(p_user_id uuid, p_stadium_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count integer;
BEGIN
  IF auth.uid() IS NULL OR (auth.uid() <> p_user_id AND coalesce((SELECT role FROM public.users WHERE id = auth.uid()), '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  UPDATE public.bookings
  SET status = 'expired',
      payment_status = 'unpaid',
      cancellation_reason = 'Payment checkout expired',
      updated_at = now()
  WHERE created_by_user_id = p_user_id
    AND stadium_id = p_stadium_id
    AND status = 'pending'
    AND created_at < now() - INTERVAL '10 minutes';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'cancelled_count', v_count);
END;
$function$
;

-- Function: close_matchup_atomic
CREATE OR REPLACE FUNCTION public.close_matchup_atomic(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_results_count int;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,end_time INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can close the matchup'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL THEN RETURN jsonb_build_object('success',true,'already_closed',true,'booking_id',p_booking_id); END IF;
 IF timezone('utc',now())<v_booking.end_time THEN RAISE EXCEPTION 'Cannot close matchup before the scheduled match ends'; END IF;
 SELECT count(*) INTO v_results_count FROM public.matchup_results WHERE booking_id=p_booking_id;
 IF v_results_count=0 THEN RAISE EXCEPTION 'Cannot close matchup without recording at least one match result'; END IF;
 UPDATE public.bookings SET matchup_closed_at=timezone('utc',now()) WHERE id=p_booking_id;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'closed_at',timezone('utc',now()),'total_results_recorded',v_results_count);
END $function$
;

-- Function: close_owner_daily_shift
CREATE OR REPLACE FUNCTION public.close_owner_daily_shift(p_owner_id uuid, p_stadium_id uuid, p_operational_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_updated_count INT := 0;
    v_total_cash_collected NUMERIC := 0;
BEGIN
    IF auth.uid() != p_owner_id AND NOT EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بإجراء تسوية هذا الملعب.';
    END IF;

    WITH updated_rows AS (
        UPDATE public.bookings
        SET 
            is_paid = TRUE,
            payment_status = 'paid',
            deposit_paid = total_price,
            updated_at = NOW()
        WHERE stadium_id = p_stadium_id
          AND owner_id = p_owner_id
          AND (operational_date = p_operational_date OR (operational_date IS NULL AND DATE(start_time AT TIME ZONE 'Africa/Cairo') = p_operational_date))
          AND status != 'cancelled'
          AND (is_paid = FALSE OR payment_status != 'paid')
        RETURNING total_price, deposit_paid
    )
    SELECT 
        COUNT(*),
        COALESCE(SUM(total_price), 0)
    INTO v_updated_count, v_total_cash_collected
    FROM updated_rows;

    RETURN jsonb_build_object(
        'success', true,
        'updated_bookings_count', v_updated_count,
        'total_cash_collected', v_total_cash_collected,
        'message', 'تم تقفيل الوردية بنجاح وتأكيد استلام كامل النقدية.'
    );
END;
$function$
;

-- Function: complete_user_registration
CREATE OR REPLACE FUNCTION public.complete_user_registration(p_user_id uuid DEFAULT NULL::uuid, p_phone text DEFAULT NULL::text, p_name text DEFAULT NULL::text, p_position text DEFAULT NULL::text, p_governorate text DEFAULT NULL::text, p_date_of_birth text DEFAULT NULL::text, p_p2p_instapay text DEFAULT NULL::text, p_p2p_vodafone text DEFAULT NULL::text, p_p2p_bank text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=coalesce(p_user_id,auth.uid());
  v_role text;
  v_updated integer;
begin
  if v_uid is null then return jsonb_build_object('success',false,'error','USER_ID_REQUIRED'); end if;
  if nullif(trim(coalesce(p_date_of_birth,'')),'') is null then
    return jsonb_build_object('success',false,'error','DATE_OF_BIRTH_REQUIRED_18_PLUS');
  end if;
  if not public.vsp_is_adult_date_of_birth(p_date_of_birth) then
    return jsonb_build_object('success',false,'error','VSP_AGE_RESTRICTED');
  end if;
  select role into v_role from public.users where id=v_uid;
  if not found then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;
  if coalesce(auth.role(),'')<>'service_role' and v_uid is distinct from auth.uid() then
    if not public.is_admin_or_cofounder(auth.uid()) then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
  end if;
  if p_phone is not null and exists(select 1 from public.users where phone=p_phone and id<>v_uid) then
    return jsonb_build_object('success',false,'error','PHONE_ALREADY_IN_USE');
  end if;
  perform set_config('vsp.system_override','true',true);
  update public.users
  set phone=coalesce(p_phone,phone),
      name=coalesce(nullif(p_name,''),name),
      position=coalesce(p_position,position,'ST'),
      governorate=coalesce(p_governorate,governorate,'Cairo'),
      date_of_birth=p_date_of_birth,
      p2p_instapay=coalesce(p_p2p_instapay,p2p_instapay),
      p2p_vodafone=coalesce(p_p2p_vodafone,p2p_vodafone),
      p2p_bank=coalesce(p_p2p_bank,p2p_bank),
      is_registration_complete=true,
      is_email_verified=true,
      updated_at=now()
  where id=v_uid;
  get diagnostics v_updated=row_count;
  if v_updated<>1 then return jsonb_build_object('success',false,'error','REGISTRATION_UPDATE_FAILED'); end if;
  return jsonb_build_object('success',true,'message','Registration completed successfully');
end;
$function$
;

-- Function: confirm_1v1_payment_atomic
CREATE OR REPLACE FUNCTION public.confirm_1v1_payment_atomic(p_order_reference text, p_paymob_transaction_id text, p_gross_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_order RECORD;
    v_champ RECORD;
    v_current_count INT;
    v_user RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_gross NUMERIC;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'غير مصرح: يتم تأكيد الطلبات عبر الـ Webhook فقط.');
    END IF;

    IF p_gross_amount IS NULL OR p_gross_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ الدفع الإجمالي الفعلي مطلوب';
    END IF;
    v_gross := round(p_gross_amount, 2);

    SELECT * INTO v_order 
    FROM public.vsp_1v1_tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND', 'message', 'طلب الدفع غير موجود.');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'message', 'تم تأكيد الطلب مسبقاً.');
    END IF;

    SELECT name, profile_image_url, is_blocked, is_debt_blocked INTO v_user 
    FROM public.users 
    WHERE id = v_order.user_id;

    IF COALESCE(v_user.is_blocked, false) = true OR COALESCE(v_user.is_debt_blocked, false) = true THEN
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'failed_user_blocked',
            paymob_transaction_id = p_paymob_transaction_id,
            gross_amount = v_gross,
            updated_at = v_now
        WHERE id = v_order.id;

        RETURN jsonb_build_object(
            'success', false,
            'user_blocked', true,
            'needs_refund', true,
            'order_id', v_order.id,
            'order_reference', p_order_reference,
            'user_id', v_order.user_id,
            'amount', v_order.amount,
            'gross_amount', v_gross,
            'paymob_transaction_id', p_paymob_transaction_id,
            'message', 'حساب اللاعب محظور. تم إرسال أمر استرداد المبلغ.'
        );
    END IF;

    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = v_order.tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'TOURNAMENT_NOT_FOUND', 'message', 'البطولة المرتبطة بالطلب غير موجودة.');
    END IF;

    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = v_order.tournament_id AND payment_status = 'paid';

    IF v_champ.status != 'registration_open' OR v_current_count >= v_champ.target_player_count THEN
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'failed_over_capacity',
            paymob_transaction_id = p_paymob_transaction_id,
            gross_amount = v_gross,
            updated_at = v_now
        WHERE id = v_order.id;

        RETURN jsonb_build_object(
            'success', false,
            'capacity_exceeded', true,
            'needs_refund', true,
            'order_id', v_order.id,
            'order_reference', p_order_reference,
            'user_id', v_order.user_id,
            'tournament_id', v_order.tournament_id,
            'amount', v_order.amount,
            'gross_amount', v_gross,
            'paymob_transaction_id', p_paymob_transaction_id,
            'message', 'اكتملت مقاعد البطولة أثناء إتمام الدفع. تم إرسال أمر استرداد فوري لبوابة Paymob.'
        );
    END IF;

    UPDATE public.vsp_1v1_tournament_orders
    SET payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        gross_amount = v_gross,
        updated_at = v_now
    WHERE id = v_order.id;

    INSERT INTO public.vsp_1v1_tournament_players (
        tournament_id,
        user_id,
        player_name,
        avatar_url,
        tackles,
        goals,
        skills,
        payment_status,
        payment_order_id,
        paid_amount,
        registered_at
    ) VALUES (
        v_order.tournament_id,
        v_order.user_id,
        COALESCE(NULLIF(TRIM(v_user.name), ''), 'لاعب'),
        COALESCE(v_user.profile_image_url, ''),
        0,
        0,
        0,
        'paid',
        v_order.id,
        v_order.amount,
        v_now
    )
    ON CONFLICT (tournament_id, user_id) 
    DO UPDATE SET 
        payment_status = 'paid',
        payment_order_id = EXCLUDED.payment_order_id,
        paid_amount = EXCLUDED.paid_amount,
        registered_at = v_now;

    UPDATE public.vsp_1v1_tournaments
    SET prize_pool = COALESCE(prize_pool, 0) + v_order.amount,
        updated_at = v_now
    WHERE id = v_order.tournament_id;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        v_order.user_id,
        v_order.amount,
        'payment',
        'paymob',
        'completed',
        'رسوم اشتراك بطولة 1v1 - ' || COALESCE(v_champ.name, ''),
        jsonb_build_object(
            'tournament_id', v_order.tournament_id,
            'order_reference', p_order_reference,
            'paymob_transaction_id', p_paymob_transaction_id,
            'gross_amount', v_gross
        ),
        v_now
    );

    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
        v_order.user_id,
        'تأكيد التسجيل في بطولة 1v1 🎉',
        'تم تأكيد دفع رسوم الاشتراك (' || v_order.amount || ' ج.م) وتسجيلك رسمياً في ' || COALESCE(v_champ.name, 'البطولة') || '. حظاً موفقاً!',
        'tournament_update',
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'paid',
        'order_id', v_order.id,
        'tournament_id', v_order.tournament_id,
        'player_user_id', v_order.user_id,
        'amount', v_order.amount,
        'gross_amount', v_gross,
        'new_prize_pool', COALESCE(v_champ.prize_pool, 0) + v_order.amount
    );
END;
$function$
;

-- Function: confirm_cash_booking_atomic
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric, p_collected_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_cash_amount numeric; v_actual_deposit numeric; v_total_price numeric; v_remaining numeric; v_target_status text; v_now timestamptz:=timezone('utc',now());
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder')
  THEN RETURN jsonb_build_object('success',false,'message','غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.'); END IF;
 END IF;
 IF v_booking.status='cancelled' THEN RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي' USING ERRCODE='P0003',DETAIL='BOOKING_CANCELLED'; END IF;
 IF coalesce(v_booking.payment_method,'')<>'cash' THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تأكيد حجز غير نقدي كتحصيل كاش.'); END IF;
 IF v_booking.is_paid IS TRUE AND v_booking.payment_status='paid' THEN
  RETURN jsonb_build_object('success',true,'message','الحجز مؤكد ومسدد بالفعل مسبقاً.','already_confirmed',true,'booking_id',p_booking_id,'amount',0,'commission',0,'total_price',v_booking.total_price,'payment_method',v_booking.payment_method);
 END IF;
 v_total_price:=coalesce(v_booking.total_price,0);
 IF v_total_price<=0 THEN RETURN jsonb_build_object('success',false,'message','قيمة الحجز غير صالحة.'); END IF;
 IF p_total_price IS NOT NULL AND abs(p_total_price-v_total_price)>0.01 THEN RETURN jsonb_build_object('success',false,'message','قيمة الحجز المرسلة لا تطابق القيمة المسجلة.','expected_total_price',v_total_price); END IF;
 v_actual_deposit:=greatest(coalesce(v_booking.deposit_paid,0),0);
 v_remaining:=greatest(round(v_total_price-v_actual_deposit,2),0);
 IF v_remaining<=0 THEN
  UPDATE public.bookings SET is_paid=true,payment_status='paid',status=case when v_now>=end_time then 'completed' else status end,updated_at=v_now WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',0,'deposit_paid',v_actual_deposit,'total_price',v_total_price,'commission',0,'status',case when v_now>=v_booking.end_time then 'completed' else v_booking.status end,'payment_status','paid','already_confirmed',true);
 END IF;
 IF p_collected_amount IS NULL THEN v_cash_amount:=v_remaining; ELSE v_cash_amount:=round(p_collected_amount,2); END IF;
 IF v_cash_amount<=0 OR v_cash_amount>v_remaining THEN RETURN jsonb_build_object('success',false,'message','مبلغ التحصيل النقدي يجب أن يساوي المبلغ المتبقي ولا يتجاوزه.','remaining_amount',v_remaining); END IF;
 IF abs(v_cash_amount-v_remaining)>0.01 THEN RETURN jsonb_build_object('success',false,'message','تأكيد التحصيل لا يتم إلا للمبلغ النقدي المتبقي بالكامل.','remaining_amount',v_remaining); END IF;
 v_target_status:=case when v_now>=v_booking.end_time then 'completed' else 'confirmed' end;
 UPDATE public.bookings SET is_paid=true,payment_status='paid',status=v_target_status,deposit_paid=v_total_price,vsp_commission=0,updated_at=v_now WHERE id=p_booking_id;
 INSERT INTO public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at)
 VALUES(v_booking.owner_id,p_booking_id,v_cash_amount,'cash_settlement','completed','cash','تحصيل كاش مؤكد بالملعب لحجز #'||substring(p_booking_id::text,1,8),v_now,v_now)
 ON CONFLICT (booking_id) WHERE type='cash_settlement' AND status='completed' DO UPDATE SET amount=EXCLUDED.amount,updated_at=v_now;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',v_cash_amount,'deposit_paid',v_total_price,'total_price',v_total_price,'commission',0,'status',v_target_status,'payment_status','paid');
END;$function$
;

-- Function: confirm_cash_booking_atomic
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN public.confirm_cash_booking_atomic(p_booking_id,p_owner_id,p_total_price,NULL);
END;
$function$
;

-- Function: confirm_matchup_atomic
CREATE OR REPLACE FUNCTION public.confirm_matchup_atomic(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_teams_count int;
  v_mode text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User not authenticated';
  END IF;

  SELECT id, created_by_user_id, user_id, status, matchup_closed_at, start_time, end_time
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF coalesce(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
    RAISE EXCEPTION 'Forbidden: Only the booking creator can confirm the matchup';
  END IF;

  IF v_booking.matchup_closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Matchup is already closed';
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RAISE EXCEPTION 'Cannot confirm a cancelled booking';
  END IF;

  IF v_booking.end_time <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'Cannot confirm a matchup after the booking has ended';
  END IF;

  SELECT count(*) INTO v_teams_count
  FROM public.matchup_teams
  WHERE booking_id = p_booking_id;

  IF v_teams_count < 2 THEN
    RAISE EXCEPTION 'Cannot confirm matchup: At least 2 teams must be added';
  END IF;

  v_mode := CASE WHEN v_teams_count = 2 THEN 'duo' ELSE 'winner_stays' END;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET matchup_mode = v_mode,
      updated_at = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'teams_count', v_teams_count,
    'matchup_mode', v_mode
  );
END;
$function$
;

-- Function: confirm_owner_onboarding
CREATE OR REPLACE FUNCTION public.confirm_owner_onboarding(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_user record; v_caller_role text;
begin
  if auth.role() <> 'service_role' then
    if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
    if p_user_id is distinct from auth.uid() then
      select role into v_caller_role from public.users where id=auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
        return jsonb_build_object('success',false,'error','UNAUTHORIZED');
      end if;
    end if;
  end if;
  select id, role, is_onboarding_confirmed into v_user from public.users where id=p_user_id;
  if not found then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;
  if v_user.role <> 'owner' then return jsonb_build_object('success',false,'error','NOT_AN_OWNER'); end if;
  update public.users set is_onboarding_confirmed=true,updated_at=now() where id=p_user_id;
  return jsonb_build_object('success',true);
end; $function$
;

-- Function: confirm_owner_subscription_payment
CREATE OR REPLACE FUNCTION public.confirm_owner_subscription_payment(p_order_id uuid, p_paymob_transaction_id text, p_gross_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz := now();
  v_expires timestamptz;
  v_claim jsonb;
  v_expected_gross numeric;
  v_matched_user public.users%rowtype;
BEGIN
  SELECT * INTO v_order FROM public.owner_subscription_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF v_order.status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_paid', true, 'order_id', p_order_id);
  END IF;
  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_PENDING');
  END IF;

  v_expected_gross := coalesce(v_order.gross_amount, v_order.amount);
  IF abs(coalesce(v_expected_gross, 0) - coalesce(p_gross_amount, 0)) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'AMOUNT_MISMATCH');
  END IF;

  UPDATE public.owner_subscription_orders
  SET status = 'paid', paymob_transaction_id = p_paymob_transaction_id, paid_at = v_now
  WHERE id = p_order_id;

  IF v_order.owner_id IS NOT NULL THEN
    v_expires := greatest(v_now, coalesce((SELECT subscription_expires_at FROM public.users WHERE id = v_order.owner_id), v_now))
      + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));

    UPDATE public.users
    SET role = CASE WHEN role IN ('admin', 'co_founder') THEN role ELSE 'owner' END,
        subscription_plan = v_order.plan_code,
        subscription_expires_at = v_expires,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = v_order.owner_id;

    INSERT INTO public.notifications(user_id, title, body, type, is_read, metadata, created_at)
    VALUES (
      v_order.owner_id,
      'تم تفعيل اشتراك Pro',
      format('تم تأكيد دفع اشتراك Pro بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo', 'DD FMMonth YYYY')),
      'subscription_activated',
      false,
      jsonb_build_object('order_id', v_order.id, 'payment_source', v_order.payment_source, 'plan_code', v_order.plan_code, 'gross_amount', v_order.gross_amount, 'paymob_transaction_id', p_paymob_transaction_id),
      v_now
    );
  ELSE
    -- Web payment without pre-bound owner_id:
    SELECT * INTO v_matched_user
    FROM public.users u
    WHERE lower(trim(u.email)) = lower(trim(v_order.checkout_email))
      AND nullif(trim(u.phone), '') IS NOT NULL
      AND nullif(trim(v_order.checkout_phone), '') IS NOT NULL
      AND regexp_replace(u.phone, '[^0-9+]', '', 'g') = regexp_replace(v_order.checkout_phone, '[^0-9+]', '', 'g')
    ORDER BY u.created_at DESC
    LIMIT 1;

    IF FOUND THEN
      -- Only auto-activate if the user is ALREADY an owner.
      -- Never silently convert an existing player to owner from background web payment alone!
      IF v_matched_user.role = 'owner' THEN
        SELECT public.claim_paid_web_subscription_for_user(v_matched_user.id) INTO v_claim;
      ELSIF v_matched_user.role IN ('admin', 'co_founder') THEN
        v_expires := greatest(v_now, coalesce(v_matched_user.subscription_expires_at, v_now))
          + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));
        UPDATE public.owner_subscription_orders SET owner_id = v_matched_user.id WHERE id = p_order_id;
        UPDATE public.users SET subscription_plan = v_order.plan_code, subscription_expires_at = v_expires, updated_at = v_now WHERE id = v_matched_user.id;
      END IF;
      -- If role is 'player', leave owner_id = null so it must be claimed via verified account claim/signup.
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'already_paid', false, 'order_id', p_order_id,
    'owner_id', (SELECT owner_id FROM public.owner_subscription_orders WHERE id = p_order_id),
    'status', 'paid', 'paid_at', v_now, 'claimed', coalesce(v_claim->>'success', 'false') = 'true'
  );
END;
$function$
;

-- Function: confirm_team_league_match_result
CREATE OR REPLACE FUNCTION public.confirm_team_league_match_result(p_match_id uuid, p_outcome text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_match     RECORD;
  v_user_id   UUID := auth.uid();
  v_winner_id UUID := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_outcome NOT IN ('home_win', 'draw', 'away_win') THEN
    RAISE EXCEPTION 'Invalid outcome. Must be home_win, draw, or away_win';
  END IF;

  SELECT tm.*, c.template_type AS champ_template_type, c.owner_id AS creator_id
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.champ_template_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  IF v_match.creator_id != v_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only the league creator can confirm or resolve match results';
  END IF;

  -- 15-minute hard lock MUST be checked before the state gate.
  -- This ensures an expired confirmed result is persisted as locked.
  IF v_match.result_status = 'locked' OR
     (v_match.result_confirmed_at IS NOT NULL
      AND v_match.result_confirmed_at + INTERVAL '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches
    SET result_status    = 'locked',
        result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;

    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- Both teams must have submitted before creator can act.
  IF v_match.result_status NOT IN ('awaiting_confirmation', 'disputed') THEN
    RAISE EXCEPTION
      'INVALID_STATE: Cannot confirm. Both teams must submit their results first. Current status: %',
      COALESCE(v_match.result_status, 'scheduled');
  END IF;

  IF p_outcome = 'home_win' THEN
    v_winner_id := v_match.home_team_id;
  ELSIF p_outcome = 'away_win' THEN
    v_winner_id := v_match.away_team_id;
  END IF;

  UPDATE public.tournament_matches
  SET result_status       = 'confirmed',
      confirmed_outcome   = p_outcome,
      winner_id           = v_winner_id,
      result_confirmed_at = COALESCE(result_confirmed_at, clock_timestamp()),
      dispute_resolved_at = CASE WHEN v_match.result_status = 'disputed'
                                  THEN clock_timestamp()
                                  ELSE dispute_resolved_at END,
      dispute_resolved_by = CASE WHEN v_match.result_status = 'disputed'
                                  THEN v_user_id
                                  ELSE dispute_resolved_by END,
      status              = 'completed',
      is_completed        = true
  WHERE id = p_match_id;

  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, actor_id, action, payload
  ) VALUES (
    p_match_id,
    v_match.championship_id,
    v_user_id,
    'creator_confirm_result',
    jsonb_build_object(
      'confirmed_outcome', p_outcome,
      'previous_status',   v_match.result_status,
      'winner_id',         v_winner_id
    )
  );

  RETURN jsonb_build_object(
    'success',           true,
    'match_id',          p_match_id,
    'result_status',     'confirmed',
    'confirmed_outcome', p_outcome,
    'winner_id',         v_winner_id
  );
END;
$function$
;

-- Function: confirm_team_league_payment
CREATE OR REPLACE FUNCTION public.confirm_team_league_payment(p_order_reference text, p_paymob_transaction_id text, p_gross_amount_cents integer, p_gateway_type text DEFAULT 'card'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_payment public.team_league_payments%ROWTYPE;
  v_fee RECORD;
  v_gateway_rate NUMERIC;
  v_expected INTEGER;
  v_champ RECORD;
  v_paid TEXT[];
  v_count INTEGER;
  v_gross NUMERIC;
BEGIN
  SELECT * INTO v_payment 
  FROM public.team_league_payments 
  WHERE order_reference = p_order_reference FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'دفع الدوري غير موجود'; END IF;
  IF v_payment.payment_status = 'paid' THEN 
    RETURN jsonb_build_object('success', true, 'already_paid', true); 
  END IF;
  IF v_payment.payment_status <> 'pending' THEN 
    RAISE EXCEPTION 'حالة دفع غير صالحة'; 
  END IF;
  IF p_paymob_transaction_id IS NULL OR TRIM(p_paymob_transaction_id) = '' THEN 
    RAISE EXCEPTION 'رقم عملية الدفع غير صالح'; 
  END IF;

  SELECT booking_vsp_rate, booking_paymob_rate, booking_paymob_local_rate, booking_paymob_wallet_rate, booking_paymob_fixed_fee 
  INTO v_fee 
  FROM public.platform_fee_config 
  WHERE id = 1;

  v_gateway_rate := CASE 
    WHEN lower(COALESCE(p_gateway_type, '')) LIKE '%wallet%' 
    THEN COALESCE(v_fee.booking_paymob_wallet_rate, v_fee.booking_paymob_rate) 
    ELSE COALESCE(v_fee.booking_paymob_local_rate, v_fee.booking_paymob_rate) 
  END;

  v_expected := round((v_payment.amount + v_payment.amount * COALESCE(v_fee.booking_vsp_rate, 0.02) + v_payment.amount * v_gateway_rate + COALESCE(v_fee.booking_paymob_fixed_fee, 3)) * 100);
  IF p_gross_amount_cents <> v_expected THEN 
    RAISE EXCEPTION 'مبلغ دفع الدوري غير مطابق'; 
  END IF;

  v_gross := round((p_gross_amount_cents::numeric / 100.0), 2);

  UPDATE public.team_league_payments 
  SET payment_status = 'paid',
      paymob_transaction_id = p_paymob_transaction_id,
      gross_amount = v_gross,
      paid_at = now(),
      updated_at = now() 
  WHERE id = v_payment.id;

  UPDATE public.championships 
  SET paid_teams = array_append(array_remove(COALESCE(paid_teams, '{}'::TEXT[]), v_payment.team_id::TEXT), v_payment.team_id::TEXT),
      updated_at = now() 
  WHERE id = v_payment.championship_id;

  SELECT * INTO v_champ FROM public.championships WHERE id = v_payment.championship_id FOR UPDATE;
  v_paid := COALESCE(v_champ.paid_teams, '{}'::TEXT[]);
  v_count := cardinality(v_paid);

  IF v_count >= v_champ.max_teams THEN
    PERFORM public.generate_team_league_fixtures(v_champ.id);
  END IF;

  RETURN jsonb_build_object('success', true, 'league_started', v_count >= v_champ.max_teams, 'gross_amount', v_gross);
END;
$function$
;

-- Function: confirm_tournament_order_atomic
CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(p_order_reference text, p_paymob_transaction_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', auth.role(), '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_caller_role     text;
  v_order           RECORD;
  v_champ           RECORD;
  v_joined_count    INT;
  v_roster_id       UUID;
BEGIN
  -- Strict Authorization: Only service_role (e.g. paymob webhook) OR Admin/Co-founder
  -- Classic Security Definer Fix: NEVER use current_user which resolves to 'postgres'
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'تسجيل الدخول مطلوب.');
    END IF;

    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
    IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'UNAUTHORIZED_ADMIN_OR_SERVICE_ROLE_ONLY', 
        'message', 'غير مصرح: تأكيد سداد البطولات مقتصر على السيرفر أو إدارة التطبيق فقط.'
      );
    END IF;
  END IF;

  -- Transaction ID is strictly mandatory
  IF p_paymob_transaction_id IS NULL OR trim(p_paymob_transaction_id) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMOB_TRANSACTION_ID_REQUIRED');
  END IF;

  SELECT * INTO v_order 
  FROM public.tournament_orders 
  WHERE order_reference = p_order_reference 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'tournament_order_not_found');
  END IF;

  -- 1. Idempotent Success
  IF v_order.payment_status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'order_id', v_order.id);
  END IF;

  -- 2. Strict Source Guard: ONLY 'pending' can be confirmed!
  IF v_order.payment_status <> 'pending' THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'invalid_order_status_for_confirmation', 
      'current_status', v_order.payment_status
    );
  END IF;

  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = v_order.championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- If championship was cancelled while payment was pending in gateway
  IF v_champ.status = 'cancelled' THEN
    UPDATE public.tournament_orders
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc', now())
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        registration_status = 'cancelled',
        updated_at = timezone('utc', now())
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at, failure_reason
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      coalesce(nullif(v_order.base_amount,0), v_order.gross_amount), coalesce(v_order.currency, 'EGP'),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'pending' ELSE 'failed_manual_review' END,
      timezone('utc', now()), timezone('utc', now()),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN NULL ELSE 'Missing historical base_amount; manual review required' END
    )
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'championship_cancelled_payment_refunded',
      'needs_refund', true,
      'amount', coalesce(nullif(v_order.base_amount,0),v_order.gross_amount),
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

  -- Capacity & Open Status Check
  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = v_order.championship_id AND registration_status = 'confirmed';

  IF v_champ.status != 'open' OR v_joined_count >= v_champ.max_teams THEN
    UPDATE public.tournament_orders
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'failed_over_capacity' ELSE 'refund_failed_manual_review' END,
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc', now())
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        registration_status = 'rejected',
        notes = 'over_capacity',
        updated_at = timezone('utc', now())
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at, failure_reason
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      coalesce(nullif(v_order.base_amount,0), v_order.gross_amount), coalesce(v_order.currency, 'EGP'),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'pending' ELSE 'failed_manual_review' END,
      timezone('utc', now()), timezone('utc', now()),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN NULL ELSE 'Missing historical base_amount; manual review required' END
    )
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'championship_full_or_closed_refund_queued',
      'needs_refund', true,
      'amount', coalesce(nullif(v_order.base_amount,0),v_order.gross_amount),
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

  -- Transition to Paid
  UPDATE public.tournament_orders
  SET payment_status = 'paid',
      paymob_transaction_id = p_paymob_transaction_id,
      updated_at = timezone('utc', now())
  WHERE id = v_order.id;

  UPDATE public.championship_registrations
  SET registration_status = 'confirmed',
      payment_status = 'paid',
      gross_amount = v_order.gross_amount,
      updated_at = timezone('utc', now())
  WHERE id = v_order.registration_id;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at
  )
  VALUES (
    v_order.registration_id, v_order.championship_id, v_order.team_id,
    to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[])), timezone('utc', now())
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[]))
  RETURNING id INTO v_roster_id;

  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF v_order.player_ids IS NOT NULL AND array_length(v_order.player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(v_order.player_ids);
  END IF;

  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
      prize_pool = coalesce(prize_pool, 0) + coalesce(v_order.base_amount, v_order.amount),
      updated_at = timezone('utc', now())
  WHERE id = v_order.championship_id
    AND NOT (v_order.team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  INSERT INTO public.transactions (
    championship_id, user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
  )
  VALUES (
    v_order.championship_id, v_order.captain_user_id, v_order.gross_amount, 'digital', 'paymob', 'completed',
    'رسوم اشتراك في بطولة: ' || v_champ.name,
    jsonb_build_object(
      'order_id', v_order.id,
      'order_reference', v_order.order_reference,
      'paymob_transaction_id', p_paymob_transaction_id,
      'base_amount', v_order.base_amount,
      'platform_fee_amount', v_order.platform_fee_amount,
      'gateway_fee_amount', v_order.gateway_fee_amount,
      'gross_amount', v_order.gross_amount
    ),
    timezone('utc', now()), timezone('utc', now())
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'payment_status', 'paid',
    'registration_status', 'confirmed',
    'joined_count', v_joined_count + 1
  );
END;
$function$
;

-- Function: create_1v1_payment_order_atomic
CREATE OR REPLACE FUNCTION public.create_1v1_payment_order_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_caller_id uuid:=auth.uid(); v_champ record; v_current_count integer; v_order_id uuid; v_order_ref text; v_existing record; v_player_status text;
begin
 if v_caller_id is null then return jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً للمشاركة.'); end if;
 select * into v_champ from public.vsp_1v1_tournaments where id=p_tournament_id for update;
 if not found then return jsonb_build_object('success',false,'error','البطولة غير موجودة.'); end if;
 if v_champ.status<>'registration_open' then return jsonb_build_object('success',false,'error','التسجيل في هذه البطولة مغلق حالياً.'); end if;
 if coalesce(v_champ.entry_fee,0)<=0 then return jsonb_build_object('success',false,'error','رسوم البطولة غير صالحة حالياً.'); end if;

 select payment_status into v_player_status
 from public.vsp_1v1_tournament_players
 where tournament_id=p_tournament_id and user_id=v_caller_id
 limit 1;

 if v_player_status='paid' then
   return jsonb_build_object('success',false,'already_registered',true,'error','أنت مسجل ودافع بالفعل في هذه البطولة.');
 end if;

 if v_player_status in ('refund_requested','refund_failed_manual_review') then
   return jsonb_build_object('success',false,'refund_pending',true,'error','لديك طلب إلغاء واسترداد قيد المعالجة لهذه البطولة. لا يمكن إعادة التسجيل قبل تسوية طلب الاسترداد.');
 end if;

 select * into v_existing from public.vsp_1v1_tournament_orders
 where tournament_id=p_tournament_id and user_id=v_caller_id and payment_status='pending'
 order by created_at desc limit 1 for update;
 if found then
   return jsonb_build_object('success',true,'existing_order',true,'order_id',v_existing.id,'order_reference',v_existing.order_reference,'amount',v_existing.amount,'tournament_id',p_tournament_id,'tournament_name',v_champ.name);
 end if;

 select count(*) into v_current_count from public.vsp_1v1_tournament_players where tournament_id=p_tournament_id and payment_status='paid';
 if v_current_count>=v_champ.target_player_count then return jsonb_build_object('success',false,'error','عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.'); end if;

 v_order_id:=gen_random_uuid();
 v_order_ref:='TOURN_1V1_'||substring(v_order_id::text,1,8)||'_'||floor(extract(epoch from now()))::bigint;
 insert into public.vsp_1v1_tournament_orders(id,tournament_id,user_id,amount,order_reference,payment_status,created_at,updated_at)
 values(v_order_id,p_tournament_id,v_caller_id,round(v_champ.entry_fee,2),v_order_ref,'pending',timezone('utc',now()),timezone('utc',now()));
 return jsonb_build_object('success',true,'order_id',v_order_id,'order_reference',v_order_ref,'amount',round(v_champ.entry_fee,2),'tournament_id',p_tournament_id,'tournament_name',v_champ.name);
end; $function$
;

-- Function: create_booking_atomic
CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0, p_idempotency_key text DEFAULT NULL::text, p_initial_players integer DEFAULT 1, p_total_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium record;
  v_caller uuid := auth.uid();
  v_caller_role text;
  v_duration_hours numeric;
  v_calculated_price numeric;
  v_hourly_rate numeric;
  v_ball_price numeric := 0;
  v_final_total_price numeric;
  v_final_needs_deposit boolean;
  v_final_deposit_amount numeric;
  v_final_deposit_paid numeric := 0;
  v_final_status text;
  v_final_is_paid boolean;
  v_locked_until timestamptz;
  v_active_cash_count int := 0;
  v_conflict_count int := 0;
  v_user_blocked boolean;
  v_no_show_count int;
  v_new_booking_id uuid;
  v_existing_id uuid;
  v_existing_status text;
  v_now timestamptz := timezone('utc', now());
  v_initial_players int;
  v_capacity int;
  v_raw_type text;
  v_normalized_type text;
BEGIN
  v_raw_type := lower(trim(coalesce(p_booking_type,'')));
  IF v_raw_type='openjoin' THEN v_raw_type:='open_join'; END IF;

  IF v_raw_type NOT IN ('personal','open_join','challenge') THEN
    RETURN jsonb_build_object('success',false,'code','INVALID_BOOKING_TYPE','message','نوع الحجز غير صالح.');
  END IF;

  IF v_raw_type='challenge' THEN
    RETURN jsonb_build_object('success',false,'code','USE_CHALLENGE_RPC','message','حجوزات التحدي تتم عبر create_challenge_booking_atomic فقط.');
  END IF;

  v_normalized_type:=v_raw_type;

  IF v_caller IS NULL AND current_user NOT IN ('postgres','service_role') THEN
    RETURN jsonb_build_object('success',false,'message','يجب تسجيل الدخول أولاً.');
  END IF;

  IF v_caller IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller;
    IF v_caller::text<>p_user_id
       AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin')
       AND current_user NOT IN ('postgres','service_role') THEN
      RETURN jsonb_build_object('success',false,'message','غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id,status INTO v_existing_id,v_existing_status
    FROM public.bookings
    WHERE idempotency_key=p_idempotency_key AND status<>'cancelled'
    LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success',true,'booking_id',v_existing_id,'status',v_existing_status,'idempotent',true);
    END IF;
  END IF;

  v_duration_hours:=extract(epoch from(p_end_time-p_start_time))/3600.0;
  IF v_duration_hours<=0 THEN
    RETURN jsonb_build_object('success',false,'message','وقت بداية ونهاية الحجز غير صالح.');
  END IF;

  IF v_duration_hours<((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id=1)/60.0)
     OR v_duration_hours>(SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id,0));

  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text=p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الملعب المطلوب غير موجود.'); END IF;
  IF v_stadium.is_deleted_by_owner THEN RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب محذوف.'); END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;


  IF NOT public.vsp_validate_stadium_booking_window(
    v_stadium.opening_time,
    v_stadium.closing_time,
    v_stadium.break_start_time,
    v_stadium.break_end_time,
    v_stadium.is_split_shift,
    v_stadium.maintenance_until,
    p_start_time,
    p_end_time
  ) THEN
    RETURN jsonb_build_object(
      'success',false,
      'code','OUTSIDE_OPERATING_HOURS',
      'message','موعد الحجز خارج ساعات تشغيل الملعب أو يتعارض مع فترة التوقف أو الصيانة.'
    );
  END IF;



  SELECT is_blocked,coalesce(no_show_count,0)
  INTO v_user_blocked,v_no_show_count
  FROM public.users WHERE id::text=p_user_id;

  IF coalesce(v_user_blocked,false) THEN
    RETURN jsonb_build_object('success',false,'message','حسابك مقيد حالياً.');
  END IF;

  IF lower(coalesce(p_payment_method,''))='cash'
     AND v_no_show_count>=(SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','حسابك مقيد عن الحجز النقدي.');
  END IF;

  SELECT COUNT(*) INTO v_active_cash_count
  FROM public.bookings
  WHERE (user_id::text=p_user_id OR created_by_user_id::text=p_user_id)
    AND lower(coalesce(payment_method,''))='cash'
    AND status IN('pending','confirmed')
    AND coalesce(is_paid,false)=false
    AND end_time>v_now;

  IF lower(coalesce(p_payment_method,''))='cash' AND v_active_cash_count>0 THEN
    RETURN jsonb_build_object(
      'success',false,'code','ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online',true,
      'message','لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.'
    );
  END IF;

  v_final_needs_deposit:=coalesce(v_stadium.needs_deposit,false);
  v_final_deposit_amount:=case when v_final_needs_deposit then coalesce(v_stadium.deposit_amount,0) else 0 end;

  -- A stadium that requires an upfront deposit must never allow a cash booking.
  -- The deposit is an online prepayment requirement; the server is authoritative.
  IF lower(coalesce(p_payment_method,''))='cash'
     AND v_final_needs_deposit
     AND v_final_deposit_amount > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ONLINE_DEPOSIT_REQUIRED',
      'requires_online_deposit', true,
      'deposit_amount', v_final_deposit_amount,
      'message', 'هذا الملعب يتطلب دفع العربون إلكترونياً لتأكيد الحجز.'
    );
  END IF;
  v_hourly_rate:=coalesce(v_stadium.price_per_hour,v_stadium.base_price,0);
  v_calculated_price:=round(v_hourly_rate*v_duration_hours,2);

  IF p_rent_ball THEN
    BEGIN
      v_ball_price:=coalesce((v_stadium.features->>'ballPrice')::numeric,0);
    EXCEPTION WHEN OTHERS THEN
      v_ball_price:=0;
    END;
    v_calculated_price:=v_calculated_price+v_ball_price;
  END IF;

  IF v_calculated_price<=0 THEN
    RETURN jsonb_build_object('success',false,'message','تسعيرة الملعب غير صحيحة.');
  END IF;

  v_final_total_price:=v_calculated_price;

  IF lower(coalesce(p_payment_method,'')) IN ('paymob','card','wallet','online') THEN
    v_final_status:='pending';
    v_final_is_paid:=false;
    v_locked_until:=v_now+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval;
  ELSE
    v_final_status:='confirmed';
    v_final_is_paid:=false;
    v_locked_until:=NULL;
  END IF;

  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text=p_stadium_id AND status<>'cancelled'
    AND NOT(status='pending' AND coalesce(locked_until,created_at+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval)<v_now)
    AND p_start_time<end_time AND p_end_time>start_time;

  IF v_conflict_count>0 THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، هذا الموعد محجوز أو قيد الدفع من لاعب آخر حالياً.');
  END IF;

  IF v_normalized_type='open_join' THEN
    v_initial_players:=coalesce(p_initial_players,1);

    IF v_initial_players<1 THEN
      RETURN jsonb_build_object('success',false,'code','INVALID_INITIAL_PLAYERS','message','عدد اللاعبين المبدئي يجب أن يكون 1 على الأقل.');
    END IF;

    v_capacity:=v_stadium.total_field_capacity;

    IF v_capacity IS NULL OR v_capacity<1 THEN
      RETURN jsonb_build_object('success',false,'code','STADIUM_CAPACITY_NOT_CONFIGURED','message','هذا الملعب لا تتوفر له سعة محددة. لا يمكن إنشاء الحجز التجميعي حتى يقوم المالك بتحديد السعة.');
    END IF;

    IF v_initial_players>v_capacity THEN
      RETURN jsonb_build_object('success',false,'code','INITIAL_PLAYERS_EXCEED_CAPACITY','message','عدد اللاعبين المبدئي ('||v_initial_players||') لا يمكن أن يتجاوز سعة الملعب ('||v_capacity||').');
    END IF;
  ELSE
    v_initial_players:=1;
    v_capacity:=NULL;
  END IF;

  INSERT INTO public.bookings(
    stadium_id,user_id,created_by_user_id,owner_id,
    start_time,end_time,booking_type,total_price,vsp_commission,gateway_fee,platform_fee,
    stadium_name,stadium_image_url,is_private,rent_ball,
    needs_deposit,deposit_amount,deposit_paid,
    payment_method,payment_status,status,is_paid,
    player_team_id,player_team_name,opponent_team_id,opponent_team_name,challenge_status,
    joined_user_ids,current_players,initial_players_count,manual_player_count,total_field_capacity,
    locked_until,idempotency_key,created_at,updated_at
  ) VALUES(
    p_stadium_id::uuid,p_user_id::uuid,p_user_id::uuid,v_stadium.owner_id,
    p_start_time,p_end_time,v_normalized_type,
    v_final_total_price,0,0,0,
    v_stadium.name,v_stadium.image_url,
    case when v_normalized_type='open_join' then true else p_is_private end,
    p_rent_ball,
    v_final_needs_deposit,v_final_deposit_amount,v_final_deposit_paid,
    lower(coalesce(p_payment_method,'cash')),'pending',v_final_status,v_final_is_paid,
    case when p_player_team_id~'^[0-9a-fA-F-]{36}$' then p_player_team_id::uuid else null end,
    p_player_team_name,
    case when p_opponent_team_id~'^[0-9a-fA-F-]{36}$' then p_opponent_team_id::uuid else null end,
    p_opponent_team_name,
    null,
    ARRAY[p_user_id::uuid],
    v_initial_players,
    v_initial_players,
    case when v_normalized_type='open_join' then greatest(v_initial_players-1,0) else 0 end,
    v_capacity,
    v_locked_until,p_idempotency_key,v_now,v_now
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success',true,
    'booking_id',v_new_booking_id,
    'status',v_final_status,
    'total_price',v_final_total_price,
    'needs_deposit',v_final_needs_deposit,
    'deposit_amount',v_final_deposit_amount,
    'initial_players',v_initial_players,
    'manual_player_count',case when v_normalized_type='open_join' then greatest(v_initial_players-1,0) else 0 end,
    'total_capacity',v_capacity,
    'requires_full_online',(v_active_cash_count>0 AND lower(coalesce(p_payment_method,'')) IN ('paymob','card','wallet','online')),
    'locked_until',v_locked_until
  );
EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$
;

-- Function: create_challenge_booking_atomic
CREATE OR REPLACE FUNCTION public.create_challenge_booking_atomic(p_challenge_code text, p_stadium_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_payment_method text DEFAULT 'cash'::text, p_rent_ball boolean DEFAULT false, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller                 uuid := auth.uid();
  v_caller_role            text;
  v_caller_team            record;
  v_code_entry             record;
  v_opponent_team          record;
  v_stadium                record;
  v_duration_hours         numeric;
  v_hourly_rate            numeric;
  v_price                  numeric;
  v_ball_price             numeric := 0;
  v_final_status           text;
  v_final_challenge_status text;
  v_final_is_paid          boolean;
  v_locked_until           timestamptz;
  v_conflict_count         int;
  v_active_cash_cnt        int := 0;
  v_user_blocked           boolean;
  v_no_show_count          int;
  v_new_booking_id         uuid;
  v_new_code               text;
  v_new_code_id            uuid;
  v_existing_id            uuid;
  v_existing_status        text;
  v_existing_user_id       uuid;
  v_clean_code             text;
  v_now                    timestamptz := timezone('utc', now());
BEGIN
  -- 1. Authentication check
  IF v_caller IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED',
      'message', 'يجب تسجيل الدخول أولاً.');
  END IF;

  -- 2. Strengthened User-Scoped Idempotency protection
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT id, status, user_id INTO v_existing_id, v_existing_status, v_existing_user_id
    FROM public.bookings
    WHERE idempotency_key = trim(p_idempotency_key) AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      IF v_existing_user_id IS NOT NULL AND v_caller IS NOT NULL AND v_existing_user_id <> v_caller THEN
        RETURN jsonb_build_object(
          'success', false,
          'error',   'IDEMPOTENCY_KEY_COLLISION',
          'message', 'مفتاح العملية غير صالح أو مستخدم مسبقاً لحساب آخر.'
        );
      END IF;

      RETURN jsonb_build_object(
        'success',     true,
        'booking_id',  v_existing_id,
        'status',      v_existing_status,
        'idempotent',  true
      );
    END IF;
  END IF;

  -- Normalize challenge code (strip 'VSP-' prefix if provided)
  v_clean_code := upper(trim(COALESCE(p_challenge_code, '')));
  IF v_clean_code LIKE 'VSP-%' THEN
    v_clean_code := substring(v_clean_code from 5);
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_CHALLENGE_CODE',
      'message', 'يرجى إدخال كود التحدي.');
  END IF;

  -- 3. Verify caller is a captain of an active team
  SELECT t.* INTO v_caller_team 
  FROM public.teams t 
  WHERE t.captain_id = v_caller 
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN',
      'message', 'يجب أن تكون كابتن فريق لإنشاء حجز تحدي.');
  END IF;

  -- 4. Verify & lock challenge code (match either raw code or with prefix)
  SELECT * INTO v_code_entry
  FROM public.team_challenge_codes
  WHERE (code = v_clean_code OR code = 'VSP-' || v_clean_code) AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_INVALID_OR_USED',
      'message', 'كود التحدي غير صالح أو تم استخدامه مسبقاً.');
  END IF;

  IF v_code_entry.expires_at IS NOT NULL AND v_code_entry.expires_at < v_now THEN
    UPDATE public.team_challenge_codes SET status = 'expired' WHERE id = v_code_entry.id;
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_EXPIRED',
      'message', 'كود التحدي منتهي الصلاحية.');
  END IF;

  -- 5. Opponent team validation & Server-Side Eligibility
  SELECT * INTO v_opponent_team FROM public.teams WHERE id = v_code_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NOT_FOUND',
      'message', 'تعذر العثور على الفريق صاحب الكود.');
  END IF;

  IF v_caller_team.id = v_opponent_team.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM',
      'message', 'لا يمكنك تحدي فريقك نفسه.');
  END IF;

  -- Server-Side FairPlay Eligibility (attendance_score >= 40)
  IF COALESCE(v_caller_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'فريقك مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  IF COALESCE(v_opponent_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'الفريق المنافس مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  -- 6. Platform business rules: Duration check
  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TIME_RANGE',
      'message', 'وقت بداية ونهاية الحجز غير صالح.');
  END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DURATION',
      'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  -- 7. Advisory lock per stadium to serialize slot bookings
  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  -- 8. Validate stadium
  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_FOUND',
      'message', 'الملعب المطلوب غير موجود.');
  END IF;
  IF COALESCE(v_stadium.is_deleted_by_owner, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_DELETED',
      'message', 'عذراً، هذا الملعب محذوف.');
  END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE',
      'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;

  -- 9. User Account & Cash Rules (Same SSOT as create_booking_atomic)
  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id = v_caller;
  IF COALESCE(v_user_blocked, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_BLOCKED',
      'message', 'حسابك مقيد حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash'
     AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'CASH_LIMIT_EXCEEDED',
      'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
  END IF;

  -- Cash policy: Only UNPAID active cash bookings block a new cash booking
  SELECT COUNT(*) INTO v_active_cash_cnt
  FROM public.bookings
  WHERE (user_id = v_caller OR created_by_user_id = v_caller)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') 
    AND COALESCE(is_paid, false) = false
    AND end_time > v_now;

  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash' AND v_active_cash_cnt > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.');
  END IF;

  -- 10. Authoritative Server-Side Pricing
  v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
  v_price := ROUND(v_hourly_rate * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_price := v_price + v_ball_price;
  END IF;
  IF v_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_PRICE_NOT_SET',
      'message', 'تسعيرة الملعب غير صحيحة.');
  END IF;

  -- 11. Slot conflict check
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval) < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع حالياً.');
  END IF;

  -- 12. Status and Payment Lock Window: Perfect SSOT State Alignment
  IF lower(COALESCE(p_payment_method, 'cash')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status           := 'pending';
    v_final_challenge_status := 'ready';       -- Ready, awaiting payment confirmation
    v_final_is_paid          := false;
    v_locked_until           := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status           := 'confirmed';
    v_final_challenge_status := 'confirmed';   -- Confirmed immediately for cash
    v_final_is_paid          := false;
    v_locked_until           := NULL;
  END IF;

  -- 13. Insert Booking (Player counters are strictly NULL for Challenge matches)
  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type,
    total_price, platform_fee, vsp_commission, gateway_fee,
    stadium_name, stadium_image_url,
    is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    challenge_status,
    joined_user_ids, current_players, initial_players_count, total_field_capacity,
    locked_until, idempotency_key,
    created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, v_caller, v_caller, v_stadium.owner_id,
    p_start_time, p_end_time, 'challenge',
    v_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    true, p_rent_ball,
    COALESCE(v_stadium.needs_deposit, false),
    CASE WHEN COALESCE(v_stadium.needs_deposit, false) THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END,
    0,
    lower(COALESCE(p_payment_method, 'cash')), 'pending',
    v_final_status, v_final_is_paid,
    v_caller_team.id, v_caller_team.name,
    v_opponent_team.id, v_opponent_team.name,
    v_final_challenge_status,
    ARRAY[v_caller], NULL, NULL, NULL,
    v_locked_until, p_idempotency_key,
    v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  -- 14. Consume challenge code
  UPDATE public.team_challenge_codes
  SET status = 'used', used_at = v_now, used_in_booking_id = v_new_booking_id
  WHERE id = v_code_entry.id;

  -- 15. Generate fresh replacement challenge code for opponent team with 7-day expiration
  v_new_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at, expires_at)
  VALUES (v_opponent_team.id, v_new_code, 'active', v_now, v_now + INTERVAL '7 days')
  RETURNING id INTO v_new_code_id;

  RETURN jsonb_build_object(
    'success',            true,
    'booking_id',         v_new_booking_id,
    'status',             v_final_status,
    'challenge_status',   v_final_challenge_status,
    'total_price',        v_price,
    'player_team_id',     v_caller_team.id,
    'player_team_name',   v_caller_team.name,
    'opponent_team_id',   v_opponent_team.id,
    'opponent_team_name', v_opponent_team.name,
    'new_opponent_code',  v_new_code,
    'locked_until',       v_locked_until
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$
;

-- Function: create_championship_atomic
CREATE OR REPLACE FUNCTION public.create_championship_atomic(p_name text, p_stadium_id uuid, p_type text, p_sport_type text, p_entry_fee numeric, p_grand_prize numeric, p_max_teams integer, p_min_players_per_team integer, p_max_players_per_team integer, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_registration_closes_at timestamp with time zone, p_rules text DEFAULT ''::text, p_logo_url text DEFAULT ''::text, p_currency text DEFAULT 'EGP'::text, p_settings jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_is_admin BOOLEAN := false;
  v_stadium RECORD;
  v_champ_id UUID;
  v_reg_deadline TIMESTAMPTZ;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
  v_is_admin := v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder');

  -- 1. Stadium Validation
  SELECT id, owner_id, is_blocked, is_deleted_by_owner, maintenance_until, governorate, city
  INTO v_stadium
  FROM public.stadiums
  WHERE id = p_stadium_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'stadium_not_found');
  END IF;

  IF v_stadium.owner_id != v_caller_id AND NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_stadium_owner');
  END IF;

  IF coalesce(v_stadium.is_blocked, false) = true OR coalesce(v_stadium.is_deleted_by_owner, false) = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'stadium_not_available');
  END IF;

  -- Maintenance check
  IF v_stadium.maintenance_until IS NOT NULL AND v_stadium.maintenance_until > now() THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'stadium_under_maintenance',
      'maintenance_until', v_stadium.maintenance_until
    );
  END IF;

  -- 2. Parameters Validation
  IF trim(coalesce(p_name, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_name_required');
  END IF;

  IF p_max_teams < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_max_teams');
  END IF;

  IF p_min_players_per_team < 1 OR p_max_players_per_team < p_min_players_per_team THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_player_limits');
  END IF;

  IF coalesce(p_entry_fee, 0) < 0 OR coalesce(p_grand_prize, 0) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_financial_amounts');
  END IF;

  IF p_start_date >= p_end_date THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_championship_dates');
  END IF;

  v_reg_deadline := coalesce(p_registration_closes_at, p_start_date);
  -- Strict validation: Reject if registration closes after start_date
  IF v_reg_deadline > p_start_date THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_registration_deadline');
  END IF;

  -- 3. Stadium Scheduling Overlap Check
  IF EXISTS (
    SELECT 1 FROM public.championships
    WHERE stadium_id = p_stadium_id
      AND status IN ('open', 'ongoing')
      AND (start_date, end_date) OVERLAPS (p_start_date, p_end_date)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'stadium_has_overlapping_championship');
  END IF;

  INSERT INTO public.championships (
    name, stadium_id, owner_id, type, sport_type,
    entry_fee, grand_prize, currency, max_teams,
    min_players_per_team, max_players_per_team,
    start_date, end_date, registration_closes_at,
    rules, logo_url, governorate, status,
    is_approved, creation_fee_paid, settings,
    joined_teams, paid_teams, created_at, updated_at
  )
  VALUES (
    p_name, p_stadium_id, v_caller_id, coalesce(p_type, 'cup'), coalesce(p_sport_type, 'football'),
    round(coalesce(p_entry_fee, 0), 2), round(coalesce(p_grand_prize, 0), 2), coalesce(p_currency, 'EGP'), p_max_teams,
    p_min_players_per_team, p_max_players_per_team,
    p_start_date, p_end_date, v_reg_deadline,
    coalesce(p_rules, ''), coalesce(p_logo_url, ''), coalesce(v_stadium.governorate, ''), 'open',
    v_is_admin, false, coalesce(p_settings, '{}'::jsonb),
    ARRAY[]::TEXT[], ARRAY[]::TEXT[], now(), now()
  )
  RETURNING id INTO v_champ_id;

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', v_champ_id,
    'status', 'open',
    'effective_phase', CASE WHEN v_is_admin THEN 'registration_open' ELSE 'draft' END
  );
END;
$function$
;

-- Function: create_direct_chat_atomic
CREATE OR REPLACE FUNCTION public.create_direct_chat_atomic(p_other_user_id uuid, p_context_type text, p_context_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_booking public.bookings%rowtype;
  v_champ public.championships%rowtype;
  v_existing public.conversations%rowtype;
  v_conv public.conversations%rowtype;
  v_end timestamptz;
  v_type text := lower(trim(coalesce(p_context_type,'')));
begin
  if v_uid is null or coalesce(auth.role(),'') <> 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if p_other_user_id is null or p_other_user_id=v_uid then raise exception 'INVALID_CHAT_PARTICIPANT'; end if;
  if v_type not in ('booking','match','challenge','tournament') or p_context_id is null then raise exception 'INVALID_CHAT_CONTEXT'; end if;
  if are_users_blocked(v_uid,p_other_user_id) then raise exception 'CHAT_BLOCKED'; end if;

  if v_type in ('booking','match','challenge') then
    select * into v_booking from public.bookings where id=p_context_id;
    if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
    if v_type='match' and not (v_booking.booking_type='open_join') then raise exception 'INVALID_MATCH_CONTEXT'; end if;
    if v_type='challenge' and v_booking.booking_type<>'challenge' then raise exception 'INVALID_CHALLENGE_CONTEXT'; end if;

    if not (
      public.vsp_user_is_booking_participant(p_context_id,v_uid)
      and public.vsp_user_is_booking_participant(p_context_id,p_other_user_id)
    ) then raise exception 'CHAT_RELATIONSHIP_REQUIRED'; end if;

    v_end:=v_booking.end_time;

    select * into v_existing
    from public.conversations
    where type='direct'
      and booking_id=p_context_id
      and context_type=v_type
      and context_id=p_context_id
      and cardinality(participant_ids)=2
      and participant_ids @> array[v_uid,p_other_user_id]::uuid[]
    limit 1;
  else
    select * into v_champ from public.championships where id=p_context_id;
    if not found then raise exception 'TOURNAMENT_NOT_FOUND'; end if;
    if not (
      public.vsp_user_is_tournament_participant(p_context_id,v_uid)
      and public.vsp_user_is_tournament_participant(p_context_id,p_other_user_id)
    ) then raise exception 'CHAT_RELATIONSHIP_REQUIRED'; end if;

    v_end:=v_champ.end_date;

    select * into v_existing
    from public.conversations
    where type='direct'
      and booking_id is null
      and context_type='tournament'
      and context_id=p_context_id
      and cardinality(participant_ids)=2
      and participant_ids @> array[v_uid,p_other_user_id]::uuid[]
    limit 1;
  end if;

  if v_existing.id is not null then return to_jsonb(v_existing); end if;

  if v_end is null or v_now > v_end + interval '7 days' then
    raise exception 'CHAT_READ_ONLY';
  end if;

  insert into public.conversations(
    type,booking_id,context_type,context_id,participant_ids,title,unread_counts,created_at,updated_at
  )
  values(
    'direct',
    case when v_type='tournament' then null else p_context_id end,
    v_type,p_context_id,array[v_uid,p_other_user_id]::uuid[],'Direct Chat',
    jsonb_build_object(v_uid::text,0,p_other_user_id::text,0),v_now,v_now
  )
  returning * into v_conv;

  return to_jsonb(v_conv);
end;
$function$
;

-- Function: create_owner_on_behalf
CREATE OR REPLACE FUNCTION public.create_owner_on_behalf(p_email text, p_password text, p_name text, p_phone text, p_governorate text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  new_user_id UUID;
  v_is_admin BOOLEAN := FALSE;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
  ) INTO v_is_admin;

  IF NOT v_is_admin AND current_setting('request.jwt.claims', true)::json->>'role' != 'service_role' THEN
    RAISE EXCEPTION 'غير مصرح لك بإجراء هذه العملية.';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmed_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
    p_email, crypt(p_password, gen_salt('bf')), NOW(),
    '{"provider": "email", "providers": ["email"]}',
    json_build_object('role', 'owner', 'name', p_name, 'phone', p_phone),
    NOW(), NOW(), NOW()
  ) RETURNING id INTO new_user_id;

  INSERT INTO public.users (
    id, email, role, name, phone, is_email_verified, is_identity_verified,
    is_registration_complete, governorate, created_at, updated_at, verification_status
  ) VALUES (
    new_user_id, p_email, 'owner', p_name, p_phone, true, true, true, p_governorate, NOW(), NOW(), 'approved'
  );

  RETURN new_user_id;
END;
$function$
;

-- Function: create_owner_subscription_order
CREATE OR REPLACE FUNCTION public.create_owner_subscription_order(p_plan_code text, p_billing_period text DEFAULT 'monthly'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_uid uuid:=auth.uid(); v_plan record; v_amount numeric; v_days integer; v_order_id uuid; BEGIN IF v_uid IS NULL THEN RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); END IF; IF p_plan_code='basic' THEN RETURN jsonb_build_object('success',false,'error','BASIC_IS_FREE','message','الباقة الأساسية مجانية بالكامل ولا تتطلب دفع إلكتروني'); END IF; SELECT * INTO v_plan FROM public.subscription_plans WHERE code=p_plan_code AND is_active=true; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','PLAN_NOT_FOUND'); END IF; IF p_billing_period='annual' THEN v_amount:=v_plan.yearly_price; v_days:=365; ELSE v_amount:=v_plan.monthly_price; v_days:=30; END IF; IF v_amount<=0 THEN RETURN jsonb_build_object('success',false,'error','INVALID_PAID_AMOUNT'); END IF; INSERT INTO public.owner_subscription_orders(owner_id,plan_code,billing_period,amount,duration_days,status,payment_source) VALUES(v_uid,p_plan_code,p_billing_period,v_amount,v_days,'pending','app') RETURNING id INTO v_order_id; RETURN jsonb_build_object('success',true,'order_id',v_order_id,'amount',v_amount,'plan_code',p_plan_code,'billing_period',p_billing_period,'duration_days',v_days); END; $function$
;

-- Function: create_report_atomic
CREATE OR REPLACE FUNCTION public.create_report_atomic(p_target_type text, p_target_id uuid, p_reason text, p_details text DEFAULT NULL::text, p_context_type text DEFAULT NULL::text, p_context_id uuid DEFAULT NULL::uuid, p_booking_id uuid DEFAULT NULL::uuid, p_conversation_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_target_type text := lower(trim(coalesce(p_target_type,'')));
  v_context_type text := nullif(lower(trim(coalesce(p_context_type,''))),'');
  v_report public.reports%rowtype;
  v_booking_id uuid;
begin
  if v_uid is null or coalesce(auth.role(),'') <> 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if v_target_type not in ('user','booking','match') then raise exception 'INVALID_REPORT_TARGET'; end if;
  if p_target_id is null or nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'INVALID_REPORT'; end if;
  if p_booking_id is not null then
    v_booking_id := p_booking_id;
  elsif v_context_type in ('booking','match','challenge') then
    v_booking_id := p_context_id;
  end if;

  if v_booking_id is null or not public.vsp_user_is_booking_participant(v_booking_id,v_uid) then
    raise exception 'REPORT_BOOKING_CONTEXT_REQUIRED';
  end if;

  if v_context_type is not null and v_context_type not in ('booking','match','challenge','tournament','refund','report') then
    raise exception 'INVALID_REPORT_CONTEXT';
  end if;

  if v_target_type='user' then
    if not exists(select 1 from public.users u where u.id=p_target_id) then raise exception 'REPORT_TARGET_USER_NOT_FOUND'; end if;
    if p_target_id=v_uid then raise exception 'INVALID_REPORT_TARGET'; end if;
    if not public.vsp_user_is_booking_participant(v_booking_id,p_target_id) then
      raise exception 'REPORT_TARGET_NOT_IN_BOOKING';
    end if;
  elsif v_target_type in ('booking','match') then
    if not exists(select 1 from public.bookings b where b.id=p_target_id) then raise exception 'REPORT_TARGET_BOOKING_NOT_FOUND'; end if;
    if p_target_id<>v_booking_id then raise exception 'REPORT_TARGET_CONTEXT_MISMATCH'; end if;
  end if;

  if p_conversation_id is not null and not exists(
    select 1 from public.conversations c
    where c.id=p_conversation_id and v_uid=any(c.participant_ids)
  ) then raise exception 'REPORT_CONVERSATION_ACCESS_DENIED'; end if;

  insert into public.reports(
    reporter_id,target_id,target_type,reason,details,status,created_at,
    context_type,context_id,booking_id,conversation_id
  )
  values(
    v_uid,p_target_id::text,v_target_type,trim(p_reason),nullif(trim(p_details),''),
    'pending',timezone('utc',now()),v_context_type,coalesce(p_context_id,v_booking_id),v_booking_id,p_conversation_id
  )
  returning * into v_report;

  return to_jsonb(v_report);
end;
$function$
;

-- Function: create_support_ticket_atomic
CREATE OR REPLACE FUNCTION public.create_support_ticket_atomic(p_subject text, p_category text, p_context_type text DEFAULT NULL::text, p_context_id uuid DEFAULT NULL::uuid, p_booking_id uuid DEFAULT NULL::uuid, p_priority text DEFAULT 'normal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_category text := trim(coalesce(p_category,'general'));
  v_subject text := trim(coalesce(p_subject,'VSP Support'));
  v_priority text := lower(trim(coalesce(p_priority,'normal')));
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF length(v_subject)=0 THEN RAISE EXCEPTION 'SUBJECT_REQUIRED'; END IF;
  IF v_priority NOT IN ('low','normal','high','urgent') THEN v_priority := 'normal'; END IF;

  IF p_booking_id IS NOT NULL AND NOT public.vsp_user_is_booking_participant(p_booking_id,v_uid) THEN
    RAISE EXCEPTION 'SUPPORT_CONTEXT_ACCESS_DENIED';
  END IF;

  INSERT INTO public.support_tickets(
    requester_id, subject, category, status, priority,
    context_type, context_id, booking_id, source, created_at, updated_at, last_message_at
  )
  VALUES(
    v_uid, v_subject, v_category, 'open', v_priority,
    p_context_type, p_context_id, p_booking_id, 'in_app',
    timezone('utc',now()), timezone('utc',now()), timezone('utc',now())
  )
  RETURNING * INTO v_ticket;

  RETURN to_jsonb(v_ticket);
END;
$function$
;

-- Function: create_team_atomic
CREATE OR REPLACE FUNCTION public.create_team_atomic(p_data jsonb, p_member_uids uuid[] DEFAULT ARRAY[]::uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_team_id uuid;
  v_caller uuid := auth.uid();
  v_count int;
  v_name text;
  v_captain_governorate text;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  v_count := coalesce(array_length(p_member_uids, 1), 0);
  v_name := trim(coalesce(p_data->>'name', ''));

  IF v_count < 1 OR v_count > 12 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team members must be between 1 and 12');
  END IF;

  IF cardinality(ARRAY(SELECT DISTINCT x FROM unnest(p_member_uids) x)) <> v_count THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate team member');
  END IF;

  IF p_member_uids[1] <> v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the captain can create the team');
  END IF;

  IF v_name = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team name is required');
  END IF;

  SELECT governorate
    INTO v_captain_governorate
  FROM public.users
  WHERE id = v_caller;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'يجب تحديد محافظة الكابتن قبل إنشاء الفريق.'
    );
  END IF;

  IF (SELECT count(*) FROM public.users WHERE id = ANY(p_member_uids)) <> v_count THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_TEAM_MEMBER',
      'message', 'أحد اللاعبين غير موجود في النظام.'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = ANY(p_member_uids)
      AND (
        u.governorate IS NULL
        OR btrim(u.governorate) = ''
        OR lower(btrim(u.governorate)) <> lower(btrim(v_captain_governorate))
      )
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TEAM_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن إنشاء الفريق لأن جميع اللاعبين يجب أن يكونوا من نفس محافظة الكابتن.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.teams
    WHERE lower(trim(name)) = lower(v_name)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team name already exists');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.team_members
    WHERE user_id = ANY(p_member_uids)
    GROUP BY user_id
    HAVING count(*) >= 3
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'A player has reached the maximum of 3 teams');
  END IF;

  INSERT INTO public.teams(
    name, bio, captain_id, logo_url, primary_color, secondary_color,
    governorate, preferred_formation, elo_rating, points, wins, draws, losses,
    matches_played, current_winning_streak, championships_won, is_active,
    is_blocked, is_verified
  )
  VALUES(
    v_name,
    coalesce(p_data->>'bio', ''),
    v_caller,
    p_data->>'logo_url',
    coalesce(p_data->>'primary_color', '#FFFFFF'),
    coalesce(p_data->>'secondary_color', '#000000'),
    v_captain_governorate,
    coalesce(p_data->>'preferred_formation', '2-2-1'),
    1200, 0, 0, 0, 0, 0, 0, 0, true, false, false
  )
  RETURNING id INTO v_team_id;

  INSERT INTO public.team_members(team_id, user_id)
  SELECT v_team_id, x
  FROM unnest(p_member_uids) x;

  RETURN jsonb_build_object(
    'success', true,
    'team_id', v_team_id,
    'governorate', v_captain_governorate
  );
END;
$function$
;

-- Function: create_team_league
CREATE OR REPLACE FUNCTION public.create_team_league(p_league_name text, p_team_id uuid, p_governorate text DEFAULT 'Cairo'::text, p_max_teams integer DEFAULT 4, p_interval_days integer DEFAULT 7, p_pay_option text DEFAULT 'my_team'::text, p_paid_teams_count integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_captain UUID;
  v_existing UUID;
  v_id UUID;
  v_fee NUMERIC;
  v_paid_count INTEGER;
  v_total_amount NUMERIC;
  v_reference TEXT;
  v_max INTEGER;
  v_interval INTEGER;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;

  SELECT captain_id INTO v_captain FROM public.teams WHERE id = p_team_id;
  IF v_captain IS NULL OR v_captain <> v_uid THEN
    RAISE EXCEPTION 'فقط قائد الفريق يستطيع إنشاء الدوري';
  END IF;

  SELECT c.id INTO v_existing 
  FROM public.championships c 
  WHERE c.template_type = 'team_league' 
    AND c.owner_id = v_uid 
    AND c.status IN ('open', 'ongoing') 
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'لديك دوري قائم بالفعل';
  END IF;

  v_max := LEAST(GREATEST(COALESCE(p_max_teams, 4), 4), 8);
  v_interval := LEAST(GREATEST(COALESCE(p_interval_days, 7), 1), 30);

  SELECT setting_value::numeric INTO v_fee
  FROM public.league_settings
  WHERE setting_key = 'team_league_entry_fee';

  IF v_fee IS NULL OR v_fee <= 0 THEN
    RAISE EXCEPTION 'رسوم اشتراك الدوري غير محددة أو غير صالحة بالنظام';
  END IF;

  IF p_pay_option = 'all' THEN
    v_paid_count := v_max;
  ELSIF p_pay_option = 'custom' THEN
    v_paid_count := LEAST(GREATEST(COALESCE(p_paid_teams_count, 1), 1), v_max);
  ELSE
    v_paid_count := 1;
  END IF;

  v_total_amount := v_paid_count * v_fee;

  INSERT INTO public.championships (
    name,
    type,
    sport_type,
    start_date,
    entry_fee,
    grand_prize,
    max_teams,
    owner_id,
    governorate,
    rules,
    payment_methods,
    max_players_per_team,
    min_players_per_team,
    winning_points,
    draw_points,
    loss_points,
    match_duration,
    is_back_and_forth,
    trophy_medals,
    red_card_suspension,
    fair_play_scoring,
    status,
    paid_teams,
    joined_teams,
    is_approved,
    number_of_groups,
    qualifying_per_group,
    is_two_legs,
    creation_fee_paid,
    prize_pool,
    prize_delivered,
    template_type,
    match_interval_days,
    paid_by_creator_count
  ) VALUES (
    NULLIF(TRIM(p_league_name), ''),
    'league',
    'football',
    now(),
    v_fee,
    0,
    v_max,
    v_uid,
    COALESCE(NULLIF(TRIM(p_governorate), ''), 'Cairo'),
    v_max || ' فرق، دور واحد، كل فريق يواجه الآخر مرة واحدة. الفوز: 3 نقاط، التعادل: 1 نقطة.',
    ARRAY['online'],
    0,
    0,
    3,
    1,
    0,
    90,
    false,
    true,
    false,
    false,
    'open',
    '{}'::TEXT[],
    ARRAY[p_team_id::TEXT],
    true,
    1,
    1,
    false,
    false,
    0,
    false,
    'team_league',
    v_interval,
    v_paid_count
  ) RETURNING id INTO v_id;

  v_reference := 'LEAGUE_' || v_id::TEXT || '_' || p_team_id::TEXT || '_' || FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;

  INSERT INTO public.team_league_payments (
    championship_id,
    team_id,
    user_id,
    amount,
    paid_teams_count,
    order_reference
  ) VALUES (
    v_id,
    p_team_id,
    v_uid,
    v_total_amount,
    v_paid_count,
    v_reference
  );

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', v_id,
    'payment_required', true,
    'payment_reference', v_reference,
    'amount', v_total_amount,
    'paid_teams_count', v_paid_count
  );
END;
$function$
;

-- Function: create_tournament_order_atomic
CREATE OR REPLACE FUNCTION public.create_tournament_order_atomic(p_championship_id uuid, p_team_id uuid, p_player_ids uuid[] DEFAULT ARRAY[]::uuid[], p_guest_names text[] DEFAULT ARRAY[]::text[], p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_champ RECORD;
  v_phase TEXT;
  v_team RECORD;
  v_captain RECORD;
  v_joined_count INT;
  v_pricing RECORD;
  v_reg_id UUID;
  v_existing_order RECORD;
  v_order_id UUID;
  v_order_ref TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- 1. LOCK FIRST: Row lock before checking phase
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  -- 2. Phase Engine SSOT Check under Lock
  v_phase := public.calculate_championship_effective_phase(p_championship_id);
  IF v_phase != 'registration_open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'current_phase', v_phase);
  END IF;

  IF coalesce(v_champ.entry_fee, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'FREE_TOURNAMENT_USE_JOIN');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'team_not_found'); END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id AND registration_status = 'confirmed';

  IF v_joined_count >= v_champ.max_teams THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_FULL');
  END IF;

  SELECT id, full_name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

  SELECT * INTO v_pricing FROM public.calculate_tournament_checkout_amount_atomic(p_championship_id);

  -- P0 Invariant: registration_status = 'pending' (NOT 'pending_payment')
  INSERT INTO public.championship_registrations (
    championship_id, team_id, captain_id, captain_snapshot,
    registration_status, payment_status, base_amount, gross_amount, currency
  )
  VALUES (
    p_championship_id, p_team_id, v_team.captain_id,
    jsonb_build_object('id', v_captain.id, 'name', v_captain.full_name, 'phone', v_captain.phone),
    'pending', 'pending', v_pricing.base_amount, v_pricing.gross_amount, v_pricing.currency
  )
  ON CONFLICT (championship_id, team_id) DO UPDATE SET
    registration_status = CASE 
      WHEN championship_registrations.registration_status = 'confirmed' THEN championship_registrations.registration_status
      ELSE 'pending'
    END,
    payment_status = CASE
      WHEN championship_registrations.payment_status = 'paid' THEN championship_registrations.payment_status
      ELSE 'pending'
    END,
    updated_at = now()
  RETURNING id INTO v_reg_id;

  -- Safe Idempotency Key Handling
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_existing_order
    FROM public.tournament_orders
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
      IF v_existing_order.payment_status = 'pending' THEN
        RETURN jsonb_build_object(
          'success', true,
          'existing_order', true,
          'order_id', v_existing_order.id,
          'order_reference', v_existing_order.order_reference,
          'gross_amount', v_existing_order.gross_amount
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'IDEMPOTENCY_KEY_ALREADY_USED',
          'order_status', v_existing_order.payment_status,
          'order_reference', v_existing_order.order_reference
        );
      END IF;
    END IF;
  END IF;

  -- Reuse existing pending order if active for this team and championship
  SELECT * INTO v_existing_order
  FROM public.tournament_orders
  WHERE championship_id = p_championship_id
    AND team_id = p_team_id
    AND payment_status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'existing_order', true,
      'order_id', v_existing_order.id,
      'order_reference', v_existing_order.order_reference,
      'gross_amount', v_existing_order.gross_amount
    );
  END IF;

  v_order_ref := 'TOURN_' || substring(replace(gen_random_uuid()::TEXT, '-', ''), 1, 12);

  INSERT INTO public.tournament_orders (
    order_reference, championship_id, team_id, captain_user_id,
    registration_id, idempotency_key, amount, base_amount,
    platform_fee_amount, gateway_fee_amount, gross_amount,
    currency, fee_policy_version, payment_status, player_ids, guest_names,
    created_at, updated_at
  )
  VALUES (
    v_order_ref, p_championship_id, p_team_id, auth.uid(),
    v_reg_id, p_idempotency_key, v_pricing.gross_amount, v_pricing.base_amount,
    v_pricing.platform_fee_amount, v_pricing.gateway_fee_amount, v_pricing.gross_amount,
    v_pricing.currency, v_pricing.fee_policy_version, 'pending',
    coalesce(p_player_ids, ARRAY[]::UUID[]), coalesce(p_guest_names, ARRAY[]::TEXT[]),
    now(), now()
  )
  RETURNING id, order_reference INTO v_order_id, v_order_ref;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_reference', v_order_ref,
    'base_amount', v_pricing.base_amount,
    'platform_fee_amount', v_pricing.platform_fee_amount,
    'gateway_fee_amount', v_pricing.gateway_fee_amount,
    'gross_amount', v_pricing.gross_amount,
    'currency', v_pricing.currency
  );
END;
$function$
;

-- Function: crown_individual_1v1_champion
CREATE OR REPLACE FUNCTION public.crown_individual_1v1_champion(p_championship_id uuid, p_winner_user_id uuid, p_prize numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ_name TEXT;
  v_user_name TEXT;
  v_user_avatar TEXT;
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only platform administrators can crown champions.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT name INTO v_champ_name FROM public.championships WHERE id = p_championship_id;
  SELECT name, profile_image_url INTO v_user_name, v_user_avatar FROM public.users WHERE id = p_winner_user_id;

  UPDATE public.championships
  SET 
    status = 'completed',
    champion_user_id = p_winner_user_id,
    champion_team_name = v_user_name,
    updated_at = NOW()
  WHERE id = p_championship_id;

  INSERT INTO public.player_trophies (user_id, championship_id, title, prize_won, created_at)
  VALUES (p_winner_user_id, p_championship_id, 'بطل بطولة ' || COALESCE(v_champ_name, 'VSP'), p_prize, NOW());

  INSERT INTO public.vsp_1vs1_players (id, name, avatar_url, titles, total_points, skill_points, goals, tackles, trend, created_at, updated_at)
  VALUES (p_winner_user_id, COALESCE(v_user_name, 'Player'), COALESCE(v_user_avatar, ''), 1, 100, 50, 0, 0, 'up', NOW(), NOW())
  ON CONFLICT (id) DO UPDATE
  SET titles = COALESCE(public.vsp_1vs1_players.titles, 0) + 1,
      total_points = public.vsp_1vs1_players.total_points + 50,
      updated_at = NOW();
END;
$function$
;

-- Function: crown_tournament_champion_atomic
CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(p_championship_id uuid, p_champion_team_id uuid, p_champion_team_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_is_owner BOOLEAN;
  v_is_admin BOOLEAN;
  v_caller_role TEXT;
  v_now TIMESTAMPTZ := timezone('utc'::text, now());
  v_team_name TEXT;
  v_prize NUMERIC;
  v_trophy_title TEXT;
  v_roster_id UUID;
  v_is_frozen BOOLEAN;
  v_member RECORD;
  v_awarded INT := 0;
  v_final_match RECORD;
  v_top_league_team_id UUID;
BEGIN
  -- 1. Lock and fetch championship
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- Idempotency check: if already completed with this exact champion, return success
  IF v_champ.status = 'completed' AND v_champ.champion_team_id = p_champion_team_id THEN
    RETURN jsonb_build_object(
      'success', true,
      'champion_team_id', v_champ.champion_team_id,
      'champion_team_name', v_champ.champion_team_name,
      'message', 'already_crowned'
    );
  END IF;

  IF v_champ.status = 'completed' AND v_champ.champion_team_id IS DISTINCT FROM p_champion_team_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_COMPLETED: Championship is already completed with a different champion');
  END IF;

  -- Authorization check
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    v_is_owner := (v_champ.owner_id IS NOT DISTINCT FROM auth.uid());
    IF NOT v_is_owner THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      v_is_admin := (COALESCE(v_caller_role, '') IN ('admin', 'co_founder', 'cofounder', 'super_admin'));
      IF NOT v_is_admin THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can crown tournament champion');
      END IF;
    END IF;
  END IF;

  -- 2. Verify team registered and paid/confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.championship_registrations
    WHERE championship_id = p_championship_id
      AND team_id = p_champion_team_id
      AND registration_status = 'confirmed'
  ) AND NOT (p_champion_team_id::TEXT = ANY(coalesce(v_champ.paid_teams, ARRAY[]::TEXT[]))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'champion_team_not_confirmed');
  END IF;

  -- 3. Verify Championship Structure and Winner SSOT (STRICTLY BY CHAMPIONSHIP TYPE)
  IF COALESCE(v_champ.type, '') = 'league' THEN
    -- =========================================================
    -- REGULAR LEAGUE / ROUND-ROBIN CHAMPIONSHIP
    -- =========================================================
    -- 1. All league matches must be completed and authoritative (confirmed/locked)
    IF EXISTS (
      SELECT 1 FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND (status != 'completed' OR COALESCE(result_status, '') NOT IN ('confirmed', 'locked'))
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'MATCHES_NOT_COMPLETED: All league matches must be completed and confirmed before crowning');
    END IF;

    -- 2. Determine champion from authoritative standings (1st place)
    SELECT s.team_id INTO v_top_league_team_id
    FROM public.get_championship_standings(p_championship_id, NULL) s
    LIMIT 1;

    IF v_top_league_team_id IS NULL OR v_top_league_team_id != p_champion_team_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'CHAMPION_MUST_BE_LEAGUE_LEADER: Champion must finish 1st in league standings');
    END IF;

  ELSE
    -- =========================================================
    -- GROUPS, CUP, OR KNOCKOUT TOURNAMENTS
    -- =========================================================
    -- For 'groups', 'cup', or 'knockout', crowning MUST happen via the actual knockout final!
    -- Group-stage leader can NEVER be crowned directly without advancing through knockout.
    SELECT * INTO v_final_match
    FROM public.tournament_matches
    WHERE championship_id = p_championship_id
      AND round_index = 0
      AND next_match_id IS NULL
      AND stage IN ('final', 'knockout', 'cup')
    ORDER BY id
    LIMIT 1;

    IF NOT FOUND THEN
      SELECT * INTO v_final_match
      FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND stage = 'final'
      LIMIT 1;
    END IF;

    IF NOT FOUND THEN
      IF COALESCE(v_champ.type, '') = 'groups' THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'FINAL_MATCH_NOT_FOUND: Groups tournament requires advancing to knockout bracket before crowning champion'
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'FINAL_MATCH_NOT_FOUND: Knockout tournament requires final match before crowning champion'
        );
      END IF;
    END IF;

    -- Final match must be completed, authoritative, and winner must match champion
    IF v_final_match.status != 'completed' OR COALESCE(v_final_match.result_status, '') NOT IN ('confirmed', 'locked') THEN
      RETURN jsonb_build_object('success', false, 'error', 'FINAL_MATCH_NOT_COMPLETED: Final match must be completed and confirmed before crowning');
    END IF;

    IF v_final_match.winner_id IS NULL OR v_final_match.winner_id != p_champion_team_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'CHAMPION_IS_NOT_FINAL_WINNER: Crowned team must be the winner of the final match');
    END IF;
  END IF;

  -- 4. Server Team Name is SSOT (Server Value Always Wins, client param ignored)
  SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  v_prize := coalesce(nullif(v_champ.prize_pool, 0), v_champ.grand_prize, 0);
  v_trophy_title := 'بطل بطولة ' || coalesce(v_champ.name, 'VSP');

  -- 5. Award Player Trophies Strictly to the Frozen Championship Roster (is_frozen = true)
  SELECT id, coalesce(is_frozen, false) INTO v_roster_id, v_is_frozen
  FROM public.championship_rosters
  WHERE championship_id = p_championship_id AND team_id = p_champion_team_id;

  IF v_roster_id IS NULL OR v_is_frozen IS NOT TRUE OR NOT EXISTS (
    SELECT 1 FROM public.championship_roster_players WHERE roster_id = v_roster_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FROZEN_ROSTER_REQUIRED');
  END IF;

  -- 6. Atomically Complete Championship
  UPDATE public.championships
  SET status = 'completed',
      champion_team_id = p_champion_team_id,
      champion_team_name = v_team_name,
      updated_at = v_now
  WHERE id = p_championship_id;

  -- 7. Distribute trophies to frozen roster players
  FOR v_member IN
    SELECT player_id AS user_id FROM public.championship_roster_players WHERE roster_id = v_roster_id
  LOOP
    IF v_member.user_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.player_trophies
        WHERE user_id = v_member.user_id AND championship_id = p_championship_id
      ) THEN
        INSERT INTO public.player_trophies(id, user_id, championship_id, title, prize_won, created_at)
        VALUES (gen_random_uuid(), v_member.user_id, p_championship_id, v_trophy_title, v_prize, v_now);
        v_awarded := v_awarded + 1;
      END IF;
    END IF;
  END LOOP;

  -- 8. Team Trophy & Prize
  UPDATE public.teams
  SET championships_won = coalesce(championships_won, 0) + 1,
      points = coalesce(points, 0) + 100,
      unlocked_badges = CASE
        WHEN 'cup_winner' = ANY(coalesce(unlocked_badges, ARRAY[]::TEXT[])) THEN unlocked_badges
        ELSE array_append(coalesce(unlocked_badges, ARRAY[]::TEXT[]), 'cup_winner')
      END,
      updated_at = v_now
  WHERE id = p_champion_team_id;

  RETURN jsonb_build_object(
    'success', true,
    'champion_team_id', p_champion_team_id,
    'champion_team_name', v_team_name,
    'players_awarded', v_awarded,
    'prize_awarded', v_prize
  );
END;
$function$
;

-- Function: delete_championship_atomic
CREATE OR REPLACE FUNCTION public.delete_championship_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actions     JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_actions := public.get_championship_actions(p_championship_id);

  IF NOT (v_actions->>'can_delete')::boolean THEN
    RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot delete championship. Active teams or historical records exist. Reason: %',
      v_actions->>'reason';
  END IF;

  -- Clean up any empty roster headers if they exist
  DELETE FROM public.championship_rosters WHERE championship_id = p_championship_id;

  -- Hard delete the pristine championship
  DELETE FROM public.championships WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success',         true,
    'championship_id', p_championship_id,
    'message',         'Championship permanently deleted'
  );
END;
$function$
;

-- Function: delete_chat_for_user
CREATE OR REPLACE FUNCTION public.delete_chat_for_user(p_conversation_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.role() <> 'service_role' AND (auth.uid() IS NULL OR auth.uid() <> p_user_id) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF auth.role() <> 'service_role' AND NOT EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id=p_conversation_id AND auth.uid()=ANY(c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'CONVERSATION_ACCESS_DENIED';
  END IF;

  UPDATE public.chat_messages
  SET deleted_for_users = array_append(coalesce(deleted_for_users,ARRAY[]::uuid[]),p_user_id)
  WHERE conversation_id=p_conversation_id
    AND NOT (coalesce(deleted_for_users,ARRAY[]::uuid[]) @> ARRAY[p_user_id]);

  UPDATE public.conversations
  SET deleted_for_users = array_append(coalesce(deleted_for_users,ARRAY[]::uuid[]),p_user_id)
  WHERE id=p_conversation_id
    AND NOT (coalesce(deleted_for_users,ARRAY[]::uuid[]) @> ARRAY[p_user_id]);
END;
$function$
;

-- Function: delete_chat_for_user_atomic
CREATE OR REPLACE FUNCTION public.delete_chat_for_user_atomic(p_booking_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 🔒 التحقق الصارم من أن المستخدم يحذف المحادثة لحسابه الشخصي فقط
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
        RAISE EXCEPTION 'Unauthorized: You can only hide or delete chats for your own user account.';
      END IF;
    END IF;
  END IF;

  -- إضافة معرف المستخدم لمصفوفة المحذوفات في الرسائل
  UPDATE public.chat_messages
  SET deleted_for_users = ARRAY(SELECT DISTINCT UNNEST(array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)))
  WHERE booking_id = p_booking_id 
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);

  -- إضافة معرف المستخدم لمصفوفة المحذوفات في جدول المحادثات
  UPDATE public.conversations
  SET deleted_for_users = ARRAY(SELECT DISTINCT UNNEST(array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)))
  WHERE booking_id = p_booking_id 
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);
END;
$function$
;

-- Function: delete_stadium_for_owner
CREATE OR REPLACE FUNCTION public.delete_stadium_for_owner(p_stadium_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text; v_owner uuid; v_active int;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select owner_id into v_owner from public.stadiums where id=p_stadium_id for update;
 if not found then raise exception 'الملعب غير موجود'; end if;
 select role into v_role from public.users where id=v_uid;
 if v_owner<>v_uid and coalesce(v_role,'') not in ('admin','co_founder','super_admin','cofounder') then
   raise exception 'غير مصرح بحذف هذا الملعب';
 end if;
 select count(*) into v_active from public.bookings
 where stadium_id=p_stadium_id and status<>'cancelled' and start_time>=now();
 if v_active>0 then
   raise exception 'لا يمكن حذف الملعب لوجود حجوزات حالية أو مستقبلية';
 end if;
 update public.stadiums
 set is_deleted_by_owner=true,is_verified=false,is_blocked=true,updated_at=now()
 where id=p_stadium_id;
 return jsonb_build_object('success',true,'stadium_id',p_stadium_id,'deleted',true);
end;
$function$
;

-- Function: delete_team_atomic
CREATE OR REPLACE FUNCTION public.delete_team_atomic(p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text; BEGIN
IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success',false,'error','Authentication required'); END IF;
SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
IF NOT EXISTS(SELECT 1 FROM public.teams WHERE id=p_team_id AND (captain_id=auth.uid() OR coalesce(v_role,'') IN ('admin','co_founder','cofounder','super_admin'))) THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF;
IF EXISTS(SELECT 1 FROM public.bookings WHERE status='confirmed' AND (player_team_id=p_team_id OR opponent_team_id=p_team_id) AND end_time>now()) OR EXISTS(SELECT 1 FROM public.championships WHERE status IN ('open','ongoing') AND p_team_id=ANY(coalesce(joined_teams,ARRAY[]::uuid[]))) THEN RETURN jsonb_build_object('success',false,'error','active_match_or_tournament_error'); END IF;
DELETE FROM public.team_members WHERE team_id=p_team_id; DELETE FROM public.teams WHERE id=p_team_id; RETURN jsonb_build_object('success',true); END $function$
;

-- Function: delete_user_permanently
CREATE OR REPLACE FUNCTION public.delete_user_permanently(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_is_sr boolean := (coalesce(auth.jwt()->>'role','')='service_role');
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_target record;
  v_team record;
  v_new_cap record;
  v_cnt int;
  v_auth_cnt int := 0;
  v_now timestamptz := timezone('utc',now());
begin
  if not v_is_sr then
    if v_caller_id is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
    if p_user_id is distinct from v_caller_id then
      select role into v_caller_role from public.users where id=v_caller_id;
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
    end if;
  end if;

  select * into v_target from public.users where id=p_user_id for update;
  if not found then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;
  if v_target.role in ('co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','PROTECTED_ACCOUNT'); end if;
  if v_caller_id=p_user_id and coalesce(v_caller_role,'') in ('admin','co_founder','cofounder') then return jsonb_build_object('success',false,'error','CANNOT_DELETE_SELF'); end if;
  if coalesce(v_target.accumulated_cash_debt,0)>0 then return jsonb_build_object('success',false,'error','OUTSTANDING_DEBT'); end if;

  select count(*) into v_cnt
  from public.bookings b
  where (b.created_by_user_id=p_user_id or b.user_id=p_user_id
    or (b.joined_user_ids is not null and p_user_id=any(b.joined_user_ids))
    or exists(select 1 from public.booking_players bp where bp.booking_id=b.id and bp.user_id=p_user_id))
    and b.status in ('confirmed','pending') and b.start_time>=timezone('utc',now());
  if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_BOOKINGS'); end if;

  select count(*) into v_cnt
  from public.championship_registrations cr
  join public.championships c on c.id=cr.championship_id
  where c.status in ('open','ongoing')
    and cr.captain_id=p_user_id
    and cr.registration_status in ('confirmed','approved','pending');
  if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_CHAMPIONSHIPS'); end if;

  select count(*) into v_cnt
  from public.vsp_1v1_tournament_orders o
  join public.vsp_1v1_tournaments t on t.id=o.tournament_id
  where o.user_id=p_user_id
    and ((o.payment_status in ('pending','refund_requested','refund_failed_manual_review'))
      or (o.payment_status='paid' and t.status in ('draft','registration_open','in_progress')));
  if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_1V1_FINANCIAL_OBLIGATION'); end if;

  select count(*) into v_cnt
  from public.vsp_1v1_cancellation_refund_queue q
  where q.user_id=p_user_id and q.status not in ('refunded','failed_over_capacity','failed_manual_review');
  if v_cnt>0 then return jsonb_build_object('success',false,'error','PENDING_REFUND'); end if;

  select count(*) into v_cnt
  from public.tournament_orders o
  join public.championships c on c.id=o.championship_id
  where o.captain_user_id=p_user_id
    and (o.payment_status in ('pending','refund_pending','refund_failed_manual_review')
      or (o.payment_status='paid' and c.status in ('open','ongoing')));
  if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_TOURNAMENT_PAYMENT'); end if;

  select count(*) into v_cnt
  from public.team_league_payments p
  join public.championships c on c.id=p.championship_id
  where p.user_id=p_user_id and p.payment_status='pending';
  if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_LEAGUE_PAYMENT'); end if;
  select count(*) into v_cnt
  from public.team_league_payments p
  join public.championships c on c.id=p.championship_id
  where p.user_id=p_user_id and p.payment_status='paid' and c.status in ('open','ongoing');
  if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_LEAGUE_PAYMENT'); end if;

  select count(*) into v_cnt from public.owner_subscription_orders where owner_id=p_user_id and status='pending';
  if v_cnt>0 then return jsonb_build_object('success',false,'error','PENDING_SUBSCRIPTION_PAYMENT'); end if;

  select count(*) into v_cnt
  from public.team_league_cancellation_refund_queue q
  where q.user_id=p_user_id and q.status not in ('refunded','failed_over_capacity','failed_manual_review');
  if v_cnt>0 then return jsonb_build_object('success',false,'error','PENDING_REFUND'); end if;

  if coalesce(v_target.role,'') in ('owner','pitch_owner','stadium_owner') then
    select count(*) into v_cnt from public.stadiums where owner_id=p_user_id and is_active=true;
    if v_cnt>0 then return jsonb_build_object('success',false,'error','ACTIVE_OWNER_STADIUMS'); end if;
  end if;

  for v_team in select id from public.teams where captain_id=p_user_id for update loop
    select tm.user_id,u.name,u.phone,u.profile_image_url into v_new_cap
    from public.team_members tm join public.users u on u.id=tm.user_id
    where tm.team_id=v_team.id and tm.user_id<>p_user_id order by tm.joined_at asc limit 1;
    if found then
      update public.teams set captain_id=v_new_cap.user_id,captain_name=coalesce(v_new_cap.name,'كابتن الفريق'),captain_phone=coalesce(v_new_cap.phone,''),captain_image_url=v_new_cap.profile_image_url,updated_at=v_now where id=v_team.id;
      delete from public.team_members where team_id=v_team.id and user_id=p_user_id;
    else
      delete from public.teams where id=v_team.id;
    end if;
  end loop;

  delete from public.team_members where user_id=p_user_id;
  delete from public.notifications where user_id=p_user_id;
  delete from public.reviews where user_id=p_user_id;
  delete from public.reports where reporter_id=p_user_id or (target_type='user' and target_id=p_user_id::text);
  delete from public.chat_messages where sender_id=p_user_id;
  delete from public.user_device_tokens where user_id=p_user_id;
  delete from public.user_blocks where blocker_id=p_user_id or blocked_user_id=p_user_id;

  if v_caller_id is not null and v_caller_id<>p_user_id then
    insert into public.system_audit_logs(action,table_name,record_id,old_data,changed_by,changed_by_role,created_at)
    values('admin_permanent_delete_user','users',p_user_id,jsonb_build_object('email',v_target.email,'role',v_target.role,'name',v_target.name),v_caller_id,v_caller_role,v_now);
  end if;

  delete from auth.users where id=p_user_id;
  get diagnostics v_auth_cnt=row_count;
  delete from public.users where id=p_user_id;
  return jsonb_build_object('success',true,'message','تم حذف الحساب نهائياً.','auth_user_deleted',(v_auth_cnt>0),'server_time',v_now);
end;
$function$
;

-- Function: dismiss_no_show_penalty
CREATE OR REPLACE FUNCTION public.dismiss_no_show_penalty(p_player_id uuid, p_booking_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_no_show int;
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only platform administrators can dismiss penalties.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.bookings
  SET 
    is_paid = true,
    payment_status = 'paid',
    notes = COALESCE(notes, '') || E'\n[DISPUTE RESOLVED - PENALTY CLEARED]'
  WHERE id = p_booking_id;

  SELECT GREATEST(0, COALESCE(no_show_count, 1) - 1) INTO v_new_no_show
  FROM public.users
  WHERE id = p_player_id;

  UPDATE public.users
  SET 
    no_show_count = v_new_no_show,
    is_blocked = (v_new_no_show >= 3),
    cash_booking_banned = (v_new_no_show >= 2),
    updated_at = NOW()
  WHERE id = p_player_id;
END;
$function$
;

-- Function: dispute_no_show_with_gps
CREATE OR REPLACE FUNCTION public.dispute_no_show_with_gps(p_booking_id text, p_player_id text, p_lat numeric, p_lng numeric, p_accuracy numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_booking record;
  v_stadium record;
  v_distance_meters numeric;
  v_player_uuid uuid;
  v_booking_uuid uuid;
BEGIN
  BEGIN
    v_player_uuid := p_player_id::uuid;
    v_booking_uuid := p_booking_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_UUID_FORMAT: Invalid player or booking identifier' USING ERRCODE = '22P02';
  END;

  IF COALESCE(auth.role(), '') != 'service_role'
     AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF auth.uid() IS NULL OR auth.uid() != v_player_uuid THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: You can only dispute penalties for your own account.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF p_lat IS NULL OR p_lng IS NULL OR p_accuracy IS NULL THEN
    RAISE EXCEPTION 'invalid_gps_input';
  END IF;

  IF p_accuracy < 0 OR p_accuracy > 50 THEN
    RAISE EXCEPTION 'gps_accuracy_too_low';
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = v_booking_uuid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking_not_found';
  END IF;

  IF v_booking.is_dispute_approved IS TRUE
     OR v_booking.status IS DISTINCT FROM 'no_show' THEN
    RETURN false;
  END IF;

  IF v_booking.user_id != v_player_uuid
     AND v_booking.created_by_user_id != v_player_uuid
     AND NOT (v_player_uuid::text = ANY(COALESCE(v_booking.joined_user_ids::text[], ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Player was not a registered participant in this booking.'
      USING ERRCODE = '42501';
  END IF;

  IF timezone('utc'::text, now()) > (v_booking.end_time + INTERVAL '60 minutes') THEN
    RAISE EXCEPTION 'dispute_window_expired';
  END IF;

  SELECT * INTO v_stadium
  FROM public.stadiums
  WHERE id = v_booking.stadium_id;

  IF v_stadium.lat IS NULL OR v_stadium.lng IS NULL THEN
    RAISE EXCEPTION 'stadium_coordinates_missing';
  END IF;

  v_distance_meters := 6371000 * acos(
    LEAST(1.0, GREATEST(-1.0,
      cos(radians(v_stadium.lat)) * cos(radians(p_lat)) *
      cos(radians(p_lng) - radians(v_stadium.lng)) +
      sin(radians(v_stadium.lat)) * sin(radians(p_lat))
    ))
  );

  -- Approved VSP rule: player must be within 200m of the stadium.
  IF v_distance_meters > 200 THEN
    RAISE EXCEPTION 'not_at_stadium';
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.users
  SET
    no_show_count = GREATEST(0, no_show_count - 1),
    is_blocked = false,
    cash_booking_banned = CASE WHEN GREATEST(0, no_show_count - 1) >= 2 THEN true ELSE false END,
    updated_at = timezone('utc'::text, now())
  WHERE id = v_player_uuid;

  UPDATE public.bookings
  SET
    is_dispute_approved = true,
    match_result_status = 'confirmed',
    updated_at = timezone('utc'::text, now())
  WHERE id = v_booking_uuid;

  RETURN true;
END;
$function$
;

-- Function: edit_chat_message_atomic
CREATE OR REPLACE FUNCTION public.edit_chat_message_atomic(p_message_id uuid, p_new_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_msg             record;
BEGIN
  IF nullif(trim(COALESCE(p_new_text, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_MESSAGE_TEXT');
  END IF;

  SELECT * INTO v_msg
  FROM public.chat_messages
  WHERE id = p_message_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;

  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL OR v_msg.sender_id IS DISTINCT FROM v_caller_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_SENDER_ONLY');
    END IF;
  END IF;

  UPDATE public.chat_messages
  SET text = trim(p_new_text),
      is_edited = true
  WHERE id = p_message_id;

  RETURN jsonb_build_object('success', true, 'message_id', p_message_id);
END;
$function$
;

-- Function: enforce_cash_booking_restrictions
CREATE OR REPLACE FUNCTION public.enforce_cash_booking_restrictions()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_record record;
  v_active_cash_count integer := 0;
  v_booking_user_id uuid;
BEGIN
  -- Owner-created manual bookings for their own stadium are not player bookings.
  IF NEW.created_by_user_id IS NOT NULL
     AND NEW.owner_id IS NOT NULL
     AND NEW.created_by_user_id = NEW.owner_id THEN
    RETURN NEW;
  END IF;

  v_booking_user_id := COALESCE(NEW.created_by_user_id, NEW.user_id);

  IF v_booking_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Serialize booking creation for the same player so two concurrent requests
  -- cannot both pass the cash-policy check.
  PERFORM pg_advisory_xact_lock(
    hashtext('vsp_cash_booking_policy:' || v_booking_user_id::text)
  );

  SELECT
    is_blocked,
    COALESCE(no_show_count, 0) AS no_show_count
  INTO v_user_record
  FROM public.users
  WHERE id = v_booking_user_id;

  IF FOUND THEN
    IF v_user_record.is_blocked = true THEN
      RAISE EXCEPTION 'حسابك معلق حالياً من قبل الإدارة. لا يمكنك إجراء حجوزات جديدة.';
    END IF;

    IF NEW.payment_method = 'cash'
       AND v_user_record.no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id=1) THEN
      RAISE EXCEPTION 'حسابك مقيد مؤقتاً من الحجوزات النقدية بسبب تكرار عدم الحضور (No-Show). يرجى الدفع إلكترونياً لتأكيد الحجز.';
    END IF;
  END IF;

  -- Core business rule: an unpaid active cash booking blocks another cash booking.
  SELECT COUNT(*)
  INTO v_active_cash_count
  FROM public.bookings b
  WHERE (b.user_id = v_booking_user_id OR b.created_by_user_id = v_booking_user_id)
    AND b.payment_method = 'cash'
    AND COALESCE(b.is_paid, false) = false
    AND b.status IN ('pending', 'confirmed')
    AND b.end_time > now();

  IF v_active_cash_count > 0 THEN
    IF NEW.payment_method = 'cash' THEN
      RAISE EXCEPTION 'لديك حجز نقدي لم ينتهِ بعد. لا يمكن إنشاء حجز نقدي آخر قبل انتهاء الحجز السابق.';
    END IF;

    -- Any second online booking must be paid in full, never by deposit.
    IF NEW.payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
      NEW.needs_deposit := false;
      NEW.deposit_amount := 0;
      NEW.deposit_paid := 0;
      NEW.is_deposit_paid := false;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: enforce_real_sender_name
CREATE OR REPLACE FUNCTION public.enforce_real_sender_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_real_name TEXT;
BEGIN
  -- إذا كان الطلب قادماً من مستخدم مسجل الدخول (Client User Request)
  IF auth.uid() IS NOT NULL THEN
    NEW.sender_id := auth.uid();
    
    SELECT name INTO v_real_name FROM public.users WHERE id = auth.uid();
    IF v_real_name IS NOT NULL AND v_real_name <> '' THEN
      NEW.sender_name := v_real_name;
    END IF;
  END IF;

  -- إذا كان الاستدعاء من السيرفر الداخلي (Service Role أو System Bot)، يُترك sender_id و sender_name كما هما
  RETURN NEW;
END;
$function$
;

-- Function: enforce_team_member_governorate
CREATE OR REPLACE FUNCTION public.enforce_team_member_governorate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_team_governorate text;
  v_captain_governorate text;
  v_player_governorate text;
BEGIN
  SELECT t.governorate, u.governorate
    INTO v_team_governorate, v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = NEW.team_id;

  SELECT governorate
    INTO v_player_governorate
  FROM public.users
  WHERE id = NEW.user_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RAISE EXCEPTION 'TEAM_CAPTAIN_GOVERNORATE_REQUIRED';
  END IF;

  IF v_player_governorate IS NULL OR btrim(v_player_governorate) = '' THEN
    RAISE EXCEPTION 'PLAYER_GOVERNORATE_REQUIRED';
  END IF;

  IF lower(btrim(v_player_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    RAISE EXCEPTION 'TEAM_GOVERNORATE_MISMATCH';
  END IF;

  IF v_team_governorate IS NULL
     OR btrim(v_team_governorate) = ''
     OR lower(btrim(v_team_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    UPDATE public.teams
    SET governorate = v_captain_governorate,
        updated_at = now()
    WHERE id = NEW.team_id;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: enforce_vsp_minimum_age
CREATE OR REPLACE FUNCTION public.enforce_vsp_minimum_age()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.role in ('player', 'owner') then
    if nullif(trim(coalesce(new.date_of_birth, '')), '') is not null
       and not public.vsp_is_adult_date_of_birth(new.date_of_birth) then
      raise exception using errcode='P0002', message='VSP_AGE_RESTRICTED';
    end if;
    if coalesce(new.is_registration_complete, false)
       and not public.vsp_is_adult_date_of_birth(new.date_of_birth) then
      raise exception using errcode='P0002', message='REGISTRATION_REQUIRES_18_PLUS';
    end if;
  end if;
  return new;
end;
$function$
;

-- Function: evaluate_owner_stadium_capacity
CREATE OR REPLACE FUNCTION public.evaluate_owner_stadium_capacity(p_owner_id uuid, p_exclude_stadium_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(allowed boolean, current_count integer, max_allowed integer, is_trial boolean, is_sub_active boolean, plan_code text, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_owner              public.users%ROWTYPE;
  v_allowed_count      integer := 1;
  v_active_count       integer := 0;
  v_is_active_trial    boolean := false;
  v_is_pro_paid        boolean := false;
  v_plan_code          text := 'basic';
BEGIN
  -- Caller authorization check:
  IF COALESCE(current_setting('request.jwt.claim.role', true), '') = 'authenticated' THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للتحقق من باقة المالك.'
        USING ERRCODE = '42501';
    END IF;
    IF auth.uid() <> p_owner_id AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالاطلاع على باقة مالك آخر.'
        USING ERRCODE = '42501';
    END IF;
  ELSIF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id THEN
    IF NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالاطلاع على باقة مالك آخر.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 1. Fetch owner record
  SELECT * INTO v_owner
  FROM public.users
  WHERE id = p_owner_id;

  IF v_owner.id IS NULL THEN
    RETURN QUERY SELECT false, 0, 0, false, false, ''::text, 'مالك الملعب غير موجود في النظام.'::text;
    RETURN;
  END IF;

  -- 2. Admins and co-founders bypass limits
  IF v_owner.role IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    SELECT count(*)::integer INTO v_active_count
    FROM public.stadiums
    WHERE owner_id = p_owner_id
      AND COALESCE(is_deleted_by_owner, false) = false
      AND (p_exclude_stadium_id IS NULL OR id <> p_exclude_stadium_id);

    RETURN QUERY SELECT true, v_active_count, 999, false, true, 'admin'::text, 'حساب إداري - ملاعب غير محدودة'::text;
    RETURN;
  END IF;

  -- 3. Check active Pro Trial (Strict 7 days)
  v_is_active_trial := (
    v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()
  );

  -- 4. Check active Pro Paid subscription
  v_is_pro_paid := (
    v_owner.subscription_plan = 'pro' AND
    v_owner.subscription_expires_at IS NOT NULL AND
    v_owner.subscription_expires_at > NOW()
  );

  -- 5. Determine capacity and plan code
  IF v_is_pro_paid THEN
    v_allowed_count := 3;
    v_plan_code := 'pro';
  ELSIF v_is_active_trial THEN
    v_allowed_count := 3;
    v_plan_code := 'pro_trial';
  ELSE
    -- Basic Free is default and perpetual: 1 stadium max
    v_allowed_count := 1;
    v_plan_code := 'basic';
  END IF;

  -- 6. Count existing active stadiums
  SELECT count(*)::integer INTO v_active_count
  FROM public.stadiums
  WHERE owner_id = p_owner_id
    AND COALESCE(is_deleted_by_owner, false) = false
    AND (p_exclude_stadium_id IS NULL OR id <> p_exclude_stadium_id);

  -- 7. Return evaluation result
  IF v_active_count >= v_allowed_count THEN
    RETURN QUERY SELECT false, v_active_count, v_allowed_count, v_is_active_trial, v_is_pro_paid, v_plan_code,
      format('وصلت للحد الأقصى للملاعب في باقتك الحالية (%s ملعب). يرجى الترقية لإضافة أو تفعيل ملاعب أخرى.', v_allowed_count)::text;
  ELSE
    RETURN QUERY SELECT true, v_active_count, v_allowed_count, v_is_active_trial, v_is_pro_paid, v_plan_code,
      'مسموح بإضافة أو تفعيل الملعب'::text;
  END IF;
END;
$function$
;

-- Function: finalize_championship_cancellation_refund_atomic
CREATE OR REPLACE FUNCTION public.finalize_championship_cancellation_refund_atomic(p_championship_id uuid, p_order_reference text, p_refund_success boolean, p_refund_txn_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order    RECORD;
  v_champ    RECORD;
  v_now      TIMESTAMPTZ := now();
BEGIN
  IF current_user NOT IN ('postgres','service_role') AND COALESCE(auth.role(),'') <> 'service_role' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_order
  FROM public.tournament_orders
  WHERE order_reference = p_order_reference AND championship_id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;

  IF p_refund_success THEN
    UPDATE public.tournament_orders
    SET payment_status = 'refunded',
        updated_at     = v_now
    WHERE order_reference = p_order_reference;

    -- Record completed refund transaction
    INSERT INTO public.transactions (
      user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
    ) VALUES (
      v_order.captain_user_id,
      v_order.amount,
      'refund',
      'paymob',
      'completed',
      'استرداد رسوم اشتراك بطولة ملغاة: ' || COALESCE(v_champ.name, ''),
      jsonb_build_object(
        'championship_id',        p_championship_id,
        'order_reference',        p_order_reference,
        'original_paymob_txn_id', v_order.paymob_transaction_id,
        'paymob_refund_id',       p_refund_txn_id,
        'amount',                 v_order.amount
      ),
      v_now, v_now
    );

    -- Financial audit log
    INSERT INTO public.financial_audit_logs (
      action_type, owner_id, user_id, amount, fee, transaction_ref, metadata, created_at
    ) VALUES (
      'cancellation_refund_completed',
      v_champ.owner_id,
      v_order.captain_user_id,
      v_order.amount,
      0,
      p_refund_txn_id,
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'status', 'refunded'
      ),
      v_now
    );

    RETURN jsonb_build_object('success', true, 'status', 'refunded', 'order_reference', p_order_reference);

  ELSE
    -- Refund failed with Paymob: flag for urgent manual admin review
    UPDATE public.tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at     = v_now
    WHERE order_reference = p_order_reference;

    INSERT INTO public.transactions (
      user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
    ) VALUES (
      v_order.captain_user_id,
      v_order.amount,
      'refund',
      'paymob',
      'failed',
      'تعذر استرداد رسوم اشتراك بطولة ملغاة تلقائياً: ' || COALESCE(v_champ.name, ''),
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'error',           p_error_message
      ),
      v_now, v_now
    );

    INSERT INTO public.financial_audit_logs (
      action_type, owner_id, user_id, amount, fee, transaction_ref, metadata, created_at
    ) VALUES (
      'refund_failed_manual_review',
      v_champ.owner_id,
      v_order.captain_user_id,
      v_order.amount,
      0,
      p_order_reference,
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'error',           p_error_message
      ),
      v_now
    );

    RETURN jsonb_build_object('success', false, 'status', 'refund_failed_manual_review', 'error', p_error_message);
  END IF;
END;
$function$
;

-- Function: finalize_team_withdrawal_refund_atomic
CREATE OR REPLACE FUNCTION public.finalize_team_withdrawal_refund_atomic(p_championship_id uuid, p_team_id uuid, p_order_reference text, p_refund_success boolean, p_refund_amount numeric, p_refund_txn_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_captain uuid; v_now timestamptz:=now();
begin
  if current_user not in ('postgres','service_role') and coalesce(auth.role(),'')<>'service_role' then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;

  select * into v_order from public.tournament_orders
  where order_reference=p_order_reference and championship_id=p_championship_id and team_id=p_team_id for update;

  if not found then
    select * into v_order from public.team_league_payments
    where order_reference=p_order_reference and championship_id=p_championship_id and team_id=p_team_id for update;
  end if;

  if not found then return jsonb_build_object('success',false,'error','Payment order not found'); end if;

  if p_refund_success then
    update public.tournament_orders set payment_status='refunded',updated_at=v_now where order_reference=p_order_reference;
    update public.team_league_payments set payment_status='refunded',updated_at=v_now where order_reference=p_order_reference;

    update public.championships
    set joined_teams=array_remove(coalesce(joined_teams,array[]::text[]),p_team_id::text),
        paid_teams=array_remove(coalesce(paid_teams,array[]::text[]),p_team_id::text),
        updated_at=v_now
    where id=p_championship_id;

    select captain_id into v_captain from public.teams where id=p_team_id;

    if v_captain is not null and p_refund_amount>0 and not exists(
      select 1 from public.transactions
      where user_id=v_captain and type='refund' and status='completed'
        and coalesce(metadata->>'order_reference','')=p_order_reference
    ) then
      insert into public.transactions(
        user_id,amount,type,payment_method,status,description,metadata,created_at,updated_at
      ) values(
        v_captain,round(p_refund_amount,2),'refund','paymob','completed',
        'استرداد انسحاب من البطولة: '||(select name from public.championships where id=p_championship_id),
        jsonb_build_object('order_reference',p_order_reference,'paymob_refund_id',p_refund_txn_id,'principal_amount',v_order.amount,'refund_amount',p_refund_amount),
        v_now,v_now
      );
    end if;
    return jsonb_build_object('success',true,'status','refunded','refund_amount',round(p_refund_amount,2));
  end if;

  update public.tournament_orders set payment_status='refund_failed_manual_review',updated_at=v_now where order_reference=p_order_reference;
  update public.team_league_payments set payment_status='refund_failed_manual_review',updated_at=v_now where order_reference=p_order_reference;
  return jsonb_build_object('success',true,'status','refund_failed_manual_review','refund_amount',round(coalesce(p_refund_amount,0),2),'error',p_error_message);
end;
$function$
;

-- Function: fn_log_sensitive_changes
CREATE OR REPLACE FUNCTION public.fn_log_sensitive_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT := 'system';
    v_changed_keys TEXT[] := ARRAY[]::TEXT[];
    v_old_json JSONB;
    v_new_json JSONB;
    v_key TEXT;
BEGIN
    IF v_user_id IS NOT NULL THEN
        SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);

        -- استخراج الحقول التي تغيرت قيمتها فقط
        FOR v_key IN SELECT jsonb_object_keys(v_new_json)
        LOOP
            IF (v_old_json->v_key IS DISTINCT FROM v_new_json->v_key) THEN
                v_changed_keys := array_append(v_changed_keys, v_key);
            END IF;
        END LOOP;

        -- إذا لم تتغير سوى حقول التوقيت updated_at فلا داعي لملء السجل
        IF v_changed_keys = ARRAY['updated_at']::TEXT[] OR array_length(v_changed_keys, 1) IS NULL THEN
            RETURN NEW;
        END IF;

        INSERT INTO public.system_audit_logs (
            table_name,
            record_id,
            action,
            changed_by,
            changed_by_role,
            old_data,
            new_data,
            changed_fields,
            created_at
        ) VALUES (
            TG_TABLE_NAME,
            NEW.id,
            'UPDATE',
            v_user_id,
            v_user_role,
            v_old_json,
            v_new_json,
            v_changed_keys,
            timezone('utc'::text, now())
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.system_audit_logs (
            table_name,
            record_id,
            action,
            changed_by,
            changed_by_role,
            old_data,
            new_data,
            changed_fields,
            created_at
        ) VALUES (
            TG_TABLE_NAME,
            OLD.id,
            'DELETE',
            v_user_id,
            v_user_role,
            to_jsonb(OLD),
            NULL,
            ARRAY['*FULL_ROW_DELETED*']::TEXT[],
            timezone('utc'::text, now())
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$function$
;

-- Function: fn_sync_stadium_prices
CREATE OR REPLACE FUNCTION public.fn_sync_stadium_prices()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- ضمان تطابق الحقلين دائماً سواء تم التعديل على هذا أو ذاك
    IF NEW.price_per_hour IS NOT NULL AND NEW.base_price IS NULL THEN
        NEW.base_price := NEW.price_per_hour;
    ELSIF NEW.base_price IS NOT NULL AND NEW.price_per_hour IS NULL THEN
        NEW.price_per_hour := NEW.base_price;
    ELSIF NEW.price_per_hour IS NOT NULL AND (OLD IS NULL OR NEW.price_per_hour IS DISTINCT FROM OLD.price_per_hour) THEN
        NEW.base_price := NEW.price_per_hour;
    ELSIF NEW.base_price IS NOT NULL AND (OLD IS NULL OR NEW.base_price IS DISTINCT FROM OLD.base_price) THEN
        NEW.price_per_hour := NEW.base_price;
    END IF;

    RETURN NEW;
END;
$function$
;

-- Function: generate_booking_qr_token
CREATE OR REPLACE FUNCTION public.generate_booking_qr_token(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
    v_booking RECORD;
    v_caller_id UUID := auth.uid();
    v_raw_token TEXT;
    v_token_hash TEXT;
    v_expires_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
    END IF;

    -- Strict Authorization: Caller must own or participate in booking (or admin/service_role)
    IF current_user NOT IN ('postgres', 'service_role') THEN
        IF v_booking.user_id != v_caller_id 
           AND v_booking.created_by_user_id != v_caller_id 
           AND NOT (v_caller_id = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You are not a participant in this booking');
        END IF;
    END IF;

    -- State guard: booking must be confirmed
    IF v_booking.status != 'confirmed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only confirmed bookings can generate attendance QR codes');
    END IF;

    IF v_booking.qr_scanned_at IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'This booking attendance has already been verified');
    END IF;

    -- Generate cryptographically random 32-byte hex token
    v_raw_token := encode(gen_random_bytes(32), 'hex');
    v_token_hash := encode(digest(v_raw_token, 'sha256'), 'hex');
    v_expires_at := GREATEST(v_now + INTERVAL '30 minutes', v_booking.end_time + INTERVAL '2 hours');

    UPDATE public.bookings
    SET 
        qr_hash = v_token_hash,
        qr_expires_at = v_expires_at,
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'qr_token', v_raw_token,
        'expires_at', v_expires_at
    );
END;
$function$
;

-- Function: generate_regular_group_fixtures_atomic
CREATE OR REPLACE FUNCTION public.generate_regular_group_fixtures_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_count INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.championships c
    WHERE c.id = p_championship_id
      AND (c.owner_id = v_user_id OR COALESCE(v_role, '') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  v_count := public.generate_regular_group_fixtures_internal(p_championship_id);

  UPDATE public.championships
  SET registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id
    AND status = 'open';

  RETURN jsonb_build_object('success', true, 'format', 'groups', 'matches_count', v_count);
END;
$function$
;

-- Function: generate_regular_group_fixtures_internal
CREATE OR REPLACE FUNCTION public.generate_regular_group_fixtures_internal(p_championship_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_team_ids UUID[];
  v_shuffled UUID[];
  v_team_count INTEGER;
  v_num_groups INTEGER;
  v_group_index INTEGER;
  v_group_name TEXT;
  v_group_team_ids UUID[];
  v_list UUID[];
  v_virtual_count INTEGER;
  v_num_weeks INTEGER;
  v_matches_per_week INTEGER;
  v_week INTEGER;
  v_match INTEGER;
  v_home_idx INTEGER;
  v_away_idx INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_match_index INTEGER := 0;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_start_date DATE;
  v_result_count INTEGER := 0;
BEGIN
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'championship_not_found';
  END IF;

  IF v_champ.template_type = 'team_league' OR v_champ.type <> 'groups' THEN
    RAISE EXCEPTION 'wrong_tournament_format';
  END IF;

  IF COALESCE(v_champ.entry_fee, 0) > 0 THEN
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[])
    INTO v_team_ids
    FROM unnest(COALESCE(v_champ.paid_teams, '{}'::text[])) AS x;
  ELSE
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[])
    INTO v_team_ids
    FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[])) AS x;
  END IF;

  v_team_count := COALESCE(array_length(v_team_ids, 1), 0);
  v_num_groups := GREATEST(2, LEAST(COALESCE(v_champ.number_of_groups, 2), 8));

  IF v_team_count < v_num_groups * 2 THEN
    RAISE EXCEPTION 'insufficient_teams_for_groups';
  END IF;

  SELECT ARRAY_AGG(t.id ORDER BY random())
  INTO v_shuffled
  FROM unnest(v_team_ids) AS x(team_id)
  JOIN public.teams t ON t.id = x.team_id;

  DELETE FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  v_start_date := COALESCE(v_champ.start_date::date, CURRENT_DATE);

  FOR v_group_index IN 0..(v_num_groups - 1) LOOP
    v_group_name := chr(65 + v_group_index);

    SELECT COALESCE(ARRAY_AGG(team_id ORDER BY ordinality), '{}'::uuid[])
    INTO v_group_team_ids
    FROM (
      SELECT v_shuffled[i] AS team_id, i AS ordinality
      FROM generate_series(1, array_length(v_shuffled,1)) AS s(i)
      WHERE ((i - 1) % v_num_groups) = v_group_index
    ) q;

    v_list := v_group_team_ids;
    IF COALESCE(array_length(v_list,1),0) % 2 = 1 THEN
      v_list := v_list || NULL::uuid;
    END IF;

    v_virtual_count := array_length(v_list,1);
    v_num_weeks := v_virtual_count - 1;
    v_matches_per_week := v_virtual_count / 2;

    FOR v_week IN 0..(v_num_weeks - 1) LOOP
      FOR v_match IN 0..(v_matches_per_week - 1) LOOP
        v_home_idx := (v_week + v_match) % (v_virtual_count - 1);
        v_away_idx := (v_virtual_count - 1 - v_match + v_week) % (v_virtual_count - 1);

        IF v_match = 0 THEN
          v_away_idx := v_virtual_count - 1;
        END IF;

        v_home_id := v_list[v_home_idx + 1];
        v_away_id := v_list[v_away_idx + 1];

        IF v_home_id IS NOT NULL AND v_away_id IS NOT NULL THEN
          SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
          SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;

          INSERT INTO public.tournament_matches (
            championship_id, round_index, match_index, group_name, week_number, stage,
            home_team_id, home_team_name, away_team_id, away_team_name,
            match_day, status, result_status, is_completed, created_at, updated_at
          ) VALUES (
            p_championship_id, 99, v_match_index, v_group_name, v_week + 1, 'group_stage',
            v_home_id, v_home_name, v_away_id, v_away_name,
            v_start_date + (v_week * COALESCE(v_champ.match_interval_days, 7)),
            'scheduled', 'scheduled', false, v_now, v_now
          );

          v_match_index := v_match_index + 1;
          v_result_count := v_result_count + 1;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN v_result_count;
END;
$function$
;

-- Function: generate_regular_league_fixtures_atomic
CREATE OR REPLACE FUNCTION public.generate_regular_league_fixtures_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_count INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.championships c
    WHERE c.id = p_championship_id
      AND (c.owner_id = v_user_id OR COALESCE(v_role, '') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  v_count := public.generate_regular_league_fixtures_internal(p_championship_id);

  UPDATE public.championships
  SET registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id
    AND status = 'open';

  RETURN jsonb_build_object('success', true, 'format', 'league', 'matches_count', v_count);
END;
$function$
;

-- Function: generate_regular_league_fixtures_internal
CREATE OR REPLACE FUNCTION public.generate_regular_league_fixtures_internal(p_championship_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_team_ids UUID[];
  v_team_list UUID[];
  v_team_count INTEGER;
  v_virtual_count INTEGER;
  v_num_weeks INTEGER;
  v_matches_per_week INTEGER;
  v_week INTEGER;
  v_match INTEGER;
  v_home_idx INTEGER;
  v_away_idx INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_match_index INTEGER := 0;
  v_two_legs BOOLEAN := false;
  v_first_leg_weeks INTEGER;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_start_date DATE;
  v_result_count INTEGER := 0;
BEGIN
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'championship_not_found';
  END IF;

  IF v_champ.template_type = 'team_league' THEN
    RAISE EXCEPTION 'wrong_tournament_format';
  END IF;

  IF v_champ.type <> 'league' THEN
    RAISE EXCEPTION 'wrong_tournament_format';
  END IF;

  IF COALESCE(v_champ.entry_fee, 0) > 0 THEN
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[])
    INTO v_team_ids
    FROM unnest(COALESCE(v_champ.paid_teams, '{}'::text[])) AS x;
  ELSE
    SELECT COALESCE(ARRAY_AGG(x::uuid), '{}'::uuid[])
    INTO v_team_ids
    FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[])) AS x;
  END IF;

  v_team_count := COALESCE(array_length(v_team_ids, 1), 0);
  IF v_team_count < 2 THEN
    RAISE EXCEPTION 'insufficient_teams';
  END IF;

  v_team_list := v_team_ids;
  IF v_team_count % 2 = 1 THEN
    v_team_list := v_team_list || NULL::uuid;
  END IF;

  v_virtual_count := array_length(v_team_list, 1);
  v_num_weeks := v_virtual_count - 1;
  v_matches_per_week := v_virtual_count / 2;
  v_two_legs := COALESCE(v_champ.is_two_legs, false);
  v_start_date := COALESCE(v_champ.start_date::date, CURRENT_DATE);

  DELETE FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  FOR v_week IN 0..(v_num_weeks - 1) LOOP
    FOR v_match IN 0..(v_matches_per_week - 1) LOOP
      v_home_idx := (v_week + v_match) % (v_virtual_count - 1);
      v_away_idx := (v_virtual_count - 1 - v_match + v_week) % (v_virtual_count - 1);

      IF v_match = 0 THEN
        v_away_idx := v_virtual_count - 1;
      END IF;

      v_home_id := v_team_list[v_home_idx + 1];
      v_away_id := v_team_list[v_away_idx + 1];

      IF v_home_id IS NOT NULL AND v_away_id IS NOT NULL THEN
        SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
        SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;

        INSERT INTO public.tournament_matches (
          championship_id, round_index, match_index, week_number, stage,
          home_team_id, home_team_name, away_team_id, away_team_name,
          match_day, status, result_status, is_completed, created_at, updated_at
        ) VALUES (
          p_championship_id, 0, v_match_index, v_week + 1, 'league',
          v_home_id, v_home_name, v_away_id, v_away_name,
          v_start_date + (v_week * COALESCE(v_champ.match_interval_days, 7)),
          'scheduled', 'scheduled', false, v_now, v_now
        );

        v_match_index := v_match_index + 1;
        v_result_count := v_result_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  IF v_two_legs THEN
    v_first_leg_weeks := v_num_weeks;

    FOR v_week IN 0..(v_first_leg_weeks - 1) LOOP
      -- Copy the original week's fixtures and reverse home/away.
      FOR v_home_id, v_away_id, v_match IN
        SELECT home_team_id, away_team_id, match_index
        FROM public.tournament_matches
        WHERE championship_id = p_championship_id
          AND week_number = v_week + 1
        ORDER BY match_index
      LOOP
        SELECT name INTO v_home_name FROM public.teams WHERE id = v_away_id;
        SELECT name INTO v_away_name FROM public.teams WHERE id = v_home_id;

        INSERT INTO public.tournament_matches (
          championship_id, round_index, match_index, week_number, stage,
          home_team_id, home_team_name, away_team_id, away_team_name,
          match_day, status, result_status, is_completed, created_at, updated_at
        ) VALUES (
          p_championship_id, 0, v_match_index, v_week + v_first_leg_weeks + 1, 'league',
          v_away_id, v_home_name, v_home_id, v_away_name,
          v_start_date + ((v_week + v_first_leg_weeks) * COALESCE(v_champ.match_interval_days, 7)),
          'scheduled', 'scheduled', false, v_now, v_now
        );

        v_match_index := v_match_index + 1;
        v_result_count := v_result_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  RETURN v_result_count;
END;
$function$
;

-- Function: generate_team_challenge_code
CREATE OR REPLACE FUNCTION public.generate_team_challenge_code(p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_team     record;
  v_code     text;
  v_code_id  uuid;
  v_now      timestamptz := timezone('utc', now());
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  -- Expire any active code that has passed its expiration
  UPDATE public.team_challenge_codes
  SET status = 'expired'
  WHERE team_id = p_team_id AND status = 'active' AND expires_at IS NOT NULL AND expires_at < v_now;

  -- Return existing active, unexpired code if present
  SELECT code, id INTO v_code, v_code_id
  FROM public.team_challenge_codes
  WHERE team_id = p_team_id AND status = 'active'
    AND (expires_at IS NULL OR expires_at > v_now)
  ORDER BY created_at DESC LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'code', v_code,
      'code_id', v_code_id,
      'team_id', p_team_id,
      'team_name', v_team.name,
      'expires_at', (SELECT expires_at FROM public.team_challenge_codes WHERE id = v_code_id)
    );
  END IF;

  -- Generate fresh code with strict 7-day expiration
  v_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at, expires_at)
  VALUES (p_team_id, v_code, 'active', v_now, v_now + INTERVAL '7 days')
  RETURNING id INTO v_code_id;

  RETURN jsonb_build_object(
    'success', true,
    'code', v_code,
    'code_id', v_code_id,
    'team_id', p_team_id,
    'team_name', v_team.name,
    'expires_at', v_now + INTERVAL '7 days'
  );
END;
$function$
;

-- Function: generate_team_invite_code
CREATE OR REPLACE FUNCTION public.generate_team_invite_code(p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_captain_id UUID;
    v_team_name TEXT;
    v_code TEXT;
    v_chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    v_i INT;
    v_exists BOOLEAN;
BEGIN
    -- 1. Authentication Check (Fail-Closed)
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Fetch team info
    SELECT captain_id, name INTO v_captain_id, v_team_name
    FROM public.teams
    WHERE id = p_team_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Team not found with ID: %', p_team_id;
    END IF;

    -- 3. Authorization: Caller must be team captain or admin/co_founder
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
    IF v_caller_id <> v_captain_id AND v_caller_role NOT IN ('admin', 'co_founder') THEN
        RAISE EXCEPTION 'Forbidden: Only the team captain can generate a matchup invite code';
    END IF;

    -- 4. Generate unique 6-character code
    LOOP
        v_code := '';
        FOR v_i IN 1..6 LOOP
            v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
        END LOOP;

        SELECT EXISTS (
            SELECT 1 FROM public.teams WHERE active_invite_code = v_code
        ) INTO v_exists;

        EXIT WHEN NOT v_exists;
    END LOOP;

    -- 5. Update team with new code and 1-hour expiration (invalidates any old code immediately)
    UPDATE public.teams
    SET active_invite_code = v_code,
        invite_code_expires_at = timezone('utc'::text, now()) + INTERVAL '1 hour'
    WHERE id = p_team_id;

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'team_name', v_team_name,
        'invite_code', v_code,
        'expires_at', (timezone('utc'::text, now()) + INTERVAL '1 hour')
    );
END;
$function$
;

-- Function: generate_team_league_fixtures
CREATE OR REPLACE FUNCTION public.generate_team_league_fixtures(p_championship_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_template_type TEXT;
  v_teams UUID[];
  v_team_count INTEGER;
  v_virtual_count INTEGER;
  v_rounds_count INTEGER;
  v_matches_per_round INTEGER;
  v_interval_days INTEGER;
  v_start_date DATE;
  v_round_idx INTEGER;
  v_match_idx INTEGER;
  v_t1_idx INTEGER;
  v_t2_idx INTEGER;
  v_home_id UUID;
  v_away_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_bye_dummy UUID := '00000000-0000-0000-0000-000000000000'::UUID;
  v_now TIMESTAMPTZ := timezone('utc', now());
BEGIN
  SELECT template_type,
         COALESCE(match_interval_days, 7),
         COALESCE(start_date::date, CURRENT_DATE)
    INTO v_template_type, v_interval_days, v_start_date
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF v_template_type IS NULL OR v_template_type <> 'team_league' THEN
    RAISE EXCEPTION 'Championship is not a valid team_league';
  END IF;

  SELECT ARRAY_AGG(jt.team_id_text::uuid ORDER BY jt.ordinality)
    INTO v_teams
  FROM unnest(
    COALESCE(
      (SELECT joined_teams
       FROM public.championships
       WHERE id = p_championship_id),
      '{}'::text[]
    )
  ) WITH ORDINALITY AS jt(team_id_text, ordinality);

  v_team_count := COALESCE(ARRAY_LENGTH(v_teams, 1), 0);

  IF v_team_count < 4 OR v_team_count > 8 THEN
    RAISE EXCEPTION 'Team league requires between 4 and 8 teams (current: %)', v_team_count;
  END IF;

  IF v_team_count % 2 <> 0 THEN
    v_teams := v_teams || v_bye_dummy;
    v_virtual_count := v_team_count + 1;
  ELSE
    v_virtual_count := v_team_count;
  END IF;

  v_rounds_count := v_virtual_count - 1;
  v_matches_per_round := v_virtual_count / 2;

  DELETE FROM public.tournament_matches
  WHERE championship_id = p_championship_id
    AND COALESCE(result_status, 'scheduled') = 'scheduled'
    AND result_confirmed_at IS NULL
    AND COALESCE(is_completed, false) = false;

  FOR v_round_idx IN 0..(v_rounds_count - 1) LOOP
    FOR v_match_idx IN 0..(v_matches_per_round - 1) LOOP
      IF v_match_idx = 0 THEN
        v_t1_idx := v_virtual_count - 1;
        v_t2_idx := v_round_idx % (v_virtual_count - 1);
      ELSE
        v_t1_idx := (v_round_idx + v_match_idx) % (v_virtual_count - 1);
        v_t2_idx := (v_round_idx - v_match_idx + (v_virtual_count - 1)) % (v_virtual_count - 1);
      END IF;

      v_home_id := v_teams[v_t1_idx + 1];
      v_away_id := v_teams[v_t2_idx + 1];

      IF v_round_idx % 2 = 1 AND v_match_idx = 0 THEN
        DECLARE
          v_temp UUID := v_home_id;
        BEGIN
          v_home_id := v_away_id;
          v_away_id := v_temp;
        END;
      END IF;

      IF v_home_id = v_bye_dummy OR v_away_id = v_bye_dummy THEN
        CONTINUE;
      END IF;

      SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
      SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;

      INSERT INTO public.tournament_matches (
        championship_id,
        stage,
        week_number,
        match_index,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        match_day,
        status,
        result_status,
        is_completed,
        created_at,
        updated_at
      ) VALUES (
        p_championship_id,
        'league',
        v_round_idx + 1,
        v_match_idx,
        v_home_id,
        v_home_name,
        v_away_id,
        v_away_name,
        v_start_date + (v_round_idx * v_interval_days),
        'scheduled',
        'scheduled',
        false,
        v_now,
        v_now
      );
    END LOOP;
  END LOOP;

  UPDATE public.championships
  SET status = 'ongoing',
      registration_locked_at = COALESCE(registration_locked_at, v_now),
      updated_at = v_now
  WHERE id = p_championship_id
    AND status = 'open';
END;
$function$
;

-- Function: generate_tournament_bracket_atomic
CREATE OR REPLACE FUNCTION public.generate_tournament_bracket_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
    v_team_ids UUID[];
    v_total_teams INT;
    v_capacity INT := 4;
    v_total_rounds INT;
    v_start_round INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_match_count INT;
    v_shuffled_ids UUID[];
    v_slots UUID[];
    v_r INT;
    v_m INT;
    v_home_id UUID;
    v_away_id UUID;
    v_home_name TEXT;
    v_away_name TEXT;
    v_next_m INT;
    v_is_home_slot BOOLEAN;
BEGIN
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً.');
    END IF;

    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط منظم البطولة أو الأدمن يمكنه إطلاق القرعة.');
        END IF;
    END IF;

    IF v_champ.status = 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'هذه البطولة منتهية بالفعل.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.tournament_matches 
        WHERE championship_id = p_championship_id 
          AND (is_completed = true OR home_score IS NOT NULL OR away_score IS NOT NULL)
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إعادة توليد القرعة لوجود مباريات مسجلة النتائج أو مكتملة بالفعل.');
    END IF;

    IF COALESCE(v_champ.entry_fee, 0) > 0 THEN
        v_team_ids := COALESCE(v_champ.paid_teams, ARRAY[]::UUID[]);
    ELSE
        v_team_ids := COALESCE(v_champ.joined_teams, ARRAY[]::UUID[]);
    END IF;

    v_total_teams := COALESCE(array_length(v_team_ids, 1), 0);
    IF v_total_teams < 2 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب وجود فريقين مسجلين ومستوفين لشروط السداد على الأقل لبدء البطولة.');
    END IF;

    IF v_total_teams <= 4 THEN
        v_capacity := 4;
        v_total_rounds := 2;
    ELSIF v_total_teams <= 8 THEN
        v_capacity := 8;
        v_total_rounds := 3;
    ELSIF v_total_teams <= 16 THEN
        v_capacity := 16;
        v_total_rounds := 4;
    ELSE
        v_capacity := 32;
        v_total_rounds := 5;
    END IF;

    v_start_round := v_total_rounds - 1;

    DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;

    CREATE TEMP TABLE temp_bracket_matches (
        round_idx INT,
        match_idx INT,
        match_id UUID DEFAULT gen_random_uuid(),
        next_match_id UUID,
        home_team_id UUID,
        home_team_name TEXT,
        away_team_id UUID,
        away_team_name TEXT,
        home_score INT,
        away_score INT,
        winner_id UUID,
        status TEXT DEFAULT 'scheduled',
        is_completed BOOLEAN DEFAULT false
    ) ON COMMIT DROP;

    FOR v_r IN REVERSE v_start_round..0 LOOP
        v_match_count := (1 << v_r);
        FOR v_m IN 0..(v_match_count - 1) LOOP
            INSERT INTO temp_bracket_matches (round_idx, match_idx)
            VALUES (v_r, v_m);
        END LOOP;
    END LOOP;

    UPDATE temp_bracket_matches curr
    SET next_match_id = parent.match_id
    FROM temp_bracket_matches parent
    WHERE parent.round_idx = curr.round_idx - 1
      AND parent.match_idx = (curr.match_idx / 2)
      AND curr.round_idx > 0;

    SELECT ARRAY_AGG(t_id ORDER BY random()) INTO v_shuffled_ids
    FROM unnest(v_team_ids) AS t_id;

    v_slots := ARRAY[]::UUID[];
    FOR i IN 1..v_capacity LOOP
        IF i <= v_total_teams THEN
            v_slots := array_append(v_slots, v_shuffled_ids[i]);
        ELSE
            v_slots := array_append(v_slots, NULL);
        END IF;
    END LOOP;

    v_match_count := (1 << v_start_round);
    FOR v_m IN 0..(v_match_count - 1) LOOP
        v_home_id := v_slots[(v_m * 2) + 1];
        v_away_id := v_slots[(v_m * 2) + 2];
        
        v_home_name := NULL;
        IF v_home_id IS NOT NULL THEN
            SELECT name INTO v_home_name FROM public.teams WHERE id = v_home_id;
        END IF;

        v_away_name := NULL;
        IF v_away_id IS NOT NULL THEN
            SELECT name INTO v_away_name FROM public.teams WHERE id = v_away_id;
        END IF;

        IF v_home_id IS NOT NULL AND v_away_id IS NULL THEN
            UPDATE temp_bracket_matches
            SET home_team_id = v_home_id, home_team_name = v_home_name,
                winner_id = v_home_id, home_score = 0, away_score = 0,
                is_completed = true, status = 'completed'
            WHERE round_idx = v_start_round AND match_idx = v_m;

            v_next_m := v_m / 2;
            v_is_home_slot := (v_m % 2 = 0);
            IF v_start_round > 0 THEN
                IF v_is_home_slot THEN
                    UPDATE temp_bracket_matches
                    SET home_team_id = v_home_id, home_team_name = v_home_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                ELSE
                    UPDATE temp_bracket_matches
                    SET away_team_id = v_home_id, away_team_name = v_home_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                END IF;
            END IF;

        ELSIF v_home_id IS NULL AND v_away_id IS NOT NULL THEN
            UPDATE temp_bracket_matches
            SET away_team_id = v_away_id, away_team_name = v_away_name,
                winner_id = v_away_id, home_score = 0, away_score = 0,
                is_completed = true, status = 'completed'
            WHERE round_idx = v_start_round AND match_idx = v_m;

            v_next_m := v_m / 2;
            v_is_home_slot := (v_m % 2 = 0);
            IF v_start_round > 0 THEN
                IF v_is_home_slot THEN
                    UPDATE temp_bracket_matches
                    SET home_team_id = v_away_id, home_team_name = v_away_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                ELSE
                    UPDATE temp_bracket_matches
                    SET away_team_id = v_away_id, away_team_name = v_away_name
                    WHERE round_idx = v_start_round - 1 AND match_idx = v_next_m;
                END IF;
            END IF;

        ELSE
            UPDATE temp_bracket_matches
            SET home_team_id = v_home_id, home_team_name = v_home_name,
                away_team_id = v_away_id, away_team_name = v_away_name
            WHERE round_idx = v_start_round AND match_idx = v_m;
        END IF;
    END LOOP;

    INSERT INTO public.tournament_matches (
        id, championship_id, round_index, match_index, next_match_id,
        home_team_id, home_team_name, away_team_id, away_team_name,
        home_score, away_score, winner_id, status, is_completed,
        created_at, updated_at
    )
    SELECT 
        match_id, p_championship_id, round_idx, match_idx, next_match_id,
        home_team_id, home_team_name, away_team_id, away_team_name,
        home_score, away_score, winner_id, status, is_completed,
        v_now, v_now
    FROM temp_bracket_matches
    ORDER BY round_idx ASC;

    -- 🆕 قفل باب التسجيل عند توليد القرعة
    UPDATE public.championships
    SET status = 'ongoing',
        registration_locked_at = v_now,
        updated_at = v_now
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true,
        'championship_id', p_championship_id,
        'capacity', v_capacity,
        'total_teams', v_total_teams,
        'rounds_count', v_total_rounds,
        'message', 'تم توليد شجرة المباريات وإطلاق البطولة بنجاح.'
    );
END;
$function$
;

-- Function: generate_tournament_bracket_fixtures_internal
CREATE OR REPLACE FUNCTION public.generate_tournament_bracket_fixtures_internal(p_championship_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_type TEXT;
  v_template TEXT;
  v_result JSONB;
BEGIN
  SELECT type, template_type INTO v_type, v_template
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF v_template = 'team_league' THEN
    RAISE EXCEPTION 'wrong_tournament_format';
  END IF;

  IF v_type = 'league' THEN
    PERFORM public.generate_regular_league_fixtures_internal(p_championship_id);
  ELSIF v_type = 'groups' THEN
    PERFORM public.generate_regular_group_fixtures_internal(p_championship_id);
  ELSE
    v_result := public.generate_tournament_bracket_atomic(p_championship_id);
    IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION '%', COALESCE(v_result->>'error', 'تعذر توليد قرعة البطولة');
    END IF;
  END IF;

  -- start_championship_atomic owns the draw-ready transition.
  UPDATE public.championships
  SET status = 'open',
      registration_locked_at = COALESCE(registration_locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_championship_id;
END;
$function$
;

-- Function: get_admin_metrics
CREATE OR REPLACE FUNCTION public.get_admin_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_role TEXT;
    v_total_owners int;
    v_pending_verifications int;
    v_active_stadiums int;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RAISE EXCEPTION 'Unauthorized: Admin access required';
        END IF;
    END IF;

    SELECT count(*) INTO v_total_owners
    FROM public.users
    WHERE role = 'owner';

    SELECT count(*) INTO v_pending_verifications
    FROM public.users
    WHERE role = 'owner' AND verification_status = 'pending';

    SELECT count(*) INTO v_active_stadiums
    FROM public.stadiums
    WHERE is_verified = true AND is_blocked = false AND is_deleted_by_owner = false;

    RETURN jsonb_build_object(
        'total_owners', v_total_owners,
        'pending_verifications', v_pending_verifications,
        'active_stadiums', v_active_stadiums
    );
END;
$function$
;

-- Function: get_admin_quick_metrics
CREATE OR REPLACE FUNCTION public.get_admin_quick_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_owners integer;
  v_pending_verifications integer;
  v_active_bookings integer;
  v_total_revenue numeric;
BEGIN
  -- Verify admin authorization
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = ANY(ARRAY['admin', 'co_founder', 'super_admin', 'cofounder'])
    ) THEN
      RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT count(*) INTO v_total_owners FROM public.users WHERE role = 'owner';
  SELECT count(*) INTO v_pending_verifications FROM public.users WHERE role = 'owner' AND verification_status = 'pending';
  SELECT count(*) INTO v_active_bookings FROM public.bookings WHERE status IN ('confirmed', 'upcoming');

  -- Gross platform completed turnover: only completed payments, excluding duplicates, refunds, payouts
  SELECT COALESCE(sum(amount), 0) INTO v_total_revenue 
  FROM public.transactions 
  WHERE type IN ('digital', 'cash_settlement') 
    AND status = 'completed';

  RETURN jsonb_build_object(
    'total_owners', v_total_owners,
    'pending_verifications', v_pending_verifications,
    'active_bookings', v_active_bookings,
    'total_revenue', v_total_revenue
  );
END;
$function$
;

-- Function: get_championship_actions
CREATE OR REPLACE FUNCTION public.get_championship_actions(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ             RECORD;
  v_user_id           UUID    := auth.uid();
  v_is_owner          BOOLEAN := false;
  v_is_admin          BOOLEAN := false;
  v_is_tl             BOOLEAN := false;
  v_teams_current     INTEGER := 0;
  v_matches_count     INTEGER := 0;
  v_paid_orders_count INTEGER := 0;
  v_has_history       BOOLEAN := false;
  -- Outputs
  v_can_edit          BOOLEAN := false;
  v_can_basic         BOOLEAN := false;
  v_can_structure     BOOLEAN := false;
  v_can_cancel        BOOLEAN := false;
  v_can_delete        BOOLEAN := false;
  v_reason            TEXT    := '';
  v_locked            TEXT[]  := ARRAY[]::TEXT[];
  v_editable          TEXT[]  := ARRAY[]::TEXT[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  -- Identity
  v_is_owner := (v_champ.owner_id = v_user_id);
  SELECT EXISTS(
    SELECT 1 FROM public.users
    WHERE id = v_user_id AND role IN ('admin','co_founder','super_admin','cofounder')
  ) INTO v_is_admin;
  v_is_tl := COALESCE(v_champ.template_type, '') = 'team_league';

  -- Non-owner & non-admin -> no permissions
  IF NOT v_is_owner AND NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'can_edit', false, 'can_edit_basic_info', false,
      'can_edit_structure', false, 'can_cancel', false,
      'can_delete', false, 'reason', 'not_authorized',
      'teams_count', 0, 'matches_count', 0, 'is_team_league', v_is_tl
    );
  END IF;

  -- Current active counts
  v_teams_current := COALESCE(array_length(v_champ.joined_teams, 1), 0);

  SELECT COUNT(*) INTO v_matches_count
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  SELECT COUNT(*) INTO v_paid_orders_count
  FROM public.tournament_orders
  WHERE championship_id = p_championship_id AND payment_status IN ('paid', 'refund_requested');

  IF v_is_tl THEN
    SELECT v_paid_orders_count + COUNT(*) INTO v_paid_orders_count
    FROM public.team_league_payments
    WHERE championship_id = p_championship_id AND payment_status IN ('paid', 'refund_requested');
  END IF;

  -- ============================================================
  -- Historical Proof Check: Has this tournament EVER had ANY activity?
  -- Used strictly for delete permission.
  -- ============================================================
  v_has_history := (
    v_teams_current > 0 OR
    COALESCE(array_length(v_champ.paid_teams, 1), 0) > 0 OR
    v_matches_count > 0 OR
    EXISTS(SELECT 1 FROM public.championship_rosters WHERE championship_id = p_championship_id) OR
    EXISTS(SELECT 1 FROM public.tournament_orders WHERE championship_id = p_championship_id) OR
    EXISTS(SELECT 1 FROM public.team_league_payments WHERE championship_id = p_championship_id) OR
    EXISTS(SELECT 1 FROM public.financial_audit_logs WHERE (metadata->>'championship_id')::text = p_championship_id::text) OR
    EXISTS(SELECT 1 FROM public.transactions WHERE (metadata->>'championship_id')::text = p_championship_id::text)
  );

  -- ── State Machine ─────────────────────────────────────────
  IF v_champ.status = 'open' THEN
    IF NOT v_has_history THEN
      -- PRISTINE OPEN (No teams, no history, no orders)
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := NOT v_is_tl; -- Team League structure always locked
      v_can_cancel    := true;
      v_can_delete    := true;
      v_reason        := 'pre_registration';
      v_editable := CASE WHEN v_is_tl
        THEN ARRAY['name','logo_url','governorate','rules','start_date','end_date']
        ELSE ARRAY['name','logo_url','governorate','rules','start_date','end_date',
                   'entry_fee','grand_prize','max_teams','max_players_per_team',
                   'min_players_per_team','match_duration','type','number_of_groups',
                   'qualifying_per_group','is_two_legs','is_back_and_forth',
                   'winning_points','draw_points','loss_points']
      END;

    ELSIF v_matches_count = 0 THEN
      -- REGISTRATION STARTED OR HISTORICAL ACTIVITY EXISTS (matches not yet generated)
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := false;
      v_can_cancel    := true;
      v_can_delete    := false; -- Locked by historical record
      v_reason        := 'registration_started';
      v_editable := ARRAY['name','logo_url','rules'];
      v_locked   := ARRAY['entry_fee','grand_prize','max_teams','max_players_per_team',
                          'min_players_per_team','type','number_of_groups',
                          'qualifying_per_group','is_two_legs','is_back_and_forth',
                          'winning_points','draw_points','loss_points','start_date','end_date'];

    ELSE
      -- FIXTURES GENERATED
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := false;
      v_can_cancel    := false;
      v_can_delete    := false;
      v_reason        := 'fixtures_generated';
      v_editable := ARRAY['name','logo_url','rules'];
      v_locked   := ARRAY['entry_fee','grand_prize','max_teams','type',
                          'number_of_groups','qualifying_per_group','is_two_legs',
                          'winning_points','draw_points','loss_points','start_date','end_date'];
    END IF;

  ELSIF v_champ.status = 'ongoing' THEN
    v_can_edit      := true;
    v_can_basic     := true;
    v_can_structure := false;
    v_can_cancel    := false;
    v_can_delete    := false;
    v_reason        := 'competition_in_progress';
    v_editable := ARRAY['logo_url','rules'];
    v_locked   := ARRAY['entry_fee','grand_prize','max_teams','type',
                        'number_of_groups','start_date','end_date','winning_points',
                        'draw_points','loss_points','name'];

  ELSIF v_champ.status = 'completed' THEN
    v_can_edit      := false;
    v_can_basic     := false;
    v_can_structure := false;
    v_can_cancel    := false;
    v_can_delete    := false;
    v_reason        := 'competition_completed';

  ELSIF v_champ.status = 'cancelled' THEN
    v_can_edit      := false;
    v_can_basic     := false;
    v_can_structure := false;
    v_can_cancel    := false;
    v_can_delete    := false;
    v_reason        := 'already_cancelled';

  ELSE
    v_reason := 'unknown_status_' || COALESCE(v_champ.status,'null');
  END IF;

  RETURN jsonb_build_object(
    'can_edit',            v_can_edit,
    'can_edit_basic_info',  v_can_basic,
    'can_edit_structure',   v_can_structure,
    'can_cancel',          v_can_cancel,
    'can_delete',          v_can_delete,
    'reason',              v_reason,
    'editable_fields',     to_jsonb(v_editable),
    'locked_fields',       to_jsonb(v_locked),
    'teams_count',         v_teams_current,
    'matches_count',       v_matches_count,
    'paid_orders_count',   v_paid_orders_count,
    'has_history',         v_has_history,
    'is_team_league',      v_is_tl
  );
END;
$function$
;

-- Function: get_championship_public_state
CREATE OR REPLACE FUNCTION public.get_championship_public_state(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_stadium RECORD;
  v_fixtures_count INT;
  v_confirmed_teams_count INT;
  v_effective_phase TEXT;
  v_can_join BOOLEAN := false;
  v_join_block_reason TEXT := NULL;
  v_caller_id UUID := auth.uid();
  v_my_registrations JSONB := '[]'::JSONB;
  v_pricing RECORD;
  v_pricing_available BOOLEAN := false;
  v_caller_reg RECORD;
  v_caller_is_captain BOOLEAN := false;
BEGIN
  SELECT c.id, c.name, c.status, c.entry_fee, c.grand_prize, c.max_teams, c.owner_id,
         c.start_date, c.end_date, c.registration_closes_at, c.registration_locked_at,
         c.min_players_per_team, c.max_players_per_team, c.stadium_id, c.currency,
         c.type, c.rules, c.is_approved, c.creation_fee_paid
  INTO v_champ
  FROM public.championships c
  WHERE c.id = p_championship_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  SELECT s.id, s.name, s.location, s.governorate, s.city, s.lat, s.lng, s.image_url, s.images
  INTO v_stadium
  FROM public.stadiums s
  WHERE s.id = v_champ.stadium_id;

  SELECT count(*)::INT INTO v_fixtures_count
  FROM public.tournament_matches tm
  WHERE tm.championship_id = p_championship_id;

  SELECT count(*)::INT INTO v_confirmed_teams_count
  FROM public.championship_registrations cr
  WHERE cr.championship_id = p_championship_id
    AND cr.registration_status = 'confirmed';

  -- Phase Engine SSOT
  IF v_champ.status = 'cancelled' THEN
    v_effective_phase := 'cancelled';
  ELSIF v_champ.status = 'completed' THEN
    v_effective_phase := 'completed';
  ELSIF v_champ.status = 'ongoing' THEN
    v_effective_phase := 'ongoing';
  ELSIF v_champ.status = 'open' AND v_champ.registration_locked_at IS NOT NULL AND v_fixtures_count > 0 THEN
    v_effective_phase := 'draw_ready';
  ELSIF v_champ.status = 'open' AND (
    v_champ.registration_locked_at IS NOT NULL
    OR (v_champ.registration_closes_at IS NOT NULL AND now() >= v_champ.registration_closes_at)
    OR now() >= v_champ.start_date
  ) THEN
    v_effective_phase := 'registration_closed';
  ELSIF v_champ.status = 'open' AND coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = false THEN
    v_effective_phase := 'draft';
  ELSIF v_champ.status = 'open' AND coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = true THEN
    v_effective_phase := 'pending_approval';
  ELSE
    v_effective_phase := 'registration_open';
  END IF;

  -- Join Eligibility Engine
  IF v_caller_id IS NULL THEN
    v_can_join := false;
    v_join_block_reason := 'AUTH_REQUIRED';
  ELSIF v_effective_phase = 'cancelled' THEN
    v_can_join := false;
    v_join_block_reason := 'CHAMPIONSHIP_CANCELLED';
  ELSIF v_effective_phase IN ('ongoing', 'completed') THEN
    v_can_join := false;
    v_join_block_reason := 'CHAMPIONSHIP_STARTED';
  ELSIF v_effective_phase != 'registration_open' THEN
    v_can_join := false;
    v_join_block_reason := 'REGISTRATION_CLOSED';
  ELSIF v_confirmed_teams_count >= v_champ.max_teams THEN
    v_can_join := false;
    v_join_block_reason := 'CHAMPIONSHIP_FULL';
  ELSE
    SELECT EXISTS (SELECT 1 FROM public.teams WHERE captain_id = v_caller_id) INTO v_caller_is_captain;
    IF NOT v_caller_is_captain THEN
      v_can_join := false;
      v_join_block_reason := 'NOT_CAPTAIN';
    ELSE
      SELECT cr.registration_status, cr.payment_status
      INTO v_caller_reg
      FROM public.championship_registrations cr
      JOIN public.teams t ON t.id = cr.team_id
      WHERE cr.championship_id = p_championship_id
        AND t.captain_id = v_caller_id
        AND cr.registration_status NOT IN ('cancelled', 'cancelled_unpaid', 'rejected')
      LIMIT 1;

      IF FOUND THEN
        v_can_join := false;
        IF v_caller_reg.payment_status = 'pending' THEN
          v_join_block_reason := 'PAYMENT_PENDING';
        ELSE
          v_join_block_reason := 'TEAM_ALREADY_REGISTERED';
        END IF;
      ELSE
        v_can_join := true;
        v_join_block_reason := NULL;
      END IF;
    END IF;
  END IF;

  IF v_caller_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'registration_id', cr.id,
      'team_id', cr.team_id,
      'team_name', t.name,
      'team_logo_url', t.logo_url,
      'registration_status', cr.registration_status,
      'payment_status', cr.payment_status,
      'is_captain', (t.captain_id = v_caller_id),
      'can_manage_roster', (t.captain_id = v_caller_id AND v_champ.registration_locked_at IS NULL),
      'gross_amount', cr.gross_amount
    )), '[]'::JSONB)
    INTO v_my_registrations
    FROM public.championship_registrations cr
    JOIN public.teams t ON t.id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND EXISTS (
        SELECT 1 FROM public.team_members tm 
        WHERE tm.team_id = cr.team_id AND tm.user_id = v_caller_id
      );
  END IF;

  SELECT * INTO v_pricing FROM public.calculate_tournament_checkout_amount_atomic(p_championship_id);
  v_pricing_available := (v_effective_phase = 'registration_open' AND v_can_join = true);

  RETURN jsonb_build_object(
    'success', true,
    'championship', jsonb_build_object(
      'id', v_champ.id,
      'name', v_champ.name,
      'status', v_champ.status,
      'effective_phase', v_effective_phase,
      'entry_fee', v_champ.entry_fee,
      'grand_prize', v_champ.grand_prize,
      'currency', coalesce(v_champ.currency, 'EGP'),
      'max_teams', v_champ.max_teams,
      'confirmed_teams_count', v_confirmed_teams_count,
      'min_players_per_team', v_champ.min_players_per_team,
      'max_players_per_team', v_champ.max_players_per_team,
      'start_date', v_champ.start_date,
      'end_date', v_champ.end_date,
      'registration_closes_at', v_champ.registration_closes_at,
      'registration_locked_at', v_champ.registration_locked_at,
      'rules', v_champ.rules,
      'stadium', CASE WHEN v_stadium.id IS NOT NULL THEN jsonb_build_object(
        'id', v_stadium.id,
        'name', v_stadium.name,
        'location', v_stadium.location,
        'governorate', v_stadium.governorate,
        'city', v_stadium.city,
        'lat', v_stadium.lat,
        'lng', v_stadium.lng,
        'image_url', v_stadium.image_url,
        'images', v_stadium.images
      ) ELSE NULL END
    ),
    'pricing', jsonb_build_object(
      'available', v_pricing_available,
      'base_amount', v_pricing.base_amount,
      'platform_fee_amount', v_pricing.platform_fee_amount,
      'gateway_fee_amount', v_pricing.gateway_fee_amount,
      'gross_amount', v_pricing.gross_amount,
      'currency', v_pricing.currency
    ),
    'capabilities', jsonb_build_object(
      'can_join', v_can_join,
      'join_block_reason', v_join_block_reason,
      'can_view_bracket', (v_fixtures_count > 0)
    ),
    'my_registrations', v_my_registrations
  );
END;
$function$
;

-- Function: get_championship_standings
CREATE OR REPLACE FUNCTION public.get_championship_standings(p_championship_id uuid, p_group_name text DEFAULT NULL::text)
 RETURNS TABLE(team_id uuid, team_name text, played bigint, won bigint, drawn bigint, lost bigint, goals_for bigint, goals_against bigint, goal_difference bigint, points bigint)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ_type TEXT;
BEGIN
  SELECT type INTO v_champ_type FROM public.championships WHERE id = p_championship_id;

  RETURN QUERY
  WITH eligible_matches AS (
    SELECT m.*
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.status = 'completed'
      AND m.result_status IN ('confirmed', 'locked')
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
      AND (
        -- If specific group requested, strictly group_stage and matching group_name
        (p_group_name IS NOT NULL AND m.stage = 'group_stage' AND m.group_name = p_group_name)
        OR
        -- If no group requested and championship is a league, strictly league matches
        (p_group_name IS NULL AND (m.stage = 'league' OR (m.stage IS NULL AND v_champ_type = 'league')))
        OR
        -- If no group requested and championship has group_stage matches
        (p_group_name IS NULL AND m.stage = 'group_stage')
      )
  ),
  group_teams AS (
    SELECT DISTINCT
      t.id AS t_id,
      t.name AS t_name
    FROM public.tournament_matches m
    JOIN public.teams t ON (t.id = m.home_team_id OR t.id = m.away_team_id)
    WHERE m.championship_id = p_championship_id
      AND (
        (p_group_name IS NOT NULL AND m.stage = 'group_stage' AND m.group_name = p_group_name)
        OR
        (p_group_name IS NULL AND (m.stage IN ('group_stage', 'league') OR (m.stage IS NULL AND v_champ_type = 'league')))
      )
    
    UNION
    
    SELECT cr.team_id AS t_id, t.name AS t_name
    FROM public.championship_rosters cr
    JOIN public.teams t ON t.id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND p_group_name IS NULL
  ),
  match_results AS (
    -- Home team perspective
    SELECT
      m.home_team_id AS t_id,
      1 AS p,
      CASE WHEN m.home_score > m.away_score THEN 1 ELSE 0 END AS w,
      CASE WHEN m.home_score = m.away_score THEN 1 ELSE 0 END AS d,
      CASE WHEN m.home_score < m.away_score THEN 1 ELSE 0 END AS l,
      COALESCE(m.home_score, 0) AS gf,
      COALESCE(m.away_score, 0) AS ga,
      CASE
        WHEN m.home_score > m.away_score THEN 3
        WHEN m.home_score = m.away_score THEN 1
        ELSE 0
      END AS pts
    FROM eligible_matches m

    UNION ALL

    -- Away team perspective
    SELECT
      m.away_team_id AS t_id,
      1 AS p,
      CASE WHEN m.away_score > m.home_score THEN 1 ELSE 0 END AS w,
      CASE WHEN m.away_score = m.home_score THEN 1 ELSE 0 END AS d,
      CASE WHEN m.away_score < m.home_score THEN 1 ELSE 0 END AS l,
      COALESCE(m.away_score, 0) AS gf,
      COALESCE(m.home_score, 0) AS ga, -- Corrected: Away team goals against = home score!
      CASE
        WHEN m.away_score > m.home_score THEN 3
        WHEN m.away_score = m.home_score THEN 1
        ELSE 0
      END AS pts
    FROM eligible_matches m
  )
  SELECT
    gt.t_id AS team_id,
    MAX(gt.t_name) AS team_name,
    COALESCE(SUM(r.p), 0) AS played,
    COALESCE(SUM(r.w), 0) AS won,
    COALESCE(SUM(r.d), 0) AS drawn,
    COALESCE(SUM(r.l), 0) AS lost,
    COALESCE(SUM(r.gf), 0) AS goals_for,
    COALESCE(SUM(r.ga), 0) AS goals_against,
    COALESCE(SUM(r.gf) - SUM(r.ga), 0) AS goal_difference,
    COALESCE(SUM(r.pts), 0) AS points
  FROM group_teams gt
  LEFT JOIN match_results r ON r.t_id = gt.t_id
  GROUP BY gt.t_id
  ORDER BY points DESC, goal_difference DESC, goals_for DESC;
END;
$function$
;

-- Function: get_collective_invite_credentials
CREATE OR REPLACE FUNCTION public.get_collective_invite_credentials(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;
  SELECT * INTO v_booking FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid<>v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;

  RETURN jsonb_build_object(
    'booking_id',v_booking.id,
    'invite_token',v_booking.collective_invite_token,
    'invite_code',v_booking.collective_invite_code,
    'active',coalesce(v_booking.collective_invite_active,false),
    'status',v_booking.status
  );
END;
$function$
;

-- Function: get_current_user_role
CREATE OR REPLACE FUNCTION public.get_current_user_role(p_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_uid uuid; v_user record; v_caller_role text;
begin
  v_uid:=coalesce(p_user_id,auth.uid());
  if v_uid is null then return jsonb_build_object('success',false,'error','NO_USER_ID'); end if;
  if auth.role()<>'service_role' then
    if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
    if v_uid is distinct from auth.uid() then
      select role into v_caller_role from public.users where id=auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
        return jsonb_build_object('success',false,'error','UNAUTHORIZED');
      end if;
    end if;
  end if;
  select id,role,subscription_plan,trial_ends_at,is_registration_complete,is_onboarding_confirmed,has_stadium
  into v_user from public.users where id=v_uid;
  if not found then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;
  return jsonb_build_object('success',true,'role',v_user.role,'subscription_plan',v_user.subscription_plan,'trial_ends_at',v_user.trial_ends_at,'is_registration_complete',v_user.is_registration_complete,'is_onboarding_confirmed',v_user.is_onboarding_confirmed,'has_stadium',v_user.has_stadium);
end; $function$
;

-- Function: get_nearby_stadiums
CREATE OR REPLACE FUNCTION public.get_nearby_stadiums(user_lat double precision, user_lng double precision, max_limit integer DEFAULT 10)
 RETURNS SETOF stadiums
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT s.*
  FROM public.stadiums s
  WHERE COALESCE(s.is_verified, false) = true
    AND COALESCE(s.is_blocked, false) = false
    AND COALESCE(s.is_deleted_by_owner, false) = false
    AND s.lat IS NOT NULL
    AND s.lng IS NOT NULL
  ORDER BY (
    6371.0 * 2.0 * asin(
      sqrt(
        power(sin(radians((s.lat - user_lat) / 2.0)), 2) +
        cos(radians(user_lat)) * cos(radians(s.lat)) *
        power(sin(radians((s.lng - user_lng) / 2.0)), 2)
      )
    )
  ) ASC
  LIMIT GREATEST(1, LEAST(COALESCE(max_limit, 10), 100));
$function$
;

-- Function: get_operational_date
CREATE OR REPLACE FUNCTION public.get_operational_date(p_timestamp timestamp with time zone, p_shift_start_hour integer DEFAULT 6)
 RETURNS date
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_local timestamp := p_timestamp AT TIME ZONE 'Africa/Cairo';
BEGIN
  IF EXTRACT(HOUR FROM v_local) < p_shift_start_hour THEN
    RETURN (v_local - INTERVAL '1 day')::date;
  ELSE
    RETURN v_local::date;
  END IF;
END;
$function$
;

-- Function: get_owner_ai_operational_insights
CREATE OR REPLACE FUNCTION public.get_owner_ai_operational_insights(p_owner_id uuid, p_period text DEFAULT '30d'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_caller_id uuid:=auth.uid(); v_caller_role text; v_now timestamptz:=now(); v_from timestamptz; v_to timestamptz:=v_now;
 v_period text:=lower(coalesce(trim(p_period),'30d')); v_period_days numeric:=30;
 v_total_bookings int:=0; v_completed_bookings int:=0; v_confirmed_bookings int:=0; v_cancelled_bookings int:=0;
 v_gross_booking_value numeric:=0; v_realized_revenue numeric:=0; v_booked_hours numeric:=0; v_available_hours numeric:=0;
 v_utilization_pct numeric:=0; v_cancellation_rate_pct numeric:=0; v_avg_booking_value numeric:=0; v_stadium_count int:=0;
 v_cash_debt numeric:=0; v_debt_limit numeric:=0; v_debt_blocked boolean:=false; v_alerts jsonb:='[]'::jsonb;
begin
 if v_caller_id is null and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','Authentication required'); end if;
 if v_caller_id is not null then
   select role into v_caller_role from public.users where id=v_caller_id;
   if v_caller_id<>p_owner_id and coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') and current_user not in ('postgres','service_role')
   then return jsonb_build_object('success',false,'error','Unauthorized access to owner insights'); end if;
 end if;
 select coalesce(accumulated_cash_debt,0),coalesce(debt_limit,0),coalesce(is_debt_blocked,false)
 into v_cash_debt,v_debt_limit,v_debt_blocked from public.users where id=p_owner_id and role='owner';
 v_from:=case v_period when '7d' then v_now-interval '7 days' when '90d' then v_now-interval '90 days' when 'all' then '1970-01-01 00:00:00+00'::timestamptz else v_now-interval '30 days' end;
 v_period_days:=greatest(1,extract(epoch from(v_to-v_from))/86400.0);
 select count(*)::int,count(*) filter(where status='completed')::int,count(*) filter(where status='confirmed')::int,count(*) filter(where status='cancelled')::int,coalesce(sum(total_price),0)
 into v_total_bookings,v_completed_bookings,v_confirmed_bookings,v_cancelled_bookings,v_gross_booking_value
 from public.bookings where owner_id=p_owner_id and created_at>=v_from and created_at<=v_to;
 select coalesce(sum(total_price),0) into v_realized_revenue from public.bookings where owner_id=p_owner_id and created_at>=v_from and created_at<=v_to and status='completed' and payment_status='paid';
 select coalesce(sum(greatest(0,extract(epoch from(least(end_time,v_to)-greatest(start_time,v_from)))/3600.0)),0) into v_booked_hours from public.bookings where owner_id=p_owner_id and status<>'cancelled' and end_time>v_from and start_time<v_to;
 select count(*)::int into v_stadium_count from public.stadiums where owner_id=p_owner_id and coalesce(is_deleted_by_owner,false)=false;
 select coalesce(sum(((case when s.closing_time>s.opening_time then extract(epoch from(s.closing_time-s.opening_time))/3600.0 else extract(epoch from(s.closing_time-s.opening_time))/3600.0+24 end) - case when coalesce(s.is_split_shift,false) and s.break_start_time is not null and s.break_end_time is not null then case when s.break_end_time>=s.break_start_time then extract(epoch from(s.break_end_time-s.break_start_time))/3600.0 else extract(epoch from(s.break_end_time-s.break_start_time))/3600.0+24 end else 0 end)*v_period_days),0) into v_available_hours from public.stadiums s where s.owner_id=p_owner_id and coalesce(s.is_deleted_by_owner,false)=false and s.opening_time is not null and s.closing_time is not null;
 if v_available_hours>0 then v_utilization_pct:=round(v_booked_hours/v_available_hours*100,2); end if;
 if v_total_bookings>0 then v_cancellation_rate_pct:=round(v_cancelled_bookings::numeric/v_total_bookings*100,2); v_avg_booking_value:=round(v_gross_booking_value/v_total_bookings,2); end if;
 if v_cash_debt>0 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','CASH_DEBT','severity',case when v_debt_blocked or (v_debt_limit>0 and v_cash_debt>=v_debt_limit) then 'critical' else 'warning' end,'metric','accumulated_cash_debt','value',round(v_cash_debt,2),'debt_limit',round(v_debt_limit,2))); end if;
 if v_total_bookings=0 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','NO_BOOKINGS_IN_PERIOD','severity','info','metric','total_bookings','value',0,'message_ar','لا توجد حجوزات مسجلة في الفترة المحددة.','evidence',jsonb_build_object('period',v_period)));
 else
   if v_utilization_pct<25 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','LOW_UTILIZATION','severity','warning','metric','utilization_pct','value',v_utilization_pct,'threshold',25));
   elsif v_utilization_pct>=70 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','HIGH_UTILIZATION','severity','info','metric','utilization_pct','value',v_utilization_pct,'threshold',70)); end if;
   if v_cancellation_rate_pct>=15 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','HIGH_CANCELLATION_RATE','severity','warning','metric','cancellation_rate_pct','value',v_cancellation_rate_pct,'threshold',15)); end if;
 end if;
 return jsonb_build_object('success',true,'owner_id',p_owner_id,'period',v_period,'period_start',v_from,'period_end',v_to,'stadium_count',v_stadium_count,'total_bookings',v_total_bookings,'completed_bookings',v_completed_bookings,'confirmed_bookings',v_confirmed_bookings,'cancelled_bookings',v_cancelled_bookings,'gross_booking_value',round(v_gross_booking_value,2),'realized_revenue',round(v_realized_revenue,2),'booked_hours',round(v_booked_hours,2),'available_hours_estimate',round(v_available_hours,2),'utilization_pct',v_utilization_pct,'cancellation_rate_pct',v_cancellation_rate_pct,'average_booking_value',v_avg_booking_value,'accumulated_cash_debt',round(v_cash_debt,2),'debt_limit',round(v_debt_limit,2),'is_debt_blocked',v_debt_blocked,'alerts',v_alerts);
end; $function$
;

-- Function: get_owner_ai_stadium_comparison
CREATE OR REPLACE FUNCTION public.get_owner_ai_stadium_comparison(p_owner_id uuid, p_period text DEFAULT '30d'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role text;
    v_now timestamptz := now();
    v_from timestamptz;
    v_period text := lower(coalesce(trim(p_period), '30d'));
    v_days numeric;
    v_prev_from timestamptz;
    v_prev_to timestamptz;
    v_rows jsonb;
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id <> p_owner_id
           AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to stadium comparison');
        END IF;
    END IF;

    v_from := CASE v_period
        WHEN '7d' THEN v_now - interval '7 days'
        WHEN '90d' THEN v_now - interval '90 days'
        WHEN 'all' THEN '1970-01-01 00:00:00+00'::timestamptz
        ELSE v_now - interval '30 days'
    END;

    v_days := greatest(1, extract(epoch FROM (v_now - v_from)) / 86400.0);

    IF v_period <> 'all' THEN
        v_prev_to := v_from;
        v_prev_from := v_prev_to - (v_now - v_from);
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.realized_revenue DESC, x.bookings_count DESC), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT
            s.id AS stadium_id,
            s.name AS stadium_name,
            count(b.id)::int AS bookings_count,
            count(*) FILTER (WHERE b.status = 'completed')::int AS completed_bookings,
            count(*) FILTER (WHERE b.status = 'cancelled')::int AS cancelled_bookings,
            round(coalesce(sum(b.total_price),0),2) AS gross_booking_value,
            round(coalesce(sum(b.total_price) FILTER (
                WHERE b.status = 'completed'
                  AND (b.payment_status = 'paid' OR b.is_paid = true)
            ),0),2) AS realized_revenue,
            round(coalesce(sum(
                CASE
                    WHEN b.id IS NULL OR b.status = 'cancelled' THEN 0
                    ELSE greatest(0, extract(epoch FROM (
                        least(b.end_time, v_now) - greatest(b.start_time, v_from)
                    )) / 3600.0)
                END
            ),0),2) AS booked_hours,
            CASE
                WHEN count(b.id) > 0
                THEN round((count(*) FILTER (WHERE b.status = 'cancelled')::numeric / count(b.id)::numeric) * 100.0, 2)
                ELSE 0
            END AS cancellation_rate_pct,

            CASE WHEN v_period <> 'all' THEN (
                SELECT count(*)::int FROM public.bookings pb
                WHERE pb.stadium_id = s.id
                  AND pb.created_at >= v_prev_from
                  AND pb.created_at < v_prev_to
            ) ELSE NULL END AS previous_bookings_count,

            CASE WHEN v_period <> 'all' THEN (
                SELECT round(coalesce(sum(pb.total_price) FILTER (
                    WHERE pb.status = 'completed'
                      AND (pb.payment_status = 'paid' OR pb.is_paid = true)
                ),0),2)
                FROM public.bookings pb
                WHERE pb.stadium_id = s.id
                  AND pb.created_at >= v_prev_from
                  AND pb.created_at < v_prev_to
            ) ELSE NULL END AS previous_realized_revenue

        FROM public.stadiums s
        LEFT JOIN public.bookings b
          ON b.stadium_id = s.id
         AND b.created_at >= v_from
         AND b.created_at <= v_now
        WHERE s.owner_id = p_owner_id
          AND coalesce(s.is_deleted_by_owner, false) = false
        GROUP BY s.id, s.name
    ) x;

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'period', v_period,
        'period_start', v_from,
        'period_end', v_now,
        'stadiums', v_rows
    );
END;
$function$
;

-- Function: get_owner_booked_hours
CREATE OR REPLACE FUNCTION public.get_owner_booked_hours(p_owner_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0), 0)
  FROM bookings
  WHERE owner_id = p_owner_id
    AND status <> 'cancelled';
$function$
;

-- Function: get_owner_dashboard_analytics
CREATE OR REPLACE FUNCTION public.get_owner_dashboard_analytics(p_owner_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_court_id uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_result json;
  v_total_op_hours numeric := 0;
  v_booked_hours numeric := 0;
  v_total_revenue numeric := 0;
  v_cash_revenue numeric := 0;
  v_online_revenue numeric := 0;
  v_realized_revenue numeric := 0;
  v_realized_cash numeric := 0;
  v_realized_online numeric := 0;
  v_cash_collected numeric := 0;
  v_cash_uncollected numeric := 0;
  v_online_collected numeric := 0;
  v_online_pending numeric := 0;
  v_online_unavailable numeric := 0;
  v_upcoming_value numeric := 0;
  v_upcoming_cash numeric := 0;
  v_upcoming_online numeric := 0;
  v_maintenance_hours numeric := 0;
  v_total_bookings integer := 0;
  v_cash_bookings integer := 0;
  v_online_bookings integer := 0;
  v_period_days integer;
  v_avg_hourly_rate numeric := 0;
begin
  if auth.uid() is null and current_user not in ('postgres', 'service_role') then
    raise exception 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للوصول إلى تحليلات لوحة التحكم.'
      using errcode = '42501';
  end if;

  if auth.uid() is not null and auth.uid() <> p_owner_id and current_user not in ('postgres', 'service_role') then
    if not public.is_admin_or_cofounder(auth.uid()) then
      raise exception 'UNAUTHORIZED: غير مصرح بالوصول إلى بيانات هذا المالك.'
        using errcode = '42501';
    end if;
  end if;

  v_period_days := greatest(1, date_part('day', p_end_date - p_start_date)::integer);

  select coalesce(avg(price_per_hour), 0)
    into v_avg_hourly_rate
  from public.stadiums
  where owner_id = p_owner_id
    and (p_court_id is null or id = p_court_id)
    and price_per_hour > 0;

  if v_avg_hourly_rate is null or v_avg_hourly_rate < 0 then
    v_avg_hourly_rate := 0;
  end if;

  select coalesce(sum(
    case
      when s.closing_time is not null and s.opening_time is not null then
        (case
          when s.closing_time > s.opening_time then
            extract(epoch from (s.closing_time - s.opening_time)) / 3600.0
          else
            extract(epoch from ('24:00:00'::time - s.opening_time + s.closing_time)) / 3600.0
        end)
        - (case
            when s.is_split_shift is true and s.break_start_time is not null and s.break_end_time is not null then
              case
                when s.break_end_time > s.break_start_time then
                  extract(epoch from (s.break_end_time - s.break_start_time)) / 3600.0
                else
                  extract(epoch from ('24:00:00'::time - s.break_start_time + s.break_end_time)) / 3600.0
              end
            else 0.0
          end)
      else 0.0
    end
  ) * v_period_days, 0)
    into v_total_op_hours
  from public.stadiums s
  where s.owner_id = p_owner_id
    and (p_court_id is null or s.id = p_court_id)
    and coalesce(s.is_deleted_by_owner, false) = false;

  -- Maintenance closes capacity but is not customer demand and must not
  -- inflate occupancy or appear as lost revenue.
  select coalesce(sum(
    greatest(
      0,
      extract(
        epoch from (
          least(b.end_time, p_end_date) - greatest(b.start_time, p_start_date)
        )
      ) / 3600.0
    )
  ), 0)
  into v_maintenance_hours
  from public.bookings b
  join public.stadiums s on s.id = b.stadium_id
  where s.owner_id = p_owner_id
    and (p_court_id is null or s.id = p_court_id)
    and coalesce(s.is_deleted_by_owner, false) = false
    and b.booking_type = 'maintenance'
    and b.status <> 'cancelled'
    and b.start_time < p_end_date
    and b.end_time > p_start_date;

  v_total_op_hours := greatest(v_total_op_hours - v_maintenance_hours, 0);

  select
    count(b.id),
    count(b.id) filter (where b.payment_source = 'cash' or b.payment_method = 'cash'),
    count(b.id) filter (where lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'),
    coalesce(sum(case when b.total_price > 0 then b.total_price else b.deposit_paid end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(greatest(0, extract(epoch from (b.end_time - b.start_time)) / 3600.0)), 0)
  into
    v_total_bookings,
    v_cash_bookings,
    v_online_bookings,
    v_total_revenue,
    v_cash_revenue,
    v_online_revenue,
    v_booked_hours
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('confirmed', 'completed', 'upcoming')
    and b.booking_type <> 'maintenance';

  select
    coalesce(sum(
      case
        when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash' then
          case when (b.payment_status = 'paid' or b.is_paid = true)
               then b.total_price
               else greatest(b.deposit_paid, 0) end
        else 0
      end
    ), 0),
    coalesce(sum(
      case
        when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
         and (b.payment_status = 'paid' or b.is_paid = true)
        then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
                  then b.deposit_paid else b.total_price end
        else 0
      end
    ), 0)
  into
    v_cash_collected,
    v_online_collected
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status <> 'cancelled'
    and b.booking_type <> 'maintenance';

  select coalesce(sum(
    case
      when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash' then
        case
          when (b.payment_status = 'paid' or b.is_paid = true) then 0
          else greatest(b.total_price - greatest(coalesce(b.deposit_paid, 0), 0), 0)
        end
      when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
           and (b.payment_status = 'paid' or b.is_paid = true)
           and b.total_price > greatest(coalesce(b.deposit_paid, 0), 0) then
        greatest(b.total_price - greatest(coalesce(b.deposit_paid, 0), 0), 0)
      else 0
    end
  ), 0)
  into v_cash_uncollected
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status <> 'cancelled';

  select coalesce(sum(
    case
      when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
       and not (b.payment_status = 'paid' or b.is_paid = true)
      then case
        when coalesce(b.needs_deposit, false) and coalesce(b.deposit_amount, 0) > 0
          then greatest(
            coalesce(b.deposit_amount, 0) - greatest(coalesce(b.deposit_paid, 0), 0),
            0
          )
        else greatest(
          coalesce(b.total_price, 0) - greatest(coalesce(b.deposit_paid, 0), 0),
          0
        )
      end
      else 0
    end
  ), 0)
  into v_online_pending
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('pending', 'confirmed', 'upcoming')
    and b.booking_type <> 'maintenance';

  -- Paid online money is collected, but remains unavailable for withdrawal
  -- until the booking reaches the terminal financial lifecycle state.
  select coalesce(sum(
    case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
         then b.deposit_paid else b.total_price end
  ), 0)
    into v_online_unavailable
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
    and (b.payment_status = 'paid' or b.is_paid = true)
    and b.status not in ('cancelled', 'completed', 'no_show');

  select
    coalesce(sum(
      case
        when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
          then case when (b.payment_status = 'paid' or b.is_paid = true)
                    then b.total_price else greatest(b.deposit_paid, 0) end
        else case when (b.payment_status = 'paid' or b.is_paid = true)
                  then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
                            then b.deposit_paid else b.total_price end
                  else 0 end
      end
    ), 0),
    coalesce(sum(
      case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
        then case when (b.payment_status = 'paid' or b.is_paid = true)
                  then b.total_price else greatest(b.deposit_paid, 0) end
        else 0 end
    ), 0),
    coalesce(sum(
      case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
        and (b.payment_status = 'paid' or b.is_paid = true)
        then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
                  then b.deposit_paid else b.total_price end
        else 0 end
    ), 0)
  into v_realized_revenue, v_realized_cash, v_realized_online
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('completed', 'no_show')
    and b.booking_type <> 'maintenance';

  select
    coalesce(sum(case when b.total_price > 0 then b.total_price else b.deposit_paid end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0)
  into v_upcoming_value, v_upcoming_cash, v_upcoming_online
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('confirmed', 'upcoming')
    and b.end_time > now();

  select json_build_object(
    'meta', json_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date,
      'period_days', v_period_days
    ),
    'revenue', json_build_object(
      'total', round(v_total_revenue, 2),
      'cash', round(v_cash_revenue, 2),
      'online', round(v_online_revenue, 2),
      'cash_percentage', case when v_total_revenue > 0
        then round((v_cash_revenue / v_total_revenue) * 100, 1) else 0 end,
      'online_percentage', case when v_total_revenue > 0
        then round((v_online_revenue / v_total_revenue) * 100, 1) else 0 end,
      'realized_revenue', round(v_realized_revenue, 2),
      'realized_cash', round(v_realized_cash, 2),
      'realized_online', round(v_realized_online, 2),
      'cash_collected', round(v_cash_collected, 2),
      'cash_uncollected', round(v_cash_uncollected, 2),
      'online_collected', round(v_online_collected, 2),
      'online_pending', round(v_online_pending, 2),
      'online_unavailable', round(v_online_unavailable, 2),
      'upcoming_confirmed_value', round(v_upcoming_value, 2),
      'upcoming_cash_value', round(v_upcoming_cash, 2),
      'upcoming_online_value', round(v_upcoming_online, 2),
      'unrealized', case when v_avg_hourly_rate > 0
        then round(greatest(v_total_op_hours - v_booked_hours, 0) * v_avg_hourly_rate, 2)
        else 0 end
    ),
    'bookings', json_build_object(
      'total_count', v_total_bookings,
      'cash_count', v_cash_bookings,
      'online_count', v_online_bookings,
      'average_price', case when v_total_bookings > 0
        then round(v_total_revenue / v_total_bookings, 2) else 0 end
    ),
    'capacity', json_build_object(
      'total_operating_hours', round(v_total_op_hours, 1),
      'booked_hours', round(v_booked_hours, 1),
      'unbooked_hours', round(greatest(v_total_op_hours - v_booked_hours, 0), 1),
      'occupancy_rate', case when v_total_op_hours > 0
        then round((v_booked_hours / v_total_op_hours) * 100, 1) else 0 end
    )
  ) into v_result;

  return v_result;
end;
$function$
;

-- Function: get_owner_financial_summary
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller_role text;
  v_stadium_count int:=0;
  v_total_bookings int:=0;
  v_realized_online_rev numeric:=0;
  v_upcoming_online_rev numeric:=0;
  v_online_collected_rev numeric:=0;
  v_total_platform_fees numeric:=0;
  v_online_count int:=0;
  v_cash_revenue numeric:=0;
  v_cash_collected numeric:=0;
  v_cash_outstanding numeric:=0;
  v_cash_bookings int:=0;
  v_total_withdrawn numeric:=0;
  v_pending_payouts numeric:=0;
  v_available_balance numeric:=0;
  v_cash_debt numeric:=0;
  v_debt_limit numeric:=0;
  v_debt_blocked boolean:=false;
  v_now timestamptz:=now();
begin
  if auth.uid() is null and current_user not in ('postgres','service_role') then
    return jsonb_build_object('success',false,'error','Authentication required');
  end if;
  if auth.uid() is not null and auth.uid()<>p_owner_id and current_user not in ('postgres','service_role') then
    select role into v_caller_role from public.users where id=auth.uid();
    if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
      return jsonb_build_object('success',false,'error','Unauthorized access to financial records');
    end if;
  end if;

  select count(*)::int into v_stadium_count from public.stadiums
  where owner_id=p_owner_id and coalesce(is_deleted_by_owner,false)=false;

  select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0),
         coalesce(sum(coalesce(b.platform_fee,0)),0),
         count(*)::int
  into v_realized_online_rev, v_total_platform_fees, v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status='paid' or b.is_paid=true)
    and b.status in ('completed','no_show')
    and b.booking_type <> 'maintenance';

  select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0)
    into v_online_collected_rev
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status='paid' or b.is_paid=true)
    and b.status<>'cancelled'
    and b.booking_type <> 'maintenance';

  select count(*)::int
    into v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and b.status<>'cancelled'
    and b.booking_type <> 'maintenance';

  select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0)
  into v_upcoming_online_rev
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status='paid' or b.is_paid=true)
    and b.status in ('confirmed','upcoming')
    and b.booking_type <> 'maintenance'
    and b.end_time>v_now;

  select coalesce(sum(
           case when (b.payment_status='paid' or b.is_paid=true)
                then greatest(coalesce(b.total_price,0),0)
                else greatest(coalesce(b.deposit_paid,0),0)
           end
         ),0),
         coalesce(sum(
           case when (b.total_price>0) then b.total_price else b.deposit_paid end
         ),0),
         count(*)::int
  into v_cash_collected,v_cash_revenue,v_cash_bookings
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))='cash'
    and b.status<>'cancelled';

  select coalesce(sum(
      case when not (b.payment_status='paid' or b.is_paid=true)
           then greatest(coalesce(b.total_price,0)-greatest(coalesce(b.deposit_paid,0),0),0)
           else 0 end
    ),0)
  into v_cash_outstanding
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))='cash'
    and b.status<>'cancelled';

  select count(*)::int into v_total_bookings
  from public.bookings
  where owner_id=p_owner_id
    and status<>'cancelled'
    and booking_type <> 'maintenance';

  select coalesce(sum(amount),0) into v_total_withdrawn from public.payout_settlements where owner_id=p_owner_id and status='completed';
  select coalesce(sum(amount),0) into v_pending_payouts from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');

  v_available_balance:=greatest(0,v_realized_online_rev-v_total_withdrawn-v_pending_payouts);

  select coalesce(accumulated_cash_debt,0),coalesce(debt_limit,0),coalesce(is_debt_blocked,false)
  into v_cash_debt,v_debt_limit,v_debt_blocked from public.users where id=p_owner_id;

  return jsonb_build_object(
    'success',true,'owner_id',p_owner_id,'stadium_count',v_stadium_count,
    'total_bookings_count',v_total_bookings,
    'realized_online_revenue',round(v_realized_online_rev,2),
    'upcoming_online_revenue',round(v_upcoming_online_rev,2),
    'online_collected_revenue',round(v_online_collected_rev,2),
    'net_online_earnings',round(v_realized_online_rev,2),
    'owner_online_earnings',round(v_realized_online_rev,2),
    'total_platform_fees',round(v_total_platform_fees,2),
    'total_withdrawn',round(v_total_withdrawn,2),
    'pending_payouts',round(v_pending_payouts,2),
    'available_balance',round(v_available_balance,2),
    'cash_revenue',round(v_cash_revenue,2),'cash_collected',round(v_cash_collected,2),
    'cash_outstanding',round(v_cash_outstanding,2),'cash_bookings_count',v_cash_bookings,
    'online_bookings_count',v_online_count,'accumulated_cash_debt',round(v_cash_debt,2),
    'debt_limit',round(v_debt_limit,2),'is_debt_blocked',v_debt_blocked
  );
end;
$function$
;

-- Function: get_owner_revenue
CREATE OR REPLACE FUNCTION public.get_owner_revenue(p_owner_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT COALESCE(SUM(total_price), 0)
  FROM bookings
  WHERE owner_id = p_owner_id
    AND payment_status = 'paid';
$function$
;

-- Function: get_owner_subscription_checkout_status
CREATE OR REPLACE FUNCTION public.get_owner_subscription_checkout_status(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(
    (
      select jsonb_build_object(
        'success',true,
        'status',o.status,
        'plan_code',o.plan_code,
        'billing_period',o.billing_period,
        'amount',o.amount,
        'base_amount',o.amount,
        'vsp_fee_amount',o.vsp_fee_amount,
        'paymob_fee_amount',o.paymob_fee_amount,
        'gross_amount',coalesce(o.gross_amount,o.amount),
        'paid_at',o.paid_at,
        'payment_source',o.payment_source
      )
      from public.owner_subscription_orders o
      where o.id=p_order_id
    ),
    jsonb_build_object('success',false,'error','ORDER_NOT_FOUND')
  );
$function$
;

-- Function: get_owner_trial_state
CREATE OR REPLACE FUNCTION public.get_owner_trial_state()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner public.users%ROWTYPE;
  v_ledger public.owner_trial_ledger%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_owner FROM public.users WHERE id=v_uid;
  IF NOT FOUND OR v_owner.role <> 'owner' THEN
    RAISE EXCEPTION 'OWNER_ONLY' USING ERRCODE='42501';
  END IF;

  IF v_owner.subscription_plan='free_trial'
     AND v_owner.trial_ends_at IS NOT NULL
     AND v_owner.trial_ends_at > now() THEN
    RETURN jsonb_build_object(
      'success',true,'state','active','trial_ends_at',v_owner.trial_ends_at
    );
  END IF;

  SELECT * INTO v_ledger
  FROM public.owner_trial_ledger
  WHERE lower(trim(email))=lower(trim(v_owner.email))
     OR (phone IS NOT NULL AND v_owner.phone IS NOT NULL AND phone=v_owner.phone)
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success',true,'state','used','trial_ends_at',v_ledger.original_trial_ends_at
    );
  END IF;

  RETURN jsonb_build_object('success',true,'state','available');
END;
$function$
;

-- Function: get_platform_business_rules
CREATE OR REPLACE FUNCTION public.get_platform_business_rules()
 RETURNS platform_business_rules
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select * from public.platform_business_rules where id=1;
$function$
;

-- Function: get_player_match_details
CREATE OR REPLACE FUNCTION public.get_player_match_details(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings%rowtype;
  v_stadium public.stadiums%rowtype;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  select * into v_booking from public.bookings where id=p_booking_id limit 1;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;

  if v_booking.booking_type='open_join' and coalesce(v_booking.is_private,false)=false then
    if v_booking.status in ('cancelled','expired') then raise exception 'PUBLIC_MATCH_NOT_AVAILABLE'; end if;
    return jsonb_build_object(
      'id',v_booking.id,'stadium_id',v_booking.stadium_id,'start_time',v_booking.start_time,'end_time',v_booking.end_time,
      'operational_date',v_booking.operational_date,'booking_type',v_booking.booking_type,
      'player_team_id',v_booking.player_team_id,'player_team_name',v_booking.player_team_name,'player_team_logo_url',v_booking.player_team_logo_url,
      'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,'is_private',false,'rent_ball',v_booking.rent_ball,
      'total_price',v_booking.total_price,'currency',v_booking.currency,'status',v_booking.status,
      'match_result_status',v_booking.match_result_status,'home_score',v_booking.home_score,'away_score',v_booking.away_score,
      'final_outcome',v_booking.final_outcome,'current_players',coalesce(v_booking.current_players,0),'players_per_team',5,
      'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
      'created_by_user_id',v_booking.created_by_user_id,'owner_id',v_booking.owner_id,'created_at',v_booking.created_at,
      'updated_at',v_booking.updated_at,'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[])
    );
  end if;

  if v_booking.booking_type='open_join' and coalesce(v_booking.is_private,false)=true then
    if v_uid<>v_booking.created_by_user_id
       and v_uid<>v_booking.owner_id
       and not (v_uid=any(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) then
      raise exception 'COLLECTIVE_MATCH_ACCESS_DENIED';
    end if;
    select * into v_stadium from public.stadiums where id=v_booking.stadium_id;
    return jsonb_build_object(
      'id',v_booking.id,'stadium_id',v_booking.stadium_id,'stadium_name',v_booking.stadium_name,'stadium_image_url',v_booking.stadium_image_url,
      'stadium_location',v_stadium.location,'stadium_city',v_stadium.city,'stadium_governorate',v_stadium.governorate,
      'start_time',v_booking.start_time,'end_time',v_booking.end_time,'operational_date',v_booking.operational_date,
      'booking_type',v_booking.booking_type,'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,'is_private',true,
      'rent_ball',v_booking.rent_ball,'total_price',v_booking.total_price,'currency',v_booking.currency,'payment_method',v_booking.payment_method,
      'payment_status',v_booking.payment_status,'status',v_booking.status,'current_players',coalesce(v_booking.current_players,0),
      'manual_player_count',coalesce(v_booking.manual_player_count,0),'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
      'created_by_user_id',v_booking.created_by_user_id,'owner_id',v_booking.owner_id,'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
      'collective_invite_active',coalesce(v_booking.collective_invite_active,false)
    );
  end if;

  -- Non-open-join booking details are private to actual booking participants.
  if not public.vsp_user_is_booking_participant(p_booking_id,v_uid) then
    raise exception 'BOOKING_ACCESS_DENIED';
  end if;

  select * into v_stadium from public.stadiums where id=v_booking.stadium_id;
  return jsonb_build_object(
    'id',v_booking.id,'stadium_id',v_booking.stadium_id,'stadium_name',v_booking.stadium_name,'stadium_image_url',v_booking.stadium_image_url,
    'stadium_location',v_stadium.location,'stadium_city',v_stadium.city,'stadium_governorate',v_stadium.governorate,
    'start_time',v_booking.start_time,'end_time',v_booking.end_time,'operational_date',v_booking.operational_date,
    'booking_type',v_booking.booking_type,'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,'is_private',coalesce(v_booking.is_private,false),
    'rent_ball',v_booking.rent_ball,'total_price',v_booking.total_price,'currency',v_booking.currency,'payment_method',v_booking.payment_method,
    'payment_status',v_booking.payment_status,'status',v_booking.status,'current_players',coalesce(v_booking.current_players,0),
    'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
    'created_by_user_id',v_booking.created_by_user_id,'owner_id',v_booking.owner_id,'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
    'player_team_id',v_booking.player_team_id,'player_team_name',v_booking.player_team_name,'player_team_logo_url',v_booking.player_team_logo_url,
    'match_result_status',v_booking.match_result_status,'home_score',v_booking.home_score,'away_score',v_booking.away_score,'final_outcome',v_booking.final_outcome,
    'created_at',v_booking.created_at,'updated_at',v_booking.updated_at
  );
end;
$function$
;

-- Function: get_player_my_bookings_atomic
CREATE OR REPLACE FUNCTION public.get_player_my_bookings_atomic(p_user_id uuid)
 RETURNS SETOF bookings
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id AND current_user NOT IN ('postgres', 'service_role') THEN
    IF NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.bookings
  WHERE (
    created_by_user_id = p_user_id
    OR user_id = p_user_id
    OR p_user_id = ANY(COALESCE(joined_user_ids, ARRAY[]::uuid[]))
  )
  ORDER BY start_time DESC
  LIMIT 100;
END;
$function$
;

-- Function: get_private_collective_invite_by_code
CREATE OR REPLACE FUNCTION public.get_private_collective_invite_by_code(p_invite_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_stadium public.stadiums%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE collective_invite_code=upper(trim(coalesce(p_invite_code,'')))
    AND booking_type='open_join'
    AND is_private=true
    AND coalesce(collective_invite_active,true)=true
    AND status='confirmed';

  IF NOT FOUND THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_FOUND'; END IF;
  IF v_booking.end_time<=timezone('utc',now()) THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_AVAILABLE'; END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id=v_booking.stadium_id;

  RETURN jsonb_build_object(
    'id',v_booking.id,'invite_token',v_booking.collective_invite_token,
    'stadium_id',v_booking.stadium_id,'stadium_name',v_booking.stadium_name,
    'stadium_image_url',v_booking.stadium_image_url,
    'stadium_location',v_stadium.location,'stadium_city',v_stadium.city,'stadium_governorate',v_stadium.governorate,
    'start_time',v_booking.start_time,'end_time',v_booking.end_time,
    'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,
    'total_price',v_booking.total_price,'currency',v_booking.currency,
    'payment_method',v_booking.payment_method,'payment_status',v_booking.payment_status,
    'status',v_booking.status,'current_players',coalesce(v_booking.current_players,0),
    'manual_player_count',coalesce(v_booking.manual_player_count,0),
    'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
    'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
    'collective_invite_code',v_booking.collective_invite_code
  );
END;
$function$
;

-- Function: get_private_collective_invite_details
CREATE OR REPLACE FUNCTION public.get_private_collective_invite_details(p_invite_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_stadium public.stadiums%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE collective_invite_token=lower(trim(coalesce(p_invite_token,'')))
    AND booking_type='open_join'
    AND is_private=true
    AND coalesce(collective_invite_active,true)=true
    AND status='confirmed';

  IF NOT FOUND THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_FOUND'; END IF;
  IF v_booking.end_time<=timezone('utc',now()) THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_AVAILABLE'; END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id=v_booking.stadium_id;

  RETURN jsonb_build_object(
    'id',v_booking.id,'invite_token',v_booking.collective_invite_token,
    'stadium_id',v_booking.stadium_id,'stadium_name',v_booking.stadium_name,
    'stadium_image_url',v_booking.stadium_image_url,
    'stadium_location',v_stadium.location,'stadium_city',v_stadium.city,'stadium_governorate',v_stadium.governorate,
    'start_time',v_booking.start_time,'end_time',v_booking.end_time,
    'operational_date',v_booking.operational_date,'booking_type',v_booking.booking_type,
    'host_name',v_booking.host_name,'host_avatar_url',v_booking.host_avatar_url,
    'is_private',true,'rent_ball',v_booking.rent_ball,
    'total_price',v_booking.total_price,'currency',v_booking.currency,
    'payment_method',v_booking.payment_method,'payment_status',v_booking.payment_status,
    'status',v_booking.status,'current_players',coalesce(v_booking.current_players,0),
    'manual_player_count',coalesce(v_booking.manual_player_count,0),
    'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
    'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
    'collective_invite_code',v_booking.collective_invite_code
  );
END;
$function$
;

-- Function: get_private_collective_match_details
CREATE OR REPLACE FUNCTION public.get_private_collective_match_details(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid:=auth.uid();
  v_stadium public.stadiums%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true;

  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;

  IF v_uid<>v_booking.created_by_user_id
     AND v_uid<>v_booking.owner_id
     AND NOT (v_uid=ANY(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) THEN
    RAISE EXCEPTION 'COLLECTIVE_MATCH_ACCESS_DENIED';
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id=v_booking.stadium_id;

  RETURN jsonb_build_object(
    'id',v_booking.id,
    'stadium_id',v_booking.stadium_id,
    'stadium_name',v_booking.stadium_name,
    'stadium_image_url',v_booking.stadium_image_url,
    'stadium_location',v_stadium.location,
    'stadium_city',v_stadium.city,
    'stadium_governorate',v_stadium.governorate,
    'start_time',v_booking.start_time,
    'end_time',v_booking.end_time,
    'operational_date',v_booking.operational_date,
    'booking_type',v_booking.booking_type,
    'host_name',v_booking.host_name,
    'host_avatar_url',v_booking.host_avatar_url,
    'is_private',true,
    'rent_ball',v_booking.rent_ball,
    'total_price',v_booking.total_price,
    'currency',v_booking.currency,
    'payment_method',v_booking.payment_method,
    'payment_status',v_booking.payment_status,
    'status',v_booking.status,
    'current_players',coalesce(v_booking.current_players,0),
    'manual_player_count',coalesce(v_booking.manual_player_count,0),
    'total_field_capacity',coalesce(v_booking.total_field_capacity,v_booking.max_players,10),
    'created_by_user_id',v_booking.created_by_user_id,
    'owner_id',v_booking.owner_id,
    'joined_user_ids',coalesce(v_booking.joined_user_ids,array[]::uuid[]),
    'collective_invite_active',coalesce(v_booking.collective_invite_active,false)
  );
END;
$function$
;

-- Function: get_private_match_invite_details
CREATE OR REPLACE FUNCTION public.get_private_match_invite_details(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_booking public.bookings%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  select *
    into v_booking
  from public.bookings
  where id = p_booking_id
    and booking_type = 'open_join'
    and is_private is true
  limit 1;

  if not found then
    raise exception 'PRIVATE_MATCH_INVITE_NOT_FOUND';
  end if;

  if v_booking.status in ('cancelled', 'expired') then
    raise exception 'PRIVATE_MATCH_INVITE_NOT_AVAILABLE';
  end if;

  return jsonb_build_object(
    'id', v_booking.id,
    'stadium_id', v_booking.stadium_id,
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'operational_date', v_booking.operational_date,
    'booking_type', v_booking.booking_type,
    'player_team_id', v_booking.player_team_id,
    'player_team_name', v_booking.player_team_name,
    'player_team_logo_url', v_booking.player_team_logo_url,
    'host_name', v_booking.host_name,
    'host_avatar_url', v_booking.host_avatar_url,
    'is_private', v_booking.is_private,
    'rent_ball', v_booking.rent_ball,
    'total_price', v_booking.total_price,
    'currency', v_booking.currency,
    'payment_method', v_booking.payment_method,
    'status', v_booking.status,
    'match_result_status', v_booking.match_result_status,
    'home_score', v_booking.home_score,
    'away_score', v_booking.away_score,
    'final_outcome', v_booking.final_outcome,
    'current_players', coalesce(v_booking.current_players, 0),
    'players_per_team', 5,
    'total_field_capacity', coalesce(v_booking.total_field_capacity, v_booking.max_players, 10),
    'created_by_user_id', v_booking.created_by_user_id,
    'owner_id', v_booking.owner_id,
    'created_at', v_booking.created_at,
    'updated_at', v_booking.updated_at,
    'joined_user_ids', coalesce(v_booking.joined_user_ids, array[]::uuid[])
  );
end;
$function$
;

-- Function: get_public_match_details
CREATE OR REPLACE FUNCTION public.get_public_match_details(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_booking public.bookings%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  select *
    into v_booking
  from public.bookings
  where id = p_booking_id
    and booking_type = 'open_join'
    and is_private is false
  limit 1;

  if not found then
    raise exception 'PUBLIC_MATCH_NOT_FOUND';
  end if;

  if v_booking.status in ('cancelled', 'expired') then
    raise exception 'PUBLIC_MATCH_NOT_AVAILABLE';
  end if;

  return jsonb_build_object(
    'id', v_booking.id,
    'stadium_id', v_booking.stadium_id,
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'operational_date', v_booking.operational_date,
    'booking_type', v_booking.booking_type,
    'player_team_id', v_booking.player_team_id,
    'player_team_name', v_booking.player_team_name,
    'player_team_logo_url', v_booking.player_team_logo_url,
    'host_name', v_booking.host_name,
    'host_avatar_url', v_booking.host_avatar_url,
    'is_private', v_booking.is_private,
    'rent_ball', v_booking.rent_ball,
    'total_price', v_booking.total_price,
    'currency', v_booking.currency,
    'status', v_booking.status,
    'match_result_status', v_booking.match_result_status,
    'home_score', v_booking.home_score,
    'away_score', v_booking.away_score,
    'final_outcome', v_booking.final_outcome,
    'current_players', coalesce(v_booking.current_players, 0),
    'players_per_team', 5,
    'total_field_capacity', coalesce(v_booking.total_field_capacity, v_booking.max_players, 10),
    'created_by_user_id', v_booking.created_by_user_id,
    'owner_id', v_booking.owner_id,
    'created_at', v_booking.created_at,
    'updated_at', v_booking.updated_at,
    'joined_user_ids', coalesce(v_booking.joined_user_ids, array[]::uuid[])
  );
end;
$function$
;

-- Function: get_server_timestamp
CREATE OR REPLACE FUNCTION public.get_server_timestamp()
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    SELECT timezone('utc'::text, now());
$function$
;

-- Function: get_stadium_booking_slots
CREATE OR REPLACE FUNCTION public.get_stadium_booking_slots(p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone)
 RETURNS TABLE(id uuid, stadium_id uuid, stadium_name text, stadium_image_url text, start_time timestamp with time zone, end_time timestamp with time zone, status text, booking_type text, is_private boolean, current_players integer, total_field_capacity integer, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select b.id,b.stadium_id,b.stadium_name,b.stadium_image_url,b.start_time,b.end_time,b.status,b.booking_type,
         b.is_private,b.current_players,b.total_field_capacity,b.created_at,b.updated_at
  from public.bookings b
  where b.stadium_id=p_stadium_id
    and b.start_time >= p_start_time
    and b.start_time < p_end_time
    and b.status <> 'cancelled'
    and (
      b.status <> 'pending'
      or b.created_at >= now() - interval '8 minutes'
    )
  order by b.start_time;
$function$
;

-- Function: get_team_active_league
CREATE OR REPLACE FUNCTION public.get_team_active_league(p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_matches JSONB;
  v_standings JSONB;
  v_teams JSONB;
  v_user_id UUID := auth.uid();
  v_is_creator BOOLEAN := false;
BEGIN
  SELECT c.*
    INTO v_champ
  FROM public.championships c
  WHERE c.template_type = 'team_league'
    AND p_team_id::text = ANY(COALESCE(c.joined_teams, '{}'::text[]))
    AND c.status IN ('open', 'ongoing', 'completed')
  ORDER BY c.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_is_creator := (v_champ.owner_id = v_user_id);

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'name', t.name,
      'logo_url', t.logo_url,
      'captain_id', t.captain_id,
      'captain_phone', u.phone,
      'joined_at', v_champ.created_at,
      'prepaid_by_creator',
        (t.id::text = ANY(COALESCE(v_champ.paid_teams, '{}'::text[])))
    )
    ORDER BY jt.ordinality ASC
  )
  INTO v_teams
  FROM unnest(COALESCE(v_champ.joined_teams, '{}'::text[])) WITH ORDINALITY AS jt(team_id_text, ordinality)
  JOIN public.teams t ON t.id = jt.team_id_text::uuid
  LEFT JOIN public.users u ON u.id = t.captain_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'championship_id', m.championship_id,
      'week_number', COALESCE(m.week_number, m.round_index + 1),
      'match_index', m.match_index,
      'stage', m.stage,
      'home_team_id', m.home_team_id,
      'home_team_name', ht.name,
      'away_team_id', m.away_team_id,
      'away_team_name', at.name,
      'home_score', m.home_score,
      'away_score', m.away_score,
      'winner_id', m.winner_id,
      'winner_name', m.winner_name,
      'confirmed_outcome', m.confirmed_outcome,
      'result_status',
        CASE
          WHEN m.result_status = 'confirmed'
           AND m.result_confirmed_at IS NOT NULL
           AND m.result_confirmed_at + interval '15 minutes' < clock_timestamp()
            THEN 'locked'
          ELSE COALESCE(m.result_status, 'scheduled')
        END,
      'status', m.status,
      'is_completed',
        (m.result_status IN ('confirmed', 'locked')
         OR (m.result_confirmed_at IS NOT NULL)),
      'scheduled_time', m.scheduled_time,
      'result_confirmed_at', m.result_confirmed_at,
      'result_locked_at', m.result_locked_at,
      'dispute_created_at', m.dispute_created_at,
      'match_day', m.match_day,
      'booking_id', m.booking_id,
      'stadium_name', m.stadium_name,
      'my_team_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id = p_team_id
      ),
      'opponent_team_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id <> p_team_id
        LIMIT 1
      ),
      'home_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id = m.home_team_id
      ),
      'away_submission', (
        SELECT sub.result
        FROM public.team_league_match_submissions sub
        WHERE sub.match_id = m.id
          AND sub.team_id = m.away_team_id
      )
    )
    ORDER BY COALESCE(m.week_number, m.round_index + 1) ASC, m.match_index ASC
  )
  INTO v_matches
  FROM public.tournament_matches m
  JOIN public.teams ht ON ht.id = m.home_team_id
  JOIN public.teams at ON at.id = m.away_team_id
  WHERE m.championship_id = v_champ.id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'rank', s.rank,
      'team_id', s.team_id,
      'team_name', s.team_name,
      'team_logo_url', s.team_logo_url,
      'played', s.played,
      'won', s.won,
      'drawn', s.drawn,
      'lost', s.lost,
      'points', s.points
    ) ORDER BY s.rank ASC
  )
  INTO v_standings
  FROM public.get_team_league_standings(v_champ.id) s;

  RETURN jsonb_build_object(
    'id', v_champ.id,
    'name', v_champ.name,
    'type', v_champ.type,
    'status', v_champ.status,
    'max_teams', v_champ.max_teams,
    'current_teams_count', COALESCE(jsonb_array_length(v_teams), 0),
    'match_interval_days', COALESCE(v_champ.match_interval_days, 7),
    'paid_by_creator_count', COALESCE(v_champ.paid_by_creator_count, 1),
    'is_creator', v_is_creator,
    'champion_team_id', v_champ.champion_team_id,
    'champion_team_name', v_champ.champion_team_name,
    'governorate', v_champ.governorate,
    'teams', COALESCE(v_teams, '[]'::jsonb),
    'matches', COALESCE(v_matches, '[]'::jsonb),
    'standings', COALESCE(v_standings, '[]'::jsonb)
  );
END;
$function$
;

-- Function: get_team_invite_code
CREATE OR REPLACE FUNCTION public.get_team_invite_code(p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_team record;
  v_is_admin boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT id, captain_id, active_invite_code, invite_code_expires_at
  INTO v_team
  FROM public.teams
  WHERE id = p_team_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود');
  END IF;

  v_is_admin := false;
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = v_caller_id
      AND role IN ('admin', 'super_admin', 'co_founder', 'cofounder')
  ) THEN
    v_is_admin := true;
  END IF;

  IF (v_team.captain_id IS DISTINCT FROM v_caller_id) AND (NOT v_is_admin) THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بالاطلاع على كود الدعوة');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'team_id', v_team.id,
    'invite_code', v_team.active_invite_code,
    'expires_at', v_team.invite_code_expires_at
  );
END;
$function$
;

-- Function: get_team_league_payment_status
CREATE OR REPLACE FUNCTION public.get_team_league_payment_status(p_championship_id uuid, p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_captain uuid;
  v_status text;
  v_payment record;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  select captain_id into v_captain from public.teams where id=p_team_id;
  if v_captain is null or v_captain <> v_uid then raise exception 'غير مصرح'; end if;

  select payment_status, order_reference, amount, paymob_transaction_id
    into v_payment
  from public.team_league_payments
  where championship_id=p_championship_id and team_id=p_team_id
  order by created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('status','not_created');
  end if;

  return jsonb_build_object(
    'status',v_payment.payment_status,
    'payment_reference',v_payment.order_reference,
    'amount',v_payment.amount,
    'paymob_transaction_id',v_payment.paymob_transaction_id
  );
end;
$function$
;

-- Function: get_team_league_standings
CREATE OR REPLACE FUNCTION public.get_team_league_standings(p_championship_id uuid)
 RETURNS TABLE(rank bigint, team_id uuid, team_name text, team_logo_url text, played integer, won integer, drawn integer, lost integer, points integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH enrolled_teams AS (
    SELECT DISTINCT t.id AS e_team_id, t.name AS e_team_name, t.logo_url AS e_team_logo_url
    FROM public.championships ch
    CROSS JOIN LATERAL unnest(ch.joined_teams) AS jt(team_id_text)
    JOIN public.teams t ON t.id = jt.team_id_text::uuid
    WHERE ch.id = p_championship_id
  ),
  base_stats AS (
    SELECT
      et.e_team_id       AS b_team_id,
      et.e_team_name     AS b_team_name,
      et.e_team_logo_url AS b_team_logo_url,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
      ), 0)::INTEGER AS b_played,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked') AND (
          (m.home_team_id = et.e_team_id AND m.confirmed_outcome = 'home_win') OR
          (m.away_team_id = et.e_team_id AND m.confirmed_outcome = 'away_win')
        )
      ), 0)::INTEGER AS b_won,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked')
          AND m.confirmed_outcome = 'draw'
          AND (m.home_team_id = et.e_team_id OR m.away_team_id = et.e_team_id)
      ), 0)::INTEGER AS b_drawn,
      COALESCE(COUNT(m.id) FILTER (
        WHERE m.result_status IN ('confirmed', 'locked') AND (
          (m.home_team_id = et.e_team_id AND m.confirmed_outcome = 'away_win') OR
          (m.away_team_id = et.e_team_id AND m.confirmed_outcome = 'home_win')
        )
      ), 0)::INTEGER AS b_lost
    FROM enrolled_teams et
    LEFT JOIN public.tournament_matches m
      ON m.championship_id = p_championship_id
      AND (m.home_team_id = et.e_team_id OR m.away_team_id = et.e_team_id)
    GROUP BY et.e_team_id, et.e_team_name, et.e_team_logo_url
  ),
  with_points AS (
    SELECT s.*, ((s.b_won * 3) + (s.b_drawn * 1))::INTEGER AS b_points
    FROM base_stats s
  ),
  with_h2h AS (
    SELECT
      p.b_team_id, p.b_team_name, p.b_team_logo_url,
      p.b_played, p.b_won, p.b_drawn, p.b_lost, p.b_points,
      COALESCE(SUM(
        CASE
          WHEN (m.home_team_id = p.b_team_id AND m.confirmed_outcome = 'home_win') OR
               (m.away_team_id = p.b_team_id AND m.confirmed_outcome = 'away_win') THEN 3
          WHEN m.confirmed_outcome = 'draw'
           AND (m.home_team_id = p.b_team_id OR m.away_team_id = p.b_team_id)     THEN 1
          ELSE 0
        END
      ), 0)::INTEGER AS h2h_points
    FROM with_points p
    LEFT JOIN with_points rival
      ON rival.b_points = p.b_points AND rival.b_team_id != p.b_team_id
    LEFT JOIN public.tournament_matches m
      ON m.championship_id = p_championship_id
      AND m.result_status IN ('confirmed', 'locked')
      AND (
        (m.home_team_id = p.b_team_id AND m.away_team_id = rival.b_team_id) OR
        (m.away_team_id = p.b_team_id AND m.home_team_id = rival.b_team_id)
      )
    GROUP BY
      p.b_team_id, p.b_team_name, p.b_team_logo_url,
      p.b_played, p.b_won, p.b_drawn, p.b_lost, p.b_points
  )
  SELECT
    ROW_NUMBER() OVER (
      ORDER BY h.b_points DESC, h.h2h_points DESC, h.b_won DESC, h.b_team_name ASC, h.b_team_id ASC
    )           AS rank,
    h.b_team_id AS team_id,
    h.b_team_name AS team_name,
    h.b_team_logo_url AS team_logo_url,
    h.b_played  AS played,
    h.b_won     AS won,
    h.b_drawn   AS drawn,
    h.b_lost    AS lost,
    h.b_points  AS points
  FROM with_h2h h
  ORDER BY rank ASC;
END;
$function$
;

-- Function: get_team_member_profiles
CREATE OR REPLACE FUNCTION public.get_team_member_profiles(p_team_id uuid)
 RETURNS TABLE(uid uuid, name text, phone text, p_position text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller uuid := auth.uid();
  v_role text;
  v_allowed boolean := false;
begin
  if v_caller is null then return; end if;

  select role into v_role from public.users where id = v_caller;

  if v_role in ('admin','super_admin','cofounder','co_founder') then
    v_allowed := true;
  elsif exists (
    select 1 from public.team_members tm
    where tm.team_id = p_team_id and tm.user_id = v_caller
  ) or exists (
    select 1 from public.teams t
    where t.id = p_team_id and t.captain_id = v_caller
  ) then
    v_allowed := true;
  end if;

  if not v_allowed then return; end if;

  return query
  select u.id, u.name, u.phone, u.position
  from public.team_members tm
  join public.users u on u.id = tm.user_id
  where tm.team_id = p_team_id
  order by tm.id;
end;
$function$
;

-- Function: get_tournament_financial_summary
CREATE OR REPLACE FUNCTION public.get_tournament_financial_summary(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_champ record;
  v_caller uuid := auth.uid();
  v_role text;
  v_is_admin boolean := false;
  v_paid_teams_count int := 0;
  v_total_collected numeric := 0;
  v_net_profit numeric := 0;
begin
  if v_caller is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required');
  end if;

  select * into v_champ
  from public.championships
  where id = p_championship_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'البطولة غير موجودة');
  end if;

  select role into v_role
  from public.users
  where id = v_caller;

  v_is_admin := coalesce(v_role in ('admin','co_founder','cofounder','super_admin'), false);

  if not v_is_admin and v_champ.owner_id is distinct from v_caller then
    return jsonb_build_object('success', false, 'error', 'غير مصرح لك بعرض البيانات المالية لهذه البطولة');
  end if;

  if coalesce(v_champ.template_type, '') = 'team_league' then
    select count(distinct team_id)::int, coalesce(sum(amount),0)
    into v_paid_teams_count, v_total_collected
    from public.team_league_payments
    where championship_id = p_championship_id
      and payment_status = 'completed';
  else
    select count(distinct team_id)::int, coalesce(sum(amount),0)
    into v_paid_teams_count, v_total_collected
    from public.tournament_orders
    where championship_id = p_championship_id
      and payment_status = 'completed';
  end if;

  v_net_profit := v_total_collected - coalesce(v_champ.grand_prize, 0);

  return jsonb_build_object(
    'success', true,
    'paid_teams_count', v_paid_teams_count,
    'entry_fee', v_champ.entry_fee,
    'total_collected', round(v_total_collected, 2),
    'grand_prize', v_champ.grand_prize,
    'net_profit', round(v_net_profit, 2),
    'is_registration_locked', v_champ.registration_locked_at is not null
  );
end;
$function$
;

-- Function: get_tournament_payment_order_status
CREATE OR REPLACE FUNCTION public.get_tournament_payment_order_status(p_order_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record;
begin
  if auth.uid() is null then
    return jsonb_build_object('success',false,'error','Authentication required');
  end if;

  select order_reference,championship_id,team_id,captain_user_id,amount,payment_status,paymob_transaction_id
  into v_order
  from public.tournament_orders
  where order_reference=p_order_reference;

  if not found then
    return jsonb_build_object('success',false,'error','Payment order not found');
  end if;

  if v_order.captain_user_id is distinct from auth.uid()
     and not public.is_admin_or_cofounder(auth.uid()) then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;

  return jsonb_build_object(
    'success',true,'order_reference',v_order.order_reference,
    'championship_id',v_order.championship_id,'team_id',v_order.team_id,
    'amount',v_order.amount,'payment_status',v_order.payment_status,
    'paymob_transaction_id',v_order.paymob_transaction_id
  );
end;
$function$
;

-- Function: global_search
CREATE OR REPLACE FUNCTION public.global_search(search_term text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadiums jsonb;
  v_teams jsonb;
  v_championships jsonb;
  v_clean_query text := trim(search_term);
BEGIN
  IF v_clean_query = '' OR length(v_clean_query) < 2 THEN
    RETURN jsonb_build_object('stadiums', '[]'::jsonb, 'teams', '[]'::jsonb, 'championships', '[]'::jsonb);
  END IF;

  -- 1. الملاعب الموثقة فقط وغير المحظورة
  SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
  INTO v_stadiums
  FROM (
    SELECT id, name, location, governorate, price_per_hour, rating, image_url
    FROM public.stadiums
    WHERE (name ILIKE '%' || v_clean_query || '%' OR location ILIKE '%' || v_clean_query || '%' OR governorate ILIKE '%' || v_clean_query || '%')
      AND is_verified = true 
      AND COALESCE(is_blocked, false) = false
      AND COALESCE(is_deleted_by_owner, false) = false
    LIMIT 10
  ) s;

  -- 2. الفرق
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  INTO v_teams
  FROM (
    SELECT id, name, logo_url, points, governorate, sport_type
    FROM public.teams
    WHERE name ILIKE '%' || v_clean_query || '%'
    LIMIT 10
  ) t;

  -- 3. البطولات (المعتمدة فقط)
  SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
  INTO v_championships
  FROM (
    SELECT id, name, type, start_date, entry_fee, grand_prize, status, logo_url
    FROM public.championships
    WHERE name ILIKE '%' || v_clean_query || '%'
      AND status IN ('open', 'ongoing')
      AND is_approved = true
    LIMIT 10
  ) c;

  RETURN jsonb_build_object(
    'stadiums', v_stadiums,
    'teams', v_teams,
    'championships', v_championships
  );
END;
$function$
;

-- Function: handle_new_notification_fcm
CREATE OR REPLACE FUNCTION public.handle_new_notification_fcm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_url text := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/fcm_push';
  v_secret text;
BEGIN
  SELECT s.secret INTO v_secret
  FROM public.internal_function_secrets AS s
  WHERE s.name = 'fcm_push'
  LIMIT 1;

  IF v_secret IS NULL OR length(v_secret) < 32 THEN
    RAISE WARNING 'FCM push trigger skipped: internal secret is missing or too short';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('record', row_to_json(NEW))
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'FCM push trigger exception (safe-bypass): %', SQLERRM;
  RETURN NEW;
END;
$function$
;

-- Function: handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_role text;
  v_name text;
  v_avatar text;
  v_phone text;
  v_governorate text;
  v_dob timestamptz;
  v_position text;
  v_is_complete boolean;
begin
  v_role := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'player');
  if v_role not in ('player', 'owner') then
    v_role := 'player';
  end if;

  v_name := coalesce(
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'name', ''),
    split_part(new.email, '@', 1)
  );

  v_avatar := coalesce(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    null
  );

  v_phone := coalesce(
    nullif(new.raw_user_meta_data->>'phone', ''),
    nullif(new.phone, '')
  );

  v_governorate := coalesce(
    nullif(new.raw_user_meta_data->>'governorate', ''),
    'Cairo'
  );

  v_position := coalesce(
    nullif(new.raw_user_meta_data->>'position', ''),
    'GK'
  );

  begin
    v_dob := (new.raw_user_meta_data->>'date_of_birth')::timestamptz;
  exception when others then
    v_dob := null;
  end;

  v_is_complete := (
    v_phone is not null
    and length(regexp_replace(v_phone, '[^0-9]', '', 'g')) >= 9
    and v_dob is not null
    and public.vsp_is_adult_date_of_birth(v_dob::text)
  );

  insert into public.users (
    id, email, name, role, phone, governorate, position, date_of_birth,
    profile_image_url, is_email_verified, is_registration_complete, created_at, updated_at
  ) values (
    new.id,
    coalesce(new.email, ''),
    v_name,
    v_role,
    v_phone,
    v_governorate,
    v_position,
    v_dob,
    v_avatar,
    true,
    v_is_complete,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do update
  set email = excluded.email,
      name = coalesce(nullif(public.users.name, ''), excluded.name),
      role = coalesce(nullif(public.users.role, ''), excluded.role),
      phone = coalesce(nullif(public.users.phone, ''), excluded.phone),
      governorate = coalesce(nullif(public.users.governorate, ''), excluded.governorate),
      position = coalesce(nullif(public.users.position, ''), excluded.position),
      date_of_birth = coalesce(public.users.date_of_birth, excluded.date_of_birth),
      profile_image_url = coalesce(public.users.profile_image_url, excluded.profile_image_url),
      is_email_verified = true,
      is_registration_complete = case
        when public.users.is_registration_complete then true
        else excluded.is_registration_complete
      end,
      updated_at = timezone('utc', now());

  return new;
exception
  when others then
    if sqlstate = 'P0002' then
      raise;
    end if;
    raise warning 'handle_new_user error: %', sqlerrm;
    return new;
end;
$function$
;

-- Function: handle_stadium_breaks_collision
CREATE OR REPLACE FUNCTION public.handle_stadium_breaks_collision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_break_start timestamptz;
  v_break_end timestamptz;
  v_is_split_shift boolean;
  v_break_start_str text;
  v_break_end_str text;
  v_start_time time;
  v_end_time time;
  v_today_cairo date;
BEGIN
  v_is_split_shift := COALESCE((NEW.features->>'isSplitShift')::boolean, false);
  v_break_start_str := NEW.features->'breakTime'->>'start';
  v_break_end_str := NEW.features->'breakTime'->>'end';

  IF (v_is_split_shift = true AND v_break_start_str IS NOT NULL AND v_break_end_str IS NOT NULL) THEN
    
    BEGIN
      v_start_time := v_break_start_str::time;
      v_end_time := v_break_end_str::time;
    EXCEPTION WHEN OTHERS THEN
      BEGIN
        v_start_time := to_timestamp(v_break_start_str, 'HH12:MI AM')::time;
        v_end_time := to_timestamp(v_break_end_str, 'HH12:MI AM')::time;
      EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
      END;
    END;

    -- Compute break window using explicit Egyptian local calendar date and timezone
    v_today_cairo := (timezone('Africa/Cairo', now()))::date;
    v_break_start := (v_today_cairo + v_start_time) AT TIME ZONE 'Africa/Cairo';
    v_break_end := (v_today_cairo + v_end_time) AT TIME ZONE 'Africa/Cairo';

    IF (v_break_end <= v_break_start) THEN
      v_break_end := v_break_end + interval '1 day';
    END IF;

    FOR v_booking IN 
      SELECT id, created_by_user_id
      FROM public.bookings
      WHERE stadium_id = NEW.id
        AND status = 'confirmed'
        AND start_time < v_break_end 
        AND end_time > v_break_start
    LOOP
      UPDATE public.bookings
      SET 
        status = 'cancelled',
        payment_status = 'refund_pending',
        updated_at = now()
      WHERE id = v_booking.id;

      INSERT INTO public.notifications (user_id, title, body, type, booking_id, created_at)
      VALUES (
        v_booking.created_by_user_id,
        '⚠️ إلغاء حجز واسترداد المبلغ',
        'تم إغلاق الملعب لفترة صيانة/راحة، وجاري استرداد المبلغ إلى حسابك.',
        'booking_cancelled',
        v_booking.id,
        now()
      );
    END LOOP;

  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: handle_stadium_review_changes
CREATE OR REPLACE FUNCTION public.handle_stadium_review_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium_id uuid;
  v_avg_rating numeric;
  v_count integer;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    v_stadium_id := OLD.stadium_id;
  ELSE
    v_stadium_id := NEW.stadium_id;
  END IF;

  SELECT COALESCE(AVG(rating), 0.0), COUNT(*)
  INTO v_avg_rating, v_count
  FROM public.reviews
  WHERE stadium_id = v_stadium_id;

  UPDATE public.stadiums
  SET rating = ROUND(v_avg_rating, 1),
      reviews_count = v_count,
      updated_at = now()
  WHERE id = v_stadium_id;

  RETURN NULL;
END;
$function$
;

-- Function: increment_banner_clicks
CREATE OR REPLACE FUNCTION public.increment_banner_clicks(p_banner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- حظر الاستدعاءات الوهمية من غير المسجلين
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN;
    END IF;

    UPDATE public.banners
    SET clicks_count = COALESCE(clicks_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_banner_id;
END;
$function$
;

-- Function: increment_banner_views
CREATE OR REPLACE FUNCTION public.increment_banner_views(p_banner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- حظر هجمات البوتات والتكرار العشوائي
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN;
    END IF;

    UPDATE public.banners
    SET views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_banner_id;
END;
$function$
;

-- Function: increment_chat_unread_count
CREATE OR REPLACE FUNCTION public.increment_chat_unread_count(p_booking_id text, p_sender_id text, p_last_message text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_joined_ids JSONB;
  v_unread JSONB;
  v_uid TEXT;
  v_booking_owner UUID;
  v_booking_user UUID;
BEGIN
  -- 🔒 فحص تسجيل الدخول
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  -- 🔒 منع انتحال معرف المرسل
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.role(), '') != 'service_role' THEN
    IF auth.uid()::text != p_sender_id THEN
      RAISE EXCEPTION 'Permission denied: sender_id does not match authenticated user' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT joined_user_ids, COALESCE(unread_counts, '{}'::jsonb), owner_id, user_id
  INTO v_joined_ids, v_unread, v_booking_owner, v_booking_user
  FROM public.bookings
  WHERE id::text = p_booking_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 🔒 التحقق من أن المستخدم طرف فعلي في الحجز (مالك، لاعب حاجز، أو منضم)
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.role(), '') != 'service_role' THEN
    IF auth.uid() != v_booking_owner 
       AND auth.uid() != v_booking_user 
       AND (v_joined_ids IS NULL OR NOT (v_joined_ids ? auth.uid()::text)) THEN
      RAISE EXCEPTION 'Permission denied: Caller is not a participant in this booking' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF v_joined_ids IS NOT NULL THEN
    FOR v_uid IN SELECT jsonb_array_elements_text(v_joined_ids)
    LOOP
      IF v_uid != p_sender_id THEN
        v_unread := jsonb_set(
          v_unread,
          ARRAY[v_uid],
          to_jsonb(COALESCE((v_unread->>v_uid)::int, 0) + 1)
        );
      END IF;
    END LOOP;

    UPDATE public.bookings
    SET last_message = p_last_message,
        last_message_time = NOW(),
        unread_counts = v_unread
    WHERE id::text = p_booking_id;
  END IF;
END;
$function$
;

-- Function: is_admin_or_cofounder
CREATE OR REPLACE FUNCTION public.is_admin_or_cofounder(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select exists(select 1 from public.users where id=p_user_id and coalesce(is_blocked,false)=false and role in ('admin','co_founder','cofounder','super_admin')); $function$
;

-- Function: is_admin_or_founder
CREATE OR REPLACE FUNCTION public.is_admin_or_founder(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select public.is_admin_or_cofounder(p_user_id); $function$
;

-- Function: is_booking_payment_valid
CREATE OR REPLACE FUNCTION public.is_booking_payment_valid()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- هذه الـ function تتأكد من تطابق الـ payment state
  -- سيتم استخدامها في الـ RLS policies
  RETURN TRUE;
END;
$function$
;

-- Function: join_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.join_1v1_tournament_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_champ RECORD;
    v_order RECORD;
    v_user RECORD;
    v_current_count INT;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED', 'message', 'يجب تسجيل الدخول أولاً للمشاركة.');
    END IF;

    SELECT * INTO v_user
    FROM public.users
    WHERE id = v_caller_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND', 'message', 'المستخدم غير موجود.');
    END IF;

    IF COALESCE(v_user.is_blocked, false) = true THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_BLOCKED', 'message', 'الحساب محظور من المشاركة في البطولات.');
    END IF;

    IF COALESCE(v_user.is_debt_blocked, false) = true THEN
        RETURN jsonb_build_object('success', false, 'error', 'DEBT_BLOCKED', 'message', 'الحساب موقوف لتجاوز حد المديونية.');
    END IF;

    SELECT * INTO v_champ
    FROM public.vsp_1v1_tournaments
    WHERE id = p_tournament_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'TOURNAMENT_NOT_FOUND', 'message', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status <> 'registration_open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'message', 'التسجيل في هذه البطولة مغلق حالياً.');
    END IF;

    IF EXISTS(
        SELECT 1 FROM public.vsp_1v1_tournament_players
        WHERE tournament_id = p_tournament_id AND user_id = v_caller_id AND payment_status = 'paid'
    ) THEN
        RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
    END IF;

    SELECT count(*)::INT INTO v_current_count
    FROM public.vsp_1v1_tournament_players
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid';

    IF v_current_count >= v_champ.target_player_count THEN
        RETURN jsonb_build_object('success', false, 'error', 'CAPACITY_REACHED', 'message', 'عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.');
    END IF;

    -- Strict Paid-Only SSOT
    SELECT * INTO v_order
    FROM public.vsp_1v1_tournament_orders
    WHERE tournament_id = p_tournament_id
      AND user_id = v_caller_id
      AND payment_status = 'paid'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'PAYMENT_REQUIRED',
            'message', 'يجب إتمام الدفع الإلكتروني أولاً للاشتراك في البطولة.'
        );
    END IF;

    INSERT INTO public.vsp_1v1_tournament_players(
        tournament_id, user_id, player_name, avatar_url, tackles, goals, skills,
        registered_at, payment_status, payment_order_id, paid_amount
    )
    VALUES(
        p_tournament_id,
        v_caller_id,
        COALESCE(NULLIF(TRIM(v_user.name), ''), 'لاعب'),
        COALESCE(v_user.profile_image_url, ''),
        0, 0, 0, timezone('utc', now()),
        'paid',
        v_order.id,
        COALESCE(v_order.amount, 0)
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تسجيلك في البطولة بنجاح! حظاً موفقاً.',
        'player_count', v_current_count + 1,
        'payment_status', 'paid',
        'order_id', v_order.id
    );
EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
END;
$function$
;

-- Function: join_championship_atomic
CREATE OR REPLACE FUNCTION public.join_championship_atomic(p_championship_id uuid, p_team_id uuid, p_player_ids uuid[] DEFAULT ARRAY[]::uuid[], p_guest_names text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_champ RECORD;
  v_phase TEXT;
  v_team RECORD;
  v_captain RECORD;
  v_reg_id UUID;
  v_roster_id UUID;
  v_joined_count INT;
  v_player_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- 1. LOCK FIRST: Guarantee atomicity against concurrent mutations
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- 2. Phase Engine Check under Row Lock
  v_phase := public.calculate_championship_effective_phase(p_championship_id);
  IF v_phase != 'registration_open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'current_phase', v_phase);
  END IF;

  -- 3. Zero-fee check
  IF coalesce(v_champ.entry_fee, 0) > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_REQUIRED_USE_ORDER');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id AND registration_status = 'confirmed';

  IF v_joined_count >= v_champ.max_teams THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_FULL');
  END IF;

  -- 4. Duplicate player check within p_player_ids
  IF coalesce(array_length(p_player_ids, 1), 0) > 0 THEN
    IF (SELECT count(DISTINCT pid) FROM unnest(p_player_ids) pid) <> array_length(p_player_ids, 1) THEN
      RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_PLAYERS_IN_ROSTER');
    END IF;
  END IF;

  -- 5. Team membership check
  IF EXISTS (
    SELECT 1 FROM unnest(coalesce(p_player_ids, ARRAY[]::UUID[])) pid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.team_members tm 
      WHERE tm.team_id = p_team_id AND tm.user_id = pid
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TEAM_PLAYER_NOT_MEMBER');
  END IF;

  -- 6. Check player already registered with another team in this championship
  IF EXISTS (
    SELECT 1 
    FROM public.championship_roster_players crp
    JOIN public.championship_rosters cr ON cr.id = crp.roster_id
    WHERE cr.championship_id = p_championship_id
      AND cr.team_id <> p_team_id
      AND crp.player_id = ANY(coalesce(p_player_ids, ARRAY[]::UUID[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYER_ALREADY_IN_ANOTHER_TEAM');
  END IF;

  -- 7. Player count validation
  v_player_count := coalesce(array_length(p_player_ids, 1), 0) + coalesce(array_length(p_guest_names, 1), 0);
  IF v_player_count > coalesce(v_champ.max_players_per_team, 999) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ROSTER_TOO_LARGE', 'max_allowed', v_champ.max_players_per_team);
  END IF;
  IF v_player_count < coalesce(v_champ.min_players_per_team, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ROSTER_INCOMPLETE', 'min_required', v_champ.min_players_per_team);
  END IF;

  SELECT id, full_name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

  -- 8. Atomic Registration
  INSERT INTO public.championship_registrations (
    championship_id, team_id, captain_id, captain_snapshot,
    registration_status, payment_status, base_amount, gross_amount, currency,
    created_at, updated_at
  )
  VALUES (
    p_championship_id, p_team_id, v_team.captain_id,
    jsonb_build_object('id', v_captain.id, 'name', v_captain.full_name, 'phone', v_captain.phone),
    'confirmed', 'exempt', 0.00, 0.00, coalesce(v_champ.currency, 'EGP'),
    now(), now()
  )
  ON CONFLICT (championship_id, team_id) DO UPDATE SET
    registration_status = 'confirmed',
    payment_status = 'exempt',
    updated_at = now()
  RETURNING id INTO v_reg_id;

  -- 9. Atomic Roster
  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at, updated_at
  )
  VALUES (
    v_reg_id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now(), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
  RETURNING id INTO v_roster_id;

  -- 10. Atomic Roster Players
  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  -- 11. Update Championship Arrays
  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      updated_at = now()
  WHERE id = p_championship_id
    AND NOT (p_team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_reg_id,
    'roster_id', v_roster_id,
    'payment_status', 'exempt',
    'registration_status', 'confirmed',
    'player_count', v_player_count
  );
END;
$function$
;

-- Function: join_private_collective_match_atomic
CREATE OR REPLACE FUNCTION public.join_private_collective_match_atomic(p_invite_token text, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid:=auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_stadium public.stadiums%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_capacity integer;
  v_joined_count integer;
  v_player_gov text;
  v_stadium_gov text;
  v_conflict integer;
  v_now timestamptz:=timezone('utc',now());
BEGIN
  IF v_uid IS NULL OR v_uid<>p_user_id THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE collective_invite_token=lower(trim(coalesce(p_invite_token,'')))
    AND booking_type='open_join'
    AND is_private=true
    AND coalesce(collective_invite_active,true)=true
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'PRIVATE_COLLECTIVE_INVITE_NOT_FOUND'; END IF;
  IF v_booking.status='cancelled' THEN RAISE EXCEPTION 'MATCH_CANCELLED'; END IF;
  IF v_booking.status='completed' THEN RAISE EXCEPTION 'MATCH_COMPLETED'; END IF;
  IF v_booking.end_time<=v_now THEN RAISE EXCEPTION 'MATCH_EXPIRED'; END IF;
  IF v_booking.status<>'confirmed' THEN RAISE EXCEPTION 'MATCH_AWAITING_HOST_PAYMENT'; END IF;

  SELECT * INTO v_user FROM public.users WHERE id=v_uid;
  IF coalesce(v_user.is_blocked,false) THEN RAISE EXCEPTION 'USER_BLOCKED'; END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id=v_booking.stadium_id;
  v_player_gov:=nullif(trim(v_user.governorate),'');
  v_stadium_gov:=nullif(trim(v_stadium.governorate),'');

  IF v_player_gov IS NULL OR v_stadium_gov IS NULL THEN
    RAISE EXCEPTION 'GOVERNORATE_NOT_VERIFIED';
  END IF;

  IF public.normalize_governorate(v_player_gov)<>public.normalize_governorate(v_stadium_gov) THEN
    RAISE EXCEPTION 'COLLECTIVE_GOVERNORATE_MISMATCH';
  END IF;

  v_capacity:=coalesce(v_booking.total_field_capacity,v_booking.max_players,10);
  v_joined_count:=coalesce(cardinality(v_booking.joined_user_ids),0);

  IF coalesce(v_booking.current_players,v_joined_count+coalesce(v_booking.manual_player_count,0))>=v_capacity THEN
    RAISE EXCEPTION 'MATCH_IS_FULL';
  END IF;

  IF v_uid=ANY(coalesce(v_booking.joined_user_ids,array[]::uuid[])) THEN
    RAISE EXCEPTION 'ALREADY_JOINED';
  END IF;

  SELECT count(*) INTO v_conflict
  FROM public.bookings b
  WHERE b.id<>v_booking.id AND b.status<>'cancelled'
    AND (b.created_by_user_id=v_uid OR v_uid=ANY(coalesce(b.joined_user_ids,array[]::uuid[])))
    AND b.start_time<v_booking.end_time AND b.end_time>v_booking.start_time;

  IF v_conflict>0 THEN RAISE EXCEPTION 'TIME_CONFLICT'; END IF;

  PERFORM set_config('vsp.system_override','true',true);

  UPDATE public.bookings
  SET joined_user_ids=array_append(coalesce(joined_user_ids,array[]::uuid[]),v_uid),
      updated_at=v_now
  WHERE id=v_booking.id;

  RETURN jsonb_build_object(
    'success',true,'booking_id',v_booking.id,
    'current_players',
      coalesce(cardinality(v_booking.joined_user_ids),0)+1+coalesce(v_booking.manual_player_count,0),
    'manual_player_count',coalesce(v_booking.manual_player_count,0),
    'host_user_id',v_booking.created_by_user_id
  );
END;
$function$
;

-- Function: join_public_match
CREATE OR REPLACE FUNCTION public.join_public_match(p_booking_id uuid, p_user_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  v_res := public.request_join_public_match(p_booking_id::text, p_user_id);
  RETURN (v_res->>'success')::boolean;
END;
$function$
;

-- Function: join_team_league
CREATE OR REPLACE FUNCTION public.join_team_league(p_championship_id uuid, p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_captain UUID;
  v_champ RECORD;
  v_joined TEXT[];
  v_paid TEXT[];
  v_payment JSONB;
  v_is_prepaid BOOLEAN := FALSE;
  v_creator_paid BOOLEAN := FALSE;
  v_entry_fee NUMERIC;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;

  SELECT captain_id INTO v_captain FROM public.teams WHERE id = p_team_id;
  IF v_captain IS NULL OR v_captain <> v_uid THEN
    RAISE EXCEPTION 'فقط قائد الفريق يستطيع الانضمام للدوري';
  END IF;

  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id AND template_type = 'team_league' 
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الدوري غير موجود'; END IF;
  IF v_champ.status <> 'open' THEN RAISE EXCEPTION 'الدوري مغلق للتسجيل'; END IF;

  IF v_champ.entry_fee IS NULL OR v_champ.entry_fee <= 0 THEN
    RAISE EXCEPTION 'رسوم اشتراك الدوري غير محددة أو غير صالحة';
  END IF;

  v_entry_fee := v_champ.entry_fee;
  v_joined := COALESCE(v_champ.joined_teams, '{}'::TEXT[]);
  v_paid := COALESCE(v_champ.paid_teams, '{}'::TEXT[]);

  IF p_team_id::TEXT = ANY(v_joined) THEN
    IF p_team_id::TEXT = ANY(v_paid) THEN
      RETURN jsonb_build_object('success', true, 'already_joined', true, 'already_paid', true, 'message', 'رسوم مشاركة هذا الفريق مدفوعة بالفعل.');
    END IF;
    v_payment := public.prepare_team_league_payment(p_championship_id, p_team_id);
    RETURN jsonb_build_object(
      'success', true, 
      'already_joined', true, 
      'payment_required', true, 
      'payment_reference', v_payment->>'payment_reference', 
      'amount', COALESCE((v_payment->>'amount')::NUMERIC, v_entry_fee)
    );
  END IF;

  IF cardinality(v_joined) >= v_champ.max_teams THEN
    RAISE EXCEPTION 'اكتمل عدد الفرق في هذا الدوري';
  END IF;

  v_joined := array_append(v_joined, p_team_id::TEXT);

  -- 🛡️ BUG 4 Fix: Verify Creator Payment is PAID before allocating any prepaid slot!
  SELECT EXISTS (
    SELECT 1 FROM public.team_league_payments
    WHERE championship_id = p_championship_id
      AND user_id = v_champ.owner_id
      AND payment_status = 'paid'
  ) INTO v_creator_paid;

  -- Only allocate prepaid slots if creator actually paid, and covered count has room
  IF v_creator_paid AND cardinality(v_paid) < COALESCE(v_champ.paid_by_creator_count, 1) THEN
    v_is_prepaid := TRUE;
    v_paid := array_append(v_paid, p_team_id::TEXT);
  END IF;

  UPDATE public.championships 
  SET joined_teams = v_joined,
      paid_teams = v_paid,
      updated_at = now() 
  WHERE id = p_championship_id;

  IF cardinality(v_paid) >= v_champ.max_teams THEN
    PERFORM public.generate_team_league_fixtures(p_championship_id);
  END IF;

  IF v_is_prepaid THEN
    RETURN jsonb_build_object(
      'success', true,
      'joined', true,
      'already_paid', true,
      'prepaid_by_creator', true,
      'message', 'رسوم مشاركة الفريق: مدفوعة'
    );
  END IF;

  v_payment := public.prepare_team_league_payment(p_championship_id, p_team_id);
  RETURN jsonb_build_object(
    'success', true,
    'joined', true,
    'payment_required', true,
    'payment_reference', v_payment->>'payment_reference',
    'amount', COALESCE((v_payment->>'amount')::NUMERIC, v_entry_fee)
  );
END;
$function$
;

-- Function: leave_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.leave_1v1_tournament_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_caller uuid:=auth.uid(); v_t record; v_player record; v_order record;
 v_now timestamptz:=timezone('utc',now()); v_refund_amount numeric; v_manual boolean:=false;
begin
 if v_caller is null then return jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً.'); end if;
 select * into v_t from public.vsp_1v1_tournaments where id=p_tournament_id for update;
 if not found then return jsonb_build_object('success',false,'error','البطولة غير موجودة.'); end if;
 if v_t.status<>'registration_open' then return jsonb_build_object('success',false,'error','لا يمكن إلغاء التسجيل بعد إغلاق باب التسجيل أو بدء البطولة.'); end if;
 select * into v_player from public.vsp_1v1_tournament_players where tournament_id=p_tournament_id and user_id=v_caller for update;
 if not found then return jsonb_build_object('success',false,'error','أنت غير مسجل في هذه البطولة.'); end if;
 if coalesce(v_player.payment_status,'')<>'paid' then
   delete from public.vsp_1v1_tournament_players where id=v_player.id;
   return jsonb_build_object('success',true,'status','cancelled_unpaid','message','تم إلغاء التسجيل غير المدفوع.');
 end if;
 select * into v_order from public.vsp_1v1_tournament_orders where id=v_player.payment_order_id and tournament_id=p_tournament_id and user_id=v_caller for update;
 if not found then
   select * into v_order from public.vsp_1v1_tournament_orders where tournament_id=p_tournament_id and user_id=v_caller and payment_status='paid' order by created_at desc limit 1 for update;
 end if;
 if not found then
   update public.vsp_1v1_tournament_players set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_player.id;
   return jsonb_build_object('success',false,'manual_review',true,'error','تعذر العثور على سجل الدفع؛ تم وضع التسجيل للمراجعة اليدوية.');
 end if;
 if v_order.payment_status<>'paid' then return jsonb_build_object('success',true,'already_processing',true,'status',v_order.payment_status); end if;
 if v_order.gross_amount is null or v_order.gross_amount<=0
    or v_order.amount is null or v_order.amount<=0
    or nullif(trim(v_order.paymob_transaction_id),'') is null then
   v_manual:=true; v_refund_amount:=v_order.amount;
   update public.vsp_1v1_tournament_orders set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_player.id;
   insert into public.vsp_1v1_cancellation_refund_queue(tournament_id,order_id,user_id,paymob_transaction_id,amount,status,failure_reason,created_at,updated_at)
   values(p_tournament_id,v_order.id,v_caller,v_order.paymob_transaction_id,v_refund_amount,'failed_manual_review','Missing historical gross_amount; player requested cancellation and manual refund.',v_now,v_now);
   insert into public.transactions(user_id,amount,type,status,payment_method,reference_number,paymob_transaction_id,metadata,description,created_at,updated_at)
   values(v_caller,v_refund_amount,'refund_request','manual_review','paymob','REFUND_'||v_order.order_reference,v_order.paymob_transaction_id,
    jsonb_build_object('order_reference',v_order.order_reference,'paymob_transaction_id',v_order.paymob_transaction_id,'tournament_id',p_tournament_id,'tournament_name',v_t.name,'principal_amount',v_order.amount,'gross_amount',null,'player_requested',true,'requires_manual_review',true),
    'طلب استرداد رسوم بطولة 1v1 بناءً على إلغاء اللاعب - مراجعة يدوية',v_now,v_now);
 else
   v_refund_amount:=round(v_order.amount,2);
   update public.vsp_1v1_tournament_orders set payment_status='refund_requested',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refund_requested',updated_at=v_now where id=v_player.id;
   insert into public.vsp_1v1_cancellation_refund_queue(tournament_id,order_id,user_id,paymob_transaction_id,amount,status,failure_reason,created_at,updated_at)
   values(p_tournament_id,v_order.id,v_caller,v_order.paymob_transaction_id,v_refund_amount,'pending','Player requested tournament cancellation and refund.',v_now,v_now);
   insert into public.transactions(user_id,amount,type,status,payment_method,reference_number,paymob_transaction_id,metadata,description,created_at,updated_at)
   values(v_caller,v_refund_amount,'refund_request','pending','paymob','REFUND_'||v_order.order_reference,v_order.paymob_transaction_id,
    jsonb_build_object('order_reference',v_order.order_reference,'paymob_transaction_id',v_order.paymob_transaction_id,'tournament_id',p_tournament_id,'tournament_name',v_t.name,'principal_amount',v_order.amount,'refund_amount',v_refund_amount,'original_gross_amount',v_order.gross_amount,'non_refundable_fee_amount',round(greatest(v_order.gross_amount-v_refund_amount,0),2),'player_requested',true),
    'طلب استرداد رسوم بطولة 1v1 بناءً على إلغاء اللاعب',v_now,v_now);
   -- Remove the refunded principal from the prize pool once, under the tournament/order locks.
   update public.vsp_1v1_tournaments
   set prize_pool = greatest(coalesce(prize_pool,0) - v_refund_amount,0), updated_at = v_now
   where id = p_tournament_id;
 end if;
 insert into public.notifications(user_id,title,body,type,created_at) values(v_caller,'تم تسجيل طلب إلغاء واسترداد رسوم البطولة 💳','تم إلغاء تسجيلك من '||coalesce(v_t.name,'بطولة 1v1')||' و'||case when v_manual then 'وضع طلب الاسترداد للمراجعة اليدوية.' else 'إنشاء طلب استرداد رسمي وسيتم تحديثك عند اكتماله.' end,'tournament_refund',v_now);
 return jsonb_build_object('success',true,'status',case when v_manual then 'refund_failed_manual_review' else 'refund_requested' end,'refund_amount',v_refund_amount,'manual_review',v_manual,'message',case when v_manual then 'تم إلغاء التسجيل ووضع الاسترداد للمراجعة اليدوية.' else 'تم إلغاء التسجيل وإنشاء طلب الاسترداد.' end);
end; $function$
;

-- Function: leave_championship_atomic
CREATE OR REPLACE FUNCTION public.leave_championship_atomic(p_championship_id uuid, p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_champ record; v_team record; v_role text; v_paid boolean;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success',false,'error','Authentication required'); END IF;
 SELECT * INTO v_champ FROM public.championships WHERE id=p_championship_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Championship not found'); END IF;
 SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','Team not found'); END IF;
 SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
 IF v_team.captain_id IS DISTINCT FROM auth.uid() AND v_champ.owner_id IS DISTINCT FROM auth.uid() AND coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','Unauthorized'); END IF;
 IF NOT (p_team_id=ANY(coalesce(v_champ.joined_teams,ARRAY[]::uuid[]))) THEN RETURN jsonb_build_object('success',false,'error','Team is not registered'); END IF;
 IF v_champ.status<>'open' THEN RETURN jsonb_build_object('success',false,'error','Cannot leave after registration has closed'); END IF;
 SELECT EXISTS(SELECT 1 FROM public.tournament_orders WHERE championship_id=p_championship_id AND team_id=p_team_id AND payment_status='paid') INTO v_paid;
 IF v_paid THEN RETURN jsonb_build_object('success',false,'error','PAID_TEAM_REFUND_REQUIRED: A paid team cannot leave without a refund flow'); END IF;
 UPDATE public.championships SET joined_teams=array_remove(coalesce(joined_teams,ARRAY[]::uuid[]),p_team_id),paid_teams=array_remove(coalesce(paid_teams,ARRAY[]::uuid[]),p_team_id),updated_at=timezone('utc',now()) WHERE id=p_championship_id;
 UPDATE public.tournament_orders SET payment_status='cancelled_withdrawal',updated_at=timezone('utc',now()) WHERE championship_id=p_championship_id AND team_id=p_team_id AND payment_status='pending';
 RETURN jsonb_build_object('success',true,'championship_id',p_championship_id,'team_id',p_team_id);
END;
$function$
;

-- Function: leave_private_collective_match_atomic
CREATE OR REPLACE FUNCTION public.leave_private_collective_match_atomic(p_booking_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking public.bookings%rowtype; v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL OR v_uid<>p_user_id THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;
  SELECT * INTO v_booking FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_booking.status IN ('completed','cancelled','expired') OR v_booking.end_time<=timezone('utc',now()) THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave this collective match now.';
  END IF;
  IF v_booking.created_by_user_id=v_uid THEN
    RAISE EXCEPTION 'HOST_CANNOT_LEAVE: The host must cancel the booking instead.';
  END IF;
  IF NOT(v_uid=ANY(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) THEN RAISE EXCEPTION 'NOT_JOINED'; END IF;
  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings
  SET joined_user_ids=array_remove(joined_user_ids,v_uid),updated_at=timezone('utc',now())
  WHERE id=p_booking_id;
  RETURN true;
END;
$function$
;

-- Function: leave_public_match_atomic
CREATE OR REPLACE FUNCTION public.leave_public_match_atomic(p_booking_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_now     timestamptz := timezone('utc', now());
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
      RAISE EXCEPTION 'Unauthorized: You can only leave matches on your own behalf.';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;

  IF v_booking.status IN ('completed', 'cancelled', 'expired') THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave a % booking.', v_booking.status;
  END IF;

  IF v_booking.end_time <= v_now THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave a match that has already ended.';
  END IF;

  IF NOT (p_user_id = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'User is not a joined participant in this match';
  END IF;

  IF v_booking.created_by_user_id = p_user_id THEN
    RAISE EXCEPTION 'HOST_CANNOT_LEAVE: The host cannot leave. Cancel the booking instead.';
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET current_players = GREATEST(0, current_players - 1),
      joined_user_ids = array_remove(joined_user_ids, p_user_id),
      updated_at = v_now
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$
;

-- Function: link_league_match_booking
CREATE OR REPLACE FUNCTION public.link_league_match_booking(p_match_id uuid, p_booking_id uuid, p_scheduled_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_stadium_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE m record;b record;
BEGIN
 SELECT tm.*,c.template_type FROM tournament_matches tm JOIN championships c ON c.id=tm.championship_id WHERE tm.id=p_match_id FOR UPDATE;
 IF m.id IS NULL OR m.template_type <> 'team_league' THEN RAISE EXCEPTION 'مباراة الدوري غير موجودة'; END IF;
 SELECT bk.*,s.owner_id AS stadium_owner_id,s.name AS actual_stadium_name INTO b FROM bookings bk JOIN stadiums s ON s.id=bk.stadium_id WHERE bk.id=p_booking_id;
 IF b.id IS NULL THEN RAISE EXCEPTION 'الحجز غير موجود'; END IF;
 IF b.player_team_id IS DISTINCT FROM m.home_team_id AND b.player_team_id IS DISTINCT FROM m.away_team_id THEN RAISE EXCEPTION 'الحجز لا يخص أحد طرفي المباراة'; END IF;
 IF b.opponent_team_id IS DISTINCT FROM (CASE WHEN b.player_team_id=m.home_team_id THEN m.away_team_id ELSE m.home_team_id END) THEN RAISE EXCEPTION 'الحجز لا يطابق طرفي المباراة'; END IF;
 IF b.status='cancelled' THEN RAISE EXCEPTION 'لا يمكن ربط حجز ملغى'; END IF;
 IF NOT EXISTS (SELECT 1 FROM teams t WHERE t.id=b.player_team_id AND t.captain_id=auth.uid()) THEN RAISE EXCEPTION 'ربط الحجز متاح لقائد الفريق الحاجز فقط'; END IF;
 UPDATE tournament_matches SET booking_id=b.id,scheduled_time=b.start_time,stadium_name=b.actual_stadium_name,status='scheduled',updated_at=NOW() WHERE id=p_match_id;
 RETURN jsonb_build_object('success',true,'message','تم ربط الحجز بالمباراة بنجاح');
END; $function$
;

-- Function: lock_sensitive_user_fields
CREATE OR REPLACE FUNCTION public.lock_sensitive_user_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ BEGIN RETURN NEW; END; $function$
;

-- Function: log_booking_payment_transaction
CREATE OR REPLACE FUNCTION public.log_booking_payment_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_existing_paid numeric; v_remaining numeric;
begin
  if new.webhook_verified is true then return new; end if;
  if current_setting('vsp.manual_booking_workflow',true)='true' then return new; end if;
  if new.status in ('confirmed','completed') and new.is_paid=true
     and (lower(coalesce(new.payment_method,''))='cash' or upper(coalesce(new.payment_transaction_id,'')) like 'MANUAL%') then
    select coalesce(sum(case
      when type in ('payment','deposit','cash_settlement','cash_collection_adjustment') then abs(amount)
      when type='refund_cash' then -abs(amount) else 0 end),0)
    into v_existing_paid from public.transactions where booking_id=new.id and status='completed';
    v_remaining:=greatest(round(coalesce(new.total_price,0)-v_existing_paid,2),0);
    if v_remaining>0 and not exists(select 1 from public.transactions where booking_id=new.id and type='cash_settlement' and status='completed') then
      insert into public.transactions(booking_id,amount,created_at,type,user_id,status,description,reference_number,payment_method,metadata)
      values(new.id,v_remaining,coalesce(new.updated_at,now()),'cash_settlement',new.user_id,'completed','تحصيل كاش مؤكد لحجز ملعب',new.payment_transaction_id,'cash',
        jsonb_build_object('principal_amount',v_remaining,'vsp_fee',0,'gateway_fee',0,'gross_amount',v_remaining))
      on conflict do nothing;
    end if;
  end if;
  return new;
end; $function$
;

-- Function: lookup_challenge_code
CREATE OR REPLACE FUNCTION public.lookup_challenge_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller         uuid := auth.uid();
  v_entry          record;
  v_team           record;
  v_members        int;
  v_caller_team_id uuid;
  v_clean_code     text;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  v_clean_code := upper(trim(COALESCE(p_code, '')));
  IF NOT v_clean_code LIKE 'VSP-%' AND length(v_clean_code) = 5 THEN
    v_clean_code := 'VSP-' || v_clean_code;
  END IF;

  SELECT * INTO v_entry
  FROM public.team_challenge_codes
  WHERE (code = v_clean_code OR code = upper(trim(p_code))) AND status = 'active'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CODE_INVALID_OR_USED');
  END IF;

  IF v_entry.expires_at IS NOT NULL AND v_entry.expires_at < timezone('utc', now()) THEN
    UPDATE public.team_challenge_codes SET status = 'expired' WHERE id = v_entry.id;
    RETURN jsonb_build_object('success', false, 'error', 'CODE_EXPIRED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  SELECT COUNT(*) INTO v_members FROM public.team_members WHERE team_id = v_entry.team_id;

  SELECT id INTO v_caller_team_id
  FROM public.teams WHERE captain_id = v_caller LIMIT 1;

  IF v_caller_team_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN');
  END IF;

  IF v_caller_team_id = v_entry.team_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM');
  END IF;

  RETURN jsonb_build_object(
    'success',              true,
    'opponent_team_id',     v_entry.team_id,
    'opponent_team_name',   v_team.name,
    'opponent_captain',     v_team.captain_name,
    'opponent_logo_url',    v_team.logo_url,
    'member_count',         v_members,
    'caller_team_id',       v_caller_team_id,
    'code_id',              v_entry.id,
    'code',                 v_entry.code
  );
END;
$function$
;

-- Function: mark_1v1_prize_delivered_atomic
CREATE OR REPLACE FUNCTION public.mark_1v1_prize_delivered_atomic(p_tournament_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_champ RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 🔒 Authorization: Only admin or co_founder
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط الأدمن يمكنه توثيق تسليم الجوائز.');
        END IF;
    END IF;

    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تسليم الجائزة قبل انتهاء البطولة وتتويج البطل رسمياً.');
    END IF;

    IF v_champ.prize_delivered = true THEN
        RETURN jsonb_build_object(
            'success', false, 
            'already_delivered', true, 
            'error', 'تم توثيق تسليم الجائزة بالفعل مسبقاً في: ' || v_champ.prize_delivered_at::text
        );
    END IF;

    -- Update tournament with delivery metadata (Pure audit log, no wallet movements)
    UPDATE public.vsp_1v1_tournaments
    SET 
        prize_delivered = true,
        prize_delivered_at = v_now,
        prize_delivered_by = v_caller_id,
        prize_delivery_notes = p_notes,
        updated_at = v_now
    WHERE id = p_tournament_id;

    -- Notify champion
    IF v_champ.champion_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_champ.champion_user_id,
            'توثيق استلام الجائزة المالية 🏆',
            'تهانينا! تم توثيق استلامك لجائزة بطولة ' || COALESCE(v_champ.name, '1v1') || ' وقدرها ' || COALESCE(v_champ.prize_pool, 0) || ' ج.م بنجاح.',
            'tournament_update',
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'prize_delivered', true,
        'prize_pool', v_champ.prize_pool,
        'champion_user_id', v_champ.champion_user_id,
        'delivered_at', v_now
    );
END;
$function$
;

-- Function: mark_championship_prize_delivered_atomic
CREATE OR REPLACE FUNCTION public.mark_championship_prize_delivered_atomic(p_championship_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
    v_caller_id UUID := auth.uid();
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Authorization: service_role, admin, co_founder, or championship owner
    IF COALESCE(auth.role(), '') != 'service_role' THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً.');
        END IF;
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
        END IF;
        IF (v_champ.owner_id IS DISTINCT FROM v_caller_id) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بتوثيق تسليم الجائزة. العملية مقتصرة على منظم البطولة أو الإدارة.');
        END IF;
    ELSE
        SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
        END IF;
    END IF;

    -- 2. Status verification
    IF v_champ.status != 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تسليم الجائزة إلا بعد اكتمال وتتويج بطل البطولة رسمياً.');
    END IF;

    -- 3. Double-handover prevention
    IF COALESCE(v_champ.prize_delivered, false) = true THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'تم توثيق تسليم الجائزة المالية لهذه البطولة مسبقاً ولا يمكن تكرار التسليم.'
        );
    END IF;

    -- 4. Mark prize delivered atomically
    UPDATE public.championships
    SET prize_delivered = true,
        prize_delivered_at = v_now,
        prize_delivered_by = v_caller_id,
        prize_delivery_notes = TRIM(COALESCE(p_notes, '')),
        updated_at = v_now
    WHERE id = p_championship_id;

    -- 5. Audit log in transactions table
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        p_championship_id,
        v_champ.champion_user_id,
        COALESCE(v_champ.prize_pool, 0.00),
        'prize_payout',
        'cash',
        'completed',
        'توثيق تسليم الجائزة المالية يداً بيد لكابتن الفريق البطل',
        jsonb_build_object(
            'handover_by', v_caller_id,
            'handover_at', v_now,
            'notes', TRIM(COALESCE(p_notes, '')),
            'champion_team_id', v_champ.champion_team_id,
            'champion_team_name', v_champ.champion_team_name,
            'amount', COALESCE(v_champ.prize_pool, 0.00)
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم توثيق تسليم الجائزة المالية بنجاح.',
        'prize_delivered_at', v_now,
        'amount', COALESCE(v_champ.prize_pool, 0.00)
    );
END;
$function$
;

-- Function: mark_chat_messages_as_read
CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(p_conversation_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_unread jsonb;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF auth.uid() IS NULL OR (auth.uid() != p_user_id) THEN
      RAISE EXCEPTION 'Unauthorized: You can only mark messages as read for yourself.';
    END IF;
  END IF;

  UPDATE public.chat_messages
  SET is_read = TRUE
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND is_read = FALSE;

  SELECT COALESCE(unread_counts, '{}'::jsonb) INTO v_unread
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF v_unread ? p_user_id::text THEN
    v_unread := jsonb_set(v_unread, ARRAY[p_user_id::text], '0'::jsonb);

    UPDATE public.conversations
    SET unread_counts = v_unread,
        updated_at = NOW()
    WHERE id = p_conversation_id;
  END IF;
END;
$function$
;

-- Function: mark_support_ticket_whatsapp_escalation
CREATE OR REPLACE FUNCTION public.mark_support_ticket_whatsapp_escalation(p_ticket_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
begin
  if v_uid is null or coalesce(auth.role(),'') <> 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  select * into v_ticket from public.support_tickets where id=p_ticket_id for update;
  if not found or v_ticket.requester_id<>v_uid then raise exception 'TICKET_ACCESS_DENIED'; end if;
  update public.support_tickets
  set source='whatsapp_escalation',
      updated_at=timezone('utc',now())
  where id=p_ticket_id;
  return jsonb_build_object('success',true,'ticket_id',p_ticket_id);
end;
$function$
;

-- Function: normalize_booking_pending_fees
CREATE OR REPLACE FUNCTION public.normalize_booking_pending_fees()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- Fees are zero only while a booking is genuinely unpaid/pending.
  -- Once an actual payment transaction has been recorded, retain the
  -- server-computed fee aggregates for both cash and electronic payments.
  if coalesce(new.payment_status, 'pending') not in ('paid','partially_paid') then
    new.vsp_commission := 0;
    new.platform_fee := 0;
    new.gateway_fee := 0;
  end if;
  return new;
end;
$function$
;

-- Function: normalize_governorate
CREATE OR REPLACE FUNCTION public.normalize_governorate(p_gov text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_gov IS NULL OR trim(p_gov) = '' THEN
        RETURN 'Cairo';
    END IF;
    
    RETURN CASE trim(lower(p_gov))
        -- Arabic variants
        WHEN 'القاهرة' THEN 'Cairo'
        WHEN 'الجيزة' THEN 'Giza'
        WHEN 'الإسكندرية' THEN 'Alexandria'
        WHEN 'الاسكندرية' THEN 'Alexandria'
        WHEN 'أسوان' THEN 'Aswan'
        WHEN 'اسوان' THEN 'Aswan'
        WHEN 'أسيوط' THEN 'Asyut'
        WHEN 'اسيوط' THEN 'Asyut'
        WHEN 'البحيرة' THEN 'Beheira'
        WHEN 'بني سويف' THEN 'Beni Suef'
        WHEN 'الدقهلية' THEN 'Dakahlia'
        WHEN 'دمياط' THEN 'Damietta'
        WHEN 'الفيوم' THEN 'Faiyum'
        WHEN 'الغربية' THEN 'Gharbia'
        WHEN 'الإسماعيلية' THEN 'Ismailia'
        WHEN 'الاسماعيلية' THEN 'Ismailia'
        WHEN 'كفر الشيخ' THEN 'Kafr El Sheikh'
        WHEN 'الأقصر' THEN 'Luxor'
        WHEN 'الاقصر' THEN 'Luxor'
        WHEN 'مطروح' THEN 'Matrouh'
        WHEN 'مرسى مطروح' THEN 'Matrouh'
        WHEN 'المنيا' THEN 'Minya'
        WHEN 'المنوفية' THEN 'Monufia'
        WHEN 'الوادي الجديد' THEN 'New Valley'
        WHEN 'شمال سيناء' THEN 'North Sinai'
        WHEN 'بورسعيد' THEN 'Port Said'
        WHEN 'بور سعيد' THEN 'Port Said'
        WHEN 'القليوبية' THEN 'Qalyubia'
        WHEN 'قنا' THEN 'Qena'
        WHEN 'البحر الأحمر' THEN 'Red Sea'
        WHEN 'البحر الاحمر' THEN 'Red Sea'
        WHEN 'الشرقية' THEN 'Sharqia'
        WHEN 'سوهاج' THEN 'Sohag'
        WHEN 'جنوب سيناء' THEN 'South Sinai'
        WHEN 'السويس' THEN 'Suez'
        -- English variants (lowercase / whitespace)
        WHEN 'cairo' THEN 'Cairo'
        WHEN 'giza' THEN 'Giza'
        WHEN 'alexandria' THEN 'Alexandria'
        WHEN 'aswan' THEN 'Aswan'
        WHEN 'asyut' THEN 'Asyut'
        WHEN 'beheira' THEN 'Beheira'
        WHEN 'beni suef' THEN 'Beni Suef'
        WHEN 'dakahlia' THEN 'Dakahlia'
        WHEN 'damietta' THEN 'Damietta'
        WHEN 'faiyum' THEN 'Faiyum'
        WHEN 'gharbia' THEN 'Gharbia'
        WHEN 'ismailia' THEN 'Ismailia'
        WHEN 'kafr el sheikh' THEN 'Kafr El Sheikh'
        WHEN 'luxor' THEN 'Luxor'
        WHEN 'matrouh' THEN 'Matrouh'
        WHEN 'minya' THEN 'Minya'
        WHEN 'monufia' THEN 'Monufia'
        WHEN 'new valley' THEN 'New Valley'
        WHEN 'north sinai' THEN 'North Sinai'
        WHEN 'port said' THEN 'Port Said'
        WHEN 'qalyubia' THEN 'Qalyubia'
        WHEN 'qena' THEN 'Qena'
        WHEN 'red sea' THEN 'Red Sea'
        WHEN 'sharqia' THEN 'Sharqia'
        WHEN 'sohag' THEN 'Sohag'
        WHEN 'south sinai' THEN 'South Sinai'
        WHEN 'suez' THEN 'Suez'
        ELSE initcap(trim(p_gov))
    END;
END;
$function$
;

-- Function: notify_cash_booking_parties
CREATE OR REPLACE FUNCTION public.notify_cash_booking_parties()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_owner_id uuid;
  v_captain_id uuid;
  v_player_name text;
  v_body text;
begin
  if lower(coalesce(NEW.payment_method,'')) <> 'cash' or NEW.status <> 'confirmed' then
    return NEW;
  end if;

  v_owner_id := NEW.owner_id;
  v_player_name := coalesce(
    nullif(trim(NEW.host_name),''),
    nullif(trim(NEW.player_team_name),''),
    'لاعب'
  );
  v_body := v_player_name || ' قام بحجز ' ||
    coalesce(NEW.stadium_name,'الملعب') || ' في الموعد المحدد.';

  if v_owner_id is not null then
    insert into public.notifications(
      user_id,title,body,message,type,is_read,created_at,booking_id
    )
    values(
      v_owner_id,'حجز جديد مستلم!',v_body,v_body,
      'info',false,timezone('utc',now()),NEW.id
    );
  end if;

  if lower(coalesce(NEW.booking_type,'')) = 'challenge'
     and NEW.opponent_team_id is not null then
    select t.captain_id into v_captain_id
    from public.teams t
    where t.id = NEW.opponent_team_id;

    if v_captain_id is not null and v_captain_id <> NEW.created_by_user_id then
      v_body := coalesce(NEW.player_team_name,'فريق') || ' × ' ||
        coalesce(NEW.opponent_team_name,'فريقك') || ' في ' ||
        coalesce(NEW.stadium_name,'الملعب') || '.';

      insert into public.notifications(
        user_id,title,body,message,type,is_read,created_at,booking_id
      )
      values(
        v_captain_id,'تم تأكيد مباراة تحدي!',v_body,v_body,
        'challenge_confirmed',false,timezone('utc',now()),NEW.id
      );
    end if;
  end if;

  return NEW;
end;
$function$
;

-- Function: owner_cancel_manual_booking_atomic
CREATE OR REPLACE FUNCTION public.owner_cancel_manual_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_refund_deposit boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_now timestamptz:=timezone('utc',now()); v_deposit numeric;
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder')
  THEN RETURN jsonb_build_object('success',false,'message','غير مصرح.'); END IF;
 END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',true,'message','الحجز ملغي بالفعل مسبقاً.'); END IF;
 IF v_booking.start_time<=v_now THEN RETURN jsonb_build_object('success',false,'message','لا يمكن إلغاء الحجز اليدوي بعد بدء موعده.'); END IF;
 v_deposit:=coalesce(v_booking.deposit_paid,0);
 IF p_refund_deposit IS TRUE AND v_deposit>0 THEN
  INSERT INTO public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at)
  VALUES(v_booking.owner_id,p_booking_id,v_deposit,'cash_refund','completed','cash','استرداد عربون حجز يدوي ملغي: '||coalesce(v_booking.stadium_name,'الملعب'),v_now,v_now);
  UPDATE public.bookings SET status='cancelled',deposit_paid=0,is_deposit_paid=false,is_paid=false,cancellation_reason='تم إلغاء الحجز اليدوي ورد العربون للعميل',cancelled_at=v_now,updated_at=v_now WHERE id=p_booking_id;
 ELSE
  UPDATE public.bookings SET status='cancelled',cancellation_reason=CASE WHEN v_deposit>0 THEN 'تم إلغاء الحجز اليدوي مع الاحتفاظ بالعربون كشرط جزائي' ELSE 'تم إلغاء الحجز اليدوي' END,cancelled_at=v_now,updated_at=v_now WHERE id=p_booking_id;
 END IF;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'deposit_refunded',p_refund_deposit AND v_deposit>0,'refunded_amount',CASE WHEN p_refund_deposit AND v_deposit>0 THEN v_deposit ELSE 0 END);
END;$function$
;

-- Function: owner_create_manual_booking_atomic
CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_total_price numeric DEFAULT 0, p_collected_amount numeric DEFAULT 0, p_current_players integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_stadium record; v_role text; v_actual_owner_id uuid; v_authorized boolean:=false;
v_duration numeric; v_server_total numeric; v_collected numeric; v_booking_id uuid; v_tx_id uuid; v_ref text; v_now timestamptz:=now();
begin
select * into v_stadium from public.stadiums where id=p_stadium_id for update;
if not found then return jsonb_build_object('success',false,'error','STADIUM_NOT_FOUND'); end if;
v_actual_owner_id:=v_stadium.owner_id;
if v_stadium.is_deleted_by_owner is true or coalesce(v_stadium.is_blocked,false) or coalesce(v_stadium.is_verified,false) is false then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
select role into v_role from public.users where id=auth.uid();
if auth.role()='service_role' or current_user in ('postgres','service_role') or v_actual_owner_id=auth.uid() or coalesce(v_role,'') in ('admin','co_founder','cofounder','super_admin') then v_authorized:=true; end if;
if not v_authorized then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
if p_end_time<=p_start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
v_duration:=extract(epoch from(p_end_time-p_start_time))/3600;
if v_duration<=0 or v_duration>(select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
v_server_total:=round(coalesce(v_stadium.price_per_hour,v_stadium.base_price,0)*v_duration,2);
if v_server_total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
if abs(coalesce(p_total_price,0)-v_server_total)>0.01 then return jsonb_build_object('success',false,'error','PRICE_MISMATCH','expected_total_price',v_server_total); end if;
v_collected:=round(coalesce(p_collected_amount,0),2);
if v_collected < 0 or v_collected > v_server_total then
  return jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT');
end if;
if p_start_time<v_now-(select booking_past_grace_minutes from public.platform_business_rules where id=1)*interval '1 minute' then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
perform pg_advisory_xact_lock(hashtextextended(p_stadium_id::text,0));
if exists(select 1 from public.bookings b where b.stadium_id=p_stadium_id and b.status<>'cancelled' and p_start_time<b.end_time and p_end_time>b.start_time) then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end if;
v_ref:='MANUAL_'||replace(gen_random_uuid()::text,'-','');
perform set_config('vsp.manual_booking_workflow','true',true);
insert into public.bookings(stadium_id,stadium_name,owner_id,user_id,created_by_user_id,start_time,end_time,booking_type,player_team_name,host_name,player_phone,notes,total_price,vsp_commission,gateway_fee,platform_fee,deposit_paid,is_deposit_paid,is_paid,payment_status,payment_method,payment_transaction_id,status,current_players,is_private,rent_ball,created_at,updated_at)
values(
  p_stadium_id,v_stadium.name,v_actual_owner_id,v_actual_owner_id,coalesce(auth.uid(),v_actual_owner_id),
  p_start_time,p_end_time,'personal',nullif(trim(p_customer_name),''),nullif(trim(p_customer_name),''),
  nullif(trim(p_customer_phone),''),nullif(trim(p_notes),''),v_server_total,0,0,0,
  v_collected,v_collected>0,v_collected>=v_server_total,
  case when v_collected>=v_server_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
  'cash',v_ref,'confirmed',null,true,false,v_now,v_now
)
returning id into v_booking_id;
insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
values(v_actual_owner_id,v_booking_id,v_collected,'cash_settlement','completed','cash',v_ref,'تحصيل نقدي لحجز يدوي',jsonb_build_object('principal_amount',v_collected,'gross_amount',v_collected,'vsp_fee',0,'gateway_fee',0,'total_payment_fees',0,'server_recorded_at',v_now),v_now,v_now)
returning id into v_tx_id;
perform set_config('vsp.manual_booking_workflow','',true);
return jsonb_build_object(
  'success',true,
  'booking_id',v_booking_id,
  'total_price',v_server_total,
  'collected_amount',v_collected,
  'remaining_amount',greatest(v_server_total-v_collected,0),
  'payment_status',case when v_collected>=v_server_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
  'transaction_id',v_tx_id
);
exception when others then perform set_config('vsp.manual_booking_workflow','',true); return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end; $function$
;

-- Function: owner_extend_match_atomic
CREATE OR REPLACE FUNCTION public.owner_extend_match_atomic(p_booking_id uuid, p_added_minutes integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_new_end_time TIMESTAMPTZ;
    v_conflict_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. فحص قطعي: منع أي استدعاء مجهول الهوية (anon)
    IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'unauthorized', 
            'message', 'Authentication required.'
        );
    END IF;

    -- 2. جلب بيانات الحجز وقفل السجل
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 3. التحقق الآمن ضد الـ NULL باستخدام IS DISTINCT FROM
    IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) 
       AND auth.role() != 'service_role' 
       AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message', 'غير مصرح لك بتعديل هذا الحجز.');
    END IF;

    -- 4. قفل الملعب لمنع أي حجز متزامن في نفس النافذة
    PERFORM 1 FROM public.stadiums WHERE id = v_booking.stadium_id FOR UPDATE;

    v_new_end_time := v_booking.end_time + (COALESCE(p_added_minutes, 30) || ' minutes')::INTERVAL;

    -- 5. فحص التضارب مع أي حجز تالٍ نشط
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id = v_booking.stadium_id
      AND id != p_booking_id
      AND status != 'cancelled'
      AND start_time < v_new_end_time
      AND end_time > v_booking.end_time;

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'conflict',
            'message', 'لا يمكن تمديد المباراة، يوجد حجز آخر يبدأ في هذا الوقت.'
        );
    END IF;

    -- 6. تحديث وقت نهاية الحجز
    UPDATE public.bookings
    SET end_time = v_new_end_time,
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_end_time', v_new_end_time,
        'message', 'تم تمديد المباراة 30 دقيقة إضافية بنجاح.'
    );
END;
$function$
;

-- Function: owner_lock_slot_atomic
CREATE OR REPLACE FUNCTION public.owner_lock_slot_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_reason text DEFAULT 'صيانة دورية'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_stadium RECORD;
    v_overlap_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_booking_id UUID;
    v_caller_role TEXT;
BEGIN
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
    END IF;

    -- 🔒 التحقق الصارم من ملكية الملعب
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

        IF (v_stadium.owner_id != auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You can only lock slots for your own stadiums.');
        END IF;
    END IF;

    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Slot already booked or overlaps with an active match');
    END IF;

    INSERT INTO public.bookings (
        stadium_id,
        owner_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
        notes,
        total_price,
        deposit_paid,
        is_deposit_paid,
        is_paid,
        payment_status,
        payment_method,
        status,
        current_players,
        is_private,
        rent_ball,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        v_stadium.owner_id,
        COALESCE(auth.uid(), p_owner_id),
        p_start_time,
        p_end_time,
        'maintenance',
        'قفل صيانة المالك',
        p_reason,
        0,
        0,
        false,
        true,
        'paid',
        'owner_block',
        'confirmed',
        0,
        true,
        false,
        v_now,
        v_now
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Slot locked successfully'
    );
END;
$function$
;

-- Function: owner_record_no_show_atomic
CREATE OR REPLACE FUNCTION public.owner_record_no_show_atomic(p_booking_id uuid, p_owner_id uuid, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_now timestamptz:=timezone('utc',now()); v_player_id uuid;
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;

 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN
  RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); 
 END IF;

 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id
     AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
   RETURN jsonb_build_object('success',false,'message','غير مصرح: تسجيل عدم الحضور متاح فقط لمالك الملعب أو الإدارة.');
  END IF;
 END IF;

 IF v_booking.status='no_show' THEN RETURN jsonb_build_object('success',true,'message','تم تسجيل عدم الحضور مسبقاً.'); END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تسجيل عدم الحضور لحجز ملغى.'); END IF;
 IF v_booking.end_time IS NULL OR v_booking.end_time>v_now THEN
  RETURN jsonb_build_object('success',false,'message','لا يمكن تسجيل عدم الحضور قبل انتهاء موعد الحجز.'); 
 END IF;

 v_player_id:=coalesce(v_booking.user_id,v_booking.created_by_user_id);

 UPDATE public.bookings
 SET status='no_show',
     is_paid=(coalesce(deposit_paid,0)>0),
     payment_status=CASE WHEN coalesce(deposit_paid,0)>0 THEN 'paid' ELSE payment_status END,
     cancellation_reason='غياب اللاعب وعدم الحضور بالموعد المحدد (العربون تعويض للملعب)',
     notes=CASE WHEN length(trim(coalesce(p_notes,'')))>0 THEN coalesce(notes,'')||' | '||trim(p_notes) ELSE notes END,
     updated_at=v_now
 WHERE id=p_booking_id;

 IF v_player_id IS NOT NULL THEN
  UPDATE public.users SET fair_play_score=greatest(0,coalesce(fair_play_score,100)-10),updated_at=v_now WHERE id=v_player_id;
  INSERT INTO public.notifications(user_id,title,body,type,created_at)
  VALUES(v_player_id,'تسجيل عدم حضور (No-Show)',
   'تم تسجيل عدم حضورك للمباراة المقررة في '||coalesce(v_booking.stadium_name,'الملعب')||'. تم احتساب العربون تعويضاً للملعب وفق شروط الحجز.',
   'booking_no_show',v_now);
 END IF;

 RETURN jsonb_build_object('success',true,'message','تم تسجيل عدم حضور اللاعب واعتماد العربون كتعويض للملعب بنجاح.');
END;$function$
;

-- Function: owner_update_manual_booking_atomic
CREATE OR REPLACE FUNCTION public.owner_update_manual_booking_atomic(p_booking_id uuid, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_current_players integer DEFAULT 1, p_collected_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare b record; s record; r text; role_name text; dur numeric; total numeric; new_col numeric; old_col numeric; delta numeric; now_ts timestamptz:=now();
begin
select * into b from public.bookings where id=p_booking_id for update;
if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
select role into role_name from public.users where id=auth.uid();
if b.owner_id is distinct from auth.uid() and coalesce(role_name,'') not in ('admin','co_founder','cofounder','super_admin') and auth.role()<>'service_role' then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
if b.status='cancelled' then return jsonb_build_object('success',false,'error','BOOKING_CANCELLED'); end if;
if b.payment_method<>'cash' or (coalesce(b.payment_transaction_id,'') not like 'MANUAL%' and b.created_by_user_id<>b.owner_id) then return jsonb_build_object('success',false,'error','MANUAL_BOOKING_ONLY'); end if;
if p_end_time<=b.start_time or now_ts>=b.start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
select * into s from public.stadiums where id=b.stadium_id for update;
if not found or s.is_deleted_by_owner or coalesce(s.is_blocked,false) then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
dur:=extract(epoch from(p_end_time-b.start_time))/3600;
if dur<=0 or dur>(select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
total:=round(coalesce(s.price_per_hour,s.base_price,0)*dur,2);
if total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
new_col:=round(coalesce(p_collected_amount,0),2);
if new_col < 0 or new_col > total then
  return jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT');
end if;
perform pg_advisory_xact_lock(hashtextextended(b.stadium_id::text,0));
if exists(select 1 from public.bookings x where x.stadium_id=b.stadium_id and x.id<>b.id and x.status<>'cancelled' and b.start_time<x.end_time and p_end_time>x.start_time) then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end if;
old_col:=round(coalesce(b.deposit_paid,0),2); delta:=round(new_col-old_col,2); r:=coalesce(nullif(b.payment_transaction_id,''),'MANUAL_'||replace(gen_random_uuid()::text,'-',''));
perform set_config('vsp.manual_booking_workflow','true',true);
update public.bookings set
  end_time=p_end_time,
  player_team_name=coalesce(nullif(trim(p_customer_name),''),player_team_name),
  host_name=coalesce(nullif(trim(p_customer_name),''),host_name),
  player_phone=nullif(trim(p_customer_phone),''),
  notes=nullif(trim(p_notes),''),
  current_players=null,
  total_price=total,
  deposit_paid=new_col,
  is_deposit_paid=new_col>0,
  is_paid=new_col>=total,
  payment_status=case when new_col>=total then 'paid' when new_col>0 then 'partially_paid' else 'pending' end,
  payment_transaction_id=r,
  updated_at=now_ts
where id=p_booking_id;
if abs(delta)>0.009 then
insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
values(b.owner_id,p_booking_id,abs(delta),case when delta>0 then 'cash_settlement' else 'refund_cash' end,'completed','cash',r||case when delta>0 then '_ADJ_' else '_REF_' end||replace(gen_random_uuid()::text,'-',''),case when delta>0 then 'تعديل تحصيل نقدي لحجز يدوي' else 'تعديل/رد تحصيل نقدي لحجز يدوي' end,jsonb_build_object('previous_collected',old_col,'new_collected',new_col,'delta',delta,'manual_booking',true),now_ts,now_ts);
end if;
perform set_config('vsp.manual_booking_workflow','',true);
return jsonb_build_object(
  'success',true,
  'booking_id',p_booking_id,
  'total_price',total,
  'collected_amount',new_col,
  'remaining_amount',greatest(total-new_col,0),
  'payment_status',case when new_col>=total then 'paid' when new_col>0 then 'partially_paid' else 'pending' end
);
exception when others then perform set_config('vsp.manual_booking_workflow','',true); return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end; $function$
;

-- Function: pay_rehabilitation_fine
CREATE OR REPLACE FUNCTION public.pay_rehabilitation_fine(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF auth.uid() != p_user_id AND NOT EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بسداد الغرامة لحساب آخر.';
    END IF;

    UPDATE public.users
    SET no_show_count = 0,
        cash_booking_banned = false,
        completed_online_bookings_count = 0,
        updated_at = now()
    WHERE id = p_user_id;

    RETURN true;
END;
$function$
;

-- Function: persist_copilot_turn
CREATE OR REPLACE FUNCTION public.persist_copilot_turn(p_conversation_id uuid, p_user_id uuid, p_user_content text, p_assistant_content text, p_stadium_results jsonb DEFAULT '[]'::jsonb, p_ui_metadata jsonb DEFAULT '{}'::jsonb, p_context_snapshot jsonb DEFAULT '{}'::jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_current_snapshot jsonb;
  v_current_version int := 0;
  v_incoming_version int := 0;
  v_last_seq bigint := 0;
  v_final_snapshot jsonb;
begin
  -- 1. Validation: p_user_id and p_conversation_id are required
  if p_conversation_id is null or p_user_id is null then
    raise exception 'conversation_id and user_id are required';
  end if;

  -- 2. Authorization: Allow service_role (Edge Function), postgres superuser, OR authenticated user matching p_user_id
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role')
     and (auth.uid() is null or p_user_id is distinct from auth.uid()) then
    raise exception 'Unauthorized';
  end if;

  -- 3. Verify conversation exists and belongs to the specified user
  select context_snapshot into v_current_snapshot
  from public.copilot_conversations
  where id = p_conversation_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'conversation not found for user';
  end if;

  -- 4. Calculate sequence number
  select coalesce(max(message_sequence), 0) into v_last_seq
  from public.copilot_messages
  where conversation_id = p_conversation_id;

  -- 5. Insert user message
  insert into public.copilot_messages(
    conversation_id, user_id, role, content, stadium_results, ui_metadata, message_sequence
  ) values (
    p_conversation_id, p_user_id, 'user', p_user_content, '[]'::jsonb,
    jsonb_build_object('task_state', coalesce(p_ui_metadata->'task_state', '{}'::jsonb)),
    v_last_seq + 1
  );

  -- 6. Insert assistant message
  insert into public.copilot_messages(
    conversation_id, user_id, role, content, stadium_results, ui_metadata, message_sequence
  ) values (
    p_conversation_id, p_user_id, 'assistant', p_assistant_content,
    coalesce(p_stadium_results, '[]'::jsonb),
    coalesce(p_ui_metadata, '{}'::jsonb),
    v_last_seq + 2
  );

  -- 7. Snapshot version conflict resolution
  if v_current_snapshot is not null and v_current_snapshot ? 'conversation_state' then
    v_current_version := coalesce((v_current_snapshot->'conversation_state'->>'version')::int, 0);
  end if;

  if p_context_snapshot is not null and p_context_snapshot ? 'conversation_state' then
    v_incoming_version := coalesce((p_context_snapshot->'conversation_state'->>'version')::int, 0);
  end if;

  if v_current_version > v_incoming_version then
    v_final_snapshot := v_current_snapshot;
  else
    v_final_snapshot := coalesce(p_context_snapshot, '{}'::jsonb);
  end if;

  -- 8. Update conversation snapshot and mark initialized
  update public.copilot_conversations
  set updated_at = now(),
      context_snapshot = v_final_snapshot,
      is_initialized = true
  where id = p_conversation_id and user_id = p_user_id;

  return true;
end;
$function$
;

-- Function: pgmq_archive
CREATE OR REPLACE FUNCTION public.pgmq_archive(queue_name text, msg_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_archived boolean := true;
BEGIN
  IF auth.role() <> 'service_role' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
        AND role IN ('admin', 'co_founder', 'cofounder', 'super_admin')
    ) THEN
      RAISE EXCEPTION 'Access denied: service_role or admin required';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'pgmq') THEN
    BEGIN
      EXECUTE format('SELECT pgmq.archive(%L, %s)', queue_name, msg_id) INTO v_archived;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'pgmq.archive notice: %', SQLERRM;
      v_archived := false;
    END;
  END IF;

  RETURN COALESCE(v_archived, true);
END;
$function$
;

-- Function: pgmq_read
CREATE OR REPLACE FUNCTION public.pgmq_read(queue_name text, vt integer DEFAULT 30, qty integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
        AND role IN ('admin', 'co_founder', 'cofounder', 'super_admin')
    ) THEN
      RAISE EXCEPTION 'Access denied: service_role or admin required';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'pgmq') THEN
    BEGIN
      EXECUTE format(
        'SELECT COALESCE(jsonb_agg(to_jsonb(r)), ''[]''::jsonb) FROM pgmq.read(%L, %s, %s) r',
        queue_name, vt, qty
      ) INTO v_result;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'pgmq.read notice: %', SQLERRM;
      v_result := '[]'::jsonb;
    END;
  END IF;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$
;

-- Function: prepare_collective_booking_fields
CREATE OR REPLACE FUNCTION public.prepare_collective_booking_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_token text;
  v_code text;
  v_payment_method text;
BEGIN
  IF NEW.booking_type='open_join' THEN
    v_payment_method:=lower(trim(coalesce(NEW.payment_method,'')));

    IF v_payment_method NOT IN ('paymob','card','wallet','online') THEN
      RAISE EXCEPTION 'COLLECTIVE_REQUIRES_FULL_ONLINE_PAYMENT';
    END IF;

    NEW.is_private:=true;
    NEW.pending_user_ids:=ARRAY[]::text[];
    NEW.needs_deposit:=false;
    NEW.deposit_amount:=0;
    NEW.deposit_paid:=0;
    NEW.payment_method:='paymob';
    NEW.payment_status:=CASE WHEN NEW.status='confirmed' AND NEW.is_paid=true THEN 'paid' ELSE 'pending' END;
    NEW.is_paid:=COALESCE(NEW.is_paid,false);

    IF TG_OP='INSERT' THEN
      NEW.manual_player_count:=GREATEST(
        COALESCE(NEW.initial_players_count,NEW.current_players,1)-1,0
      );
    ELSE
      NEW.manual_player_count:=GREATEST(COALESCE(NEW.manual_player_count,0),0);
    END IF;

    IF NEW.collective_invite_token IS NULL OR btrim(NEW.collective_invite_token)='' THEN
      LOOP
        v_token:=encode(gen_random_bytes(18),'hex');
        EXIT WHEN NOT EXISTS(
          SELECT 1 FROM public.bookings b WHERE b.collective_invite_token=v_token
        );
      END LOOP;
      NEW.collective_invite_token:=v_token;
    END IF;

    IF NEW.collective_invite_code IS NULL OR btrim(NEW.collective_invite_code)='' THEN
      LOOP
        v_code:=upper(substr(encode(gen_random_bytes(8),'hex'),1,10));
        EXIT WHEN NOT EXISTS(
          SELECT 1 FROM public.bookings b WHERE b.collective_invite_code=v_code
        );
      END LOOP;
      NEW.collective_invite_code:=v_code;
    END IF;

    NEW.collective_invite_active:=(NEW.status='confirmed' AND (NEW.payment_status='paid' OR NEW.payment_status='partially_paid'));

    NEW.current_players:=
      COALESCE(cardinality(COALESCE(NEW.joined_user_ids,ARRAY[]::uuid[])),0)
      + COALESCE(NEW.manual_player_count,0);

    IF TG_OP='UPDATE'
       AND COALESCE(current_setting('vsp.system_override',true),'')<>'true'
       AND (
         NEW.joined_user_ids IS DISTINCT FROM OLD.joined_user_ids OR
         NEW.manual_player_count IS DISTINCT FROM OLD.manual_player_count OR
         NEW.current_players IS DISTINCT FROM OLD.current_players OR
         NEW.collective_invite_token IS DISTINCT FROM OLD.collective_invite_token OR
         NEW.collective_invite_code IS DISTINCT FROM OLD.collective_invite_code
       ) THEN
      RAISE EXCEPTION 'COLLECTIVE_FIELDS_ARE_SERVER_MANAGED';
    END IF;
  ELSE
    NEW.manual_player_count:=0;
    NEW.collective_invite_token:=NULL;
    NEW.collective_invite_code:=NULL;
    NEW.collective_invite_active:=false;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: prepare_team_league_payment
CREATE OR REPLACE FUNCTION public.prepare_team_league_payment(p_championship_id uuid, p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_captain UUID;
  v_status TEXT;
  v_joined TEXT[];
  v_paid TEXT[];
  v_entry_fee NUMERIC;
  v_existing RECORD;
  v_reference TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT t.captain_id INTO v_captain
  FROM public.teams t
  WHERE t.id = p_team_id;

  IF v_captain IS NULL OR v_captain <> v_uid THEN
    RAISE EXCEPTION 'فقط قائد الفريق يستطيع الدفع';
  END IF;

  SELECT c.status, coalesce(c.joined_teams, '{}'::TEXT[]), coalesce(c.paid_teams, '{}'::TEXT[]), c.entry_fee
    INTO v_status, v_joined, v_paid, v_entry_fee
  FROM public.championships c
  WHERE c.id = p_championship_id
    AND c.template_type = 'team_league'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الدوري غير موجود';
  END IF;

  IF v_status <> 'open' THEN
    RAISE EXCEPTION 'الدوري لم يعد مفتوحاً للتسجيل';
  END IF;

  IF v_entry_fee IS NULL OR v_entry_fee <= 0 THEN
    RAISE EXCEPTION 'رسوم اشتراك الدوري غير محددة أو غير صالحة';
  END IF;

  IF NOT (p_team_id::TEXT = ANY(v_joined)) THEN
    RAISE EXCEPTION 'الفريق غير مسجل في هذا الدوري';
  END IF;

  IF p_team_id::TEXT = ANY(v_paid) THEN
    RAISE EXCEPTION 'الفريق مدفوع بالفعل';
  END IF;

  SELECT *
    INTO v_existing
  FROM public.team_league_payments
  WHERE championship_id = p_championship_id
    AND team_id = p_team_id
    AND payment_status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'payment_required', true,
      'payment_reference', v_existing.order_reference,
      'amount', v_existing.amount
    );
  END IF;

  v_reference := 'LEAGUE_' || p_championship_id::TEXT || '_' ||
                 p_team_id::TEXT || '_' ||
                 FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;

  INSERT INTO public.team_league_payments(
    championship_id, team_id, user_id, amount, order_reference
  )
  VALUES (
    p_championship_id, p_team_id, v_uid, v_entry_fee, v_reference
  );

  RETURN jsonb_build_object(
    'success', true,
    'payment_required', true,
    'payment_reference', v_reference,
    'amount', v_entry_fee
  );
END;
$function$
;

-- Function: prepare_tournament_bracket
CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket(p_championship_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.championships c
      LEFT JOIN public.users u ON u.id = auth.uid()
      WHERE c.id = p_championship_id
        AND (c.owner_id = auth.uid() OR u.role IN ('admin', 'co_founder', 'super_admin', 'cofounder'))
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only the championship organizer or platform administrator can prepare brackets.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;
END;
$function$
;

-- Function: prepare_tournament_bracket_atomic
CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    IF coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized');
    END IF;
  END IF;
  RETURN public.generate_tournament_bracket_atomic(p_championship_id);
END;
$function$
;

-- Function: prevent_late_cancellation
CREATE OR REPLACE FUNCTION public.prevent_late_cancellation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_is_owner boolean := false;
  v_cutoff numeric := 6;
  v_grace numeric := 20;
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    v_is_owner := auth.uid() IS NOT NULL AND auth.uid() = OLD.owner_id;

    IF auth.uid() IS NOT NULL THEN
      SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    END IF;

    IF NOT v_is_owner
       AND coalesce(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin','service_role')
       AND current_user NOT IN ('postgres','service_role') THEN

      IF OLD.status <> 'pending' THEN
        IF now() > OLD.start_time - ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id=1) * interval '1 hour')
           AND now() > OLD.created_at + ((SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id=1) * interval '1 minute')
        THEN
          RAISE EXCEPTION 'cannot_cancel_within_6_hours';
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: prevent_unauthorized_role_change
CREATE OR REPLACE FUNCTION public.prevent_unauthorized_role_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- إذا تمت محاولة تغيير الرتبة (role)
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        -- منع التعديل إلا إذا تم الاستدعاء بصلاحيات النظام الإداري (SECURITY DEFINER / service_role)
        -- أو إبقاء الرتبة القديمة كما هي تلقائياً وإلغاء محاولة الترقية
        NEW.role := OLD.role;
    END IF;
    RETURN NEW;
END;
$function$
;

-- Function: process_paymob_webhook
CREATE OR REPLACE FUNCTION public.process_paymob_webhook(p_booking_id text, p_txn_id text, p_order_id text, p_success boolean, p_signature_verified boolean, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_clean_id TEXT;
  v_existing_booking RECORD;
  v_already_processed BOOLEAN;
  v_caller_role TEXT;
  v_deposit_paid NUMERIC := 0;
  v_payment_status TEXT;
  v_is_paid BOOLEAN;
  v_is_deposit_paid BOOLEAN;
BEGIN
  -- 🔒 STRICT SECURITY CHECK: Only service_role or admin can call this webhook processor
  IF auth.role() != 'service_role' THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder') THEN
      RAISE EXCEPTION 'Security Alert: Unauthorized access to process_paymob_webhook.';
    END IF;
  END IF;

  -- 🔒 STRICT SIGNATURE CHECK: Must be verified by Edge Function HMAC
  IF NOT p_signature_verified THEN
    RAISE EXCEPTION 'Security Alert: Unverified Paymob signature rejected.';
  END IF;

  v_clean_id := split_part(p_booking_id, '_', 1);

  -- Log into webhook_logs
  INSERT INTO public.webhook_logs (
    provider, event_type, txn_id, order_id, booking_id, payload, signature_verified, status
  )
  VALUES (
    'paymob',
    CASE WHEN p_success THEN 'payment_success' ELSE 'payment_failed' END,
    p_txn_id, p_order_id, 
    CASE WHEN v_clean_id ~ '^[0-9a-fA-F-]{36}$' THEN v_clean_id::uuid ELSE NULL END, 
    p_payload, p_signature_verified,
    CASE WHEN p_signature_verified THEN 'processed' ELSE 'unverified' END
  );

  -- Idempotency check: ignore duplicate webhooks for confirmed or already settled bookings
  IF p_txn_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.bookings
      WHERE paymob_txn_id = p_txn_id
        AND (status = 'confirmed' OR payment_status IN ('paid', 'partially_paid'))
    ) INTO v_already_processed;

    IF v_already_processed THEN
      RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'duplicate_webhook_ignored',
        'idempotent', TRUE,
        'booking_id', v_clean_id
      );
    END IF;
  END IF;

  SELECT * INTO v_existing_booking
  FROM public.bookings
  WHERE id::text = v_clean_id
  FOR UPDATE;

  IF v_existing_booking.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'booking_not_found',
      'message', 'No booking found matching the provided ID.'
    );
  END IF;

  IF p_success THEN
    -- 🔒 RACE CONDITION & LOCK EXPOSURE GUARD:
    -- If booking was cancelled (e.g. timeout / admin cancel), or another user confirmed the slot:
    IF EXISTS (
      SELECT 1 FROM public.bookings
      WHERE stadium_id = v_existing_booking.stadium_id
        AND id <> v_existing_booking.id
        AND status = 'confirmed'
        AND start_time < v_existing_booking.end_time
        AND end_time > v_existing_booking.start_time
    ) THEN
      -- Slot is occupied by another confirmed user! Cannot hijack the slot.
      UPDATE public.bookings
      SET
        status = 'cancelled',
        payment_status = 'refund_pending',
        cancellation_reason = 'Slot was confirmed by another player after lock expired. Payment queued for refund.',
        payment_transaction_id = 'PAYMOB_' || p_txn_id,
        paymob_txn_id = p_txn_id,
        paymob_order_id = p_order_id,
        webhook_processed_at = NOW(),
        webhook_verified = TRUE,
        updated_at = NOW()
      WHERE id = v_existing_booking.id;

      RETURN jsonb_build_object(
        'success', FALSE,
        'status', 'cancelled_conflict',
        'error', 'SLOT_OCCUPIED',
        'message', 'Slot was confirmed by another player. Booking cancelled and queued for refund.',
        'booking_id', v_clean_id
      );
    END IF;

    -- If booking was already cancelled (e.g. manual user cancel before late webhook arrived)
    IF v_existing_booking.status = 'cancelled' THEN
      UPDATE public.bookings
      SET
        payment_status = 'refund_pending',
        cancellation_reason = COALESCE(cancellation_reason, 'Booking cancelled prior to payment confirmation. Refund pending.'),
        payment_transaction_id = 'PAYMOB_' || p_txn_id,
        paymob_txn_id = p_txn_id,
        paymob_order_id = p_order_id,
        webhook_processed_at = NOW(),
        webhook_verified = TRUE,
        updated_at = NOW()
      WHERE id = v_existing_booking.id;

      RETURN jsonb_build_object(
        'success', FALSE,
        'status', 'cancelled',
        'error', 'BOOKING_ALREADY_CANCELLED',
        'message', 'Booking was already cancelled. Payment marked for refund.',
        'booking_id', v_clean_id
      );
    END IF;

    -- Differentiate Full Payment vs Deposit Payment
    IF v_existing_booking.needs_deposit AND COALESCE(v_existing_booking.deposit_amount, 0) > 0
       AND COALESCE(v_existing_booking.deposit_amount, 0) < v_existing_booking.total_price THEN
      v_deposit_paid := v_existing_booking.deposit_amount;
      v_payment_status := 'partially_paid';
      v_is_paid := false;
      v_is_deposit_paid := true;
    ELSE
      v_deposit_paid := COALESCE(v_existing_booking.deposit_paid, v_existing_booking.total_price);
      v_payment_status := 'paid';
      v_is_paid := true;
      v_is_deposit_paid := true;
    END IF;

    -- Flag internal payment call for triggers
    PERFORM set_config('vsp.internal_payment_call', 'true', true);

    UPDATE public.bookings
    SET
      status = 'confirmed',
      is_paid = v_is_paid,
      payment_status = v_payment_status,
      is_deposit_paid = v_is_deposit_paid,
      deposit_paid = v_deposit_paid,
      payment_transaction_id = 'PAYMOB_' || p_txn_id,
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      challenge_status = CASE WHEN booking_type = 'challenge' THEN 'confirmed' ELSE challenge_status END,
      webhook_processed_at = NOW(),
      webhook_verified = TRUE,
      updated_at = NOW()
    WHERE id::text = v_clean_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'status', 'confirmed',
      'payment_status', v_payment_status,
      'deposit_paid', v_deposit_paid,
      'is_deposit_paid', v_is_deposit_paid,
      'booking_id', v_clean_id
    );
  ELSE
    UPDATE public.bookings
    SET
      status = 'cancelled',
      payment_status = 'failed',
      cancellation_reason = 'Paymob electronic payment transaction failed',
      updated_at = NOW()
    WHERE id::text = v_clean_id;

    RETURN jsonb_build_object(
      'success', FALSE,
      'status', 'failed',
      'booking_id', v_clean_id
    );
  END IF;
END;
$function$
;

-- Function: protect_booking_payment_fields
CREATE OR REPLACE FUNCTION public.protect_booking_payment_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  is_admin BOOLEAN := FALSE;
BEGIN
  SELECT (role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))
  INTO is_admin
  FROM public.users
  WHERE id = auth.uid();

  -- السماح للسيرفر (webhook) بالمرور بحرية
  IF current_user IN ('postgres', 'service_role') THEN
    RETURN NEW;
  END IF;

  IF NOT COALESCE(is_admin, FALSE) THEN
    -- منع اللاعب من تأكيد الدفع مباشرة
    IF (NEW.is_paid IS TRUE AND OLD.is_paid IS FALSE)
      AND (NEW.payment_method = 'paymob')
      AND (OLD.payment_status = 'pending') THEN
        IF auth.uid() IS NOT NULL AND auth.uid() = OLD.created_by_user_id THEN
          RAISE EXCEPTION 'Access Denied: Payment confirmation must go through the payment gateway webhook.';
        END IF;
    END IF;

    -- منع تقليل السعر الإجمالي
    IF NEW.total_price < OLD.total_price AND (OLD.payment_transaction_id NOT LIKE 'MANUAL%') THEN
      RAISE EXCEPTION 'Access Denied: You cannot reduce the booking total price.';
    END IF;

    -- منع اللاعب من تعديل refund fields مباشرة
    IF NEW.refund_transaction_id IS DISTINCT FROM OLD.refund_transaction_id
      AND OLD.refund_transaction_id IS NOT NULL THEN
        RAISE EXCEPTION 'Security Alert: Refund transaction ID cannot be modified after being set.';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: protect_booking_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_booking_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_admin boolean := false;
BEGIN
  IF COALESCE(auth.role(), '') = 'service_role'
     OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin'))
  THEN RETURN NEW; END IF;
  IF current_setting('vsp.system_override', true) = 'true'
     OR current_setting('vsp.internal_payment_call', true) = 'true'
  THEN RETURN NEW; END IF;
  IF auth.uid() IS NOT NULL THEN
    SELECT (role IN ('admin', 'co_founder', 'cofounder', 'super_admin'))
    INTO v_is_admin FROM public.users WHERE id = auth.uid();
  END IF;
  IF COALESCE(v_is_admin, false) THEN RETURN NEW; END IF;
  IF OLD.stadium_id IS DISTINCT FROM NEW.stadium_id OR OLD.owner_id IS DISTINCT FROM NEW.owner_id
     OR OLD.user_id IS DISTINCT FROM NEW.user_id OR OLD.created_by_user_id IS DISTINCT FROM NEW.created_by_user_id
     OR OLD.start_time IS DISTINCT FROM NEW.start_time OR OLD.end_time IS DISTINCT FROM NEW.end_time
     OR OLD.booking_type IS DISTINCT FROM NEW.booking_type
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Booking core identity is server-authoritative.'
    USING errcode='42501', detail='UNAUTHORIZED_BOOKING_CORE_UPDATE'; END IF;
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Booking status must be changed via atomic RPCs.'
      USING errcode='42501', detail='UNAUTHORIZED_STATUS_UPDATE'; END IF;
  IF OLD.payment_status IS DISTINCT FROM NEW.payment_status OR OLD.is_paid IS DISTINCT FROM NEW.is_paid
     OR OLD.is_deposit_paid IS DISTINCT FROM NEW.is_deposit_paid OR OLD.deposit_paid IS DISTINCT FROM NEW.deposit_paid
     OR OLD.deposit_amount IS DISTINCT FROM NEW.deposit_amount OR OLD.payment_method IS DISTINCT FROM NEW.payment_method
     OR OLD.payment_transaction_id IS DISTINCT FROM NEW.payment_transaction_id
     OR OLD.paymob_txn_id IS DISTINCT FROM NEW.paymob_txn_id OR OLD.paymob_order_id IS DISTINCT FROM NEW.paymob_order_id
     OR OLD.paymob_transaction_id IS DISTINCT FROM NEW.paymob_transaction_id
     OR OLD.webhook_verified IS DISTINCT FROM NEW.webhook_verified
     OR OLD.webhook_processed_at IS DISTINCT FROM NEW.webhook_processed_at
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Payment state is managed by payment workflows only.'
    USING errcode='42501', detail='UNAUTHORIZED_PAYMENT_STATE_UPDATE'; END IF;
  IF OLD.total_price IS DISTINCT FROM NEW.total_price OR OLD.platform_fee IS DISTINCT FROM NEW.platform_fee
     OR OLD.vsp_commission IS DISTINCT FROM NEW.vsp_commission OR OLD.gateway_fee IS DISTINCT FROM NEW.gateway_fee
     OR OLD.refund_amount IS DISTINCT FROM NEW.refund_amount OR OLD.refund_transaction_id IS DISTINCT FROM NEW.refund_transaction_id
     OR OLD.refunded_at IS DISTINCT FROM NEW.refunded_at OR OLD.refund_payment_method IS DISTINCT FROM NEW.refund_payment_method
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Financial booking fields are immutable from the client.'
    USING errcode='42501', detail='UNAUTHORIZED_FINANCIAL_UPDATE'; END IF;
  IF OLD.cancelled_at IS DISTINCT FROM NEW.cancelled_at OR OLD.cancellation_reason IS DISTINCT FROM NEW.cancellation_reason
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Cancellation records are server-authoritative.'
    USING errcode='42501', detail='UNAUTHORIZED_CANCELLATION_UPDATE'; END IF;
  IF OLD.joined_user_ids IS DISTINCT FROM NEW.joined_user_ids OR OLD.current_players IS DISTINCT FROM NEW.current_players
     OR OLD.initial_players_count IS DISTINCT FROM NEW.initial_players_count
     OR OLD.total_field_capacity IS DISTINCT FROM NEW.total_field_capacity
     OR OLD.pending_user_ids IS DISTINCT FROM NEW.pending_user_ids
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Player list must be managed via join/leave RPCs.'
    USING errcode='42501', detail='UNAUTHORIZED_PLAYER_LIST_UPDATE'; END IF;
  IF OLD.player_team_id IS DISTINCT FROM NEW.player_team_id OR OLD.opponent_team_id IS DISTINCT FROM NEW.opponent_team_id
     OR OLD.challenge_status IS DISTINCT FROM NEW.challenge_status
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Challenge team fields are server-authoritative.'
    USING errcode='42501', detail='UNAUTHORIZED_CHALLENGE_TEAM_UPDATE'; END IF;
  IF OLD.match_result_status IS DISTINCT FROM NEW.match_result_status
     OR OLD.final_outcome IS DISTINCT FROM NEW.final_outcome OR OLD.pending_outcome IS DISTINCT FROM NEW.pending_outcome
     OR OLD.result_submitted_by_team_id IS DISTINCT FROM NEW.result_submitted_by_team_id
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Match result fields must be submitted via result RPCs.'
    USING errcode='42501', detail='UNAUTHORIZED_RESULT_UPDATE'; END IF;
  RETURN NEW;
END;
$function$
;

-- Function: protect_championship_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_championship_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role      TEXT;
  v_has_participants BOOLEAN := false;
  v_has_fixtures     BOOLEAN := false;
BEGIN
  IF current_user IN ('postgres','service_role') THEN RETURN NEW; END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin','co_founder','super_admin','cofounder') THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.is_approved, false) = true THEN
      RAISE EXCEPTION 'Security Alert: Non-admin users cannot create pre-approved championships.';
    END IF;
    IF COALESCE(NEW.creation_fee_paid, false) = true THEN
      RAISE EXCEPTION 'Security Alert: Creation fee status is server-authoritative.';
    END IF;
    RETURN NEW;
  END IF;

  v_has_participants := (
    cardinality(COALESCE(OLD.paid_teams,   ARRAY[]::TEXT[])) > 0 OR
    cardinality(COALESCE(OLD.joined_teams, ARRAY[]::TEXT[])) > 0 OR
    OLD.registration_locked_at IS NOT NULL
  );

  SELECT EXISTS(
    SELECT 1 FROM public.tournament_matches WHERE championship_id = OLD.id LIMIT 1
  ) INTO v_has_fixtures;

  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved OR
     NEW.champion_team_id IS DISTINCT FROM OLD.champion_team_id OR
     NEW.winner_team_id IS DISTINCT FROM OLD.winner_team_id OR
     NEW.champion_user_id IS DISTINCT FROM OLD.champion_user_id OR
     NEW.paid_teams IS DISTINCT FROM OLD.paid_teams OR
     NEW.joined_teams IS DISTINCT FROM OLD.joined_teams OR
     NEW.prize_pool IS DISTINCT FROM OLD.prize_pool OR
     NEW.creation_fee_paid IS DISTINCT FROM OLD.creation_fee_paid OR
     NEW.creation_payment_id IS DISTINCT FROM OLD.creation_payment_id OR
     NEW.prize_delivered IS DISTINCT FROM OLD.prize_delivered OR
     NEW.prize_delivered_at IS DISTINCT FROM OLD.prize_delivered_at OR
     NEW.prize_delivered_by IS DISTINCT FROM OLD.prize_delivered_by OR
     NEW.prize_delivery_notes IS DISTINCT FROM OLD.prize_delivery_notes OR
     NEW.registration_locked_at IS DISTINCT FROM OLD.registration_locked_at THEN
    RAISE EXCEPTION 'Security Alert: Championship financial, roster, approval and result fields are server-authoritative.';
  END IF;

  IF (v_has_participants OR v_has_fixtures) AND (
     NEW.entry_fee IS DISTINCT FROM OLD.entry_fee OR
     NEW.grand_prize IS DISTINCT FROM OLD.grand_prize OR
     NEW.max_teams IS DISTINCT FROM OLD.max_teams OR
     NEW.min_players_per_team IS DISTINCT FROM OLD.min_players_per_team OR
     NEW.max_players_per_team IS DISTINCT FROM OLD.max_players_per_team OR
     NEW.type IS DISTINCT FROM OLD.type OR
     NEW.number_of_groups IS DISTINCT FROM OLD.number_of_groups OR
     NEW.qualifying_per_group IS DISTINCT FROM OLD.qualifying_per_group OR
     NEW.is_two_legs IS DISTINCT FROM OLD.is_two_legs OR
     NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth OR
     NEW.winning_points IS DISTINCT FROM OLD.winning_points OR
     NEW.draw_points IS DISTINCT FROM OLD.draw_points OR
     NEW.loss_points IS DISTINCT FROM OLD.loss_points
  ) THEN
    RAISE EXCEPTION 'Security Alert: Championship structure cannot change after registration or fixture generation. Fixtures exist: %', v_has_fixtures;
  END IF;

  IF OLD.template_type = 'team_league' AND (
     NEW.entry_fee IS DISTINCT FROM OLD.entry_fee OR
     NEW.max_teams IS DISTINCT FROM OLD.max_teams OR
     NEW.winning_points IS DISTINCT FROM OLD.winning_points OR
     NEW.draw_points IS DISTINCT FROM OLD.draw_points OR
     NEW.loss_points IS DISTINCT FROM OLD.loss_points OR
     NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth OR
     NEW.number_of_groups IS DISTINCT FROM OLD.number_of_groups OR
     NEW.is_two_legs IS DISTINCT FROM OLD.is_two_legs OR
     NEW.grand_prize IS DISTINCT FROM OLD.grand_prize
  ) THEN
    RAISE EXCEPTION 'Security Alert: Team League structure is always fixed — cannot override VSP rules.';
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: protect_completed_match_scores
CREATE OR REPLACE FUNCTION public.protect_completed_match_scores()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ_status text;
BEGIN
  -- Allow service_role or admin
  IF (auth.jwt()->>'role' = 'service_role') OR 
     (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder'))) THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_champ_status FROM public.championships WHERE id = OLD.championship_id;

  IF (v_champ_status = 'completed') THEN
    RAISE EXCEPTION 'cannot_modify_completed_championship_match';
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: protect_stadium_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_stadium_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_caller_role text;
begin
  if current_user in ('postgres','service_role') then return new; end if;

  select role into v_caller_role from public.users where id=auth.uid();
  if v_caller_role in ('admin','co_founder','cofounder','super_admin') then return new; end if;

  if new.is_verified is distinct from old.is_verified then
    if new.is_verified=true then
      raise exception 'Security Alert: Stadium verification requires admin approval.';
    else
      -- Owner may request a re-review by un-verifying, but cannot approve it.
      new.is_verified:=false;
    end if;
  end if;

  if new.is_blocked is distinct from old.is_blocked then
    raise exception 'Security Alert: Stadium blocking state requires admin approval.';
  end if;

  if new.rating is distinct from old.rating then
    new.rating:=old.rating;
  end if;

  if new.reviews_count is distinct from old.reviews_count then
    new.reviews_count:=old.reviews_count;
  end if;

  if new.is_featured is distinct from old.is_featured and new.is_featured=true then
    raise exception 'Security Alert: Featuring a stadium requires admin approval.';
  end if;

  return new;
end;
$function$
;

-- Function: protect_team_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_team_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_caller_role text;
begin
  if current_user in ('postgres','service_role') then return new; end if;

  select role into v_caller_role from public.users where id=auth.uid();
  if v_caller_role in ('admin','co_founder','cofounder','super_admin') then return new; end if;

  if new.captain_id is distinct from old.captain_id then
    raise exception 'Security Alert: Team captain changes require the official team-management workflow.';
  end if;

  if new.is_verified is distinct from old.is_verified and new.is_verified=true then
    raise exception 'Security Alert: Team verification requires admin approval.';
  end if;

  if new.is_blocked is distinct from old.is_blocked and new.is_blocked=false then
    raise exception 'Security Alert: Team unblocking requires admin approval.';
  end if;

  new.points:=old.points;
  new.wins:=old.wins;
  new.draws:=old.draws;
  new.losses:=old.losses;
  new.matches_played:=old.matches_played;
  new.current_winning_streak:=old.current_winning_streak;
  new.championships_won:=old.championships_won;
  new.elo_rating:=old.elo_rating;
  new.attendance_score:=old.attendance_score;
  new.verified_badge:=old.verified_badge;
  new.is_official:=old.is_official;
  new.has_1v1_champion:=old.has_1v1_champion;
  new.beaten_opponents:=old.beaten_opponents;
  new.played_opponents:=old.played_opponents;
  new.unlocked_badges:=old.unlocked_badges;
  new.last_reset_year:=old.last_reset_year;
  return new;
end;
$function$
;

-- Function: protect_user_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ BEGIN RETURN NEW; END; $function$
;

-- Function: protect_user_verification_fields
CREATE OR REPLACE FUNCTION public.protect_user_verification_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ BEGIN RETURN NEW; END; $function$
;

-- Function: publish_1v1_final_standings_atomic
CREATE OR REPLACE FUNCTION public.publish_1v1_final_standings_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caller_role text; v_champ record; v_champion_user_id uuid; v_champion_name text; v_champion_team_id uuid; v_prize numeric;
BEGIN
IF coalesce(auth.role(),'') <> 'service_role' AND current_user <> 'postgres' THEN SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid(); IF coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','غير مصرح: فقط الأدمن يمكنه اعتماد ونشر النتائج.'); END IF; END IF;
SELECT * INTO v_champ FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id FOR UPDATE;
IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','البطولة غير موجودة.'); END IF;
v_champion_user_id:=v_champ.champion_user_id;
IF v_champion_user_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','يجب اعتماد بطل البطولة أولاً. الترتيب بالنقاط لا يحدد البطل تلقائياً.'); END IF;
SELECT user_id,player_name INTO v_champion_user_id,v_champion_name FROM public.vsp_1v1_tournament_players WHERE tournament_id=p_tournament_id AND user_id=v_champion_user_id AND payment_status='paid' LIMIT 1;
IF v_champion_user_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','البطل المختار يجب أن يكون لاعباً مسدداً ومسجلاً في البطولة.'); END IF;
UPDATE public.vsp_1v1_tournaments SET status='archived' WHERE governorate=v_champ.governorate AND status IN ('completed','published') AND id<>p_tournament_id;
UPDATE public.vsp_1v1_tournaments SET status='completed',published_at=coalesce(published_at,timezone('utc',now())),champion_user_id=v_champion_user_id,updated_at=timezone('utc',now()) WHERE id=p_tournament_id;
v_prize:=coalesce(v_champ.prize_amount,v_champ.prize_pool,0);
IF NOT EXISTS (SELECT 1 FROM public.player_trophies WHERE user_id=v_champion_user_id AND tournament_1v1_id=p_tournament_id) THEN
 INSERT INTO public.player_trophies(id,user_id,tournament_1v1_id,title,prize_won,created_at) VALUES(gen_random_uuid(),v_champion_user_id,p_tournament_id,'بطل تحدي 1v1 - '||coalesce(v_champ.name,'VSP 1v1')||' ('||coalesce(v_champ.governorate,'')||')',v_prize,timezone('utc',now()));
END IF;
SELECT team_id INTO v_champion_team_id FROM public.team_members WHERE user_id=v_champion_user_id LIMIT 1;
IF v_champion_team_id IS NOT NULL THEN UPDATE public.teams SET has_1v1_champion=true WHERE id=v_champion_team_id; END IF;
RETURN jsonb_build_object('success',true,'tournament_id',p_tournament_id,'governorate',v_champ.governorate,'champion_user_id',v_champion_user_id,'champion_name',v_champion_name,'champion_team_id',v_champion_team_id,'status','completed');
END;$function$
;

-- Function: publish_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.publish_1v1_tournament_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_role TEXT;
    v_champ RECORD;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    SELECT * INTO v_champ FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
    END IF;

    -- Archive whatever was previously published IN THE SAME GOVERNORATE ONLY
    UPDATE public.vsp_1v1_tournaments
    SET status = 'archived'
    WHERE governorate = v_champ.governorate AND status = 'published' AND id != p_tournament_id;

    -- Publish the target tournament
    UPDATE public.vsp_1v1_tournaments
    SET status = 'published', published_at = timezone('utc'::text, now())
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('success', true, 'tournament_id', p_tournament_id, 'governorate', v_champ.governorate);
END;
$function$
;

-- Function: purge_aswan_seed_data
CREATE OR REPLACE FUNCTION public.purge_aswan_seed_data()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_del_bookings int := 0;
    v_del_matches int := 0;
    v_del_champs int := 0;
    v_del_1v1_tp int := 0;
    v_del_1v1_t int := 0;
    v_del_1v1_p int := 0;
    v_del_trophies int := 0;
    v_del_tm int := 0;
    v_del_h2h int := 0;
    v_del_teams int := 0;
    v_del_stadiums int := 0;
    v_del_auth_users int := 0;
    v_del_public_users int := 0;
BEGIN
    -- 1. Delete booking players and bookings
    DELETE FROM public.booking_players
    WHERE booking_id IN (
        SELECT id FROM public.bookings
        WHERE stadium_id >= 'b1000000-0000-0000-0000-000000000001'::uuid 
          AND stadium_id <= 'b1000000-0000-0000-0000-000000000010'::uuid
           OR id = 'f1000000-0000-0000-0000-000000000001'::uuid
    );

    WITH deleted AS (
        DELETE FROM public.bookings
        WHERE stadium_id >= 'b1000000-0000-0000-0000-000000000001'::uuid 
          AND stadium_id <= 'b1000000-0000-0000-0000-000000000010'::uuid
           OR id = 'f1000000-0000-0000-0000-000000000001'::uuid
           OR created_by_user_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_bookings FROM deleted;

    -- 2. Delete tournament matches & championships
    WITH del_m AS (
        DELETE FROM public.tournament_matches
        WHERE championship_id = 'd1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_matches FROM del_m;

    WITH del_c AS (
        DELETE FROM public.championships
        WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_champs FROM del_c;

    -- 3. Delete 1v1 data and trophies
    WITH del_tp AS (
        DELETE FROM public.vsp_1v1_tournament_players
        WHERE tournament_id = 'e1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_1v1_tp FROM del_tp;

    WITH del_t AS (
        DELETE FROM public.vsp_1v1_tournaments
        WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_1v1_t FROM del_t;

    WITH del_p AS (
        DELETE FROM public.vsp_1vs1_players
        WHERE id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_1v1_p FROM del_p;

    WITH del_tr AS (
        DELETE FROM public.player_trophies
        WHERE user_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_trophies FROM del_tr;

    -- 4. Delete team head to head and matchup results
    WITH del_h2h_rows AS (
        DELETE FROM public.team_head_to_head
        WHERE team_a_id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND team_a_id <= 'c1000000-0000-0000-0000-000000000010'::uuid
           OR team_b_id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND team_b_id <= 'c1000000-0000-0000-0000-000000000010'::uuid
        RETURNING team_a_id
    )
    SELECT COUNT(*) INTO v_del_h2h FROM del_h2h_rows;

    -- 5. Delete team members and teams
    WITH del_tm_rows AS (
        DELETE FROM public.team_members
        WHERE team_id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND team_id <= 'c1000000-0000-0000-0000-000000000010'::uuid
           OR user_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING team_id
    )
    SELECT COUNT(*) INTO v_del_tm FROM del_tm_rows;

    WITH del_teams_rows AS (
        DELETE FROM public.teams
        WHERE id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND id <= 'c1000000-0000-0000-0000-000000000010'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_teams FROM del_teams_rows;

    -- 6. Delete stadiums
    WITH del_s_rows AS (
        DELETE FROM public.stadiums
        WHERE id >= 'b1000000-0000-0000-0000-000000000001'::uuid 
          AND id <= 'b1000000-0000-0000-0000-000000000010'::uuid
           OR owner_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_stadiums FROM del_s_rows;

    -- 7. Delete users from auth.users (cascades automatically to public.users via users_id_fkey)
    WITH del_auth_rows AS (
        DELETE FROM auth.users
        WHERE email LIKE '%@aswan.seed.vsp.app'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_auth_users FROM del_auth_rows;

    -- Fallback cleanup on public.users just in case
    WITH del_pub_rows AS (
        DELETE FROM public.users
        WHERE email LIKE '%@aswan.seed.vsp.app'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_public_users FROM del_pub_rows;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_auth_users', v_del_auth_users,
        'deleted_public_users', v_del_public_users,
        'deleted_stadiums', v_del_stadiums,
        'deleted_teams', v_del_teams,
        'deleted_team_members', v_del_tm,
        'deleted_team_h2h', v_del_h2h,
        'deleted_championships', v_del_champs,
        'deleted_tournament_matches', v_del_matches,
        'deleted_1v1_tournament_players', v_del_1v1_tp,
        'deleted_1v1_tournaments', v_del_1v1_t,
        'deleted_1vs1_players', v_del_1v1_p,
        'deleted_trophies', v_del_trophies,
        'deleted_bookings', v_del_bookings
    );
END;
$function$
;

-- Function: recalculate_stadium_rating
CREATE OR REPLACE FUNCTION public.recalculate_stadium_rating()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium_id uuid;
BEGIN
  -- تحديد الـ stadium_id بناءً على نوع العملية (إدخال، تعديل، حذف)
  IF (TG_OP = 'DELETE') THEN
    v_stadium_id := OLD.stadium_id;
  ELSE
    v_stadium_id := NEW.stadium_id;
  END IF;

  -- تحديث التقييم الكلي وعدد المقيّمين تلقائياً في جدول الملاعب
  UPDATE public.stadiums
  SET 
    rating = COALESCE((SELECT AVG(rating) FROM public.reviews WHERE stadium_id = v_stadium_id), 0.0),
    reviews_count = (SELECT COUNT(*) FROM public.reviews WHERE stadium_id = v_stadium_id)
  WHERE id = v_stadium_id;

  RETURN NULL;
END;
$function$
;

-- Function: reconcile_cancellation_refund_queue
CREATE OR REPLACE FUNCTION public.reconcile_cancellation_refund_queue()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_url TEXT := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/process_tournament_refund';
  v_secret TEXT;
  v_has_pending BOOLEAN := false;
BEGIN
  -- Check regular cancellation queue
  SELECT EXISTS (
    SELECT 1 
    FROM public.cancellation_refund_queue
    WHERE status = 'pending'
       OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
       OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ) INTO v_has_pending;

  -- Check 1v1 cancellation queue if regular has none
  IF NOT v_has_pending THEN
    SELECT EXISTS (
      SELECT 1 
      FROM public.vsp_1v1_cancellation_refund_queue
      WHERE status = 'pending'
         OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
         OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
    ) INTO v_has_pending;
  END IF;

  IF NOT v_has_pending THEN
    RETURN;
  END IF;

  SELECT secret INTO v_secret
  FROM public.internal_function_secrets
  WHERE name = 'refund_worker'
  LIMIT 1;

  IF coalesce(v_secret, '') = '' THEN
    RAISE WARNING 'Dedicated refund_worker secret missing in reconcile cron job; skipping push.';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('action', 'process_queue')
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'reconcile_cancellation_refund_queue error: %', SQLERRM;
END;
$function$
;

-- Function: reconcile_daily_elo_ratings
CREATE OR REPLACE FUNCTION public.reconcile_daily_elo_ratings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    r RECORD;
    v_home_rating INT;
    v_away_rating INT;
    v_outcome DOUBLE PRECISION; -- تم التعديل: فصل الكلمتين بمسافة
    v_k_factor INT := 32;
    v_expected_home DOUBLE PRECISION; -- تم التعديل: فصل الكلمتين بمسافة
    v_expected_away DOUBLE PRECISION; -- تم التعديل: فصل الكلمتين بمسافة
    v_new_home INT;
    v_new_away INT;
BEGIN
    -- جلب جميع مباريات التحدي المؤكدة التي لم يتم احتساب نقاطها بعد
    FOR r IN 
        SELECT id, player_team_id, opponent_team_id, final_outcome 
        FROM bookings 
        WHERE booking_type = 'challenge' 
          AND match_result_status = 'confirmed' 
          AND elo_processed = false
    LOOP
        -- جلب النقاط الحالية للفريقين
        SELECT points INTO v_home_rating FROM teams WHERE id = r.player_team_id;
        SELECT points INTO v_away_rating FROM teams WHERE id = r.opponent_team_id;

        IF v_home_rating IS NOT NULL AND v_away_rating IS NOT NULL THEN
            -- تحديد النتيجة رقمياً
            IF r.final_outcome = 'homeWin' THEN
                v_outcome := 1.0;
            ELSIF r.final_outcome = 'draw' THEN
                v_outcome := 0.5;
            ELSE
                v_outcome := 0.0;
            END IF;

            -- حساب الاحتمالات المتوقعة (معادلة Elo)
            v_expected_home := 1.0 / (1.0 + power(10.0, (v_away_rating - v_home_rating)::DOUBLE PRECISION / 400.0));
            v_expected_away := 1.0 / (1.0 + power(10.0, (v_home_rating - v_away_rating)::DOUBLE PRECISION / 400.0));

            -- احتساب النقاط الجديدة بعد الموازنة
            v_new_home := round(v_home_rating + v_k_factor * (v_outcome - v_expected_home));
            v_new_away := round(v_away_rating + v_k_factor * ((1.0 - v_outcome) - v_expected_away));

            -- تحديث إحصائيات الفريقين ونقاطهما في جدول الفرق
            UPDATE teams
            SET 
                points = v_new_home,
                matches_played = matches_played + 1,
                wins = CASE WHEN v_outcome = 1.0 THEN wins + 1 ELSE wins END,
                draws = CASE WHEN v_outcome = 0.5 THEN draws + 1 ELSE draws END,
                losses = CASE WHEN v_outcome = 0.0 THEN losses + 1 ELSE losses END
            WHERE id = r.player_team_id;

            UPDATE teams
            SET 
                points = v_new_away,
                matches_played = matches_played + 1,
                wins = CASE WHEN v_outcome = 0.0 THEN wins + 1 ELSE wins END,
                draws = CASE WHEN v_outcome = 0.5 THEN draws + 1 ELSE draws END,
                losses = CASE WHEN v_outcome = 1.0 THEN losses + 1 ELSE losses END
            WHERE id = r.opponent_team_id;

            -- وضع علامة "تم الاحتساب" على هذه المباراة لكي لا يتم احتسابها غداً مجدداً
            UPDATE bookings 
            SET elo_processed = true 
            WHERE id = r.id;
        END IF;
    END LOOP;
END;
$function$
;

-- Function: reconcile_owner_web_subscription_orders
CREATE OR REPLACE FUNCTION public.reconcile_owner_web_subscription_orders()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_order record;
  v_count integer := 0;
  v_request_id bigint;
begin
  for v_order in
    select id
    from public.owner_subscription_orders
    where status='pending'
      and payment_source='web'
      and paymob_order_id is not null
      and created_at >= timezone('utc',now()) - interval '48 hours'
    order by created_at asc
    limit 100
  loop
    begin
      select net.http_post(
        url := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/get_owner_web_checkout_status',
        headers := jsonb_build_object('Content-Type','application/json'),
        body := jsonb_build_object('order_id',v_order.id)
      ) into v_request_id;
      v_count := v_count + 1;
    exception when others then
      raise warning
        'owner web subscription reconciliation enqueue failed for %: %',
        v_order.id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object(
    'success',true,
    'queued',v_count,
    'server_time',timezone('utc',now())
  );
end;
$function$
;

-- Function: record_1v1_refund_status_atomic
CREATE OR REPLACE FUNCTION public.record_1v1_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_now timestamptz:=timezone('utc',now()); v_amount numeric; v_admin_id uuid;
begin
 if current_user not in ('postgres','service_role') and coalesce(auth.role(),'')<>'service_role' then return jsonb_build_object('success',false,'error','غير مصرح.'); end if;
 select * into v_order from public.vsp_1v1_tournament_orders where order_reference=p_order_reference for update;
 if not found then return jsonb_build_object('success',false,'error','الطلب غير موجود.'); end if;
 if v_order.payment_status='refunded' then return jsonb_build_object('success',true,'already_refunded',true,'status','refunded'); end if;
 if v_order.payment_status not in ('paid','refund_requested','failed_over_capacity','refund_failed_manual_review') then
   return jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','status',v_order.payment_status);
 end if;
 -- Canonical refundable amount is the tournament entry principal; fees are not refundable.
 v_amount:=round(coalesce(v_order.amount,0),2);
 if v_amount<=0 then return jsonb_build_object('success',false,'error','مبلغ الاسترداد غير صالح.'); end if;
 if p_refund_success then
   update public.vsp_1v1_tournament_orders set payment_status='refunded',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refunded',updated_at=v_now where tournament_id=v_order.tournament_id and user_id=v_order.user_id and payment_order_id=v_order.id;
   update public.transactions set amount=v_amount,status='completed',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_amount',v_amount,'original_gross_amount',v_order.gross_amount,'non_refundable_fee_amount',round(greatest(coalesce(v_order.gross_amount,v_amount)-v_amount,0),2),'refund_recorded_at',v_now),updated_at=v_now
   where user_id=v_order.user_id and type='refund_request' and metadata->>'order_reference'=p_order_reference;
   insert into public.notifications(user_id,title,body,type,created_at)
   values(v_order.user_id,'استرداد رسوم البطولة بنجاح 💳','تم إرجاع مبلغ '||v_amount||' ج.م إلى وسيلة الدفع الخاصة بك بنجاح.','tournament_refund',v_now);
 else
   update public.vsp_1v1_tournament_orders set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refund_failed_manual_review',updated_at=v_now where tournament_id=v_order.tournament_id and user_id=v_order.user_id and payment_order_id=v_order.id;
   update public.transactions set status='failed_manual_review',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('refund_error',p_error_message,'refund_amount',v_amount,'original_gross_amount',v_order.gross_amount,'non_refundable_fee_amount',round(greatest(coalesce(v_order.gross_amount,v_amount)-v_amount,0),2),'refund_recorded_at',v_now),updated_at=v_now
   where user_id=v_order.user_id and type='refund_request' and metadata->>'order_reference'=p_order_reference;
   for v_admin_id in select id from public.users where role in ('admin','co_founder','cofounder','super_admin') loop
     insert into public.notifications(user_id,title,body,type,created_at)
     values(v_admin_id,'تنبيه مالي: فشل استرداد بطولة 1v1','فشل استرداد الطلب '||p_order_reference||' بمبلغ '||v_amount||' ج.م. السبب: '||coalesce(p_error_message,'Paymob API error'),'admin_alert',v_now);
   end loop;
 end if;
 return jsonb_build_object('success',true,'status',case when p_refund_success then 'refunded' else 'refund_failed_manual_review' end,'refund_amount',v_amount,'paymob_refund_id',p_paymob_refund_id);
end; $function$
;

-- Function: record_ai_copilot_audit_event
CREATE OR REPLACE FUNCTION public.record_ai_copilot_audit_event(p_request_id uuid, p_conversation_id uuid, p_user_id uuid, p_user_role text, p_event_type text, p_status text, p_capability_id text DEFAULT NULL::text, p_tool_name text DEFAULT NULL::text, p_action_type text DEFAULT NULL::text, p_verified boolean DEFAULT false, p_verification_source text DEFAULT NULL::text, p_error_code text DEFAULT NULL::text, p_request_hash text DEFAULT NULL::text, p_latency_ms integer DEFAULT NULL::integer, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
begin
  insert into public.ai_copilot_audit_events (
    request_id, conversation_id, user_id, user_role, event_type, status,
    capability_id, tool_name, action_type, verified, verification_source,
    error_code, request_hash, latency_ms, metadata
  ) values (
    p_request_id, p_conversation_id, p_user_id,
    lower(coalesce(trim(p_user_role), 'unknown')),
    p_event_type, p_status,
    nullif(upper(trim(coalesce(p_capability_id, ''))), ''),
    nullif(trim(coalesce(p_tool_name, '')), ''),
    nullif(upper(trim(coalesce(p_action_type, ''))), ''),
    coalesce(p_verified, false),
    nullif(trim(coalesce(p_verification_source, '')), ''),
    nullif(trim(coalesce(p_error_code, '')), ''),
    nullif(trim(coalesce(p_request_hash, '')), ''),
    p_latency_ms,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$function$
;

-- Function: record_booking_gateway_refund_atomic
CREATE OR REPLACE FUNCTION public.record_booking_gateway_refund_atomic(p_booking_id uuid, p_refund_amount numeric, p_refund_txn_id text, p_refund_payment_method text DEFAULT 'card'::text, p_refund_gross_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  b       record;
  t       record;
  v_gross numeric;
BEGIN
  IF current_user NOT IN ('postgres', 'service_role')
     AND coalesce(auth.role(), '') <> 'service_role' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Booking not found'); END IF;
  IF p_refund_amount IS NULL OR p_refund_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid refund amount');
  END IF;

  v_gross := coalesce(p_refund_gross_amount, p_refund_amount);

  IF EXISTS (
    SELECT 1 FROM public.transactions
    WHERE booking_id = p_booking_id
      AND type = 'refund'
      AND status = 'completed'
      AND coalesce(metadata->>'paymob_refund_transaction_id', '') = coalesce(p_refund_txn_id, '')
  ) THEN
    RETURN jsonb_build_object('success', true, 'already_recorded', true, 'booking_id', p_booking_id);
  END IF;

  SELECT id INTO t FROM public.transactions
  WHERE booking_id = p_booking_id AND type = 'refund' AND status = 'pending'
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF FOUND THEN
    UPDATE public.transactions SET
      status         = 'completed',
      amount         = round(p_refund_amount, 2),
      gross_amount   = round(v_gross, 2),
      payment_method = coalesce(nullif(p_refund_payment_method, ''), payment_method),
      metadata       = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
                         'paymob_refund_transaction_id', p_refund_txn_id,
                         'refund_gross_amount',          round(v_gross, 2)
                       ),
      updated_at     = timezone('utc', now())
    WHERE id = t.id;
  ELSE
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(b.created_by_user_id, b.user_id),
      p_booking_id,
      round(p_refund_amount, 2),
      round(v_gross, 2),
      'refund', 'completed',
      coalesce(nullif(p_refund_payment_method, ''), 'card'),
      'استرداد Paymob مؤكد للحجز',
      jsonb_build_object(
        'paymob_refund_transaction_id', p_refund_txn_id,
        'refund_gross_amount',          round(v_gross, 2)
      ),
      timezone('utc', now()), timezone('utc', now())
    ) RETURNING id INTO t;
  END IF;

  UPDATE public.bookings SET
    status                  = 'cancelled',
    payment_status          = 'refunded',
    refund_transaction_id   = p_refund_txn_id,
    refund_amount           = round(p_refund_amount, 2),
    refunded_at             = timezone('utc', now()),
    refund_payment_method   = coalesce(nullif(p_refund_payment_method, ''), 'card'),
    cancelled_at            = coalesce(cancelled_at, timezone('utc', now())),
    updated_at              = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success',       true,
    'booking_id',    p_booking_id,
    'transaction_id', t.id,
    'refund_amount',  round(p_refund_amount, 2),
    'refund_gross',   round(v_gross, 2)
  );
END;
$function$
;

-- Function: record_booking_payment_atomic
CREATE OR REPLACE FUNCTION public.record_booking_payment_atomic(p_booking_id uuid, p_user_id uuid, p_paymob_transaction_id text, p_paymob_order_id text, p_payment_method text, p_principal_amount numeric, p_gross_amount numeric, p_is_deposit boolean DEFAULT false, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking          record;
  v_existing_tx      record;
  v_total_collected  numeric := 0;
  v_total_gross      numeric := 0;
  v_remaining_before numeric := 0;
  v_vsp_rate         numeric;
  v_gateway_rate     numeric;
  v_gateway_fixed    numeric;
  v_vsp_fee          numeric;
  v_gateway_fee      numeric;
  v_expected_gross   numeric;
  v_new_collected    numeric;
  v_new_gross        numeric;
  v_is_final         boolean;
  v_now              timestamptz := timezone('utc', now());
  v_tx_id            uuid;
  v_payment_method   text := lower(coalesce(p_payment_method, 'card'));
  v_card_origin      text := lower(coalesce(p_metadata->>'card_origin', 'local'));
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  IF p_booking_id IS NULL OR p_user_id IS NULL
     OR nullif(trim(p_paymob_transaction_id), '') IS NULL
     OR p_principal_amount IS NULL OR p_principal_amount <= 0
     OR p_gross_amount    IS NULL OR p_gross_amount    <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_arguments');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  SELECT id, amount, status, booking_id
  INTO v_existing_tx
  FROM public.transactions
  WHERE paymob_transaction_id = p_paymob_transaction_id
     OR reference_number = p_paymob_transaction_id
     OR reference_number = 'PAYMOB_' || p_paymob_transaction_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    IF v_existing_tx.booking_id IS DISTINCT FROM p_booking_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'transaction_already_bound_to_other_booking');
    END IF;
    RETURN jsonb_build_object('success', true, 'idempotent', true,
      'transaction_id', v_existing_tx.id, 'booking_id', p_booking_id,
      'principal_amount', v_existing_tx.amount);
  END IF;

  IF coalesce(v_booking.created_by_user_id, v_booking.user_id) IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_user_mismatch');
  END IF;

  SELECT
    coalesce(sum(amount), 0),
    coalesce(sum(coalesce(gross_amount, amount)), 0)
  INTO v_total_collected, v_total_gross
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND type IN ('payment', 'deposit')
    AND status = 'completed';

  v_remaining_before := round(greatest(coalesce(v_booking.total_price, 0) - v_total_collected, 0), 2);

  IF p_principal_amount > v_remaining_before + 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_exceeds_remaining_booking_balance',
      'remaining_amount', v_remaining_before, 'attempted_amount', p_principal_amount);
  END IF;

  SELECT
    booking_vsp_rate,
    CASE
      WHEN v_payment_method = 'wallet'  THEN booking_paymob_wallet_rate
      WHEN v_card_origin   = 'foreign'  THEN booking_paymob_foreign_rate
      ELSE booking_paymob_local_rate
    END,
    booking_paymob_fixed_fee
  INTO v_vsp_rate, v_gateway_rate, v_gateway_fixed
  FROM public.platform_fee_config
  WHERE id = 1;

  IF v_vsp_rate IS NULL OR v_gateway_rate IS NULL OR v_gateway_fixed IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_fee_configuration_unavailable');
  END IF;

  v_vsp_fee        := round(p_principal_amount * v_vsp_rate,                       2);
  v_gateway_fee    := round(p_principal_amount * v_gateway_rate + v_gateway_fixed,  2);
  v_expected_gross := round(p_principal_amount + v_vsp_fee + v_gateway_fee,         2);

  IF abs(p_gross_amount - v_expected_gross) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'gross_amount_mismatch',
      'expected_gross_amount', v_expected_gross, 'received_gross_amount', p_gross_amount,
      'principal_amount', p_principal_amount, 'vsp_fee', v_vsp_fee, 'gateway_fee', v_gateway_fee);
  END IF;

  v_new_collected := round(v_total_collected + p_principal_amount, 2);
  v_new_gross     := round(v_total_gross     + p_gross_amount,     2);
  v_is_final      := v_new_collected >= round(coalesce(v_booking.total_price, 0), 2) - 0.01;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, gross_amount, type, status, payment_method,
    reference_number, paymob_transaction_id, description, metadata, created_at, updated_at
  ) VALUES (
    p_user_id, p_booking_id, p_principal_amount, p_gross_amount,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'payment' ELSE 'deposit' END,
    'completed', v_payment_method,
    p_paymob_transaction_id, p_paymob_transaction_id,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'دفع حجز ملعب' ELSE 'دفع عربون حجز ملعب' END,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'principal_amount',    p_principal_amount,
      'gross_amount_charged', p_gross_amount,
      'vsp_fee',             v_vsp_fee,
      'gateway_fee',         v_gateway_fee,
      'total_payment_fees',  round(v_vsp_fee + v_gateway_fee, 2),
      'paymob_order_id',     p_paymob_order_id,
      'server_recorded_at',  v_now,
      'paymob_fee_policy',   'contract_2026_09'
    ),
    v_now, v_now
  ) RETURNING id INTO v_tx_id;

  UPDATE public.bookings SET
    status                  = 'confirmed',
    is_paid                 = v_is_final,
    payment_status          = CASE WHEN v_is_final THEN 'paid' ELSE 'partially_paid' END,
    is_deposit_paid         = true,
    deposit_paid            = v_new_collected,
    gross_amount_charged    = v_new_gross,
    payment_transaction_id  = 'PAYMOB_' || p_paymob_transaction_id,
    paymob_txn_id           = p_paymob_transaction_id,
    paymob_order_id         = p_paymob_order_id,
    paymob_transaction_id   = p_paymob_transaction_id,
    payment_method          = v_payment_method,
    webhook_verified        = true,
    webhook_processed_at    = v_now,
    vsp_commission          = (SELECT coalesce(sum(coalesce((metadata->>'vsp_fee')::numeric,0)),0)
                               FROM public.transactions
                               WHERE booking_id = p_booking_id AND type IN ('payment','deposit') AND status = 'completed'),
    gateway_fee             = (SELECT coalesce(sum(coalesce((metadata->>'gateway_fee')::numeric,0)),0)
                               FROM public.transactions
                               WHERE booking_id = p_booking_id AND type IN ('payment','deposit') AND status = 'completed'),
    platform_fee            = (SELECT coalesce(sum(coalesce((metadata->>'vsp_fee')::numeric,0)),0)
                               FROM public.transactions
                               WHERE booking_id = p_booking_id AND type IN ('payment','deposit') AND status = 'completed'),
    updated_at              = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success',          true,
    'idempotent',       false,
    'transaction_id',   v_tx_id,
    'booking_id',       p_booking_id,
    'principal_amount', p_principal_amount,
    'gross_amount',     p_gross_amount,
    'vsp_fee',          v_vsp_fee,
    'gateway_fee',      v_gateway_fee,
    'total_collected',  v_new_collected,
    'gross_total',      v_new_gross,
    'remaining_amount', round(greatest(coalesce(v_booking.total_price,0) - v_new_collected, 0), 2),
    'is_final_payment', v_is_final,
    'payment_status',   CASE WHEN v_is_final THEN 'paid' ELSE 'partially_paid' END
  );
END;
$function$
;

-- Function: record_match_result_and_advance_atomic
CREATE OR REPLACE FUNCTION public.record_match_result_and_advance_atomic(p_match_id uuid, p_home_score integer, p_away_score integer, p_home_penalties integer DEFAULT NULL::integer, p_away_penalties integer DEFAULT NULL::integer, p_winner_id uuid DEFAULT NULL::uuid, p_winner_name text DEFAULT NULL::text, p_goal_details jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_match RECORD;
    v_champ RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_is_knockout BOOLEAN;
    v_expected_winner_id UUID;
    v_effective_winner_id UUID := p_winner_id;
    v_effective_winner_name TEXT := p_winner_name;
    v_next_match RECORD;
    v_next_home_id UUID;
    v_next_home_name TEXT;
    v_next_away_id UUID;
    v_next_away_name TEXT;
BEGIN
    -- 1. Reject negative scores
    IF p_home_score < 0 OR p_away_score < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_SCORE: Scores cannot be negative');
    END IF;

    IF (p_home_penalties IS NOT NULL AND p_home_penalties < 0) OR (p_away_penalties IS NOT NULL AND p_away_penalties < 0) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_PENALTIES: Penalty scores cannot be negative');
    END IF;

    -- 2. Fetch match and lock
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- Prevent modifying locked matches
    IF v_match.result_status = 'locked' THEN
        RETURN jsonb_build_object('success', false, 'error', 'LOCKED_MATCH: Match result is locked and cannot be modified');
    END IF;

    -- 3. Authorization (owner or admin)
    SELECT * INTO v_champ FROM public.championships WHERE id = v_match.championship_id;
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can submit scores');
            END IF;
        END IF;
    END IF;

    -- Both teams must be populated
    IF v_match.home_team_id IS NULL OR v_match.away_team_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'INCOMPLETE_MATCH: Both teams must be assigned before recording score');
    END IF;

    -- Authoritative League vs Knockout determination
    IF v_match.stage = 'league' OR COALESCE(v_champ.type, '') = 'league' THEN
        v_is_knockout := false;
    ELSIF v_match.stage = 'group_stage' OR v_match.group_name IS NOT NULL THEN
        v_is_knockout := false;
    ELSE
        -- Knockout stage match
        v_is_knockout := (
            v_match.next_match_id IS NOT NULL OR 
            v_match.stage IN ('knockout', 'cup', 'round_of_16', 'quarter_final', 'semi_final', 'final') OR 
            COALESCE(v_champ.type, '') IN ('cup', 'knockout')
        );
    END IF;

    -- 4. Validate winner vs scores
    IF p_home_score != p_away_score THEN
        IF p_home_score > p_away_score THEN
            v_expected_winner_id := v_match.home_team_id;
            v_effective_winner_name := v_match.home_team_name;
        ELSE
            v_expected_winner_id := v_match.away_team_id;
            v_effective_winner_name := v_match.away_team_name;
        END IF;

        IF p_winner_id IS NOT NULL AND p_winner_id != v_expected_winner_id THEN
            RETURN jsonb_build_object('success', false, 'error', 'WINNER_MISMATCH: Winner does not match regular time score');
        END IF;
        v_effective_winner_id := v_expected_winner_id;
    ELSE
        -- Tied score (p_home_score = p_away_score)
        IF v_is_knockout THEN
            IF p_home_penalties IS NULL OR p_away_penalties IS NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'PENALTIES_REQUIRED: Tied knockout match requires penalties');
            END IF;
            IF p_home_penalties = p_away_penalties THEN
                RETURN jsonb_build_object('success', false, 'error', 'PENALTIES_TIED: Penalties cannot be tied in knockout match');
            END IF;

            IF p_home_penalties > p_away_penalties THEN
                v_expected_winner_id := v_match.home_team_id;
                v_effective_winner_name := v_match.home_team_name;
            ELSE
                v_expected_winner_id := v_match.away_team_id;
                v_effective_winner_name := v_match.away_team_name;
            END IF;

            IF p_winner_id IS NOT NULL AND p_winner_id != v_expected_winner_id THEN
                RETURN jsonb_build_object('success', false, 'error', 'WINNER_MISMATCH: Winner does not match penalty shootout result');
            END IF;
            v_effective_winner_id := v_expected_winner_id;
        ELSE
            -- Group stage / League draw: no penalties, no winner
            IF p_winner_id IS NOT NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'WINNER_MISMATCH: Draws in league or group matches cannot have a winner');
            END IF;
            v_effective_winner_id := NULL;
            v_effective_winner_name := NULL;
        END IF;
    END IF;

    -- Winner must be one of the two participating teams if not a draw
    IF v_effective_winner_id IS NOT NULL AND v_effective_winner_id NOT IN (v_match.home_team_id, v_match.away_team_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_WINNER: Winner must be one of the participating teams');
    END IF;

    -- Knockout matches require a decisive winner
    IF v_is_knockout AND v_effective_winner_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'KNOCKOUT_REQUIRES_WINNER: Knockout matches cannot end without a winner');
    END IF;

    -- If winner name is null but we have a winner id, resolve name
    IF v_effective_winner_id IS NOT NULL AND v_effective_winner_name IS NULL THEN
        IF v_effective_winner_id = v_match.home_team_id THEN
            v_effective_winner_name := v_match.home_team_name;
        ELSIF v_effective_winner_id = v_match.away_team_id THEN
            v_effective_winner_name := v_match.away_team_name;
        ELSE
            SELECT name INTO v_effective_winner_name FROM public.teams WHERE id = v_effective_winner_id;
        END IF;
    END IF;

    -- 5. Update match row to authoritative completed & confirmed status
    UPDATE public.tournament_matches
    SET home_score = p_home_score,
        away_score = p_away_score,
        home_penalties = CASE WHEN v_is_knockout THEN p_home_penalties ELSE NULL END,
        away_penalties = CASE WHEN v_is_knockout THEN p_away_penalties ELSE NULL END,
        winner_id = v_effective_winner_id,
        winner_name = v_effective_winner_name,
        goal_details = COALESCE(p_goal_details, '[]'::jsonb),
        status = 'completed',
        is_completed = true,
        result_status = 'confirmed',
        result_confirmed_at = COALESCE(result_confirmed_at, v_now),
        updated_at = v_now
    WHERE id = p_match_id;

    -- 6. Advance winner if next_match_id is set (Knockout progression)
    IF v_is_knockout AND v_match.next_match_id IS NOT NULL AND v_effective_winner_id IS NOT NULL THEN
        SELECT * INTO v_next_match FROM public.tournament_matches WHERE id = v_match.next_match_id FOR UPDATE;
        IF FOUND THEN
            -- Deterministic slot placement based on match_index parity
            IF (v_match.match_index % 2) = 0 THEN
                v_next_home_id := v_effective_winner_id;
                v_next_home_name := v_effective_winner_name;
                v_next_away_id := v_next_match.away_team_id;
                v_next_away_name := v_next_match.away_team_name;
            ELSE
                v_next_home_id := v_next_match.home_team_id;
                v_next_home_name := v_next_match.home_team_name;
                v_next_away_id := v_effective_winner_id;
                v_next_away_name := v_effective_winner_name;
            END IF;

            UPDATE public.tournament_matches
            SET home_team_id = v_next_home_id,
                home_team_name = v_next_home_name,
                away_team_id = v_next_away_id,
                away_team_name = v_next_away_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'match_id', p_match_id,
        'status', 'completed',
        'result_status', 'confirmed',
        'winner_id', v_effective_winner_id,
        'winner_name', v_effective_winner_name
    );
END;
$function$
;

-- Function: record_matchup_result_atomic
CREATE OR REPLACE FUNCTION public.record_matchup_result_atomic(p_booking_id uuid, p_team_a_id uuid, p_team_b_id uuid, p_outcome text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caller_id uuid:=auth.uid(); v_booking record; v_result_id uuid;
BEGIN
 IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: User not authenticated'; END IF;
 SELECT id,created_by_user_id,user_id,status,matchup_closed_at,matchup_mode,start_time,end_time INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF coalesce(v_booking.created_by_user_id,v_booking.user_id)<>v_caller_id THEN RAISE EXCEPTION 'Forbidden: Only the booking creator can record match results'; END IF;
 IF v_booking.matchup_closed_at IS NOT NULL THEN RAISE EXCEPTION 'Matchup is closed'; END IF;
 IF v_booking.status NOT IN ('confirmed','completed','started') THEN RAISE EXCEPTION 'Matchup booking is not active'; END IF;
 IF timezone('utc',now())<v_booking.end_time THEN RAISE EXCEPTION 'MATCHUP_RESULT_TOO_EARLY: Result can be recorded only after the scheduled match ends'; END IF;
 IF p_outcome NOT IN ('team_a_win','team_b_win','draw') THEN RAISE EXCEPTION 'Invalid outcome'; END IF;
 IF p_team_a_id=p_team_b_id THEN RAISE EXCEPTION 'Cannot record same team'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=p_team_a_id) OR NOT EXISTS(SELECT 1 FROM public.matchup_teams WHERE booking_id=p_booking_id AND team_id=p_team_b_id) THEN RAISE EXCEPTION 'Both teams must be registered'; END IF;
 IF v_booking.matchup_mode='duo' AND EXISTS(SELECT 1 FROM public.matchup_results WHERE booking_id=p_booking_id) THEN RAISE EXCEPTION 'Duo matchup already has a result'; END IF;
 INSERT INTO public.matchup_results(booking_id,team_a_id,team_b_id,outcome,recorded_by,created_at) VALUES(p_booking_id,p_team_a_id,p_team_b_id,p_outcome,v_caller_id,timezone('utc',now())) RETURNING id INTO v_result_id;
 RETURN jsonb_build_object('success',true,'result_id',v_result_id,'booking_id',p_booking_id,'outcome',p_outcome);
END $function$
;

-- Function: record_tournament_refund_status_atomic
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN public.record_tournament_refund_status_atomic(
        p_order_reference,
        CASE WHEN p_refund_success THEN 'refunded' ELSE 'refund_failed_manual_review' END,
        p_paymob_refund_id,
        p_error_message
    );
END;
$function$
;

-- Function: record_tournament_refund_status_atomic
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_admin_id uuid; v_now timestamptz:=timezone('utc',now()); v_amount numeric; v_updated integer:=0;
begin
 if coalesce(auth.role(),'')<>'service_role' and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','غير مصرح: تحديث حالة الاسترداد مقتصر على الخادم.'); end if;
 if p_refund_status not in ('refunded','refund_failed_manual_review') then return jsonb_build_object('success',false,'error','حالة الاسترداد غير صالحة.'); end if;
 select * into v_order from public.tournament_orders where order_reference=p_order_reference for update;
 if not found then return jsonb_build_object('success',false,'error','طلب اشتراك البطولة غير موجود.'); end if;
 if v_order.payment_status='refunded' then return jsonb_build_object('success',true,'already_refunded',true,'order_reference',p_order_reference,'status','refunded'); end if;
 if v_order.payment_status not in ('paid','failed_over_capacity','refund_failed_manual_review') then return jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','current_status',v_order.payment_status); end if;
 v_amount:=round(coalesce(nullif(p_refund_amount,0),v_order.amount),2);
 if v_amount<=0 then return jsonb_build_object('success',false,'error','مبلغ الاسترداد غير صالح.'); end if;
 update public.tournament_orders set payment_status=p_refund_status,updated_at=v_now where id=v_order.id;
 update public.transactions set amount=v_amount,status=case when p_refund_status='refunded' then 'completed' else 'failed' end,
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now,'refund_amount',v_amount,'principal_amount',v_order.amount)
 where championship_id=v_order.championship_id and type='refund' and metadata->>'order_reference'=p_order_reference;
 get diagnostics v_updated = row_count;
 if v_updated=0 then
  insert into public.transactions(user_id,championship_id,amount,type,status,payment_method,reference_number,metadata,created_at,updated_at)
  values(v_order.captain_user_id,v_order.championship_id,v_amount,'refund',case when p_refund_status='refunded' then 'completed' else 'failed' end,'paymob',
   'REFUND_'||p_order_reference,jsonb_build_object('order_reference',p_order_reference,'paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now,'refund_amount',v_amount,'principal_amount',v_order.amount),v_now,v_now);
 end if;
 if p_refund_status='refunded' then
  insert into public.notifications(user_id,title,body,type,created_at) values(v_order.captain_user_id,'تم استرداد رسوم اشتراك البطولة بنجاح','تمت إعادة مبلغ رسوم الاشتراك ('||v_amount||' ج.م) بنجاح عبر Paymob (مرجع: '||coalesce(p_paymob_refund_id,'')||').','tournament_refund',v_now);
 else
  insert into public.notifications(user_id,title,body,type,created_at) values(v_order.captain_user_id,'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)','تعذر الاسترداد التلقائي للرسوم ('||v_amount||' ج.م). تم تحويل العملية للمراجعة اليدوية.','tournament_refund_manual',v_now);
  for v_admin_id in select id from public.users where role in ('admin','co_founder','cofounder','super_admin') loop
   insert into public.notifications(user_id,title,body,type,created_at) values(v_admin_id,'تنبيه مالي: فشل استرداد رسوم بطولة فرق','فشل استرداد الطلب '||p_order_reference||' (المبلغ: '||v_amount||' ج.م). السبب: '||coalesce(p_error_message,'Paymob API error')||'.','admin_alert',v_now);
  end loop;
 end if;
 return jsonb_build_object('success',true,'order_reference',p_order_reference,'status',p_refund_status,'paymob_refund_id',p_paymob_refund_id,'refund_amount',v_amount,'ledger_recorded',true);
end; $function$
;

-- Function: record_tournament_refund_status_atomic
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
 return public.record_tournament_refund_status_atomic(p_order_reference,case when p_refund_success then 'refunded' else 'refund_failed_manual_review' end,p_paymob_refund_id,p_error_message,p_refund_amount);
end;
$function$
;

-- Function: record_tournament_refund_status_atomic
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_order record; v_admin_id uuid; v_now timestamptz:=timezone('utc',now());
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  RETURN jsonb_build_object('success',false,'error','غير مصرح: تحديث حالة الاسترداد مقتصر على الخادم.');
 END IF;
 IF p_refund_status NOT IN ('refunded','refund_failed_manual_review') THEN RETURN jsonb_build_object('success',false,'error','حالة الاسترداد غير صالحة.'); END IF;
 SELECT * INTO v_order FROM public.tournament_orders WHERE order_reference=p_order_reference FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','طلب اشتراك البطولة غير موجود.'); END IF;
 IF v_order.payment_status='refunded' THEN RETURN jsonb_build_object('success',true,'already_refunded',true,'order_reference',p_order_reference,'status','refunded'); END IF;
 IF v_order.payment_status NOT IN ('paid','refund_failed_manual_review') THEN RETURN jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','current_status',v_order.payment_status); END IF;
 UPDATE public.tournament_orders SET payment_status=p_refund_status,updated_at=v_now WHERE id=v_order.id;
 UPDATE public.transactions SET status=CASE WHEN p_refund_status='refunded' THEN 'completed' ELSE 'failed' END,
  metadata=coalesce(metadata,'{}')||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now)
  WHERE championship_id=v_order.championship_id AND type='refund' AND metadata->>'order_reference'=p_order_reference;
 IF p_refund_status='refunded' THEN
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_order.captain_user_id,'تم استرداد رسوم اشتراك البطولة بنجاح','تمت إعادة مبلغ رسوم الاشتراك ('||v_order.amount||' ج.م) بنجاح عبر Paymob (مرجع: '||coalesce(p_paymob_refund_id,'')||').','tournament_refund',v_now);
 ELSE
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_order.captain_user_id,'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)','تعذر الاسترداد التلقائي للرسوم ('||v_order.amount||' ج.م). تم تحويل العملية للمراجعة اليدوية.','tournament_refund_manual',v_now);
  FOR v_admin_id IN SELECT id FROM public.users WHERE role IN ('admin','co_founder','cofounder','super_admin') LOOP
   INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_admin_id,'تنبيه مالي: فشل استرداد رسوم بطولة فرق','فشل استرداد الطلب '||p_order_reference||' (المبلغ: '||v_order.amount||' ج.م). السبب: '||coalesce(p_error_message,'Paymob API error')||'.','admin_alert',v_now);
  END LOOP;
 END IF;
 RETURN jsonb_build_object('success',true,'order_reference',p_order_reference,'status',p_refund_status,'paymob_refund_id',p_paymob_refund_id);
END;$function$
;

-- Function: reject_join_request
CREATE OR REPLACE FUNCTION public.reject_join_request(p_booking_id text, p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    -- 🔒 التحقق من الصلاحية
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL OR (auth.uid() != v_booking.created_by_user_id AND auth.uid() != v_booking.owner_id) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح.');
        END IF;
    END IF;

    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids::text[], ARRAY[]::text[]), p_user_id),
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'تم رفض الطلب بنجاح.');
END;
$function$
;

-- Function: reject_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.reject_payout_settlement_atomic(p_settlement_id uuid, p_rejection_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_settlement      record;
  v_now             timestamptz := timezone('utc', now());
  v_reason          text := trim(COALESCE(p_rejection_reason, ''));
BEGIN
  -- Strict Admin Authorization Check
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF NOT public.is_admin_or_cofounder(v_caller_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_ADMIN_REQUIRED');
    END IF;
  END IF;

  -- Lock settlement FOR UPDATE
  SELECT * INTO v_settlement
  FROM public.payout_settlements
  WHERE id = p_settlement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SETTLEMENT_NOT_FOUND');
  END IF;

  -- Idempotency: If already rejected, return idempotent success
  IF v_settlement.status = 'rejected' THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent', true,
      'settlement_id', p_settlement_id,
      'status', 'rejected',
      'amount', v_settlement.amount,
      'message', 'Settlement is already rejected'
    );
  END IF;

  -- Cannot reject if already completed / paid out
  IF v_settlement.status = 'completed' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CANNOT_REJECT_COMPLETED',
      'message', 'لا يمكن رفض طلب تسوية تم صرفه واكتماله بالفعل'
    );
  END IF;

  -- Only pending or approved can be rejected
  IF v_settlement.status NOT IN ('pending', 'approved') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_SETTLEMENT_STATE',
      'message', 'حالة طلب التسوية لا تسمح بالرفض'
    );
  END IF;

  -- Update settlement status to 'rejected'
  UPDATE public.payout_settlements
  SET status = 'rejected',
      admin_notes = CASE 
        WHEN v_reason <> '' THEN v_reason 
        ELSE admin_notes 
      END,
      updated_at = v_now
  WHERE id = p_settlement_id;

  -- Update linked transactions in transactions table
  UPDATE public.transactions
  SET type = 'payout_rejected',
      status = 'failed',
      description = 'رفض طلب سحب أرباح المالك من قبل الإدارة',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'rejected_by', v_caller_id,
        'rejected_at', v_now,
        'rejection_reason', v_reason
      ),
      updated_at = v_now
  WHERE (metadata->>'settlement_id') = p_settlement_id::text
    AND type IN ('payout_pending', 'payout');

  -- Insert notification for owner
  INSERT INTO public.notifications(
    user_id,
    title,
    body,
    type,
    is_read,
    created_at
  ) VALUES (
    v_settlement.owner_id,
    'تم رفض طلب سحب الأرباح ⚠️',
    'تم رفض طلب تسوية الأرباح بمبلغ ' || round(v_settlement.amount, 2) || ' ج.م.' || 
      CASE WHEN v_reason <> '' THEN ' السبب: ' || v_reason ELSE '' END,
    'payout',
    false,
    v_now
  );

  RETURN jsonb_build_object(
    'success', true,
    'idempotent', false,
    'settlement_id', p_settlement_id,
    'status', 'rejected',
    'restored_amount', round(v_settlement.amount, 2),
    'message', 'تم رفض طلب التسوية واستعادة الرصيد للمالك بنجاح.'
  );
END;
$function$
;

-- Function: release_booking_lock
CREATE OR REPLACE FUNCTION public.release_booking_lock(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
BEGIN
    UPDATE public.bookings
    SET status = 'cancelled',
        cancellation_reason = 'Cancelled by user during payment checkout',
        updated_at = NOW()
    WHERE id = p_booking_id
      AND status = 'pending'
      AND (created_by_user_id = v_caller_id OR user_id = v_caller_id);

    RETURN jsonb_build_object('success', true);
END;
$function$
;

-- Function: remove_private_collective_participant_atomic
CREATE OR REPLACE FUNCTION public.remove_private_collective_participant_atomic(p_booking_id uuid, p_participant_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking public.bookings%rowtype; v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;
  SELECT * INTO v_booking FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid<>v_booking.created_by_user_id AND v_uid<>v_booking.owner_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;
  IF p_participant_id=v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_CANNOT_BE_REMOVED'; END IF;
  IF v_booking.status IN ('cancelled','completed','expired') OR v_booking.end_time<=timezone('utc',now()) THEN
    RAISE EXCEPTION 'MATCH_NOT_EDITABLE';
  END IF;
  IF NOT(p_participant_id=ANY(coalesce(v_booking.joined_user_ids,array[]::uuid[]))) THEN RAISE EXCEPTION 'NOT_JOINED'; END IF;
  PERFORM set_config('vsp.system_override','true',true);
  UPDATE public.bookings
  SET joined_user_ids=array_remove(joined_user_ids,p_participant_id),updated_at=timezone('utc',now())
  WHERE id=p_booking_id;
  RETURN true;
END;
$function$
;

-- Function: remove_public_match_participant_atomic
CREATE OR REPLACE FUNCTION public.remove_public_match_participant_atomic(p_booking_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking bookings%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
 IF auth.uid()<>v_booking.created_by_user_id AND auth.uid()<>v_booking.owner_id THEN RAISE EXCEPTION 'Unauthorized: Only the host or stadium owner can remove a participant'; END IF;
 IF NOT (p_user_id=ANY(coalesce(v_booking.joined_user_ids,ARRAY[]::uuid[]))) THEN RAISE EXCEPTION 'User is not a joined participant'; END IF;
 UPDATE public.bookings SET joined_user_ids=array_remove(joined_user_ids,p_user_id),current_players=GREATEST(0,coalesce(current_players,0)-1),updated_at=timezone('utc',now()) WHERE id=p_booking_id;
 RETURN true;
END $function$
;

-- Function: remove_team_member_atomic
CREATE OR REPLACE FUNCTION public.remove_team_member_atomic(p_team_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_cap uuid;
  v_next uuid;
  v_team_disbanded boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  SELECT captain_id INTO v_cap FROM public.teams WHERE id = p_team_id FOR UPDATE;

  IF v_cap IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team not found');
  END IF;

  -- Authority Check: Caller must be the member leaving (self-leave), the team captain, or platform admin
  IF auth.uid() <> p_user_id AND v_cap <> auth.uid() AND COALESCE(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: فقط الكابتن أو العضو نفسه يمكنه إتمام المغادرة.');
  END IF;

  -- Active match or ongoing tournament safeguard
  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE status = 'confirmed'
      AND (player_team_id = p_team_id OR opponent_team_id = p_team_id)
      AND end_time > now()
  ) OR EXISTS (
    SELECT 1 FROM public.championships
    WHERE status IN ('open', 'ongoing')
      AND p_team_id = ANY(COALESCE(joined_teams, ARRAY[]::uuid[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'active_match_or_tournament_error');
  END IF;

  -- Verify user is actually a member of this team
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player is not a member of this team');
  END IF;

  -- Delete member record
  DELETE FROM public.team_members
  WHERE team_id = p_team_id AND user_id = p_user_id;

  -- If the captain is removing themselves / leaving:
  IF v_cap = p_user_id THEN
    -- Find the next oldest joined member (Primary Key is (team_id, user_id), ordering by joined_at ASC)
    SELECT user_id INTO v_next
    FROM public.team_members
    WHERE team_id = p_team_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_next IS NOT NULL THEN
      -- Transfer captaincy to next senior member
      UPDATE public.teams t
      SET captain_id = v_next,
          captain_name = u.name,
          captain_phone = u.phone,
          captain_image_url = u.profile_image_url,
          updated_at = now()
      FROM public.users u
      WHERE t.id = p_team_id AND u.id = v_next;
    ELSE
      -- Team has 0 remaining members: delete empty team cleanly
      DELETE FROM public.teams WHERE id = p_team_id;
      v_team_disbanded := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'captain_transferred', (v_cap = p_user_id AND v_next IS NOT NULL),
    'new_captain_id', v_next,
    'team_disbanded', v_team_disbanded
  );
END;
$function$
;

-- Function: remove_tournament_team_atomic
CREATE OR REPLACE FUNCTION public.remove_tournament_team_atomic(p_championship_id uuid, p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN public.leave_championship_atomic(p_championship_id, p_team_id);
END;
$function$
;

-- Function: request_booking_reschedule_atomic
CREATE OR REPLACE FUNCTION public.request_booking_reschedule_atomic(p_booking_id uuid, p_new_start timestamp with time zone, p_new_end timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare b record; now_ts timestamptz:=now(); duration_minutes int;
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if p_new_end<=p_new_start then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 if b.owner_id<>auth.uid() and b.user_id<>auth.uid() and b.created_by_user_id<>auth.uid() then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status in ('cancelled','completed') then return jsonb_build_object('success',false,'error','BOOKING_NOT_RESCHEDULABLE'); end if;
 if now_ts>=b.start_time then return jsonb_build_object('success',false,'error','BOOKING_ALREADY_STARTED'); end if;
 if b.reschedule_status='pending' then return jsonb_build_object('success',false,'error','RESCHEDULE_ALREADY_PENDING'); end if;
 duration_minutes:=extract(epoch from(p_new_end-p_new_start))/60;
 if duration_minutes < (select booking_min_duration_minutes from public.platform_business_rules where id=1)
    or duration_minutes > (select booking_max_duration_hours from public.platform_business_rules where id=1)*60
 then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
 if p_new_start < now_ts then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
 update public.bookings
 set reschedule_status='pending',proposed_start_time=p_new_start,proposed_end_time=p_new_end,updated_at=now_ts
 where id=p_booking_id;
 return jsonb_build_object('success',true,'status','pending','booking_id',p_booking_id);
end; $function$
;

-- Function: request_emergency_stadium_closure
CREATE OR REPLACE FUNCTION public.request_emergency_stadium_closure(p_stadium_id uuid, p_owner_id uuid, p_reason text, p_duration_hours integer DEFAULT 24)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_last_closure timestamptz;
  v_days_diff integer;
  v_maintenance_until timestamptz;
  v_affected_bookings_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Authentication required.');
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

  -- التحقق من ملكية الملعب
  IF NOT EXISTS (
    SELECT 1 FROM public.stadiums 
    WHERE id = p_stadium_id AND (owner_id = v_caller_id OR v_caller_role IN ('admin', 'co_founder'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإدارة هذا الملعب.');
  END IF;

  -- فحص آخر إغلاق طارئ (مهلة 30 يوم)
  SELECT last_emergency_closure_at INTO v_last_closure 
  FROM public.stadiums WHERE id = p_stadium_id;

  IF v_last_closure IS NOT NULL THEN
    v_days_diff := EXTRACT(DAY FROM (NOW() - v_last_closure));
    IF v_days_diff < 30 AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
      RETURN jsonb_build_object(
        'success', false, 
        'message', format('لقد استخدمت حق الإلغاء الطارئ لهذا الشهر مسبقاً. متبقي %s يوم لإعادة تفعيل الميزة.', 30 - v_days_diff)
      );
    END IF;
  END IF;

  v_maintenance_until := NOW() + (p_duration_hours || ' hours')::interval;

  -- تحديث حالة الملعب
  UPDATE public.stadiums
  SET
    maintenance_until = v_maintenance_until,
    maintenance_reason = p_reason,
    last_emergency_closure_at = NOW(),
    updated_at = NOW()
  WHERE id = p_stadium_id;

  -- تحويل الحجوزات المتداخلة للإلغاء الطارئ والمراجعة الإدارية
  UPDATE public.bookings
  SET
    emergency_cancel_status = 'pending_admin_approval',
    emergency_reason = p_reason,
    emergency_downtime_hours = p_duration_hours,
    updated_at = NOW()
  WHERE stadium_id = p_stadium_id
    AND status = 'confirmed'
    AND start_time >= NOW()
    AND start_time <= v_maintenance_until;

  GET DIAGNOSTICS v_affected_bookings_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'affected_bookings', v_affected_bookings_count,
    'maintenance_until', v_maintenance_until
  );
END;
$function$
;

-- Function: request_join_public_match
CREATE OR REPLACE FUNCTION public.request_join_public_match(p_booking_id text, p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking       record;
  v_user_conflict int;
  v_user_blocked  boolean;
  v_capacity      int;
  v_booking_uuid  uuid;
  v_user_uuid     uuid;
  v_now           timestamptz := timezone('utc', now());
BEGIN
  BEGIN
    v_booking_uuid := p_booking_id::uuid;
    v_user_uuid    := p_user_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_UUID_FORMAT' USING ERRCODE = '22P02';
  END;

  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF auth.uid() IS NULL OR auth.uid() <> v_user_uuid THEN
      RAISE EXCEPTION 'PERMISSION_DENIED' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking_uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  -- SSOT Gate: strictly open_join bookings allow public joining
  IF COALESCE(v_booking.booking_type, '') <> 'open_join' THEN
    RAISE EXCEPTION 'not_an_open_join_match';
  END IF;

  IF v_booking.is_private IS TRUE THEN RAISE EXCEPTION 'match_not_public'; END IF;
  IF v_booking.status = 'cancelled' THEN RAISE EXCEPTION 'match_cancelled'; END IF;
  IF v_booking.status = 'completed' THEN RAISE EXCEPTION 'match_already_completed'; END IF;
  IF v_booking.end_time <= v_now THEN RAISE EXCEPTION 'match_expired'; END IF;

  -- Block joining unpaid pending online bookings until host payment confirms
  IF v_booking.status NOT IN ('confirmed')
     AND NOT (v_booking.status = 'pending' AND lower(COALESCE(v_booking.payment_method, '')) = 'cash') THEN
    RAISE EXCEPTION 'match_not_confirmed';
  END IF;

  SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
  IF v_user_blocked IS TRUE THEN RAISE EXCEPTION 'user_blocked'; END IF;

  v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
  IF COALESCE(v_booking.current_players, 0) >= v_capacity THEN
    RAISE EXCEPTION 'match_is_full';
  END IF;

  IF v_user_uuid = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))
     OR v_booking.created_by_user_id = v_user_uuid THEN
    RAISE EXCEPTION 'already_joined';
  END IF;

  -- Time conflict check for joining player
  SELECT COUNT(*) INTO v_user_conflict FROM public.bookings
  WHERE status <> 'cancelled' AND id <> v_booking_uuid
    AND (created_by_user_id = v_user_uuid OR v_user_uuid = ANY(COALESCE(joined_user_ids, ARRAY[]::uuid[])))
    AND start_time < v_booking.end_time AND end_time > v_booking.start_time;

  IF v_user_conflict > 0 THEN RAISE EXCEPTION 'time_conflict'; END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::uuid[]), v_user_uuid),
      current_players = COALESCE(current_players, 0) + 1,
      updated_at = v_now
  WHERE id = v_booking_uuid;

  RETURN jsonb_build_object(
    'success',         true,
    'booking_id',      p_booking_id,
    'current_players', COALESCE(v_booking.current_players, 0) + 1,
    'host_user_id',    v_booking.created_by_user_id
  );
END;
$function$
;

-- Function: request_owner_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_method text DEFAULT 'instapay'::text, p_destination text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_pending_count integer; v_settlement_id uuid; v_owner record; v_caller_role text;
 v_now timestamptz:=timezone('utc',now()); v_online_earned numeric:=0;
 v_total_withdrawn numeric:=0; v_pending_payouts numeric:=0; v_available_balance numeric:=0;
 v_method text; v_destination text;
begin
 if auth.uid() is null and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','Authentication required'); end if;
 if auth.uid() is not null and auth.uid()<>p_owner_id and current_user not in ('postgres','service_role') then
  select role into v_caller_role from public.users where id=auth.uid();
  if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','Unauthorized payout request'); end if;
 end if;
 if p_amount is null or p_amount<=0 then return jsonb_build_object('success',false,'error','يجب أن يكون مبلغ السحب أكبر من الصفر.'); end if;
 select * into v_owner from public.users where id=p_owner_id for update;
 if not found then return jsonb_build_object('success',false,'error','حساب المالك غير موجود.'); end if;

 v_method:=lower(trim(coalesce(p_method,'')));
 v_method:=case v_method when 'wallet' then 'vodafone_cash' when 'vodafone' then 'vodafone_cash' when 'bank' then 'bank_transfer' else v_method end;
 if v_method not in ('instapay','vodafone_cash','bank_transfer') then return jsonb_build_object('success',false,'error','وسيلة السحب غير مدعومة.'); end if;

 v_destination:=case v_method
  when 'instapay' then trim(coalesce(v_owner.p2p_instapay,''))
  when 'vodafone_cash' then trim(coalesce(v_owner.p2p_vodafone,''))
  when 'bank_transfer' then trim(coalesce(v_owner.p2p_bank,''))
 end;
 if v_destination='' then return jsonb_build_object('success',false,'error','بيانات جهة التحويل لهذه الوسيلة غير مسجلة في حسابك.'); end if;
 if p_destination is not null and trim(p_destination)<>'' and trim(p_destination)<>v_destination then
  return jsonb_build_object('success',false,'error','بيانات جهة التحويل تغيرت عن البيانات المسجلة. حدّث إعدادات الحساب ثم أعد المحاولة.'); end if;

 select count(*) into v_pending_count from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');
 if v_pending_count>0 then return jsonb_build_object('success',false,'error','لديك طلب سحب قيد المراجعة بالفعل.'); end if;

 select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0)
 into v_online_earned
 from public.bookings b
 where b.owner_id=p_owner_id
   and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
   and (b.payment_status='paid' or b.is_paid=true)
   and b.status in ('completed','no_show');

 select coalesce(sum(amount),0) into v_total_withdrawn from public.payout_settlements where owner_id=p_owner_id and status='completed';
 select coalesce(sum(amount),0) into v_pending_payouts from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');
 v_available_balance:=greatest(0,v_online_earned-v_total_withdrawn-v_pending_payouts);

 if round(p_amount,2)>round(v_available_balance,2)+0.01 then
  return jsonb_build_object('success',false,'error','المبلغ المطلوب ('||round(p_amount,2)||' ج.م) يتجاوز رصيدك المتاح للسحب ('||round(v_available_balance,2)||' ج.م).','available_balance',round(v_available_balance,2));
 end if;

 insert into public.payout_settlements(owner_id,amount,method,destination,status,created_at,updated_at)
 values(p_owner_id,round(p_amount,2),v_method,v_destination,'pending',v_now,v_now) returning id into v_settlement_id;

 insert into public.transactions(user_id,amount,type,status,payment_method,metadata,created_at,updated_at)
 values(p_owner_id,round(p_amount,2),'payout_pending','pending',v_method,
 jsonb_build_object('settlement_id',v_settlement_id,'destination',v_destination,'owner_name',coalesce(v_owner.name,'Unknown Owner'),
 'owner_phone',coalesce(v_owner.phone,''),'remaining_balance_after',round(v_available_balance-p_amount,2)),v_now,v_now);

 insert into public.notifications(user_id,title,body,type,is_read,created_at)
 select id,'طلب سحب أرباح جديد','طلب المالك '||coalesce(v_owner.name,'مالك')||' سحب '||round(p_amount,2)||' ج.م عبر '||v_method,'payout',false,v_now
 from public.users where role in ('admin','co_founder','cofounder','super_admin');

 return jsonb_build_object('success',true,'settlement_id',v_settlement_id,'available_balance',round(v_available_balance-p_amount,2),
 'method',v_method,'destination',v_destination,'message','تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.');
end;
$function$
;

-- Function: reset_fair_play_score_annually
CREATE OR REPLACE FUNCTION public.reset_fair_play_score_annually()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_current_year INT := EXTRACT(YEAR FROM CURRENT_TIMESTAMP);
BEGIN
  IF NEW.last_reset_year IS NULL OR v_current_year > NEW.last_reset_year THEN
    NEW.fair_play_score := 100;
    NEW.last_reset_year := v_current_year;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: respond_booking_reschedule_atomic
CREATE OR REPLACE FUNCTION public.respond_booking_reschedule_atomic(p_booking_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare b record; role_name text; new_total numeric; old_total numeric; duration_hours numeric; now_ts timestamptz:=now();
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 select role into role_name from public.users where id=auth.uid();
 if b.owner_id<>auth.uid() and b.user_id<>auth.uid() and b.created_by_user_id<>auth.uid()
    and coalesce(role_name,'') not in ('admin','co_founder','cofounder','super_admin')
 then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status in ('cancelled','completed') then return jsonb_build_object('success',false,'error','BOOKING_NOT_RESCHEDULABLE'); end if;
 if b.reschedule_status<>'pending' or b.proposed_start_time is null or b.proposed_end_time is null
 then return jsonb_build_object('success',false,'error','NO_PENDING_RESCHEDULE'); end if;

 if not p_accept then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',true,'status','rejected','booking_id',p_booking_id);
 end if;

 if now_ts>=b.start_time then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','BOOKING_ALREADY_STARTED');
 end if;

 perform pg_advisory_xact_lock(hashtextextended(b.stadium_id::text,0));

 if exists(
   select 1 from public.bookings x
   where x.stadium_id=b.stadium_id and x.id<>b.id and x.status<>'cancelled'
     and x.start_time<b.proposed_end_time and x.end_time>b.proposed_start_time
 ) then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','SLOT_NO_LONGER_AVAILABLE');
 end if;

 duration_hours:=extract(epoch from(b.proposed_end_time-b.proposed_start_time))/3600;
 if duration_hours <= 0 or duration_hours > (select booking_max_duration_hours from public.platform_business_rules where id=1) then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','INVALID_DURATION');
 end if;

 select round(coalesce(s.price_per_hour,s.base_price,0)*duration_hours +
   case when b.rent_ball then coalesce((s.features->>'ballPrice')::numeric,0) else 0 end,2)
 into new_total
 from public.stadiums s where s.id=b.stadium_id for update;

 old_total:=round(coalesce(b.total_price,0),2);
 if new_total is null or new_total<=0 then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE');
 end if;

 if abs(new_total-old_total)>0.01 then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','PRICE_CHANGE_REQUIRES_REBOOKING','old_total',old_total,'new_total',new_total);
 end if;

 update public.bookings set start_time=b.proposed_start_time,end_time=b.proposed_end_time,
   reschedule_status='accepted',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts
 where id=p_booking_id;
 return jsonb_build_object('success',true,'status','accepted','booking_id',p_booking_id,'total_price',old_total);
end; $function$
;

-- Function: respond_to_challenge_atomic
CREATE OR REPLACE FUNCTION public.respond_to_challenge_atomic(p_booking_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'LEGACY_CHALLENGE_FLOW_DISABLED',
    'message', 'تم استبدال نظام الموافقة بنظام كود التحدي المباشر. التحديات الجديدة مؤكدة فور الإنشاء.'
  );
END;
$function$
;

-- Function: sanitize_user_phone
CREATE OR REPLACE FUNCTION public.sanitize_user_phone()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.phone IS NOT NULL AND TRIM(NEW.phone) = '' THEN
    NEW.phone := NULL;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: save_and_publish_1v1_tournament_atomic
CREATE OR REPLACE FUNCTION public.save_and_publish_1v1_tournament_atomic(p_tournament_id uuid, p_players jsonb, p_champion_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_role text; v_tournament record; v_champion record;
  v_now timestamptz := timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    raise exception 'Unauthorized: Only admins can publish tournaments';
  end if;

  select * into v_tournament from public.vsp_1v1_tournaments
  where id=p_tournament_id and status in ('in_progress','completed') for update;
  if not found then raise exception 'البطولة ليست في حالة تسمح باعتماد النتائج.'; end if;

  select * into v_champion from public.vsp_1v1_tournament_players
  where id=p_champion_player_id and tournament_id=p_tournament_id and payment_status='paid' for update;
  if not found then raise exception 'يجب اختيار بطل من اللاعبين المسددين في هذه البطولة.'; end if;

  if exists (
    select 1 from public.vsp_1v1_tournament_players
    where tournament_id=p_tournament_id and payment_status='paid'
      and coalesce(rounds_played,0) < 1
  ) then
    raise exception 'يجب إدخال عدد الجولات التي لعبها كل لاعب قبل نشر النتائج.';
  end if;

  update public.vsp_1v1_tournament_players
  set total_points =
      greatest(coalesce(tackles,0),0)
      + greatest(coalesce(goals,0),0)
      + greatest(coalesce(skills,0),0),
      updated_at=v_now
  where tournament_id=p_tournament_id and payment_status='paid';

  update public.vsp_1v1_tournaments
  set status='published', published_at=v_now,
      champion_player_id=p_champion_player_id,
      champion_user_id=v_champion.user_id, updated_at=v_now
  where id=p_tournament_id;

  if v_champion.user_id is not null and not exists (
    select 1 from public.player_trophies
    where user_id=v_champion.user_id and tournament_1v1_id=p_tournament_id
  ) then
    insert into public.player_trophies(id,user_id,tournament_1v1_id,title,prize_won,created_at)
    values(gen_random_uuid(),v_champion.user_id,p_tournament_id,
      'بطل تحدي 1v1 - ' || coalesce(v_tournament.name,'VSP 1v1'),
      coalesce(v_tournament.prize_amount,0),v_now);
  end if;

  return jsonb_build_object('success',true,'tournament_id',p_tournament_id,
    'champion_name',v_champion.player_name,'champion_user_id',v_champion.user_id,
    'champion_player_id',p_champion_player_id,'status','published');
end;
$function$
;

-- Function: send_chat_message_atomic
CREATE OR REPLACE FUNCTION public.send_chat_message_atomic(p_conversation_id uuid, p_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_text text := trim(coalesce(p_text,''));
  v_conv public.conversations%rowtype;
  v_user public.users%rowtype;
  v_msg public.chat_messages%rowtype;
  v_recipients uuid[] := ARRAY[]::uuid[];
  v_pid uuid;
  v_unread jsonb;
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF v_text='' THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;

  SELECT * INTO v_conv FROM public.conversations WHERE id=p_conversation_id FOR UPDATE;
  IF NOT FOUND OR NOT (v_uid = ANY(v_conv.participant_ids)) THEN
    RAISE EXCEPTION 'CONVERSATION_ACCESS_DENIED';
  END IF;
  IF NOT public.vsp_chat_write_allowed(p_conversation_id,v_uid) THEN
    RAISE EXCEPTION 'CHAT_READ_ONLY';
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id=v_uid;
  INSERT INTO public.chat_messages(
    conversation_id, booking_id, sender_id, sender_name, text, created_at, is_read, is_edited, deleted_for_users
  )
  VALUES(
    v_conv.id,
    v_conv.booking_id,
    v_uid,
    coalesce(v_user.name, 'VSP User'),
    v_text,
    timezone('utc',now()),
    false, false, ARRAY[]::uuid[]
  )
  RETURNING * INTO v_msg;

  v_unread := coalesce(v_conv.unread_counts,'{}'::jsonb);
  FOREACH v_pid IN ARRAY v_conv.participant_ids LOOP
    IF v_pid <> v_uid THEN
      v_unread := jsonb_set(v_unread, ARRAY[v_pid::text], to_jsonb(coalesce((v_unread->>v_pid::text)::int,0)+1), true);
      v_recipients := array_append(v_recipients,v_pid);
    END IF;
  END LOOP;

  UPDATE public.conversations
  SET last_message=v_text,
      last_message_time=timezone('utc',now()),
      unread_counts=v_unread,
      deleted_for_users=ARRAY[]::uuid[],
      updated_at=timezone('utc',now())
  WHERE id=v_conv.id;

  RETURN jsonb_build_object(
    'success',true,
    'message_id',v_msg.id,
    'booking_id',v_conv.booking_id,
    'recipients',to_jsonb(v_recipients),
    'sender_name',coalesce(v_user.name,'VSP User'),
    'message_text',v_text
  );
END;
$function$
;

-- Function: send_support_ticket_message_atomic
CREATE OR REPLACE FUNCTION public.send_support_ticket_message_atomic(p_ticket_id uuid, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_body text := trim(coalesce(p_body,''));
  v_ticket public.support_tickets%rowtype;
  v_msg public.support_ticket_messages%rowtype;
  v_admin boolean := public.vsp_is_admin_actor();
BEGIN
  IF v_uid IS NULL OR coalesce(auth.role(),'') <> 'authenticated' THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;
  IF v_body='' THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id=p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;

  IF NOT v_admin AND v_ticket.requester_id <> v_uid THEN
    RAISE EXCEPTION 'TICKET_ACCESS_DENIED';
  END IF;
  IF v_ticket.status IN ('closed','resolved') AND NOT v_admin THEN
    RAISE EXCEPTION 'TICKET_CLOSED';
  END IF;

  INSERT INTO public.support_ticket_messages(ticket_id,sender_id,body,is_internal,created_at)
  VALUES(p_ticket_id,v_uid,v_body,false,timezone('utc',now()))
  RETURNING * INTO v_msg;

  UPDATE public.support_tickets
  SET updated_at=timezone('utc',now()),
      last_message_at=timezone('utc',now()),
      status=CASE
        WHEN v_admin THEN 'waiting_user'
        ELSE 'in_progress'
      END,
      resolved_at=CASE WHEN v_admin THEN NULL ELSE resolved_at END
  WHERE id=p_ticket_id;

  RETURN to_jsonb(v_msg);
END;
$function$
;

-- Function: set_user_role_on_signup
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(p_role text, p_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := coalesce(p_user_id, auth.uid());
  v_user record;
  v_ledger record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_USER_ID');
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    IF v_uid IS DISTINCT FROM auth.uid()
       AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  SELECT id, email, phone, role, is_registration_complete
  INTO v_user
  FROM public.users
  WHERE id = v_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF coalesce(v_user.is_registration_complete, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_ALREADY_COMPLETE');
  END IF;

  IF p_role NOT IN ('player', 'owner') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  IF p_role = 'owner' THEN
    -- Existing identity: preserve its original one-time trial entitlement.
    SELECT *
    INTO v_ledger
    FROM public.owner_trial_ledger
    WHERE lower(trim(email)) = lower(trim(v_user.email))
       OR (phone IS NOT NULL AND v_user.phone IS NOT NULL AND phone = v_user.phone)
    LIMIT 1;

    IF FOUND THEN
      IF v_ledger.original_trial_ends_at > now() THEN
        UPDATE public.users
        SET role = 'owner',
            subscription_plan = 'free_trial',
            trial_ends_at = v_ledger.original_trial_ends_at,
            subscription_expires_at = NULL
        WHERE id = v_uid AND coalesce(is_registration_complete, false) = false;
      ELSE
        UPDATE public.users
        SET role = 'owner',
            subscription_plan = 'expired',
            trial_ends_at = v_ledger.original_trial_ends_at,
            subscription_expires_at = NULL
        WHERE id = v_uid AND coalesce(is_registration_complete, false) = false;
      END IF;
    ELSE
      -- New owner: trial is available but is NOT started until the explicit CTA.
      UPDATE public.users
      SET role = 'owner',
          subscription_plan = 'expired',
          trial_ends_at = NULL,
          subscription_expires_at = NULL
      WHERE id = v_uid AND coalesce(is_registration_complete, false) = false;
    END IF;
  ELSE
    UPDATE public.users
    SET role = 'player'
    WHERE id = v_uid AND coalesce(is_registration_complete, false) = false;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'role', p_role,
    'trial_ends_at', (
      SELECT trial_ends_at FROM public.users WHERE id = v_uid
    )
  );
END;
$function$
;

-- Function: standardize_egypt_governorate
CREATE OR REPLACE FUNCTION public.standardize_egypt_governorate(p_gov text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
    IF p_gov IS NULL OR TRIM(p_gov) = '' THEN
        RETURN 'Cairo';
    END IF;
    
    RETURN CASE LOWER(TRIM(p_gov))
        WHEN 'القاهرة' THEN 'Cairo'
        WHEN 'al qahirah' THEN 'Cairo'
        WHEN 'cairo' THEN 'Cairo'
        WHEN 'الإسكندرية' THEN 'Alexandria'
        WHEN 'الاسكندرية' THEN 'Alexandria'
        WHEN 'alexandria' THEN 'Alexandria'
        WHEN 'alex' THEN 'Alexandria'
        WHEN 'الجيزة' THEN 'Giza'
        WHEN 'giza' THEN 'Giza'
        WHEN 'أسوان' THEN 'Aswan'
        WHEN 'اسوان' THEN 'Aswan'
        WHEN 'aswan' THEN 'Aswan'
        WHEN 'أسيوط' THEN 'Asyut'
        WHEN 'اسيوط' THEN 'Asyut'
        WHEN 'asyut' THEN 'Asyut'
        WHEN 'البحيرة' THEN 'Beheira'
        WHEN 'beheira' THEN 'Beheira'
        WHEN 'بني سويف' THEN 'Beni Suef'
        WHEN 'beni suef' THEN 'Beni Suef'
        WHEN 'الدقهلية' THEN 'Dakahlia'
        WHEN 'dakahlia' THEN 'Dakahlia'
        WHEN 'دمياط' THEN 'Damietta'
        WHEN 'damietta' THEN 'Damietta'
        WHEN 'الفيوم' THEN 'Faiyum'
        WHEN 'faiyum' THEN 'Faiyum'
        WHEN 'الغربية' THEN 'Gharbia'
        WHEN 'gharbia' THEN 'Gharbia'
        WHEN 'الإسماعيلية' THEN 'Ismailia'
        WHEN 'الاسماعيلية' THEN 'Ismailia'
        WHEN 'ismailia' THEN 'Ismailia'
        WHEN 'كفر الشيخ' THEN 'Kafr El Sheikh'
        WHEN 'kafr el sheikh' THEN 'Kafr El Sheikh'
        WHEN 'الأقصر' THEN 'Luxor'
        WHEN 'الاقصر' THEN 'Luxor'
        WHEN 'luxor' THEN 'Luxor'
        WHEN 'مطروح' THEN 'Matrouh'
        WHEN 'مرسى مطروح' THEN 'Matrouh'
        WHEN 'matrouh' THEN 'Matrouh'
        WHEN 'المنيا' THEN 'Minya'
        WHEN 'minya' THEN 'Minya'
        WHEN 'المنوفية' THEN 'Monufia'
        WHEN 'monufia' THEN 'Monufia'
        WHEN 'الوادي الجديد' THEN 'New Valley'
        WHEN 'new valley' THEN 'New Valley'
        WHEN 'شمال سيناء' THEN 'North Sinai'
        WHEN 'north sinai' THEN 'North Sinai'
        WHEN 'بورسعيد' THEN 'Port Said'
        WHEN 'port said' THEN 'Port Said'
        WHEN 'القليوبية' THEN 'Qalyubia'
        WHEN 'qalyubia' THEN 'Qalyubia'
        WHEN 'قنا' THEN 'Qena'
        WHEN 'qena' THEN 'Qena'
        WHEN 'البحر الأحمر' THEN 'Red Sea'
        WHEN 'red sea' THEN 'Red Sea'
        WHEN 'الشرقية' THEN 'Sharqia'
        WHEN 'sharqia' THEN 'Sharqia'
        WHEN 'سوهاج' THEN 'Sohag'
        WHEN 'sohag' THEN 'Sohag'
        WHEN 'جنوب سيناء' THEN 'South Sinai'
        WHEN 'south sinai' THEN 'South Sinai'
        WHEN 'السويس' THEN 'Suez'
        WHEN 'suez' THEN 'Suez'
        ELSE INITCAP(TRIM(p_gov))
    END;
END;
$function$
;

-- Function: start_championship_atomic
CREATE OR REPLACE FUNCTION public.start_championship_atomic(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_confirmed_count INT;
  v_lock_time TIMESTAMPTZ := now();
  v_matches_count INT := 0;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  -- Phase & Administrative Preconditions
  IF coalesce(v_champ.is_approved, false) != true THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_approved');
  END IF;

  IF coalesce(v_champ.creation_fee_paid, false) != true THEN
    RETURN jsonb_build_object('success', false, 'error', 'creation_fee_unpaid');
  END IF;

  IF v_champ.status != 'open' OR v_champ.registration_locked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'registration_already_locked_or_invalid_status');
  END IF;

  -- 1. Apply Lock Timestamp (Single SSOT)
  UPDATE public.championships
  SET registration_locked_at = v_lock_time,
      updated_at = v_lock_time
  WHERE id = p_championship_id;

  -- 2. Resolve unpaid teams: mark cancelled_unpaid
  UPDATE public.championship_registrations
  SET registration_status = 'cancelled_unpaid',
      updated_at = v_lock_time
  WHERE championship_id = p_championship_id
    AND registration_status = 'pending'
    AND payment_status = 'pending';

  -- 3. Verify eligible confirmed teams count
  SELECT count(*)::INT INTO v_confirmed_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id
    AND registration_status = 'confirmed';

  IF v_confirmed_count < 2 THEN
    RAISE EXCEPTION 'insufficient_confirmed_teams: %', v_confirmed_count;
  END IF;

  -- 4. Freeze all rosters with parity timestamp
  UPDATE public.championship_rosters
  SET is_frozen = true,
      frozen_at = v_lock_time
  WHERE championship_id = p_championship_id;

  -- 5. Generate tournament fixtures
  PERFORM public.generate_tournament_bracket_fixtures_internal(p_championship_id);

  SELECT count(*)::INT INTO v_matches_count
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'effective_phase', 'draw_ready',
    'confirmed_teams', v_confirmed_count,
    'matches_count', v_matches_count
  );
END;
$function$
;

-- Function: start_owner_trial
CREATE OR REPLACE FUNCTION public.start_owner_trial()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner public.users%ROWTYPE;
  v_plan public.subscription_plans%ROWTYPE;
  v_existing public.owner_trial_ledger%ROWTYPE;
  v_now timestamptz := now();
  v_ends timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_owner
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND OR v_owner.role <> 'owner' THEN
    RAISE EXCEPTION 'OWNER_ONLY' USING ERRCODE = '42501';
  END IF;

  IF v_owner.subscription_plan = 'pro'
     AND v_owner.subscription_expires_at IS NOT NULL
     AND v_owner.subscription_expires_at > v_now THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'SUBSCRIPTION_ALREADY_ACTIVE',
      'subscription_expires_at', v_owner.subscription_expires_at
    );
  END IF;

  IF v_owner.trial_ends_at IS NOT NULL
     AND v_owner.trial_ends_at > v_now THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_active', true,
      'trial_ends_at', v_owner.trial_ends_at
    );
  END IF;

  SELECT * INTO v_existing
  FROM public.owner_trial_ledger
  WHERE lower(trim(email)) = lower(trim(v_owner.email))
     OR (phone IS NOT NULL AND v_owner.phone IS NOT NULL AND phone = v_owner.phone)
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TRIAL_ALREADY_USED',
      'trial_ends_at', v_existing.original_trial_ends_at
    );
  END IF;

  SELECT * INTO v_plan
  FROM public.subscription_plans
  WHERE code = 'pro'
    AND is_active = true
  LIMIT 1;

  IF NOT FOUND OR v_plan.trial_days IS NULL OR v_plan.trial_days <= 0 THEN
    v_ends := v_now + INTERVAL '7 days';
  ELSE
    v_ends := v_now + make_interval(days => v_plan.trial_days);
  END IF;

  INSERT INTO public.owner_trial_ledger(
    email, phone, user_id, first_trial_started_at, original_trial_ends_at
  )
  VALUES (
    lower(trim(v_owner.email)),
    nullif(trim(v_owner.phone), ''),
    v_uid,
    v_now,
    v_ends
  );

  UPDATE public.users
  SET trial_ends_at = v_ends,
      updated_at = v_now
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'already_active', false,
    'trial_started_at', v_now,
    'trial_ends_at', v_ends,
    'trial_days', 7
  );
END;
$function$
;

-- Function: submit_challenge_result_atomic
CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(p_booking_id uuid, p_team_id uuid, p_outcome text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_team record;
  v_now timestamptz := timezone('utc', now());
  v_existing_team uuid;
  v_existing_outcome text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_outcome NOT IN ('homeWin','draw','awayWin') THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_OUTCOME');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); END IF;
  IF v_booking.booking_type <> 'challenge' THEN
    RETURN jsonb_build_object('success',false,'error','NOT_A_CHALLENGE');
  END IF;
  IF v_booking.end_time > v_now THEN
    RETURN jsonb_build_object('success',false,'error','MATCH_NOT_FINISHED');
  END IF;
  IF v_booking.status='cancelled' THEN
    RETURN jsonb_build_object('success',false,'error','BOOKING_CANCELLED');
  END IF;
  IF p_team_id NOT IN (v_booking.player_team_id,v_booking.opponent_team_id) THEN
    RETURN jsonb_build_object('success',false,'error','TEAM_NOT_IN_BOOKING');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
  IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller_id THEN
    RETURN jsonb_build_object('success',false,'error','CAPTAIN_ONLY');
  END IF;

  IF v_booking.match_result_status='confirmed' THEN
    RETURN jsonb_build_object('success',false,'error','RESULT_ALREADY_FINALIZED');
  END IF;

  -- If the same team edits its current submission, simply replace it.
  -- If the other team submitted a different result, keep the match unresolved
  -- and make the latest submission visible to both captains for correction.
  v_existing_team := v_booking.result_submitted_by_team_id;
  v_existing_outcome := v_booking.pending_outcome;

  IF v_existing_team IS NULL OR v_existing_team = p_team_id THEN
    UPDATE public.bookings SET
      pending_outcome=p_outcome,
      result_submitted_by_team_id=p_team_id,
      match_result_status='waitingOpponent',
      requires_admin_intervention=false,
      final_outcome=NULL,
      updated_at=v_now
    WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'state','waitingOpponent','finalized',false,
      'pending_outcome',p_outcome,'submitted_by_team_id',p_team_id);
  END IF;

  IF v_existing_outcome = p_outcome THEN
    UPDATE public.bookings SET
      final_outcome=p_outcome,
      match_result_status='confirmed',
      status='completed',
      requires_admin_intervention=false,
      pending_outcome=NULL,
      result_submitted_by_team_id=NULL,
      updated_at=v_now
    WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'state','confirmed','finalized',true,
      'final_outcome',p_outcome);
  END IF;

  -- Mismatch is NOT a dispute and never goes to Admin. Keep it waiting.
  UPDATE public.bookings SET
    pending_outcome=p_outcome,
    result_submitted_by_team_id=p_team_id,
    match_result_status='waitingOpponent',
    requires_admin_intervention=false,
    final_outcome=NULL,
    updated_at=v_now
  WHERE id=p_booking_id;

  RETURN jsonb_build_object('success',true,'state','mismatch','finalized',false,
    'error','RESULT_MISMATCH','latest_outcome',p_outcome,
    'latest_submitted_by_team_id',p_team_id);
END;
$function$
;

-- Function: submit_owner_verification
CREATE OR REPLACE FUNCTION public.submit_owner_verification(p_owner_id uuid DEFAULT NULL::uuid, p_additional_data jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_uid             uuid;
  v_has_stadium     boolean := false;
  v_existing_data   jsonb;
  v_merged_data     jsonb;
  v_docs            jsonb;
  v_cr              text;
  v_tc              text;
  v_idf             text;
  v_idb             text;
BEGIN
  -- Strict Authorization: Service role, or owner submitting own verification, or Admin
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF p_owner_id IS NOT NULL AND p_owner_id IS DISTINCT FROM v_caller_id THEN
      IF NOT public.is_admin_or_cofounder(v_caller_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
      END IF;
      v_uid := p_owner_id;
    ELSE
      v_uid := v_caller_id;
    END IF;
  ELSE
    v_uid := COALESCE(p_owner_id, v_caller_id);
  END IF;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
  END IF;

  -- Check user existence and lock row
  SELECT additional_data INTO v_existing_data
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  -- Check authoritative existence of active stadium
  SELECT EXISTS (
    SELECT 1 FROM public.stadiums 
    WHERE owner_id = v_uid AND COALESCE(is_deleted_by_owner, false) = false
  ) INTO v_has_stadium;

  IF NOT v_has_stadium THEN
    RETURN jsonb_build_object('success', false, 'error', 'ACTIVE_STADIUM_REQUIRED');
  END IF;

  -- Merge existing user additional_data with incoming p_additional_data
  v_merged_data := COALESCE(v_existing_data, '{}'::jsonb) || COALESCE(p_additional_data, '{}'::jsonb);
  v_docs := COALESCE(v_merged_data->'verificationDocuments', '{}'::jsonb);

  -- 1. Commercial Register (STRICT: only commercialRegisterUrl or commercialRegister)
  v_cr := COALESCE(
    nullif(trim(v_docs->>'commercialRegisterUrl'), ''),
    nullif(trim(v_docs->>'commercialRegister'), ''),
    nullif(trim(v_merged_data->>'commercialRegisterUrl'), ''),
    nullif(trim(v_merged_data->>'commercialRegister'), '')
  );
  IF v_cr IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_COMMERCIAL_REGISTER');
  END IF;

  -- 2. Tax Card (STRICT: only taxCardUrl or taxCard)
  v_tc := COALESCE(
    nullif(trim(v_docs->>'taxCardUrl'), ''),
    nullif(trim(v_docs->>'taxCard'), ''),
    nullif(trim(v_merged_data->>'taxCardUrl'), ''),
    nullif(trim(v_merged_data->>'taxCard'), '')
  );
  IF v_tc IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_TAX_CARD');
  END IF;

  -- 3. National ID Front (STRICT: only nationalIdFrontUrl or idFront)
  v_idf := COALESCE(
    nullif(trim(v_docs->>'nationalIdFrontUrl'), ''),
    nullif(trim(v_docs->>'idFront'), ''),
    nullif(trim(v_merged_data->>'nationalIdFrontUrl'), ''),
    nullif(trim(v_merged_data->>'idFront'), '')
  );
  IF v_idf IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_NATIONAL_ID_FRONT');
  END IF;

  -- 4. National ID Back (STRICT: only nationalIdBackUrl or idBack)
  v_idb := COALESCE(
    nullif(trim(v_docs->>'nationalIdBackUrl'), ''),
    nullif(trim(v_docs->>'idBack'), ''),
    nullif(trim(v_merged_data->>'nationalIdBackUrl'), ''),
    nullif(trim(v_merged_data->>'idBack'), '')
  );
  IF v_idb IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_NATIONAL_ID_BACK');
  END IF;

  -- Normalize verificationDocuments inside v_merged_data
  v_merged_data := jsonb_set(
    v_merged_data,
    '{verificationDocuments}',
    v_docs || jsonb_build_object(
      'commercialRegisterUrl', v_cr,
      'taxCardUrl', v_tc,
      'nationalIdFrontUrl', v_idf,
      'nationalIdBackUrl', v_idb
    ),
    true
  );

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET verification_status = 'pending',
      is_registration_complete = true,
      has_stadium = v_has_stadium,
      additional_data = v_merged_data,
      updated_at = now()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'verification_status', 'pending',
    'has_stadium', v_has_stadium,
    'message', 'Owner verification submitted successfully'
  );
END;
$function$
;

-- Function: submit_stadium_review_atomic
CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(p_stadium_id uuid, p_user_id uuid, p_rating integer, p_comment text DEFAULT NULL::text, p_user_name text DEFAULT NULL::text, p_user_image_url text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_stadium_owner   uuid;
  v_name            text;
  v_image           text;
  v_has_completed   boolean := false;
BEGIN
  IF p_stadium_id IS NULL OR p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'بيانات التقييم غير مكتملة.');
  END IF;

  -- Strict Authorization: Caller must be the reviewing user or service role
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF p_user_id IS DISTINCT FROM v_caller_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rating must be between 1 and 5');
  END IF;

  SELECT owner_id INTO v_stadium_owner FROM public.stadiums WHERE id = p_stadium_id;
  IF v_stadium_owner IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'الملعب غير موجود.');
  END IF;

  IF v_stadium_owner = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_review_own_stadium');
  END IF;

  -- Authoritative check: User must have an actually completed booking at this stadium
  SELECT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.stadium_id = p_stadium_id
      AND b.status = 'completed'
      AND (
        b.created_by_user_id = p_user_id
        OR b.user_id = p_user_id
        OR (b.joined_user_ids IS NOT NULL AND p_user_id = ANY(b.joined_user_ids))
        OR EXISTS (SELECT 1 FROM public.booking_players bp WHERE bp.booking_id = b.id AND bp.user_id = p_user_id)
      )
  ) INTO v_has_completed;

  IF NOT v_has_completed THEN
    RETURN jsonb_build_object('success', false, 'error', 'must_have_completed_booking');
  END IF;

  -- Pull canonical identity from public.users with fallback to parameters
  SELECT COALESCE(nullif(trim(name), ''), nullif(trim(p_user_name), ''), 'لاعب'),
         COALESCE(profile_image_url, nullif(trim(p_user_image_url), ''), '')
  INTO v_name, v_image
  FROM public.users
  WHERE id = p_user_id;

  INSERT INTO public.reviews (
    stadium_id, user_id, user_name, user_image_url, rating, review_text, created_at
  ) VALUES (
    p_stadium_id, p_user_id, v_name, v_image, p_rating, trim(COALESCE(p_comment, '')), timezone('utc', now())
  )
  ON CONFLICT (stadium_id, user_id)
  DO UPDATE SET
    rating = EXCLUDED.rating,
    review_text = EXCLUDED.review_text,
    user_name = EXCLUDED.user_name,
    user_image_url = EXCLUDED.user_image_url,
    created_at = timezone('utc', now());

  -- Recalculate stadium aggregate rating & reviews_count
  UPDATE public.stadiums
  SET rating = (SELECT round(avg(r.rating)::numeric, 1) FROM public.reviews r WHERE r.stadium_id = p_stadium_id),
      reviews_count = (SELECT count(*) FROM public.reviews r WHERE r.stadium_id = p_stadium_id),
      updated_at = timezone('utc', now())
  WHERE id = p_stadium_id;

  RETURN jsonb_build_object('success', true, 'stadium_id', p_stadium_id, 'rating', p_rating);
END;
$function$
;

-- Function: submit_team_league_match_result
CREATE OR REPLACE FUNCTION public.submit_team_league_match_result(p_match_id uuid, p_team_id uuid, p_result text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_match              RECORD;
  v_user_id            UUID := auth.uid();
  v_is_captain         BOOLEAN := false;
  v_opp_sub            RECORD;
  v_new_status         TEXT;
  v_reconciled_outcome TEXT := NULL;
  v_home_res           TEXT;
  v_away_res           TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_result NOT IN ('win', 'draw', 'loss') THEN
    RAISE EXCEPTION 'Invalid result outcome. Must be win, draw, or loss.';
  END IF;

  -- FIX #1+#2: Use c.owner_id (not c.creator_id) and c.template_type (not c.type)
  SELECT tm.*, c.template_type AS champ_template_type, c.owner_id AS creator_id
  INTO v_match
  FROM public.tournament_matches tm
  JOIN public.championships c ON c.id = tm.championship_id
  WHERE tm.id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.champ_template_type != 'team_league' THEN
    RAISE EXCEPTION 'This RPC is strictly isolated for team_league matches';
  END IF;

  IF p_team_id != v_match.home_team_id AND p_team_id != v_match.away_team_id THEN
    RAISE EXCEPTION 'Team does not belong to this match';
  END IF;

  -- FIX #3: Use public.team_members (not public.players which does not exist)
  SELECT (captain_id = v_user_id) INTO v_is_captain
  FROM public.teams WHERE id = p_team_id;

  IF NOT v_is_captain THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_id = p_team_id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'You are not authorized to submit results for this team';
    END IF;
  END IF;

  -- Server-side 15-minute hard lock
  IF v_match.result_status = 'locked' OR
     (v_match.result_confirmed_at IS NOT NULL
      AND v_match.result_confirmed_at + INTERVAL '15 minutes' < clock_timestamp()) THEN
    UPDATE public.tournament_matches
    SET result_status    = 'locked',
        result_locked_at = COALESCE(result_locked_at, clock_timestamp())
    WHERE id = p_match_id;
    RAISE EXCEPTION 'MATCH_RESULT_LOCKED: Result is permanently locked and cannot be modified';
  END IF;

  -- Upsert this team submission
  INSERT INTO public.team_league_match_submissions (
    match_id, team_id, submitted_by, result, submitted_at, submission_version
  ) VALUES (
    p_match_id, p_team_id, v_user_id, p_result, clock_timestamp(), 1
  )
  ON CONFLICT (match_id, team_id) DO UPDATE SET
    submitted_by       = EXCLUDED.submitted_by,
    result             = EXCLUDED.result,
    submitted_at       = clock_timestamp(),
    submission_version = public.team_league_match_submissions.submission_version + 1;

  -- Check opponent submission
  SELECT * INTO v_opp_sub
  FROM public.team_league_match_submissions
  WHERE match_id = p_match_id AND team_id != p_team_id;

  IF v_opp_sub.id IS NULL THEN
    v_new_status := 'awaiting_submissions';
  ELSE
    IF p_team_id = v_match.home_team_id THEN
      v_home_res := p_result;
      v_away_res := v_opp_sub.result;
    ELSE
      v_home_res := v_opp_sub.result;
      v_away_res := p_result;
    END IF;

    IF v_home_res = 'win' AND v_away_res = 'loss' THEN
      v_reconciled_outcome := 'home_win';
      v_new_status         := 'awaiting_confirmation';
    ELSIF v_home_res = 'loss' AND v_away_res = 'win' THEN
      v_reconciled_outcome := 'away_win';
      v_new_status         := 'awaiting_confirmation';
    ELSIF v_home_res = 'draw' AND v_away_res = 'draw' THEN
      v_reconciled_outcome := 'draw';
      v_new_status         := 'awaiting_confirmation';
    ELSE
      v_reconciled_outcome := NULL;
      v_new_status         := 'disputed';
    END IF;
  END IF;

  UPDATE public.tournament_matches
  SET result_status      = v_new_status,
      confirmed_outcome  = CASE WHEN v_new_status = 'awaiting_confirmation' THEN v_reconciled_outcome ELSE NULL END,
      dispute_created_at = CASE WHEN v_new_status = 'disputed' THEN COALESCE(dispute_created_at, clock_timestamp()) ELSE NULL END
  WHERE id = p_match_id;

  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, team_id, actor_id, action, payload
  ) VALUES (
    p_match_id, v_match.championship_id, p_team_id, v_user_id,
    'submit_result',
    jsonb_build_object(
      'result', p_result,
      'resulting_status', v_new_status,
      'reconciled_outcome', v_reconciled_outcome
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'match_id', p_match_id,
    'result_status', v_new_status,
    'reconciled_outcome', v_reconciled_outcome
  );
END;
$function$
;

-- Function: sync_booking_players_table
CREATE OR REPLACE FUNCTION public.sync_booking_players_table()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 1. Remove players who are no longer in joined_user_ids
  IF TG_OP = 'UPDATE' THEN
    DELETE FROM public.booking_players
    WHERE booking_id = NEW.id
      AND user_id NOT IN (
        SELECT unnest(COALESCE(NEW.joined_user_ids, ARRAY[]::uuid[]))
      );
  END IF;

  -- 2. Insert new players
  IF NEW.joined_user_ids IS NOT NULL AND array_length(NEW.joined_user_ids, 1) > 0 THEN
    INSERT INTO public.booking_players (booking_id, user_id, joined_at)
    SELECT NEW.id, uid, NOW()
    FROM unnest(NEW.joined_user_ids) AS uid
    ON CONFLICT (booking_id, user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: sync_booking_public_feed
CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE' then
    delete from public.booking_public_feed where id=old.id;
    return old;
  end if;

  if new.is_private=false
     and new.booking_type<>'open_join'
     and new.status in ('pending','confirmed','completed') then
    insert into public.booking_public_feed (
      id,stadium_id,stadium_name,stadium_image_url,start_time,end_time,operational_date,
      booking_type,player_team_id,player_team_name,player_team_logo_url,host_name,host_avatar_url,
      opponent_team_id,opponent_team_name,opponent_team_logo_url,is_private,rent_ball,total_price,currency,
      status,match_result_status,home_score,away_score,final_outcome,current_players,players_per_team,
      total_field_capacity,matchup_mode,matchup_closed_at,created_at,updated_at
    ) values (
      new.id,new.stadium_id,new.stadium_name,new.stadium_image_url,new.start_time,new.end_time,new.operational_date,
      new.booking_type,new.player_team_id,new.player_team_name,new.player_team_logo_url,new.host_name,new.host_avatar_url,
      new.opponent_team_id,new.opponent_team_name,new.opponent_team_logo_url,new.is_private,new.rent_ball,new.total_price,new.currency,
      new.status,new.match_result_status,new.home_score,new.away_score,new.final_outcome,new.current_players,new.max_players,
      new.total_field_capacity,new.matchup_mode,new.matchup_closed_at,new.created_at,new.updated_at
    )
    on conflict(id) do update set
      stadium_id=excluded.stadium_id,stadium_name=excluded.stadium_name,stadium_image_url=excluded.stadium_image_url,
      start_time=excluded.start_time,end_time=excluded.end_time,operational_date=excluded.operational_date,
      booking_type=excluded.booking_type,player_team_id=excluded.player_team_id,player_team_name=excluded.player_team_name,
      player_team_logo_url=excluded.player_team_logo_url,host_name=excluded.host_name,host_avatar_url=excluded.host_avatar_url,
      opponent_team_id=excluded.opponent_team_id,opponent_team_name=excluded.opponent_team_name,
      opponent_team_logo_url=excluded.opponent_team_logo,is_private=excluded.is_private,rent_ball=excluded.rent_ball,
      total_price=excluded.total_price,currency=excluded.currency,status=excluded.status,
      match_result_status=excluded.match_result_status,home_score=excluded.home_score,away_score=excluded.away_score,
      final_outcome=excluded.final_outcome,current_players=excluded.current_players,players_per_team=excluded.players_per_team,
      total_field_capacity=excluded.total_field_capacity,matchup_mode=excluded.matchup_mode,
      matchup_closed_at=excluded.matchup_closed_at,created_at=excluded.created_at,updated_at=excluded.updated_at;
  else
    delete from public.booking_public_feed where id=new.id;
  end if;
  return new;
end;
$function$
;

-- Function: sync_booking_user_ids
CREATE OR REPLACE FUNCTION public.sync_booking_user_ids()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.created_by_user_id IS NULL AND NEW.user_id IS NOT NULL THEN
    NEW.created_by_user_id := NEW.user_id;
  END IF;
  IF NEW.user_id IS NULL AND NEW.created_by_user_id IS NOT NULL THEN
    NEW.user_id := NEW.created_by_user_id;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: sync_head_to_head_on_result_insert
CREATE OR REPLACE FUNCTION public.sync_head_to_head_on_result_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_first_team UUID;
    v_second_team UUID;
    v_first_wins_inc INT := 0;
    v_second_wins_inc INT := 0;
    v_draws_inc INT := 0;
BEGIN
    IF NEW.team_a_id < NEW.team_b_id THEN
        v_first_team := NEW.team_a_id;
        v_second_team := NEW.team_b_id;
        IF NEW.outcome = 'team_a_win' THEN
            v_first_wins_inc := 1;
        ELSIF NEW.outcome = 'team_b_win' THEN
            v_second_wins_inc := 1;
        ELSE
            v_draws_inc := 1;
        END IF;
    ELSE
        v_first_team := NEW.team_b_id;
        v_second_team := NEW.team_a_id;
        IF NEW.outcome = 'team_b_win' THEN
            v_first_wins_inc := 1;
        ELSIF NEW.outcome = 'team_a_win' THEN
            v_second_wins_inc := 1;
        ELSE
            v_draws_inc := 1;
        END IF;
    END IF;

    INSERT INTO public.team_head_to_head (
        team_a_id,
        team_b_id,
        team_a_wins,
        team_b_wins,
        draws,
        updated_at
    )
    VALUES (
        v_first_team,
        v_second_team,
        v_first_wins_inc,
        v_second_wins_inc,
        v_draws_inc,
        timezone('utc'::text, now())
    )
    ON CONFLICT (team_a_id, team_b_id) DO UPDATE SET
        team_a_wins = public.team_head_to_head.team_a_wins + EXCLUDED.team_a_wins,
        team_b_wins = public.team_head_to_head.team_b_wins + EXCLUDED.team_b_wins,
        draws = public.team_head_to_head.draws + EXCLUDED.draws,
        updated_at = timezone('utc'::text, now());

    RETURN NEW;
END;
$function$
;

-- Function: sync_notification_message_body
CREATE OR REPLACE FUNCTION public.sync_notification_message_body()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.message IS NULL AND NEW.body IS NOT NULL THEN
    NEW.message := NEW.body;
  ELSIF NEW.body IS NULL AND NEW.message IS NOT NULL THEN
    NEW.body := NEW.message;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: sync_owner_has_stadium
CREATE OR REPLACE FUNCTION public.sync_owner_has_stadium()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_owner_id UUID;
  v_has_active BOOLEAN;
BEGIN
  -- تحديد معرف المالك المعني بالعملية
  IF (TG_OP = 'DELETE') THEN
    v_owner_id := OLD.owner_id;
  ELSE
    v_owner_id := NEW.owner_id;
  END IF;

  IF v_owner_id IS NOT NULL THEN
    -- فحص ما إذا كان للمالك أي ملعب نشط غير محذوف
    SELECT EXISTS (
      SELECT 1 FROM public.stadiums 
      WHERE owner_id = v_owner_id AND is_deleted_by_owner = false
    ) INTO v_has_active;

    UPDATE public.users
    SET has_stadium = v_has_active,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_owner_id;
  END IF;

  -- في حال نقل ملكية الملعب وتغيير owner_id
  IF (TG_OP = 'UPDATE' AND OLD.owner_id IS DISTINCT FROM NEW.owner_id AND OLD.owner_id IS NOT NULL) THEN
    SELECT EXISTS (
      SELECT 1 FROM public.stadiums 
      WHERE owner_id = OLD.owner_id AND is_deleted_by_owner = false
    ) INTO v_has_active;

    UPDATE public.users
    SET has_stadium = v_has_active,
        updated_at = timezone('utc'::text, now())
    WHERE id = OLD.owner_id;
  END IF;

  RETURN NULL;
END;
$function$
;

-- Function: sync_owner_has_stadium_on_delete
CREATE OR REPLACE FUNCTION public.sync_owner_has_stadium_on_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_remaining_stadiums_count int;
BEGIN
  SELECT COUNT(*) INTO v_remaining_stadiums_count
  FROM public.stadiums
  WHERE owner_id::text = OLD.owner_id::text
    AND COALESCE(is_deleted_by_owner, false) = false;

  IF v_remaining_stadiums_count = 0 THEN
    UPDATE public.users
    SET has_stadium = false,
        updated_at = now()
    WHERE id::text = OLD.owner_id::text;
  END IF;

  RETURN OLD;
END;
$function$
;

-- Function: sync_owner_has_stadium_on_insert
CREATE OR REPLACE FUNCTION public.sync_owner_has_stadium_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- تحديث حالة المالك تلقائياً على السيرفر لضمان المزامنة 100%
  UPDATE public.users
  SET 
    has_stadium = true,
    updated_at = now()
  WHERE id::text = NEW.owner_id::text; -- تحويل الأنواع صراحة لضمان الحصانة
  
  RETURN NEW;
END;
$function$
;

-- Function: sync_owner_has_stadium_on_soft_delete
CREATE OR REPLACE FUNCTION public.sync_owner_has_stadium_on_soft_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_remaining_stadiums int;
BEGIN
  IF NEW.is_deleted_by_owner = true AND OLD.is_deleted_by_owner = false THEN
    SELECT COUNT(*) INTO v_remaining_stadiums
    FROM public.stadiums
    WHERE owner_id = NEW.owner_id AND is_deleted_by_owner = false;

    IF v_remaining_stadiums = 0 THEN
      UPDATE public.users
      SET has_stadium = false, updated_at = NOW()
      WHERE id = NEW.owner_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: sync_owner_pro_features
CREATE OR REPLACE FUNCTION public.sync_owner_pro_features()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- إذا كان المالك مشتركاً في باقة Pro والاشتراك سارٍ
  IF (NEW.subscription_plan = 'pro' AND (NEW.subscription_expires_at IS NULL OR NEW.subscription_expires_at > NOW())) THEN
    UPDATE public.stadiums 
    SET is_featured = TRUE 
    WHERE owner_id::text = NEW.id::text;
  ELSE
    -- إعادة الملاعب للوضع العادي إذا كانت باقة عادية أو منتهية
    UPDATE public.stadiums 
    SET is_featured = FALSE 
    WHERE owner_id::text = NEW.id::text;
  END IF;
  
  RETURN NEW;
END;
$function$
;

-- Function: sync_payment_reconcile_state
CREATE OR REPLACE FUNCTION public.sync_payment_reconcile_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 1. Infer payment source
  IF lower(coalesce(NEW.payment_method, '')) = 'cash'
     OR upper(coalesce(NEW.payment_transaction_id, '')) LIKE 'MANUAL%' THEN
    NEW.payment_source := 'cash';
  ELSIF lower(coalesce(NEW.payment_method, '')) IN ('paymob', 'card', 'online', 'wallet', 'visa', 'mastercard', 'meeza') THEN
    NEW.payment_source := 'paymob';
  ELSIF lower(coalesce(NEW.payment_method, '')) = 'instapay' THEN
    NEW.payment_source := 'instapay';
  ELSIF lower(coalesce(NEW.payment_method, '')) = 'vodafone_cash' THEN
    NEW.payment_source := 'vodafone_cash';
  ELSIF lower(coalesce(NEW.payment_method, '')) = 'bank_transfer' THEN
    NEW.payment_source := 'bank_transfer';
  ELSE
    NEW.payment_source := 'unknown';
  END IF;

  -- 2. Reconcile payment state hierarchy (strictly preserving refund states)
  IF NEW.payment_status = 'refunded' THEN
    NEW.payment_reconcile_state := 'refunded';
  ELSIF NEW.payment_status = 'refund_failed' THEN
    NEW.payment_reconcile_state := 'refund_failed';
  ELSIF NEW.payment_status = 'refund_pending' THEN
    NEW.payment_reconcile_state := 'refund_pending';
  ELSIF NEW.payment_reconcile_state IN ('refunded', 'refund_failed', 'refund_pending') THEN
    -- Preserve explicit reconcile refund state
    NULL;
  ELSIF NEW.is_paid = TRUE OR NEW.payment_status IN ('paid', 'fully_paid') OR NEW.payment_reconcile_state = 'fully_paid' THEN
    NEW.payment_reconcile_state := 'fully_paid';
  ELSIF (coalesce(NEW.deposit_paid, 0) > 0 AND NEW.deposit_paid < NEW.total_price)
     OR NEW.payment_status = 'partially_paid'
     OR NEW.payment_reconcile_state = 'partially_paid' THEN
    NEW.payment_reconcile_state := 'partially_paid';
  ELSE
    NEW.payment_reconcile_state := 'unpaid';
  END IF;

  -- 3. Payment Matrix Enforcement (enforced on INSERT or when status/payment changes)
  IF current_setting('vsp.bypass_state_machine', true) IS DISTINCT FROM 'true' THEN
    IF TG_OP = 'INSERT' OR (OLD.status IS DISTINCT FROM NEW.status OR OLD.payment_reconcile_state IS DISTINCT FROM NEW.payment_reconcile_state) THEN
      IF NEW.status = 'pending' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "pending" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'confirmed' THEN
        -- Cash bookings can be confirmed while unpaid (awaiting pitch payment)
        -- Online bookings (paymob, card, wallet, online) CANNOT be confirmed while unpaid
        IF NEW.payment_reconcile_state = 'unpaid' THEN
          IF NEW.payment_source = 'paymob' OR lower(coalesce(NEW.payment_method, '')) IN ('paymob', 'card', 'wallet', 'online', 'visa', 'mastercard', 'meeza') THEN
            RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: Online booking with payment method "%" cannot be confirmed while unpaid', NEW.payment_method
              USING ERRCODE = 'P0005', DETAIL = 'ONLINE_BOOKING_CANNOT_BE_CONFIRMED_UNPAID';
          END IF;
        ELSIF NEW.payment_reconcile_state NOT IN ('partially_paid', 'fully_paid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "confirmed" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'completed' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid', 'partially_paid', 'fully_paid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "completed" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'cancelled' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid', 'refund_pending', 'refunded', 'refund_failed') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "cancelled" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'expired' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "expired" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: sync_player_phone_on_booking_insert
CREATE OR REPLACE FUNCTION public.sync_player_phone_on_booking_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.created_by_user_id is not null
     and new.owner_id is not null
     and new.created_by_user_id <> new.owner_id
     and nullif(trim(coalesce(new.player_phone, '')), '') is null
  then
    select nullif(trim(u.phone), '')
      into new.player_phone
    from public.users u
    where u.id = new.created_by_user_id;
  end if;

  return new;
end;
$function$
;

-- Function: sync_user_public_profile
CREATE OR REPLACE FUNCTION public.sync_user_public_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'DELETE' OR COALESCE(OLD.is_blocked,false) = true THEN
    DELETE FROM public.user_public_profiles WHERE id=OLD.id;
    RETURN COALESCE(OLD,NEW);
  END IF;
  INSERT INTO public.user_public_profiles(id,name,profile_image_url,position,updated_at)
  VALUES(NEW.id,NEW.name,NEW.profile_image_url,NEW.position,now())
  ON CONFLICT (id) DO UPDATE SET
    name=EXCLUDED.name,
    profile_image_url=EXCLUDED.profile_image_url,
    position=EXCLUDED.position,
    updated_at=now();
  RETURN NEW;
END;
$function$
;

-- Function: touch_1v1_tournament_player_updated_at
CREATE OR REPLACE FUNCTION public.touch_1v1_tournament_player_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$function$
;

-- Function: transfer_team_captaincy_atomic
CREATE OR REPLACE FUNCTION public.transfer_team_captaincy_atomic(p_team_id uuid, p_new_captain_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_cap uuid;
  v_current_captain_governorate text;
  v_new_captain_governorate text;
  v_new_user record;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  SELECT captain_id INTO v_cap FROM public.teams WHERE id = p_team_id FOR UPDATE;

  IF v_cap IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود.');
  END IF;

  IF v_cap <> auth.uid()
     AND COALESCE(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: نقل شارة الكابتنة من صلاحية الكابتن الحالي فقط.');
  END IF;

  IF p_new_captain_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'أنت بالفعل كابتن هذا الفريق.');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_new_captain_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'اللاعب المحدد ليس عضواً في هذا الفريق.');
  END IF;

  SELECT * INTO v_new_user FROM public.users WHERE id = p_new_captain_id;
  IF NOT FOUND OR COALESCE(v_new_user.is_blocked, false) = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'حساب اللاعب المحدد غير متاح أو محظور.');
  END IF;

  SELECT governorate INTO v_current_captain_governorate
  FROM public.users WHERE id = v_cap;

  v_new_captain_governorate := v_new_user.governorate;

  IF v_current_captain_governorate IS NULL OR btrim(v_current_captain_governorate) = ''
     OR v_new_captain_governorate IS NULL OR btrim(v_new_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'لا يمكن نقل الكابتنة بدون محافظة محددة.'
    );
  END IF;

  IF lower(btrim(v_current_captain_governorate)) <> lower(btrim(v_new_captain_governorate)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن نقل الكابتنة إلى لاعب من محافظة مختلفة عن محافظة الفريق.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE status = 'confirmed'
      AND (player_team_id = p_team_id OR opponent_team_id = p_team_id)
      AND end_time > now()
  ) OR EXISTS (
    SELECT 1 FROM public.championships
    WHERE status IN ('open', 'ongoing')
      AND p_team_id = ANY(COALESCE(joined_teams, ARRAY[]::uuid[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'active_match_or_tournament_error');
  END IF;

  UPDATE public.teams
  SET captain_id = p_new_captain_id,
      captain_name = COALESCE(v_new_user.name, 'Captain'),
      captain_phone = COALESCE(v_new_user.phone, ''),
      captain_image_url = COALESCE(v_new_user.profile_image_url, ''),
      governorate = v_new_captain_governorate,
      updated_at = v_now
  WHERE id = p_team_id;

  INSERT INTO public.notifications (user_id, title, body, type, created_at)
  VALUES (
    p_new_captain_id,
    'شارة الكابتنة ⚽',
    'تم نقل شارة قيادة الفريق إليك رسمياً. يمكنك الآن إدارة الفريق وقائمة اللاعبين.',
    'team_transfer',
    v_now
  );

  RETURN jsonb_build_object(
    'success', true,
    'team_id', p_team_id,
    'new_captain_id', p_new_captain_id,
    'new_captain_name', v_new_user.name
  );
END;
$function$
;

-- Function: transition_championship_status_atomic
CREATE OR REPLACE FUNCTION public.transition_championship_status_atomic(p_championship_id uuid, p_new_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_is_owner BOOLEAN;
  v_is_admin BOOLEAN;
  v_caller_role TEXT;
  v_matches_count INT;
BEGIN
  -- Validate target status value
  IF p_new_status NOT IN ('open', 'ongoing', 'completed', 'cancelled') THEN
    RAISE EXCEPTION 'INVALID_STATUS: Invalid championship status %', p_new_status;
  END IF;

  -- Lock and fetch championship
  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  -- Authorization check
  v_is_owner := (v_champ.owner_id IS NOT DISTINCT FROM auth.uid());
  SELECT (
    COALESCE(auth.role(), '') = 'service_role' OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'cofounder', 'super_admin')
    )
  ) INTO v_is_admin;

  IF NOT v_is_owner AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: only owner or admin can transition championship status';
  END IF;

  IF p_new_status = 'cancelled' THEN
    RAISE EXCEPTION 'Cancellation must go through cancel_championship_atomic';
  END IF;

  IF v_champ.status = p_new_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', p_new_status,
      'new_status', p_new_status,
      'message', 'Already in requested status'
    );
  END IF;

  -- Transition Guard:
  -- open -> ongoing: MUST have fixtures generated
  IF v_champ.status = 'open' AND p_new_status = 'ongoing' THEN
    SELECT COUNT(*) INTO v_matches_count
    FROM public.tournament_matches
    WHERE championship_id = p_championship_id;

    IF v_matches_count = 0 THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to ongoing without generated fixtures';
    END IF;

  -- ongoing -> completed: STRICT COMPLETION GUARD
  -- Cannot complete without crowning a champion and completing & confirming all matches
  ELSIF v_champ.status = 'ongoing' AND p_new_status = 'completed' THEN
    IF v_champ.champion_team_id IS NULL THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to completed without crowning champion via crown_tournament_champion_atomic';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.tournament_matches
      WHERE championship_id = p_championship_id
        AND (status != 'completed' OR COALESCE(result_status, '') NOT IN ('confirmed', 'locked'))
    ) THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to completed while there are uncompleted or unconfirmed matches';
    END IF;

  ELSE
    RAISE EXCEPTION 'INVALID_TRANSITION: Cannot transition championship from % to %',
      v_champ.status, p_new_status;
  END IF;

  UPDATE public.championships
  SET status = p_new_status,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', p_championship_id,
    'previous_status', v_champ.status,
    'new_status', p_new_status,
    'status', p_new_status
  );
END;
$function$
;

-- Function: trg_fn_enforce_booking_state_machine
CREATE OR REPLACE FUNCTION public.trg_fn_enforce_booking_state_machine()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Explicit session override for rare administrative manual data repairs only
  IF current_setting('vsp.bypass_state_machine', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- If status is not changing, proceed
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- STRICT WHITELIST STATE MACHINE:
  -- Allowed transitions:
  --   pending   -> confirmed
  --   pending   -> cancelled
  --   pending   -> expired
  --   confirmed -> completed
  --   confirmed -> cancelled

  IF OLD.status = 'pending' AND NEW.status IN ('confirmed', 'cancelled', 'expired') THEN
    RETURN NEW;
  ELSIF OLD.status = 'confirmed' AND NEW.status IN ('completed', 'cancelled') THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'ILLEGAL_STATE_TRANSITION: Transition from % to % is strictly forbidden by SSOT state machine.', OLD.status, NEW.status
      USING ERRCODE = 'P0004', DETAIL = 'BOOKING_STATE_MACHINE_VIOLATION';
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: trg_fn_normalize_governorate
CREATE OR REPLACE FUNCTION public.trg_fn_normalize_governorate()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NEW.governorate IS NOT NULL THEN
        NEW.governorate := public.normalize_governorate(NEW.governorate);
    END IF;
    RETURN NEW;
END;
$function$
;

-- Function: trg_fn_protect_user_sensitive_fields
CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_is_system_override boolean := (current_setting('vsp.system_override', true) = 'true');
    v_jwt_role           text := COALESCE(auth.jwt() ->> 'role', auth.role(), '');
    v_caller_id          uuid := auth.uid();
    v_is_admin           boolean := false;
BEGIN
    IF v_is_system_override THEN
        RETURN NEW;
    END IF;

    IF v_jwt_role = 'service_role' THEN
        RETURN NEW;
    END IF;

    IF v_caller_id IS NULL AND v_jwt_role = '' AND session_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT (role IN ('admin', 'co_founder', 'cofounder', 'super_admin'))
        INTO v_is_admin
        FROM public.users
        WHERE id = v_caller_id;
    END IF;

    IF COALESCE(v_is_admin, false) THEN 
        RETURN NEW; 
    END IF;

    IF OLD.role IS DISTINCT FROM NEW.role
       OR OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan
       OR OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at
       OR OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at
       OR OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees
       OR OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned
       OR OLD.no_show_count IS DISTINCT FROM NEW.no_show_count
       OR OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified
       OR OLD.is_email_verified IS DISTINCT FROM NEW.is_email_verified
       OR OLD.verification_status IS DISTINCT FROM NEW.verification_status
       OR OLD.is_blocked IS DISTINCT FROM NEW.is_blocked
       OR OLD.has_stadium IS DISTINCT FROM NEW.has_stadium
       OR OLD.is_registration_complete IS DISTINCT FROM NEW.is_registration_complete
       OR OLD.is_onboarding_confirmed IS DISTINCT FROM NEW.is_onboarding_confirmed
       OR OLD.accumulated_cash_debt IS DISTINCT FROM NEW.accumulated_cash_debt
       OR OLD.debt_limit IS DISTINCT FROM NEW.debt_limit
       OR OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Account security, financial state, and lifecycle fields are server-authoritative.'
          USING errcode = '42501', detail = 'UNAUTHORIZED_USER_SENSITIVE_UPDATE';
    END IF;

    RETURN NEW;
END;
$function$
;

-- Function: trg_protect_bookings_payment_fields
CREATE OR REPLACE FUNCTION public.trg_protect_bookings_payment_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.role() = 'service_role' OR public.is_admin_or_founder(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Block non-service callers from marking electronic bookings as paid
  IF OLD.is_paid IS NOT TRUE 
     AND NEW.is_paid IS TRUE 
     AND NEW.payment_method IN ('paymob', 'card', 'wallet') 
     AND (NEW.webhook_verified IS NOT TRUE OR NEW.paymob_txn_id IS NULL) THEN
    RAISE EXCEPTION 'Security Alert: Online booking payments cannot be verified directly from client.';
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$function$
;

-- Function: trg_standardize_1v1_tournament_governorate
CREATE OR REPLACE FUNCTION public.trg_standardize_1v1_tournament_governorate()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
    NEW.governorate := public.standardize_egypt_governorate(NEW.governorate);
    RETURN NEW;
END;
$function$
;

-- Function: trg_sync_challenge_booking_status
CREATE OR REPLACE FUNCTION public.trg_sync_challenge_booking_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.booking_type = 'challenge' THEN
    IF NEW.status = 'confirmed' AND (OLD.status IS DISTINCT FROM 'confirmed' OR NEW.challenge_status = 'ready') THEN
      NEW.challenge_status := 'confirmed';
    ELSIF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
      NEW.challenge_status := 'cancelled';
    ELSIF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
      NEW.challenge_status := 'completed';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: trigger_cancellation_refund_worker
CREATE OR REPLACE FUNCTION public.trigger_cancellation_refund_worker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_url TEXT := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/process_tournament_refund';
  v_secret TEXT;
BEGIN
  -- Obtain dedicated internal refund_worker secret strictly
  SELECT secret INTO v_secret
  FROM public.internal_function_secrets
  WHERE name = 'refund_worker'
  LIMIT 1;

  IF coalesce(v_secret, '') = '' THEN
    RAISE WARNING 'Dedicated refund_worker secret is missing; refund worker push skipped safely. Cron will reconcile.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('action', 'process_queue')
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Refund worker trigger exception (safe-bypass): %', SQLERRM;
  RETURN NEW;
END;
$function$
;

-- Function: trigger_claim_paid_web_subscription
CREATE OR REPLACE FUNCTION public.trigger_claim_paid_web_subscription()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ BEGIN PERFORM public.claim_paid_web_subscription_for_user(NEW.id); RETURN NEW; END; $function$
;

-- Function: unblock_user_atomic
CREATE OR REPLACE FUNCTION public.unblock_user_atomic(p_blocked_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  end if;

  delete from public.user_blocks
  where blocker_id = v_uid and blocked_user_id = p_blocked_user_id;

  return jsonb_build_object('success',true,'unblocked_user_id',p_blocked_user_id);
end;
$function$
;

-- Function: update_championship_atomic
CREATE OR REPLACE FUNCTION public.update_championship_atomic(p_championship_id uuid, p_updates jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actions      JSONB;
  v_user_id      UUID := auth.uid();
  v_editable     TEXT[];
  v_key          TEXT;
  v_safe_updates JSONB := '{}'::JSONB;
  v_blocked_keys TEXT[] := ARRAY[]::TEXT[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get authoritative actions from SSOT
  v_actions := public.get_championship_actions(p_championship_id);

  IF NOT (v_actions->>'can_edit')::boolean AND NOT (v_actions->>'can_edit_basic_info')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code',    'BLOCKED_BY_STATE',
      'reason',  v_actions->>'reason',
      'message', 'تعديل البطولة غير متاح في حالتها الحالية'
    );
  END IF;

  SELECT ARRAY(SELECT jsonb_array_elements_text(v_actions->'editable_fields')) INTO v_editable;

  -- Filter requested updates against editable fields (No admin bypass)
  FOR v_key IN SELECT jsonb_object_keys(p_updates)
  LOOP
    IF v_key = ANY(v_editable) THEN
      v_safe_updates := v_safe_updates || jsonb_build_object(v_key, p_updates->v_key);
    ELSE
      v_blocked_keys := array_append(v_blocked_keys, v_key);
    END IF;
  END LOOP;

  -- EXPLICIT REJECTION: If no allowed fields in updates, fail explicitly!
  IF v_safe_updates = '{}'::JSONB THEN
    RETURN jsonb_build_object(
      'success',        false,
      'code',           'NO_EDITABLE_FIELDS',
      'reason',         v_actions->>'reason',
      'blocked_fields', to_jsonb(v_blocked_keys),
      'message',        'التعديلات المطلوبة مقفولة في هذه المرحلة من البطولة'
    );
  END IF;

  v_safe_updates := v_safe_updates || jsonb_build_object('updated_at', now());

  UPDATE public.championships
  SET
    name                 = COALESCE((v_safe_updates->>'name')::TEXT,                 name),
    logo_url             = COALESCE((v_safe_updates->>'logo_url')::TEXT,             logo_url),
    rules                = COALESCE((v_safe_updates->>'rules')::TEXT,                rules),
    governorate          = COALESCE((v_safe_updates->>'governorate')::TEXT,          governorate),
    start_date           = COALESCE((v_safe_updates->>'start_date')::TIMESTAMPTZ,    start_date),
    end_date             = COALESCE((v_safe_updates->>'end_date')::TIMESTAMPTZ,      end_date),
    entry_fee            = COALESCE((v_safe_updates->>'entry_fee')::NUMERIC,         entry_fee),
    grand_prize          = COALESCE((v_safe_updates->>'grand_prize')::NUMERIC,       grand_prize),
    max_teams            = COALESCE((v_safe_updates->>'max_teams')::INTEGER,         max_teams),
    max_players_per_team = COALESCE((v_safe_updates->>'max_players_per_team')::INT,  max_players_per_team),
    min_players_per_team = COALESCE((v_safe_updates->>'min_players_per_team')::INT,  min_players_per_team),
    match_duration       = COALESCE((v_safe_updates->>'match_duration')::INTEGER,    match_duration),
    number_of_groups     = COALESCE((v_safe_updates->>'number_of_groups')::INTEGER,  number_of_groups),
    qualifying_per_group = COALESCE((v_safe_updates->>'qualifying_per_group')::INT,  qualifying_per_group),
    is_two_legs          = COALESCE((v_safe_updates->>'is_two_legs')::BOOLEAN,       is_two_legs),
    is_back_and_forth    = COALESCE((v_safe_updates->>'is_back_and_forth')::BOOLEAN, is_back_and_forth),
    winning_points       = COALESCE((v_safe_updates->>'winning_points')::INTEGER,    winning_points),
    draw_points          = COALESCE((v_safe_updates->>'draw_points')::INTEGER,       draw_points),
    loss_points          = COALESCE((v_safe_updates->>'loss_points')::INTEGER,       loss_points),
    updated_at           = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success',        true,
    'updated_fields', to_jsonb(ARRAY(SELECT jsonb_object_keys(v_safe_updates))),
    'blocked_fields', to_jsonb(v_blocked_keys),
    'allowed_reason', v_actions->>'reason'
  );
END;
$function$
;

-- Function: update_championship_roster_atomic
CREATE OR REPLACE FUNCTION public.update_championship_roster_atomic(p_championship_id uuid, p_team_id uuid, p_player_ids uuid[] DEFAULT ARRAY[]::uuid[], p_guest_names text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_champ RECORD;
  v_team RECORD;
  v_reg RECORD;
  v_roster_id UUID;
  v_player_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- Row lock first
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- Freeze check: locked registration or past open phase
  IF v_champ.registration_locked_at IS NOT NULL OR v_champ.status IN ('ongoing', 'completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_frozen_registration_locked');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT * INTO v_reg FROM public.championship_registrations 
  WHERE championship_id = p_championship_id AND team_id = p_team_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'registration_not_found');
  END IF;

  -- Duplicate player check inside p_player_ids
  IF coalesce(array_length(p_player_ids, 1), 0) > 0 THEN
    IF (SELECT count(DISTINCT pid) FROM unnest(p_player_ids) pid) <> array_length(p_player_ids, 1) THEN
      RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_PLAYERS_IN_ROSTER');
    END IF;
  END IF;

  -- Check team membership for each player_id
  IF EXISTS (
    SELECT 1 FROM unnest(coalesce(p_player_ids, ARRAY[]::UUID[])) pid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.team_members tm 
      WHERE tm.team_id = p_team_id AND tm.user_id = pid
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_team_player');
  END IF;

  -- Check player already registered with another team in the same championship
  IF EXISTS (
    SELECT 1 
    FROM public.championship_roster_players crp
    JOIN public.championship_rosters cr ON cr.id = crp.roster_id
    WHERE cr.championship_id = p_championship_id
      AND cr.team_id <> p_team_id
      AND crp.player_id = ANY(coalesce(p_player_ids, ARRAY[]::UUID[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYER_ALREADY_IN_ANOTHER_TEAM');
  END IF;

  -- Player count validation
  v_player_count := coalesce(array_length(p_player_ids, 1), 0) + coalesce(array_length(p_guest_names, 1), 0);
  IF v_player_count > coalesce(v_champ.max_players_per_team, 999) THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_too_large', 'max_allowed', v_champ.max_players_per_team);
  END IF;
  IF v_player_count < coalesce(v_champ.min_players_per_team, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_incomplete', 'min_required', v_champ.min_players_per_team);
  END IF;

  -- Upsert championship roster
  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at, updated_at
  )
  VALUES (
    v_reg.id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now(), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
  RETURNING id INTO v_roster_id;

  -- Synchronize roster players
  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  RETURN jsonb_build_object('success', true, 'roster_id', v_roster_id, 'player_count', v_player_count);
END;
$function$
;

-- Function: update_collective_manual_players_atomic
CREATE OR REPLACE FUNCTION public.update_collective_manual_players_atomic(p_booking_id uuid, p_user_id uuid, p_manual_player_count integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid:=auth.uid();
  v_joined_count integer;
  v_capacity integer;
  v_total integer;
  v_now timestamptz:=timezone('utc',now());
BEGIN
  IF v_uid IS NULL OR v_uid<>p_user_id THEN RAISE EXCEPTION 'PERMISSION_DENIED'; END IF;
  IF p_manual_player_count<0 THEN RAISE EXCEPTION 'INVALID_MANUAL_PLAYER_COUNT'; END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id=p_booking_id AND booking_type='open_join' AND is_private=true
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'COLLECTIVE_MATCH_NOT_FOUND'; END IF;
  IF v_uid<>v_booking.created_by_user_id THEN RAISE EXCEPTION 'HOST_ONLY'; END IF;

  IF v_booking.status IN ('cancelled','completed','expired') OR v_booking.end_time<=v_now THEN
    RAISE EXCEPTION 'MATCH_NOT_EDITABLE';
  END IF;

  v_joined_count:=coalesce(cardinality(v_booking.joined_user_ids),0);
  v_capacity:=coalesce(v_booking.total_field_capacity,v_booking.max_players,10);
  v_total:=v_joined_count+p_manual_player_count;

  IF v_total<1 THEN RAISE EXCEPTION 'INVALID_COLLECTIVE_TOTAL'; END IF;
  IF v_total>v_capacity THEN RAISE EXCEPTION 'EXCEEDS_TOTAL_STADIUM_CAPACITY'; END IF;

  PERFORM set_config('vsp.system_override','true',true);

  UPDATE public.bookings
  SET manual_player_count=p_manual_player_count,
      current_players=v_total,
      updated_at=v_now
  WHERE id=p_booking_id;

  RETURN jsonb_build_object(
    'success',true,'booking_id',p_booking_id,
    'manual_player_count',p_manual_player_count,
    'joined_players_count',v_joined_count,
    'current_players',v_total,
    'remaining_players',v_capacity-v_total
  );
END;
$function$
;

-- Function: update_host_spots_atomic
CREATE OR REPLACE FUNCTION public.update_host_spots_atomic(p_booking_id uuid, p_user_id uuid, p_new_host_spots integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking bookings%ROWTYPE;
  v_joined_count integer;
  v_capacity integer;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF auth.uid() IS NULL OR (auth.uid() != v_booking.created_by_user_id AND auth.uid() != v_booking.owner_id) THEN
      RAISE EXCEPTION 'Unauthorized: Only the host or owner can modify spots';
    END IF;
  END IF;

  v_joined_count := coalesce(cardinality(v_booking.joined_user_ids), 0);
  v_capacity := coalesce(v_booking.total_field_capacity, 10);

  IF (v_joined_count + p_new_host_spots) > v_capacity THEN
    RAISE EXCEPTION 'Exceeds total stadium capacity';
  END IF;

  UPDATE bookings
  SET 
    current_players = v_joined_count + p_new_host_spots,
    updated_at = timezone('utc'::text, now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$
;

-- Function: update_onboarding_confirmed_atomic
CREATE OR REPLACE FUNCTION public.update_onboarding_confirmed_atomic(p_user_id uuid, p_confirmed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
  if p_user_id is distinct from auth.uid() and not public.is_admin_or_cofounder(auth.uid()) then
    return jsonb_build_object('success',false,'error','UNAUTHORIZED');
  end if;

  perform set_config('vsp.system_override','true',true);
  update public.users
  set is_onboarding_confirmed=coalesce(p_confirmed,false),updated_at=now()
  where id=p_user_id;

  return jsonb_build_object('success',true);
end;
$function$
;

-- Function: update_owner_onboarding_atomic
CREATE OR REPLACE FUNCTION public.update_owner_onboarding_atomic(p_user_id uuid, p_additional_data jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_has_active_stadium boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
  END IF;

  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- Authoritatively derive whether owner has an active (non-soft-deleted) stadium
  SELECT EXISTS (
    SELECT 1 FROM public.stadiums
    WHERE owner_id = p_user_id AND coalesce(is_deleted_by_owner, false) = false
  ) INTO v_has_active_stadium;

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET has_stadium = v_has_active_stadium,
      is_onboarding_confirmed = true,
      additional_data = coalesce(additional_data, '{}'::jsonb) || coalesce(p_additional_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'has_stadium', v_has_active_stadium,
    'is_onboarding_confirmed', true
  );
END;
$function$
;

-- Function: update_owner_verification_document
CREATE OR REPLACE FUNCTION public.update_owner_verification_document(p_user_id uuid, p_doc_field_name text, p_file_url text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_existing        jsonb;
  v_data            jsonb;
BEGIN
  -- Strict Authorization: Service role, or user modifying own docs, or Admin
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF p_user_id IS DISTINCT FROM v_caller_id AND NOT public.is_admin_or_cofounder(v_caller_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  -- Strictly allowed document field names (removed generic nationalIdUrl)
  IF p_doc_field_name NOT IN (
    'nationalIdFrontUrl', 'nationalIdBackUrl',
    'commercialRegisterUrl', 'taxCardUrl', 'stadiumOwnershipProofUrl'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DOCUMENT_FIELD');
  END IF;

  IF nullif(trim(COALESCE(p_file_url, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DOCUMENT_URL');
  END IF;

  SELECT COALESCE(additional_data, '{}'::jsonb) INTO v_existing
  FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  v_data := jsonb_set(
    v_existing,
    '{verificationDocuments}',
    COALESCE(v_existing->'verificationDocuments', '{}'::jsonb) ||
      jsonb_build_object(p_doc_field_name, trim(p_file_url)),
    true
  );

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET additional_data = v_data,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object('success', true, 'doc_field_name', p_doc_field_name);
END;
$function$
;

-- Function: update_team_atomic
CREATE OR REPLACE FUNCTION public.update_team_atomic(p_team_id uuid, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_captain_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id
      AND (captain_id = auth.uid()
           OR coalesce(v_role, '') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT u.governorate
    INTO v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = p_team_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'محافظة الكابتن غير محددة.'
    );
  END IF;

  UPDATE public.teams
  SET
    name = coalesce(p_data->>'name', name),
    bio = coalesce(p_data->>'bio', bio),
    logo_url = coalesce(p_data->>'logo_url', logo_url),
    primary_color = coalesce(p_data->>'primary_color', primary_color),
    secondary_color = coalesce(p_data->>'secondary_color', secondary_color),
    governorate = v_captain_governorate,
    preferred_formation = coalesce(p_data->>'preferred_formation', preferred_formation),
    updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('success', true);
END;
$function$
;

-- Function: update_tournament_match_schedule_atomic
CREATE OR REPLACE FUNCTION public.update_tournament_match_schedule_atomic(p_match_id uuid, p_scheduled_time timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_match RECORD;
  v_champ RECORD;
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_duration INTEGER;
  v_start TIMESTAMPTZ;
  v_end TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_match
  FROM public.tournament_matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'MATCH_NOT_FOUND');
  END IF;

  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = v_match.championship_id;

  SELECT role INTO v_role FROM public.users WHERE id = v_user_id;

  IF v_champ.template_type = 'team_league' THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_LEAGUE_USES_OWN_SCHEDULING');
  END IF;

  IF v_champ.owner_id IS DISTINCT FROM v_user_id
     AND COALESCE(v_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF v_champ.status NOT IN ('open','ongoing') THEN
    RETURN jsonb_build_object('success', false, 'error', 'MATCH_SCHEDULING_LOCKED');
  END IF;

  IF p_scheduled_time IS NULL THEN
    UPDATE public.tournament_matches
    SET scheduled_time = NULL, updated_at = timezone('utc', now())
    WHERE id = p_match_id;

    RETURN jsonb_build_object('success', true, 'scheduled_time', NULL);
  END IF;

  v_duration := COALESCE(v_champ.match_duration, 45);
  v_start := p_scheduled_time;
  v_end := p_scheduled_time + make_interval(mins => v_duration);

  IF v_match.home_team_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.tournament_matches other
    WHERE other.championship_id = v_match.championship_id
      AND other.id <> v_match.id
      AND other.scheduled_time IS NOT NULL
      AND (other.home_team_id = v_match.home_team_id OR other.away_team_id = v_match.home_team_id)
      AND v_start < other.scheduled_time + make_interval(mins => v_duration)
      AND v_end > other.scheduled_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_SCHEDULE_CONFLICT');
  END IF;

  IF v_match.away_team_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.tournament_matches other
    WHERE other.championship_id = v_match.championship_id
      AND other.id <> v_match.id
      AND other.scheduled_time IS NOT NULL
      AND (other.home_team_id = v_match.away_team_id OR other.away_team_id = v_match.away_team_id)
      AND v_start < other.scheduled_time + make_interval(mins => v_duration)
      AND v_end > other.scheduled_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_SCHEDULE_CONFLICT');
  END IF;

  UPDATE public.tournament_matches
  SET scheduled_time = p_scheduled_time,
      updated_at = timezone('utc', now())
  WHERE id = p_match_id;

  RETURN jsonb_build_object('success', true, 'scheduled_time', p_scheduled_time);
END;
$function$
;

-- Function: validate_challenge_rosters
CREATE OR REPLACE FUNCTION public.validate_challenge_rosters()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(new.booking_type, '') <> 'challenge' THEN
    RETURN new;
  END IF;

  IF new.player_team_id IS NULL OR new.opponent_team_id IS NULL THEN
    RAISE EXCEPTION 'Challenge requires two teams.';
  END IF;

  -- Challenge match between two valid teams verified.
  RETURN new;
END;
$function$
;

-- Function: verify_booking_qr_atomic
CREATE OR REPLACE FUNCTION public.verify_booking_qr_atomic(p_booking_id uuid, p_qr_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_stadium RECORD;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_is_authorized BOOLEAN := false;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF v_caller_id IS NULL AND session_user NOT IN ('postgres', 'supabase_admin') AND COALESCE(auth.role(), '') != 'service_role' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'BOOKING_NOT_FOUND', 'message', 'الحجز غير موجود.');
    END IF;

    SELECT * INTO v_stadium FROM public.stadiums WHERE id = v_booking.stadium_id;

    -- Authorization check: Stadium owner or platform admin
    IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        v_is_authorized := true;
    ELSIF v_caller_id IS NOT NULL THEN
        IF v_stadium.owner_id = v_caller_id THEN
            v_is_authorized := true;
        ELSE
            SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
            IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
                v_is_authorized := true;
            END IF;
        END IF;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Only the stadium owner or platform admin can verify match attendance.'
            USING ERRCODE = '42501';
    END IF;

    -- 1. Single-use guard: check if already scanned
    IF v_booking.qr_scanned_at IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'QR_ALREADY_SCANNED', 'message', 'تم مسح رمز الحضور وتأكيد الحضور لهذا الحجز مسبقاً.');
    END IF;

    -- 2. State guard
    IF v_booking.status != 'confirmed' THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_BOOKING_STATUS', 'message', 'لا يمكن تأكيد حضور حجز غير مؤكد أو ملغي.');
    END IF;

    -- 3. Token hash verification
    IF v_booking.qr_hash IS NULL OR encode(digest(p_qr_token, 'sha256'), 'hex') != v_booking.qr_hash THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_QR_TOKEN', 'message', 'رمز الـ QR غير صالح أو لا يطابق بيانات هذا الحجز.');
    END IF;

    -- 4. Expiration check
    IF v_now > v_booking.qr_expires_at THEN
        RETURN jsonb_build_object('success', false, 'code', 'QR_EXPIRED', 'message', 'انتهت صلاحية رمز الـ QR المحدد.');
    END IF;

    -- 5. Mark completed and verified
    UPDATE public.bookings
    SET 
        qr_scanned_at = v_now,
        is_verified_by_owner = true,
        status = 'completed',
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'status', 'completed',
        'is_verified_by_owner', true,
        'message', 'تم تأكيد حضور المباراة واكتمال الحجز بنجاح.'
    );
END;
$function$
;

-- Function: verify_match_played
CREATE OR REPLACE FUNCTION public.verify_match_played(p_booking_id uuid, p_attended boolean, p_absent_team_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_caller_role text;
  v_is_authorized boolean := false;
BEGIN
  -- 1. Fetch booking record
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  -- 2. Strict Zero-Trust Authorization check (auth.uid = owner_id OR admin OR service_role)
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    v_is_authorized := true;
  ELSIF auth.uid() IS NOT NULL THEN
    IF v_booking.owner_id = auth.uid() THEN
      v_is_authorized := true;
    ELSE
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
        v_is_authorized := true;
      END IF;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Only the stadium owner or platform administrators can verify match attendance.'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Idempotency Check: Do not trigger duplicate Elo calculations, penalties, or status writes
  IF p_attended THEN
    IF v_booking.is_verified_by_owner IS TRUE AND v_booking.status = 'completed' THEN
      RETURN true;
    END IF;

    UPDATE public.bookings
    SET 
      is_verified_by_owner = true,
      status = 'completed',
      updated_at = now()
    WHERE id = p_booking_id;
  ELSE
    IF v_booking.status = 'cancelled' AND v_booking.is_verified_by_owner IS FALSE THEN
      RETURN true;
    END IF;

    UPDATE public.bookings
    SET 
      is_verified_by_owner = false,
      absent_team_id = p_absent_team_id,
      status = 'cancelled',
      updated_at = now()
    WHERE id = p_booking_id;

    IF p_absent_team_id IS NOT NULL THEN
      UPDATE public.teams SET attendance_score = GREATEST(0, attendance_score - 10) WHERE id::text = p_absent_team_id;
      UPDATE public.users SET no_show_count = no_show_count + 1 WHERE id = (SELECT captain_id FROM public.teams WHERE id::text = p_absent_team_id);
    END IF;
  END IF;

  RETURN true;
END;
$function$
;

-- Function: vsp_1v1_sync_player_total_from_stats
CREATE OR REPLACE FUNCTION public.vsp_1v1_sync_player_total_from_stats()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.total_points :=
    greatest(coalesce(new.tackles,0),0)
    + greatest(coalesce(new.goals,0),0)
    + greatest(coalesce(new.skills,0),0);
  return new;
end;
$function$
;

-- Function: vsp_chat_write_allowed
CREATE OR REPLACE FUNCTION public.vsp_chat_write_allowed(p_conversation_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_conv record;
  v_end timestamptz;
BEGIN
  SELECT * INTO v_conv
  FROM public.conversations
  WHERE id = p_conversation_id
    AND p_user_id = ANY(participant_ids);

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF coalesce(v_conv.type,'direct') <> 'direct' THEN
    RETURN false;
  END IF;

  IF v_conv.context_type IN ('booking','match','challenge') AND v_conv.booking_id IS NOT NULL THEN
    SELECT end_time INTO v_end FROM public.bookings WHERE id = v_conv.booking_id;
  ELSIF v_conv.context_type = 'tournament' AND v_conv.context_id IS NOT NULL THEN
    SELECT end_date INTO v_end FROM public.championships WHERE id = v_conv.context_id;
  ELSE
    RETURN false;
  END IF;

  RETURN v_end IS NOT NULL
     AND timezone('utc', now()) <= v_end + interval '7 days';
END;
$function$
;

-- Function: vsp_enforce_booking_operating_window
CREATE OR REPLACE FUNCTION public.vsp_enforce_booking_operating_window()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare s record;
begin
  -- Maintenance rows are themselves closures, not customer bookings.
  if coalesce(new.booking_type,'') = 'maintenance' then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.start_time is not distinct from old.start_time
     and new.end_time is not distinct from old.end_time then
    return new;
  end if;

  select opening_time, closing_time, break_start_time, break_end_time,
         is_split_shift, maintenance_until
    into s
  from public.stadiums
  where id = new.stadium_id
  for update;

  if not found then
    raise exception 'STADIUM_NOT_FOUND';
  end if;

  if not public.vsp_validate_stadium_booking_window(
    s.opening_time, s.closing_time, s.break_start_time, s.break_end_time,
    s.is_split_shift, s.maintenance_until, new.start_time, new.end_time
  ) then
    raise exception 'OUTSIDE_OPERATING_HOURS: موعد الحجز خارج ساعات تشغيل الملعب أو يتعارض مع فترة التوقف أو الصيانة.'
      using errcode = '22023';
  end if;

  return new;
end;
$function$
;

-- Function: vsp_guard_direct_booking_mutation
CREATE OR REPLACE FUNCTION public.vsp_guard_direct_booking_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text;
BEGIN
 IF coalesce(auth.role(),'')='service_role' OR current_user IN ('postgres','service_role') THEN RETURN NEW; END IF;
 SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
 IF coalesce(v_role,'') IN ('admin','co_founder','cofounder','super_admin') THEN RETURN NEW; END IF;

 IF NEW.owner_id IS DISTINCT FROM OLD.owner_id
 OR NEW.user_id IS DISTINCT FROM OLD.user_id
 OR NEW.created_by_user_id IS DISTINCT FROM OLD.created_by_user_id
 OR NEW.stadium_id IS DISTINCT FROM OLD.stadium_id
 OR NEW.total_price IS DISTINCT FROM OLD.total_price
 OR NEW.vsp_commission IS DISTINCT FROM OLD.vsp_commission
 OR NEW.gateway_fee IS DISTINCT FROM OLD.gateway_fee
 OR NEW.platform_fee IS DISTINCT FROM OLD.platform_fee
 OR NEW.deposit_paid IS DISTINCT FROM OLD.deposit_paid
 OR NEW.is_deposit_paid IS DISTINCT FROM OLD.is_deposit_paid
 OR NEW.is_paid IS DISTINCT FROM OLD.is_paid
 OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
 OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
 OR NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
 OR NEW.status IS DISTINCT FROM OLD.status
 OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
 OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason
 OR NEW.created_at IS DISTINCT FROM OLD.created_at
 THEN
   RAISE EXCEPTION 'BOOKING_CORE_FIELDS_REQUIRE_SERVER_WORKFLOW';
 END IF;
 RETURN NEW;
END;$function$
;

-- Function: vsp_guard_sensitive_owner_profile_changes
CREATE OR REPLACE FUNCTION public.vsp_guard_sensitive_owner_profile_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller uuid := auth.uid();
  v_recent_password_auth boolean := false;
begin
  if TG_OP <> 'UPDATE' then
    return NEW;
  end if;

  if v_caller is null or v_caller <> OLD.id then
    return NEW;
  end if;

  if (NEW.phone is distinct from OLD.phone)
     or (NEW.p2p_instapay is distinct from OLD.p2p_instapay)
     or (NEW.p2p_vodafone is distinct from OLD.p2p_vodafone)
     or (NEW.p2p_bank is distinct from OLD.p2p_bank) then

    select exists (
      select 1
      from jsonb_array_elements(
        coalesce(auth.jwt()->'amr', '[]'::jsonb)
      ) as amr
      where amr->>'method' = 'password'
        and (amr->>'timestamp') ~ '^[0-9]+$'
        and to_timestamp((amr->>'timestamp')::double precision) >= now() - interval '10 minutes'
    )
    into v_recent_password_auth;

    if not v_recent_password_auth then
      raise exception 'recent_password_verification_required';
    end if;
  end if;

  return NEW;
end;
$function$
;

-- Function: vsp_guard_stadium_owner_rules
CREATE OR REPLACE FUNCTION public.vsp_guard_stadium_owner_rules()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval               record;
  v_caller             uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.owner_id IS NULL THEN
      RAISE EXCEPTION 'stadium_owner_required';
    END IF;

    -- Concurrency lock on owner record
    PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;

    SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(NEW.owner_id);
    IF NOT v_eval.allowed THEN
      RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: %', v_eval.message
        USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
    END IF;

    NEW.is_verified := false;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF v_caller = OLD.owner_id AND NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
      RAISE EXCEPTION 'owner_cannot_reassign_stadium: لا يمكن نقل ملكية الملعب لمستخدم آخر.';
    END IF;

    -- Stadium Reactivation Limit:
    -- When un-deleting a soft-deleted stadium (is_deleted_by_owner: true -> false)
    IF OLD.is_deleted_by_owner IS TRUE AND NEW.is_deleted_by_owner IS FALSE THEN
      PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;

      -- Check if reactivating this stadium would exceed allowed capacity
      SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(NEW.owner_id, NEW.id);
      IF NOT v_eval.allowed THEN
        RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: %', v_eval.message
          USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
      END IF;
    END IF;

    -- Reset verification if stadium critical specs changed by owner
    IF v_caller = OLD.owner_id THEN
      IF NEW.name IS DISTINCT FROM OLD.name
         OR NEW.location IS DISTINCT FROM OLD.location
         OR NEW.governorate IS DISTINCT FROM OLD.governorate
         OR NEW.price_per_hour IS DISTINCT FROM OLD.price_per_hour
         OR NEW.base_price IS DISTINCT FROM OLD.base_price
         OR NEW.players_per_team IS DISTINCT FROM OLD.players_per_team
         OR NEW.total_field_capacity IS DISTINCT FROM OLD.total_field_capacity
         OR NEW.opening_time IS DISTINCT FROM OLD.opening_time
         OR NEW.closing_time IS DISTINCT FROM OLD.closing_time
         OR NEW.needs_deposit IS DISTINCT FROM OLD.needs_deposit
         OR NEW.deposit_amount IS DISTINCT FROM OLD.deposit_amount
         OR NEW.images IS DISTINCT FROM OLD.images
         OR NEW.image_url IS DISTINCT FROM OLD.image_url
         OR NEW.features IS DISTINCT FROM OLD.features
         OR NEW.lat IS DISTINCT FROM OLD.lat
         OR NEW.lng IS DISTINCT FROM OLD.lng THEN
        NEW.is_verified := false;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: vsp_guard_team_league_structure
CREATE OR REPLACE FUNCTION public.vsp_guard_team_league_structure()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  joined_count integer;
BEGIN
  IF NEW.template_type = 'team_league' THEN
    NEW.entry_fee := 30;

    IF NEW.max_teams IS NULL OR NEW.max_teams < 4 OR NEW.max_teams > 8 THEN
      RAISE EXCEPTION 'Team League must support between 4 and 8 teams';
    END IF;

    NEW.winning_points := 3;
    NEW.draw_points := 1;
    NEW.loss_points := 0;
    NEW.is_back_and_forth := false;
    NEW.number_of_groups := 1;
    NEW.is_two_legs := false;
    NEW.grand_prize := 0;
    NEW.prize_pool := 0;

    IF TG_OP = 'UPDATE' THEN
      SELECT COALESCE(array_length(OLD.joined_teams, 1), 0)
      INTO joined_count;

      IF joined_count > 0 THEN
        IF NEW.entry_fee IS DISTINCT FROM OLD.entry_fee
           OR NEW.max_teams IS DISTINCT FROM OLD.max_teams
           OR NEW.winning_points IS DISTINCT FROM OLD.winning_points
           OR NEW.draw_points IS DISTINCT FROM OLD.draw_points
           OR NEW.loss_points IS DISTINCT FROM OLD.loss_points
           OR NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth
           OR NEW.number_of_groups IS DISTINCT FROM OLD.number_of_groups
           OR NEW.is_two_legs IS DISTINCT FROM OLD.is_two_legs
           OR NEW.grand_prize IS DISTINCT FROM OLD.grand_prize
           OR NEW.prize_pool IS DISTINCT FROM OLD.prize_pool THEN
          RAISE EXCEPTION 'هيكل دوري VSP ثابت بعد انضمام أول فريق';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: vsp_is_admin_actor
CREATE OR REPLACE FUNCTION public.vsp_is_admin_actor()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role IN ('admin','super_admin','cofounder','co_founder')
      AND coalesce(u.is_blocked,false)=false
  );
$function$
;

-- Function: vsp_is_adult_date_of_birth
CREATE OR REPLACE FUNCTION public.vsp_is_adult_date_of_birth(p_dob text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_raw text := trim(coalesce(p_dob, ''));
  v_date date;
begin
  if v_raw = '' or v_raw !~ '^\d{4}-\d{2}-\d{2}' then return false; end if;
  begin
    v_date := to_date(substr(v_raw, 1, 10), 'YYYY-MM-DD');
  exception when others then return false; end;
  if to_char(v_date, 'YYYY-MM-DD') <> substr(v_raw, 1, 10) then return false; end if;
  if v_date > current_date then return false; end if;
  return extract(year from age(current_date, v_date)) >= 18;
end;
$function$
;

-- Function: vsp_user_is_booking_participant
CREATE OR REPLACE FUNCTION public.vsp_user_is_booking_participant(p_booking_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.id = p_booking_id
      AND (
        b.owner_id = p_user_id
        OR b.user_id = p_user_id
        OR b.created_by_user_id = p_user_id
        OR p_user_id = ANY(coalesce(b.joined_user_ids, ARRAY[]::uuid[]))
      )
  );
$function$
;

-- Function: vsp_user_is_tournament_participant
CREATE OR REPLACE FUNCTION public.vsp_user_is_tournament_participant(p_championship_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.championships c
    WHERE c.id = p_championship_id
      AND c.owner_id = p_user_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.championship_registrations cr
    JOIN public.teams t ON t.id = cr.team_id
    LEFT JOIN public.team_members tm ON tm.team_id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND cr.registration_status IN ('pending','confirmed')
      AND (
        cr.captain_id = p_user_id
        OR t.captain_id = p_user_id
        OR tm.user_id = p_user_id
      )
  );
$function$
;

-- Function: vsp_validate_stadium_booking_window
CREATE OR REPLACE FUNCTION public.vsp_validate_stadium_booking_window(p_opening_time time without time zone, p_closing_time time without time zone, p_break_start_time time without time zone, p_break_end_time time without time zone, p_is_split_shift boolean, p_maintenance_until timestamp with time zone, p_start_time timestamp with time zone, p_end_time timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_local_start timestamp;
  v_local_end timestamp;
  v_day date;
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_break_start_ts timestamp;
  v_break_end_ts timestamp;
begin
  if p_end_time <= p_start_time then return false; end if;
  if p_maintenance_until is not null and p_end_time > p_maintenance_until then return false; end if;

  v_local_start := timezone('Africa/Cairo', p_start_time);
  v_local_end := timezone('Africa/Cairo', p_end_time);
  v_day := v_local_start::date;

  if p_opening_time is null or p_closing_time is null then return false; end if;

  v_open_ts := v_day + p_opening_time;
  v_close_ts := v_day + p_closing_time;

  if p_closing_time <= p_opening_time then
    v_close_ts := v_close_ts + interval '1 day';
    if v_local_start < v_open_ts then
      v_open_ts := v_open_ts - interval '1 day';
      v_close_ts := v_close_ts - interval '1 day';
    end if;
  end if;

  if v_local_start < v_open_ts or v_local_end > v_close_ts then return false; end if;

  if coalesce(p_is_split_shift,false)
     and p_break_start_time is not null
     and p_break_end_time is not null
     and p_break_start_time <> p_break_end_time then
    v_break_start_ts := v_day + p_break_start_time;
    v_break_end_ts := v_day + p_break_end_time;

    if p_break_end_time <= p_break_start_time then
      v_break_end_ts := v_break_end_ts + interval '1 day';
      if v_local_start < v_break_start_ts then
        v_break_start_ts := v_break_start_ts - interval '1 day';
        v_break_end_ts := v_break_end_ts - interval '1 day';
      end if;
    end if;

    if v_local_start < v_break_end_ts and v_local_end > v_break_start_ts then
      return false;
    end if;
  end if;

  return true;
end;
$function$
;

-- Function: withdraw_team_from_championship_atomic
CREATE OR REPLACE FUNCTION public.withdraw_team_from_championship_atomic(p_championship_id uuid, p_team_id uuid, p_reason text DEFAULT 'انسحاب الفريق'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_champ record; v_caller uuid:=auth.uid(); v_role text; v_order record;
  v_minutes numeric; v_refund numeric; v_gateway numeric:=0; v_within boolean:=false; v_authorized boolean:=false;
begin
  if v_caller is null then return jsonb_build_object('success',false,'error','Authentication required'); end if;
  select * into v_champ from public.championships where id=p_championship_id for update;
  if not found then return jsonb_build_object('success',false,'error','البطولة غير موجودة'); end if;

  select role into v_role from public.users where id=v_caller;
  v_authorized:=coalesce(v_role in ('admin','co_founder','cofounder','super_admin'),false)
    or v_champ.owner_id=v_caller
    or exists(select 1 from public.teams t where t.id=p_team_id and t.captain_id=v_caller);
  if not v_authorized then return jsonb_build_object('success',false,'error','غير مصرح لك بسحب هذا الفريق'); end if;

  if not (
    p_team_id::text=any(coalesce(v_champ.joined_teams,array[]::text[]))
    or p_team_id::text=any(coalesce(v_champ.paid_teams,array[]::text[]))
  ) then
    return jsonb_build_object('success',false,'error','الفريق غير مشترك في هذه البطولة');
  end if;

  if v_champ.status not in ('open','registration_open') then
    return jsonb_build_object('success',false,'error','لا يمكن الانسحاب بعد إغلاق التسجيل');
  end if;

  if coalesce(v_champ.template_type,'')='team_league' then
    select * into v_order from public.team_league_payments
    where championship_id=p_championship_id and team_id=p_team_id and payment_status='paid'
    order by created_at desc limit 1;
  else
    select * into v_order from public.tournament_orders
    where championship_id=p_championship_id and team_id=p_team_id and payment_status='paid'
    order by created_at desc limit 1;
  end if;

  if found then
    v_minutes:=extract(epoch from(now()-v_order.created_at))/60.0;
    v_within:=v_minutes<=20;
    if v_within then
      v_refund:=round(v_order.amount,2);
    else
      select round(v_order.amount*coalesce(booking_paymob_local_rate,booking_paymob_rate,0)+coalesce(booking_paymob_fixed_fee,0),2)
      into v_gateway from public.platform_fee_config where id=1;
      v_refund:=greatest(0,round(v_order.amount-v_gateway,2));
    end if;

    return jsonb_build_object(
      'success',true,'refund_required',true,'refund_amount',v_refund,
      'gateway_fee_deducted',round(v_gateway,2),'within_grace_period',v_within,
      'order_reference',v_order.order_reference,'paymob_transaction_id',v_order.paymob_transaction_id,
      'championship_id',p_championship_id,'team_id',p_team_id
    );
  end if;

  update public.championships
  set joined_teams=array_remove(coalesce(joined_teams,array[]::text[]),p_team_id::text),
      paid_teams=array_remove(coalesce(paid_teams,array[]::text[]),p_team_id::text),
      updated_at=now()
  where id=p_championship_id;

  update public.tournament_orders set payment_status='cancelled_withdrawal',updated_at=now()
  where championship_id=p_championship_id and team_id=p_team_id and payment_status='pending';

  update public.team_league_payments set payment_status='cancelled_withdrawal',updated_at=now()
  where championship_id=p_championship_id and team_id=p_team_id and payment_status='pending';

  return jsonb_build_object('success',true,'refund_required',false,'championship_id',p_championship_id,'team_id',p_team_id);
end;
$function$
;



-- --------------------------------------------------------------------------
-- 9. TRIGGERS
-- --------------------------------------------------------------------------
DROP TRIGGER IF EXISTS "aaa_trg_enforce_booking_state_machine" ON public."bookings";
CREATE TRIGGER aaa_trg_enforce_booking_state_machine BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION trg_fn_enforce_booking_state_machine();

DROP TRIGGER IF EXISTS "trg_audit_bookings" ON public."bookings";
CREATE TRIGGER trg_audit_bookings AFTER DELETE OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS "trg_audit_bookings" ON public."bookings";
CREATE TRIGGER trg_audit_bookings AFTER DELETE OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS "trg_bookings_operating_window" ON public."bookings";
CREATE TRIGGER trg_bookings_operating_window BEFORE INSERT OR UPDATE OF start_time, end_time ON bookings FOR EACH ROW EXECUTE FUNCTION vsp_enforce_booking_operating_window();

DROP TRIGGER IF EXISTS "trg_bookings_operating_window" ON public."bookings";
CREATE TRIGGER trg_bookings_operating_window BEFORE INSERT OR UPDATE OF start_time, end_time ON bookings FOR EACH ROW EXECUTE FUNCTION vsp_enforce_booking_operating_window();

DROP TRIGGER IF EXISTS "trg_calculate_elo" ON public."bookings";
CREATE TRIGGER trg_calculate_elo BEFORE UPDATE OF status, final_outcome, match_result_status ON bookings FOR EACH ROW EXECUTE FUNCTION calculate_elo_on_match_completion();

DROP TRIGGER IF EXISTS "trg_guard_direct_booking_mutation" ON public."bookings";
CREATE TRIGGER trg_guard_direct_booking_mutation BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION vsp_guard_direct_booking_mutation();

DROP TRIGGER IF EXISTS "trg_normalize_booking_pending_fees" ON public."bookings";
CREATE TRIGGER trg_normalize_booking_pending_fees BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION normalize_booking_pending_fees();

DROP TRIGGER IF EXISTS "trg_normalize_booking_pending_fees" ON public."bookings";
CREATE TRIGGER trg_normalize_booking_pending_fees BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION normalize_booking_pending_fees();

DROP TRIGGER IF EXISTS "trg_notify_cash_booking_parties" ON public."bookings";
CREATE TRIGGER trg_notify_cash_booking_parties AFTER INSERT ON bookings FOR EACH ROW EXECUTE FUNCTION notify_cash_booking_parties();

DROP TRIGGER IF EXISTS "trg_prepare_collective_booking_fields" ON public."bookings";
CREATE TRIGGER trg_prepare_collective_booking_fields BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION prepare_collective_booking_fields();

DROP TRIGGER IF EXISTS "trg_prepare_collective_booking_fields" ON public."bookings";
CREATE TRIGGER trg_prepare_collective_booking_fields BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION prepare_collective_booking_fields();

DROP TRIGGER IF EXISTS "trg_prevent_late_cancellation" ON public."bookings";
CREATE TRIGGER trg_prevent_late_cancellation BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION prevent_late_cancellation();

DROP TRIGGER IF EXISTS "trg_protect_booking_sensitive_fields" ON public."bookings";
CREATE TRIGGER trg_protect_booking_sensitive_fields BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION protect_booking_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_protect_bookings_payment_fields" ON public."bookings";
CREATE TRIGGER trg_protect_bookings_payment_fields BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION protect_booking_payment_fields();

DROP TRIGGER IF EXISTS "trg_sync_booking_players" ON public."bookings";
CREATE TRIGGER trg_sync_booking_players AFTER INSERT OR UPDATE OF joined_user_ids ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_players_table();

DROP TRIGGER IF EXISTS "trg_sync_booking_players" ON public."bookings";
CREATE TRIGGER trg_sync_booking_players AFTER INSERT OR UPDATE OF joined_user_ids ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_players_table();

DROP TRIGGER IF EXISTS "trg_sync_booking_public_feed" ON public."bookings";
CREATE TRIGGER trg_sync_booking_public_feed AFTER INSERT OR DELETE OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_public_feed();

DROP TRIGGER IF EXISTS "trg_sync_booking_public_feed" ON public."bookings";
CREATE TRIGGER trg_sync_booking_public_feed AFTER INSERT OR DELETE OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_public_feed();

DROP TRIGGER IF EXISTS "trg_sync_booking_public_feed" ON public."bookings";
CREATE TRIGGER trg_sync_booking_public_feed AFTER INSERT OR DELETE OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_public_feed();

DROP TRIGGER IF EXISTS "trg_sync_booking_user_ids" ON public."bookings";
CREATE TRIGGER trg_sync_booking_user_ids BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_user_ids();

DROP TRIGGER IF EXISTS "trg_sync_booking_user_ids" ON public."bookings";
CREATE TRIGGER trg_sync_booking_user_ids BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_user_ids();

DROP TRIGGER IF EXISTS "trg_sync_challenge_booking_status" ON public."bookings";
CREATE TRIGGER trg_sync_challenge_booking_status BEFORE UPDATE OF status ON bookings FOR EACH ROW EXECUTE FUNCTION trg_sync_challenge_booking_status();

DROP TRIGGER IF EXISTS "trg_sync_player_phone_on_booking_insert" ON public."bookings";
CREATE TRIGGER trg_sync_player_phone_on_booking_insert BEFORE INSERT ON bookings FOR EACH ROW EXECUTE FUNCTION sync_player_phone_on_booking_insert();

DROP TRIGGER IF EXISTS "trg_validate_challenge_rosters" ON public."bookings";
CREATE TRIGGER trg_validate_challenge_rosters BEFORE INSERT OR UPDATE OF booking_type, player_team_id, opponent_team_id ON bookings FOR EACH ROW EXECUTE FUNCTION validate_challenge_rosters();

DROP TRIGGER IF EXISTS "trg_validate_challenge_rosters" ON public."bookings";
CREATE TRIGGER trg_validate_challenge_rosters BEFORE INSERT OR UPDATE OF booking_type, player_team_id, opponent_team_id ON bookings FOR EACH ROW EXECUTE FUNCTION validate_challenge_rosters();

DROP TRIGGER IF EXISTS "trigger_enforce_cash_restrictions" ON public."bookings";
CREATE TRIGGER trigger_enforce_cash_restrictions BEFORE INSERT ON bookings FOR EACH ROW EXECUTE FUNCTION enforce_cash_booking_restrictions();

DROP TRIGGER IF EXISTS "trigger_log_booking_payment" ON public."bookings";
CREATE TRIGGER trigger_log_booking_payment AFTER INSERT OR UPDATE OF is_paid, payment_status ON bookings FOR EACH ROW EXECUTE FUNCTION log_booking_payment_transaction();

DROP TRIGGER IF EXISTS "trigger_log_booking_payment" ON public."bookings";
CREATE TRIGGER trigger_log_booking_payment AFTER INSERT OR UPDATE OF is_paid, payment_status ON bookings FOR EACH ROW EXECUTE FUNCTION log_booking_payment_transaction();

DROP TRIGGER IF EXISTS "trigger_sync_payment_reconcile" ON public."bookings";
CREATE TRIGGER trigger_sync_payment_reconcile BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_payment_reconcile_state();

DROP TRIGGER IF EXISTS "trigger_sync_payment_reconcile" ON public."bookings";
CREATE TRIGGER trigger_sync_payment_reconcile BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_payment_reconcile_state();

DROP TRIGGER IF EXISTS "trg_cancellation_refund_queue_worker" ON public."cancellation_refund_queue";
CREATE TRIGGER trg_cancellation_refund_queue_worker AFTER INSERT ON cancellation_refund_queue FOR EACH ROW EXECUTE FUNCTION trigger_cancellation_refund_worker();

DROP TRIGGER IF EXISTS "trg_check_roster_player_single_championship" ON public."championship_roster_players";
CREATE TRIGGER trg_check_roster_player_single_championship BEFORE INSERT OR UPDATE ON championship_roster_players FOR EACH ROW EXECUTE FUNCTION check_roster_player_single_championship();

DROP TRIGGER IF EXISTS "trg_check_roster_player_single_championship" ON public."championship_roster_players";
CREATE TRIGGER trg_check_roster_player_single_championship BEFORE INSERT OR UPDATE ON championship_roster_players FOR EACH ROW EXECUTE FUNCTION check_roster_player_single_championship();

DROP TRIGGER IF EXISTS "trg_protect_championship_sensitive_fields" ON public."championships";
CREATE TRIGGER trg_protect_championship_sensitive_fields BEFORE INSERT OR UPDATE ON championships FOR EACH ROW EXECUTE FUNCTION protect_championship_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_protect_championship_sensitive_fields" ON public."championships";
CREATE TRIGGER trg_protect_championship_sensitive_fields BEFORE INSERT OR UPDATE ON championships FOR EACH ROW EXECUTE FUNCTION protect_championship_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_vsp_guard_team_league_structure" ON public."championships";
CREATE TRIGGER trg_vsp_guard_team_league_structure BEFORE INSERT OR UPDATE ON championships FOR EACH ROW EXECUTE FUNCTION vsp_guard_team_league_structure();

DROP TRIGGER IF EXISTS "trg_vsp_guard_team_league_structure" ON public."championships";
CREATE TRIGGER trg_vsp_guard_team_league_structure BEFORE INSERT OR UPDATE ON championships FOR EACH ROW EXECUTE FUNCTION vsp_guard_team_league_structure();

DROP TRIGGER IF EXISTS "trg_enforce_sender_name" ON public."chat_messages";
CREATE TRIGGER trg_enforce_sender_name BEFORE INSERT ON chat_messages FOR EACH ROW EXECUTE FUNCTION enforce_real_sender_name();

DROP TRIGGER IF EXISTS "trg_assign_copilot_message_sequence" ON public."copilot_messages";
CREATE TRIGGER trg_assign_copilot_message_sequence BEFORE INSERT ON copilot_messages FOR EACH ROW WHEN (new.message_sequence IS NULL OR new.message_sequence = 0) EXECUTE FUNCTION private.assign_copilot_message_sequence();

DROP TRIGGER IF EXISTS "trg_sync_head_to_head" ON public."matchup_results";
CREATE TRIGGER trg_sync_head_to_head AFTER INSERT ON matchup_results FOR EACH ROW EXECUTE FUNCTION sync_head_to_head_on_result_insert();

DROP TRIGGER IF EXISTS "trg_sync_notification_message_body" ON public."notifications";
CREATE TRIGGER trg_sync_notification_message_body BEFORE INSERT OR UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION sync_notification_message_body();

DROP TRIGGER IF EXISTS "trg_sync_notification_message_body" ON public."notifications";
CREATE TRIGGER trg_sync_notification_message_body BEFORE INSERT OR UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION sync_notification_message_body();

DROP TRIGGER IF EXISTS "trigger_notification_fcm" ON public."notifications";
CREATE TRIGGER trigger_notification_fcm AFTER INSERT ON notifications FOR EACH ROW EXECUTE FUNCTION handle_new_notification_fcm();

DROP TRIGGER IF EXISTS "trg_audit_payouts" ON public."payout_settlements";
CREATE TRIGGER trg_audit_payouts AFTER DELETE OR UPDATE ON payout_settlements FOR EACH ROW EXECUTE FUNCTION fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS "trg_audit_payouts" ON public."payout_settlements";
CREATE TRIGGER trg_audit_payouts AFTER DELETE OR UPDATE ON payout_settlements FOR EACH ROW EXECUTE FUNCTION fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS "trigger_stadium_review_changes" ON public."reviews";
CREATE TRIGGER trigger_stadium_review_changes AFTER INSERT OR DELETE OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION handle_stadium_review_changes();

DROP TRIGGER IF EXISTS "trigger_stadium_review_changes" ON public."reviews";
CREATE TRIGGER trigger_stadium_review_changes AFTER INSERT OR DELETE OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION handle_stadium_review_changes();

DROP TRIGGER IF EXISTS "trigger_stadium_review_changes" ON public."reviews";
CREATE TRIGGER trigger_stadium_review_changes AFTER INSERT OR DELETE OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION handle_stadium_review_changes();

DROP TRIGGER IF EXISTS "trg_audit_stadiums" ON public."stadiums";
CREATE TRIGGER trg_audit_stadiums AFTER DELETE OR UPDATE ON stadiums FOR EACH ROW EXECUTE FUNCTION fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS "trg_audit_stadiums" ON public."stadiums";
CREATE TRIGGER trg_audit_stadiums AFTER DELETE OR UPDATE ON stadiums FOR EACH ROW EXECUTE FUNCTION fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS "trg_protect_stadium_sensitive_fields" ON public."stadiums";
CREATE TRIGGER trg_protect_stadium_sensitive_fields BEFORE UPDATE ON stadiums FOR EACH ROW EXECUTE FUNCTION protect_stadium_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_stadiums_normalize_gov" ON public."stadiums";
CREATE TRIGGER trg_stadiums_normalize_gov BEFORE INSERT OR UPDATE OF governorate ON stadiums FOR EACH ROW EXECUTE FUNCTION trg_fn_normalize_governorate();

DROP TRIGGER IF EXISTS "trg_stadiums_normalize_gov" ON public."stadiums";
CREATE TRIGGER trg_stadiums_normalize_gov BEFORE INSERT OR UPDATE OF governorate ON stadiums FOR EACH ROW EXECUTE FUNCTION trg_fn_normalize_governorate();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium AFTER INSERT OR DELETE OR UPDATE OF is_deleted_by_owner, owner_id ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium AFTER INSERT OR DELETE OR UPDATE OF is_deleted_by_owner, owner_id ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium AFTER INSERT OR DELETE OR UPDATE OF is_deleted_by_owner, owner_id ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium_soft_delete" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium_soft_delete AFTER UPDATE OF is_deleted_by_owner ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium_on_soft_delete();

DROP TRIGGER IF EXISTS "trg_sync_stadium_prices" ON public."stadiums";
CREATE TRIGGER trg_sync_stadium_prices BEFORE INSERT OR UPDATE OF price_per_hour, base_price ON stadiums FOR EACH ROW EXECUTE FUNCTION fn_sync_stadium_prices();

DROP TRIGGER IF EXISTS "trg_sync_stadium_prices" ON public."stadiums";
CREATE TRIGGER trg_sync_stadium_prices BEFORE INSERT OR UPDATE OF price_per_hour, base_price ON stadiums FOR EACH ROW EXECUTE FUNCTION fn_sync_stadium_prices();

DROP TRIGGER IF EXISTS "trg_vsp_guard_stadium_owner_rules" ON public."stadiums";
CREATE TRIGGER trg_vsp_guard_stadium_owner_rules BEFORE INSERT OR UPDATE ON stadiums FOR EACH ROW EXECUTE FUNCTION vsp_guard_stadium_owner_rules();

DROP TRIGGER IF EXISTS "trg_vsp_guard_stadium_owner_rules" ON public."stadiums";
CREATE TRIGGER trg_vsp_guard_stadium_owner_rules BEFORE INSERT OR UPDATE ON stadiums FOR EACH ROW EXECUTE FUNCTION vsp_guard_stadium_owner_rules();

DROP TRIGGER IF EXISTS "trigger_stadium_breaks_collision" ON public."stadiums";
CREATE TRIGGER trigger_stadium_breaks_collision AFTER UPDATE OF features ON stadiums FOR EACH ROW EXECUTE FUNCTION handle_stadium_breaks_collision();

DROP TRIGGER IF EXISTS "trg_team_league_cancellation_refund_queue_worker" ON public."team_league_cancellation_refund_queue";
CREATE TRIGGER trg_team_league_cancellation_refund_queue_worker AFTER INSERT ON team_league_cancellation_refund_queue FOR EACH ROW EXECUTE FUNCTION trigger_cancellation_refund_worker();

DROP TRIGGER IF EXISTS "trg_check_team_and_member_limits" ON public."team_members";
CREATE TRIGGER trg_check_team_and_member_limits BEFORE INSERT ON team_members FOR EACH ROW EXECUTE FUNCTION check_team_and_member_limits();

DROP TRIGGER IF EXISTS "trg_team_member_governorate" ON public."team_members";
CREATE TRIGGER trg_team_member_governorate BEFORE INSERT OR UPDATE OF team_id, user_id ON team_members FOR EACH ROW EXECUTE FUNCTION enforce_team_member_governorate();

DROP TRIGGER IF EXISTS "trg_team_member_governorate" ON public."team_members";
CREATE TRIGGER trg_team_member_governorate BEFORE INSERT OR UPDATE OF team_id, user_id ON team_members FOR EACH ROW EXECUTE FUNCTION enforce_team_member_governorate();

DROP TRIGGER IF EXISTS "trg_protect_teams_sensitive_fields" ON public."teams";
CREATE TRIGGER trg_protect_teams_sensitive_fields BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION protect_team_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_reset_fair_play_score" ON public."teams";
CREATE TRIGGER trg_reset_fair_play_score BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION reset_fair_play_score_annually();

DROP TRIGGER IF EXISTS "trg_protect_completed_match_scores" ON public."tournament_matches";
CREATE TRIGGER trg_protect_completed_match_scores BEFORE UPDATE ON tournament_matches FOR EACH ROW EXECUTE FUNCTION protect_completed_match_scores();

DROP TRIGGER IF EXISTS "aaa_trg_enforce_vsp_minimum_age" ON public."users";
CREATE TRIGGER aaa_trg_enforce_vsp_minimum_age BEFORE INSERT OR UPDATE OF role, date_of_birth, is_registration_complete ON users FOR EACH ROW EXECUTE FUNCTION enforce_vsp_minimum_age();

DROP TRIGGER IF EXISTS "aaa_trg_enforce_vsp_minimum_age" ON public."users";
CREATE TRIGGER aaa_trg_enforce_vsp_minimum_age BEFORE INSERT OR UPDATE OF role, date_of_birth, is_registration_complete ON users FOR EACH ROW EXECUTE FUNCTION enforce_vsp_minimum_age();

DROP TRIGGER IF EXISTS "trg_claim_paid_web_subscription" ON public."users";
CREATE TRIGGER trg_claim_paid_web_subscription AFTER INSERT OR UPDATE OF email, phone ON users FOR EACH ROW EXECUTE FUNCTION trigger_claim_paid_web_subscription();

DROP TRIGGER IF EXISTS "trg_claim_paid_web_subscription" ON public."users";
CREATE TRIGGER trg_claim_paid_web_subscription AFTER INSERT OR UPDATE OF email, phone ON users FOR EACH ROW EXECUTE FUNCTION trigger_claim_paid_web_subscription();

DROP TRIGGER IF EXISTS "trg_protect_users_sensitive_fields" ON public."users";
CREATE TRIGGER trg_protect_users_sensitive_fields BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION trg_fn_protect_user_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_sync_user_public_profile" ON public."users";
CREATE TRIGGER trg_sync_user_public_profile AFTER INSERT OR DELETE OR UPDATE OF name, profile_image_url, "position", is_blocked ON users FOR EACH ROW EXECUTE FUNCTION sync_user_public_profile();

DROP TRIGGER IF EXISTS "trg_sync_user_public_profile" ON public."users";
CREATE TRIGGER trg_sync_user_public_profile AFTER INSERT OR DELETE OR UPDATE OF name, profile_image_url, "position", is_blocked ON users FOR EACH ROW EXECUTE FUNCTION sync_user_public_profile();

DROP TRIGGER IF EXISTS "trg_sync_user_public_profile" ON public."users";
CREATE TRIGGER trg_sync_user_public_profile AFTER INSERT OR DELETE OR UPDATE OF name, profile_image_url, "position", is_blocked ON users FOR EACH ROW EXECUTE FUNCTION sync_user_public_profile();

DROP TRIGGER IF EXISTS "trg_users_normalize_gov" ON public."users";
CREATE TRIGGER trg_users_normalize_gov BEFORE INSERT OR UPDATE OF governorate ON users FOR EACH ROW EXECUTE FUNCTION trg_fn_normalize_governorate();

DROP TRIGGER IF EXISTS "trg_users_normalize_gov" ON public."users";
CREATE TRIGGER trg_users_normalize_gov BEFORE INSERT OR UPDATE OF governorate ON users FOR EACH ROW EXECUTE FUNCTION trg_fn_normalize_governorate();

DROP TRIGGER IF EXISTS "trg_vsp_guard_sensitive_owner_profile_changes" ON public."users";
CREATE TRIGGER trg_vsp_guard_sensitive_owner_profile_changes BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION vsp_guard_sensitive_owner_profile_changes();

DROP TRIGGER IF EXISTS "trg_1v1_cancellation_refund_queue_worker" ON public."vsp_1v1_cancellation_refund_queue";
CREATE TRIGGER trg_1v1_cancellation_refund_queue_worker AFTER INSERT ON vsp_1v1_cancellation_refund_queue FOR EACH ROW EXECUTE FUNCTION trigger_cancellation_refund_worker();

DROP TRIGGER IF EXISTS "trg_check_1v1_registration_capacity" ON public."vsp_1v1_registrations";
CREATE TRIGGER trg_check_1v1_registration_capacity BEFORE INSERT ON vsp_1v1_registrations FOR EACH ROW EXECUTE FUNCTION check_1v1_registration_capacity();

DROP TRIGGER IF EXISTS "trg_touch_1v1_tournament_player_updated_at" ON public."vsp_1v1_tournament_players";
CREATE TRIGGER trg_touch_1v1_tournament_player_updated_at BEFORE UPDATE ON vsp_1v1_tournament_players FOR EACH ROW EXECUTE FUNCTION touch_1v1_tournament_player_updated_at();

DROP TRIGGER IF EXISTS "trg_vsp_1v1_sync_player_total" ON public."vsp_1v1_tournament_players";
CREATE TRIGGER trg_vsp_1v1_sync_player_total BEFORE INSERT OR UPDATE OF tackles, goals, skills ON vsp_1v1_tournament_players FOR EACH ROW EXECUTE FUNCTION vsp_1v1_sync_player_total_from_stats();

DROP TRIGGER IF EXISTS "trg_vsp_1v1_sync_player_total" ON public."vsp_1v1_tournament_players";
CREATE TRIGGER trg_vsp_1v1_sync_player_total BEFORE INSERT OR UPDATE OF tackles, goals, skills ON vsp_1v1_tournament_players FOR EACH ROW EXECUTE FUNCTION vsp_1v1_sync_player_total_from_stats();

DROP TRIGGER IF EXISTS "trg_1v1_tournament_gov" ON public."vsp_1v1_tournaments";
CREATE TRIGGER trg_1v1_tournament_gov BEFORE INSERT OR UPDATE OF governorate ON vsp_1v1_tournaments FOR EACH ROW EXECUTE FUNCTION trg_standardize_1v1_tournament_governorate();

DROP TRIGGER IF EXISTS "trg_1v1_tournament_gov" ON public."vsp_1v1_tournaments";
CREATE TRIGGER trg_1v1_tournament_gov BEFORE INSERT OR UPDATE OF governorate ON vsp_1v1_tournaments FOR EACH ROW EXECUTE FUNCTION trg_standardize_1v1_tournament_governorate();


