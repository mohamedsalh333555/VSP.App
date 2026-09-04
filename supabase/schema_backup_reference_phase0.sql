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

CREATE TABLE IF NOT EXISTS public."bookings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "stadium_id" UUID,
    "stadium_name" TEXT,
    "stadium_image_url" TEXT,
    "owner_id" UUID NOT NULL,
    "created_by_user_id" UUID NOT NULL,
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
    "status" TEXT DEFAULT 'confirmed'::text,
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
    "refund_amount" NUMERIC DEFAULT 0.00,
    "payment_reference" TEXT,
    "initial_players_count" INTEGER DEFAULT 1,
    "total_field_capacity" INTEGER DEFAULT 10,
    "challenge_status" TEXT DEFAULT 'none'::text,
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
    "matchup_closed_at" TIMESTAMP WITH TIME ZONE
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
    "guest_names" JSONB DEFAULT '[]'::jsonb
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
    "is_approved" BOOLEAN DEFAULT true,
    "winner_team_id" UUID,
    "winner_team_name" TEXT,
    "number_of_groups" INTEGER DEFAULT 1,
    "qualifying_per_group" INTEGER DEFAULT 2,
    "is_two_legs" BOOLEAN DEFAULT false,
    "creation_payment_id" TEXT,
    "creation_fee_paid" BOOLEAN DEFAULT false,
    "champion_user_id" UUID,
    "settings" JSONB DEFAULT '{}'::jsonb
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
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
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

CREATE TABLE IF NOT EXISTS public."matchup_results" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "booking_id" UUID NOT NULL,
    "team_a_id" UUID NOT NULL,
    "team_b_id" UUID NOT NULL,
    "outcome" TEXT NOT NULL,
    "recorded_by" UUID NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."matchup_teams" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "booking_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "added_by_user_id" UUID NOT NULL,
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

CREATE TABLE IF NOT EXISTS public."payout_settlements" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID NOT NULL,
    "amount" NUMERIC NOT NULL,
    "method" TEXT NOT NULL,
    "destination" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending'::text,
    "admin_notes" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."player_trophies" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "championship_id" UUID,
    "title" TEXT NOT NULL,
    "prize_won" NUMERIC DEFAULT 0,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
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

CREATE TABLE IF NOT EXISTS public."reports" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "reporter_id" UUID,
    "target_id" TEXT NOT NULL,
    "target_type" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "details" TEXT,
    "status" TEXT DEFAULT 'pending'::text,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
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

CREATE TABLE IF NOT EXISTS public."team_head_to_head" (
    "team_a_id" UUID NOT NULL,
    "team_b_id" UUID NOT NULL,
    "team_a_wins" INTEGER NOT NULL DEFAULT 0,
    "team_b_wins" INTEGER NOT NULL DEFAULT 0,
    "draws" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
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
    "invite_code_expires_at" TIMESTAMP WITH TIME ZONE
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
    "away_penalties" INTEGER
);

CREATE TABLE IF NOT EXISTS public."tournament_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_reference" TEXT NOT NULL,
    "championship_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "captain_user_id" UUID NOT NULL,
    "amount" NUMERIC NOT NULL,
    "payment_status" TEXT NOT NULL DEFAULT 'pending'::text,
    "player_ids" uuid[] DEFAULT ARRAY[]::uuid[],
    "guest_names" text[] DEFAULT ARRAY[]::text[],
    "paymob_transaction_id" TEXT,
    "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
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
    "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
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
    "trial_ends_at" TIMESTAMP WITH TIME ZONE,
    "subscription_expires_at" TIMESTAMP WITH TIME ZONE,
    "total_platform_fees" NUMERIC DEFAULT 0,
    "fcm_token" TEXT,
    "last_seen" TIMESTAMP WITH TIME ZONE DEFAULT now(),
    "terms_accepted_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public."vsp_1v1_registrations" (
    "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
    "user_id" UUID,
    "status" TEXT DEFAULT 'pending'::text,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
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
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT now()
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
ALTER TABLE public."app_config" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."app_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."banners" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."booking_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."bookings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."challenge_results" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_roster_guests" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_roster_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championship_rosters" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."championships" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."chat_messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."financial_audit_logs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."matchup_results" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."matchup_teams" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."payout_settlements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."player_trophies" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."promotions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."reports" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."reviews" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."stadium_custom_rates" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."stadiums" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_head_to_head" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."team_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."teams" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tournament_matches" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tournament_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."transactions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1v1_registrations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vsp_1vs1_players" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."webhook_logs" ENABLE ROW LEVEL SECURITY;


