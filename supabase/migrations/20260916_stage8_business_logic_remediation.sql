-- ============================================================================
-- VSP MIGRATION: 20260916_stage8_business_logic_remediation.sql
-- Description: Stage 8 Implementation - Business Logic, Financial Ledger,
--              Operating Hours, Missing Contracts, Dynamic QR & Referral Engine.
-- Authoritative Zero-Trust Server-Side Enforcement.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SECTION 1: SCHEMA ENHANCEMENTS (Users, Bookings, Referrals, Points Ledger)
-- ----------------------------------------------------------------------------

-- 1.1 Users schema additions
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS accumulated_cash_debt NUMERIC NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS debt_limit NUMERIC NOT NULL DEFAULT 500.00,
    ADD COLUMN IF NOT EXISTS is_debt_blocked BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS points INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS referral_code TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_users_debt_non_negative'
    ) THEN
        ALTER TABLE public.users ADD CONSTRAINT check_users_debt_non_negative CHECK (accumulated_cash_debt >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_users_debt_limit_non_negative'
    ) THEN
        ALTER TABLE public.users ADD CONSTRAINT check_users_debt_limit_non_negative CHECK (debt_limit >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_users_points_non_negative'
    ) THEN
        ALTER TABLE public.users ADD CONSTRAINT check_users_points_non_negative CHECK (points >= 0);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_referral_code 
ON public.users(referral_code) 
WHERE referral_code IS NOT NULL;

-- Backfill referral codes for users missing one
UPDATE public.users 
SET referral_code = UPPER(SUBSTRING(REPLACE(id::text, '-', ''), 1, 8))
WHERE referral_code IS NULL;

-- 1.2 Bookings schema additions
ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS vsp_commission NUMERIC NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS gateway_fee NUMERIC NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS qr_hash TEXT,
    ADD COLUMN IF NOT EXISTS qr_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS qr_scanned_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_bookings_vsp_commission_non_negative'
    ) THEN
        ALTER TABLE public.bookings ADD CONSTRAINT check_bookings_vsp_commission_non_negative CHECK (vsp_commission >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_bookings_gateway_fee_non_negative'
    ) THEN
        ALTER TABLE public.bookings ADD CONSTRAINT check_bookings_gateway_fee_non_negative CHECK (gateway_fee >= 0);
    END IF;
END $$;

