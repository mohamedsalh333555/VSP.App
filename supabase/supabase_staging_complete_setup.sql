-- ==============================================================================
-- 🚀 VSP COMPLETE SUPABASE STAGING & CONCURRENCY SETUP SCRIPT
-- Copy & Paste this entire script into your Supabase SQL Editor on Staging project
-- ==============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Hardened Atomic Booking Function (Postgres Advisory Lock & Conflict Resolver)
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
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_conflict_count INT;
    v_new_booking_id UUID;
    v_stadium RECORD;
    v_duration_hours NUMERIC;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0.0;
    v_final_total_price NUMERIC;
    v_final_owner_id UUID;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_final_deposit_paid NUMERIC;
    v_locked_until TIMESTAMPTZ := NULL;
BEGIN
    -- 1. Authentication Check
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإتمام الحجز.');
    END IF;

    -- 2. Time Duration Validation
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;

    -- 🔒 3. Postgres Advisory Lock on Stadium ID (Serializes concurrent requests)
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Check Stadium Existence & Status
    SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    -- 5. Calculate Official Server Price
    v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
    v_calculated_price := round(v_hourly_rate * v_duration_hours, 2);
    v_final_total_price := v_calculated_price;
    v_final_owner_id := v_stadium.owner_id;

    -- 🔒 6. Conflict Checking (Overlap Protection)
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

    -- 7. Determine Status & Payment Lock
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

    -- 8. Insert Booking Record Atomically
    INSERT INTO public.bookings (
        stadium_id,
        user_id,
        created_by_user_id,
        owner_id,
        stadium_name,
        stadium_image_url,
        start_time,
        end_time,
        operational_date,
        booking_type,
        is_private,
        rent_ball,
        needs_deposit,
        deposit_paid,
        total_price,
        platform_fee,
        payment_method,
        payment_status,
        status,
        is_paid,
        locked_until,
        created_at,
        updated_at
    ) VALUES (
        v_stadium.id,
        v_caller_id,
        v_caller_id,
        v_final_owner_id,
        v_stadium.name,
        COALESCE(v_stadium.image_url, ''),
        p_start_time,
        p_end_time,
        p_start_time::date,
        p_booking_type,
        p_is_private,
        p_rent_ball,
        p_needs_deposit,
        v_final_deposit_paid,
        v_final_total_price,
        p_platform_fee,
        p_payment_method,
        p_payment_status,
        v_final_status,
        v_final_is_paid,
        v_locked_until,
        NOW(),
        NOW()
    ) RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'message', 'تم تأكيد الحجز بنجاح.'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_booking_atomic TO authenticated, anon;