-- --------------------------------------------------------------------------
-- 5. CONSTRAINTS (PK, FK, UNIQUE, CHECK)
-- --------------------------------------------------------------------------
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

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "exclude_overlapping_stadium_bookings";
ALTER TABLE bookings ADD CONSTRAINT "exclude_overlapping_stadium_bookings" EXCLUDE USING gist (stadium_id WITH =, tstzrange(start_time, end_time) WITH &&) WHERE (status <> 'cancelled'::text);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_pkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_pkey" PRIMARY KEY (id);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_created_by_user_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_opponent_team_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_opponent_team_id_fkey" FOREIGN KEY (opponent_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_owner_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_player_team_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_player_team_id_fkey" FOREIGN KEY (player_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_result_submitted_by_team_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_result_submitted_by_team_id_fkey" FOREIGN KEY (result_submitted_by_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_stadium_id_fkey";
ALTER TABLE bookings ADD CONSTRAINT "bookings_stadium_id_fkey" FOREIGN KEY (stadium_id) REFERENCES stadiums(id) ON DELETE RESTRICT;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_booking_type_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_booking_type_check" CHECK (booking_type = ANY (ARRAY['personal'::text, 'openJoin'::text, 'open_join'::text, 'openjoin'::text, 'challenge'::text, 'team'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_final_outcome_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_final_outcome_check" CHECK (final_outcome = ANY (ARRAY['homeWin'::text, 'draw'::text, 'awayWin'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_match_result_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_match_result_status_check" CHECK (match_result_status = ANY (ARRAY['noResult'::text, 'waitingOpponent'::text, 'confirmed'::text, 'disputed'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_matchup_mode_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_matchup_mode_check" CHECK ((matchup_mode = ANY (ARRAY['duo'::text, 'winner_stays'::text])) OR matchup_mode IS NULL);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_payment_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_payment_status_check" CHECK (payment_status = ANY (ARRAY['pending'::text, 'unpaid'::text, 'paid'::text, 'partially_paid'::text, 'refunded'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_pending_outcome_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_pending_outcome_check" CHECK (pending_outcome = ANY (ARRAY['homeWin'::text, 'draw'::text, 'awayWin'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "bookings_status_check";
ALTER TABLE bookings ADD CONSTRAINT "bookings_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'completed'::text, 'cancelled'::text]));

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "check_positive_price";
ALTER TABLE bookings ADD CONSTRAINT "check_positive_price" CHECK (total_price >= 0::numeric AND deposit_paid >= 0::numeric);

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS "valid_booking_duration";
ALTER TABLE bookings ADD CONSTRAINT "valid_booking_duration" CHECK (end_time > start_time);

ALTER TABLE challenge_results DROP CONSTRAINT IF EXISTS "challenge_results_pkey";
ALTER TABLE challenge_results ADD CONSTRAINT "challenge_results_pkey" PRIMARY KEY (id);

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

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_pkey";
ALTER TABLE championships ADD CONSTRAINT "championships_pkey" PRIMARY KEY (id);

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_champion_team_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_champion_team_id_fkey" FOREIGN KEY (champion_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_champion_user_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_champion_user_id_fkey" FOREIGN KEY (champion_user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_owner_id_fkey";
ALTER TABLE championships ADD CONSTRAINT "championships_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_status_check";
ALTER TABLE championships ADD CONSTRAINT "championships_status_check" CHECK (status = ANY (ARRAY['open'::text, 'ongoing'::text, 'completed'::text]));

ALTER TABLE championships DROP CONSTRAINT IF EXISTS "championships_type_check";
ALTER TABLE championships ADD CONSTRAINT "championships_type_check" CHECK (type = ANY (ARRAY['cup'::text, 'league'::text, 'tournament'::text, 'groups'::text, 'knockout'::text, '1v1'::text]));

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

ALTER TABLE financial_audit_logs DROP CONSTRAINT IF EXISTS "financial_audit_logs_pkey";
ALTER TABLE financial_audit_logs ADD CONSTRAINT "financial_audit_logs_pkey" PRIMARY KEY (id);

ALTER TABLE financial_audit_logs DROP CONSTRAINT IF EXISTS "financial_audit_logs_booking_id_fkey";
ALTER TABLE financial_audit_logs ADD CONSTRAINT "financial_audit_logs_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_pkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_pkey" PRIMARY KEY (id);

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_booking_id_fkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE matchup_results DROP CONSTRAINT IF EXISTS "matchup_results_recorded_by_fkey";
ALTER TABLE matchup_results ADD CONSTRAINT "matchup_results_recorded_by_fkey" FOREIGN KEY (recorded_by) REFERENCES users(id);

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
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_added_by_user_id_fkey" FOREIGN KEY (added_by_user_id) REFERENCES users(id);

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_booking_id_fkey";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE matchup_teams DROP CONSTRAINT IF EXISTS "matchup_teams_team_id_fkey";
ALTER TABLE matchup_teams ADD CONSTRAINT "matchup_teams_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS "notifications_pkey";
ALTER TABLE notifications ADD CONSTRAINT "notifications_pkey" PRIMARY KEY (id);

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS "notifications_user_id_fkey";
ALTER TABLE notifications ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_pkey";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_pkey" PRIMARY KEY (id);

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_owner_id_fkey";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_amount_check";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_amount_check" CHECK (amount > 0::numeric);

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_method_check";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_method_check" CHECK (method = ANY (ARRAY['instapay'::text, 'wallet'::text, 'bank'::text, 'unknown'::text]));

ALTER TABLE payout_settlements DROP CONSTRAINT IF EXISTS "payout_settlements_status_check";
ALTER TABLE payout_settlements ADD CONSTRAINT "payout_settlements_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'completed'::text]));

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_pkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_pkey" PRIMARY KEY (id);

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_championship_id_fkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE player_trophies DROP CONSTRAINT IF EXISTS "player_trophies_user_id_fkey";
ALTER TABLE player_trophies ADD CONSTRAINT "player_trophies_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE promotions DROP CONSTRAINT IF EXISTS "promotions_pkey";
ALTER TABLE promotions ADD CONSTRAINT "promotions_pkey" PRIMARY KEY (id);

ALTER TABLE reports DROP CONSTRAINT IF EXISTS "reports_pkey";
ALTER TABLE reports ADD CONSTRAINT "reports_pkey" PRIMARY KEY (id);

ALTER TABLE reports DROP CONSTRAINT IF EXISTS "reports_reporter_id_fkey";
ALTER TABLE reports ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;

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

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_pkey";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_pkey" PRIMARY KEY (team_a_id, team_b_id);

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_team_a_id_fkey";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_team_a_id_fkey" FOREIGN KEY (team_a_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_team_b_id_fkey";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_team_b_id_fkey" FOREIGN KEY (team_b_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE team_head_to_head DROP CONSTRAINT IF EXISTS "team_head_to_head_check";
ALTER TABLE team_head_to_head ADD CONSTRAINT "team_head_to_head_check" CHECK (team_a_id < team_b_id);

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

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_home_team_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_home_team_id_fkey" FOREIGN KEY (home_team_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_next_match_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_next_match_id_fkey" FOREIGN KEY (next_match_id) REFERENCES tournament_matches(id) ON DELETE SET NULL;

ALTER TABLE tournament_matches DROP CONSTRAINT IF EXISTS "tournament_matches_winner_id_fkey";
ALTER TABLE tournament_matches ADD CONSTRAINT "tournament_matches_winner_id_fkey" FOREIGN KEY (winner_id) REFERENCES teams(id) ON DELETE SET NULL;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_order_reference_key";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_order_reference_key" UNIQUE (order_reference);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_pkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_pkey" PRIMARY KEY (id);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_captain_user_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_captain_user_id_fkey" FOREIGN KEY (captain_user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_championship_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE CASCADE;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_team_id_fkey";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_team_id_fkey" FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_amount_check";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_amount_check" CHECK (amount >= 0::numeric);

ALTER TABLE tournament_orders DROP CONSTRAINT IF EXISTS "tournament_orders_payment_status_check";
ALTER TABLE tournament_orders ADD CONSTRAINT "tournament_orders_payment_status_check" CHECK (payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'cancelled'::text]));

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_pkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_pkey" PRIMARY KEY (id);

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_booking_id_fkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_championship_id_fkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_championship_id_fkey" FOREIGN KEY (championship_id) REFERENCES championships(id) ON DELETE SET NULL;

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS "transactions_user_id_fkey";
ALTER TABLE transactions ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_phone_unique";
ALTER TABLE users ADD CONSTRAINT "users_phone_unique" UNIQUE (phone);

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_pkey";
ALTER TABLE users ADD CONSTRAINT "users_pkey" PRIMARY KEY (id);

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_id_fkey";
ALTER TABLE users ADD CONSTRAINT "users_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE users DROP CONSTRAINT IF EXISTS "users_role_check";
ALTER TABLE users ADD CONSTRAINT "users_role_check" CHECK (role = ANY (ARRAY['player'::text, 'owner'::text, 'admin'::text, 'cofounder'::text, 'co_founder'::text, 'super_admin'::text]));

ALTER TABLE vsp_1v1_registrations DROP CONSTRAINT IF EXISTS "vsp_1v1_registrations_pkey";
ALTER TABLE vsp_1v1_registrations ADD CONSTRAINT "vsp_1v1_registrations_pkey" PRIMARY KEY (id);

ALTER TABLE vsp_1v1_registrations DROP CONSTRAINT IF EXISTS "vsp_1v1_registrations_user_id_fkey";
ALTER TABLE vsp_1v1_registrations ADD CONSTRAINT "vsp_1v1_registrations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE vsp_1v1_registrations DROP CONSTRAINT IF EXISTS "vsp_1v1_registrations_status_check";
ALTER TABLE vsp_1v1_registrations ADD CONSTRAINT "vsp_1v1_registrations_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));

ALTER TABLE vsp_1vs1_players DROP CONSTRAINT IF EXISTS "vsp_1vs1_players_pkey";
ALTER TABLE vsp_1vs1_players ADD CONSTRAINT "vsp_1vs1_players_pkey" PRIMARY KEY (id);

ALTER TABLE webhook_logs DROP CONSTRAINT IF EXISTS "webhook_logs_pkey";
ALTER TABLE webhook_logs ADD CONSTRAINT "webhook_logs_pkey" PRIMARY KEY (id);



-- --------------------------------------------------------------------------
-- 6. INDEXES
-- --------------------------------------------------------------------------
CREATE INDEX idx_banners_active_placement ON public.banners USING btree (is_active, placement, priority_order);
CREATE INDEX exclude_overlapping_stadium_bookings ON public.bookings USING gist (stadium_id, tstzrange(start_time, end_time)) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_bookings_conflict_check ON public.bookings USING btree (stadium_id, status, start_time, end_time);
CREATE INDEX idx_bookings_created_by_status ON public.bookings USING btree (created_by_user_id, status);
CREATE INDEX idx_bookings_created_by_status_start ON public.bookings USING btree (created_by_user_id, status, start_time DESC);
CREATE INDEX idx_bookings_created_by_user_id ON public.bookings USING btree (created_by_user_id);
CREATE INDEX idx_bookings_elo_reconcile ON public.bookings USING btree (booking_type, match_result_status, elo_processed) WHERE (status <> 'cancelled'::text);
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
CREATE INDEX idx_bookings_owner_user ON public.bookings USING btree (owner_id, created_by_user_id);
CREATE INDEX idx_bookings_paymob_txn_id ON public.bookings USING btree (paymob_txn_id);
CREATE INDEX idx_bookings_pending_cleanup ON public.bookings USING btree (created_by_user_id, stadium_id, status, is_paid);
CREATE INDEX idx_bookings_player_team_id ON public.bookings USING btree (player_team_id) WHERE (player_team_id IS NOT NULL);
CREATE INDEX idx_bookings_player_team_status ON public.bookings USING btree (player_team_id, status);
CREATE INDEX idx_bookings_public_feed ON public.bookings USING btree (is_private, status, start_time, end_time) WHERE (is_private = false);
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
CREATE UNIQUE INDEX prevent_double_booking ON public.bookings USING btree (stadium_id, start_time) WHERE (status <> 'cancelled'::text);
CREATE INDEX idx_challenge_results_challenge_id ON public.challenge_results USING btree (challenge_id);
CREATE INDEX idx_championship_roster_guests_roster_id ON public.championship_roster_guests USING btree (roster_id);
CREATE UNIQUE INDEX championship_roster_players_roster_id_player_id_key ON public.championship_roster_players USING btree (roster_id, player_id);
CREATE UNIQUE INDEX championship_rosters_championship_id_team_id_key ON public.championship_rosters USING btree (championship_id, team_id);
CREATE INDEX idx_champ_rosters_team_id ON public.championship_rosters USING btree (team_id);
CREATE INDEX idx_championship_rosters_championship ON public.championship_rosters USING btree (championship_id);
CREATE INDEX idx_championships_governorate ON public.championships USING btree (governorate);
CREATE INDEX idx_championships_joined_teams_gin ON public.championships USING gin (joined_teams);
CREATE INDEX idx_championships_name_trgm ON public.championships USING gin (name gin_trgm_ops);
CREATE INDEX idx_championships_owner_id ON public.championships USING btree (owner_id);
CREATE INDEX idx_championships_status_sport ON public.championships USING btree (status, sport_type, governorate);
CREATE INDEX idx_chat_messages_booking_created ON public.chat_messages USING btree (booking_id, created_at DESC);
CREATE INDEX idx_chat_messages_conversation_created ON public.chat_messages USING btree (conversation_id, created_at DESC);
CREATE INDEX idx_chat_messages_sender_id ON public.chat_messages USING btree (sender_id);
CREATE INDEX idx_chat_msgs_booking_id ON public.chat_messages USING btree (booking_id);
CREATE INDEX idx_conversations_booking ON public.conversations USING btree (booking_id);
CREATE INDEX idx_conversations_participants_gin ON public.conversations USING gin (participant_ids);
CREATE INDEX idx_financial_logs_booking ON public.financial_audit_logs USING btree (booking_id);
CREATE INDEX idx_financial_logs_owner ON public.financial_audit_logs USING btree (owner_id, created_at);
CREATE INDEX idx_financial_logs_user ON public.financial_audit_logs USING btree (user_id, created_at);
CREATE INDEX idx_matchup_results_booking_id ON public.matchup_results USING btree (booking_id);
CREATE INDEX idx_matchup_results_team_a_id ON public.matchup_results USING btree (team_a_id);
CREATE INDEX idx_matchup_results_team_b_id ON public.matchup_results USING btree (team_b_id);
CREATE UNIQUE INDEX matchup_teams_booking_id_team_id_key ON public.matchup_teams USING btree (booking_id, team_id);
CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_id_unread ON public.notifications USING btree (user_id) WHERE (is_read = false);
CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, is_read);
CREATE INDEX idx_notifications_user_unread_perf ON public.notifications USING btree (user_id, is_read, created_at DESC);
CREATE INDEX idx_payout_settlements_owner ON public.payout_settlements USING btree (owner_id, created_at DESC);
CREATE INDEX idx_payout_settlements_status ON public.payout_settlements USING btree (status, created_at DESC);
CREATE INDEX idx_player_trophies_user_id ON public.player_trophies USING btree (user_id);
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
CREATE INDEX idx_stadiums_public_filter ON public.stadiums USING btree (is_verified, is_blocked, is_deleted_by_owner, governorate);
CREATE INDEX idx_team_members_user ON public.team_members USING btree (user_id);
CREATE INDEX idx_teams_captain ON public.teams USING btree (captain_id);
CREATE INDEX idx_teams_governorate ON public.teams USING btree (governorate);
CREATE INDEX idx_teams_governorate_sport ON public.teams USING btree (governorate, sport_type, points DESC);
CREATE INDEX idx_teams_ranking_points ON public.teams USING btree (points DESC, wins DESC, matches_played);
CREATE UNIQUE INDEX teams_active_invite_code_key ON public.teams USING btree (active_invite_code);
CREATE UNIQUE INDEX teams_name_key ON public.teams USING btree (name);
CREATE INDEX idx_tournament_matches_away_team_id ON public.tournament_matches USING btree (away_team_id) WHERE (away_team_id IS NOT NULL);
CREATE INDEX idx_tournament_matches_bracket ON public.tournament_matches USING btree (championship_id, round_index, match_index);
CREATE INDEX idx_tournament_matches_champ_round ON public.tournament_matches USING btree (championship_id, round_index);
CREATE INDEX idx_tournament_matches_championship_id ON public.tournament_matches USING btree (championship_id);
CREATE INDEX idx_tournament_matches_home_team_id ON public.tournament_matches USING btree (home_team_id) WHERE (home_team_id IS NOT NULL);
CREATE INDEX idx_tournament_matches_next_match_id ON public.tournament_matches USING btree (next_match_id);
CREATE INDEX idx_tournament_matches_stage ON public.tournament_matches USING btree (championship_id, stage);
CREATE INDEX idx_tournament_matches_status_scheduled ON public.tournament_matches USING btree (status, scheduled_time);
CREATE INDEX idx_tournament_matches_winner_id ON public.tournament_matches USING btree (winner_id) WHERE (winner_id IS NOT NULL);
CREATE INDEX idx_tournament_orders_captain_user_id ON public.tournament_orders USING btree (captain_user_id);
CREATE INDEX idx_tournament_orders_champ_team ON public.tournament_orders USING btree (championship_id, team_id);
CREATE INDEX idx_tournament_orders_status ON public.tournament_orders USING btree (payment_status);
CREATE UNIQUE INDEX tournament_orders_order_reference_key ON public.tournament_orders USING btree (order_reference);
CREATE INDEX idx_transactions_booking_id ON public.transactions USING btree (booking_id) WHERE (booking_id IS NOT NULL);
CREATE INDEX idx_transactions_champ_created ON public.transactions USING btree (championship_id, created_at DESC) WHERE (championship_id IS NOT NULL);
CREATE INDEX idx_transactions_championship_id ON public.transactions USING btree (championship_id) WHERE (championship_id IS NOT NULL);
CREATE INDEX idx_transactions_created_at ON public.transactions USING btree (created_at DESC);
CREATE INDEX idx_transactions_type_status ON public.transactions USING btree (type, status);
CREATE INDEX idx_transactions_user_created ON public.transactions USING btree (user_id, created_at DESC);
CREATE INDEX idx_transactions_user_id ON public.transactions USING btree (user_id);
CREATE INDEX idx_users_role ON public.users USING btree (role);
CREATE INDEX idx_users_role_status ON public.users USING btree (role, is_blocked, verification_status);
CREATE UNIQUE INDEX users_phone_unique ON public.users USING btree (phone);
CREATE UNIQUE INDEX idx_unique_active_registration ON public.vsp_1v1_registrations USING btree (user_id) WHERE (status = ANY (ARRAY['pending'::text, 'approved'::text]));
CREATE INDEX idx_vsp1v1_ranking_points ON public.vsp_1vs1_players USING btree (total_points DESC, skill_points DESC, goals DESC);


-- --------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY POLICIES
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins full access" ON public."app_config";
CREATE POLICY "Admins full access" ON public."app_config" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "admin_manage_app_config" ON public."app_config";
CREATE POLICY "admin_manage_app_config" ON public."app_config" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "app_config_select_public" ON public."app_config";
CREATE POLICY "app_config_select_public" ON public."app_config" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "Admins full access" ON public."app_settings";
CREATE POLICY "Admins full access" ON public."app_settings" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "app_settings_admin_manage" ON public."app_settings";
CREATE POLICY "app_settings_admin_manage" ON public."app_settings" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "app_settings_public_read" ON public."app_settings";
CREATE POLICY "app_settings_public_read" ON public."app_settings" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (true);

DROP POLICY IF EXISTS "app_settings_select" ON public."app_settings";
CREATE POLICY "app_settings_select" ON public."app_settings" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "Admins have full access to banners" ON public."banners";
CREATE POLICY "Admins have full access to banners" ON public."banners" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'cofounder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'cofounder'::text]))))));

DROP POLICY IF EXISTS "Public and users can view active banners" ON public."banners";
CREATE POLICY "Public and users can view active banners" ON public."banners" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (((is_active = true) AND ((start_date IS NULL) OR (start_date <= timezone('utc'::text, now()))) AND ((end_date IS NULL) OR (end_date >= timezone('utc'::text, now())))));

DROP POLICY IF EXISTS "booking_players_select_policy" ON public."booking_players";
CREATE POLICY "booking_players_select_policy" ON public."booking_players" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = booking_players.booking_id) AND ((b.owner_id = auth.uid()) OR (b.created_by_user_id = auth.uid()) OR (auth.uid() = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "Admins full access" ON public."bookings";
CREATE POLICY "Admins full access" ON public."bookings" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "bookings_delete_secure" ON public."bookings";
CREATE POLICY "bookings_delete_secure" ON public."bookings" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((((status = 'pending'::text) AND ((auth.uid() = created_by_user_id) OR (auth.uid() = owner_id))) OR ((payment_transaction_id ~~ 'MANUAL%'::text) AND (auth.uid() = owner_id)) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "bookings_insert_secure" ON public."bookings";
CREATE POLICY "bookings_insert_secure" ON public."bookings" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((((auth.uid() = created_by_user_id) OR (auth.uid() = owner_id)) AND ((is_paid = false) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))));

DROP POLICY IF EXISTS "bookings_select_unified" ON public."bookings";
CREATE POLICY "bookings_select_unified" ON public."bookings" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (((auth.uid() = user_id) OR (auth.uid() = owner_id) OR (auth.uid() = created_by_user_id) OR (is_private = false) OR (auth.uid() = ANY (COALESCE(joined_user_ids, ARRAY[]::uuid[])))));

DROP POLICY IF EXISTS "bookings_update_secure" ON public."bookings";
CREATE POLICY "bookings_update_secure" ON public."bookings" AS PERMISSIVE FOR UPDATE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((auth.uid() = user_id) OR (auth.uid() = owner_id) OR (auth.uid() = created_by_user_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK (((auth.uid() = user_id) OR (auth.uid() = owner_id) OR (auth.uid() = created_by_user_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "challenge_results_insert" ON public."challenge_results";
CREATE POLICY "challenge_results_insert" ON public."challenge_results" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((((auth.uid())::text = submitted_by) AND (confirmed_by IS NULL) AND (status = 'pending'::text)));

DROP POLICY IF EXISTS "challenge_results_select" ON public."challenge_results";
CREATE POLICY "challenge_results_select" ON public."challenge_results" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "challenge_results_update" ON public."challenge_results";
CREATE POLICY "challenge_results_update" ON public."challenge_results" AS PERMISSIVE FOR UPDATE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((((auth.uid())::text = submitted_by) AND (status = 'pending'::text)) OR ((status = 'pending'::text) AND (confirmed_by IS NULL) AND ((auth.uid())::text <> submitted_by)) OR ((auth.uid())::text = confirmed_by))) WITH CHECK ((((status = 'confirmed'::text) AND ((auth.uid())::text = confirmed_by) AND ((auth.uid())::text <> submitted_by)) OR ((status = 'pending'::text) AND ((auth.uid())::text = submitted_by))));

DROP POLICY IF EXISTS "roster_guests_manage_policy" ON public."championship_roster_guests";
CREATE POLICY "roster_guests_manage_policy" ON public."championship_roster_guests" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_guests.roster_id) AND ((t.captain_id = auth.uid()) OR (c.owner_id = auth.uid()) OR (( SELECT users.role
           FROM users
          WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_guests.roster_id) AND ((t.captain_id = auth.uid()) OR (c.owner_id = auth.uid()) OR (( SELECT users.role
           FROM users
          WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "roster_guests_select_policy" ON public."championship_roster_guests";
CREATE POLICY "roster_guests_select_policy" ON public."championship_roster_guests" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "roster_players_manage_policy" ON public."championship_roster_players";
CREATE POLICY "roster_players_manage_policy" ON public."championship_roster_players" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_players.roster_id) AND ((t.captain_id = auth.uid()) OR (c.owner_id = auth.uid()) OR (( SELECT users.role
           FROM users
          WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_players.roster_id) AND ((t.captain_id = auth.uid()) OR (c.owner_id = auth.uid()) OR (( SELECT users.role
           FROM users
          WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "championship_rosters_manage_secure" ON public."championship_rosters";
CREATE POLICY "championship_rosters_manage_secure" ON public."championship_rosters" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = championship_rosters.team_id) AND (t.captain_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_rosters.championship_id) AND (c.owner_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = championship_rosters.team_id) AND (t.captain_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_rosters.championship_id) AND (c.owner_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "Admins full access" ON public."championships";
CREATE POLICY "Admins full access" ON public."championships" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "championships_admin_manage" ON public."championships";
CREATE POLICY "championships_admin_manage" ON public."championships" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "championships_insert" ON public."championships";
CREATE POLICY "championships_insert" ON public."championships" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((auth.uid() = owner_id));

DROP POLICY IF EXISTS "championships_select" ON public."championships";
CREATE POLICY "championships_select" ON public."championships" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "championships_update_own" ON public."championships";
CREATE POLICY "championships_update_own" ON public."championships" AS PERMISSIVE FOR UPDATE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = owner_id)) WITH CHECK ((auth.uid() = owner_id));

DROP POLICY IF EXISTS "chat_messages_insert" ON public."chat_messages";
CREATE POLICY "chat_messages_insert" ON public."chat_messages" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK (((auth.uid() = sender_id) AND ((EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = chat_messages.conversation_id) AND ((auth.uid() = ANY (c.participant_ids)) OR ((c.type = 'support'::text) AND (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = chat_messages.booking_id) AND ((b.user_id = auth.uid()) OR (b.owner_id = auth.uid()) OR (b.created_by_user_id = auth.uid()) OR (auth.uid() = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))))));

DROP POLICY IF EXISTS "chat_messages_select" ON public."chat_messages";
CREATE POLICY "chat_messages_select" ON public."chat_messages" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = chat_messages.conversation_id) AND ((auth.uid() = ANY (c.participant_ids)) OR ((c.type = 'support'::text) AND (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = chat_messages.booking_id) AND ((b.user_id = auth.uid()) OR (b.owner_id = auth.uid()) OR (b.created_by_user_id = auth.uid()) OR (auth.uid() = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))))))));

DROP POLICY IF EXISTS "conversations_modify_unified" ON public."conversations";
CREATE POLICY "conversations_modify_unified" ON public."conversations" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((auth.uid() = ANY (participant_ids)) OR ((type = 'support'::text) AND (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) OR (auth.uid() = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id))))) WITH CHECK (((auth.uid() = ANY (participant_ids)) OR ((type = 'support'::text) AND (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) OR (auth.uid() = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id)))));

DROP POLICY IF EXISTS "conversations_select_unified" ON public."conversations";
CREATE POLICY "conversations_select_unified" ON public."conversations" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((auth.uid() = ANY (participant_ids)) OR ((type = 'support'::text) AND (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) OR (auth.uid() = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id)))));

DROP POLICY IF EXISTS "financial_logs_admin_all" ON public."financial_audit_logs";
CREATE POLICY "financial_logs_admin_all" ON public."financial_audit_logs" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "financial_logs_owner_select" ON public."financial_audit_logs";
CREATE POLICY "financial_logs_owner_select" ON public."financial_audit_logs" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((owner_id = auth.uid()));

DROP POLICY IF EXISTS "financial_logs_user_select" ON public."financial_audit_logs";
CREATE POLICY "financial_logs_user_select" ON public."financial_audit_logs" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((user_id = auth.uid()));

DROP POLICY IF EXISTS "Anyone authenticated can view matchup results" ON public."matchup_results";
CREATE POLICY "Anyone authenticated can view matchup results" ON public."matchup_results" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (true);

DROP POLICY IF EXISTS "Anyone authenticated can view matchup teams" ON public."matchup_teams";
CREATE POLICY "Anyone authenticated can view matchup teams" ON public."matchup_teams" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (true);

DROP POLICY IF EXISTS "Server and booking host can manage matchup teams" ON public."matchup_teams";
CREATE POLICY "Server and booking host can manage matchup teams" ON public."matchup_teams" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((auth.uid() = added_by_user_id) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = matchup_teams.booking_id) AND ((b.created_by_user_id = auth.uid()) OR (b.user_id = auth.uid())))))));

DROP POLICY IF EXISTS "Admins full access" ON public."notifications";
CREATE POLICY "Admins full access" ON public."notifications" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "notifications_delete" ON public."notifications";
CREATE POLICY "notifications_delete" ON public."notifications" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = user_id));

DROP POLICY IF EXISTS "notifications_insert_secure" ON public."notifications";
CREATE POLICY "notifications_insert_secure" ON public."notifications" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK (((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))) OR (user_id = auth.uid()) OR ((booking_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = notifications.booking_id) AND ((b.user_id = auth.uid()) OR (b.owner_id = auth.uid()) OR (b.created_by_user_id = auth.uid()) OR (auth.uid() = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))))));

DROP POLICY IF EXISTS "notifications_select_own" ON public."notifications";
CREATE POLICY "notifications_select_own" ON public."notifications" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = user_id));

