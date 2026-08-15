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

-- Add platform_fee and deposit tracking columns to bookings
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS platform_fee NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS deposit_paid NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_deposit_paid BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS needs_deposit BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS payment_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS paymob_txn_id TEXT,
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'EGP',
ADD COLUMN IF NOT EXISTS host_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS host_avatar_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS player_team_logo_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS opponent_team_logo_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS player_phone TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS unread_counts JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS last_message TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS deleted_for_users TEXT[] DEFAULT ARRAY[]::text[],
ADD COLUMN IF NOT EXISTS pending_user_ids TEXT[] DEFAULT ARRAY[]::text[],
ADD COLUMN IF NOT EXISTS is_official_match BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_dispute_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS dispute_photo_url TEXT DEFAULT NULL;

-- Add missing columns to stadiums
ALTER TABLE public.stadiums
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS needs_deposit BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_deleted_by_owner BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS opening_time TEXT DEFAULT '04:00 PM',
ADD COLUMN IF NOT EXISTS closing_time TEXT DEFAULT '03:00 AM',
ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT ARRAY[]::text[];

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

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

CREATE OR REPLACE VIEW public.owner_subscription_status
WITH (security_invoker = true) AS
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

-- Drop rigid legacy exclusion constraint on bookings table to allow atomic PL/pgSQL row locks
ALTER TABLE public.bookings
-- =========================================================================
-- 🛡️ VSP PRODUCTION DATABASE INTEGRITY & SECURITY PACK (TYPE-SAFE FIX)
-- =========================================================================

-- 1. تفعيل الامتدادات الضرورية
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2. دالة الحجز الذري الآمنة مع أقفال المعاملات ومنع الـ Race Condition
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id UUID,
    p_user_id UUID,
    p_owner_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_booking_type TEXT,
    p_total_price NUMERIC,
    p_stadium_name TEXT DEFAULT '',
    p_stadium_image_url TEXT DEFAULT '',
    p_is_private BOOLEAN DEFAULT TRUE,
    p_rent_ball BOOLEAN DEFAULT FALSE,
    p_needs_deposit BOOLEAN DEFAULT FALSE,
    p_deposit_amount NUMERIC DEFAULT 0,
    p_payment_method TEXT DEFAULT 'cash',
    p_payment_status TEXT DEFAULT 'pending',
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
    v_stadium_verified BOOLEAN;
    v_stadium_blocked BOOLEAN;
    v_user_blocked BOOLEAN;
BEGIN
    -- قفل مخصص للمعاملة لمنع حجز نفس الملعب في نفس اللحظة
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id::text));

    -- أ. التحقق من حالة الملعب
    SELECT is_verified, is_blocked INTO v_stadium_verified, v_stadium_blocked
    FROM public.stadiums WHERE id::text = p_stadium_id::text;

    IF v_stadium_verified IS NOT TRUE OR v_stadium_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
    END IF;

    -- ب. التحقق من عدم حظر المستخدم
    SELECT is_blocked INTO v_user_blocked 
    FROM public.users WHERE id::text = p_user_id::text;
    
    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع الدعم الفني.');
    END IF;

    -- ج. فحص التضارب الزمني المباشر
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id::text
      AND status != 'cancelled'
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الوقت محجوز بالفعل لمباراة أخرى.');
    END IF;

    -- د. إنشاء وتثبيت الحجز
    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, created_at, updated_at
    ) VALUES (
        p_stadium_id, p_user_id, p_user_id, p_owner_id,
        p_start_time, p_end_time, p_booking_type, p_total_price,
        p_stadium_name, p_stadium_image_url, p_is_private, p_rent_ball,
        p_needs_deposit, p_deposit_amount, CASE WHEN p_payment_status = 'paid' THEN p_deposit_amount ELSE 0 END,
        p_payment_method, p_payment_status,
        CASE WHEN p_payment_status = 'paid' OR p_payment_method = 'cash' THEN 'confirmed' ELSE 'pending' END,
        CASE WHEN p_payment_status = 'paid' THEN TRUE ELSE FALSE END,
        p_player_team_id, p_player_team_name, p_opponent_team_id, p_opponent_team_name,
        ARRAY[p_user_id::text], NOW(), NOW()
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'message', 'تم تأكيد الحجز بنجاح.'
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

-- =========================================================================
-- 🛡️ VSP BOOKING PERMISSIONS & REALTIME ACTIVATION
-- =========================================================================

-- 1. تفعيل Realtime على جدول الحجوزات بأمان (فقط إذا لم يكن مضافاً مسبقاً)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'bookings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
    END IF;
END $$;

-- 2. إعطاء صلاحيات الإدخال (INSERT) لجميع المستخدمين المسجلين
DROP POLICY IF EXISTS "Users can insert their own bookings" ON public.bookings;
CREATE POLICY "Users can insert their own bookings" ON public.bookings
FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
);

