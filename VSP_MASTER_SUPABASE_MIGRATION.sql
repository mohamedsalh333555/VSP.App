-- ==============================================================================
-- 🏆 VSP SPORTS PLATFORM — MASTER SUPABASE CONSOLIDATED PRODUCTION MIGRATION
-- ==============================================================================
-- Instructions: Copy all content below, paste into Supabase Dashboard -> SQL Editor, and click RUN.
-- This script is 100% idempotent (safe to run multiple times without breaking existing data).

-- 0. Championships Approval Gate
-- Adds is_approved column so championships only appear to players after admin approves the owner.
-- Existing championships (already created before this fix) are approved by default to avoid disruption.
ALTER TABLE public.championships
ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;

-- Migrate existing championships: mark them approved if the owner is already verified,
-- otherwise keep them hidden (false) until the owner is approved.
UPDATE public.championships c
SET is_approved = TRUE
WHERE EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id::text = c.owner_id::text
  AND u.verification_status = 'approved'
);

-- ==============================================================================
-- 0.5. VSP OWNER SUBSCRIPTION PLANS & PLATFORM FEE
-- ==============================================================================
-- Subscription plans: free_trial (default 3 months) / basic (500 EGP) / pro (1000 EGP)

-- Add subscription columns to users table
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free_trial',
ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS total_platform_fees NUMERIC DEFAULT 0;

-- Add platform_fee column to bookings (2% of total_price for online payments)
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS platform_fee NUMERIC DEFAULT 0;

-- Initialize trial period for all existing owners:
-- Each owner gets a 90-day trial starting from their account creation date.
UPDATE public.users
SET
  trial_ends_at = COALESCE(created_at, NOW()) + INTERVAL '90 days',
  subscription_plan = 'free_trial'
WHERE role = 'owner'
  AND (subscription_plan IS NULL OR subscription_plan = 'free_trial');

-- Convenience view for admin: shows each owner's subscription status
DROP VIEW IF EXISTS public.owner_subscription_status CASCADE;

CREATE OR REPLACE VIEW public.owner_subscription_status AS
SELECT
  u.id,
  u.name,
  u.phone,
  u.verification_status,
  u.subscription_plan,
  u.trial_ends_at,
  u.subscription_expires_at,
  u.total_platform_fees,
  CASE
    WHEN u.subscription_plan IN ('basic', 'pro') AND u.subscription_expires_at > NOW() THEN 'active_paid'
    WHEN u.subscription_plan = 'free_trial' AND u.trial_ends_at > NOW() THEN 'active_trial'
    ELSE 'expired'
  END AS effective_status,
  CASE
    WHEN u.subscription_plan = 'pro' THEN 3
    WHEN u.subscription_plan = 'basic' THEN 1
    WHEN u.subscription_plan = 'free_trial' AND u.trial_ends_at > NOW() THEN 1
    ELSE 0
  END AS max_stadiums_allowed
FROM public.users u
WHERE u.role = 'owner';


-- 1. Add P2P receivables columns to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS p2p_instapay TEXT,
ADD COLUMN IF NOT EXISTS p2p_vodafone TEXT,
ADD COLUMN IF NOT EXISTS p2p_bank TEXT,
ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS no_show_count INT DEFAULT 0;

-- 2. Enforce unique review constraint per user per stadium
ALTER TABLE public.reviews
DROP CONSTRAINT IF EXISTS unique_user_stadium_review;

ALTER TABLE public.reviews
ADD CONSTRAINT unique_user_stadium_review UNIQUE (user_id, stadium_id);

-- 3. Atomic Booking Creation Function (Prevents Double-Booking via Row Locks)
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_stadium_id UUID,
  p_user_id UUID,
  p_owner_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_booking_type TEXT,
  p_total_price NUMERIC,
  p_stadium_name TEXT,
  p_stadium_image_url TEXT,
  p_is_private BOOLEAN DEFAULT TRUE,
  p_rent_ball BOOLEAN DEFAULT FALSE,
  p_needs_deposit BOOLEAN DEFAULT FALSE,
  p_deposit_amount NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'cash',
  p_payment_status TEXT DEFAULT 'unpaid',
  p_player_team_id UUID DEFAULT NULL,
  p_player_team_name TEXT DEFAULT NULL,
  p_opponent_team_id UUID DEFAULT NULL,
  p_opponent_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conflict_count INT;
  v_new_booking_id UUID;
  v_status TEXT;
  v_is_paid BOOLEAN;
  v_is_deposit_paid BOOLEAN;