DROP POLICY IF EXISTS "Admins full access" ON public."payout_settlements";
CREATE POLICY "Admins full access" ON public."payout_settlements" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "payout_settlements_insert_policy" ON public."payout_settlements";
CREATE POLICY "payout_settlements_insert_policy" ON public."payout_settlements" AS PERMISSIVE FOR INSERT TO {, p, u, b, l, i, c, } WITH CHECK ((auth.uid() = owner_id));

DROP POLICY IF EXISTS "payout_settlements_select_policy" ON public."payout_settlements";
CREATE POLICY "payout_settlements_select_policy" ON public."payout_settlements" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (((auth.uid() = owner_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "payout_settlements_update_policy" ON public."payout_settlements";
CREATE POLICY "payout_settlements_update_policy" ON public."payout_settlements" AS PERMISSIVE FOR UPDATE TO {, p, u, b, l, i, c, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "player_trophies_public_select" ON public."player_trophies";
CREATE POLICY "player_trophies_public_select" ON public."player_trophies" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "promotions_admin_manage" ON public."promotions";
CREATE POLICY "promotions_admin_manage" ON public."promotions" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "promotions_public_read" ON public."promotions";
CREATE POLICY "promotions_public_read" ON public."promotions" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING ((is_active = true));

DROP POLICY IF EXISTS "Admins full access" ON public."reports";
CREATE POLICY "Admins full access" ON public."reports" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "reports_admin_delete" ON public."reports";
CREATE POLICY "reports_admin_delete" ON public."reports" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "reports_admin_select" ON public."reports";
CREATE POLICY "reports_admin_select" ON public."reports" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "reports_insert_auth" ON public."reports";
CREATE POLICY "reports_insert_auth" ON public."reports" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((auth.uid() = reporter_id));

DROP POLICY IF EXISTS "reviews_insert" ON public."reviews";
CREATE POLICY "reviews_insert" ON public."reviews" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK (((auth.uid() = user_id) AND ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.stadium_id = reviews.stadium_id) AND ((b.user_id = auth.uid()) OR (b.created_by_user_id = auth.uid())) AND (b.status = 'confirmed'::text)))))));

DROP POLICY IF EXISTS "reviews_select" ON public."reviews";
CREATE POLICY "reviews_select" ON public."reviews" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "stadium_custom_rates_manage_own" ON public."stadium_custom_rates";
CREATE POLICY "stadium_custom_rates_manage_own" ON public."stadium_custom_rates" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM stadiums
  WHERE ((stadiums.id = stadium_custom_rates.stadium_id) AND ((stadiums.owner_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM stadiums
  WHERE ((stadiums.id = stadium_custom_rates.stadium_id) AND ((stadiums.owner_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))))));

DROP POLICY IF EXISTS "stadium_custom_rates_select" ON public."stadium_custom_rates";
CREATE POLICY "stadium_custom_rates_select" ON public."stadium_custom_rates" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "Admins full access" ON public."stadiums";
CREATE POLICY "Admins full access" ON public."stadiums" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "stadiums_delete_own" ON public."stadiums";
CREATE POLICY "stadiums_delete_own" ON public."stadiums" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = owner_id));

DROP POLICY IF EXISTS "stadiums_insert_own" ON public."stadiums";
CREATE POLICY "stadiums_insert_own" ON public."stadiums" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((auth.uid() = owner_id));

DROP POLICY IF EXISTS "stadiums_select_public" ON public."stadiums";
CREATE POLICY "stadiums_select_public" ON public."stadiums" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING ((((is_verified = true) AND (is_blocked = false) AND (is_deleted_by_owner = false)) OR (auth.uid() = owner_id)));

DROP POLICY IF EXISTS "stadiums_update_own" ON public."stadiums";
CREATE POLICY "stadiums_update_own" ON public."stadiums" AS PERMISSIVE FOR UPDATE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = owner_id)) WITH CHECK ((auth.uid() = owner_id));

DROP POLICY IF EXISTS "Anyone authenticated can view team head to head" ON public."team_head_to_head";
CREATE POLICY "Anyone authenticated can view team head to head" ON public."team_head_to_head" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (true);

DROP POLICY IF EXISTS "team_members_delete" ON public."team_members";
CREATE POLICY "team_members_delete" ON public."team_members" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM teams
  WHERE ((teams.id = team_members.team_id) AND (teams.captain_id = auth.uid()))))));

DROP POLICY IF EXISTS "team_members_insert" ON public."team_members";
CREATE POLICY "team_members_insert" ON public."team_members" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((EXISTS ( SELECT 1
   FROM teams
  WHERE ((teams.id = team_members.team_id) AND (teams.captain_id = auth.uid())))));

DROP POLICY IF EXISTS "team_members_select" ON public."team_members";
CREATE POLICY "team_members_select" ON public."team_members" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "teams_delete_own" ON public."teams";
CREATE POLICY "teams_delete_own" ON public."teams" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = captain_id));

DROP POLICY IF EXISTS "teams_insert" ON public."teams";
CREATE POLICY "teams_insert" ON public."teams" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((auth.uid() = captain_id));

DROP POLICY IF EXISTS "teams_select" ON public."teams";
CREATE POLICY "teams_select" ON public."teams" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "teams_update_own" ON public."teams";
CREATE POLICY "teams_update_own" ON public."teams" AS PERMISSIVE FOR UPDATE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = captain_id)) WITH CHECK ((auth.uid() = captain_id));

DROP POLICY IF EXISTS "Admins full access" ON public."tournament_matches";
CREATE POLICY "Admins full access" ON public."tournament_matches" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "tournament_matches_insert" ON public."tournament_matches";
CREATE POLICY "tournament_matches_insert" ON public."tournament_matches" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_matches.championship_id) AND ((c.owner_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))))));

DROP POLICY IF EXISTS "tournament_orders_insert_policy" ON public."tournament_orders";
CREATE POLICY "tournament_orders_insert_policy" ON public."tournament_orders" AS PERMISSIVE FOR INSERT TO {, p, u, b, l, i, c, } WITH CHECK ((auth.uid() = captain_user_id));

DROP POLICY IF EXISTS "tournament_orders_select_policy" ON public."tournament_orders";
CREATE POLICY "tournament_orders_select_policy" ON public."tournament_orders" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (((auth.uid() = captain_user_id) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_orders.championship_id) AND (c.owner_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "Admins full access" ON public."transactions";
CREATE POLICY "Admins full access" ON public."transactions" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Admins have full access to transactions" ON public."transactions";
CREATE POLICY "Admins have full access to transactions" ON public."transactions" AS PERMISSIVE FOR ALL TO {, p, u, b, l, i, c, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Users can view own transactions" ON public."transactions";
CREATE POLICY "Users can view own transactions" ON public."transactions" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING ((auth.uid() = user_id));

DROP POLICY IF EXISTS "transactions_insert_policy" ON public."transactions";
CREATE POLICY "transactions_insert_policy" ON public."transactions" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "transactions_select_policy" ON public."transactions";
CREATE POLICY "transactions_select_policy" ON public."transactions" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM (stadiums s
     JOIN bookings b ON ((b.stadium_id = s.id)))
  WHERE ((b.id = transactions.booking_id) AND (s.owner_id = auth.uid())))) OR (( SELECT users.role
   FROM users
  WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::text, 'co_founder'::text]))));

DROP POLICY IF EXISTS "users_delete_policy" ON public."users";
CREATE POLICY "users_delete_policy" ON public."users" AS PERMISSIVE FOR DELETE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = id));

DROP POLICY IF EXISTS "users_insert_policy" ON public."users";
CREATE POLICY "users_insert_policy" ON public."users" AS PERMISSIVE FOR INSERT TO {, p, u, b, l, i, c, } WITH CHECK (((auth.uid() = id) OR (auth.role() = 'anon'::text) OR (auth.role() = 'service_role'::text)));

DROP POLICY IF EXISTS "users_select_policy" ON public."users";
CREATE POLICY "users_select_policy" ON public."users" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (((auth.role() = 'service_role'::text) OR ((auth.uid() IS NOT NULL) AND (auth.uid() = id)) OR ((auth.uid() IS NOT NULL) AND (is_blocked = false))));

DROP POLICY IF EXISTS "users_update_policy" ON public."users";
CREATE POLICY "users_update_policy" ON public."users" AS PERMISSIVE FOR UPDATE TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));

DROP POLICY IF EXISTS "Admins full access" ON public."vsp_1v1_registrations";
CREATE POLICY "Admins full access" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "vsp_1v1_registrations_insert" ON public."vsp_1v1_registrations";
CREATE POLICY "vsp_1v1_registrations_insert" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR INSERT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } WITH CHECK ((auth.uid() = user_id));

DROP POLICY IF EXISTS "vsp_1v1_registrations_select" ON public."vsp_1v1_registrations";
CREATE POLICY "vsp_1v1_registrations_select" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "Admins full access" ON public."vsp_1vs1_players";
CREATE POLICY "Admins full access" ON public."vsp_1vs1_players" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "admin_manage_1v1_players" ON public."vsp_1vs1_players";
CREATE POLICY "admin_manage_1v1_players" ON public."vsp_1vs1_players" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "vsp_1vs1_players_select_unified" ON public."vsp_1vs1_players";
CREATE POLICY "vsp_1vs1_players_select_unified" ON public."vsp_1vs1_players" AS PERMISSIVE FOR SELECT TO {, p, u, b, l, i, c, } USING (true);

DROP POLICY IF EXISTS "webhook_logs_admin_only" ON public."webhook_logs";
CREATE POLICY "webhook_logs_admin_only" ON public."webhook_logs" AS PERMISSIVE FOR ALL TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "webhook_logs_admin_select" ON public."webhook_logs";
CREATE POLICY "webhook_logs_admin_select" ON public."webhook_logs" AS PERMISSIVE FOR SELECT TO {, a, u, t, h, e, n, t, i, c, a, t, e, d, } USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::text)))));



-- --------------------------------------------------------------------------
-- 8. FUNCTIONS & STORED PROCEDURES
-- --------------------------------------------------------------------------
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
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.current_players >= COALESCE(v_booking.total_field_capacity, 10) THEN
        RAISE EXCEPTION 'match_is_full';
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

-- Function: add_team_to_matchup_by_code
CREATE OR REPLACE FUNCTION public.add_team_to_matchup_by_code(p_booking_id uuid, p_invite_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_target_team RECORD;
    v_clean_code TEXT := upper(trim(p_invite_code));
    v_current_count INT;
    v_target_members_count INT;
    v_paid_fee_exists BOOLEAN;
BEGIN
    -- 1. Authentication Check (Fail-Closed)
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    IF v_clean_code IS NULL OR length(v_clean_code) < 4 THEN
        RAISE EXCEPTION 'Invalid invite code provided';
    END IF;

    -- 2. Verify Booking Ownership
    SELECT id, created_by_user_id, user_id, status, matchup_closed_at INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator can add teams to the matchup';
    END IF;

    IF v_booking.matchup_closed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot add teams: This matchup is already closed';
    END IF;

    -- 3. Lookup target team by active code & expiration
    SELECT id, name, logo_url, captain_id, invite_code_expires_at INTO v_target_team
    FROM public.teams
    WHERE active_invite_code = v_clean_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invite code';
    END IF;

    IF v_target_team.invite_code_expires_at IS NOT NULL AND v_target_team.invite_code_expires_at < timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'This invite code has expired. Please ask the captain to generate a new one.';
    END IF;

    -- 4. Check minimum 5 players requirement for official registration
    SELECT count(*) INTO v_target_members_count
    FROM public.team_members
    WHERE team_id = v_target_team.id;

    IF v_target_members_count < 5 THEN
        RAISE EXCEPTION 'Team "%" is incomplete (has %/5 members required for Matchups)', v_target_team.name, v_target_members_count;
    END IF;

    -- 5. Verify team is not already added to this booking
    IF EXISTS (
        SELECT 1 FROM public.matchup_teams
        WHERE booking_id = p_booking_id AND team_id = v_target_team.id
    ) THEN
        RAISE EXCEPTION 'Team "%" is already added to this matchup', v_target_team.name;
    END IF;

    -- 6. Count current teams in DB directly (Server-verified)
    SELECT count(*) INTO v_current_count
    FROM public.matchup_teams
    WHERE booking_id = p_booking_id;

    -- 7. Sixth team fee validation (Hard Requirement #7)
    IF v_current_count >= 5 THEN
        SELECT EXISTS (
            SELECT 1 FROM public.transactions
            WHERE booking_id = p_booking_id
            AND transaction_type = 'matchup_extra_teams_fee'
            AND status IN ('paid', 'completed')
        ) INTO v_paid_fee_exists;

        IF NOT v_paid_fee_exists THEN
            RAISE EXCEPTION 'LIMIT_REACHED_EXTRA_FEE_REQUIRED: Adding more than 5 teams requires 25 EGP extra fee';
        END IF;
    END IF;

    -- 8. Add team to matchup
    INSERT INTO public.matchup_teams (
        booking_id,
        team_id,
        added_by_user_id,
        joined_at
    )
    VALUES (
        p_booking_id,
        v_target_team.id,
        v_caller_id,
        timezone('utc'::text, now())
    );

    -- 9. Consume the invite code immediately (one-time use)
    UPDATE public.teams
    SET active_invite_code = NULL,
        invite_code_expires_at = NULL
    WHERE id = v_target_team.id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'team_id', v_target_team.id,
        'team_name', v_target_team.name,
        'logo_url', v_target_team.logo_url,
        'total_teams_now', (v_current_count + 1)
    );
END;
$function$
;

-- Function: admin_approve_owner_atomic
CREATE OR REPLACE FUNCTION public.admin_approve_owner_atomic(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    UPDATE public.users
    SET verification_status = 'approved',
        is_identity_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_owner_id;

    UPDATE public.stadiums
    SET is_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_owner_id;

    UPDATE public.championships
    SET is_approved = true,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_owner_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تهانينا! تم توثيق حسابك كصاحب ملعب رسمي 🏆',
        'تمت مراجعة مستنداتك وتوثيق حسابك بنجاح. ملاعبك وبطولاتك أصبحت الآن ظاهرة لجميع اللاعبين.',
        'stadium_approved',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id);
END;
$function$
;

-- Function: admin_record_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.admin_record_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_payment_method text, p_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_tx_id UUID;
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid payout amount');
    END IF;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        status,
        payment_method,
        reference_number,
        description,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout',
        'completed',
        p_payment_method,
        p_reference,
        'تسوية أرباح مالك ملعب من إدارة VSP',
        timezone('utc'::text, now())
    ) RETURNING id INTO v_tx_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تم تحويل أرباحك بنجاح! 💸',
        'تم إرسال مبلغ ' || p_amount || ' ج.م إلى حسابك عبر ' || p_payment_method || ' برقم مرجع: ' || p_reference,
        'info',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'transaction_id', v_tx_id, 'amount', p_amount);