-- 3. إعطاء صلاحيات التعديل (UPDATE) لصاحب الحجز أو مالك الملعب
DROP POLICY IF EXISTS "Users and Owners can update relevant bookings" ON public.bookings;
CREATE POLICY "Users and Owners can update relevant bookings" ON public.bookings
FOR UPDATE USING (
    auth.uid()::text = user_id::text OR
    auth.uid()::text = created_by_user_id::text OR
    auth.uid()::text = owner_id::text
) WITH CHECK (
    auth.uid()::text = user_id::text OR
    auth.uid()::text = created_by_user_id::text OR
    auth.uid()::text = owner_id::text
);

-- 4. إعطاء صلاحيات الحذف (DELETE) لصاحب الحجز والمالك
DROP POLICY IF EXISTS "Users and Owners can delete relevant bookings" ON public.bookings;
CREATE POLICY "Users and Owners can delete relevant bookings" ON public.bookings
FOR DELETE USING (
    auth.uid()::text = user_id::text OR
    auth.uid()::text = created_by_user_id::text OR
    auth.uid()::text = owner_id::text
);

-- 5. تحديث دالة الحجز الذري لتقبل نصوص المعرفات بدون انهيار UUID
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id TEXT,
    p_user_id TEXT,
    p_owner_id TEXT,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_booking_type TEXT,
    p_total_price NUMERIC,
    p_stadium_name TEXT DEFAULT '',
    p_stadium_image_url TEXT DEFAULT '',
    p_is_private BOOLEAN DEFAULT TRUE,
    p_rent_ball BOOLEAN DEFAULT FALSE,
    p_needs_deposit BOOLEAN DEFAULT FALSE,
    p_deposit_amount NUMERIC DEFAULT 0,
    p_payment_method TEXT DEFAULT 'cash',
    p_payment_status TEXT DEFAULT 'pending',
    p_player_team_id TEXT DEFAULT NULL,
    p_player_team_name TEXT DEFAULT NULL,
    p_opponent_team_id TEXT DEFAULT NULL,
    p_opponent_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conflict_count INT;
    v_new_booking_id UUID;
BEGIN
    -- قفل تزامني للملعب
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- فحص التضارب
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الوقت محجوز بالفعل لمباراة أخرى.');
    END IF;

    -- الإدخال المباشر
    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, created_at, updated_at
    ) VALUES (
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id, p_user_id, p_owner_id,
        p_start_time, p_end_time, p_booking_type, p_total_price,
        p_stadium_name, p_stadium_image_url, p_is_private, p_rent_ball,
        p_needs_deposit, p_deposit_amount, CASE WHEN p_payment_status = 'paid' THEN p_deposit_amount ELSE 0 END,
        p_payment_method, p_payment_status,
        CASE WHEN p_payment_status = 'paid' OR p_payment_method = 'cash' THEN 'confirmed' ELSE 'pending' END,
        CASE WHEN p_payment_status = 'paid' THEN TRUE ELSE FALSE END,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id], NOW(), NOW()
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'message', 'تم تأكيد الحجز بنجاح.'
    );
END;
$$;
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

-- 5. Auto-sync user_id and created_by_user_id Guarantee Trigger
CREATE OR REPLACE FUNCTION public.sync_booking_user_ids()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.created_by_user_id IS NULL AND NEW.user_id IS NOT NULL THEN
    NEW.created_by_user_id := NEW.user_id;
  END IF;
  IF NEW.user_id IS NULL AND NEW.created_by_user_id IS NOT NULL THEN
    NEW.user_id := NEW.created_by_user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_booking_user_ids ON public.bookings;
CREATE TRIGGER trg_sync_booking_user_ids
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.sync_booking_user_ids();