BEGIN
  -- Perform an explicit row-level lock check on existing bookings for this stadium
  SELECT COUNT(*)
  INTO v_conflict_count
  FROM bookings
  WHERE stadium_id = p_stadium_id
    AND status NOT IN ('cancelled', 'rejected')
    AND NOT (user_id = p_user_id AND status = 'pending')
    AND (
      (p_start_time >= start_time AND p_start_time < end_time) OR
      (p_end_time > start_time AND p_end_time <= end_time) OR
      (p_start_time <= start_time AND p_end_time >= end_time)
    )
  FOR UPDATE;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'double_booking',
      'message', 'This time slot is already booked or currently being reserved by another player.'
    );
  END IF;

  IF p_payment_status = 'paid' OR p_payment_method = 'free' THEN
    v_status := 'confirmed';
    v_is_paid := TRUE;
    v_is_deposit_paid := TRUE;
  ELSIF p_needs_deposit AND p_deposit_amount > 0 THEN
    v_status := 'pending';
    v_is_paid := FALSE;
    v_is_deposit_paid := FALSE;
  ELSE
    v_status := 'confirmed';
    v_is_paid := FALSE;
    v_is_deposit_paid := FALSE;
  END IF;

  INSERT INTO bookings (
    stadium_id,
    user_id,
    owner_id,
    start_time,
    end_time,
    booking_type,
    total_price,
    stadium_name,
    stadium_image_url,
    is_private,
    rent_ball,
    needs_deposit,
    deposit_amount,
    payment_method,
    payment_status,
    status,
    is_paid,
    is_deposit_paid,
    player_team_id,
    player_team_name,
    opponent_team_id,
    opponent_team_name,
    created_at,
    updated_at
  )
  VALUES (
    p_stadium_id,
    p_user_id,
    p_owner_id,
    p_start_time,
    p_end_time,
    p_booking_type,
    p_total_price,
    p_stadium_name,
    p_stadium_image_url,
    p_is_private,
    p_rent_ball,
    p_needs_deposit,
    p_deposit_amount,
    p_payment_method,
    p_payment_status,
    v_status,
    v_is_paid,
    v_is_deposit_paid,
    p_player_team_id,
    p_player_team_name,
    p_opponent_team_id,
    p_opponent_team_name,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'booking_id', v_new_booking_id,
    'status', v_status,
    'is_paid', v_is_paid
  );
END;
$$;

-- 4. 15-Minute Unconfirmed Booking Auto-Expiry Function
CREATE OR REPLACE FUNCTION public.auto_expire_unconfirmed_bookings()
RETURNS void AS $$
BEGIN
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Cancelled due to 15-minute payment timeout]'
  WHERE 
    status = 'pending'
    AND created_at <= NOW() - INTERVAL '15 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Secure Owner Document Storage Bucket & RLS Policies