END;
$function$
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
BEGIN
    -- 1. إنشاء الحساب في نظام المصادقة الداخلي لـ Supabase وتشفير كلمة المرور
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

    -- 2. إدراج أو تحديث الملف الشخصي للمالك (ON CONFLICT) لتفادي التعارض مع الـ Triggers الخلفية
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

-- Function: admin_resolve_dispute_atomic
CREATE OR REPLACE FUNCTION public.admin_resolve_dispute_atomic(p_booking_id uuid, p_final_outcome text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin authorization required');
        END IF;
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    UPDATE public.bookings
    SET status = 'completed',
        final_outcome = p_final_outcome,
        match_result_status = 'confirmed',
        pending_outcome = NULL,
        requires_admin_intervention = false,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    IF v_booking.player_team_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية للمباراة: ' || p_final_outcome, 'result_confirmation', timezone('utc'::text, now())
        FROM public.teams WHERE id = v_booking.player_team_id;
    END IF;

    IF v_booking.opponent_team_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية للمباراة: ' || p_final_outcome, 'result_confirmation', timezone('utc'::text, now())
        FROM public.teams WHERE id = v_booking.opponent_team_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'outcome', p_final_outcome);
END;
$function$
;

-- Function: admin_upgrade_owner_subscription_atomic
CREATE OR REPLACE FUNCTION public.admin_upgrade_owner_subscription_atomic(p_owner_id uuid, p_plan text, p_days integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_expires_at TIMESTAMPTZ;
    v_plan_title TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_admin_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_admin_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    -- التحقق من صحة الباقة
    IF p_plan NOT IN ('free_trial', 'basic', 'pro') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid subscription plan');
    END IF;

    v_expires_at := v_now + (p_days || ' days')::interval;

    IF p_plan = 'free_trial' THEN
        UPDATE public.users
        SET 
            subscription_plan = 'free_trial',
            trial_ends_at = v_expires_at,
            subscription_expires_at = NULL,
            updated_at = v_now
        WHERE id = p_owner_id;
        v_plan_title := 'الفترة التجريبية المجانية';
    ELSE
        UPDATE public.users
        SET 
            subscription_plan = p_plan,
            subscription_expires_at = v_expires_at,
            updated_at = v_now
        WHERE id = p_owner_id;
        v_plan_title := CASE WHEN p_plan = 'pro' THEN 'الباقة الاحترافية (Pro 👑)' ELSE 'الباقة الأساسية (Basic)' END;
    END IF;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    ) VALUES (
        p_owner_id,
        'تم ترقية اشتراكك بنجاح! 🏆',
        'تهانينا! تم تفعيل ' || v_plan_title || ' لمدة ' || p_days || ' يوماً. استمتع بكامل المزايا الآن.',
        'subscription',
        false,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'plan', p_plan,
        'expires_at', v_expires_at,
        'message', 'Owner subscription upgraded successfully'
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
    v_settlement RECORD;
    v_admin_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من صلاحيات المشرف
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_admin_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_admin_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Admin authorization required');
        END IF;
    END IF;

    SELECT * INTO v_settlement FROM public.payout_settlements WHERE id = p_settlement_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found');
    END IF;

    IF v_settlement.status = 'completed' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Settlement already completed');
    END IF;

    UPDATE public.payout_settlements
    SET 
        status = 'completed',
        admin_notes = p_admin_notes,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_settlement_id;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        v_settlement.owner_id,
        v_settlement.amount,
        'payout_disbursed',
        v_settlement.method,
        jsonb_build_object(
            'settlement_id', p_settlement_id,
            'destination', v_settlement.destination,
            'approved_by', auth.uid(),
            'notes', p_admin_notes
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'settlement_id', p_settlement_id, 'amount', v_settlement.amount);
END;
$function$
;

-- Function: auto_approve_tournament_matches_24h
CREATE OR REPLACE FUNCTION public.auto_approve_tournament_matches_24h()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tournament_matches') THEN
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
AS $function$
BEGIN
  -- تنزيل باقات Pro المنتهية إلى الوضع العادي وإلغاء تمييز الملاعب
  UPDATE public.stadiums s
  SET is_featured = FALSE,
      updated_at = NOW()
  FROM public.users u
  WHERE s.owner_id = u.id
    AND u.subscription_plan = 'pro'
    AND u.subscription_expires_at IS NOT NULL
    AND u.subscription_expires_at <= NOW();

  UPDATE public.users
  SET subscription_plan = 'free_trial',
      updated_at = NOW()
  WHERE subscription_plan = 'pro'
    AND subscription_expires_at IS NOT NULL
    AND subscription_expires_at <= NOW();
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

-- Function: auto_expire_pending_challenges
CREATE OR REPLACE FUNCTION public.auto_expire_pending_challenges()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- إلغاء التحديات المعلقة التي مر عليها 4 ساعات أو فاضل على مباراتها أقل من 12 ساعة
  UPDATE public.bookings
  SET status = 'cancelled',
      updated_at = NOW()
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND (
      NOW() - created_at >= INTERVAL '4 hours' OR
      start_time - NOW() <= INTERVAL '12 hours'
    );
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
            cancellation_reason = 'Payment session expired (5 minutes limit)',
            updated_at = NOW()
        WHERE status = 'pending'
          AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < NOW()
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
AS $function$
BEGIN
  -- إلغاء الحجوزات المعلقة غير المدفوعة بعد 10 دقائق
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    payment_status = 'failed',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to payment timeout]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND created_at <= NOW() - INTERVAL '10 minutes';

  -- إلغاء التحديات المعلقة إذا مر عليها 4 ساعات أو اقتربت المباراة لأقل من 12 ساعة
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Challenge expired automatically]'
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND (
      NOW() - created_at >= INTERVAL '4 hours' OR
      start_time - NOW() <= INTERVAL '12 hours'
    );
END;
$function$
;

-- Function: auto_reconcile_all_past_bookings
CREATE OR REPLACE FUNCTION public.auto_reconcile_all_past_bookings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.bookings
  SET 
    status = 'completed',
    payment_status = CASE WHEN payment_method = 'cash' THEN 'paid' ELSE payment_status END,
    is_paid = CASE WHEN payment_method = 'cash' THEN TRUE ELSE is_paid END,
    updated_at = NOW()
  WHERE end_time < NOW()
    AND status = 'confirmed';
END;
$function$
;

-- Function: auto_reconcile_past_bookings
CREATE OR REPLACE FUNCTION public.auto_reconcile_past_bookings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
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
AS $function$
DECLARE
    r RECORD;
    v_submitted_by uuid;
    v_stalling_team_id uuid;
    v_stalling_captain_id uuid;
    v_outcome text;
BEGIN
    FOR r IN 
        SELECT 
            id, player_team_id, opponent_team_id, 
            pending_outcome, result_submitted_by_team_id,
            updated_at
        FROM public.bookings
        WHERE booking_type = 'challenge'
          AND match_result_status = 'waitingOpponent'
          AND status != 'cancelled'
          AND updated_at <= NOW() - INTERVAL '24 hours'
    LOOP
        v_outcome := r.pending_outcome;
        v_submitted_by := r.result_submitted_by_team_id;

        -- تحديد الفريق المماطل
        IF v_submitted_by = r.player_team_id THEN
            v_stalling_team_id := r.opponent_team_id;
        ELSE
            v_stalling_team_id := r.player_team_id;
        END IF;

        -- 1. اعتماد النتيجة رسمياً
        UPDATE public.bookings
        SET 
            final_outcome = v_outcome,
            match_result_status = 'confirmed',
            status = 'completed',
            pending_outcome = NULL,
            result_submitted_by_team_id = NULL,
            notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-Approved after 24h timeout. 5 Fair-Play pts deducted from stalling team]',
            updated_at = NOW()
        WHERE id = r.id;

        -- 2. خصم 5 نقاط من تقييم اللعب النظيف للفريق المتجاهل
        IF v_stalling_team_id IS NOT NULL THEN
            UPDATE public.teams
            SET 
                fair_play_score = GREATEST(0, fair_play_score - 5),
                updated_at = NOW()
            WHERE id = v_stalling_team_id;

            -- إرسال إشعار تحذيري لكابتن الفريق
            SELECT captain_id INTO v_stalling_captain_id FROM public.teams WHERE id = v_stalling_team_id;
            IF v_stalling_captain_id IS NOT NULL THEN
                INSERT INTO public.notifications (user_id, title, body, type, booking_id, created_at, is_read)
                VALUES (
                    v_stalling_captain_id,
                    '⚠️ خصم نقاط اللعب النظيف لتجاهل النتيجة',
                    'تم اعتماد نتيجة المباراة تلقائياً وخصم 5 نقاط من تقييم فريقك لعدم الرد خلال مهلة الـ 24 ساعة.',
                    'info',
                    r.id,
                    NOW(),
                    FALSE
                );
            END IF;
        END IF;
    END LOOP;
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

-- Function: calculate_elo_on_match_completion
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    home_elo INT;
    away_elo INT;
    new_home_elo INT;
    new_away_elo INT;
    outcome FLOAT;
BEGIN
    IF NEW.status = 'confirmed' 
       AND NEW.booking_type = 'challenge' 
       AND NEW.final_outcome IS NOT NULL 
       AND COALESCE(NEW.elo_processed, false) = false THEN
        
        SELECT COALESCE(points, 1000) INTO home_elo FROM public.teams WHERE id = NEW.player_team_id;
        SELECT COALESCE(points, 1000) INTO away_elo FROM public.teams WHERE id = NEW.opponent_team_id;

        IF home_elo IS NOT NULL AND away_elo IS NOT NULL THEN
            IF NEW.final_outcome = 'homeWin' THEN outcome := 1.0;
            ELSIF NEW.final_outcome = 'draw' THEN outcome := 0.5;
            ELSE outcome := 0.0;
            END IF;

            new_home_elo := round(home_elo + 32 * (outcome - (1.0 / (1.0 + power(10, (away_elo - home_elo)::float / 400.0)))));
            new_away_elo := round(away_elo + 32 * ((1.0 - outcome) - (1.0 / (1.0 + power(10, (home_elo - away_elo)::float / 400.0)))));

            UPDATE public.teams 
            SET points = GREATEST(0, new_home_elo), 
                matches_played = COALESCE(matches_played, 0) + 1,
                wins = COALESCE(wins, 0) + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                draws = COALESCE(draws, 0) + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = COALESCE(losses, 0) + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.player_team_id;

            UPDATE public.teams 
            SET points = GREATEST(0, new_away_elo), 
                matches_played = COALESCE(matches_played, 0) + 1,
                wins = COALESCE(wins, 0) + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                draws = COALESCE(draws, 0) + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = COALESCE(losses, 0) + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.opponent_team_id;

            NEW.elo_processed := true;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$
;

-- Function: cancel_booking_with_refund_atomic
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid, p_user_id uuid, p_reason text DEFAULT 'Cancelled by user'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_booking RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_tx_id UUID;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- Check 2-hour cutoff rule for players
    IF v_booking.start_time <= (timezone('utc'::text, now()) + INTERVAL '2 hours') THEN
        RETURN jsonb_build_object('success', false, 'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة.');
    END IF;

    -- Calculate refund amount if online payment was made
    IF v_booking.payment_status = 'paid' OR v_booking.payment_status = 'confirmed' THEN
        v_refund_amount := COALESCE(v_booking.deposit_amount, v_booking.total_price, 0.00);
    END IF;

    -- Update booking status to cancelled
    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = CASE WHEN v_refund_amount > 0 THEN 'refunded' ELSE payment_status END,
        cancellation_reason = p_reason,
        cancelled_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- If deposit was paid, log refund in transactions ledger
    IF v_refund_amount > 0 THEN
        INSERT INTO public.transactions (
            user_id,
            booking_id,
            amount,
            type,
            status,
            payment_method,
            description,
            created_at
        ) VALUES (
            p_user_id,
            p_booking_id,
            v_refund_amount,
            'refund',
            'completed',
            v_booking.payment_method,
            'استرداد إلكتروني لقيمة حجز ملغى: ' || v_booking.stadium_name,
            timezone('utc'::text, now())
        ) RETURNING id INTO v_tx_id;
    END IF;

    -- Notify Stadium Owner
    IF v_booking.owner_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            created_at
        ) VALUES (
            v_booking.owner_id,
            'إلغاء حجز في ملعبك ⚠️',
            'قام اللاعب بإلغاء حجزه المقرر في ' || v_booking.stadium_name || ' وتم إتاحة الموعد مجدداً.',
            'booking_cancelled',
            timezone('utc'::text, now())
        );
    END IF;

    -- Notify User
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_user_id,
        'تم إلغاء الحجز بنجاح ✅',
        CASE WHEN v_refund_amount > 0 
            THEN 'تم إلغاء حجزك وجاري رد مبلغ ' || v_refund_amount || ' ج.م إلى وسيلة الدفع الخاصة بك.'
            ELSE 'تم إلغاء حجزك بنجاح دون أي رسوم.' END,
        'booking_cancelled',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'refund_amount', v_refund_amount,
        'transaction_id', v_tx_id
    );
END;
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

-- Function: check_owner_stadium_limit
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_owner RECORD;
    v_count INT;
    v_max_allowed INT := 1;
BEGIN
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', true);
    END IF;

    IF v_owner.subscription_plan = 'pro' AND (v_owner.subscription_expires_at IS NULL OR v_owner.subscription_expires_at > NOW()) THEN
        v_max_allowed := 3;
    ELSIF v_owner.subscription_plan = 'basic' AND (v_owner.subscription_expires_at IS NULL OR v_owner.subscription_expires_at > NOW()) THEN
        v_max_allowed := 1;
    ELSIF v_owner.subscription_plan = 'free_trial' AND (v_owner.trial_ends_at IS NULL OR v_owner.trial_ends_at > NOW()) THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 1;
    END IF;

    SELECT COUNT(*) INTO v_count FROM public.stadiums WHERE owner_id = p_owner_id AND is_deleted_by_owner = false;

    IF v_count >= v_max_allowed THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'current_count', v_count,
            'max_allowed', v_max_allowed,
            'message', '??? ???? ???? ?????? ??????? ???????? ?????? (' || v_max_allowed || ' ?????). ???? ????? ????? ?????? ????? ?????.'
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'current_count', v_count,
        'max_allowed', v_max_allowed
    );
END;
$function$
;