-- 1.3 Referrals table creation
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    invitee_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    referral_code TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'qualified', 'rewarded')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    qualified_at TIMESTAMPTZ,
    qualifying_booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    CONSTRAINT check_no_self_referral CHECK (inviter_user_id <> invitee_user_id),
    CONSTRAINT uq_invitee_referral UNIQUE (invitee_user_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_inviter ON public.referrals(inviter_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_invitee ON public.referrals(invitee_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);

-- 1.4 Points Ledger table creation
CREATE TABLE IF NOT EXISTS public.points_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    points_delta INTEGER NOT NULL,
    balance_after INTEGER,
    reason TEXT NOT NULL,
    reference_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_points_ledger_user ON public.points_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_points_ledger_ref ON public.points_ledger(reference_id);

-- 1.5 RLS & Permissions on Referrals & Points Ledger
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own referrals" ON public.referrals;
CREATE POLICY "Users can view their own referrals" ON public.referrals
FOR SELECT TO authenticated
USING (
    inviter_user_id = auth.uid() OR
    invitee_user_id = auth.uid() OR
    COALESCE((SELECT role FROM public.users WHERE id = auth.uid()), '') IN ('admin', 'co_founder')
);

DROP POLICY IF EXISTS "Users can view their own points ledger" ON public.points_ledger;
CREATE POLICY "Users can view their own points ledger" ON public.points_ledger
FOR SELECT TO authenticated
USING (
    user_id = auth.uid() OR
    COALESCE((SELECT role FROM public.users WHERE id = auth.uid()), '') IN ('admin', 'co_founder')
);

REVOKE INSERT, UPDATE, DELETE ON public.referrals FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.points_ledger FROM anon, authenticated;


-- ----------------------------------------------------------------------------
-- SECTION 2: TRIGGER HARDENING (Protect Users Sensitive Fields)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
  v_is_admin boolean := false;
BEGIN
  -- Allow internal postgres and service_role system processes ONLY when no user identity is set
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    RETURN NEW;
  END IF;

  -- Allow trusted internal system procedures within the transaction
  IF current_setting('vsp.system_override', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- Verify if caller is an authoritative administrator based on pre-existing database record
  IF auth.uid() IS NOT NULL THEN
    SELECT (role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))
    INTO v_is_admin
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  -- Allow platform admins to update sensitive user fields
  IF COALESCE(v_is_admin, false) THEN
    RETURN NEW;
  END IF;

  -- For normal authenticated users, strictly forbid self-mutation of sensitive columns
  IF (OLD.role IS DISTINCT FROM NEW.role) OR
     (OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan) OR
     (OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at) OR
     (OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at) OR
     (OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees) OR
     (OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned) OR
     (OLD.no_show_count IS DISTINCT FROM NEW.no_show_count) OR
     (OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified) OR
     (OLD.verification_status IS DISTINCT FROM NEW.verification_status) OR
     (OLD.is_blocked IS DISTINCT FROM NEW.is_blocked) OR
     (OLD.accumulated_cash_debt IS DISTINCT FROM NEW.accumulated_cash_debt) OR
     (OLD.debt_limit IS DISTINCT FROM NEW.debt_limit) OR
     (OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked) OR
     (OLD.points IS DISTINCT FROM NEW.points) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Modifying security-sensitive user fields is restricted to platform administrators.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SENSITIVE_FIELD_UPDATE';
  END IF;

  RETURN NEW;
END;
$function$;


-- ----------------------------------------------------------------------------
-- SECTION 3: F7-004 — HARDEN dispute_no_show_with_gps
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.dispute_no_show_with_gps(
    p_booking_id text,
    p_player_id text,
    p_lat numeric,
    p_lng numeric,
    p_accuracy numeric
)
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
  -- 1. Parse & validate UUIDs
  BEGIN
    v_player_uuid := p_player_id::uuid;
    v_booking_uuid := p_booking_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_UUID_FORMAT: Invalid player or booking identifier' USING ERRCODE = '22P02';
  END;

  -- 2. Strict Zero-Trust Caller Authorization (auth.uid must match p_player_id unless service_role/admin)
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF auth.uid() IS NULL OR auth.uid() != v_player_uuid THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: You can only dispute penalties for your own account.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 3. GPS accuracy validation (must be <= 50 meters)
  IF p_accuracy > 50 THEN
    RAISE EXCEPTION 'gps_accuracy_too_low';
  END IF;

  -- 4. Fetch booking record
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = v_booking_uuid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking_not_found';
  END IF;

  -- 5. Strict Participant Verification: caller MUST have been a participant in this booking
  IF v_booking.user_id != v_player_uuid 
     AND v_booking.created_by_user_id != v_player_uuid 
     AND NOT (v_player_uuid::text = ANY(COALESCE(v_booking.joined_user_ids::text[], ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Player was not a registered participant in this booking.'
      USING ERRCODE = '42501';
  END IF;

  -- 6. Dispute window verification: maximum 60 minutes after match end
  IF timezone('utc'::text, now()) > (v_booking.end_time + INTERVAL '60 minutes') THEN
    RAISE EXCEPTION 'dispute_window_expired';
  END IF;

  -- 7. Fetch stadium coordinates
  SELECT * INTO v_stadium
  FROM public.stadiums
  WHERE id = v_booking.stadium_id;

  IF v_stadium.lat IS NULL OR v_stadium.lng IS NULL THEN
    RAISE EXCEPTION 'stadium_coordinates_missing';
  END IF;

  -- 8. Calculate geographic distance (Haversine formula)
  v_distance_meters := 6371000 * acos(
    LEAST(1.0, GREATEST(-1.0,
      cos(radians(v_stadium.lat)) * cos(radians(p_lat)) *
      cos(radians(p_lng) - radians(v_stadium.lng)) +
      sin(radians(v_stadium.lat)) * sin(radians(p_lat))
    ))
  );

  -- Must be physically within 150 meters of the stadium
  IF v_distance_meters > 150 THEN
    RAISE EXCEPTION 'not_at_stadium';
  END IF;

  -- 9. Decrement no_show_count & clear block state
  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET 
    no_show_count = GREATEST(0, no_show_count - 1),
    is_blocked = false,
    cash_booking_banned = CASE WHEN GREATEST(0, no_show_count - 1) >= 2 THEN true ELSE false END,
    updated_at = timezone('utc'::text, now())
  WHERE id = v_player_uuid;

  -- 10. Mark booking dispute approved
  UPDATE public.bookings
  SET 
    is_dispute_approved = true,
    match_result_status = 'confirmed',
    updated_at = timezone('utc'::text, now())
  WHERE id = v_booking_uuid;

  RETURN true;
END;
$function$;


-- ----------------------------------------------------------------------------
-- SECTION 4: F7-005 & F7-003 — HARDEN create_booking_atomic
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id text,
    p_user_id text,
    p_owner_id text,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_booking_type text,
    p_total_price numeric,
    p_stadium_name text DEFAULT ''::text,
    p_stadium_image_url text DEFAULT ''::text,
    p_is_private boolean DEFAULT true,
    p_rent_ball boolean DEFAULT false,
    p_needs_deposit boolean DEFAULT false,
    p_deposit_amount numeric DEFAULT 0,
    p_payment_method text DEFAULT 'cash'::text,
    p_payment_status text DEFAULT 'pending'::text,
    p_player_team_id text DEFAULT NULL::text,
    p_player_team_name text DEFAULT NULL::text,
    p_opponent_team_id text DEFAULT NULL::text,
    p_opponent_team_name text DEFAULT NULL::text,
    p_platform_fee numeric DEFAULT 0.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_new_booking_id UUID;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0;
    v_duration_hours NUMERIC;
    v_final_total_price NUMERIC;
    v_vsp_commission NUMERIC;
    v_gateway_fee NUMERIC := 0.00;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_deposit_paid NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_locked_until TIMESTAMPTZ;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_conflict_count INT;
    v_final_owner_id UUID;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    
    -- Operating hours variables (Cairo local time)
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
BEGIN
    -- 1. Identity & Zero-Trust Caller check
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- 2. Duration validity (30 minutes to 8 hours)
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;

    IF v_duration_hours < 0.5 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تقل عن 30 دقيقة.');
    END IF;

    IF v_duration_hours > 8.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تتجاوز 8 ساعات في المرة الواحدة.');
    END IF;

    -- 3. Concurrency Lock on Stadium (Advisory Lock)
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Verify stadium existence and status
    SELECT * INTO v_stadium
    FROM public.stadiums 
    WHERE id::text = p_stadium_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 5. [F7-005] Operating Hours & Split-Shift Validation (Cairo Local Time)
    v_start_cairo := timezone('Africa/Cairo', p_start_time);
    v_end_cairo := timezone('Africa/Cairo', p_end_time);
    v_date_cairo := v_start_cairo::date;

    IF v_stadium.opening_time IS NOT NULL AND v_stadium.closing_time IS NOT NULL THEN
        -- Construct open & close timestamps for the operational shift
        IF v_stadium.closing_time > v_stadium.opening_time THEN
            v_open_ts := v_date_cairo + v_stadium.opening_time;
            v_close_ts := v_date_cairo + v_stadium.closing_time;
        ELSE
            -- Overnight shift (e.g. 16:00 to 01:00 next day)
            IF v_start_cairo::time >= v_stadium.opening_time THEN
                v_open_ts := v_date_cairo + v_stadium.opening_time;
                v_close_ts := (v_date_cairo + interval '1 day') + v_stadium.closing_time;
            ELSE
                v_open_ts := (v_date_cairo - interval '1 day') + v_stadium.opening_time;
                v_close_ts := v_date_cairo + v_stadium.closing_time;
            END IF;
        END IF;

        IF v_start_cairo < v_open_ts OR v_end_cairo > v_close_ts THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'OUTSIDE_OPERATING_HOURS',
                'message', 'عذراً، هذا الموعد خارج أوقات عمل الملعب الرسمية (' || v_stadium.opening_time || ' - ' || v_stadium.closing_time || ').'
            );
        END IF;

        -- Split-shift break validation
        IF v_stadium.is_split_shift IS TRUE AND v_stadium.break_start_time IS NOT NULL AND v_stadium.break_end_time IS NOT NULL THEN
            IF v_stadium.break_start_time >= v_stadium.opening_time THEN
                v_break_start_ts := v_open_ts::date + v_stadium.break_start_time;
            ELSE
                v_break_start_ts := (v_open_ts::date + interval '1 day') + v_stadium.break_start_time;
            END IF;

            IF v_stadium.break_end_time >= v_stadium.break_start_time THEN
                v_break_end_ts := v_break_start_ts::date + v_stadium.break_end_time;
            ELSE
                v_break_end_ts := (v_break_start_ts::date + interval '1 day') + v_stadium.break_end_time;
            END IF;

            -- Check interval overlap
            IF v_start_cairo < v_break_end_ts AND v_end_cairo > v_break_start_ts THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'code', 'OUTSIDE_OPERATING_HOURS',
                    'message', 'عذراً، هذا الموعد يتعارض مع فترة راحة الملعب (Shift Break).'
                );
            END IF;
        END IF;
    END IF;

    -- 6. Server-Side Price Calculation
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

    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.'
        );
    END IF;

    v_final_total_price := v_calculated_price;
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 7. [F7-003] Calculate 2% Platform Commission and Gateway Fee
    v_vsp_commission := round(v_final_total_price * 0.02, 2);
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_gateway_fee := round((v_final_total_price * 0.0475) + 3.0, 2);
    ELSE
        v_gateway_fee := 0.00;
    END IF;

    -- 8. User state & No-show checks
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 9. [F7-003] Cash Booking: Check Owner Debt Limit
    IF p_payment_method = 'cash' THEN
        SELECT accumulated_cash_debt, debt_limit, is_debt_blocked 
        INTO v_owner
        FROM public.users 
        WHERE id = v_final_owner_id;

        IF v_owner.is_debt_blocked IS TRUE OR COALESCE(v_owner.accumulated_cash_debt, 0) >= COALESCE(v_owner.debt_limit, 500.0) THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'DEBT_LIMIT_EXCEEDED',
                'message', 'عذراً، تم إيقاف الحجز النقدي لهذا الملعب مؤقتاً لتجاوز حد المديونية المسموح. يرجى الدفع إلكترونياً.'
            );
        END IF;

        -- One active cash booking per user restriction
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > v_now;

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 10. Conflict detection against active bookings
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
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

    -- 11. Booking status assignment
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := v_now + INTERVAL '5 minutes';
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 12. Insert Booking Record
    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price, 
        vsp_commission, gateway_fee, platform_fee,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, locked_until, created_at, updated_at
    ) VALUES (
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
        p_start_time, p_end_time, p_booking_type, v_final_total_price,
        v_vsp_commission, v_gateway_fee, v_gateway_fee,
        COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
        COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
        p_is_private, p_rent_ball,
        v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
        p_payment_method, 'pending', v_final_status, v_final_is_paid,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id::uuid], v_locked_until, v_now, v_now
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'vsp_commission', v_vsp_commission,
        'gateway_fee', v_gateway_fee,
        'deposit_amount', v_final_deposit_amount,
        'needs_deposit', v_final_needs_deposit,
        'locked_until', v_locked_until
    );