INSERT INTO storage.buckets (id, name, public)
VALUES ('owner_documents', 'owner_documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "Owners can upload their own docs" ON storage.objects;
CREATE POLICY "Owners can upload their own docs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'owner_documents' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Owners can view their own docs" ON storage.objects;
CREATE POLICY "Owners can view their own docs"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'owner_documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 6. Tightened RLS Policies for Bookings & Team Members (Security Hardening)
DROP POLICY IF EXISTS "Player can update joined bookings" ON public.bookings;
CREATE POLICY "Player can update joined bookings"
ON public.bookings FOR UPDATE
TO authenticated
USING (auth.uid()::text = user_id::text OR auth.uid()::text = owner_id::text);

DROP POLICY IF EXISTS "Members can leave team" ON public.team_members;
CREATE POLICY "Members can leave team"
ON public.team_members FOR DELETE
TO authenticated
USING (auth.uid()::text = user_id::text);

-- 7. Real-Time Publication Setup
DO $$
DECLARE
    pub_exists boolean;
    tables_to_add text[] := ARRAY['users', 'bookings', 'chat_messages'];
    t text;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') INTO pub_exists;
    IF NOT pub_exists THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;

    FOREACH t IN ARRAY tables_to_add LOOP
        IF EXISTS (
            SELECT 1 FROM pg_namespace n JOIN pg_class c ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relname = t
        ) THEN
            IF NOT EXISTS (
                SELECT 1 FROM pg_publication_rel pr JOIN pg_class c ON c.oid = pr.prrelid JOIN pg_publication p ON p.oid = pr.prpubid
                WHERE p.pubname = 'supabase_realtime' AND c.relname = t
            ) THEN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
            END IF;
        END IF;
    END LOOP;
END $$;

-- ⚽ Ensure goal_details column exists on tournament_matches table
ALTER TABLE public.tournament_matches 
ADD COLUMN IF NOT EXISTS goal_details jsonb DEFAULT '[]'::jsonb;

-- ==============================================================================
-- 🚀 8. WEBHOOK-FIRST PAYMENT ARCHITECTURE SCHEMA & IDEMPOTENCY HANDLER
-- ==============================================================================

-- Add Webhook audit columns to bookings table
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS paymob_txn_id TEXT,
ADD COLUMN IF NOT EXISTS paymob_order_id TEXT,
ADD COLUMN IF NOT EXISTS webhook_processed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS webhook_verified BOOLEAN DEFAULT FALSE;

-- Create index on paymob_txn_id for fast idempotency lookups
CREATE INDEX IF NOT EXISTS idx_bookings_paymob_txn_id ON public.bookings(paymob_txn_id);

-- Create webhook_logs table for audit trail & debugging
CREATE TABLE IF NOT EXISTS public.webhook_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL DEFAULT 'paymob',
  event_type TEXT NOT NULL,
  txn_id TEXT,
  order_id TEXT,
  booking_id UUID,
  payload JSONB NOT NULL,
  signature_verified BOOLEAN DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'received',
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policy for webhook_logs (Admin/Service Role only)
ALTER TABLE public.webhook_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view webhook logs" ON public.webhook_logs;
CREATE POLICY "Admins can view webhook logs"
ON public.webhook_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id::text = auth.uid()::text
    AND u.role = 'admin'
  )
);

-- PostgreSQL function to process Paymob Webhook atomically with Idempotency
CREATE OR REPLACE FUNCTION public.process_paymob_webhook(
  p_booking_id UUID,
  p_txn_id TEXT,
  p_order_id TEXT,
  p_success BOOLEAN,
  p_signature_verified BOOLEAN,
  p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_booking RECORD;
  v_already_processed BOOLEAN;
BEGIN
  -- 1. Audit Log Entry
  INSERT INTO public.webhook_logs (
    provider, event_type, txn_id, order_id, booking_id, payload, signature_verified, status
  )
  VALUES (
    'paymob',
    CASE WHEN p_success THEN 'payment_success' ELSE 'payment_failed' END,
    p_txn_id, p_order_id, p_booking_id, p_payload, p_signature_verified,
    CASE WHEN p_signature_verified THEN 'processed' ELSE 'unverified' END
  );

  -- 2. Check if transaction ID was already processed (Idempotency)
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
        'booking_id', p_booking_id
      );
    END IF;
  END IF;

  -- 3. Lock & Fetch Target Booking Record
  SELECT * INTO v_existing_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_existing_booking.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'booking_not_found',
      'message', 'No booking found matching the provided ID.'
    );
  END IF;

  -- 4. Process Status Update
  IF p_success THEN
    UPDATE public.bookings
    SET
      status = 'confirmed',
      is_paid = TRUE,
      payment_status = 'paid',
      payment_method = 'paymob_card',
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_processed_at = NOW(),
      webhook_verified = p_signature_verified,
      updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'status', 'confirmed',
      'booking_id', p_booking_id
    );
  ELSE
    UPDATE public.bookings
    SET
      status = 'cancelled',
      is_paid = FALSE,
      payment_status = 'failed',
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_processed_at = NOW(),
      webhook_verified = p_signature_verified,
      notes = COALESCE(notes, '') || E'\n[SYSTEM: Payment declined via Paymob Webhook]',
      updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'status', 'cancelled',
      'booking_id', p_booking_id
    );
  END IF;
END;
$$;