-- Function: check_owner_stadium_limit
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_plan text;
  v_expires_at timestamptz;
  v_trial_ends_at timestamptz;
  v_current_count int;
  v_max_allowed int := 1;
BEGIN
  -- جلب باقة المالك وتاريخ انتهائها
  SELECT subscription_plan, subscription_expires_at, trial_ends_at
  INTO v_plan, v_expires_at, v_trial_ends_at
  FROM public.users
  WHERE id = NEW.owner_id;

  -- تحديد الحد الأقصى للملاعب المسموحة
  IF v_plan = 'pro' AND (v_expires_at IS NULL OR v_expires_at > NOW()) THEN
    v_max_allowed := 3; -- باقة Pro تسمح حتى 3 ملاعب
  ELSIF v_plan = 'basic' AND (v_expires_at IS NULL OR v_expires_at > NOW()) THEN
    v_max_allowed := 1; -- باقة Basic تسمح بملعب واحد
  ELSIF v_plan = 'free_trial' AND (v_trial_ends_at IS NULL OR v_trial_ends_at > NOW()) THEN
    v_max_allowed := 1; -- الفترة التجريبية تسمح بملعب واحد
  ELSE
    v_max_allowed := 0; -- في حال انتهاء الاشتراك
  END IF;

  -- حساب عدد الملاعب الحالية غير المحذوفة للمالك
  SELECT COUNT(*) INTO v_current_count
  FROM public.stadiums
  WHERE owner_id = NEW.owner_id
    AND is_deleted_by_owner = false
    AND (TG_OP = 'INSERT' OR id <> NEW.id);

  IF v_current_count >= v_max_allowed THEN
    RAISE EXCEPTION 'Reached maximum stadiums limit (%) for current subscription plan (%)', v_max_allowed, v_plan;
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
 SET search_path TO 'public'
AS $function$
DECLARE
  v_team_count int;
  v_player_teams_count int;
BEGIN
  -- 1. فحص سعة الفريق (12 لاعباً كحد أقصى)
  SELECT COUNT(*) INTO v_team_count
  FROM public.team_members
  WHERE team_id = NEW.team_id;

  IF v_team_count >= 12 THEN
    RAISE EXCEPTION 'Team capacity reached: Maximum 12 players allowed per team.';
  END IF;

  -- 2. فحص عدد الفرق التي انضم إليها اللاعب (3 فرق كحد أقصى)
  SELECT COUNT(*) INTO v_player_teams_count
  FROM public.team_members
  WHERE user_id = NEW.user_id;

  IF v_player_teams_count >= 3 THEN
    RAISE EXCEPTION 'Player team limit reached: A player can join up to 3 teams only.';
  END IF;

  RETURN NEW;
END;
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
    has_champion BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.team_members tm
        JOIN public.vsp_1vs1_players p1v1 ON tm.user_id = p1v1.id
        WHERE tm.team_id = p_team_id AND p1v1.titles > 0
    ) INTO has_champion;
    
    RETURN has_champion;
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

-- Function: close_matchup_atomic
CREATE OR REPLACE FUNCTION public.close_matchup_atomic(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_results_count INT;
BEGIN
    -- 1. Authentication Check
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Verify Booking Ownership
    SELECT id, created_by_user_id, user_id, status, matchup_closed_at INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator can close the matchup';
    END IF;

    -- 3. Hard Requirement #6: Must have at least 1 result recorded before leaving/closing
    SELECT count(*) INTO v_results_count
    FROM public.matchup_results
    WHERE booking_id = p_booking_id;

    IF v_results_count = 0 THEN
        RAISE EXCEPTION 'Cannot close matchup without recording at least one match result';
    END IF;

    -- 4. Close the matchup
    UPDATE public.bookings
    SET matchup_closed_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'closed_at', timezone('utc'::text, now()),
        'total_results_recorded', v_results_count
    );
END;
$function$
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
CREATE OR REPLACE FUNCTION public.complete_user_registration(p_user_id uuid, p_phone text, p_name text DEFAULT NULL::text, p_position text DEFAULT NULL::text, p_governorate text DEFAULT 'Cairo'::text, p_date_of_birth timestamp with time zone DEFAULT NULL::timestamp with time zone, p_p2p_instapay text DEFAULT NULL::text, p_p2p_vodafone text DEFAULT NULL::text, p_p2p_bank text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.uid());
    v_caller_role TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User ID required');
    END IF;

    -- 🔒 منع الـ IDOR: المستخدم يمكنه فقط استكمال حسابه الشخصي أو الأدمن أو service_role
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_uid IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You can only complete registration for your own account');
            END IF;
        END IF;
    END IF;

    -- التحقق من عدم تكرار رقم الهاتف مع مستخدم آخر
    IF p_phone IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.users 
        WHERE phone = p_phone AND id != v_uid
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Phone number already in use');
    END IF;

    UPDATE public.users
    SET 
        phone = COALESCE(p_phone, phone),
        name = COALESCE(NULLIF(p_name, ''), name),
        position = COALESCE(p_position, position, 'ST'),
        governorate = COALESCE(p_governorate, governorate, 'Cairo'),
        date_of_birth = COALESCE(p_date_of_birth, date_of_birth),
        p2p_instapay = COALESCE(p_p2p_instapay, p2p_instapay),
        p2p_vodafone = COALESCE(p_p2p_vodafone, p2p_vodafone),
        p2p_bank = COALESCE(p_p2p_bank, p2p_bank),
        is_registration_complete = true,
        is_email_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Registration completed successfully'
    );
END;
$function$
;

-- Function: confirm_cash_booking_atomic
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
BEGIN
    -- 1. جلب بيانات الحجز وقفل السجل
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 🔒 2. التحقق الصارم من الهوية والصلاحية: المالك الحقيقي للملعب أو الإدارة أو service_role
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- 3. تحديث حالة الحجز إلى مدفوع ومكتمل
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        deposit_paid = p_total_price,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- 4. إدراج قيد في سجل المعاملات المالية المركزي
    INSERT INTO public.transactions (
        user_id,
        booking_id,
        amount,
        type,
        status,
        payment_method,
        currency,
        description,
        created_at
    ) VALUES (
        v_booking.owner_id,
        p_booking_id,
        p_total_price,
        'cash_settlement',
        'completed',
        'cash',
        'EGP',
        'تحصيل كاش مؤكد بالملعب لحجز #' || substring(p_booking_id::text, 1, 8),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'amount', p_total_price);
END;
$function$
;

-- Function: confirm_matchup_atomic
CREATE OR REPLACE FUNCTION public.confirm_matchup_atomic(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_teams_count INT;
    v_mode TEXT;
BEGIN
    -- 1. Authentication Check
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Verify Booking Ownership
    SELECT id, created_by_user_id, user_id, status INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator can confirm the matchup';
    END IF;

    -- 3. Calculate added teams directly from DB
    SELECT count(*) INTO v_teams_count
    FROM public.matchup_teams
    WHERE booking_id = p_booking_id;

    IF v_teams_count < 2 THEN
        RAISE EXCEPTION 'Cannot confirm matchup: At least 2 teams must be added (Current: %)', v_teams_count;
    END IF;

    -- 4. Automatically determine mode from live teams count
    IF v_teams_count = 2 THEN
        v_mode := 'duo';
    ELSE
        v_mode := 'winner_stays';
    END IF;

    -- 5. Update booking
    UPDATE public.bookings
    SET matchup_mode = v_mode,
        booking_type = 'matchup'
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

-- Function: confirm_tournament_order_atomic
CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(p_order_reference text, p_paymob_transaction_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_order RECORD;
    v_caller_role TEXT;
BEGIN
    -- 🔒 حظر الاستدعاء من المستخدمين العاديين وحصره بالسيرفر
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Tournament orders can only be confirmed via server webhook.');
        END IF;
    END IF;

    SELECT * INTO v_order FROM public.tournament_orders 
    WHERE order_reference = p_order_reference FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament order not found');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Order already confirmed');
    END IF;

    -- تحديث حالة الطلب
    UPDATE public.tournament_orders
    SET 
        payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_order.id;

    -- إدراج الفريق في البطولة
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), v_order.team_id),
        paid_teams = array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), v_order.team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_order.championship_id;

    -- حفظ المعاملة المالية في جدول transactions
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        v_order.championship_id,
        v_order.captain_user_id,
        v_order.amount,
        'digital',
        'paymob',
        jsonb_build_object(
            'paymob_transaction_id', p_paymob_transaction_id,
            'order_reference', p_order_reference,
            'team_id', v_order.team_id
        ),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'order_id', v_order.id, 'team_id', v_order.team_id);
END;
$function$
;

-- Function: create_booking_atomic
CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0.0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_conflict_count INT;
    v_new_booking_id UUID;
    v_stadium RECORD;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_duration_hours NUMERIC;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0.0;
    v_final_total_price NUMERIC;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_owner_id UUID;
    v_calculated_fee NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_final_deposit_paid NUMERIC;
    v_locked_until TIMESTAMPTZ := NULL;
BEGIN
    -- 1. التحقق من هوية المستدعي (Authentication & Authorization)
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإتمام الحجز.');
    END IF;

    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

    IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
        RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;

    -- 2. التحقق من صحة التوقيت
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;

    -- 3. قفل الملعب استشارياً لمنع الحجز المزدوج في نفس اللحظة (Advisory Lock)
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. التحقق من وجود وحالة الملعب وجلب البيانات الرسمية من قاعدة البيانات
    SELECT * INTO v_stadium
    FROM public.stadiums 
    WHERE id::text = p_stadium_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 🔒 5. حساب السعر الحقيقي وحصانة المالك من السيرفر (Strict Fail-Closed Price & Deposit Calculation)
    v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
    v_calculated_price := round(v_hourly_rate * v_duration_hours, 2);

    IF p_rent_ball IS TRUE THEN
        BEGIN
            v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0.0);
        EXCEPTION WHEN OTHERS THEN
            v_ball_price := 0.0;
        END;
        v_calculated_price := v_calculated_price + v_ball_price;
    END IF;

    -- 🔒 رفض صريح وقطعي لأي تسعيرة غير صالحة أو منعدمة (Fail-Closed Zero Tolerance)
    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.'
        );
    END IF;

    v_final_total_price := v_calculated_price;

    -- قراءة قواعد العربون والمالك الرسمي من سجل الملعب بالداتابيز
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 6. التحقق من حالة المستخدم وقيود عدم الحضور
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- قيد الحجز النقدي الواحد النشط
    IF p_payment_method = 'cash' THEN
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > NOW();

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 7. فحص تضارب المواعيد بدقة مع استبعاد الحجوزات المعلقة المنتهية (أكثر من 5 دقائق)
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < NOW())
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'SLOT_LOCKED_OR_TAKEN',
            'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.'
        );
    END IF;

    -- 8. ضبط الحالة وقفل الـ 5 دقائق للدفع الإلكتروني
    IF p_payment_method IN ('paymob', 'card', 'wallet') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NOW() + INTERVAL '5 minutes';
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 9. حساب رسوم المنصة بدقة في الخادم
    v_calculated_fee := round((v_final_total_price * 0.0475) + 3.0, 2);

    -- 10. إدراج الحجز بالسعر والمالك المحسوبين من السيرفر
    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price, platform_fee,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, locked_until, created_at, updated_at
    ) VALUES (
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
        p_start_time, p_end_time, p_booking_type, v_final_total_price, v_calculated_fee,
        COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
        COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
        p_is_private, p_rent_ball,
        v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
        p_payment_method, 'pending', v_final_status, v_final_is_paid,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id::uuid], v_locked_until, NOW(), NOW()
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'deposit_amount', v_final_deposit_amount,
        'needs_deposit', v_final_needs_deposit,
        'locked_until', v_locked_until
    );
END;
$function$
;

-- Function: create_owner_on_behalf
CREATE OR REPLACE FUNCTION public.create_owner_on_behalf(p_email text, p_password text, p_name text, p_phone text, p_governorate text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
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

-- Function: create_tournament_order_atomic
CREATE OR REPLACE FUNCTION public.create_tournament_order_atomic(p_championship_id uuid, p_team_id uuid, p_player_ids uuid[] DEFAULT ARRAY[]::uuid[], p_guest_names text[] DEFAULT ARRAY[]::text[], p_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_order_ref TEXT;
    v_order_id UUID;
    v_joined_count INT;
    v_caller_role TEXT;
    v_real_amount NUMERIC;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    -- 1. التحقق من وجود وحالة البطولة
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is not open for registration');
    END IF;

    -- 🔒 2. التحقق من الفريق وصلاحية الكابتن
    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only the team captain can register the team for a tournament');
        END IF;
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team is already registered in this championship');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NULL THEN v_joined_count := 0; END IF;

    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is already full');
    END IF;

    -- 🔒 3. فرض سعر الاشتراك من قاعدة البيانات (Zero-Trust Server Price)
    v_real_amount := COALESCE(v_champ.entry_fee, 0);
    IF v_real_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'This championship has no entry fee; use join_championship_atomic directly');
    END IF;

    -- توليد رقم مرجعي فريد للطلب
    v_order_ref := 'TOURN_' || SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 12);

    -- إدراج الطلب بحالة pending
    INSERT INTO public.tournament_orders (
        order_reference,
        championship_id,
        team_id,
        captain_user_id,
        amount,
        payment_status,
        player_ids,
        guest_names,
        created_at,
        updated_at
    ) VALUES (
        v_order_ref,
        p_championship_id,
        p_team_id,
        auth.uid(),
        v_real_amount,
        'pending',
        COALESCE(p_player_ids, ARRAY[]::UUID[]),
        COALESCE(p_guest_names, ARRAY[]::TEXT[]),
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    ) RETURNING id INTO v_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_reference', v_order_ref,
        'amount', v_real_amount
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
    v_caller_role TEXT;
    v_team_name TEXT;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    -- 🔒 التحقق من صلاحية منظم البطولة
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can crown tournament champion');
            END IF;
        END IF;
    END IF;

    IF p_champion_team_name IS NULL THEN
        SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
    ELSE
        v_team_name := p_champion_team_name;
    END IF;

    UPDATE public.championships
    SET status = 'completed',
        champion_team_id = p_champion_team_id,
        champion_team_name = v_team_name,
        winner_team_id = p_champion_team_id,
        winner_team_name = v_team_name,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    UPDATE public.teams
    SET championships_won = COALESCE(championships_won, 0) + 1,
        points = COALESCE(points, 0) + 100,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_champion_team_id;

    RETURN jsonb_build_object('success', true, 'champion_team_id', p_champion_team_id, 'championship_id', p_championship_id);
END;
$function$
;

-- Function: delete_chat_for_user
CREATE OR REPLACE FUNCTION public.delete_chat_for_user(p_conversation_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.chat_messages
  SET deleted_for_users = array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)
  WHERE conversation_id = p_conversation_id
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);

  UPDATE public.conversations
  SET deleted_for_users = array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)
  WHERE id = p_conversation_id
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);
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