END;
$function$;


-- ----------------------------------------------------------------------------
-- SECTION 5: F7-003 — CASH DEBT ACCUMULATION & SETTLEMENT RPCS
-- ----------------------------------------------------------------------------

-- 5.1 confirm_cash_booking_atomic with debt increment & limit check
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id uuid,
    p_owner_id uuid,
    p_total_price numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_booking RECORD;
    v_owner RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
    v_commission NUMERIC;
    v_new_debt NUMERIC;
    v_is_blocked BOOLEAN;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Fetch & lock booking row
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. Authorization check: Real stadium owner or platform admin
    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role 
        FROM public.users 
        WHERE id = auth.uid();

        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- 3. Prevent confirming cancelled booking
    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
            USING ERRCODE = 'P0003', DETAIL = 'BOOKING_CANCELLED';
    END IF;

    -- 4. Idempotency Check: if already paid, return safely without duplicate debt
    IF v_booking.is_paid IS TRUE AND v_booking.payment_status = 'paid' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'total_price', v_booking.total_price
        );
    END IF;

    -- 5. Lock owner row for atomic debt calculation
    SELECT * INTO v_owner
    FROM public.users
    WHERE id = v_booking.owner_id
    FOR UPDATE;

    -- 6. Calculate cash amount & 2% platform commission
    v_cash_amount := GREATEST(0, COALESCE(v_booking.total_price, p_total_price, 0) - COALESCE(v_booking.deposit_paid, 0));
    IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
        v_cash_amount := v_booking.total_price;
    END IF;

    v_commission := COALESCE(NULLIF(v_booking.vsp_commission, 0), round(v_cash_amount * 0.02, 2));
    v_new_debt := COALESCE(v_owner.accumulated_cash_debt, 0) + v_commission;
    v_is_blocked := (v_new_debt >= COALESCE(v_owner.debt_limit, 500.00));

    -- 7. Atomically update owner debt
    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users
    SET 
        accumulated_cash_debt = v_new_debt,
        is_debt_blocked = v_is_blocked,
        updated_at = v_now
    WHERE id = v_booking.owner_id;

    -- 8. Update booking to paid & confirmed
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        status = 'confirmed',
        vsp_commission = v_commission,
        deposit_paid = COALESCE(v_booking.total_price, p_total_price),
        updated_at = v_now
    WHERE id = p_booking_id;

    -- 9. Insert central ledger transaction
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
        v_booking.owner_id,
        p_booking_id,
        v_cash_amount,
        'cash_settlement',
        'completed',
        'cash',
        'تحصيل كاش مؤكد بالملعب لحجز #' || substring(p_booking_id::text, 1, 8),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'already_confirmed', false,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'vsp_commission', v_commission,
        'accumulated_cash_debt', v_new_debt,
        'is_debt_blocked', v_is_blocked,
        'total_price', COALESCE(v_booking.total_price, p_total_price)
    );
