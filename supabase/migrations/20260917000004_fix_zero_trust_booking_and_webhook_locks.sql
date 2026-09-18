-- ==============================================================================
-- Migration: 20260917000004_fix_zero_trust_booking_and_webhook_locks.sql
-- Description: Zero-Trust Hardening for Slot Booking & Payment Webhook Concurrency.
--
-- Fixes applied:
-- 1. Server-Authoritative Pricing: Discards client-controlled p_total_price and enforces server calculation.
-- 2. Deposit Enforcement: Rejects 'cash' payment method if stadium requires an online deposit (v_stadium.needs_deposit).
-- 3. Webhook TOCTOU Resolution: Acquires row lock (FOR UPDATE) BEFORE checking transaction idempotency.
-- 4. Timezone Precision: Replaces timezone('utc', now()) with native TIMESTAMPTZ now().
-- 5. B-Tree Index Preservation: Queries stadium_id = v_stadium_uuid directly instead of stadium_id::text.
-- 6. Simplified Mathematical Overlap: (p_start_time < end_time AND p_end_time > start_time).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. HARDENED create_booking_atomic
-- ------------------------------------------------------------------------------

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
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_stadium_uuid UUID;
    v_user_uuid UUID;
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
    v_now TIMESTAMPTZ := now(); -- Fix 4: Native TIMESTAMPTZ (No casting drift)
    
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
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإجراء حجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- Fix 5: Validate and parse UUID upfront to preserve B-Tree indexing
    IF p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN
        v_stadium_uuid := p_stadium_id::uuid;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'معرف الملعب غير صالح.');
    END IF;

    IF p_user_id ~ '^[0-9a-fA-F-]{36}$' THEN
        v_user_uuid := p_user_id::uuid;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'معرف المستخدم غير صالح.');
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

    -- 3. Concurrency Lock on Stadium (Advisory Lock per stadium)
    PERFORM pg_advisory_xact_lock(hashtext(v_stadium_uuid::text));

    -- 4. Verify stadium existence and status (Uses B-Tree index on id)
    SELECT * INTO v_stadium 
    FROM public.stadiums 
    WHERE id = v_stadium_uuid;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- Fix 2: 🛡️ Deposit Enforcement — Reject full cash if owner requires an online deposit
    IF COALESCE(v_stadium.needs_deposit, false) IS TRUE AND p_payment_method = 'cash' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'DEPOSIT_REQUIRED',
            'message', 'عذراً، هذا الملعب يشترط دفع عربون إلكتروني أونلاين لتأكيد الحجز ولا يقبل الحجز النقدي الكامل.'
        );
    END IF;

    -- 5. Operating Hours & Split-Shift Validation (Cairo Local Time)
    v_start_cairo := timezone('Africa/Cairo', p_start_time);
    v_end_cairo := timezone('Africa/Cairo', p_end_time);
    v_date_cairo := v_start_cairo::date;

    IF v_stadium.opening_time IS NOT NULL AND v_stadium.closing_time IS NOT NULL THEN
        IF v_stadium.closing_time > v_stadium.opening_time THEN
            v_open_ts := v_date_cairo + v_stadium.opening_time;
            v_close_ts := v_date_cairo + v_stadium.closing_time;
        ELSE
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

            IF v_start_cairo < v_break_end_ts AND v_end_cairo > v_break_start_ts THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'code', 'OUTSIDE_OPERATING_HOURS',
                    'message', 'عذراً، هذا الموعد يتعارض مع فترة راحة الملعب (Shift Break).'
                );
            END IF;
        END IF;
    END IF;

    -- Fix 1: 🛡️ Server-Authoritative Price Calculation (Client input is strictly ignored/overridden)
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

    v_final_total_price := v_calculated_price; -- Strict server enforcement
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 6. Platform Commission and Gateway Fee
    v_vsp_commission := round(v_final_total_price * 0.02, 2);
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_gateway_fee := round((v_final_total_price * 0.0475) + 3.0, 2);
    ELSE
        v_gateway_fee := 0.00;
    END IF;

    -- 7. User state & No-show checks
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id = v_user_uuid;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 8. Cash Booking: Check Owner Debt Limit
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
        WHERE (user_id = v_user_uuid OR created_by_user_id = v_user_uuid)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > v_now;

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- Fix 5 & 6: ⚡ Direct UUID Index Search + Simplified Mathematical Overlap
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id = v_stadium_uuid -- Direct UUID equality uses B-Tree index
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
      AND (p_start_time < end_time AND p_end_time > start_time); -- Elegant single mathematical overlap condition

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'SLOT_LOCKED_OR_TAKEN',
            'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.'
        );
    END IF;

    -- 9. Booking status assignment
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

    -- 10. Insert Booking Record (Fully server-authoritative values)
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
        v_stadium_uuid,
        v_user_uuid, 
        v_user_uuid, 
        v_final_owner_id,
        p_start_time, 
        p_end_time, 
        p_booking_type, 
        v_final_total_price, -- Server-calculated total price
        v_vsp_commission, 
        v_gateway_fee, 
        v_gateway_fee,
        COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
        COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
        p_is_private, 
        p_rent_ball,
        v_final_needs_deposit, 
        v_final_deposit_amount, 
        0.0,
        p_payment_method, 
        'pending', 
        v_final_status, 
        v_final_is_paid,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[v_user_uuid], 
        v_locked_until, 
        v_now, 
        v_now
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