-- Function: delete_user_permanently
CREATE OR REPLACE FUNCTION public.delete_user_permanently(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_role TEXT;
BEGIN
    -- 🔒 التحقق الصارم من أن المتصل يحذف حسابه الشخصي فقط
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: يمكنك حذف حسابك الشخصي فقط.');
            END IF;
        END IF;
    END IF;

    -- حذف من الجداول التابعة
    DELETE FROM public.notifications WHERE user_id = p_user_id;
    DELETE FROM public.reviews WHERE user_id = p_user_id;
    DELETE FROM public.reports WHERE reporter_id = p_user_id;
    DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
    
    -- حذف المستخدم من جدول users
    DELETE FROM public.users WHERE id = p_user_id;

    -- حذف المستخدم من auth.users
    BEGIN
        DELETE FROM auth.users WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object('success', true, 'deleted_user_id', p_user_id);
END;
$function$
;

-- Function: dismiss_no_show_penalty
CREATE OR REPLACE FUNCTION public.dismiss_no_show_penalty(p_player_id uuid, p_booking_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_new_no_show int;
BEGIN
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
BEGIN
  -- 1. التحقق من دقة الـ GPS (يجب أن تكون <= 50 متراً لمنع التزييف)
  IF p_accuracy > 50 THEN
    RAISE EXCEPTION 'gps_accuracy_too_low';
  END IF;

  -- 2. جلب بيانات الحجز
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id::text = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking_not_found';
  END IF;

  -- 3. التحقق من مهلة الـ 60 دقيقة من نهاية المباراة
  IF NOW() > (v_booking.end_time + INTERVAL '60 minutes') THEN
    RAISE EXCEPTION 'dispute_window_expired';
  END IF;

  -- 4. جلب إحداثيات الملعب
  SELECT * INTO v_stadium
  FROM public.stadiums
  WHERE id = v_booking.stadium_id;

  IF v_stadium.lat IS NULL OR v_stadium.lng IS NULL THEN
    RAISE EXCEPTION 'stadium_coordinates_missing';
  END IF;

  -- 5. حساب المسافة الجغرافية (Haversine Formula)
  v_distance_meters := 6371000 * acos(
    cos(radians(v_stadium.lat)) * cos(radians(p_lat)) *
    cos(radians(p_lng) - radians(v_stadium.lng)) +
    sin(radians(v_stadium.lat)) * sin(radians(p_lat))
  );

  -- يجب أن يكون اللاعب ضمن نطاق 150 متراً من الملعب
  IF v_distance_meters > 150 THEN
    RAISE EXCEPTION 'not_at_stadium';
  END IF;

  -- 6. إلغاء عقوبة الـ No-Show وإعادة النقاط للاعب
  UPDATE public.users
  SET 
    no_show_count = GREATEST(0, no_show_count - 1),
    is_blocked = false,
    updated_at = NOW()
  WHERE id::text = p_player_id;

  -- تحديث الحجز بنجاح الطعن
  UPDATE public.bookings
  SET 
    is_dispute_approved = true,
    match_result_status = 'confirmed',
    updated_at = NOW()
  WHERE id::text = p_booking_id;

  RETURN true;
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
BEGIN
  -- جلب بيانات اللاعب بالكامل من جدول المستخدمين
  SELECT is_blocked, COALESCE(no_show_count, 0) as no_show_count INTO v_user_record
  FROM public.users
  WHERE id = NEW.created_by_user_id;

  IF FOUND THEN
    -- أ) صمام الأمان الإداري الشامل: منع أي حجز (كاش أو أونلاين) إذا كان الحساب محظوراً
    IF (v_user_record.is_blocked = true) THEN
      RAISE EXCEPTION 'حسابك معلق حالياً من قبل الإدارة. لا يمكنك إجراء حجوزات جديدة.';
    END IF;

    -- ب) منع حجز الكاش فقط إذا كان عدد غياب اللاعب 2 أو أكثر
    IF (NEW.payment_method = 'cash' AND v_user_record.no_show_count >= 2) THEN
      RAISE EXCEPTION 'حسابك مقيد مؤقتاً من الحجوزات النقدية بسبب تكرار عدم الحضور (No-Show). يرجى الدفع إلكترونياً لتأكيد الحجز.';
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

-- Function: get_admin_metrics
CREATE OR REPLACE FUNCTION public.get_admin_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_total_owners int;
    v_pending_verifications int;
    v_active_stadiums int;
BEGIN
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
AS $function$
DECLARE
  v_total_owners integer;
  v_pending_verifications integer;
  v_active_bookings integer;
  v_total_revenue numeric;
BEGIN
  -- التحقق من صلاحية الأدمن
  IF NOT EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = ANY(ARRAY['admin', 'co_founder'])
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT count(*) INTO v_total_owners FROM public.users WHERE role = 'owner';
  SELECT count(*) INTO v_pending_verifications FROM public.users WHERE role = 'owner' AND verification_status = 'pending';
  SELECT count(*) INTO v_active_bookings FROM public.bookings WHERE status IN ('confirmed', 'upcoming');
  SELECT COALESCE(sum(amount), 0) INTO v_total_revenue FROM public.transactions;

  RETURN jsonb_build_object(
    'total_owners', v_total_owners,
    'pending_verifications', v_pending_verifications,
    'active_bookings', v_active_bookings,
    'total_revenue', v_total_revenue
  );
END;
$function$
;

-- Function: get_championship_standings
CREATE OR REPLACE FUNCTION public.get_championship_standings(p_championship_id uuid, p_group_name text DEFAULT NULL::text)
 RETURNS TABLE(team_id uuid, team_name text, played bigint, won bigint, drawn bigint, lost bigint, goals_for bigint, goals_against bigint, goal_difference bigint, points bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH group_teams AS (
    SELECT DISTINCT
      t.id AS t_id,
      t.name AS t_name
    FROM public.tournament_matches m
    JOIN public.teams t ON (t.id = m.home_team_id OR t.id = m.away_team_id)
    WHERE m.championship_id = p_championship_id
      AND (p_group_name IS NULL OR m.group_name = p_group_name)
      AND (m.stage = 'group_stage' OR m.stage = 'league')
    
    UNION
    
    SELECT cr.team_id AS t_id, t.name AS t_name
    FROM public.championship_rosters cr
    JOIN public.teams t ON t.id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND p_group_name IS NULL
  ),
  match_results AS (
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
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
      AND (p_group_name IS NULL OR m.group_name = p_group_name)

    UNION ALL

    SELECT
      m.away_team_id AS t_id,
      1 AS p,
      CASE WHEN m.away_score > m.home_score THEN 1 ELSE 0 END AS w,
      CASE WHEN m.away_score = m.home_score THEN 1 ELSE 0 END AS d,
      CASE WHEN m.away_score < m.home_score THEN 1 ELSE 0 END AS l,
      COALESCE(m.away_score, 0) AS gf,
      COALESCE(m.home_score, 0) AS ga,
      CASE
        WHEN m.away_score > m.home_score THEN 3
        WHEN m.away_score = m.home_score THEN 1
        ELSE 0
      END AS pts
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
      AND (p_group_name IS NULL OR m.group_name = p_group_name)
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

-- Function: get_nearby_stadiums
CREATE OR REPLACE FUNCTION public.get_nearby_stadiums(user_lat double precision, user_lng double precision, max_limit integer DEFAULT 10)
 RETURNS SETOF stadiums
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.stadiums
    WHERE 
        COALESCE(is_verified, false) = true 
        AND COALESCE(is_blocked, false) = false
    LIMIT max_limit;
END;
$function$
;

-- Function: get_operational_date
CREATE OR REPLACE FUNCTION public.get_operational_date(p_timestamp timestamp with time zone, p_shift_start_hour integer DEFAULT 6)
 RETURNS date
 LANGUAGE plpgsql
 IMMUTABLE
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

-- Function: get_owner_booked_hours
CREATE OR REPLACE FUNCTION public.get_owner_booked_hours(p_owner_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0), 0)
  FROM bookings
  WHERE owner_id = p_owner_id
    AND status <> 'cancelled';
$function$
;

-- Function: get_owner_revenue
CREATE OR REPLACE FUNCTION public.get_owner_revenue(p_owner_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(SUM(total_price), 0)
  FROM bookings
  WHERE owner_id = p_owner_id
    AND payment_status = 'paid';
$function$
;

-- Function: global_search
CREATE OR REPLACE FUNCTION public.global_search(search_term text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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

  -- 3. البطولات
  SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
  INTO v_championships
  FROM (
    SELECT id, name, type, start_date, entry_fee, grand_prize, status, logo_url
    FROM public.championships
    WHERE name ILIKE '%' || v_clean_query || '%'
      AND status IN ('open', 'ongoing')
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
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_url text;
BEGIN
  v_url := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/fcm_push';
  
  -- Send async HTTP POST via pg_net with internal authorization
  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer internal_db_trigger'
    ),
    body := jsonb_build_object(
      'record', row_to_json(NEW)
    )
  );
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Non-blocking fail-safe: Database insertion NEVER fails if push network fails
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
DECLARE
  v_role text;
  v_name text;
  v_avatar text;
  v_phone text;
  v_governorate text;
  v_dob timestamptz;
  v_position text;
  v_is_complete boolean;
BEGIN
  -- 🔒 قصر الرتب المسموح بطلبها على player أو owner فقط (منع تصعيد الأدمن نهائياً)
  v_role := COALESCE(new.raw_user_meta_data->>'role', 'player');
  IF v_role NOT IN ('player', 'owner') THEN
    v_role := 'player';
  END IF;

  -- 2. استخراج الاسم
  v_name := COALESCE(
    NULLIF(new.raw_user_meta_data->>'full_name', ''),
    NULLIF(new.raw_user_meta_data->>'name', ''),
    split_part(new.email, '@', 1)
  );

  -- 3. استخراج صورة الحساب
  v_avatar := COALESCE(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    NULL
  );

  -- 4. استخراج رقم الهاتف والمحافظة وتاريخ الميلاد
  v_phone := COALESCE(
    NULLIF(new.raw_user_meta_data->>'phone', ''),
    NULLIF(new.phone, '')
  );

  v_governorate := COALESCE(
    NULLIF(new.raw_user_meta_data->>'governorate', ''),
    'Cairo'
  );

  v_position := COALESCE(
    NULLIF(new.raw_user_meta_data->>'position', ''),
    'GK'
  );

  BEGIN
    v_dob := (new.raw_user_meta_data->>'date_of_birth')::timestamptz;
  EXCEPTION WHEN OTHERS THEN
    v_dob := NULL;
  END;

  IF v_phone IS NOT NULL AND length(regexp_replace(v_phone, '\D', '', 'g')) >= 9 THEN
    v_is_complete := TRUE;
  ELSE
    v_is_complete := FALSE;
  END IF;

  -- 5. إدراج أو تحديث المستخدم في public.users
  INSERT INTO public.users (
    id,
    email,
    name,
    role,
    phone,
    governorate,
    position,
    date_of_birth,
    profile_image_url,
    is_email_verified,
    is_registration_complete,
    created_at,
    updated_at
  ) VALUES (
    new.id,
    COALESCE(new.email, ''),
    v_name,
    v_role,
    v_phone,
    v_governorate,
    v_position,
    v_dob,
    v_avatar,
    TRUE,
    v_is_complete,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(public.users.name, ''), EXCLUDED.name),
    role = COALESCE(NULLIF(public.users.role, ''), EXCLUDED.role),
    phone = COALESCE(NULLIF(public.users.phone, ''), EXCLUDED.phone),
    governorate = COALESCE(NULLIF(public.users.governorate, ''), EXCLUDED.governorate),
    position = COALESCE(NULLIF(public.users.position, ''), EXCLUDED.position),
    date_of_birth = COALESCE(public.users.date_of_birth, EXCLUDED.date_of_birth),
    profile_image_url = COALESCE(public.users.profile_image_url, EXCLUDED.profile_image_url),
    is_email_verified = TRUE,
    is_registration_complete = CASE 
      WHEN public.users.is_registration_complete = TRUE THEN TRUE 
      ELSE EXCLUDED.is_registration_complete 
    END,
    updated_at = timezone('utc'::text, now());

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    RETURN new;
END;
$function$
;

-- Function: handle_stadium_breaks_collision
CREATE OR REPLACE FUNCTION public.handle_stadium_breaks_collision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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
BEGIN
  v_is_split_shift := COALESCE((NEW.features->>'isSplitShift')::boolean, false);
  v_break_start_str := NEW.features->'breakTime'->>'start';
  v_break_end_str := NEW.features->'breakTime'->>'end';

  IF (v_is_split_shift = true AND v_break_start_str IS NOT NULL AND v_break_end_str IS NOT NULL) THEN
    
    -- تحويل الوقت بمرونة سواء كان 24h أو 12h AM/PM
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

    v_break_start := (current_date + v_start_time)::timestamptz;
    v_break_end := (current_date + v_end_time)::timestamptz;

    -- معالجة عبور منتصف الليل
    IF (v_break_end <= v_break_start) THEN
      v_break_end := v_break_end + interval '1 day';
    END IF;

    -- إلغاء الحجوزات المتداخلة مع فترة الراحة
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
AS $function$
BEGIN
    UPDATE public.banners
    SET clicks_count = clicks_count + 1
    WHERE id = p_banner_id;
END;
$function$
;

-- Function: increment_banner_views
CREATE OR REPLACE FUNCTION public.increment_banner_views(p_banner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE public.banners
    SET views_count = views_count + 1
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
BEGIN
  SELECT joined_user_ids, COALESCE(unread_counts, '{}'::jsonb)
  INTO v_joined_ids, v_unread
  FROM public.bookings
  WHERE id = p_booking_id;

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
    WHERE id = p_booking_id;
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
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND role IN ('admin', 'co_founder')
  );
$function$
;

-- Function: join_championship_atomic
CREATE OR REPLACE FUNCTION public.join_championship_atomic(p_championship_id uuid, p_team_id uuid, p_is_paid boolean DEFAULT false, p_player_ids uuid[] DEFAULT ARRAY[]::uuid[], p_guest_names text[] DEFAULT ARRAY[]::text[], p_total_paid_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_joined_count INT;
    v_caller_role TEXT;
    v_is_authorized_free_join BOOLEAN := false;
    v_is_paid_result BOOLEAN := false;
BEGIN
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship registration is closed');
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    -- 🔒 التحقق من صلاحية الكابتن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) AND (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only team captain or championship organizer can register team');
        END IF;
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team is already registered in this championship');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NULL THEN v_joined_count := 0; END IF;

    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is already full');
    END IF;

    -- 🔒 تحديد حالة السداد: لا يمكن تسجيل الفريق كـ paid إلا إذا كانت البطولة مجانية فعلياً (entry_fee = 0)
    -- أو تم الاستدعاء عبر service_role (الويب هوك) أو منظم البطولة / الأدمن
    IF (COALESCE(auth.role(), '') = 'service_role') THEN
        v_is_paid_result := true;
    ELSIF v_champ.owner_id = auth.uid() OR COALESCE(v_caller_role, '') IN ('admin', 'co_founder') THEN
        v_is_paid_result := true;
    ELSIF COALESCE(v_champ.entry_fee, 0) = 0 THEN
        v_is_paid_result := true;
    ELSE
        -- للبطولات المدفوعة من لاعب عادي: لا يمكن تعيين paid=true مباشرة
        v_is_paid_result := false;
    END IF;

    -- إضافة الفريق لقائمة الفرق المنضمة
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), p_team_id),
        paid_teams = CASE 
            WHEN v_is_paid_result 
            THEN array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), p_team_id)
            ELSE COALESCE(paid_teams, ARRAY[]::UUID[])
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Team registered successfully in championship',
        'is_paid', v_is_paid_result,
        'joined_teams_count', v_joined_count + 1
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
  v_current_players int;
  v_total_field_capacity int;
  v_joined_ids text[];
  v_start_time timestamptz;
  v_end_time timestamptz;