END;
$function$;

-- 5.2 owner_create_manual_booking_atomic with debt limit guard & debt increment
CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(
    p_owner_id uuid,
    p_stadium_id uuid,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_customer_name text,
    p_customer_phone text DEFAULT NULL::text,
    p_notes text DEFAULT NULL::text,
    p_total_price numeric DEFAULT 0.0,
    p_collected_amount numeric DEFAULT 0.0,
    p_current_players integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_overlap_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_booking_id UUID;
    v_payment_status TEXT;
    v_is_paid BOOLEAN;
    v_customer_clean TEXT;
    v_caller_role TEXT;
    v_actual_owner_id UUID;
    v_is_authorized BOOLEAN := false;
    v_vsp_commission NUMERIC;
    v_new_debt NUMERIC;
    v_is_blocked BOOLEAN;
BEGIN
    -- 1. Fetch stadium and verify existence
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found', 'message', 'الملعب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'error', 'stadium_deleted', 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    -- 2. Authorization check
    IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        v_is_authorized := true;
    ELSIF auth.uid() IS NOT NULL THEN
        IF v_stadium.owner_id = auth.uid() THEN
            v_is_authorized := true;
        ELSE
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
                v_is_authorized := true;
            END IF;
        END IF;
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized', 'message', 'غير مصرح لك بالحجز في هذا الملعب: يمكنك فقط إدارة حجوزات ملاعبك.');
    END IF;

    v_actual_owner_id := v_stadium.owner_id;

    -- 3. Row lock on owner to check & accumulate debt
    SELECT * INTO v_owner FROM public.users WHERE id = v_actual_owner_id FOR UPDATE;

    IF v_owner.is_debt_blocked IS TRUE OR COALESCE(v_owner.accumulated_cash_debt, 0) >= COALESCE(v_owner.debt_limit, 500.00) THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'DEBT_LIMIT_EXCEEDED',
            'error', 'debt_limit_exceeded',
            'message', 'عذراً، تم إيقاف إنشاء الحجوزات النقدية مؤقتاً لتجاوز حد مديونية عمولات المنصة. يرجى تسوية المديونية للمتابعة.'
        );
    END IF;

    -- 4. Lock stadium for update
    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    -- 5. Overlap check
    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'conflict', 'message', 'عذراً، هذا الموعد تم حجزه للتو أو يتعارض مع حجز آخر نشط.');
    END IF;

    -- 6. Payment status & Commission calculation
    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_collected_amount > 0 THEN 'partially_paid'
        ELSE 'pending'
    END;

    v_customer_clean := COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي');
    v_vsp_commission := round(p_total_price * 0.02, 2);

    -- 7. Insert booking
    INSERT INTO public.bookings (
        stadium_id,
        stadium_name,
        owner_id,
        user_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
        host_name,
        player_phone,
        notes,
        total_price,
        vsp_commission,
        gateway_fee,
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
        v_stadium.name,
        v_actual_owner_id,
        v_actual_owner_id,
        COALESCE(auth.uid(), v_actual_owner_id),
        p_start_time,
        p_end_time,
        'personal',
        v_customer_clean,
        v_customer_clean,
        NULLIF(TRIM(p_customer_phone), ''),
        NULLIF(TRIM(p_notes), ''),
        p_total_price,
        v_vsp_commission,
        0.00,
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

    -- 8. Accumulate cash debt on owner
    v_new_debt := COALESCE(v_owner.accumulated_cash_debt, 0) + v_vsp_commission;
    v_is_blocked := (v_new_debt >= COALESCE(v_owner.debt_limit, 500.00));

    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users
    SET 
        accumulated_cash_debt = v_new_debt,
        is_debt_blocked = v_is_blocked,
        updated_at = v_now
    WHERE id = v_actual_owner_id;

    -- 9. Insert cash transaction if collected
    IF p_collected_amount > 0 THEN
        INSERT INTO public.transactions (
            user_id,
            booking_id,
            amount,
            type,
            status,
            payment_method,
            description,
            created_at,
            updated_at
        ) VALUES (
            v_actual_owner_id,
            v_booking_id,
            p_collected_amount,
            'cash',
            'completed',
            'cash',
            'دفع ' || CASE WHEN v_is_paid THEN 'كامل' ELSE 'عربون' END || ' حجز يدوي: ' || COALESCE(v_stadium.name, 'الملعب'),
            v_now,
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'vsp_commission', v_vsp_commission,
        'accumulated_cash_debt', v_new_debt,
        'is_debt_blocked', v_is_blocked,
        'message', 'تم إنشاء الحجز اليدوي بنجاح.'
    );
END;
$function$;

-- 5.3 admin_settle_owner_cash_debt_atomic for debt settlement
CREATE OR REPLACE FUNCTION public.admin_settle_owner_cash_debt_atomic(
    p_owner_id uuid,
    p_amount numeric,
    p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_owner RECORD;
    v_caller_role TEXT;
    v_new_debt NUMERIC;
    v_is_blocked BOOLEAN;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- Check admin or service_role
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin privileges required');
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Settlement amount must be greater than zero');
    END IF;

    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Owner not found');
    END IF;

    v_new_debt := GREATEST(0.00, COALESCE(v_owner.accumulated_cash_debt, 0.00) - p_amount);
    v_is_blocked := (v_new_debt >= COALESCE(v_owner.debt_limit, 500.00));

    UPDATE public.users
    SET 
        accumulated_cash_debt = v_new_debt,
        is_debt_blocked = v_is_blocked,
        updated_at = v_now
    WHERE id = p_owner_id;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        status,
        payment_method,
        description,
        metadata,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'debt_settlement',
        'completed',
        'admin_adjustment',
        'تسوية مديونية عمولات نقدية: ' || COALESCE(p_notes, 'سداد نقدي/تحويل'),
        jsonb_build_object(
            'previous_debt', v_owner.accumulated_cash_debt,
            'settled_amount', p_amount,
            'remaining_debt', v_new_debt,
            'notes', p_notes
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'settled_amount', p_amount,
        'remaining_debt', v_new_debt,
        'is_debt_blocked', v_is_blocked,
        'message', 'تم تسوية مديونية المالك بنجاح.'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_settle_owner_cash_debt_atomic(uuid, numeric, text) TO authenticated, service_role;


-- ----------------------------------------------------------------------------
-- SECTION 6: F7-003 — UPDATE get_owner_financial_summary
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_owner RECORD;
    v_total_online_revenue NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_cash_revenue NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
    v_debt_limit NUMERIC := 500.0;
    v_is_debt_blocked BOOLEAN := false;
    v_total_completed_bookings INT := 0;
BEGIN
    -- Verification of identity & authorization
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id != p_owner_id AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    -- Fetch owner debt status
    SELECT accumulated_cash_debt, debt_limit, is_debt_blocked
    INTO v_accumulated_debt, v_debt_limit, v_is_debt_blocked
    FROM public.users WHERE id = p_owner_id;

    -- 1. Online revenue, gateway fees, and commission
    SELECT 
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0),
        COUNT(*)
    INTO 
        v_total_online_revenue,
        v_total_gateway_fees,
        v_total_vsp_commission,
        v_total_completed_bookings
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status != 'cancelled';

    v_net_online_earnings := v_total_online_revenue - v_total_gateway_fees - v_total_vsp_commission;

    -- 2. Withdrawn and pending payouts
    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    -- 3. Available balance (taking cash debt liability into account)
    v_available_balance := GREATEST(0.0, v_net_online_earnings - v_total_withdrawn - v_pending_payouts - COALESCE(v_accumulated_debt, 0.0));

    -- 4. Cash revenue
    SELECT COALESCE(SUM(total_price), 0.0)
    INTO v_cash_revenue
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method = 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status != 'cancelled';

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'total_online_revenue', ROUND(v_total_online_revenue, 2),
        'total_gateway_fees', ROUND(v_total_gateway_fees, 2),
        'total_vsp_commission', ROUND(v_total_vsp_commission, 2),
        'net_online_earnings', ROUND(v_net_online_earnings, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'cash_revenue', ROUND(v_cash_revenue, 2),
        'accumulated_cash_debt', ROUND(COALESCE(v_accumulated_debt, 0.0), 2),
        'debt_limit', ROUND(COALESCE(v_debt_limit, 500.0), 2),
        'is_debt_blocked', COALESCE(v_is_debt_blocked, false),
        'completed_bookings_count', v_total_completed_bookings
    );
END;
$function$;


-- ----------------------------------------------------------------------------
-- SECTION 7: F7-006 — RESTORE MISSING RPC CONTRACTS
-- ----------------------------------------------------------------------------

-- 7.1 get_server_timestamp()
CREATE OR REPLACE FUNCTION public.get_server_timestamp()
RETURNS timestamptz
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT timezone('utc'::text, now());
$$;

GRANT EXECUTE ON FUNCTION public.get_server_timestamp() TO anon, authenticated, service_role;

-- 7.2 remove_tournament_team_atomic()
CREATE OR REPLACE FUNCTION public.remove_tournament_team_atomic(
    p_championship_id uuid,
    p_team_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    RETURN public.leave_championship_atomic(p_championship_id, p_team_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_tournament_team_atomic(uuid, uuid) TO authenticated, service_role;


-- ----------------------------------------------------------------------------
-- SECTION 8: F7-002 — DYNAMIC QR CODE SUBSYSTEM
-- ----------------------------------------------------------------------------

-- 8.1 generate_booking_qr_token(p_booking_id uuid)
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
$function$;

GRANT EXECUTE ON FUNCTION public.generate_booking_qr_token(uuid) TO authenticated, service_role;

-- 8.2 verify_booking_qr_atomic(p_booking_id uuid, p_qr_token text)
CREATE OR REPLACE FUNCTION public.verify_booking_qr_atomic(
    p_booking_id uuid,
    p_qr_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
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

    -- 6. [F7-001] Process referral reward if this invitee qualifies
    PERFORM public.process_referral_reward_on_qr_verification(p_booking_id, v_booking.user_id);

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'status', 'completed',
        'is_verified_by_owner', true,
        'message', 'تم تأكيد حضور المباراة واكتمال الحجز بنجاح.'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.verify_booking_qr_atomic(uuid, text) TO authenticated, service_role;


-- ----------------------------------------------------------------------------
-- SECTION 9: F7-001 — REFERRAL SUBSYSTEM & POINTS REWARDS
-- ----------------------------------------------------------------------------

-- 9.1 register_user_referral(p_referral_code text)
CREATE OR REPLACE FUNCTION public.register_user_referral(p_referral_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_invitee_id UUID := auth.uid();
    v_inviter RECORD;
    v_code_clean TEXT;
BEGIN
    IF v_invitee_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    v_code_clean := UPPER(TRIM(p_referral_code));
    IF v_code_clean IS NULL OR LENGTH(v_code_clean) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Referral code cannot be empty');
    END IF;

    -- Find inviter by referral code
    SELECT * INTO v_inviter
    FROM public.users
    WHERE UPPER(referral_code) = v_code_clean;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'كود الدعوة غير صالح أو غير موجود.');
    END IF;

    -- Self-referral rejection
    IF v_inviter.id = v_invitee_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكنك استخدام كود الدعوة الخاص بك.');
    END IF;

    -- Insert referral record
    BEGIN
        INSERT INTO public.referrals (
            inviter_user_id,
            invitee_user_id,
            referral_code,
            status,
            created_at
        ) VALUES (
            v_inviter.id,
            v_invitee_id,
            v_code_clean,
            'pending',
            timezone('utc'::text, now())
        );
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'error', 'لقد قمت باستخدام كود دعوة مسبقاً.');
    END;

    RETURN jsonb_build_object(
        'success', true,
        'inviter_name', v_inviter.name,
        'message', 'تم ربط كود الدعوة بنجاح! سيتم إضافة 500 نقطة بعد إتمام مباراتك الأولى.'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.register_user_referral(text) TO authenticated, service_role;

-- 9.2 process_referral_reward_on_qr_verification(p_booking_id uuid, p_invitee_id uuid)
CREATE OR REPLACE FUNCTION public.process_referral_reward_on_qr_verification(
    p_booking_id uuid,
    p_invitee_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_ref RECORD;
    v_first_qr_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF p_invitee_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Check if user has a pending referral
    SELECT * INTO v_ref
    FROM public.referrals
    WHERE invitee_user_id = p_invitee_id
      AND status = 'pending'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- 2. Verify this is the invitee's first completed QR-verified booking
    SELECT COUNT(*) INTO v_first_qr_count
    FROM public.bookings
    WHERE (user_id = p_invitee_id OR created_by_user_id = p_invitee_id)
      AND status = 'completed'
      AND qr_scanned_at IS NOT NULL;

    -- Only release reward on the very first QR verified booking
    IF v_first_qr_count <> 1 THEN
        RETURN false;
    END IF;

    -- 3. Mark referral rewarded atomically
    UPDATE public.referrals
    SET 
        status = 'rewarded',
        qualified_at = v_now,
        qualifying_booking_id = p_booking_id
    WHERE id = v_ref.id;

    -- 4. Reward Inviter: +250 points (= 5 EGP)
    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users
    SET points = COALESCE(points, 0) + 250,
        updated_at = v_now
    WHERE id = v_ref.inviter_user_id;

    INSERT INTO public.points_ledger (
        user_id,
        points_delta,
        balance_after,
        reason,
        reference_id,
        created_at
    )
    SELECT 
        v_ref.inviter_user_id,
        250,
        points,
        'referral_inviter_reward',
        p_booking_id::text,
        v_now
    FROM public.users WHERE id = v_ref.inviter_user_id;

    -- 5. Reward Invitee: +500 points (= 10 EGP)
    UPDATE public.users
    SET points = COALESCE(points, 0) + 500,
        updated_at = v_now
    WHERE id = v_ref.invitee_user_id;

    INSERT INTO public.points_ledger (
        user_id,
        points_delta,
        balance_after,
        reason,
        reference_id,
        created_at
    )
    SELECT 
        v_ref.invitee_user_id,
        500,
        points,
        'referral_invitee_reward',
        p_booking_id::text,
        v_now
    FROM public.users WHERE id = v_ref.invitee_user_id;

    -- 6. Send Celebratory Notifications
    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
        v_ref.inviter_user_id,
        'مكافأة دعوة صديق! 🎁',
        'تهانينا! لقد أكمل صديقك مباراته الأولى في VSP. تم إضافة 250 نقطة (5 ج.م) إلى محفظتك!',
        'referral_reward',
        v_now
    );

    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
        v_ref.invitee_user_id,
        'مكافأة ترحيبية! 🌟',
        'أهلاً بك في VSP! تم تأكيد حضور مباراتك الأولى وإضافة 500 نقطة (10 ج.م) ترحيبية إلى حسابك!',
        'referral_reward',
        v_now
    );

    RETURN true;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_referral_reward_on_qr_verification(uuid, uuid) TO authenticated, service_role;

-- ============================================================================
-- END OF STAGE 8 REMEDIATION MIGRATION
-- ============================================================================
