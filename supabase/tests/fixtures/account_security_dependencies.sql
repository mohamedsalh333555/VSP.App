-- TEST ONLY: account-security dependency snapshot, observed staging 2026-11-11.
-- NOT a full Supabase schema, migration replay or production installer.
-- 25 tables / 518 column definitions. Only the users Auth cascade and ID keys
-- needed by these contracts are included; unrelated FKs/triggers are omitted.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth, public TO anon, authenticated, service_role;
CREATE OR REPLACE FUNCTION auth.uid()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$;

CREATE OR REPLACE FUNCTION auth.role()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$function$;

CREATE OR REPLACE FUNCTION auth.jwt()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$;

CREATE TABLE auth.users (
  "instance_id" uuid,
  "id" uuid NOT NULL,
  "aud" character varying(255),
  "role" character varying(255),
  "email" character varying(255),
  "encrypted_password" character varying(255),
  "email_confirmed_at" timestamp with time zone,
  "invited_at" timestamp with time zone,
  "confirmation_token" character varying(255),
  "confirmation_sent_at" timestamp with time zone,
  "recovery_token" character varying(255),
  "recovery_sent_at" timestamp with time zone,
  "email_change_token_new" character varying(255),
  "email_change" character varying(255),
  "email_change_sent_at" timestamp with time zone,
  "last_sign_in_at" timestamp with time zone,
  "raw_app_meta_data" jsonb,
  "raw_user_meta_data" jsonb,
  "is_super_admin" boolean,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "phone" text DEFAULT NULL::character varying,
  "phone_confirmed_at" timestamp with time zone,
  "phone_change" text DEFAULT ''::character varying,
  "phone_change_token" character varying(255) DEFAULT ''::character varying,
  "phone_change_sent_at" timestamp with time zone,
  "confirmed_at" timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
  "email_change_token_current" character varying(255) DEFAULT ''::character varying,
  "email_change_confirm_status" smallint DEFAULT 0,
  "banned_until" timestamp with time zone,
  "reauthentication_token" character varying(255) DEFAULT ''::character varying,
  "reauthentication_sent_at" timestamp with time zone,
  "is_sso_user" boolean DEFAULT false NOT NULL,
  "deleted_at" timestamp with time zone,
  "is_anonymous" boolean DEFAULT false NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public.booking_players (
  "booking_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "joined_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.bookings (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "stadium_id" uuid,
  "stadium_name" text,
  "stadium_image_url" text,
  "owner_id" uuid,
  "created_by_user_id" uuid,
  "start_time" timestamp with time zone NOT NULL,
  "end_time" timestamp with time zone NOT NULL,
  "booking_type" text,
  "player_team_id" uuid,
  "player_team_name" text,
  "player_team_logo_url" text,
  "host_name" text,
  "host_avatar_url" text,
  "opponent_team_id" uuid,
  "opponent_team_name" text,
  "opponent_team_logo_url" text,
  "is_private" boolean DEFAULT true,
  "rent_ball" boolean DEFAULT false,
  "total_price" numeric NOT NULL,
  "currency" text DEFAULT 'EGP'::text,
  "payment_method" text DEFAULT 'cash'::text,
  "payment_transaction_id" text,
  "status" text DEFAULT 'confirmed'::text NOT NULL,
  "is_paid" boolean DEFAULT false,
  "payment_status" text DEFAULT 'pending'::text,
  "player_phone" text,
  "notes" text,
  "home_score" integer,
  "away_score" integer,
  "result_submitted_by_team_id" uuid,
  "match_result_status" text DEFAULT 'noResult'::text,
  "pending_outcome" text,
  "final_outcome" text,
  "requires_admin_intervention" boolean DEFAULT false,
  "current_players" integer DEFAULT 1,
  "max_players" integer DEFAULT 10,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "deposit_receipt_url" text,
  "receipt_url" text,
  "elo_processed" boolean DEFAULT false,
  "deposit_paid" numeric DEFAULT 0.0,
  "is_deposit_paid" boolean DEFAULT false,
  "joined_user_ids" uuid[] DEFAULT '{}'::uuid[],
  "paymob_order_id" text,
  "paymob_transaction_id" text,
  "payment_gateway_logs" jsonb DEFAULT '{}'::jsonb,
  "is_verified_by_owner" boolean,
  "absent_team_id" text,
  "is_dispute_approved" boolean,
  "dispute_photo_url" text,
  "payment_hold_released" boolean DEFAULT false,
  "result_submitted_at" timestamp with time zone,
  "pending_user_ids" text[] DEFAULT '{}'::text[],
  "user_id" uuid,
  "platform_fee" numeric DEFAULT 0.0,
  "is_official_match" boolean DEFAULT true,
  "operational_date" date,
  "unread_counts" jsonb DEFAULT '{}'::jsonb,
  "last_message" text,
  "last_message_time" timestamp with time zone,
  "deleted_for_users" text[] DEFAULT '{}'::text[],
  "cancelled_at" timestamp with time zone,
  "refund_amount" numeric,
  "payment_reference" text,
  "initial_players_count" integer DEFAULT 1,
  "total_field_capacity" integer DEFAULT 10,
  "challenge_status" text,
  "paymob_txn_id" text,
  "webhook_processed_at" timestamp with time zone,
  "webhook_verified" boolean DEFAULT false,
  "deposit_amount" numeric DEFAULT 0,
  "needs_deposit" boolean DEFAULT false,
  "reschedule_status" text DEFAULT 'none'::text,
  "proposed_start_time" timestamp with time zone,
  "proposed_end_time" timestamp with time zone,
  "emergency_cancel_status" text DEFAULT 'none'::text,
  "emergency_reason" text,
  "emergency_downtime_hours" integer,
  "cancellation_reason" text,
  "locked_until" timestamp with time zone,
  "matchup_mode" text,
  "matchup_closed_at" timestamp with time zone,
  "refund_transaction_id" text,
  "refunded_at" timestamp with time zone,
  "refund_payment_method" text,
  "vsp_commission" numeric DEFAULT 0.00 NOT NULL,
  "gateway_fee" numeric DEFAULT 0.00 NOT NULL,
  "qr_hash" text,
  "qr_expires_at" timestamp with time zone,
  "qr_scanned_at" timestamp with time zone,
  "payment_reconcile_state" text DEFAULT 'unpaid'::text NOT NULL,
  "payment_source" text DEFAULT 'pending'::text NOT NULL,
  "idempotency_key" text,
  "gross_amount_charged" numeric,
  "manual_player_count" integer DEFAULT 0 NOT NULL,
  "collective_invite_token" text,
  "collective_invite_code" text,
  "collective_invite_active" boolean DEFAULT true NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public.championship_registrations (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "championship_id" uuid NOT NULL,
  "team_id" uuid NOT NULL,
  "captain_id" uuid,
  "captain_snapshot" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "registration_status" text DEFAULT 'pending'::text NOT NULL,
  "payment_status" text DEFAULT 'pending'::text NOT NULL,
  "base_amount" numeric DEFAULT 0.00 NOT NULL,
  "gross_amount" numeric DEFAULT 0.00 NOT NULL,
  "currency" text DEFAULT 'EGP'::text NOT NULL,
  "notes" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public.championships (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "name" text NOT NULL,
  "type" text NOT NULL,
  "sport_type" text DEFAULT 'Football'::text,
  "logo_url" text,
  "start_date" timestamp with time zone NOT NULL,
  "end_date" timestamp with time zone NOT NULL,
  "entry_fee" numeric NOT NULL,
  "grand_prize" numeric NOT NULL,
  "max_teams" integer DEFAULT 16,
  "owner_id" uuid NOT NULL,
  "governorate" text NOT NULL,
  "rules" text,
  "payment_methods" text[] DEFAULT '{cash}'::text[],
  "max_players_per_team" integer DEFAULT 11,
  "min_players_per_team" integer DEFAULT 5,
  "winning_points" integer DEFAULT 3,
  "draw_points" integer DEFAULT 1,
  "loss_points" integer DEFAULT 0,
  "match_duration" integer DEFAULT 30,
  "is_back_and_forth" boolean DEFAULT false,
  "trophy_medals" boolean DEFAULT true,
  "red_card_suspension" boolean DEFAULT true,
  "fair_play_scoring" boolean DEFAULT false,
  "status" text DEFAULT 'open'::text,
  "champion_team_id" uuid,
  "champion_team_name" text,
  "paid_teams" text[] DEFAULT '{}'::uuid[],
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "joined_teams" text[] DEFAULT '{}'::text[],
  "is_approved" boolean DEFAULT false,
  "winner_team_id" uuid,
  "winner_team_name" text,
  "number_of_groups" integer DEFAULT 1,
  "qualifying_per_group" integer DEFAULT 2,
  "is_two_legs" boolean DEFAULT false,
  "creation_payment_id" text,
  "creation_fee_paid" boolean DEFAULT false,
  "champion_user_id" uuid,
  "settings" jsonb DEFAULT '{}'::jsonb,
  "prize_pool" numeric DEFAULT 0.00 NOT NULL,
  "prize_delivered" boolean DEFAULT false NOT NULL,
  "prize_delivered_at" timestamp with time zone,
  "prize_delivered_by" uuid,
  "prize_delivery_notes" text,
  "template_type" text,
  "registration_locked_at" timestamp with time zone,
  "match_interval_days" integer DEFAULT 7,
  "paid_by_creator_count" integer DEFAULT 1,
  "stadium_id" uuid,
  "registration_closes_at" timestamp with time zone,
  "currency" text DEFAULT 'EGP'::text NOT NULL,
  "rejection_reason" text,
  "rejected_at" timestamp with time zone,
  "rejected_by" uuid,
  "owner_approval_home_seen_at" timestamp with time zone,
  PRIMARY KEY (id)
);
CREATE TABLE public.chat_messages (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "booking_id" uuid,
  "sender_id" uuid NOT NULL,
  "sender_name" text NOT NULL,
  "text" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "is_read" boolean DEFAULT false,
  "is_edited" boolean DEFAULT false,
  "deleted_for_users" uuid[] DEFAULT '{}'::uuid[],
  "conversation_id" uuid,
  PRIMARY KEY (id)
);
CREATE TABLE public.notifications (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "title" text NOT NULL,
  "body" text NOT NULL,
  "type" text NOT NULL,
  "is_read" boolean DEFAULT false NOT NULL,
  "booking_id" uuid,
  "metadata" jsonb,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "message" text,
  PRIMARY KEY (id)
);
CREATE TABLE public.owner_subscription_orders (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "owner_id" uuid,
  "checkout_email" text,
  "status" text DEFAULT 'pending'::text,
  "plan_code" text,
  "billing_period" text,
  "amount" numeric,
  "vsp_fee_amount" numeric,
  "paymob_fee_amount" numeric,
  "gross_amount" numeric,
  "paid_at" timestamp with time zone,
  "payment_source" text DEFAULT 'app'::text,
  "paymob_order_id" text,
  "paymob_transaction_id" text,
  "created_at" timestamp with time zone DEFAULT now(),
  "checkout_phone" text,
  "paymob_intention_id" text,
  "claim_expires_at" timestamp with time zone,
  "checkout_name" text,
  "duration_days" integer,
  PRIMARY KEY (id)
);
CREATE TABLE public.owner_trial_ledger (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "email" text NOT NULL,
  "phone" text,
  "user_id" uuid,
  "first_trial_started_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "original_trial_ends_at" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public.reports (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "reporter_id" uuid,
  "target_id" text NOT NULL,
  "target_type" text NOT NULL,
  "reason" text NOT NULL,
  "details" text,
  "status" text DEFAULT 'pending'::text,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "context_type" text,
  "context_id" uuid,
  "booking_id" uuid,
  "conversation_id" uuid,
  PRIMARY KEY (id)
);
CREATE TABLE public.reviews (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "stadium_id" uuid NOT NULL,
  "user_id" uuid,
  "rating" integer,
  "review_text" text,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "user_name" text,
  "user_image_url" text,
  PRIMARY KEY (id)
);
CREATE TABLE public.stadiums (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "owner_id" uuid NOT NULL,
  "name" text NOT NULL,
  "location" text NOT NULL,
  "governorate" text NOT NULL,
  "price_per_hour" numeric NOT NULL,
  "base_price" numeric NOT NULL,
  "seats_capacity" integer DEFAULT 0,
  "image_url" text,
  "images" text[] DEFAULT '{}'::text[],
  "rating" numeric DEFAULT 4.5,
  "reviews_count" integer DEFAULT 0,
  "notes" text,
  "is_verified" boolean DEFAULT true,
  "is_featured" boolean DEFAULT false,
  "is_blocked" boolean DEFAULT false,
  "opening_time" time without time zone DEFAULT '08:00:00'::time without time zone,
  "closing_time" time without time zone DEFAULT '00:00:00'::time without time zone,
  "is_split_shift" boolean DEFAULT false,
  "break_start_time" time without time zone,
  "break_end_time" time without time zone,
  "lat" numeric,
  "lng" numeric,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "needs_deposit" boolean DEFAULT false,
  "deposit_amount" numeric DEFAULT 0.0,
  "city" text,
  "description" text,
  "features" jsonb DEFAULT '{}'::jsonb,
  "players_per_team" integer DEFAULT 5,
  "total_field_capacity" integer DEFAULT 10,
  "is_deleted_by_owner" boolean DEFAULT false,
  "maintenance_until" timestamp with time zone,
  "maintenance_reason" text,
  "last_emergency_closure_at" timestamp with time zone,
  PRIMARY KEY (id)
);
CREATE TABLE public.system_audit_logs (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "table_name" text NOT NULL,
  "record_id" uuid NOT NULL,
  "action" text NOT NULL,
  "changed_by" uuid DEFAULT auth.uid(),
  "changed_by_role" text,
  "old_data" jsonb,
  "new_data" jsonb,
  "changed_fields" text[],
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public.team_league_cancellation_refund_queue (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "championship_id" uuid NOT NULL,
  "payment_id" uuid NOT NULL,
  "user_id" uuid,
  "paymob_transaction_id" text,
  "amount" numeric NOT NULL,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "retry_count" integer DEFAULT 0 NOT NULL,
  "error_message" text,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "currency" text DEFAULT 'EGP'::text,
  "failure_reason" text,
  "processed_at" timestamp with time zone,
  "processing_started_at" timestamp with time zone,
  "locked_until" timestamp with time zone,
  PRIMARY KEY (id)
);
CREATE TABLE public.team_league_payments (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "championship_id" uuid NOT NULL,
  "team_id" uuid NOT NULL,
  "user_id" uuid,
  "amount" numeric DEFAULT 30 NOT NULL,
  "payment_status" text DEFAULT 'pending'::text NOT NULL,
  "order_reference" text NOT NULL,
  "paymob_transaction_id" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "paid_at" timestamp with time zone,
  "paid_teams_count" integer DEFAULT 1,
  "gross_amount" numeric,
  "paymob_order_id" text,
  PRIMARY KEY (id)
);
CREATE TABLE public.team_members (
  "team_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "joined_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.teams (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "name" text NOT NULL,
  "captain_id" uuid NOT NULL,
  "captain_phone" text,
  "active_invite_code" text,
  "invite_code_expires_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "logo_url" text,
  "points" integer DEFAULT 0,
  "wins" integer DEFAULT 0,
  "draws" integer DEFAULT 0,
  "losses" integer DEFAULT 0,
  "matches_played" integer DEFAULT 0,
  "current_winning_streak" integer DEFAULT 0,
  "championships_won" integer DEFAULT 0,
  "last_reset_year" integer DEFAULT 2026,
  "primary_color" text DEFAULT '#FFFFFF'::text,
  "secondary_color" text DEFAULT '#000000'::text,
  "captain_image_url" text DEFAULT ''::text,
  "beaten_opponents" text[] DEFAULT '{}'::text[],
  "played_opponents" text[] DEFAULT '{}'::text[],
  "unlocked_badges" text[] DEFAULT '{explorer}'::text[],
  "governorate" text DEFAULT 'Cairo'::text,
  "sport_type" text DEFAULT 'Football'::text,
  "price_per_person" double precision DEFAULT 50.0,
  "date" text DEFAULT 'Upcoming'::text,
  "stadium" text DEFAULT 'TBD'::text,
  "captain_name" text DEFAULT 'Captain'::text,
  "is_official" boolean DEFAULT false,
  "attendance_score" numeric DEFAULT 100.0,
  "verified_badge" boolean DEFAULT true,
  "has_1v1_champion" boolean DEFAULT false,
  "bio" text,
  PRIMARY KEY (id)
);
CREATE TABLE public.tournament_orders (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "order_reference" text NOT NULL,
  "championship_id" uuid NOT NULL,
  "team_id" uuid NOT NULL,
  "captain_user_id" uuid,
  "amount" numeric NOT NULL,
  "payment_status" text DEFAULT 'pending'::text NOT NULL,
  "player_ids" uuid[] DEFAULT ARRAY[]::uuid[],
  "guest_names" text[] DEFAULT ARRAY[]::text[],
  "paymob_transaction_id" text,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "registration_id" uuid,
  "idempotency_key" text,
  "base_amount" numeric,
  "platform_fee_amount" numeric DEFAULT 0.00,
  "gateway_fee_amount" numeric DEFAULT 0.00,
  "gross_amount" numeric,
  "currency" text DEFAULT 'EGP'::text,
  "fee_policy_version" text,
  "paymob_order_id" text,
  PRIMARY KEY (id)
);
CREATE TABLE public.user_blocks (
  "blocker_id" uuid NOT NULL,
  "blocked_user_id" uuid NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.user_device_tokens (
  "token" text NOT NULL,
  "user_id" uuid NOT NULL,
  "platform" text DEFAULT 'android'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.users (
  "id" uuid NOT NULL,
  "role" text DEFAULT 'player'::text,
  "is_blocked" boolean DEFAULT false,
  "email" text,
  "name" text,
  "phone" text,
  "profile_image_url" text,
  "position" text,
  "governorate" text,
  "is_registration_complete" boolean DEFAULT false,
  "is_email_verified" boolean DEFAULT false,
  "has_stadium" boolean DEFAULT false,
  "is_identity_verified" boolean DEFAULT false,
  "favorite_stadiums" uuid[] DEFAULT '{}'::uuid[],
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "verification_status" text DEFAULT 'pending'::text,
  "last_warning" text,
  "date_of_birth" text,
  "p2p_instapay" text,
  "p2p_vodafone" text,
  "p2p_bank" text,
  "additional_data" jsonb DEFAULT '{}'::jsonb,
  "cash_booking_banned" boolean DEFAULT false,
  "completed_online_bookings_count" integer DEFAULT 0,
  "no_show_count" integer DEFAULT 0,
  "subscription_plan" text DEFAULT 'free_trial'::text,
  "trial_ends_at" timestamp with time zone DEFAULT (timezone('utc'::text, now()) + '365 days'::interval),
  "subscription_expires_at" timestamp with time zone,
  "total_platform_fees" numeric DEFAULT 0,
  "fcm_token" text,
  "last_seen" timestamp with time zone DEFAULT now(),
  "terms_accepted_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "is_onboarding_confirmed" boolean DEFAULT false,
  "accumulated_cash_debt" numeric DEFAULT 0.00,
  "debt_limit" numeric DEFAULT 500.00,
  "is_debt_blocked" boolean DEFAULT false,
  PRIMARY KEY (id)
);
CREATE TABLE public.vsp_1v1_cancellation_refund_queue (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "order_id" uuid NOT NULL,
  "user_id" uuid,
  "paymob_transaction_id" text,
  "amount" numeric NOT NULL,
  "currency" text DEFAULT 'EGP'::text NOT NULL,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "retry_count" integer DEFAULT 0 NOT NULL,
  "failure_reason" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  "processing_started_at" timestamp with time zone,
  "locked_until" timestamp with time zone,
  PRIMARY KEY (id)
);
CREATE TABLE public.vsp_1v1_tournament_orders (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "user_id" uuid,
  "amount" numeric NOT NULL,
  "order_reference" text NOT NULL,
  "payment_status" text DEFAULT 'pending'::text NOT NULL,
  "paymob_transaction_id" text,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "refund_retry_count" integer DEFAULT 0,
  "refund_last_attempt_at" timestamp with time zone,
  "refund_next_retry_at" timestamp with time zone,
  "expires_at" timestamp with time zone DEFAULT (timezone('utc'::text, now()) + '00:30:00'::interval),
  "gross_amount" numeric,
  "paymob_order_id" text,
  PRIMARY KEY (id)
);
CREATE TABLE public.vsp_1v1_tournaments (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "name" text NOT NULL,
  "target_player_count" integer NOT NULL,
  "status" text DEFAULT 'draft'::text NOT NULL,
  "created_by" uuid,
  "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  "published_at" timestamp with time zone,
  "scheduled_at" timestamp with time zone,
  "champion_user_id" uuid,
  "entry_fee" numeric DEFAULT 0 NOT NULL,
  "prize_pool" numeric DEFAULT 0 NOT NULL,
  "prize_delivered" boolean DEFAULT false NOT NULL,
  "prize_delivered_at" timestamp with time zone,
  "prize_delivered_by" uuid,
  "prize_delivery_notes" text,
  "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
  "governorate" text DEFAULT 'Cairo'::text NOT NULL,
  "prize_delivery_details" text,
  "prize_delivery_scheduled_at" timestamp with time zone,
  "prize_amount" numeric DEFAULT 0 NOT NULL,
  "champion_player_id" uuid,
  PRIMARY KEY (id)
);
ALTER TABLE public.users ADD CONSTRAINT test_users_auth_cascade FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE OR REPLACE FUNCTION public.is_admin_or_cofounder(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select exists(select 1 from public.users where id=p_user_id and coalesce(is_blocked,false)=false and role in ('admin','co_founder','cofounder','super_admin')); $function$;

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
$function$;

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
$function$;

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
$function$;

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
$function$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_or_cofounder(uuid), public.set_user_role_on_signup(text,uuid), public.delete_user_permanently(uuid) TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO authenticated;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_admin_manage_all" ON public.users AS PERMISSIVE FOR ALL TO "authenticated" USING (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid))) WITH CHECK (is_admin_or_cofounder(( SELECT ( SELECT auth.uid() AS uid) AS uid)));
CREATE POLICY "users_delete_policy" ON public.users AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = id));
CREATE POLICY "users_insert_policy" ON public.users AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((id = auth.uid()));
CREATE POLICY "users_select_policy" ON public.users AS PERMISSIVE FOR SELECT TO "authenticated" USING (((id = auth.uid()) OR is_admin_or_cofounder(auth.uid())));
CREATE POLICY "users_update_policy" ON public.users AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = id)) WITH CHECK ((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = id));

CREATE TABLE public.conversations (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "type" text DEFAULT 'direct'::text NOT NULL,
  "booking_id" uuid,
  "participant_ids" uuid[] DEFAULT '{}'::uuid[] NOT NULL,
  "title" text,
  "last_message" text,
  "last_message_time" timestamp with time zone DEFAULT now(),
  "unread_counts" jsonb DEFAULT '{}'::jsonb,
  "deleted_for_users" uuid[] DEFAULT '{}'::uuid[],
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "context_type" text,
  "context_id" uuid,
  PRIMARY KEY (id)
);