BEGIN
  -- 1. قفل السطر جغرافياً وزمنياً لضمان معالجة طلب واحد فقط في الجزء من الثانية
  SELECT current_players, total_field_capacity, joined_user_ids, start_time, end_time
  INTO v_current_players, v_total_field_capacity, v_joined_ids, v_start_time, v_end_time
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  -- أمان: التحقق من وجود المباراة
  IF NOT FOUND THEN
    RAISE EXCEPTION 'match_not_found';
  END IF;

  -- أمان: منع اللاعب من الانضمام مرتين لنفس الماتش
  IF p_user_id = ANY(v_joined_ids) THEN
    RAISE EXCEPTION 'already_joined';
  END IF;

  -- أمان: منع الانضمام إذا كانت المباراة مكتملة المقاعد
  IF v_current_players >= v_total_field_capacity THEN
    RAISE EXCEPTION 'match_is_full';
  END IF;

  -- 🛡️ التحصين الأمني الأقوى: منع اللاعب من التواجد في مباراتين متداخلتين زمنياً
  IF EXISTS (
    SELECT 1 
    FROM public.bookings
    WHERE id != p_booking_id
      AND status = 'confirmed'
      AND (created_by_user_id = p_user_id OR p_user_id = ANY(joined_user_ids))
      AND start_time < v_end_time 
      AND end_time > v_start_time
  ) THEN
    RAISE EXCEPTION 'time_conflict';
  END IF;

  -- 2. إتمام العملية وتحديث السجلات إذا تخطى اللاعب كل الفحوصات بنجاح
  UPDATE public.bookings
  SET 
    joined_user_ids = array_append(joined_user_ids, p_user_id),
    current_players = current_players + 1,
    updated_at = now()
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$
;

-- Function: leave_championship_atomic
CREATE OR REPLACE FUNCTION public.leave_championship_atomic(p_championship_id uuid, p_team_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_caller_role TEXT;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    -- 🔒 التحقق من الصلاحية: كابتن الفريق أو منظم البطولة أو الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_team.captain_id IS DISTINCT FROM auth.uid()) AND (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only team captain or championship organizer can remove team');
            END IF;
        END IF;
    END IF;

    UPDATE public.championships
    SET joined_teams = array_remove(joined_teams, p_team_id),
        paid_teams = array_remove(paid_teams, p_team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'team_id', p_team_id);
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
  v_booking bookings%ROWTYPE;
BEGIN
  -- قفل السجل ذرياً لمنع الـ Race Conditions
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF NOT (p_user_id = ANY(v_booking.joined_user_ids)) THEN
    RAISE EXCEPTION 'User is not a joined participant in this match';
  END IF;

  UPDATE bookings
  SET 
    current_players = GREATEST(0, current_players - 1),
    joined_user_ids = array_remove(joined_user_ids, p_user_id),
    updated_at = timezone('utc'::text, now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$
;

-- Function: lock_sensitive_user_fields
CREATE OR REPLACE FUNCTION public.lock_sensitive_user_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ BEGIN RETURN NEW; END; $function$
;

-- Function: log_booking_payment_transaction
CREATE OR REPLACE FUNCTION public.log_booking_payment_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_type text;
BEGIN
  IF NEW.status = 'confirmed' AND (NEW.is_paid = TRUE OR NEW.payment_status = 'paid') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.transactions WHERE booking_id = NEW.id
    ) THEN
      IF NEW.payment_method = 'cash' OR NEW.payment_transaction_id LIKE 'MANUAL_%' THEN
        v_type := 'cash';
      ELSE
        v_type := 'digital';
      END IF;

      INSERT INTO public.transactions (booking_id, amount, created_at, type, user_id)
      VALUES (NEW.id, NEW.total_price, NOW(), v_type, NEW.user_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$function$
;

-- Function: mark_chat_messages_as_read
CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(p_conversation_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_unread jsonb;
BEGIN
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

-- Function: owner_create_manual_booking_atomic
CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_total_price numeric DEFAULT 0.0, p_collected_amount numeric DEFAULT 0.0, p_current_players integer DEFAULT 10)
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
    v_payment_status TEXT;
    v_is_paid BOOLEAN;
BEGIN
    -- التحقق من صلاحية الملعب والمالك
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
    END IF;

    IF v_stadium.owner_id != p_owner_id AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to stadium');
    END IF;

    -- قفل الملعب لمنع أي تضارب متزامن (Race Condition)
    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    -- فحص التضارب الزمني مع أي حجز نشط آخر
    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Slot already booked or overlaps with an active match');
    END IF;

    -- تحديد حالة الدفع
    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_collected_amount > 0 THEN 'partially_paid'
        ELSE 'pending'
    END;

    -- إدراج الحجز اليدوي
    INSERT INTO public.bookings (
        stadium_id,
        owner_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
        player_phone,
        notes,
        total_price,
        deposit_paid,
        is_deposit_paid,
        is_paid,
        payment_status,
        payment_method,
        payment_transaction_id,
        status,
        current_players,
        is_private,
        rent_ball,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        p_owner_id,
        p_owner_id,
        p_start_time,
        p_end_time,
        'personal',
        COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي'),
        NULLIF(TRIM(p_customer_phone), ''),
        NULLIF(TRIM(p_notes), ''),
        p_total_price,
        p_collected_amount,
        (p_collected_amount > 0),
        v_is_paid,
        v_payment_status,
        'cash',
        'MANUAL_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
        'confirmed',
        p_current_players,
        true,
        false,
        v_now,
        v_now
    )
    RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Manual booking created successfully'
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
BEGIN
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
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
        payment_transaction_id,
        status,
        current_players,
        is_private,
        rent_ball,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        p_owner_id,
        p_owner_id,
        p_start_time,
        p_end_time,
        'personal',
        COALESCE(NULLIF(TRIM(p_reason), ''), 'مغلق للصيانة'),
        'قفل مخصص من إدارة الملعب',
        0.0,
        0.0,
        false,
        true,
        'paid',
        'cash',
        'LOCK_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
        'confirmed',
        0,
        true,
        false,
        v_now,
        v_now
    )
    RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Slot locked successfully'
    );
END;
$function$
;

-- Function: pay_rehabilitation_fine
CREATE OR REPLACE FUNCTION public.pay_rehabilitation_fine(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
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

-- Function: prepare_tournament_bracket
CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket(p_championship_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
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
DECLARE
    v_champ RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    -- مسح أي مباريات سابقة للبطولة
    DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;

    -- تحديث حالة البطولة إلى ongoing
    UPDATE public.championships
    SET 
        status = 'ongoing',
        champion_team_id = NULL,
        champion_team_name = NULL,
        updated_at = v_now
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true,
        'championship_id', p_championship_id,
        'message', 'Tournament bracket prepared successfully'
    );
END;
$function$
;

-- Function: prevent_late_cancellation
CREATE OR REPLACE FUNCTION public.prevent_late_cancellation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        -- استثناء الحجوزات المعلقة (غير المؤكدة بعد)
        IF OLD.status = 'pending' THEN
            RETURN NEW;
        END IF;

        -- استثناء إذا كان الإلغاء بواسطة النظام أو بسبب تسجيل غياب من المالك
        IF NEW.is_verified_by_owner = false OR NEW.absent_team_id IS NOT NULL OR (NEW.notes ILIKE '%[SYSTEM:%') THEN
            RETURN NEW;
        END IF;

        -- منع الإلغاء إذا تبقى أقل من ساعتين على موعد المباراة المؤكدة
        IF NOW() > OLD.start_time - INTERVAL '2 hours' THEN
            RAISE EXCEPTION 'cannot_cancel_within_2_hours';
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

  -- Idempotency check: ignore duplicate webhooks
  IF p_txn_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.bookings
      WHERE paymob_txn_id = p_txn_id
        AND status = 'confirmed'
    ) INTO v_already_processed;

    IF v_already_processed THEN
      RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'duplicate_webhook_ignored',
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
    -- Flag internal payment call for triggers
    PERFORM set_config('vsp.internal_payment_call', 'true', true);

    UPDATE public.bookings
    SET
      status = 'confirmed',
      is_paid = TRUE,
      payment_status = 'paid',
      is_deposit_paid = TRUE,
      payment_transaction_id = 'PAYMOB_' || p_txn_id,
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_processed_at = NOW(),
      webhook_verified = TRUE,
      updated_at = NOW()
    WHERE id::text = v_clean_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'status', 'confirmed',
      'booking_id', v_clean_id
    );
  ELSE
    UPDATE public.bookings
    SET
      status = 'cancelled',
      payment_status = 'failed',
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
AS $function$
DECLARE
    is_admin BOOLEAN := FALSE;
BEGIN
    SELECT (role = ANY (ARRAY['admin'::text, 'co_founder'::text]))
    INTO is_admin
    FROM public.users
    WHERE id = auth.uid();

    -- إذا لم يكن مسؤولاً، وتغيرت حالة الدفع أو السعر بشكل مباشر غير مصرح به
    IF NOT COALESCE(is_admin, FALSE) THEN
        -- منع اللاعب من تأكيد الدفع بنفسه دون المرور بـ Webhook أو دالة دفع
        IF (NEW.is_paid IS TRUE AND OLD.is_paid IS FALSE) AND (NEW.payment_method = 'paymob') AND (OLD.payment_status = 'pending') THEN
            -- السماح فقط إذا كانت العملية من السيرفر (auth.uid() is null في background webhooks)
            IF auth.uid() IS NOT NULL AND auth.uid() = OLD.created_by_user_id THEN
                RAISE EXCEPTION 'Access Denied: Payment confirmation must be verified by the payment gateway webhook.';
            END IF;
        END IF;

        -- منع تقليل السعر الإجمالي للحجز
        IF NEW.total_price < OLD.total_price AND (OLD.payment_transaction_id NOT LIKE 'MANUAL%') THEN
            RAISE EXCEPTION 'Access Denied: You cannot reduce the booking total price.';
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
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع التلاعب المباشر بحالة الدفع من العميل
  IF NEW.is_paid IS DISTINCT FROM OLD.is_paid AND NEW.is_paid = true AND OLD.is_paid = false THEN
    RAISE EXCEPTION 'Security Alert: Direct payment state manipulation is prohibited.';
  END IF;

  IF NEW.payment_status IS DISTINCT FROM OLD.payment_status AND NEW.payment_status = 'paid' AND OLD.payment_status != 'paid' THEN
    RAISE EXCEPTION 'Security Alert: Setting payment_status to paid directly is prohibited.';
  END IF;

  IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
    RAISE EXCEPTION 'Security Alert: Booking total_price cannot be modified directly.';
  END IF;

  IF NEW.deposit_paid IS DISTINCT FROM OLD.deposit_paid THEN
    RAISE EXCEPTION 'Security Alert: Booking deposit_paid cannot be modified directly.';
  END IF;

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
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved AND NEW.is_approved = true THEN
    RAISE EXCEPTION 'Security Alert: Championship approval requires admin verification.';
  END IF;

  IF NEW.champion_team_id IS DISTINCT FROM OLD.champion_team_id AND NEW.champion_team_id IS NOT NULL THEN
    RAISE EXCEPTION 'Security Alert: Crowning tournament champion must be performed via tournament engine.';
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
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع توثيق أو فك حظر الملعب ذاتياً
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified AND NEW.is_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Stadium verification requires admin approval.';
  END IF;

  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked AND NEW.is_blocked = false THEN
    RAISE EXCEPTION 'Security Alert: Stadium unblocking requires admin approval.';
  END IF;

  -- منع التلاعب بالتقييم أو عدد المراجعات مباشرة من مالك الملعب
  IF NEW.rating IS DISTINCT FROM OLD.rating THEN
    NEW.rating := OLD.rating;
  END IF;

  IF NEW.reviews_count IS DISTINCT FROM OLD.reviews_count THEN
    NEW.reviews_count := OLD.reviews_count;
  END IF;

  IF NEW.is_featured IS DISTINCT FROM OLD.is_featured AND NEW.is_featured = true THEN
    RAISE EXCEPTION 'Security Alert: Featuring a stadium requires admin approval.';
  END IF;

  RETURN NEW;
END;
$function$
;

-- Function: protect_team_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_team_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role TEXT;
BEGIN
  -- السماح للـ Service Role وخادم قاعدة البيانات الداخلي
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  -- استعلام عن رتبة المستدعي
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

  -- السماح الكامل للإدارة والمؤسسين
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع التوثيق أو الحظر الذاتي
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified AND NEW.is_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Team verification requires admin approval.';
  END IF;

  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked AND NEW.is_blocked = false THEN
    RAISE EXCEPTION 'Security Alert: Team unblocking requires admin approval.';
  END IF;

  -- إرجاع الإحصائيات التنافسية لقيمتها الأصلية إن تم محاولة تعديلها مباشرة
  NEW.points := OLD.points;
  NEW.wins := OLD.wins;
  NEW.draws := OLD.draws;
  NEW.losses := OLD.losses;
  NEW.matches_played := OLD.matches_played;
  NEW.current_winning_streak := OLD.current_winning_streak;
  NEW.championships_won := OLD.championships_won;
  NEW.elo_rating := OLD.elo_rating;

  RETURN NEW;
END;
$function$
;

-- Function: protect_user_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ BEGIN RETURN NEW; END; $function$
;

-- Function: protect_user_verification_fields
CREATE OR REPLACE FUNCTION public.protect_user_verification_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ BEGIN RETURN NEW; END; $function$
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
BEGIN
    -- 1. جلب بيانات المباراة وقفلها
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- 🔒 2. التحقق من صلاحية مالك البطولة (owner_id فقط)
    SELECT * INTO v_champ FROM public.championships WHERE id = v_match.championship_id;
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Only championship owner or admin can submit scores');
            END IF;
        END IF;
    END IF;

    -- 3. تحديث نتيجة المباراة الحالية
    UPDATE public.tournament_matches
    SET 
        home_score = p_home_score,
        away_score = p_away_score,
        home_penalties = p_home_penalties,
        away_penalties = p_away_penalties,
        winner_id = p_winner_id,
        status = 'completed',
        is_completed = true,
        goal_details = COALESCE(p_goal_details, '[]'::jsonb),
        updated_at = v_now
    WHERE id = p_match_id;

    -- 4. تصعيد الفائز للمباراة التالية إذا وجدت
    IF v_match.next_match_id IS NOT NULL AND p_winner_id IS NOT NULL THEN
        IF (v_match.match_index % 2 = 0) THEN
            UPDATE public.tournament_matches
            SET home_team_id = p_winner_id,
                home_team_name = p_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        ELSE
            UPDATE public.tournament_matches
            SET away_team_id = p_winner_id,
                away_team_name = p_winner_name,
                updated_at = v_now
            WHERE id = v_match.next_match_id;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'match_id', p_match_id, 'winner_id', p_winner_id);
END;
$function$
;