REVOKE EXECUTE ON FUNCTION public.create_booking_atomic(text, text, text, timestamp with time zone, timestamp with time zone, text, numeric, text, text, boolean, boolean, boolean, numeric, text, text, text, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_booking_atomic(text, text, text, timestamp with time zone, timestamp with time zone, text, numeric, text, text, boolean, boolean, boolean, numeric, text, text, text, text, text, text, numeric) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 2. HARDENED process_paymob_webhook (TOCTOU Race Condition Eliminated)
-- ------------------------------------------------------------------------------

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
SET search_path = public, pg_temp
AS $$
DECLARE
  v_clean_id TEXT;
  v_booking_uuid UUID;
  v_existing_booking RECORD;
  v_is_deposit_only BOOLEAN := FALSE;
  v_deposit_amount NUMERIC := 0.0;
BEGIN
  -- 🔒 الأمان: ممنوع الاستدعاء المباشر من الموبايل — مسموح فقط لـ service_role
  IF auth.role() IS NOT NULL AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Security Alert: Direct user invocation of payment webhook RPC is prohibited.';
  END IF;

  v_clean_id := split_part(p_booking_id, '_', 1);
  IF v_clean_id ~ '^[0-9a-fA-F-]{36}$' THEN
    v_booking_uuid := v_clean_id::uuid;
  ELSE
    RETURN jsonb_build_object('success', FALSE, 'error', 'invalid_booking_id');
  END IF;

  -- 1. تسجيل قيد الـ Webhook للتدقيق والامتثال المالي
  INSERT INTO public.webhook_logs (
    provider, event_type, txn_id, order_id, booking_id, payload, signature_verified, status
  )
  VALUES (
    'paymob',
    CASE WHEN p_success THEN 'payment_success' ELSE 'payment_failed' END,
    p_txn_id, p_order_id, 
    v_booking_uuid, 
    p_payload, p_signature_verified,
    CASE WHEN p_signature_verified THEN 'processed' ELSE 'unverified' END
  );

  -- Fix 3: ⚡ قفل صف الحجز أولاً وفوراً بـ FOR UPDATE قبل فحص الـ Idempotency
  -- هذا يمنع أي TOCTOU Race Condition بين استدعاءين متزامنين لـ Paymob
  SELECT * INTO v_existing_booking
  FROM public.bookings
  WHERE id = v_booking_uuid
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'booking_not_found');
  END IF;

  -- 2. ⚡ الآن بعد قفل الصف حصرياً: افحص إذا كان الحجز قد عولج بالفعل
  IF v_existing_booking.status = 'confirmed' AND (
      (p_txn_id IS NOT NULL AND v_existing_booking.paymob_txn_id = p_txn_id)
      OR v_existing_booking.is_paid IS TRUE 
      OR v_existing_booking.is_deposit_paid IS TRUE
  ) THEN
    RETURN jsonb_build_object(
      'success', TRUE,
      'message', 'duplicate_webhook_ignored',
      'booking_id', v_booking_uuid
    );
  END IF;

  -- 3. فحص إذا كان الحجز نظام عربون فقط
  IF v_existing_booking.needs_deposit = TRUE AND COALESCE(v_existing_booking.deposit_amount, 0) > 0 THEN
    v_is_deposit_only := TRUE;
    v_deposit_amount := v_existing_booking.deposit_amount;
  END IF;

  -- 4. التأكيد النهائي فقط عند نجاح الدفع وصحة التوقيع البنكي
  IF p_success AND p_signature_verified THEN
    UPDATE public.bookings
    SET 
      status = 'confirmed',
      is_paid = NOT v_is_deposit_only,
      payment_status = CASE WHEN v_is_deposit_only THEN 'partially_paid' ELSE 'paid' END,
      is_deposit_paid = TRUE,
      deposit_paid = CASE WHEN v_is_deposit_only THEN v_deposit_amount ELSE COALESCE(deposit_paid, total_price) END,
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_verified = TRUE,
      webhook_processed_at = now(),
      updated_at = now()
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
      'success', TRUE,
      'booking_id', v_booking_uuid,
      'action', 'booking_confirmed',
      'payment_status', CASE WHEN v_is_deposit_only THEN 'partially_paid' ELSE 'paid' END
    );
  ELSE
    UPDATE public.bookings
    SET 
      payment_status = 'failed',
      webhook_verified = p_signature_verified,
      webhook_processed_at = now(),
      updated_at = now()
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
      'success', FALSE, 
      'booking_id', v_booking_uuid, 
      'action', 'payment_failed_recorded'
    );
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_paymob_webhook FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_paymob_webhook TO service_role;