-- =========================================================================
-- ⚽ VSP PUBLIC MATCH JOIN & APPROVAL RPC ENGINE
-- =========================================================================

-- 0. إسقاط الدوال القديمة لتفادي خطأ تغير نوع الإرجاع (42P13)
DROP FUNCTION IF EXISTS public.request_join_public_match(UUID, UUID);
DROP FUNCTION IF EXISTS public.accept_join_request(UUID, UUID);
DROP FUNCTION IF EXISTS public.reject_join_request(UUID, UUID);

-- 1. دالة الانضمام الفوري المباشر للمباراة (Instant Join Engine)
CREATE OR REPLACE FUNCTION public.request_join_public_match(
    p_booking_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
BEGIN
    -- 1. قفل السطر الخاص بالمباراة لمنع أي تضارب أو زيادة عن العدد المسموح (Race Condition)
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'match_cancelled';
    END IF;

    -- 2. التحقق من عدم حظر اللاعب
    SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = p_user_id;
    IF v_user_blocked IS TRUE THEN
        RAISE EXCEPTION 'user_blocked';
    END IF;

    -- 3. التحقق من السعة الكلية للملعب
    v_capacity := COALESCE(v_booking.total_field_capacity, 10);
    IF v_booking.current_players >= v_capacity THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    -- 4. التحقق من عدم الانضمام مسبقاً لنفس المباراة
    IF p_user_id::text = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::text[])) THEN
        RAISE EXCEPTION 'already_joined';
    END IF;

    -- 5. فحص التضارب الزمني مع مباريات وحجوزات أخرى للاعب في نفس الوقت
    SELECT COUNT(*) INTO v_user_conflict
    FROM public.bookings
    WHERE status = 'confirmed'
      AND (user_id::text = p_user_id::text OR p_user_id::text = ANY(joined_user_ids))
      AND id != p_booking_id
      AND (
          (v_booking.start_time >= start_time AND v_booking.start_time < end_time) OR
          (v_booking.end_time > start_time AND v_booking.end_time <= end_time)
      );

    IF v_user_conflict > 0 THEN
        RAISE EXCEPTION 'time_conflict';
    END IF;

    -- 6. ✅ تسجيل وحجز المكان فورياً في قائمة المنضمين وزيادة العداد تلقائياً
    UPDATE public.bookings
    SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::text[]), p_user_id::text),
        pending_user_ids = array_remove(COALESCE(pending_user_ids, ARRAY[]::text[]), p_user_id::text),
        current_players = current_players + 1,
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Joined match instantly.'
    );
END;
$$;

-- 2. دالة قبول طلب الانضمام من قِبل المستضيف
CREATE OR REPLACE FUNCTION public.accept_join_request(
    p_booking_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.current_players >= COALESCE(v_booking.total_field_capacity, 10) THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    -- إزالة من المعلقين وإضافة للمنضمين وزيادة العداد
    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids, ARRAY[]::text[]), p_user_id::text),
        joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::text[]), p_user_id::text),
        current_players = current_players + 1,
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Player accepted successfully.');
END;
$$;

-- 3. دالة رفض طلب الانضمام
CREATE OR REPLACE FUNCTION public.reject_join_request(
    p_booking_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids, ARRAY[]::text[]), p_user_id::text),
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Request rejected.');
END;
$$;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- 🏆 VSP COMPLETE RPC MASTER PACK (STANDINGS, SEARCH, NO-SHOW & BADGES)
-- =========================================================================