-- Function: record_matchup_result_atomic
CREATE OR REPLACE FUNCTION public.record_matchup_result_atomic(p_booking_id uuid, p_team_a_id uuid, p_team_b_id uuid, p_outcome text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_team_a_valid BOOLEAN;
    v_team_b_valid BOOLEAN;
    v_new_result_id UUID;
BEGIN
    -- 1. Authentication Check (Fail-Closed)
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Verify Booking Ownership (Hard Requirement #5: Host captain ONLY)
    SELECT id, created_by_user_id, user_id, status, matchup_closed_at INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator (host captain) has permission to record match results';
    END IF;

    IF v_booking.matchup_closed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Matchup is closed: Cannot record new results for this booking';
    END IF;

    -- 3. Verify Outcome Format
    IF p_outcome NOT IN ('team_a_win', 'team_b_win', 'draw') THEN
        RAISE EXCEPTION 'Invalid outcome "%". Allowed: team_a_win, team_b_win, draw', p_outcome;
    END IF;

    IF p_team_a_id = p_team_b_id THEN
        RAISE EXCEPTION 'Cannot record match result between the same team';
    END IF;

    -- 4. Verify Both Teams belong to this Matchup Booking
    SELECT EXISTS (
        SELECT 1 FROM public.matchup_teams WHERE booking_id = p_booking_id AND team_id = p_team_a_id
    ) INTO v_team_a_valid;

    SELECT EXISTS (
        SELECT 1 FROM public.matchup_teams WHERE booking_id = p_booking_id AND team_id = p_team_b_id
    ) INTO v_team_b_valid;

    IF NOT v_team_a_valid OR NOT v_team_b_valid THEN
        RAISE EXCEPTION 'Both participating teams must be registered in this matchup';
    END IF;

    -- 5. Insert Result (Triggers sync_head_to_head_on_result_insert automatically)
    INSERT INTO public.matchup_results (
        booking_id,
        team_a_id,
        team_b_id,
        outcome,
        recorded_by,
        created_at
    )
    VALUES (
        p_booking_id,
        p_team_a_id,
        p_team_b_id,
        p_outcome,
        v_caller_id,
        timezone('utc'::text, now())
    )
    RETURNING id INTO v_new_result_id;

    RETURN jsonb_build_object(
        'success', true,
        'result_id', v_new_result_id,
        'booking_id', p_booking_id,
        'team_a_id', p_team_a_id,
        'team_b_id', p_team_b_id,
        'outcome', p_outcome
    );
END;
$function$
;

-- Function: reject_join_request
CREATE OR REPLACE FUNCTION public.reject_join_request(p_booking_id text, p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids::text[], ARRAY[]::text[]), p_user_id),
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Request rejected.');
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
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
    v_booking_uuid UUID;
    v_user_uuid UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    v_booking_uuid := p_booking_id::UUID;
    v_user_uuid := p_user_id::UUID;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = v_booking_uuid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'match_cancelled';
    END IF;

    SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
    IF v_user_blocked IS TRUE THEN
        RAISE EXCEPTION 'user_blocked';
    END IF;

    v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
    IF v_booking.current_players >= v_capacity THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    IF p_user_id = ANY(COALESCE(v_booking.joined_user_ids::text[], ARRAY[]::text[])) THEN
        RAISE EXCEPTION 'already_joined';
    END IF;

    -- التحقق من تضارب المواعيد مع مباريات اللاعب الأخرى
    SELECT COUNT(*) INTO v_user_conflict
    FROM public.bookings
    WHERE status != 'cancelled'
      AND id != v_booking_uuid
      AND (created_by_user_id = p_user_id OR p_user_id = ANY(COALESCE(joined_user_ids::text[], ARRAY[]::text[])))
      AND start_time < v_booking.end_time
      AND end_time > v_booking.start_time;

    IF v_user_conflict > 0 THEN
        RAISE EXCEPTION 'time_conflict';
    END IF;

    -- تنفيذ الانضمام وتحديث العدد
    UPDATE public.bookings
    SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::text[]), p_user_id),
        current_players = COALESCE(current_players, 0) + 1,
        updated_at = v_now
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'current_players', v_booking.current_players + 1
    );
END;
$function$
;

-- Function: request_owner_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_method text, p_destination text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- التحقق من صلاحيات وهوية المالك
    IF auth.uid() IS NULL OR (auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout amount must be greater than zero');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout destination details are required');
    END IF;

    -- جلب بيانات المالك
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Owner account not found');
    END IF;

    -- التحقق من عدم وجود طلب تسوية قيد المراجعة حالياً لمنع التكرار
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل من قبل الإدارة. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- إدراج طلب التسوية في جدول payout_settlements
    INSERT INTO public.payout_settlements (
        owner_id,
        amount,
        method,
        destination,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_owner_id,
        p_amount,
        COALESCE(p_method, 'instapay'),
        p_destination,
        'pending',
        v_now,
        v_now
    ) RETURNING id INTO v_settlement_id;

    -- تسجيل المعاملة المعلقة في جدول transactions
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout_pending',
        COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', v_owner.full_name,
            'owner_phone', v_owner.phone_number
        ),
        v_now
    );

    -- إرسال إشعار فوري للأدمن
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    )
    SELECT 
        id,
        'طلب تسوية أرباح جديد',
        'طلب المالك ' || COALESCE(v_owner.full_name, 'مالك') || ' تسوية رصيد بقيمة ' || p_amount || ' ج.م عبر ' || p_destination,
        'payout',
        false,
        v_now
    FROM public.users
    WHERE role IN ('admin', 'co_founder');

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'message', 'Payout request submitted successfully'
    );
END;
$function$
;

-- Function: reset_fair_play_score_annually
CREATE OR REPLACE FUNCTION public.reset_fair_play_score_annually()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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

-- Function: sanitize_user_phone
CREATE OR REPLACE FUNCTION public.sanitize_user_phone()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.phone IS NOT NULL AND TRIM(NEW.phone) = '' THEN
    NEW.phone := NULL;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Function: set_user_role_on_signup
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(p_role text, p_user_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_current_role text;
  v_caller_role text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 🔒 قصر الرتب المتاحة على player أو owner فقط
  IF p_role NOT IN ('player', 'owner') THEN
    RAISE EXCEPTION 'Invalid role assignment attempt (%s). Only player or owner allowed.', p_role;
  END IF;

  -- 🔒 منع الـ IDOR: المستخدم يمكنه تغيير رتبة حسابه فقط
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF (v_uid IS DISTINCT FROM auth.uid()) THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
        RAISE EXCEPTION 'Unauthorized: You can only set your own role.';
      END IF;
    END IF;
  END IF;

  SELECT role INTO v_current_role FROM public.users WHERE id = v_uid;

  -- منع المساس برتب الأدمن ومؤسسي المنصة
  IF v_current_role IN ('admin', 'co_founder') THEN
    RETURN true;
  END IF;

  UPDATE public.users
  SET role = p_role, updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  RETURN true;
END;
$function$
;

-- Function: submit_owner_verification
CREATE OR REPLACE FUNCTION public.submit_owner_verification(p_owner_id uuid, p_additional_data jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := COALESCE(p_owner_id, auth.uid());
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
    END IF;

    UPDATE public.users
    SET 
        verification_status = 'pending',
        is_registration_complete = true,
        has_stadium = true,
        additional_data = COALESCE(additional_data, '{}'::jsonb) || p_additional_data,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Owner verification submitted successfully'
    );
END;
$function$
;

-- Function: submit_stadium_review_atomic
CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(p_stadium_id uuid, p_user_id uuid, p_user_name text, p_user_image_url text, p_rating integer, p_comment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- 🔒 التحقق من أن المستخدم يقيّم بحسابه الحقيقي
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You cannot submit reviews on behalf of another user');
        END IF;
    END IF;

    IF p_rating < 1 OR p_rating > 5 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Rating must be between 1 and 5');
    END IF;

    -- إدراج أو تحديث التقييم
    INSERT INTO public.reviews (
        stadium_id,
        user_id,
        user_name,
        user_image_url,
        rating,
        comment,
        created_at
    ) VALUES (
        p_stadium_id,
        p_user_id,
        p_user_name,
        p_user_image_url,
        p_rating,
        p_comment,
        timezone('utc'::text, now())
    )
    ON CONFLICT (stadium_id, user_id) 
    DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        user_name = EXCLUDED.user_name,
        user_image_url = EXCLUDED.user_image_url,
        created_at = timezone('utc'::text, now());

    -- تحديث متوسط تقييم الملعب
    UPDATE public.stadiums
    SET 
        rating = (SELECT ROUND(AVG(rating)::numeric, 1) FROM public.reviews WHERE stadium_id = p_stadium_id),
        reviews_count = (SELECT COUNT(*) FROM public.reviews WHERE stadium_id = p_stadium_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_stadium_id;

    RETURN jsonb_build_object('success', true, 'stadium_id', p_stadium_id, 'rating', p_rating);
END;
$function$
;

-- Function: sync_booking_players_table
CREATE OR REPLACE FUNCTION public.sync_booking_players_table()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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

-- Function: sync_booking_user_ids
CREATE OR REPLACE FUNCTION public.sync_booking_user_ids()
 RETURNS trigger
 LANGUAGE plpgsql
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

  IF v_booking.created_by_user_id <> p_user_id AND v_booking.owner_id <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Only the host or owner can modify spots';
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

-- Function: verify_match_played
CREATE OR REPLACE FUNCTION public.verify_match_played(p_booking_id uuid, p_attended boolean, p_absent_team_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_booking record;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF p_attended THEN
    -- تغيير الحالة سيطلق تلقائياً تريجر trg_match_completed لاحتساب الـ Elo مرة واحدة فقط
    UPDATE public.bookings
    SET 
      is_verified_by_owner = true,
      status = 'completed',
      updated_at = now()
    WHERE id = p_booking_id;
  ELSE
    UPDATE public.bookings
    SET 
      is_verified_by_owner = false,
      absent_team_id = p_absent_team_id,
      status = 'cancelled',
      updated_at = now()
    WHERE id = p_booking_id;

    IF p_absent_team_id IS NOT NULL THEN
      UPDATE public.teams SET fair_play_score = GREATEST(0, fair_play_score - 10) WHERE id::text = p_absent_team_id;
      UPDATE public.users SET no_show_count = no_show_count + 1 WHERE id = (SELECT captain_id FROM public.teams WHERE id::text = p_absent_team_id);
    END IF;
  END IF;

  RETURN true;
END;
$function$
;



-- --------------------------------------------------------------------------
-- 9. TRIGGERS
-- --------------------------------------------------------------------------
DROP TRIGGER IF EXISTS "trg_calculate_elo" ON public."bookings";
CREATE TRIGGER trg_calculate_elo BEFORE UPDATE OF status, final_outcome ON bookings FOR EACH ROW EXECUTE FUNCTION calculate_elo_on_match_completion();

DROP TRIGGER IF EXISTS "trg_match_completed" ON public."bookings";
CREATE TRIGGER trg_match_completed BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION calculate_elo_on_match_completion();

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

DROP TRIGGER IF EXISTS "trg_sync_booking_user_ids" ON public."bookings";
CREATE TRIGGER trg_sync_booking_user_ids BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_user_ids();

DROP TRIGGER IF EXISTS "trg_sync_booking_user_ids" ON public."bookings";
CREATE TRIGGER trg_sync_booking_user_ids BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION sync_booking_user_ids();

DROP TRIGGER IF EXISTS "trigger_enforce_cash_restrictions" ON public."bookings";
CREATE TRIGGER trigger_enforce_cash_restrictions BEFORE INSERT ON bookings FOR EACH ROW EXECUTE FUNCTION enforce_cash_booking_restrictions();

DROP TRIGGER IF EXISTS "trigger_log_booking_payment" ON public."bookings";
CREATE TRIGGER trigger_log_booking_payment AFTER INSERT OR UPDATE OF is_paid, payment_status ON bookings FOR EACH ROW EXECUTE FUNCTION log_booking_payment_transaction();

DROP TRIGGER IF EXISTS "trigger_log_booking_payment" ON public."bookings";
CREATE TRIGGER trigger_log_booking_payment AFTER INSERT OR UPDATE OF is_paid, payment_status ON bookings FOR EACH ROW EXECUTE FUNCTION log_booking_payment_transaction();

DROP TRIGGER IF EXISTS "trg_protect_championship_sensitive_fields" ON public."championships";
CREATE TRIGGER trg_protect_championship_sensitive_fields BEFORE UPDATE ON championships FOR EACH ROW EXECUTE FUNCTION protect_championship_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_enforce_sender_name" ON public."chat_messages";
CREATE TRIGGER trg_enforce_sender_name BEFORE INSERT ON chat_messages FOR EACH ROW EXECUTE FUNCTION enforce_real_sender_name();

DROP TRIGGER IF EXISTS "trg_sync_head_to_head" ON public."matchup_results";
CREATE TRIGGER trg_sync_head_to_head AFTER INSERT ON matchup_results FOR EACH ROW EXECUTE FUNCTION sync_head_to_head_on_result_insert();

DROP TRIGGER IF EXISTS "trg_sync_notification_message_body" ON public."notifications";
CREATE TRIGGER trg_sync_notification_message_body BEFORE INSERT OR UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION sync_notification_message_body();

DROP TRIGGER IF EXISTS "trg_sync_notification_message_body" ON public."notifications";
CREATE TRIGGER trg_sync_notification_message_body BEFORE INSERT OR UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION sync_notification_message_body();

DROP TRIGGER IF EXISTS "trigger_notification_fcm" ON public."notifications";
CREATE TRIGGER trigger_notification_fcm AFTER INSERT ON notifications FOR EACH ROW EXECUTE FUNCTION handle_new_notification_fcm();

DROP TRIGGER IF EXISTS "trigger_stadium_review_changes" ON public."reviews";
CREATE TRIGGER trigger_stadium_review_changes AFTER INSERT OR DELETE OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION handle_stadium_review_changes();

DROP TRIGGER IF EXISTS "trigger_stadium_review_changes" ON public."reviews";
CREATE TRIGGER trigger_stadium_review_changes AFTER INSERT OR DELETE OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION handle_stadium_review_changes();

DROP TRIGGER IF EXISTS "trigger_stadium_review_changes" ON public."reviews";
CREATE TRIGGER trigger_stadium_review_changes AFTER INSERT OR DELETE OR UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION handle_stadium_review_changes();

DROP TRIGGER IF EXISTS "trg_check_owner_stadium_limit" ON public."stadiums";
CREATE TRIGGER trg_check_owner_stadium_limit BEFORE INSERT ON stadiums FOR EACH ROW EXECUTE FUNCTION check_owner_stadium_limit();

DROP TRIGGER IF EXISTS "trg_protect_stadium_sensitive_fields" ON public."stadiums";
CREATE TRIGGER trg_protect_stadium_sensitive_fields BEFORE UPDATE ON stadiums FOR EACH ROW EXECUTE FUNCTION protect_stadium_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium AFTER INSERT OR DELETE OR UPDATE OF is_deleted_by_owner, owner_id ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium AFTER INSERT OR DELETE OR UPDATE OF is_deleted_by_owner, owner_id ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium AFTER INSERT OR DELETE OR UPDATE OF is_deleted_by_owner, owner_id ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium();

DROP TRIGGER IF EXISTS "trg_sync_owner_has_stadium_soft_delete" ON public."stadiums";
CREATE TRIGGER trg_sync_owner_has_stadium_soft_delete AFTER UPDATE OF is_deleted_by_owner ON stadiums FOR EACH ROW EXECUTE FUNCTION sync_owner_has_stadium_on_soft_delete();

DROP TRIGGER IF EXISTS "trigger_stadium_breaks_collision" ON public."stadiums";
CREATE TRIGGER trigger_stadium_breaks_collision AFTER UPDATE OF features ON stadiums FOR EACH ROW EXECUTE FUNCTION handle_stadium_breaks_collision();

DROP TRIGGER IF EXISTS "trg_check_team_and_member_limits" ON public."team_members";
CREATE TRIGGER trg_check_team_and_member_limits BEFORE INSERT ON team_members FOR EACH ROW EXECUTE FUNCTION check_team_and_member_limits();

DROP TRIGGER IF EXISTS "trg_protect_teams_sensitive_fields" ON public."teams";
CREATE TRIGGER trg_protect_teams_sensitive_fields BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION protect_team_sensitive_fields();

DROP TRIGGER IF EXISTS "trg_reset_fair_play_score" ON public."teams";
CREATE TRIGGER trg_reset_fair_play_score BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION reset_fair_play_score_annually();

DROP TRIGGER IF EXISTS "trg_protect_completed_match_scores" ON public."tournament_matches";
CREATE TRIGGER trg_protect_completed_match_scores BEFORE UPDATE ON tournament_matches FOR EACH ROW EXECUTE FUNCTION protect_completed_match_scores();

DROP TRIGGER IF EXISTS "trg_check_1v1_registration_capacity" ON public."vsp_1v1_registrations";
CREATE TRIGGER trg_check_1v1_registration_capacity BEFORE INSERT ON vsp_1v1_registrations FOR EACH ROW EXECUTE FUNCTION check_1v1_registration_capacity();