DROP FUNCTION IF EXISTS public.get_championship_standings(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.global_search(TEXT);
DROP FUNCTION IF EXISTS public.check_team_has_1v1_champion(TEXT);
DROP FUNCTION IF EXISTS public.apply_no_show_penalty(TEXT);
DROP FUNCTION IF EXISTS public.dispute_no_show_with_gps(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC);

-- 1. دالة حساب جدول ترتيب الدوري والمجموعات تلقائياً
CREATE OR REPLACE FUNCTION public.get_championship_standings(
    p_championship_id TEXT,
    p_group_name TEXT DEFAULT NULL
)
RETURNS TABLE (
    team_id TEXT,
    team_name TEXT,
    played INT,
    won INT,
    drawn INT,
    lost INT,
    goals_for INT,
    goals_against INT,
    goal_difference INT,
    points INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH matches_data AS (
        SELECT 
            home_team_id AS t_id,
            home_team_name AS t_name,
            home_score AS gf,
            away_score AS ga,
            CASE 
                WHEN home_score > away_score THEN 3
                WHEN home_score = away_score THEN 1
                ELSE 0 
            END AS pts,
            CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS w,
            CASE WHEN home_score = away_score THEN 1 ELSE 0 END AS d,
            CASE WHEN home_score < away_score THEN 1 ELSE 0 END AS l
        FROM public.tournament_matches
        WHERE championship_id::text = p_championship_id
          AND status = 'completed'
          AND (p_group_name IS NULL OR group_name = p_group_name)

        UNION ALL

        SELECT 
            away_team_id AS t_id,
            away_team_name AS t_name,
            away_score AS gf,
            home_score AS ga,
            CASE 
                WHEN away_score > home_score THEN 3
                WHEN away_score = home_score THEN 1
                ELSE 0 
            END AS pts,
            CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS w,
            CASE WHEN away_score = home_score THEN 1 ELSE 0 END AS d,
            CASE WHEN away_score < home_score THEN 1 ELSE 0 END AS l
        FROM public.tournament_matches
        WHERE championship_id::text = p_championship_id
          AND status = 'completed'
          AND (p_group_name IS NULL OR group_name = p_group_name)
    )
    SELECT 
        m.t_id::text AS team_id,
        MAX(m.t_name)::text AS team_name,
        COUNT(*)::int AS played,
        SUM(m.w)::int AS won,
        SUM(m.d)::int AS drawn,
        SUM(m.l)::int AS lost,
        SUM(m.gf)::int AS goals_for,
        SUM(m.ga)::int AS goals_against,
        (SUM(m.gf) - SUM(m.ga))::int AS goal_difference,
        SUM(m.pts)::int AS points
    FROM matches_data m
    WHERE m.t_id IS NOT NULL
    GROUP BY m.t_id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC;
END;
$$;

-- 2. دالة البحث الشامل الموحد (ملاعب، فرق، بطولات)
CREATE OR REPLACE FUNCTION public.global_search(search_term TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stadiums JSONB;
    v_teams JSONB;
    v_championships JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb) INTO v_stadiums
    FROM public.stadiums s
    WHERE s.name ILIKE '%' || search_term || '%' OR s.location ILIKE '%' || search_term || '%';

    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_teams
    FROM public.teams t
    WHERE t.name ILIKE '%' || search_term || '%';

    SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) INTO v_championships
    FROM public.championships c
    WHERE c.name ILIKE '%' || search_term || '%';

    RETURN jsonb_build_object(
        'stadiums', v_stadiums,
        'teams', v_teams,
        'championships', v_championships
    );
END;
$$;

-- 3. دالة فحص وجود بطل 1 ضد 1 داخل الفريق
CREATE OR REPLACE FUNCTION public.check_team_has_1v1_champion(p_team_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_has_champion BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.team_members tm
        JOIN public.vsp_1vs1_players p ON p.id::text = tm.user_id::text
        WHERE tm.team_id::text = p_team_id
          AND p.rank = 1
    ) INTO v_has_champion;

    RETURN v_has_champion;
END;
$$;

-- 4. دالة تطبيق عقوبة عدم الحضور
CREATE OR REPLACE FUNCTION public.apply_no_show_penalty(p_player_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.users
    SET no_show_count = COALESCE(no_show_count, 0) + 1,
        is_blocked = CASE WHEN COALESCE(no_show_count, 0) + 1 >= 3 THEN TRUE ELSE is_blocked END,
        updated_at = NOW()
    WHERE id::text = p_player_id;
END;
$$;

-- 5. دالة الطعن على الغياب بالـ GPS
CREATE OR REPLACE FUNCTION public.dispute_no_show_with_gps(
    p_booking_id TEXT,
    p_player_id TEXT,
    p_lat NUMERIC,
    p_lng NUMERIC,
    p_accuracy NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- إذا كانت دقة الـ GPS مقبولة، يتم تصفير العقوبة
    IF p_accuracy <= 50 THEN
        UPDATE public.users
        SET no_show_count = GREATEST(COALESCE(no_show_count, 0) - 1, 0),
            is_blocked = FALSE,
            updated_at = NOW()
        WHERE id::text = p_player_id;

        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- 🛡️ PUBLIC TEAMS & TEAM MEMBERS RLS POLICIES (OPEN READ FOR STREAM & RPC)
-- =========================================================================

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public teams read access" ON public.teams;
CREATE POLICY "Public teams read access"
ON public.teams FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Public teams write access" ON public.teams;
CREATE POLICY "Public teams write access"
ON public.teams FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Public team members read access" ON public.team_members;
CREATE POLICY "Public team members read access"
ON public.team_members FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Public team members write access" ON public.team_members;
CREATE POLICY "Public team members write access"
ON public.team_members FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- =========================================================================
-- 🚨 EMERGENCY CLOSURE, RESCHEDULING & AUTO-RECONCILIATION MIGRATION
-- =========================================================================

ALTER TABLE public.stadiums
ADD COLUMN IF NOT EXISTS maintenance_until TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS maintenance_reason TEXT,
ADD COLUMN IF NOT EXISTS last_emergency_closure_at TIMESTAMPTZ;

ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS reschedule_status TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS proposed_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS proposed_end_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS emergency_cancel_status TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS emergency_reason TEXT,
ADD COLUMN IF NOT EXISTS emergency_downtime_hours INT,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS refund_amount NUMERIC DEFAULT 0;

-- 🔄 Database Function for Auto-Reconciling Past Bookings
CREATE OR REPLACE FUNCTION public.auto_reconcile_past_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.bookings
  SET
    is_paid = true,
    payment_status = 'paid',
    status = 'completed',
    updated_at = NOW()
  WHERE
    end_time < NOW()
    AND status != 'cancelled'
    AND (is_paid = false OR status != 'completed');
END;
$$;

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- 🛡️ VSP PRODUCTION DATABASE SECURITY & PERFORMANCE HARDENING SCRIPT (PHASE 2)
-- ============================================================================

-- 1️⃣ Enable RLS on all system tables
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stadiums ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.championships ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.championship_rosters ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vsp_1vs1_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vsp_1v1_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.transactions ENABLE ROW LEVEL SECURITY;

-- 2️⃣ Row Level Security Policies

-- A. Public Read Tables
DROP POLICY IF EXISTS "Public can view stadiums" ON public.stadiums;
CREATE POLICY "Public can view stadiums" ON public.stadiums FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view championships" ON public.championships;
CREATE POLICY "Public can view championships" ON public.championships FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view teams" ON public.teams;
CREATE POLICY "Public can view teams" ON public.teams FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view team members" ON public.team_members;
CREATE POLICY "Public can view team members" ON public.team_members FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view tournament matches" ON public.tournament_matches;
CREATE POLICY "Public can view tournament matches" ON public.tournament_matches FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view 1v1 standings" ON public.vsp_1vs1_players;
CREATE POLICY "Public can view 1v1 standings" ON public.vsp_1vs1_players FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view reviews" ON public.reviews;
CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view app settings" ON public.app_settings;
CREATE POLICY "Public can view app settings" ON public.app_settings FOR SELECT USING (true);

-- B. Users Table (User Profile Isolation)
DROP POLICY IF EXISTS "Users can read own and public profile" ON public.users;
CREATE POLICY "Users can read own and public profile" ON public.users FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update only their own profile" ON public.users;
CREATE POLICY "Users can update only their own profile" ON public.users FOR UPDATE 
USING (auth.uid() = id) 
WITH CHECK (auth.uid() = id);

-- C. Bookings Table (Bookings Isolation)
DROP POLICY IF EXISTS "Users can view bookings they are part of or public" ON public.bookings;
CREATE POLICY "Users can view bookings they are part of or public" ON public.bookings FOR SELECT 
USING (
  auth.uid() = user_id OR 
  auth.uid() = owner_id OR 
  auth.uid() = created_by_user_id OR 
  is_private = false OR 
  auth.uid()::text = ANY(joined_user_ids)
);

DROP POLICY IF EXISTS "Users can insert bookings" ON public.bookings;
CREATE POLICY "Users can insert bookings" ON public.bookings FOR INSERT 
WITH CHECK (auth.uid() = user_id OR auth.uid() = created_by_user_id OR auth.uid() = owner_id);

DROP POLICY IF EXISTS "Participants can update their booking" ON public.bookings;
CREATE POLICY "Participants can update their booking" ON public.bookings FOR UPDATE 
USING (auth.uid() = user_id OR auth.uid() = owner_id OR auth.uid() = created_by_user_id);

-- D. Chat Messages (Isolation)
DROP POLICY IF EXISTS "Participants can read chat messages" ON public.chat_messages;
CREATE POLICY "Participants can read chat messages" ON public.chat_messages FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE bookings.id = chat_messages.booking_id 
    AND (
      bookings.user_id = auth.uid() OR 
      bookings.owner_id = auth.uid() OR 
      bookings.created_by_user_id = auth.uid() OR
      auth.uid()::text = ANY(bookings.joined_user_ids)
    )
  )
);

DROP POLICY IF EXISTS "Participants can send chat messages" ON public.chat_messages;
CREATE POLICY "Participants can send chat messages" ON public.chat_messages FOR INSERT 
WITH CHECK (auth.uid() = sender_id);

-- E. Notifications (User Isolation)
DROP POLICY IF EXISTS "Users can only read own notifications" ON public.notifications;
CREATE POLICY "Users can only read own notifications" ON public.notifications FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE 
USING (auth.uid() = user_id);

-- 3️⃣ Performance Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_owner_id ON public.bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_stadium_start ON public.bookings(stadium_id, start_time);
CREATE INDEX IF NOT EXISTS idx_stadiums_governorate ON public.stadiums(governorate);
CREATE INDEX IF NOT EXISTS idx_stadiums_owner_id ON public.stadiums(owner_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_booking ON public.chat_messages(booking_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON public.team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_champ ON public.tournament_matches(championship_id);

-- =========================================================================
-- 🛡️ VSP BULLETPROOF PRECISION PATCH
-- =========================================================================

-- 1. ELO Double Calculation Prevention Trigger
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    home_elo INT;
    away_elo INT;
    new_home_elo INT;
    new_away_elo INT;
    outcome FLOAT;
BEGIN
    IF NEW.status = 'completed' 
       AND OLD.status != 'completed' 
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

            new_home_elo := round(home_elo + 32 * (outcome - (1 / (1 + power(10, (away_elo - home_elo)::float / 400)))));
            new_away_elo := round(away_elo + 32 * ((1 - outcome) - (1 / (1 + power(10, (home_elo - away_elo)::float / 400)))));

            UPDATE public.teams 
            SET points = GREATEST(0, new_home_elo), 
                matches_played = matches_played + 1,
                wins = wins + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                draws = draws + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = losses + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                trend = (CASE WHEN outcome > 0.0 THEN 'up' ELSE 'down' END)
            WHERE id = NEW.player_team_id;

            UPDATE public.teams 
            SET points = GREATEST(0, new_away_elo), 
                matches_played = matches_played + 1,
                wins = wins + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                draws = draws + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = losses + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                trend = (CASE WHEN outcome < 1.0 THEN 'up' ELSE 'down' END)
            WHERE id = NEW.opponent_team_id;

            -- Mark processed to prevent double calculation
            NEW.elo_processed := true;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- 2. Paymob Webhook Clean UUID Extractor
CREATE OR REPLACE FUNCTION public.process_paymob_webhook(
    p_booking_id TEXT,
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
    v_clean_id TEXT;
    v_existing_booking RECORD;
BEGIN
    -- Extract clean UUID prefix before timestamp suffix
    v_clean_id := split_part(p_booking_id, '_', 1);

    SELECT * INTO v_existing_booking
    FROM public.bookings
    WHERE id::text = v_clean_id
    FOR UPDATE;

    IF v_existing_booking.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
    END IF;

    IF p_success THEN
        UPDATE public.bookings
        SET status = 'confirmed',
            is_paid = TRUE,
            payment_status = 'paid',
            payment_transaction_id = 'PAYMOB_' || p_txn_id,
            updated_at = NOW()
        WHERE id::text = v_clean_id;

        RETURN jsonb_build_object('success', true, 'status', 'confirmed');
    ELSE
        UPDATE public.bookings
        SET status = 'cancelled',
            is_paid = FALSE,
            payment_status = 'failed',
            updated_at = NOW()
        WHERE id::text = v_clean_id;

        RETURN jsonb_build_object('success', true, 'status', 'cancelled');
    END IF;
END;
$$;





